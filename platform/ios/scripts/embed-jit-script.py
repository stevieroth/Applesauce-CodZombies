#!/usr/bin/env python3
"""Embed the separately licensed JIT launch script in LiveContainer metadata."""
import base64
import hashlib
import pathlib
import plistlib
import sys

root = pathlib.Path(__file__).resolve().parents[3]
app = pathlib.Path(sys.argv[1])
script = (root / "jit/Applesauce-LiveContainer-universal.js").read_bytes()
assert hashlib.sha256(script).hexdigest() == "e9828331a815c10c2077df6c66c2a974dfec235d03231aba4e50044c6015ea14"
assert (app / "Info.plist").is_file()
info_path = app / "LCAppInfo.plist"
info = plistlib.loads(info_path.read_bytes()) if info_path.exists() else {}
info["jitLaunchScriptJs"] = base64.b64encode(script).decode("ascii")
info_path.write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_BINARY))
(app / "JIT-SCRIPT-LICENSE.txt").write_bytes((root / "jit/LICENSE").read_bytes())
print("Embedded known-working JIT launch script")
