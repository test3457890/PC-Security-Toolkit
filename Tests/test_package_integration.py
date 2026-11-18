"""Test the built ZIP and real scan-only server startup without scanning host settings."""
import hashlib
import http.client
import importlib.util
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import tempfile
import time
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("preview_builder", ROOT / "Build Preview.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class PackageTests(unittest.TestCase):
    def test_complete_reproducible_package_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            first, sums = builder.build_preview(ROOT, directory / "first")
            second, _ = builder.build_preview(ROOT, directory / "second")
            self.assertEqual(first.read_bytes(), second.read_bytes())
            before = first.read_bytes()
            with self.assertRaises(FileExistsError):
                builder.build_preview(ROOT, directory / "first")
            self.assertEqual(first.read_bytes(), before)
            self.assertTrue(sums.read_text().startswith(hashlib.sha256(before).hexdigest()))
            with zipfile.ZipFile(first) as archive:
                self.assertIsNone(archive.testzip())
                names = archive.namelist()
                self.assertFalse(any(name.endswith((".exe", ".dll")) or "/Profiles/" in name or "RECOVERY MODE" in name for name in names))
                self.assertTrue(all(name.startswith("PC Security Toolkit/") and ".." not in Path(name).parts for name in names))
                manifest = json.loads(archive.read("PC Security Toolkit/PACKAGE CONTENTS.json"))
                self.assertEqual(len(manifest["files"]) + 1, len(names))
                for item in manifest["files"]:
                    data = archive.read("PC Security Toolkit/" + item["path"])
                    self.assertEqual(hashlib.sha256(data).hexdigest(), item["sha256"])
                    self.assertEqual(len(data), item["size_bytes"])

    def test_missing_input_fails_before_output(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            with self.assertRaises(FileNotFoundError):
                builder.build_preview(directory, directory / "output")
            self.assertFalse((directory / "output").exists())


class ExtractedStartupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="Toolkit space é ")
        base = Path(self.temp.name)
        archive, _ = builder.build_preview(ROOT, base / "build")
        with zipfile.ZipFile(archive) as source:
            source.extractall(base / "extracted")
        self.folder = base / "extracted/PC Security Toolkit"
        self.before = self.snapshot()
        self.child = None

    def tearDown(self):
        if self.child is not None:
            if self.child.poll() is None:
                self.child.terminate()
            try:
                self.child.communicate(timeout=10)
            except subprocess.TimeoutExpired:
                self.child.kill()
                self.child.communicate(timeout=10)
        self.temp.cleanup()

    def snapshot(self):
        return {str(path.relative_to(self.folder)): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in self.folder.rglob("*") if path.is_file()}

    def command(self, port):
        if os.name == "nt":
            return ["powershell.exe", "-NoProfile", "-NonInteractive", "-File",
                    str(self.folder / "Engine/Toolkit Server.ps1"), "-NoBrowser", "-Port", str(port)]
        return [sys.executable, str(self.folder / "Engine/Mac and Linux Server.py"), "--no-browser", "--port", str(port)]

    def request(self, port, path, token="", body=None):
        connection = http.client.HTTPConnection("127.0.0.1", port, timeout=2)
        headers = {"X-Toolkit-Token": token, "Origin": f"http://127.0.0.1:{port}", "Content-Type": "application/json"}
        connection.request("GET" if body is None else "POST", path, body=body, headers=headers)
        response = connection.getresponse()
        status, data = response.status, response.read()
        connection.close()
        return status, data

    def test_extracted_real_server_consent_denials_and_clean_shutdown(self):
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        self.child = subprocess.Popen(self.command(port), cwd=self.temp.name,
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        deadline = time.monotonic() + 25
        while True:
            try:
                status, page = self.request(port, "/")
                break
            except (OSError, http.client.HTTPException):
                if self.child.poll() is not None:
                    output, errors = self.child.communicate(timeout=3)
                    self.fail(f"Server exited during startup: {output!r} {errors!r}")
                if time.monotonic() >= deadline:
                    self.fail("Extracted server did not start within 25 seconds")
                time.sleep(0.1)
        self.assertEqual(status, 200)
        self.assertIn(b"Three separate USB roles", page)
        token = re.search(rb'name="toolkit-token" content="([a-f0-9]+)"', page).group(1).decode()
        self.assertEqual(self.request(port, "/api/scan", token)[0], 409)
        self.assertEqual(self.request(port, "/api/execute", token, '{"script":"never run this"}')[0], 403)
        self.assertEqual(self.request(port, "/api/clean-caches", token, '{}')[0], 403)
        self.assertEqual(self.request(port, "/api/family-apply", token, '{}')[0], 403)
        self.assertEqual(self.request(port, "/api/recovery-action", token, '{}')[0], 403)
        self.assertEqual(self.request(port, "/api/consent", token, '{"authorized":true}')[0], 200)
        status, data = self.request(port, "/api/session", token)
        self.assertEqual(status, 200)
        self.assertTrue(json.loads(data)["consented"])
        self.assertEqual(self.request(port, "/api/shutdown", token, '{}')[0], 200)
        self.child.communicate(timeout=10)
        self.assertEqual(self.child.returncode, 0)
        self.assertEqual(self.snapshot(), self.before, "Startup/API requests must not write toolkit files")

    def test_missing_dashboard_stops_before_listener(self):
        (self.folder / "Engine/Guest Dashboard.html").unlink()
        result = subprocess.run(self.command(0 if os.name != "nt" else 18765), cwd=self.temp.name,
                                capture_output=True, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"Guest Dashboard.html", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
