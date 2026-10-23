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

## Desktop privileges

In desktop mode the installer adds a polkit rule
(`/etc/polkit-1/rules.d/49-fortivpn-sgcan.rules`) that lets the installing
user, in a local active session, run `fortivpn-up`, `fortivpn-down`, and
`fortivpn-status` without a password. Viewing, saving, or deleting profiles
still requires administrator authentication. The OTP is still required for
every connection.

To read the status without privileges, a systemd drop-in
(`/etc/systemd/system/strongswan.service.d/fortivpn-vici.conf`) gives the
user's primary group access to the strongSwan VICI socket. VICI does not expose
stored secrets, but any process running as that user can list, start, or stop
IKE connections. Remove both files to require authentication for every
operation again.

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
