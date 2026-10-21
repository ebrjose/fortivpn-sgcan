# Repository instructions

## Scope

This repository builds and installs an unofficial FortiGate-compatible IKEv2
client based on patched Ubuntu strongSwan packages. Keep support limited to
Ubuntu 24.04 LTS and Ubuntu 26.04 LTS on amd64 unless support for another target
is explicitly requested and fully validated. Ubuntu 26.06 is not a release.

## Security requirements

- Never commit or print real PSKs, passwords, OTP values, gateways, usernames,
  Local IDs, private network details, generated profiles, packet captures, or
  machine-specific `fct_data.txt` files.
- Use only synthetic `.example.test` hosts and documentation-only network
  ranges in tests and examples.
- Keep profile files owned by `root:root` with mode `0600`.
- Treat Base64 as encoding, not encryption. Do not describe stored credentials
  as encrypted.
- Never log the OTP or pass PSKs/passwords as process arguments.
- Preserve the single-active-profile rule so credentials and routes from
  different FortiGate accounts cannot be mixed.

## Source and patch policy

- Build only from the exact Ubuntu source URLs, versions, and SHA-256 values in
  `versions/ubuntu-*.env`.
- Keep the six logical FortiGate patches separate and apply them in the order
  documented in `strongswan/README.md`.
- Ubuntu 24.04 uses
  `eap_authenticator-fortigate-pskauth-noble.patch`; Ubuntu 26.04 uses
  `eap_authenticator-fortigate-pskauth.patch`.
- A patch change requires `make check-patches` and complete package builds for
  both supported releases before distribution.
- Do not weaken the EAP-Success length validation or reintroduce OTP logging.

## User experience

- Keep documentation, comments, diagnostics, and graphical/CLI text in
  English.
- Desktop privilege elevation must use `pkexec`; headless operation must use
  `sudo` and read the OTP from the controlling terminal.
- Keep the connection display name separate from the FortiGate Local ID.
- Allow multiple comma-separated split-tunnel ranges. Do not silently add a
  default route or assume which private networks a user may access.
- The OTP is supplied only when the gateway requests it and is never saved.

## Validation

Run the smallest relevant checks while editing and the complete local suite
before committing:

```bash
make check
make check-patches
make build
make bundle
```

Also verify both `dist/ubuntu-*/SHA256SUMS` files and the checksum in
`release/`. Run ShellCheck when available. Package builds must occur in the
matching official Ubuntu Docker image; do not build a package for one release
on the other release's host environment.

Generated `.deb` files and release archives remain untracked. Do not install
the project on the host merely to test a repository change; use disposable
containers where possible. An explicit user request is required before
modifying the host VPN installation.

## Distribution and maintenance

- Preserve the GPL license, notices, patch provenance, and corresponding
  source needed to redistribute modified strongSwan binaries.
- The installer holds the two patched packages. When Ubuntu publishes a newer
  strongSwan security update, update the pinned source, adapt and review the
  patches, rebuild both targets, and publish a new bundle promptly.
- Keep backup and rollback behavior intact whenever installation logic changes.
