"""Render single-app signing options without reading credentials."""
import os
from pathlib import Path
import plistlib
import sys

data = plistlib.loads(Path(__file__).with_name("ExportOptions.plist").read_bytes())
data["teamID"] = os.environ["TEAM_ID"]
data["provisioningProfiles"] = {os.environ.get("APP_ID", "com.hgsldswk.shutoffmap"): os.environ.get("APP_PROFILE", "ShutoffMap AppStore")}
sys.stdout.buffer.write(plistlib.dumps(data))
