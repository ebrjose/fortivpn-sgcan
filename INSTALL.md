# Installation

Step-by-step guide for a clean Ubuntu machine. See [README.md](README.md) for
an overview of the project and [SECURITY.md](SECURITY.md) for how credentials
are stored.

## Requirements

- Ubuntu 24.04 LTS or 26.04 LTS, amd64.
- A regular user account with administrator rights (do not run the installer
  as root).
- Internet access to the Ubuntu archive.
- The FortiGate connection details: gateway address, Local ID, username, PSK,
  password, the remote networks to route through the VPN, and an OTP device.

The patched packages are built for one exact strongSwan version per release:

| Ubuntu | strongSwan |
|---|---|
| 24.04 | `5.9.13-2ubuntu4.24.04.1` |
| 26.04 | `6.0.4-1ubuntu3.2` |

Check what the Ubuntu archive currently offers:

```bash
sudo apt update
apt-cache policy strongswan-libcharon
```

If the candidate version is newer than the table above, the installer will stop.
Use [Option B](#option-b-build-from-source) after updating `versions/`, or wait
for a newer release of this project.

## 1. Install the prerequisites

```bash
sudo apt update
sudo apt install git pkexec
```

strongSwan itself does not need to be installed beforehand; the installer
installs it.

## 2. Get the packages

A fresh clone does **not** contain the patched `.deb` files: they are generated
artifacts and are not committed. Choose one of the two options below.

### Option A: download a release (no Docker needed)

Download both files from the project's GitHub Releases page:

```bash
V=v1.0.0
F=fortivpn-sgcan-ubuntu-24.04-26.04-amd64.tar.gz
wget "https://github.com/ebrjose/fortivpn-sgcan/releases/download/$V/$F" \
     "https://github.com/ebrjose/fortivpn-sgcan/releases/download/$V/$F.sha256"
```

For a private repository, use the GitHub CLI instead:

```bash
gh release download v1.0.0 --repo ebrjose/fortivpn-sgcan
```

Verify and extract the bundle, then continue with
[step 3](#3-install) from inside the extracted directory:

```bash
sha256sum -c fortivpn-sgcan-ubuntu-24.04-26.04-amd64.tar.gz.sha256
tar -xzf fortivpn-sgcan-ubuntu-24.04-26.04-amd64.tar.gz
cd fortivpn-sgcan
```

### Option B: build from source

Requires Docker, and your user must be able to run `docker` (for example, by
being a member of the `docker` group).

```bash
git clone https://github.com/ebrjose/fortivpn-sgcan.git
cd fortivpn-sgcan
make check
make check-patches
./scripts/build-strongswan.sh 26.04   # or 24.04: build the release you run
```

The build runs inside the official `ubuntu:<release>` image, downloads the
pinned strongSwan sources, verifies their SHA-256 checksums, applies the six
patches, and writes the packages to `dist/ubuntu-<release>/`. Verify them:

```bash
(cd dist/ubuntu-26.04 && sha256sum -c SHA256SUMS)
```

To build both releases and produce a transferable bundle for other machines,
run `make build` followed by `make bundle`; the archive appears under
`release/`.

## 3. Install

Run from the repository (or extracted bundle) directory as your regular user.

### Desktop

```bash
./install.sh --desktop
```

A polkit dialog asks for your password. The installer:

1. verifies the Ubuntu release and the package checksums;
2. installs the strongSwan dependencies and Zenity;
3. downloads the official packages to
   `/var/backups/fortivpn-sgcan/<release>-<version>/official/` for rollback;
4. installs the two patched packages and places them on `apt-mark hold`;
5. installs the client, the **FortiGate VPN** application, and the OTP agent
   for your user session.

It finishes with:

```text
FortiVPN SGCAN installed for <user> on Ubuntu <release> (desktop).
```

### Headless server (SSH)

```bash
./install.sh --headless
```

This uses `sudo`, skips the graphical components, and reads the OTP from the
terminal.

## 4. Create a connection

### Desktop

Open **FortiGate VPN** from the application menu and create a connection with:

- Connection name: any label.
- FortiGate address: IP or DNS name.
- Local ID.
- Username.
- PSK.
- Password.
- Remote networks, comma-separated, for example `198.51.100.0/24,203.0.113.0/24`.

Only the listed networks go through the VPN. Do not use `0.0.0.0/0` unless all
IPv4 traffic, including Internet access, should go through the FortiGate.

### Headless

```bash
fortivpn-cli add
```

## 5. Connect and verify

Connect from the application, or with `fortivpn-cli connect` on a server. Enter
the OTP when prompted; it is never stored.

```bash
fortivpn-cli status
ping <an address in a remote network>
```

Disconnect from the application or with `fortivpn-cli disconnect`.

## Keeping it up to date

The two patched packages are on hold, so `apt upgrade` will not replace them,
and it will not install strongSwan security updates either. When Ubuntu
publishes a new strongSwan version, update `versions/ubuntu-<release>.env`,
rebuild, and reinstall as described in [README.md](README.md#strongswan-updates).

## Rollback

Restore the official Ubuntu packages (profiles are kept):

```bash
sudo ./scripts/rollback.sh
```

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `Desktop mode requires pkexec` | Install `pkexec` and log in to a graphical session with a polkit agent, or use `--headless`. |
| `Ubuntu packages are missing. Run: ./scripts/build-strongswan.sh …` | A fresh clone has no packages. Use Option A or Option B. |
| `The repository installed strongSwan X, but this checkout is pinned to Y` | Ubuntu published a newer strongSwan. Update `versions/`, rebuild, or use a newer release. |
| `Package SHA-256 verification failed` | The packages in `dist/` are corrupt or were modified. Download or build them again. |
| Connection fails right after entering the OTP | Check that the OTP agent is running: `systemctl --user status fortivpn-otp-agent`. |
