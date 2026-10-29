#!/bin/bash
# Build a private-library beta package; never replace system OpenConnect/GnuTLS.
set -euo pipefail
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 OPENCONNECT_SOURCE_DIR GNUTLS_SOURCE_DIR EMPTY_WORK_DIR" >&2
  exit 2
fi
oc=$(realpath "$1"); tls=$(realpath "$2"); work=$(realpath -m "$3")
recipe=$(cd "$(dirname "$0")" && pwd)
[ "$(dpkg-parsechangelog -l "$oc/debian/changelog" -S Version)" = "9.12-3.3" ] || { echo 'Expected OpenConnect source 9.12-3.3' >&2; exit 1; }
[ "$(dpkg-parsechangelog -l "$tls/debian/changelog" -S Version)" = "3.8.12-2ubuntu1.1" ] || { echo 'Expected GnuTLS source 3.8.12-2ubuntu1.1' >&2; exit 1; }
if [ -e "$work" ] && [ -n "$(ls -A "$work")" ]; then echo "Work directory must be empty" >&2; exit 1; fi
mkdir -p "$work"
cp -a "$oc" "$work/openconnect"
cp -a "$tls" "$work/gnutls"
patch -d "$work/openconnect" -p1 < "$recipe/openconnect-networkmanager.patch"
patch -d "$work/gnutls" -p1 < "$recipe/gnutls-certificate-chain.patch"
(cd "$work/gnutls"; touch aclocal.m4 configure config.h.in; find . -name Makefile.in -exec touch {} +; ./configure --disable-doc --disable-tests --disable-guile --disable-nls --with-included-unistring --with-default-trust-store-file=/etc/ssl/certs/ca-certificates.crt --with-default-priority-string="NORMAL:-VERS-ALL:+VERS-TLS1.3:+VERS-TLS1.2:+VERS-DTLS1.2:%PROFILE_MEDIUM"; make -j"${JOBS:-2}" -C gl; make -j"${JOBS:-2}" -C lib)
(cd "$work/openconnect"; ./configure --disable-nls; make -j"${JOBS:-2}")
pkg="$work/package"
install -d "$pkg/DEBIAN" "$pkg/usr/lib/codiserver-ksu-vpn" "$pkg/usr/share/polkit-1/rules.d" "$pkg/etc/xdg/autostart" "$pkg/usr/share/doc/codiserver-ksu-vpn-beta"
install -m 755 "$work/openconnect/.libs/libopenconnect.so.5.9.0" "$pkg/usr/lib/codiserver-ksu-vpn/libopenconnect.so.5"
install -m 755 "$work/gnutls/lib/.libs/libgnutls.so.30.41.1" "$pkg/usr/lib/codiserver-ksu-vpn/libgnutls.so.30"
install -m 644 "$recipe/60-codiserver-network.rules" "$pkg/usr/share/polkit-1/rules.d/60-codiserver-network.rules"
install -m 755 "$recipe/ensure-profile.sh" "$pkg/usr/lib/codiserver-ksu-vpn/ensure-profile"
install -m 644 "$recipe/codiserver-ksu-vpn-profile.desktop" "$pkg/etc/xdg/autostart/codiserver-ksu-vpn-profile.desktop"
install -m 644 "$recipe/README.txt" "$pkg/usr/share/doc/codiserver-ksu-vpn-beta/README"
install -m 644 "$work/openconnect/COPYING.LGPL" "$pkg/usr/share/doc/codiserver-ksu-vpn-beta/OPENCONNECT-LICENSE"
install -m 644 "$work/gnutls/COPYING.LESSERv2" "$pkg/usr/share/doc/codiserver-ksu-vpn-beta/GNUTLS-LICENSE"
install -d "$pkg/usr/share/doc/codiserver-ksu-vpn-beta/source"
find "$recipe" -maxdepth 1 -type f -exec cp -a {} "$pkg/usr/share/doc/codiserver-ksu-vpn-beta/source/" \;
cat > "$pkg/DEBIAN/control" <<'CONTROL'
Package: codiserver-ksu-vpn-beta
Version: 0.1.0-1
Architecture: amd64
Maintainer: CodiServer Maint <maint@code.contractors>
Depends: network-manager-openconnect-gnome, libgnutls30t64, libopenconnect5
Description: KSU NetworkManager VPN beta private libraries
 Isolated authentication libraries and active-local network permissions.
CONTROL
cat > "$pkg/DEBIAN/postinst" <<'POST'
#!/bin/sh
set -e
if [ "$1" = configure ]; then
  dpkg-divert --package codiserver-ksu-vpn-beta --rename --add /usr/libexec/nm-openconnect-auth-dialog
  cat > /usr/libexec/nm-openconnect-auth-dialog <<'WRAPPER'
#!/bin/sh
previous=
for argument in "$@"; do
  if [ "$previous" = '-n' ] && [ "$argument" = 'KSU GlobalProtect' ]; then
    export LD_LIBRARY_PATH=/usr/lib/codiserver-ksu-vpn
    break
  fi
  previous=$argument
done
exec /usr/libexec/nm-openconnect-auth-dialog.distrib "$@"
WRAPPER
  chmod 755 /usr/libexec/nm-openconnect-auth-dialog
fi
POST
cat > "$pkg/DEBIAN/prerm" <<'PRE'
#!/bin/sh
set -e
if [ "$1" = remove ] || [ "$1" = deconfigure ]; then
  rm -f /usr/libexec/nm-openconnect-auth-dialog
  dpkg-divert --package codiserver-ksu-vpn-beta --rename --remove /usr/libexec/nm-openconnect-auth-dialog
fi
PRE
chmod 755 "$pkg/DEBIAN/postinst" "$pkg/DEBIAN/prerm"
sha256sum "$recipe/openconnect-networkmanager.patch" "$recipe/gnutls-certificate-chain.patch" > "$pkg/usr/share/doc/codiserver-ksu-vpn-beta/patches.sha256"
dpkg-deb --root-owner-group --build "$pkg" "$work/codiserver-ksu-vpn-beta_0.1.0-1_amd64.deb"
python3 - "$recipe" "$work" <<'PYCODE'
import hashlib, json, subprocess, sys
from pathlib import Path
recipe, work = map(Path, sys.argv[1:])
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
out = work / 'codiserver-ksu-vpn-beta_0.1.0-1_amd64.deb'
data = {'package': out.name, 'artifact_sha256': sha(out), 'source_versions': {'openconnect':'9.12-3.3', 'gnutls28':'3.8.12-2ubuntu1.1'}, 'recipe_files': {p.name: sha(p) for p in recipe.iterdir() if p.is_file()}, 'build_dependencies': subprocess.check_output(['dpkg-query','-W','-f=${binary:Package}\t${Version}\n'], text=True).splitlines(), 'compiler': subprocess.check_output(['gcc','--version'],text=True).splitlines()[0], 'configure': {'gnutls':'--disable-doc --disable-tests --disable-guile --disable-nls --with-included-unistring --with-default-trust-store-file=/etc/ssl/certs/ca-certificates.crt --with-default-priority-string=NORMAL:-VERS-ALL:+VERS-TLS1.3:+VERS-TLS1.2:+VERS-DTLS1.2:%PROFILE_MEDIUM','openconnect':'--disable-nls'}}
(work/'provenance.json').write_text(json.dumps(data, indent=2)+'\n')
PYCODE
