#!/bin/bash
cd "$(dirname "$0")"
echo "================================================================"
echo "  PC Security Toolkit (macOS)"
echo "  Starting the local server at http://127.0.0.1:8765/ ..."
echo "================================================================"
chmod +x "$0" 2>/dev/null
if command -v python3 >/dev/null 2>&1; then
    python3 "Engine/Mac and Linux Server.py"
else
    echo "Python 3 is required on macOS. Install it with: xcode-select --install"
    read -p "Press Enter to exit..."
fi
