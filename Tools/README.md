# Tools folder

The toolkit works without any of these. Each one switches on an extra feature.

| Feature | What to put here | Where to get it |
|---|---|---|
| 🛡️ Run HitmanPro (second-opinion malware scan) | `HitmanPro x64.exe` | Download HitmanPro from the official Sophos website, rename it to `HitmanPro x64.exe` and drop it in this folder. |
| 🤖 Android scanner | `adb\adb.exe`, `adb\AdbWinApi.dll`, `adb\AdbWinUsbApi.dll` | Google's free **SDK Platform-Tools for Windows** (developer.android.com/tools/releases/platform-tools). Copy those three files into an `adb` folder here. |
| 🍎 Full iPad / iPhone scan | `libimobiledevice\` | Already included (open source, LGPL). See `libimobiledevice/ABOUT THESE FILES.txt`. Windows also needs the free **Apple Devices** app from the Microsoft Store. |

HitmanPro and adb are not included in the GitHub copy. They are third-party programs with their own licenses, so download them from the official sites yourself.
