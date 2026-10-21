# Notices and provenance

This repository contains an independent, unofficial FortiGate/FortiClient
integration. Fortinet, FortiGate, and FortiClient are trademarks of their
respective owners.

The six patches were derived from the community `strongswan-deb-build` project
at revision:

```text
580192d321065a9628779ce77962cfd8851c2d73
```

The initial OTP agent implementation and integration research were based on
`fortivpn-nm` at revision:

```text
3f0040559abf57de13882009049b4014e4eca5d1
```

Changes added in this repository include:

- strict EAP-Success validation for lengths 4 or 5;
- removal of OTP values from logs;
- multiple profiles with only one active connection;
- separate connection name and Local ID fields;
- ephemeral local IKE/NAT-T ports;
- minimal graphical and headless frontends;
- split-tunnel range validation;
- an installer with backup, package hold, and rollback;
- Ubuntu source files pinned by SHA-256.

The patches modify strongSwan, which is distributed under GPL-2.0-or-later
with the exceptions described by the upstream project. Review `LICENSE` and
the original source headers when redistributing modified binaries. Artifacts
must be accompanied by this repository or by a valid source-code offer that
complies with the GPL.
