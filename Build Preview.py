"""Build a portable source preview. Does not access raw devices or install software."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parent
PACKAGE_ROOT = "PC Security Toolkit"
PACKAGE_FILES = (
    "README.md", "READ ME FIRST.txt", "SECURITY.md", "CONTRIBUTING.md",
    "START HERE Windows.bat", "START HERE Mac.command", "START HERE Linux.sh",
    "Engine/Toolkit Server.ps1", "Engine/Guest Policy.ps1",
    "Engine/Mac and Linux Server.py", "Engine/Guest Dashboard.html",
    "Docs/Safety Review.md", "Docs/Implementation Plan.md", "Docs/Safety Test Plan.md",
    "Docs/Preview Validation.md", "Docs/Three USB Modes.md", "Docs/Download and Run.md",
    "Docs/Bundled Binary Inventory.json",
    "Build Preview.py", "Tests/test_guest_boundary.py", "Tests/test_package_integration.py",
    "Tests/test_scan_observations.py", "Docs/Windows Testing Checklist.md",
    "Tests/Guest Policy Tests.ps1",
)


def package_bytes(root, name):
    # Normalize line endings so Windows and Unix produce the same file bytes.
    text = (root / name).read_text(encoding="utf-8")
    if name.endswith((".ps1", ".bat")):
        text = text.replace("\n", "\r\n")
    return text.encode("utf-8")


def build_preview(source_root, output_dir, revision="unversioned-source"):
    source_root, output_dir = Path(source_root), Path(output_dir)
    if revision != "unversioned-source" and not re.fullmatch(r"[0-9a-f]{7,40}", revision):
        raise ValueError("revision must be a Git SHA or unversioned-source")
    # Read and validate every input before creating any output.
    content = {name: package_bytes(source_root, name) for name in PACKAGE_FILES}
    manifest = {"format": 1, "product": "PC Security Toolkit", "status": "scan-only preview",
                "revision": revision, "secure_session_helper": "not included",
                "bootable_workspace_image": "not included", "third_party_binaries": "not included",
                "files": [{"path": name, "sha256": hashlib.sha256(data).hexdigest(),
                           "size_bytes": len(data)} for name, data in sorted(content.items())]}
    content["PACKAGE CONTENTS.json"] = (json.dumps(manifest, indent=2) + "\n").encode("utf-8")
    archive = output_dir / "PC Security Toolkit Preview.zip"
    checksums = output_dir / "SHA256SUMS.txt"
    if archive.exists() or checksums.exists():
        raise FileExistsError("Output already exists. Choose an empty output folder; existing files will not be replaced.")
    output_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive, "x", compression=zipfile.ZIP_DEFLATED) as target:
        for name, data in sorted(content.items()):
            entry = zipfile.ZipInfo(PACKAGE_ROOT + "/" + name, date_time=(2026, 1, 1, 0, 0, 0))
            entry.create_system = 3
            entry.external_attr = (0o100755 if name.endswith((".sh", ".command")) else 0o100644) << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            target.writestr(entry, data)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    with checksums.open("x", encoding="utf-8") as handle:
        handle.write(f"{digest}  {archive.name}\n")
    return archive, checksums


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "Dist")
    parser.add_argument("--revision", default=os.environ.get("GITHUB_SHA", "unversioned-source"))
    args = parser.parse_args()
    for artifact in build_preview(ROOT, args.output, args.revision):
        print(artifact)
