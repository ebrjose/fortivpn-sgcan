# strongSwan patches

The patches are applied in this order:

1. `eap_payload-fortigate.patch`: accepts only standard 4-byte EAP-Success or
   the 5-byte FortiGate variant.
2. `eap_authenticator-fortigate.patch`: chains MSCHAPv2 and GTC.
3. `eap_gtc-otp-v3.patch`: obtains the OTP from an external helper.
4. `eap_authenticator-fortigate-pskauth.patch`: reproduces the EAP and
   AUTH/PSK combination expected by the gateway. Noble uses
   `eap_authenticator-fortigate-pskauth-noble.patch` because the internal
   `get_psk_sig()` signature changed between strongSwan 5.9 and 6.0; the added
   logic is the same.
5. `ike_auth-fortigate-fct.patch`: sends INITIAL_CONTACT and the FCT notify.
6. `ike_vendor-forticlient-vid.patch`: sends FortiClient Vendor IDs.

The patches remain separate to simplify auditing and adaptation when Ubuntu
updates strongSwan. `scripts/check-patches.sh` downloads the exact source and
verifies that all six apply cleanly before compilation.
