KSU Linux VPN beta
==================

The beta uses NetworkManager's OpenConnect interface with isolated patched
OpenConnect and GnuTLS libraries. The normal system libraries are unchanged.
The desktop creates a user-owned KSU GlobalProtect profile on first login;
the user can manage networking without sudo. The VPN uses interactive KSU
sign-in and optional HIP reporting is disabled by default.

Source inputs are Ubuntu openconnect 9.12-3.3 and gnutls28
3.8.12-2ubuntu1.1. The offline bundle carries these sources, local patches,
package recipe, package hashes and build provenance. The beta certificate
path change has passed selected tests but needs broader security review. TLS
certificate verification remains enabled.

Validation on one Surface established a KSU tunnel and DNS while retaining
LAN access. Long-running sessions, real network interruptions and deployment
across other hardware and distributions require further testing. Do not embed
usernames, passwords, session cookies or machine-specific identifiers.
