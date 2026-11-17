#!/bin/bash
# PC Security Toolkit - Linux launcher.
# Run it with:  bash "START HERE Linux.sh"   (or make it executable and double-click it)
cd "$(dirname "$0")"
echo "================================================================"
echo "  PC Security Toolkit (Linux)"
echo "  Starting the local server (only this computer can reach it)..."
echo "================================================================"
if command -v python3 >/dev/null 2>&1; then
    python3 "Engine/Mac and Linux Server.py"
else
    echo "Python 3 is needed. Install it with your package manager, for example:"
    echo "  sudo apt install python3      or      sudo dnf install python3"
    read -r -p "Press Enter to exit..."
fi
