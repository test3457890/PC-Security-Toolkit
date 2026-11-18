#!/usr/bin/env python3
"""
Mac and Linux Server.py - PC Security Toolkit v3.1 local server for macOS and Linux.

Binds to loopback with per-run API tokens and a scan-only request policy.
Uses port 8765, or an available ephemeral port. Loopback does not protect against
a compromised host or privileged browser extensions.

macOS checks: FileVault, Firewall + Stealth Mode, Gatekeeper, SIP, LaunchAgents.
Linux checks: firewall (ufw/firewalld/nftables), LUKS disk encryption, Secure Boot,
SSH server, automatic security updates, autostart apps.
Both: listening ports, outbound connections, big downloads and extension metadata.
Legacy modification/export helpers remain in source but are denied by Guest Mode.
"""

import datetime
import glob
import http.server
import json
import os
import platform as pyplatform
import re
import secrets
import shutil
import socket
import socketserver
import subprocess
import threading
import webbrowser

IS_MAC = pyplatform.system() == "Darwin"
PLATFORM = "macOS" if IS_MAC else "Linux"
ENGINE_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(ENGINE_DIR)
HOST = socket.gethostname().split(".")[0] or "computer"
CONFIG_DIR = os.path.join(ROOT_DIR, "Config")
SETTINGS_FILE = os.path.join(CONFIG_DIR, "settings.json")
REPORTS_DIR = os.path.join(ROOT_DIR, "Reports")
LOG_DIR = os.path.join(ROOT_DIR, "Logs", HOST)
TOKEN = secrets.token_hex(32)
PORT = 8765
ALLOWED_HOSTS = set()
SCAN_CONSENTED = False
GUEST_ROUTES = {
    "/api/settings": "GET", "/api/session": "GET", "/api/consent": "POST",
    "/api/scan": "GET", "/api/shutdown": "POST",
}


def guest_decision(path, method, consented):
    if path not in GUEST_ROUTES:
        return 403, "guest_read_only"
    if method != GUEST_ROUTES[path]:
        return 405, "method_not_allowed"
    if path == "/api/scan" and not consented:
        return 409, "consent_required"
    return 200, "allowed"

KNOWN_RISKY = {
    "amnbcmdbanbkjhnfoeceemmmdiepnbpp": "Honey (Coupon/Cookie Tracker)",
    "pefhciejnkgdgoahgfeklebcbpmhnhhd": "Coupert (Coupon/Cookie Tracker)",
    "klekeajafkkpokaofllcadenjdckhinm": "McAfee Web Boost",
    "fheoggkfdfchfphceeifdbepaooicaho": "McAfee WebAdvisor",
    "cjboohgkgchdnfnjiaggdbkdmpieoagi": "PDF Editor for Docs",
}


# ---------------------------------------------------------------------------
# Activity log: Logs/<computer>/toolkit <date>.log (kept 30 days)
# ---------------------------------------------------------------------------
def write_log(level, message):
    # Guest Mode never persists toolkit logs.
    return


def prune_logs():
    # Existing logs belong to prior sessions; do not delete them.
    return


def run_cmd(cmd, timeout=6):
    try:
        out = subprocess.check_output(cmd, shell=True, stderr=subprocess.DEVNULL, text=True, timeout=timeout)
        return out.strip()
    except Exception:
        return ""


# ---------------------------------------------------------------------------
# Shared pieces
# ---------------------------------------------------------------------------
def disk_and_ram():
    du = shutil.disk_usage("/")
    disk = (round(du.free / 1024 ** 3, 2), round(du.total / 1024 ** 3, 2), round(du.free / du.total * 100, 1))
    total_ram = free_ram = 0.0
    if IS_MAC:
        total_ram = round(int(run_cmd("sysctl -n hw.memsize") or 0) / 1024 ** 3, 2)
        vm = run_cmd("vm_stat")
        page = 16384 if "page size of 16384" in vm else 4096
        pages = 0
        for line in vm.splitlines():
            if "Pages free:" in line or "Pages inactive:" in line:
                try:
                    pages += int(line.split(":")[1].strip().rstrip("."))
                except ValueError:
                    pass
        free_ram = round(pages * page / 1024 ** 3, 2)
    else:
        try:
            info = dict(re.findall(r"^(\w+):\s+(\d+)", open("/proc/meminfo").read(), re.M))
            total_ram = round(int(info.get("MemTotal", 0)) / 1024 ** 2, 2)
            free_ram = round(int(info.get("MemAvailable", 0)) / 1024 ** 2, 2)
        except Exception:
            pass
    return disk, total_ram, free_ram


def large_downloads():
    out = []
    d = os.path.expanduser("~/Downloads")
    if os.path.isdir(d):
        for f in os.listdir(d):
            fp = os.path.join(d, f)
            if os.path.isfile(fp) and os.path.getsize(fp) >= 100 * 1024 ** 2:
                out.append({"Name": f, "Type": "File", "SizeGB": round(os.path.getsize(fp) / 1024 ** 3, 2)})
    return sorted(out, key=lambda x: x["SizeGB"], reverse=True)[:12]


def risky_extensions(paths):
    found = []
    for bname, bpath in paths:
        full = os.path.expanduser(bpath)
        if os.path.isdir(full):
            for ext_id in os.listdir(full):
                if ext_id in KNOWN_RISKY:
                    found.append({"Browser": bname, "Id": ext_id, "Name": KNOWN_RISKY[ext_id]})
    return found


def lsof_ports():
    listening, seen = [], set()
    for line in run_cmd("lsof -nP -iTCP -sTCP:LISTEN").splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 9 and ":" in parts[8]:
            ip, port_s = parts[8].rsplit(":", 1)
            if ip not in ("127.0.0.1", "[::1]") and port_s.isdigit() and int(port_s) not in seen:
                seen.add(int(port_s))
                listening.append({"LocalAddress": ip, "LocalPort": int(port_s), "Process": parts[0]})
    outbound, seen_out = [], set()
    for line in run_cmd("lsof -nP -iTCP -sTCP:ESTABLISHED | head -n 60").splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 9 and "->" in parts[8]:
            remote = parts[8].split("->", 1)[1]
            if not remote.startswith("127.0.0.1") and parts[0] not in seen_out:
                seen_out.add(parts[0])
                rip, rport = remote.rsplit(":", 1) if ":" in remote else (remote, "")
                outbound.append({"RemoteAddress": rip, "RemotePort": rport, "Process": parts[0]})
    return listening, outbound


def ss_ports():
    """Linux: use `ss` (no root needed; process names show for your own programs)."""
    def proc_of(text):
        m = re.search(r'users:\(\("([^"]+)"', text)
        return m.group(1) if m else "system"
    listening, seen = [], set()
    for line in run_cmd("ss -tlnpH").splitlines():
        parts = line.split()
        if len(parts) >= 4 and ":" in parts[3]:
            ip, port_s = parts[3].rsplit(":", 1)
            ip = ip.strip("[]")
            if not ip.startswith("127.") and ip != "::1" and port_s.isdigit() and int(port_s) not in seen:
                seen.add(int(port_s))
                listening.append({"LocalAddress": ip, "LocalPort": int(port_s), "Process": proc_of(line)})
    outbound, seen_out = [], set()
    for line in run_cmd("ss -tnpH state established").splitlines()[:80]:
        parts = line.split()
        if len(parts) >= 4 and ":" in parts[3]:
            rip, rport = parts[3].rsplit(":", 1)
            proc = proc_of(line)
            if not rip.strip("[]").startswith("127.") and proc not in seen_out:
                seen_out.add(proc)
                outbound.append({"RemoteAddress": rip.strip("[]"), "RemotePort": rport, "Process": proc})
    return listening, outbound[:25]


def result(os_name, score, findings, controls, startup, listening, outbound, caches, exts, integrity_ok):
    (free_gb, total_gb, free_pct), total_ram, free_ram = disk_and_ram()
    return {
        "platform": PLATFORM, "hostname": HOST, "user": os.environ.get("USER", "user"), "os": os_name,
        "lastBoot": run_cmd("uptime -p") or run_cmd("uptime | sed 's/.*up //' | cut -d',' -f1") or "Active",
        "score": max(0, score), "freeGB": free_gb, "totalGB": total_gb, "freePct": free_pct,
        "freeRAM": free_ram, "totalRAM": total_ram, "startupItems": startup,
        "listeningPorts": listening, "outboundConns": outbound, "largeDownloads": large_downloads(),
        "caches": caches, "riskyExts": exts, "ifeoHijacks": [], "stickyKeysClean": integrity_ok,
        "hitmanProAvailable": False, "ollamaAvailable": False, "wifi": None, "patchDays": None,
        "controls": controls, "findings": findings,
    }


def low_disk_finding(findings):
    (free_gb, _, free_pct), _, _ = disk_and_ram()
    if free_pct < 10:
        findings.append({"severity": "CRITICAL", "title": f"Low disk space ({free_gb} GB / {free_pct}% free)", "fix": "Empty the Trash, clear caches and remove big Downloads."})
        return 20
    return 0


# ---------------------------------------------------------------------------
# macOS scan
# ---------------------------------------------------------------------------
def invoke_mac_scan():
    fw = "enabled" in run_cmd("/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate").lower()
    stealth = "enabled" in run_cmd("/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode").lower()
    fv = "FileVault is On" in run_cmd("fdesetup status")
    gk = "assessments enabled" in run_cmd("spctl --status")
    sip = "enabled" in run_cmd("csrutil status").lower()
    listening, outbound = lsof_ports()
    startup = []
    for folder in [os.path.expanduser("~/Library/LaunchAgents"), "/Library/LaunchAgents", "/Library/LaunchDaemons"]:
        if os.path.isdir(folder):
            startup += [{"Name": f[:-6], "Command": os.path.join(folder, f)} for f in sorted(os.listdir(folder)) if f.endswith(".plist")]
    caches = [{"Name": n, "Key": p, "SizeGB": None, "Cleanable": False}
              for n, p in [("User caches (~/Library/Caches)", "~/Library/Caches"), ("npm cache (~/.npm)", "~/.npm"), ("Trash", "~/.Trash")]
              if os.path.exists(os.path.expanduser(p))]
    exts = risky_extensions([("Chrome", "~/Library/Application Support/Google/Chrome/Default/Extensions"),
                             ("Edge", "~/Library/Application Support/Microsoft Edge/Default/Extensions")])
    score, findings = 100, []
    score -= low_disk_finding(findings)
    checks = [
        (fw, 15, "HIGH", "macOS Firewall is OFF", "System Settings > Network > Firewall > ON (and turn on Stealth Mode)."),
        (fv, 15, "HIGH", "FileVault disk encryption is OFF", "System Settings > Privacy & Security > FileVault > Turn On."),
        (gk, 15, "CRITICAL", "Gatekeeper is disabled", "Run 'sudo spctl --master-enable' to block unsigned apps."),
        (sip, 15, "CRITICAL", "System Integrity Protection is OFF", "Boot into macOS Recovery and run 'csrutil enable'."),
    ]
    for ok, pts, sev, title, fix in checks:
        if not ok:
            score -= pts
            findings.append({"severity": sev, "title": title, "fix": fix})
    if exts:
        score -= 5
        findings.append({"severity": "MEDIUM", "title": f"{len(exts)} tracking browser extensions found", "fix": "Remove Honey, Coupert or McAfee extensions."})
    controls = {"gatekeeper": gk, "firewall": fw, "stealth": stealth, "filevault": fv, "sip": sip}
    return result("macOS " + run_cmd("sw_vers -productVersion"), score, findings, controls, startup, listening, outbound, caches, exts, sip)


# ---------------------------------------------------------------------------
# Linux scan
# ---------------------------------------------------------------------------
def svc_active(*names):
    return any(run_cmd(f"systemctl is-active {n} 2>/dev/null") == "active" for n in names)


def linux_os_name():
    try:
        info = dict(re.findall(r'^(\w+)="?([^"\n]*)"?', open("/etc/os-release").read(), re.M))
        return info.get("PRETTY_NAME", "Linux")
    except Exception:
        return "Linux"


def linux_secure_boot():
    for f in glob.glob("/sys/firmware/efi/efivars/SecureBoot-*"):
        try:
            return open(f, "rb").read()[-1] == 1
        except Exception:
            pass
    return "enabled" in run_cmd("mokutil --sb-state").lower()


def invoke_linux_scan():
    firewall = svc_active("ufw", "firewalld") or "Status: active" in run_cmd("ufw status 2>/dev/null")
    encryption = "crypt" in run_cmd("lsblk -no TYPE 2>/dev/null")
    secure_boot = linux_secure_boot()
    ssh_on = svc_active("ssh", "sshd")
    auto_updates = svc_active("unattended-upgrades", "dnf-automatic.timer", "dnf-automatic-install.timer") or \
        bool(glob.glob("/etc/apt/apt.conf.d/*unattended-upgrades")) and "1" in run_cmd("grep -h Unattended-Upgrade /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null")
    listening, outbound = ss_ports() if shutil.which("ss") else lsof_ports()
    startup = []
    for folder in [os.path.expanduser("~/.config/autostart"), "/etc/xdg/autostart"]:
        if os.path.isdir(folder):
            startup += [{"Name": f[:-8], "Command": os.path.join(folder, f)} for f in sorted(os.listdir(folder)) if f.endswith(".desktop")]
    for line in run_cmd("systemctl --user list-unit-files --state=enabled --no-legend 2>/dev/null").splitlines():
        if line.split():
            startup.append({"Name": line.split()[0], "Command": "systemd user service"})
    caches = [{"Name": n, "Key": p, "SizeGB": None, "Cleanable": False}
              for n, p in [("User cache (~/.cache)", "~/.cache"), ("Trash", "~/.local/share/Trash"), ("npm cache (~/.npm)", "~/.npm")]
              if os.path.exists(os.path.expanduser(p))]
    exts = risky_extensions([("Chrome", "~/.config/google-chrome/Default/Extensions"),
                             ("Edge", "~/.config/microsoft-edge/Default/Extensions"),
                             ("Chromium", "~/.config/chromium/Default/Extensions")])
    score, findings = 100, []
    score -= low_disk_finding(findings)
    checks = [
        (firewall, 15, "HIGH", "No firewall is running", "Ubuntu/Mint: run 'sudo ufw enable'. Fedora: 'sudo systemctl enable --now firewalld'."),
        (encryption, 10, "MEDIUM", "The disk is not encrypted (no LUKS)", "Files can be read if the laptop is stolen. Encryption is chosen when installing Linux."),
        (not ssh_on, 10, "MEDIUM", "An SSH server is running", "If you don't log in remotely: 'sudo systemctl disable --now ssh'."),
        (auto_updates, 10, "HIGH", "Automatic security updates are off", "Ubuntu/Debian: 'sudo apt install unattended-upgrades'. Fedora: install dnf-automatic."),
        (secure_boot, 5, "LOW", "Secure Boot is off", "Turn it on in the UEFI/BIOS settings if your distribution supports it."),
    ]
    for ok, pts, sev, title, fix in checks:
        if not ok:
            score -= pts
            findings.append({"severity": sev, "title": title, "fix": fix})
    risky = [p for p in listening if p["LocalPort"] in (21, 23, 139, 445, 3306, 3389, 5432, 5900, 6379, 27017)]
    if risky:
        score -= 15
        findings.append({"severity": "CRITICAL", "title": "Risky listening ports: " + ", ".join(f"{p['LocalPort']} ({p['Process']})" for p in risky), "fix": "Stop the service or block it with the firewall."})
    if exts:
        score -= 5
        findings.append({"severity": "MEDIUM", "title": f"{len(exts)} tracking browser extensions found", "fix": "Remove Honey, Coupert or McAfee extensions."})
    controls = {"firewall": firewall, "encryption": encryption, "secureBoot": secure_boot, "sshOff": not ssh_on, "autoUpdates": auto_updates}
    return result(linux_os_name(), score, findings, controls, startup, listening, outbound, caches, exts, True)


# ---------------------------------------------------------------------------
# iPad / iPhone over USB
# ---------------------------------------------------------------------------
def invoke_mobile_scan():
    if IS_MAC:
        usb = run_cmd("system_profiler SPUSBDataType 2>/dev/null", timeout=10)
        names = sorted(set(re.findall(r"^\s+(iPad[^\n:]*|iPhone[^\n:]*|iPod[^\n:]*):\s*$", usb, re.M)))
    else:
        names = sorted(set(m.strip() for m in re.findall(r"ID 05ac:\w{4}\s+(.*)", run_cmd("lsusb 2>/dev/null"))))
    joined = " ".join(names)
    kind = "iPad" if "iPad" in joined else "iPhone" if "iPhone" in joined else "Apple device"
    tools = bool(shutil.which("ideviceinfo"))
    apple = {"usbConnected": bool(names), "kind": kind, "usbNames": names, "bluetoothOnly": False, "bluetoothNames": [],
             "appleDriver": True, "appleDriverRunning": True, "toolsFound": tools, "toolsBlocked": False,
             "trusted": False, "status": f"{kind} connected over USB" if names else "No iPad or iPhone found on USB",
             "info": None, "apps": [], "findings": []}
    if names and not tools:
        apple["status"] += " (basic mode - install libimobiledevice for the full scan: " + ("'brew install libimobiledevice'" if IS_MAC else "'sudo apt install libimobiledevice-utils usbmuxd'") + ")"
    if names and tools:
        info = dict(re.findall(r"^(\w+):\s?(.*)$", run_cmd("ideviceinfo", timeout=8), re.M))
        if info:
            ver = info.get("ProductVersion", "")
            apple.update(trusted=True, status=f"{info.get('DeviceName', kind)} connected and trusted")
            apple["info"] = {"name": info.get("DeviceName"), "model": info.get("ProductType"), "ios": ver,
                             "build": info.get("BuildVersion"), "passcode": info.get("PasswordProtected") == "true",
                             "serialEnd": info.get("SerialNumber", "")[-4:], "backupEncrypted": None, "udid": info.get("UniqueDeviceID", "")}
            if info.get("PasswordProtected") != "true":
                apple["findings"].append({"severity": "CRITICAL", "title": "No passcode is set", "fix": "Settings > Face ID & Passcode > Turn Passcode On."})
            try:
                if int(ver.split(".")[0]) < 26:
                    apple["findings"].append({"severity": "HIGH", "title": f"iPadOS/iOS {ver} is out of date", "fix": "Settings > General > Software Update."})
            except ValueError:
                pass
        else:
            apple["status"] = f"Unlock the {kind} and tap 'Trust This Computer', then scan again"
    return {"android": {"available": bool(shutil.which("adb")), "connected": False, "status": "Android scanning is Windows-only for now", "apps": []},
            "apple": apple, "adbAvailable": bool(shutil.which("adb"))}


def read_settings():
    try:
        with open(SETTINGS_FILE, encoding="utf-8-sig") as f:
            return json.load(f)
    except Exception:
        return {}


SAFE_LOG = re.compile(r"^[^/\\:*?\"<>|]+\.log$")


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def send_json(self, obj, status=200):
        data = json.dumps(obj).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)
        if isinstance(obj, dict) and "message" in obj:
            write_log("INFO" if obj.get("ok") else "WARN", f"{self.path}: {obj['message']}")

    def guard(self):
        if self.headers.get("Host") not in ALLOWED_HOSTS:
            self.send_response(403)
            self.end_headers()
            return False
        if self.path.startswith("/api/") and self.headers.get("X-Toolkit-Token") != TOKEN:
            self.send_json({"ok": False, "message": "Missing or wrong toolkit token. Reload the page."}, 403)
            return False
        origin = self.headers.get("Origin")
        expected_origin = f"http://127.0.0.1:{self.server.server_address[1]}"
        if origin and origin != expected_origin:
            self.send_json({"ok": False, "code": "origin_denied", "message": "Origin denied."}, 403)
            return False
        if self.command == "POST" and not origin:
            self.send_json({"ok": False, "code": "origin_required", "message": "Same-origin browser request required."}, 403)
            return False
        if self.path.startswith("/api/"):
            status, code = guest_decision(self.path, self.command, SCAN_CONSENTED)
            if status != 200:
                self.send_json({"ok": False, "code": code, "message": "Scan only. Confirm permission before scanning. Changes and persistent data are unavailable in this preview."}, status)
                return False
        return True

    def do_GET(self):
        if not self.guard():
            return
        try:
            if self.path in ("/", "/index.html"):
                with open(os.path.join(ENGINE_DIR, "Guest Dashboard.html"), "r", encoding="utf-8") as f:
                    data = f.read().replace("%%TOOLKIT-TOKEN%%", TOKEN).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Cache-Control", "no-store")
                self.send_header("X-Frame-Options", "DENY")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            elif self.path == "/api/scan":
                scan = invoke_mac_scan() if IS_MAC else invoke_linux_scan()
                write_log("INFO", f"Scan finished: score {scan['score']}/100, {len(scan['findings'])} issue(s): " + "; ".join(f"[{f['severity']}] {f['title']}" for f in scan["findings"]))
                self.send_json(scan)
            elif self.path == "/api/settings":
                self.send_json({"theme": "midnight", "platform": PLATFORM, "mode": "guest", "persistence": False, "modification": False})
            elif self.path == "/api/session":
                self.send_json({"mode": "guest", "consented": SCAN_CONSENTED, "persistence": False, "modification": False,
                                "usbModes": {"portable": "preview", "secureSession": "planned", "disposableWorkspace": "planned"}})
            elif self.path == "/api/mobile-scan":
                self.send_json(invoke_mobile_scan())
            elif self.path == "/api/logs":
                files = sorted(glob.glob(os.path.join(LOG_DIR, "*.log")), key=os.path.getmtime, reverse=True)[:60]
                self.send_json({"files": [{"name": os.path.basename(f), "sizeKB": -(-os.path.getsize(f) // 1024),
                                           "modified": datetime.datetime.fromtimestamp(os.path.getmtime(f)).isoformat(timespec="seconds")} for f in files],
                                "folder": f"Logs/{HOST}"})
            elif self.path.startswith("/api/"):
                self.send_json({"ok": False, "message": f"This part of the toolkit is Windows-only."})
            else:
                self.send_response(404)
                self.end_headers()
        except Exception as e:
            write_log("ERROR", f"{self.path} failed: {e}")
            self.send_json({"ok": False, "message": f"Server error: {e}"}, 500)

    def do_POST(self):
        global SCAN_CONSENTED
        if not self.guard():
            return
        try:
            length = int(self.headers.get("Content-Length", "-1"))
        except ValueError:
            length = -1
        if length < 0 or length > 4096 or self.headers.get("Transfer-Encoding"):
            self.send_json({"ok": False, "message": "Known request size of at most 4096 bytes required."}, 413)
            return
        if self.headers.get_content_type() != "application/json":
            self.send_json({"ok": False, "message": "JSON required."}, 415)
            return
        try:
            self.connection.settimeout(10)
            body = json.loads(self.rfile.read(length).decode("utf-8")) if length else {}
            if not isinstance(body, dict):
                raise ValueError("JSON object required")
        except Exception:
            self.send_json({"ok": False, "message": "Invalid JSON request."}, 400)
            return
        try:
            if self.path == "/api/consent":
                if body.get("authorized") is not True:
                    self.send_json({"ok": False, "message": "Permission to inspect this device is required."}, 400)
                    return
                SCAN_CONSENTED = True
                self.send_json({"ok": True, "message": "Read-only scan authorized for this toolkit session."})
            elif self.path == "/api/settings":
                theme = str(body.get("theme", "midnight"))
                if not re.fullmatch(r"[a-z]{2,20}", theme):
                    theme = "midnight"
                os.makedirs(CONFIG_DIR, exist_ok=True)
                with open(SETTINGS_FILE, "w", encoding="utf-8") as f:
                    json.dump({"theme": theme}, f)
                self.send_json({"ok": True})
            elif self.path == "/api/log-read":
                name = str(body.get("file", ""))
                path = os.path.join(LOG_DIR, name)
                if not SAFE_LOG.match(name) or not os.path.isfile(path):
                    self.send_json({"ok": False, "text": "Log not found."})
                else:
                    with open(path, encoding="utf-8", errors="replace") as f:
                        self.send_json({"ok": True, "text": "".join(f.readlines()[-500:])})
            elif self.path == "/api/client-log":
                write_log("BROWSER", str(body.get("message", ""))[:600])
                self.send_json({"ok": True})
            elif self.path == "/api/save-report":
                html = str(body.get("html", ""))
                if len(html) > 5 * 1024 * 1024:
                    self.send_json({"ok": False, "message": "Report too large."})
                    return
                os.makedirs(REPORTS_DIR, exist_ok=True)
                name = f"{HOST} report {datetime.datetime.now():%Y-%m-%d %H-%M}.html"
                with open(os.path.join(REPORTS_DIR, name), "w", encoding="utf-8") as f:
                    f.write(html)
                self.send_json({"ok": True, "message": f"Report saved to Reports/{name}"})
            elif self.path == "/api/open":
                what = body.get("what")
                folder = {"reports": REPORTS_DIR, "logs": LOG_DIR}.get(what)
                if folder:
                    os.makedirs(folder, exist_ok=True)
                    subprocess.Popen(["open" if IS_MAC else "xdg-open", folder], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    self.send_json({"ok": True, "message": "Opened."})
                else:
                    self.send_json({"ok": False, "message": "That one is Windows-only."})
            elif self.path == "/api/shutdown":
                self.send_json({"ok": True, "message": "Server stopped cleanly."})
                threading.Thread(target=self.server.shutdown, daemon=True).start()
            else:
                self.send_json({"ok": False, "message": "This action is Windows-only. The scan, reports, logs and checklists work here."})
        except Exception as e:
            write_log("ERROR", f"{self.path} failed: {e}")
            self.send_json({"ok": False, "message": f"Server error: {e}"}, 500)


def open_server():
    """Port 8765, or a random free port if it's busy. Always 127.0.0.1 only."""
    socketserver.TCPServer.allow_reuse_address = True
    for port in [8765, 0, 0, 0]:
        try:
            return socketserver.ThreadingTCPServer(("127.0.0.1", port), Handler)
        except OSError:
            continue
    raise SystemExit("Could not open a local port. Restart the computer and try again.")


if __name__ == "__main__":
    prune_logs()
    httpd = open_server()
    PORT = httpd.server_address[1]
    ALLOWED_HOSTS.update({f"127.0.0.1:{PORT}", f"localhost:{PORT}"})
    url = f"http://127.0.0.1:{PORT}/"
    write_log("INFO", f"Toolkit started on {url} ({PLATFORM}, Python {pyplatform.python_version()})")
    print(f"PC Security Toolkit ({PLATFORM}) running at {url}")
    print("Keep this window open while you use the dashboard. Press Ctrl+C to stop.")
    try:
        webbrowser.open(url)
    except Exception:
        pass
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        write_log("INFO", "Toolkit stopped")
        httpd.server_close()
