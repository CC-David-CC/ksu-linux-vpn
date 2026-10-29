#!/bin/sh
# Create an owned VPN profile once for each logged-in desktop user.
set -eu
name='KSU GlobalProtect'
if nmcli -g connection.id connection show "$name" >/dev/null 2>&1; then exit 0; fi
user=$(id -un)
case "$user" in ''|*[!a-zA-Z0-9_.-]*) echo 'Cannot create KSU VPN profile: unsupported username' >&2; exit 1;; esac
nmcli connection add type vpn vpn-type openconnect con-name "$name" ifname '*' \
  connection.permissions "user:$user" vpn.data 'gateway=vpn.kennesaw.edu,protocol=gp' >/dev/null
