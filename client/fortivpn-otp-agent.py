#!/usr/bin/env python3
"""Prompt for a FortiGate email OTP in the logged-in user's desktop session."""

import errno
import os
import re
import subprocess
import sys
import time

REQUEST = "/run/fortivpn/otp.request"
PIPE = "/run/fortivpn/otp.pipe"
REQUEST_RE = re.compile(r"^REQUEST (\S+)\s*$")
OTP_RE = re.compile(r"^\s*(\d{4,8})\s*$")


def log(message):
    print(f"fortivpn-otp-agent: {message}", file=sys.stderr, flush=True)


def request_nonce():
    try:
        with open(REQUEST, encoding="ascii") as stream:
            match = REQUEST_RE.match(stream.read())
            return match.group(1) if match else None
    except OSError:
        return None


def prompt():
    try:
        result = subprocess.run(
            [
                "zenity",
                "--entry",
                "--hide-text",
                "--title=FortiGate VPN — OTP code",
                "--text=Enter the code received by email:",
                "--width=360",
            ],
            capture_output=True,
            text=True,
            timeout=115,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        log(f"could not display OTP prompt: {error}")
        return None
    if result.returncode != 0:
        log("OTP prompt cancelled or timed out")
        return None
    match = OTP_RE.match(result.stdout)
    return match.group(1) if match else None


def deliver(nonce, code):
    try:
        descriptor = os.open(PIPE, os.O_WRONLY | os.O_NONBLOCK)
        try:
            os.write(descriptor, f"{nonce} {code}\n".encode("ascii"))
        finally:
            os.close(descriptor)
        return True
    except OSError as error:
        if error.errno == errno.ENXIO:
            log("OTP request expired before the code was entered")
        else:
            log(f"could not deliver OTP: {error}")
        return False


def main():
    log("started")
    # Process a request that might already be waiting when the user service
    # starts (for example immediately after login).
    last_nonce = None
    last_mtime_ns = None
    while True:
        try:
            mtime_ns = os.stat(REQUEST).st_mtime_ns
        except OSError:
            time.sleep(0.5)
            continue
        if mtime_ns != last_mtime_ns:
            last_mtime_ns = mtime_ns
            nonce = request_nonce()
            if nonce and nonce != last_nonce:
                last_nonce = nonce
                code = prompt()
                if code and deliver(nonce, code):
                    log("OTP delivered")
                elif not code:
                    log("no valid OTP supplied")
        time.sleep(0.5)


if __name__ == "__main__":
    sys.exit(main())
