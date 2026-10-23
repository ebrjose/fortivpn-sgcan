#!/usr/bin/env python3
"""Tests for the Qt-independent helpers of client/fortivpn-manager."""

import importlib.machinery
import importlib.util
import pathlib
import sys

path = pathlib.Path(__file__).resolve().parent.parent / "client" / "fortivpn-manager"
loader = importlib.machinery.SourceFileLoader("fortivpn_manager", str(path))
spec = importlib.util.spec_from_loader(loader.name, loader)
manager = importlib.util.module_from_spec(spec)
loader.exec_module(manager)

CONNECTED = """\
fortigate-test: #1, ESTABLISHED, IKEv2, ee5b99b614d36ae0_i* e989bc11d100c172_r
  local  'LOCAL-ID' @ 192.168.0.10[4501] [10.255.91.202]
  remote '203.0.113.9' @ 203.0.113.9[4500]
  AES_CBC-256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_2048
  established 3725s ago, rekeying in 82675s
  fortigate-test-lan: #1, reqid 1, INSTALLED, TUNNEL-in-UDP, ESP:AES_CBC-256/HMAC_SHA2_256_128
    installed 3725s ago, rekeying in 39475s, expires in 41275s
    in  c40bd279,  152340 bytes,   900 packets,     2s ago
    out 53552b8a,   48211 bytes,   700 packets,     2s ago
    local  10.255.91.202/32
    remote 198.51.100.0/24 203.0.113.0/24
"""

CONNECTING = """\
fortigate-test: #1, CONNECTING, IKEv2, ab12_i* 0000_r
  local  '%any' @ 192.168.0.10[500]
  remote '%any' @ 203.0.113.9[500]
"""


def main():
    status = manager.parse_list_sas(CONNECTED)
    assert status.state == "connected", status
    assert status.slug == "test"
    assert status.virtual_ip == "10.255.91.202"
    assert status.remote_ts == ["198.51.100.0/24", "203.0.113.0/24"]
    assert (status.established_seconds, status.bytes_in, status.bytes_out) == (3725, 152340, 48211)
    assert manager.parse_list_sas(CONNECTING).state == "connecting"
    assert manager.parse_list_sas("").state == "disconnected"
    assert manager.parse_list_sas("other-conn: #1, ESTABLISHED, IKEv2\n").state == "disconnected"

    assert manager.format_duration(3725) == "1:02:05"
    assert manager.format_duration(65) == "1:05"
    assert manager.format_bytes(500) == "500 B"
    assert manager.format_bytes(152340) == "148.8 KiB"

    valid = {"name": "Test VPN", "gateway": "vpn.example.test", "local_id": "LOCAL-ID",
             "user": "user@example.test", "ranges": "198.51.100.0/24, 203.0.113.0/24",
             "psk": "tunnel-key", "password": "secret"}
    assert manager.validate_form(valid, new=True) == []
    assert manager.validate_form(dict(valid, psk="", password=""), new=False) == []
    fields = {key for key, _ in manager.validate_form(
        dict(valid, gateway="bad host", ranges="198.51.100.0/24,300.1.1.1/24", psk=""), new=True)}
    assert fields == {"gateway", "ranges", "psk"}, fields
    assert manager.validate_form(dict(valid, ranges="10.0.0.0/0"), new=True)[0][0] == "ranges"
    assert manager.validate_form(dict(valid, ranges="0.0.0.0/0"), new=True) == []
    print("fortivpn-manager helper tests passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
