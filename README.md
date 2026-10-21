# fortivpn-sgcan

FortiGate IKEv2 client for Ubuntu with:

- gateway PSK;
- username and password authentication through EAP-MSCHAPv2;
- OTP second factor through EAP-GTC;
- multiple independent connections;
- separate connection name and Local ID parameters;
- multiple split-tunnel ranges per connection;
- a graphical desktop interface and a CLI for servers over SSH.

This project reproduces a configuration validated against a real FortiGate.
It is not an official Fortinet product and requires six small, auditable
patches to strongSwan to implement proprietary FortiClient extensions.

## Supported systems

| Ubuntu | Codename | Pinned strongSwan version | Architecture |
|---|---|---|---|
| 24.04 LTS | Noble | `5.9.13-2ubuntu4.24.04.1` | amd64 |
| 26.04 LTS | Resolute | `6.0.4-1ubuntu3.2` | amd64 |

Ubuntu `26.06` is not an official release; this repository interprets that
requirement as Ubuntu 26.04 LTS.

The official source versions and hashes are stored in [`versions/`](versions/).
The installer stops if the system or installed version does not match; it does
not force downgrades.

## Reproducible build

Requirement: Docker.

```bash
make check
make check-patches
make build
```

Each build runs inside the official image for its Ubuntu release. The process:

1. downloads the exact source published by Ubuntu/Launchpad;
2. verifies the three pinned SHA-256 checksums;
3. installs build dependencies in a disposable container;
4. applies the six patches in order;
5. builds unsigned Debian packages;
6. copies only `strongswan-libcharon` and `libcharon-extra-plugins` to
   `dist/ubuntu-VERSION/`;
7. generates `SHA256SUMS` for the artifacts.

You can also build one release at a time:

```bash
./scripts/build-strongswan.sh 24.04
./scripts/build-strongswan.sh 26.04
```

The `.deb` files are not committed. They are generated from the sources and
patches in this repository.

## Desktop installation

Build the artifacts for the local release first. Then run:

```bash
./install.sh --desktop
```

The script uses `pkexec`, installs the **FortiGate VPN** application, and
enables the OTP agent in the user's session. The application can create, edit,
connect, disconnect, and delete connections.

`pkexec` is not guaranteed to be installed on every Debian-family system. On
the supported Ubuntu releases, install the `pkexec` package if the command is
missing. Desktop authorization also requires an active polkit authentication
agent. Headless mode deliberately uses `sudo` instead.

Each connection requests these fields separately:

- Connection name (a free-form label);
- FortiGate address (IP or DNS name);
- Local ID;
- username;
- PSK;
- password;
- comma-separated remote networks.

Example split-tunnel networks:

```text
198.51.100.0/24,203.0.113.0/24
```

Only those networks go through the VPN. Do not use `0.0.0.0/0` unless you want
all IPv4 traffic, including Internet access, routed through the FortiGate.

## Headless server installation

```bash
./install.sh --headless
fortivpn-cli add
fortivpn-cli connect
```

Headless mode uses `sudo`, does not install Zenity, and reads the OTP privately
from the SSH terminal. The SSH session may be closed after the tunnel is
established; the SA remains active in strongSwan.

Available commands:

```text
fortivpn-cli list
fortivpn-cli add
fortivpn-cli edit [ID]
fortivpn-cli delete [ID]
fortivpn-cli connect [ID]
fortivpn-cli disconnect
fortivpn-cli status
```

A VPN that requires an OTP cannot fully reconnect by itself after a reboot: an
operator must enter a new code unless the FortiGate authentication method is
changed.

## Profiles and secrets

- Profiles are stored under `/etc/fortivpn/profiles/` as `root:root 0600`.
- OTP values are never stored.
- PSKs and passwords are never passed as process arguments.
- The public index contains only the name, Local ID, gateway, and ranges; it
  contains no secrets.
- Only one connection may be active at a time, preventing PSKs, Local IDs, and
  routes from different accounts on the same FortiGate from being mixed.
- The bundle never includes profiles or credentials from any machine.

## strongSwan updates

The two patched packages are placed on `apt-mark hold`. When Ubuntu publishes a
security update:

1. update the version and hashes in `versions/ubuntu-XX.XX.env`;
2. run `make check-patches`;
3. review and adapt any patch that no longer applies cleanly;
4. run `make build` and the tests;
5. deploy the new packages;
6. do not remove the hold until validated artifacts are available.

Do not keep an old strongSwan version indefinitely after Ubuntu publishes a
security fix.

## Rollback

During installation, the official packages are downloaded and saved under:

```text
/var/backups/fortivpn-sgcan/UBUNTU-VERSION/STRONGSWAN-VERSION/official/
```

To restore them without deleting profiles:

```bash
sudo ./scripts/rollback.sh
```

## Transferable bundle

After building both releases:

```bash
make bundle
```

The archive and its SHA-256 checksum appear under `release/`. Copy both files
to the other machine and run the following commands from their destination
directory:

```bash
sha256sum -c fortivpn-sgcan-ubuntu-24.04-26.04-amd64.tar.gz.sha256
tar -xzf fortivpn-sgcan-ubuntu-24.04-26.04-amd64.tar.gz
cd fortivpn-sgcan
./install.sh --desktop  # or: ./install.sh --headless
```

The destination machine does not need Docker because the bundle already
contains packages built for both Ubuntu releases.

## Scope and warnings

- The patches mimic proprietary behavior observed in FortiClient.
- They must be reviewed again whenever the strongSwan version changes.
- The FortiGate firewall remains responsible for authorizing destinations and
  users; client ranges only decide which traffic is sent into the tunnel.
- Local IKE ports are ephemeral to avoid NAT conflicts when multiple machines
  connect to the same FortiGate from one network.

Read [SECURITY.md](SECURITY.md) and [NOTICE.md](NOTICE.md) before distributing
the artifacts.
