# Security

## Data that must never be committed

- FortiGate PSKs.
- User passwords.
- OTP values.
- `*.profile` files from `/etc/fortivpn/profiles/`.
- `/etc/strongswan.d/fct_data.txt` generated on a machine.
- `/etc/swanctl/conf.d/fortivpn-active.conf`.
- Packet captures containing identities or private addresses.

The `.gitignore` file covers common artifacts, but it is not a substitute for
reviewing every commit.

## Local storage

Secrets are Base64-encoded only so they can be inserted into swanctl syntax;
Base64 is not encryption. Actual protection comes from `root` ownership and
mode `0600`. Systems with a stronger threat model should integrate a secret
store or request credentials for every connection.

## OTP

The strongSwan helper and the user exchange the OTP through a FIFO under
`/run/fortivpn`. The directory is not group-writable, and each request includes
a nonce to reject stale responses. The code is never logged.

## Patches and updates

Installation modifies two security-sensitive packages. Both are pinned with
`apt-mark hold` to prevent an update from silently replacing the patches, but
this also requires prompt rebuilding whenever Ubuntu publishes a fix. Never
force a package built for a different release.

## Reporting vulnerabilities

Do not publish PSKs, passwords, OTP values, complete logs, or packet captures
in an issue. Share only sanitized traces with the project's internal owner.
