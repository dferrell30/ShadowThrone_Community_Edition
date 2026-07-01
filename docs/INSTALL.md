# Installation

1. Download the Shadow Throne v1.0 release ZIP.
2. Extract the archive to a trusted local folder.
3. Unblock files if required:

```powershell
Get-ChildItem . -Recurse | Unblock-File
```

4. Start Shadow Throne:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\ShadowThrone.ps1
```

## Updating Tool Runtimes

Replace the relevant folder under `Tools\` with the new validated runtime. Keep the folder name stable unless updating the manifest and Shadow Throne mappings.
