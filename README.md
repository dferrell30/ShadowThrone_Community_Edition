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
