#!/usr/bin/env python3
"""Validate the unsigned offline iOS release, without signing tools or a device."""
import base64
import hashlib
import pathlib
import plistlib
import struct
import sys
import zipfile

ipa = pathlib.Path(sys.argv[1])
root = pathlib.Path(__file__).resolve().parents[3]
prefix = "Payload/Applesauce.app/"
with zipfile.ZipFile(ipa) as z:
    assert z.testzip() is None, "Corrupt ZIP member"
    names = z.namelist()
    assert all(n.startswith(prefix) or n == "Payload/" for n in names)
    assert not any(".." in pathlib.PurePosixPath(n).parts for n in names)
    info = plistlib.loads(z.read(prefix + "Info.plist"))
    assert info["CFBundleIdentifier"] == "io.github.johnny901901901.applesauce"
    assert info["CFBundleShortVersionString"] == "0.4.1"
    assert info["CFBundleVersion"] == "35"
    assert info["MinimumOSVersion"] == "15.0"
    assert "NSBonjourServices" not in info
    assert "NSLocalNetworkUsageDescription" not in info
    libs = {pathlib.PurePosixPath(n).name for n in names if "/Frameworks/" in n and n.endswith(".dylib")}
    assert libs == {"libtouchhle_core.dylib", "libSDL2-2.0.0.dylib"}, libs
    script = (root / "jit/Applesauce-LiveContainer-universal.js").read_bytes()
    launch = plistlib.loads(z.read(prefix + "LCAppInfo.plist"))
    assert base64.b64decode(launch["jitLaunchScriptJs"]) == script
    assert z.read(prefix + "JIT-SCRIPT-LICENSE.txt") == (root / "jit/LICENSE").read_bytes()
    forbidden_names = (".ipa", ".p12", ".cer", ".mobileprovision", ".mobiledevicepairing")
    forbidden_bytes = (b"/Users/", b"195.7.7.200", b"SDL_TOUCHHLE_CODZ_CONTROLLER",
                       b"codzControllerEnabled", b"TRACE34", b"TRACE33 NET")
    for name in names:
        assert not name.endswith(forbidden_names), name
        assert "_CodeSignature" not in name and not name.endswith("touchHLE_log.txt"), name
        if name.endswith("/"):
            continue
        data = z.read(name)
        for marker in forbidden_bytes:
            assert marker not in data, (name, marker)
        if data[:4] != b"\xcf\xfa\xed\xfe":
            continue
        magic, cpu, subtype, kind, count, size, flags, reserved = struct.unpack_from("<8I", data)
        assert cpu == 0x100000C, name
        offset = 32
        for _ in range(count):
            command, length = struct.unpack_from("<2I", data, offset)
            if command == 0x32:  # LC_BUILD_VERSION
                platform, minimum = struct.unpack_from("<2I", data, offset + 8)
                assert platform == 2 and minimum <= 0xF0000, (name, platform, minimum)
            if name == prefix + "Applesauce":
                assert command != 0x1D, "Host must be unsigned"
            offset += length
    core = z.read(prefix + "Frameworks/libtouchhle_core.dylib")
    assert b"S3E loader compatibility applied" in core
    assert b"fbase=0x1000" in core
    assert b"Starting Orientation" in z.read(prefix + "Applesauce")

print("PASS: unsigned arm64 IPA, touchHLE-only, offline profile, preserved loader fixes and JIT script")
print(hashlib.sha256(ipa.read_bytes()).hexdigest(), ipa.name)
