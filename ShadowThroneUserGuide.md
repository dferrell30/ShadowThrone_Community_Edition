# Shadow Throne v1.0 User Guide

Shadow Throne is the command center for the Shadow Suite. It launches and organizes the individual Shadow Suite tools, called Knights, while preserving each tool’s original functionality, reports, logs, configuration, and workflow.

---

## 1. Requirements

Before running Shadow Throne, make sure you have:

- Windows 10 or Windows 11
- PowerShell 5.1 or PowerShell 7+
- Microsoft Edge or Google Chrome
- Internet access for Microsoft Graph authentication where required
- Local permissions to run PowerShell scripts
- Required Microsoft 365 / Microsoft Defender permissions for each individual tool

---

## 2. Download and Extract

1. Go to the GitHub release page.
2. Download the latest Shadow Throne v1.0 ZIP.
3. Extract the ZIP to a local folder.

Recommended location:

```powershell
C:\Tools\ShadowThrone

Expected folder structure:

ShadowThrone
├── ShadowThrone.ps1
├── Assets
├── Config
├── Exports
├── Imports
├── Intelligence
├── Logs
├── Reports
├── Tools
└── Web
3. Unblock Files

If the ZIP was downloaded from GitHub, Windows may block the files.

Run:

Get-ChildItem "C:\Tools\ShadowThrone" -Recurse | Unblock-File
4. Start Shadow Throne

Open PowerShell and run:

cd C:\Tools\ShadowThrone
Set-ExecutionPolicy -Scope Process Bypass
.\ShadowThrone.ps1

Shadow Throne opens in your browser using a local URL.

5. Known v1.0 Issue

The FRONT button is currently under construction.

Tools may open behind the browser window. If a tool does not appear after launch:

Check the Windows taskbar.
Minimize the browser.
Select the launched PowerShell or tool window manually.

This does not affect tool functionality.

6. Shadow Throne Layout

Shadow Throne is organized into several main areas.

Area	Purpose
Throne Room	Main dashboard and tool launcher
Reports	View indexed reports and evidence
Logs	Access activity and tool logs
Settings	Configuration area
About	Version and project information
Knights Table	Latest report status from each tool
Operations Intelligence	Summary of current suite posture
Kingdom Status	Readiness and health of each Knight
Evidence Inventory	Recently indexed reports and JSON evidence
7. The Knights

Each Shadow Suite tool is represented as a Knight.

Knight	Tool	Purpose
Warrior	Shadow Deploy MDE	Defender for Endpoint deployment and reporting
Gatekeeper	Shadow Deploy DFO365	Defender for Office 365 deployment and reporting
Trial Master	Shadow Verify	Defender validation and readiness testing
Hunter	Shadow Trace Ops	Investigation and signal intelligence
Sentinel	Shadow CA	Conditional Access governance placeholder

Each Knight runs from its own folder under:

Tools\<ToolName>

Each tool remains responsible for its own configuration, authentication, reports, logs, and workflows.

8. Launching a Tool

From the Throne Room:

Locate the Knight card.
Click the card or use the available action buttons.
The tool launches in its own PowerShell process.
Complete the workflow inside the launched tool.
Return to Shadow Throne when finished.

Example:

Throne Room → Warrior → Launch Shadow Deploy MDE
9. Tool Action Buttons

Each Knight card includes action buttons.

Button	Purpose
Launch / Card Click	Launches the tool
Front	Attempts to bring the tool window forward; under construction in v1.0
Folder / Open Folder	Opens the tool runtime folder
Reports	Opens the tool reports folder
Logs	Opens the tool logs folder
View Latest Report	Opens the latest available HTML report
Import / View Results	Shadow Verify-specific result action
Package	Shadow Verify-specific packaging action
Latest Investigation	Shadow Trace Ops-specific report shortcut
Executive Report	Shadow Trace Ops-specific executive report shortcut
10. Running Shadow Deploy MDE

Use Warrior for Microsoft Defender for Endpoint deployment and reporting.

Basic workflow:

Launch Shadow Deploy MDE from the Warrior card.
Connect to Microsoft Graph when prompted.
Load or select the desired Defender for Endpoint configuration.
Review settings before deployment.
Deploy, export, back up, or report using the tool’s own interface.
Generate reports from inside the tool.
Return to Shadow Throne.
Open the Reports page.
Click Refresh Intel to update Shadow Throne’s report intelligence.

For detailed usage, see:

Tools\ShadowDeploy-MDE\README.md
11. Running Shadow Deploy Defender for Office 365

Use Gatekeeper for Defender for Office 365 deployment and reporting.

Basic workflow:

Launch Shadow Deploy DFO365 from the Gatekeeper card.
Connect to Microsoft Graph or Exchange Online as required by the tool.
Select the desired policy or configuration workflow.
Review protection settings such as Safe Links, Safe Attachments, Anti-Phishing, and related policies.
Deploy, export, back up, or assign scope using the tool’s interface.
Generate reports.
Return to Shadow Throne.
Click Refresh Intel on the Reports page.

For detailed usage, see:

Tools\ShadowDeploy-DFO365\README.md
12. Running Shadow Verify

Use Trial Master for Defender validation and readiness testing.

Basic workflow:

Launch Shadow Verify from the Trial Master card.
Select the desired validation scenario.
Run validation checks.
Review guided test output.
Generate the HTML and JSON reports.
Confirm pop-out blades and KQL guidebooks are available in the generated report.
Return to Shadow Throne.
Click Refresh Intel.

Shadow Verify produces both human-readable reports and structured JSON results.

For detailed usage, see:

Tools\ShadowVerify\README.md
13. Running Shadow Trace Ops

Use Hunter for investigation, signal intelligence, and report generation.

Basic workflow:

Launch Shadow Trace Ops from the Hunter card.
Connect required services.
Enter the investigation target or workflow details.
Run the investigation.
Review identity, authentication, alert, session, OAuth, and cloud activity context.
Generate investigation and executive reports.
Return to Shadow Throne.
Click Refresh Intel.

For detailed usage, see:

Tools\ShadowTraceOps\README.md
14. Shadow CA / Sentinel

Shadow CA is currently represented as Sentinel.

In v1.0 this area may appear as coming soon or under construction depending on the package.

Future functionality is expected to focus on Conditional Access governance, access policy visibility, and Zero Trust review workflows.

15. Using the Reports Page

The Reports page indexes evidence generated by each Knight.

To update reports:

Run a tool.
Generate a report from that tool.
Return to Shadow Throne.
Open Reports.
Click Refresh Intel.

The Reports page shows:

Latest report per Knight
Health/status summary
Report counts
Top attention items
Evidence inventory
Report intelligence
16. Report Types

Shadow Throne may detect both HTML and JSON files.

File Type	Purpose
.html / .htm	Human-readable report opened by View Report
.json	Structured intelligence used by Shadow Throne
.log	Tool activity and troubleshooting information

When clicking View Report, Shadow Throne prefers the latest HTML report.

JSON files are used for indexing and intelligence.

17. Refreshing Intelligence

Use Refresh Intel when you want Shadow Throne to re-index reports and evidence.

This updates:

Reports page
Knights Table
Kingdom Status
Operations Intelligence
Evidence Inventory

Recommended use:

Run Knight → Generate Report → Return to Shadow Throne → Refresh Intel
18. Using the Knights Table

The Knights Table shows the latest known reporting status for each Knight.

It helps answer:

Which tools have reported?
Which tools need attention?
Which tool produced the latest evidence?
Which reports require review?

If the table does not update immediately, click Refresh Intel.

19. Using Evidence Inventory

Evidence Inventory displays recently indexed report and JSON evidence.

Use it to quickly confirm whether Shadow Throne has detected output from the tools.

Evidence remains owned by the original tool runtime. Shadow Throne indexes and summarizes it.

20. Using Kingdom Status

Kingdom Status summarizes overall readiness.

It may show:

Healthy
Review
High
Critical
Pending
Coming Soon

This status is based on indexed evidence and tool availability.

21. Opening Tool Folders

Each Knight has folder shortcuts.

Common folders include:

Reports
Logs
Exports
Config
Assets

Use these buttons when you need to inspect generated output or troubleshoot a tool.

22. Updating a Knight

Shadow Throne packages complete tool runtimes.

To update a tool:

Download the latest release of the tool.
Replace the matching folder under:
Tools\<ToolName>

Example:

Tools\ShadowVerify
Make sure the replacement includes the full runtime:
Scripts
Assets
Config
Reports
Logs
KQL
Playbooks
JSON files
Required modules
Restart Shadow Throne.
Launch the tool again.

Do not replace only a single script unless the tool is truly self-contained.

23. Recommended Operating Model

Shadow Throne should be used as the central command layer.

Recommended workflow:

Open Shadow Throne.
Launch the required Knight.
Complete the tool workflow.
Generate reports.
Return to Shadow Throne.
Refresh intelligence.
Review Kingdom Status and Reports.
Open detailed reports when needed.
24. Troubleshooting
Tool launches behind the browser

Known v1.0 issue.

Use the Windows taskbar or minimize the browser.

Report does not appear

Try:

Confirm the tool generated a report.
Confirm the report exists in the tool’s Reports or Logs folder.
Return to Shadow Throne.
Click Refresh Intel.
Open the Reports page again.
JSON appears instead of HTML

Shadow Throne should prefer HTML reports for View Report. If JSON opens, check whether a matching HTML report exists in the tool folder.

Missing KQL, guidebooks, or report blades

This usually means the tool runtime is incomplete.

Replace the full tool folder under:

Tools\<ToolName>

with the complete runtime release.

PowerShell execution blocked

Run:

Set-ExecutionPolicy -Scope Process Bypass

Or unblock the extracted files:

Get-ChildItem "C:\Tools\ShadowThrone" -Recurse | Unblock-File
25. Where to Find Detailed Tool Documentation

Each Knight maintains its own operational documentation.

Knight	Documentation
Warrior	Tools\ShadowDeploy-MDE\README.md
Gatekeeper	Tools\ShadowDeploy-DFO365\README.md
Trial Master	Tools\ShadowVerify\README.md
Hunter	Tools\ShadowTraceOps\README.md
Sentinel	Tools\ShadowCA\README.md when available

Shadow Throne documents the command center.

Each Knight documents its own detailed operational workflow.

26. Support

For issues:

Check this guide.
Check the Knight-specific README.
Review logs under:
Logs
Tools\<ToolName>\Logs
Open an issue on GitHub with:
Shadow Throne version
Tool name
Steps to reproduce
Screenshot if available
Relevant log file
27. Summary

Shadow Throne v1.0 provides a unified command center for the Shadow Suite.

It is designed to:

Launch tools
Preserve tool independence
Index reports
Surface operational intelligence
Maintain evidence visibility
Prepare for future AI-assisted summaries

Each Knight remains authoritative for its own workflow. Shadow Throne coordinates, indexes, and presents the operational view.
