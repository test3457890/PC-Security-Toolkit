"""Exercise real HTTP handlers with fixture scans. No host security commands run."""
import ast
import http.client
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import tempfile
import threading
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("toolkit", ROOT / "Engine/Mac and Linux Server.py")
toolkit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(toolkit)


class GuestHTTPTests(unittest.TestCase):
    def setUp(self):
        toolkit.SCAN_CONSENTED = False
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.path_patches = [patch.object(toolkit, name, str(self.root / name))
                             for name in ("LOG_DIR", "CONFIG_DIR", "REPORTS_DIR", "SETTINGS_FILE")]
        for mocked in self.path_patches:
            mocked.start()
        self.scan = patch.object(toolkit, "invoke_linux_scan", return_value={
            "score": 42, "findings": [], "hostname": "fixture"})
        self.scan_mock = self.scan.start()
        self.mac_scan = patch.object(toolkit, "invoke_mac_scan", return_value={
            "score": 42, "findings": [], "hostname": "fixture"})
        self.mac_mock = self.mac_scan.start()
        self.server = toolkit.socketserver.ThreadingTCPServer(("127.0.0.1", 0), toolkit.Handler)
        self.server.daemon_threads = True
        self.port = self.server.server_address[1]
        toolkit.ALLOWED_HOSTS = {f"127.0.0.1:{self.port}"}
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=3)
        self.scan.stop()
        self.mac_scan.stop()
        for mocked in self.path_patches:
            mocked.stop()
        self.temp.cleanup()

    def request(self, path, method="GET", body=None, headers=None):
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=3)
        all_headers = {"X-Toolkit-Token": toolkit.TOKEN, "Origin": f"http://127.0.0.1:{self.port}",
                       "Content-Type": "application/json"}
        all_headers.update(headers or {})
        connection.request(method, path, body=body, headers=all_headers)
        response = connection.getresponse()
        status, data = response.status, response.read()
        connection.close()
        return status, data

    def test_consent_before_scan(self):
        self.assertEqual(self.request("/api/scan")[0], 409)
        self.scan_mock.assert_not_called()
        self.mac_mock.assert_not_called()
        self.assertEqual(self.request("/api/consent", "POST", '{"authorized":false}')[0], 400)
        self.assertEqual(self.request("/api/consent", "POST", '{"authorized":true}')[0], 200)
        self.assertEqual(self.request("/api/scan")[0], 200)

    def test_all_existing_mutation_routes_denied(self):
        sources = (ROOT / "Engine/Toolkit Server.ps1").read_text(encoding="utf-8")
        routes = set(re.findall(r"'(/api/[^']+)'\s*\{", sources))
        blocked = routes - set(toolkit.GUEST_ROUTES)
        self.assertIn("/api/family-apply", blocked)
        self.assertIn("/api/execute", blocked)
        for route in blocked:
            for method in ("GET", "POST"):
                with self.subTest(route=route, method=method):
                    self.assertEqual(self.request(route, method, '{"script":"do not execute"}')[0], 403)
        self.assertEqual(self.request("/api/settings", "POST", '{"theme":"light"}')[0], 405)
        self.assertEqual(list(self.root.rglob("*")), [])

    def test_token_host_origin_and_methods(self):
        self.assertEqual(self.request("/api/session", headers={"X-Toolkit-Token": "wrong"})[0], 403)
        self.assertEqual(self.request("/api/session", headers={"Host": "evil.example"})[0], 403)
        self.assertEqual(self.request("/api/session", headers={"Origin": "https://evil.example"})[0], 403)
        self.assertEqual(self.request("/api/session", headers={"Origin": "null"})[0], 403)
        self.assertEqual(self.request("/api/consent", "POST", '{}', {"Origin": ""})[0], 403)
        self.assertEqual(self.request("/api/scan", "POST", '{}')[0], 405)
        self.assertEqual(self.request("/api/shutdown", "GET")[0], 405)

    def test_bounded_json(self):
        self.assertEqual(self.request("/api/consent", "POST", 'x' * 4097)[0], 413)
        self.assertEqual(self.request("/api/consent", "POST", '{}', {"Transfer-Encoding": "chunked"})[0], 413)
        self.assertEqual(self.request("/api/consent", "POST", '{')[0], 400)
        self.assertEqual(self.request("/api/consent", "POST", '[]')[0], 400)
        self.assertEqual(self.request("/api/consent", "POST", '{}', {"Content-Type": "text/plain"})[0], 415)

    def test_no_automatic_persistence_and_no_pruning(self):
        logs = self.root / "LOG_DIR"
        logs.mkdir()
        existing = logs / "old.log"
        existing.write_text("preserve me")
        toolkit.write_log("INFO", "do not save")
        toolkit.prune_logs()
        self.assertEqual(existing.read_text(encoding="utf-8"), "preserve me")
        self.assertEqual(list(logs.iterdir()), [existing])
        status, data = self.request("/api/settings")
        self.assertEqual(status, 200)
        self.assertFalse(json.loads(data)["persistence"])
        self.assertFalse((self.root / "CONFIG_DIR").exists())

    def test_new_dashboard_has_no_automatic_scan_or_storage(self):
        status, data = self.request("/")
        self.assertEqual(status, 200)
        self.assertIn(b"Three separate USB roles", data)
        self.assertNotIn(b"%%TOOLKIT-TOKEN%%", data)
        self.assertNotIn(b"localStorage", data)
        self.assertNotIn(b"sessionStorage", data)
        self.scan_mock.assert_not_called()
        self.mac_mock.assert_not_called()

    def test_shutdown(self):
        self.assertEqual(self.request("/api/shutdown", "POST", '{}')[0], 200)
        self.thread.join(timeout=3)
        self.assertFalse(self.thread.is_alive())


class SyntaxTests(unittest.TestCase):
    def test_restricted_export_and_consent_ui(self):
        html = (ROOT / "Engine/Guest Dashboard.html").read_text(encoding="utf-8")
        script = re.findall(r"<script(?:\s[^>]*)?>(.*?)</script>", html, re.S | re.I)[0]
        harness = r'''
const vm = require('node:vm');
const assert = require('node:assert/strict');
const nodes = new Map();
const node = id => {
  if (!nodes.has(id)) nodes.set(id,{checked:false,value:'',hidden:false,textContent:'',
    addEventListener(event,fn){this[event]=fn;},replaceChildren(){},append(){},click(){}});
  return nodes.get(id);
};
let captured;
const calls=[];
const fixture={hostname:'PRIVATE HOST',user:'PRIVATE USER',score:1,
  findings:[{severity:'HIGH',title:'PRIVATE SSID',fix:'PRIVATE PATH'}]};
const context={document:{querySelector:()=>({content:'fixture-token'}),getElementById:node,
  documentElement:{dataset:{}},createElement:()=>node('temporary')},
  fetch:async(path)=>{calls.push(path);return {ok:true,json:async()=>path==='/api/scan'?fixture:{ok:true}};},
  confirm:()=>true,Blob:class{constructor(parts){captured=JSON.parse(parts.join(''));}},
  URL:{createObjectURL:()=> 'blob:fixture',revokeObjectURL(){}},setTimeout:()=>{},console};
vm.createContext(context);
vm.runInContext(SOURCE,context);
(async()=>{
  assert.equal(calls.length,0,'dashboard must not scan on load');
  await node('scan').click();
  assert.equal(calls.length,0,'missing consent must not send requests');
  node('permission').checked=true;
  await node('scan').click();
  assert.deepEqual(calls,['/api/consent','/api/scan']);
  node('redact').checked=true;
  node('export').click();
  const serialized=JSON.stringify(captured);
  assert(!serialized.includes('PRIVATE'),'restricted summary must omit identifier-bearing text');
  assert.equal(captured.findings[0].severity,'HIGH');
  node('redact').checked=false;
  node('export').click();
  assert.equal(captured.evidence.hostname,'PRIVATE HOST');
  await node('stop').click();
  assert.equal(calls.at(-1),'/api/shutdown');
  assert.equal(node('evidence').textContent,'');
})().catch(error=>{console.error(error);process.exitCode=1;});
'''
        source = "const SOURCE=" + json.dumps(script) + ";\n" + harness
        result = subprocess.run(["node"], input=source, text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_python_and_javascript_syntax(self):
        ast.parse((ROOT / "Engine/Mac and Linux Server.py").read_text(encoding="utf-8"))
        html = (ROOT / "Engine/Guest Dashboard.html").read_text(encoding="utf-8")
        scripts = re.findall(r"<script(?:\s[^>]*)?>(.*?)</script>", html, re.S | re.I)
        self.assertEqual(len(scripts), 1)
        for script in scripts:
            result = subprocess.run(["node", "--check", "--input-type=commonjs"], input=script,
                                    text=True, capture_output=True, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
