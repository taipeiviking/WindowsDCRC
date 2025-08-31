# WindowsDCRC
Windows Display Configuration Registry Cleaner (Windows DCRC)

## Overview
- Safely view, back up (.reg), and delete stale Windows display configuration records.
- Registry path: HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Configuration
- Tech stack: .NET 8 WPF (C#)

## Features
- Scan both 64-bit and 32-bit registry views; de-duplicate by subkey name.
- Grid columns: Key, SetId, Timestamp (local), Displays, Resolution(s), Position(s), Rotation, Scaling, Refresh Hz.
- Details pane lists every display node (Width, Height, Pos X/Y, Rotation, Scaling, Refresh Hz).
- Backup on delete: before deleting, exports selected/all entries into a single Unicode .reg (standard header once; per-key exports merged).
- Delete from both Registry64 and Registry32 views (Admin required).
- Refresh to re-scan at any time.

## How it works
- Each configuration entry is an immediate subkey under ...\\Configuration.
- Display nodes live under numeric subkeys like "00", "01"; values include:
  - PrimSurfSize.cx, PrimSurfSize.cy (width/height)
  - Position.cx, Position.cy (origin)
  - Details subkey "00": Rotation, Scaling, VSyncFreq.Numerator/Denominator (for Hz)

## Build and run (developer)
Prerequisites: .NET 8 SDK on Windows 10/11.

```powershell
dotnet build
dotnet run
```

Note: the app manifest requests Administrator. Windows will show a UAC prompt on launch.

## Usage
1) Start the app (accept UAC). The grid is auto-populated on load.
2) Optionally select one or more rows.
3) Click "Backup .reg and Delete Selected" (or "Delete All" if nothing is selected). Choose where to save the .reg.
4) Confirm deletion. After deletion, click Refresh to see the current state.
5) To restore, double‑click the saved .reg and accept the UAC prompts; then click Refresh in the app.

## Safety and permissions
- Deletion is guarded by confirmation and requires elevation.
- If a permission or export error occurs, the app shows a clear message.

## Troubleshooting
- Access denied: ensure you launched elevated (UAC) and that security software isn’t blocking registry access.
- Export failed: ensure reg.exe is available, and try saving to a writable location.

## Contributing
Issues and pull requests are welcome. Please keep code explicit and readable, avoid unsafe casts, and handle exceptions with user‑friendly messages.

## License
GPL‑3.0 — see LICENSE.

## Disclaimer
Provided "AS IS" without warranties; use at your own risk. Always make a .reg backup before deleting registry entries.
