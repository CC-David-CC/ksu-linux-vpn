# KSU Linux VPN — beta

Linux NetworkManager and OpenConnect support for Kennesaw State University's GlobalProtect VPN. The beta has connected on a CodiServer Surface using Microsoft sign-in, KSU DNS and simultaneous local-network access. It requires no maint password when the VPN connection is owned by the desktop user and network permissions are configured.

**Status:** One Surface and one account tested. The certificate-path change requires further security review; long sessions, actual network interruption, installation, and other distributions and hardware are not yet verified. This repository does not yet provide an installer or a tested general-purpose installation recipe.

## Components

- `patches/openconnect-networkmanager.patch`: OpenConnect 9.12 portal SAML handoff and host identifier changes. The test generates a new identifier; stability and policy implications require further study. This patch additionally scopes KSU-specific request changes and suppresses cookie logging; those refinements await a fresh live test.
- `patches/gnutls-certificate-chain.patch`: GnuTLS 3.8.12 certificate-chain path selection change. Selected upstream checks passed, including hostname rejection, but this is not a complete security audit. Certificate checks remain enabled.
- `desktop/60-codiserver-network.rules`: CodiServer policy allowing active local desktop users limited network control, without sudo. This policy is system-specific; administrators should review it before installing.

The test used NetworkManager's OpenConnect plugin and system DNS integration. HIP reporting was not required for the limited KSU resources tested and is not enabled by this beta. Access to other resources may differ.

## Source and licensing

Changes are supplied as patches; obtain the matching upstream source and follow its license and build instructions. No credentials, private keys, logs or binaries belong in this repository.

- OpenConnect: https://gitlab.com/openconnect/openconnect (LGPL)
- GnuTLS: https://gitlab.com/gnutls/gnutls (see upstream licenses)
- NetworkManager OpenConnect plugin: https://gitlab.gnome.org/GNOME/NetworkManager-openconnect

Run the network policy logic test with `gjs tests/test_network_policy.js`. This isolated test does not replace live connection, certificate or authorization tests.
