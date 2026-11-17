# PC Security Toolkit

A portable security, privacy and parental-controls dashboard that runs from a USB drive or any folder.
It scans the computer, explains what it finds in plain English, fixes problems with one click,
and can undo every change it makes.

Works on **Windows 10/11** (full features), **macOS** and **Linux** (scanning, reports, logs, checklists).

> **No security tool can promise 100% protection.** Nothing connected to the internet is ever completely
> safe, and this toolkit isn't either. Its job is to make an attacker work a lot harder, and to show you
> what's going on so you can spot trouble early. [Read the full disclaimer.](#disclaimer)

---

## Why I made this

Windows computers are a big target. Most of them run with settings that were chosen for convenience,
not safety: old network features that leak password hashes on public Wi-Fi, remote-access services
nobody uses, browser extensions that track everything, and protections like the firewall or Defender
that can get switched off without anyone noticing. Attackers know those defaults well, and many
break-ins don't need anything clever, just an unlocked door.

Like a lot of people, I've watched the stream of hacks, scams and data leaks in the news and wanted a
bit more peace of mind. Proper security tools are often expensive, confusing, or made for IT
departments. I wanted something anyone could plug in, understand, and use:

- **See it:** a plain-English list of what the computer is protected from, and what it isn't.
- **Fix it:** close the common holes with one click, with a snapshot saved first so every change can be undone.
- **Watch it:** a report and an activity log, so if something odd happens you can see what changed and when.
- **Protect the family:** parental controls, because kids are online earlier than ever.

It won't stop a determined expert with unlimited time, and it doesn't claim to. It's meant to take a
computer from "easy target" to "not worth the trouble". Most attackers go after the easy ones. The aim
is to slow them down long enough for you to notice what's happening and act.

---

## Is it safe? Can people get into my computer through this?

No. The dashboard is a web page, but it is **only reachable from the computer it is running on**:

- The server listens on `127.0.0.1` (localhost), never on your network or the internet. Other devices,
  even on the same Wi-Fi, can't connect to it.
- Every time it starts, it creates a new random 64-character secret. Every request must include that secret,
  so other websites open in your browser can't control it either.
- It uses port 8765, or a random free port if 8765 is busy, and it stops when you close the window.
- Putting the code on GitHub only shares the code. Nobody can reach anyone's computer through GitHub.
- Anything that changes Windows settings needs you to click **Yes** on the Windows admin prompt,
  and a recovery snapshot is saved first.

Don't "port forward" it or put it on a web host. It's designed to run only on your own computer.

---

## Start it

1. Download: green **Code** button > **Download ZIP** (or `git clone`).
2. **Windows only:** before extracting, right-click the ZIP > **Properties** > tick **Unblock** > **OK**.
   (Windows otherwise runs files from internet downloads in a restricted mode. The toolkit tells you if that happens.)
3. Extract it, then double-click the file for your system:

| System | Start the toolkit | If something goes wrong |
|---|---|---|
| Windows | `START HERE Windows.bat` | `RECOVERY MODE Windows.bat` |
| Mac | `START HERE Mac.command` (first time: right-click > Open) | Time Machine / macOS Recovery |
| Linux | `bash "START HERE Linux.sh"` | Timeshift / recovery boot |

If Windows shows "Windows protected your PC", click **More info > Run anyway**. That message appears for
any program that isn't from a big publisher.

Mac and Linux need Python 3 (built into most Linux systems; on Mac run `xcode-select --install`).

---

## Features

| Tab | What it does |
|---|---|
| 📊 Overview & Advisor | Security score, issues found, offline Q&A advisor (uses a local Ollama AI if you have one) |
| 💾 Storage | Cache sizes, old Windows upgrade files, big downloads, one-click safe cleanup |
| 🛡️ Backdoors, Ports & Extensions | Listening ports, programs online, startup apps, login-screen backdoor checks, tracking extensions |
| 🔒 Privacy & Network | Live status of Defender, firewall, UAC, BitLocker, Secure Boot, Wi-Fi spoofing protections and privacy settings |
| ⚙️ Script Builder | Pick a profile (Travel, School, Work, Gaming, Friend PC audit) and run or download the hardening script |
| 📱 iPad, iPhone & Android | USB scan of iPads/iPhones (passcode, iPadOS version, storage, backups, apps) and Android apps |
| 👨‍👩‍👧 Family Plan | Parental controls: block sites in every app, SafeSearch, family DNS filter, blocked search words, sign-in hours, bedtime, parent PIN |
| 🛟 Recovery Mode | Undo any change from a snapshot, back to Windows defaults, System Restore, file repair, network reset, Safe Mode |
| 📄 Reports & Logs | "What you're protected from" report, saved HTML reports, and a full activity log for troubleshooting |

Plus 7 themes: Classic Midnight, Hacker Terminal, Cyberpunk Neon, Retro Amber, Deep Ocean, Daylight and High Contrast.

## Reports and logs

- **Reports/** has saved security reports: what the computer is protected from, what it isn't, issues, ports,
  startup apps and recent activity.
- **Logs/<computer>/** has `toolkit <date>.log` with every action and error, plus a `run ...` / `recovery ...`
  log with the complete output of every script that changed something. Logs older than 30 days are deleted automatically.
- **Backups/<computer>/** holds the recovery snapshots.

These folders contain personal information about the computer, so they're excluded from Git (`.gitignore`).

## Folders

```
Engine/    the toolkit (server, dashboard, recovery engine)
Profiles/  ready-made Windows setup scripts
Tools/     optional helpers: HitmanPro, adb, iPad tools (see Tools/README.md)
Docs/      guides and setup prompts
```

## Disclaimer

**There is no such thing as 100% security.** Any computer connected to the internet can be attacked, and
no tool, including this one, can guarantee that a computer won't be hacked, infected or scammed.

What this toolkit does is **raise the bar**: it closes common weaknesses, makes an attacker work harder and
take longer, and helps you notice when something is wrong so you can act. Treat it as one layer of
protection, not a guarantee. Keep doing the basics too:

- Install Windows, app and phone updates promptly.
- Use strong, unique passwords and a password manager, and turn on two-step sign-in (2FA) wherever you can.
- Keep backups of anything you can't afford to lose, on a drive that isn't always plugged in.
- Be suspicious of unexpected links, attachments, pop-ups and "tech support" calls.
- If you think a computer has been compromised, disconnect it from the internet and get help from a professional.

This toolkit changes security and system settings. Every change saves a snapshot first and can be undone in
Recovery Mode, but you use it at your own risk. Review what a script does (the Script Builder shows the full
script) before running it. It is provided as-is, with no warranty of any kind, and the authors are not
responsible for any damage, data loss or security incident.
