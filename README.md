# Shadow Throne v1.0

**Shadow Throne** is the command and orchestration layer for the Shadow Suite defensive security tool family. It provides a unified Shadow Suite dashboard for launching tools, viewing operational status, indexing reports/logs, and surfacing evidence without merging or modifying the individual tools.

> Preserve the defenders. Improve the castle.

## Included Shadow Suite Runtimes

Shadow Throne v1.0 ships with packaged runtime folders under `Tools\`:

| Knight | Tool | Purpose |
|---|---|---|
| Warrior | Shadow Deploy - Defender for Endpoint | Deploy, validate, back up, and report on Defender for Endpoint settings. |
| Gatekeeper | Shadow Deploy - Defender for Office 365 | Deploy, validate, scope, and report on Defender for Office 365 protections. |
| Trial Master | Shadow Verify | Validate endpoint telemetry, alerts, EDR/ASR behavior, and operational visibility. |
| Hunter | Shadow Trace Ops | Investigate post-authentication activity and surface identity/cloud/XDR findings. |
| Sentinel | Shadow CA | Placeholder for future Conditional Access and access governance module. |

Each tool remains its own runtime and retains its own UI, logic, Graph permissions, assets, reports, logs, KQL/playbooks, and release lifecycle.

Shadow Throne v1.0 GitHub Release Walkthrough
1. Create the GitHub repository

Go to GitHub → New repository

Recommended name:

ShadowThrone

Description:

Shadow Throne v1.0 – Command Center for the Shadow Suite

Choose:

Public or Private
Do not initialize with README if your folder already has one

Create the repo.

2. Prepare your local folder

Use the approved release folder.

Make sure the root looks like:

ShadowThrone
├── ShadowThrone.ps1
├── README.md
├── CHANGELOG.md
├── LICENSE
├── SECURITY.md
├── SHADOW-SUITE-DOCTRINE.md
├── Assets
├── Web
├── Tools
├── Logs
├── Reports
├── Exports
├── Intelligence
└── Imports
3. Upload with GitHub Desktop or web upload

Simplest method:

Open the GitHub repo.
Click Add file.
Click Upload files.
Drag all files/folders from your ShadowThrone folder.
Commit with:
Initial Shadow Throne v1.0 release
4. Command-line upload option

From PowerShell:

cd C:\Path\To\ShadowThrone

git init
git add .
git commit -m "Initial Shadow Throne v1.0 release"
git branch -M main
git remote add origin https://github.com/YOURNAME/ShadowThrone.git
git push -u origin main
5. Create the GitHub release

Go to:

Releases → Create a new release

Tag:

v1.0

Release title:

Shadow Throne v1.0 – Command Center

Release notes:

Initial public release of Shadow Throne, the command and orchestration layer for the Shadow Suite.

Includes:
- Shadow Throne command dashboard
- Packaged runtime support for Shadow Suite tools
- Report intelligence
- Evidence inventory
- Kingdom Status
- Runtime isolation
- Shadow Suite doctrine

Attach the release ZIP.

Publish release.

6. Installation instructions for users

Users should:

Download the release ZIP.
Extract it to:
C:\Tools\ShadowThrone
Unblock files:
Get-ChildItem "C:\Tools\ShadowThrone" -Recurse | Unblock-File
Run:
cd C:\Tools\ShadowThrone
Set-ExecutionPolicy -Scope Process Bypass
.\ShadowThrone.ps1
7. Known issue note

Add this to README or release notes:

Known Issue:
The FRONT button is currently under construction. Tools may launch behind the browser window. If a launched tool does not appear immediately, check the taskbar or minimize the browser.

## Repository Structure

```text
ShadowThrone/
├── ShadowThrone.ps1
├── Assets/
├── Web/
├── Tools/
│   ├── ShadowDeploy-MDE/
│   ├── ShadowDeploy-DFO365/
│   ├── ShadowVerify/
│   ├── ShadowTraceOps/
│   └── ShadowCA/
├── Reports/
├── Logs/
├── Exports/
├── Imports/Reports/
├── Intelligence/
├── Config/
├── Distributions/
├── SHADOW-SUITE-DOCTRINE.md
├── SECURITY.md
├── CHANGELOG.md
└── LICENSE
```

## Running Shadow Throne

1. Download the release ZIP.
2. Extract it to a local folder.
3. If Windows blocks the ZIP, right-click the ZIP, select **Properties**, then **Unblock** before extracting.
4. Open PowerShell in the extracted folder.
5. Run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\ShadowThrone.ps1
```

Shadow Throne opens a local HTML dashboard and launches tools from their packaged runtime folders.

## Runtime Packaging Model

Shadow Throne packages complete tool runtimes, not individual scripts. A runtime can include scripts, assets, configuration, KQL, playbooks, JSON, docs, reports, logs, exports, and supporting files.

To update a Knight later, replace its folder under `Tools\` with the new validated runtime and update its `manifest.json` if paths changed.

## Report and Intelligence Model

Shadow Throne does not replace each tool's reports. It indexes evidence from tool report/log locations and surfaces a high-level command view:

- Knights Table
- Kingdom Status
- Evidence Inventory
- Reports page
- Intelligence snapshot JSON

HTML reports are opened for human review. JSON outputs are treated as structured intelligence where available.

## Current Notes

- The **FRONT** button/window activation behavior is a known platform usability issue on some systems because PowerShell/WinForms windows do not always expose a reliable foreground window handle.
- Shadow CA is included as a placeholder for future development.
- This release is local-first and intended for defensive Microsoft Security operations.

## License

Released under the MIT License. See [LICENSE](LICENSE).
