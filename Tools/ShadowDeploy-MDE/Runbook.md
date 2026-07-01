# 📘 Shadow Deploy MDE Runbook

> Operational guide for deploying, validating, exporting, backing up, and reporting on Microsoft Defender for Endpoint security baselines using Shadow Deploy MDE.

---

# 📚 Table of Contents

* [Overview](#overview)
* [Prerequisites](#prerequisites)
* [Repository Structure](#repository-structure)
* [Launching Shadow Deploy MDE](#launching-shadow-deploy-mde)
* [Connecting to Microsoft Graph](#connecting-to-microsoft-graph)
* [Understanding the Interface](#understanding-the-interface)
* [Refreshing the JSON Catalog](#refreshing-the-json-catalog)
* [Validating JSON Policies](#validating-json-policies)
* [WhatIf Deployment Testing](#whatif-deployment-testing)
* [Deploying Policies](#deploying-policies)
* [Assigning Policies After Deployment](#assigning-policies-after-deployment)
* [Export Targeted Policy](#export-targeted-policy)
* [Export All Security Settings](#export-all-security-settings)
* [Backup All Policies](#backup-all-policies)
* [Generating Reports](#generating-reports)
* [Logs and Troubleshooting](#logs-and-troubleshooting)
* [Common Deployment Scenarios](#common-deployment-scenarios)
* [Expected Outcomes](#expected-outcomes)
* [Known Limitations](#known-limitations)
* [Recommended Workflow](#recommended-workflow)

---

# Overview

Shadow Deploy MDE is a PowerShell-based deployment framework designed to simplify Microsoft Defender for Endpoint policy deployment using Microsoft Intune Settings Catalog and Microsoft Graph.

The tool provides:

* Policy deployment
* JSON validation
* Policy assignment
* Policy export
* Policy backup
* Deployment reporting
* Operational visibility

The goal is to provide repeatable Defender security baselines across environments.

---

# Prerequisites

## Required Components

| Component                      | Requirement  |
| ------------------------------ | ------------ |
| Operating System               | Windows      |
| PowerShell                     | 5.1 or later |
| Microsoft Graph SDK            | Installed    |
| Microsoft Intune               | Required     |
| Entra ID                       | Required     |
| Appropriate Intune Permissions | Required     |

---

## Install Microsoft Graph

Run PowerShell as Administrator:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

---

# Repository Structure

Expected repository structure:

```text
ShadowDeploy-MDE
│
├─ Invoke-ShadowDeployMDE.ps1
│
├─ Config
│   └─ SettingsCatalog
│
├─ Logs
├─ Reports
├─ Backups
├─ Exports
│
├─ README.md
├─ RUNBOOK.md
├─ CHANGELOG.md
├─ SECURITY.md
└─ LICENSE
```

---

# Launching Shadow Deploy MDE

## Step 1

Open PowerShell.

---

## Step 2

Navigate to the repository:

```powershell
cd "C:\Path\To\ShadowDeploy-MDE"
```

---

## Step 3

Launch the tool:

```powershell
.\Invoke-ShadowDeployMDE.ps1
```

---

## Expected Result

The Shadow Deploy MDE dashboard opens.

---

# Connecting to Microsoft Graph

## Connect Graph

Click:

```text
Connect Graph
```

The tool will:

1. Disconnect any existing Graph session
2. Start a fresh Graph authentication session
3. Prompt for authentication
4. Trigger MFA if required by Conditional Access

---

## Expected Result

Graph status changes to:

```text
GRAPH: CONNECTED
```

---

## Disconnect Graph

Click:

```text
Disconnect Graph
```

---

## Expected Result

Graph status changes to:

```text
GRAPH: DISCONNECTED
```

---

# Understanding the Interface

## Deployment Controls

| Control             | Purpose                                   |
| ------------------- | ----------------------------------------- |
| Deploy Selected     | Deploy selected policies                  |
| WhatIf              | Test deployment without creating policies |
| Assign After Deploy | Assign policy after deployment            |

---

## Actions

| Button              | Purpose                      |
| ------------------- | ---------------------------- |
| Refresh JSON        | Reload policy catalog        |
| Validate JSON       | Validate JSON structure      |
| Export Targeted     | Export one Intune policy     |
| Export Security     | Export all security policies |
| Backup All Policies | Backup deployed policies     |
| Generate Report     | Create HTML report           |
| Clear Results       | Clear results table          |

---

## Folder Shortcuts

| Button       | Opens          |
| ------------ | -------------- |
| Open Config  | Config folder  |
| Open Logs    | Logs folder    |
| Open Reports | Reports folder |

---

# Refreshing the JSON Catalog

## Purpose

Loads all JSON files from:

```text
Config\SettingsCatalog
```

---

## Procedure

Click:

```text
Refresh JSON
```

---

## Expected Result

All JSON files appear in the policy grid.

---

# Validating JSON Policies

## Purpose

Verify deployment readiness.

---

## Procedure

Click:

```text
Validate JSON
```

---

## Validation Checks

| Validation            | Checked |
| --------------------- | ------- |
| File Exists           | ✅       |
| JSON Structure        | ✅       |
| Settings Array Exists | ✅       |
| Settings Present      | ✅       |

---

## Example Result

```text
Firewall.json - Valid
ASR.json - Valid
EDR.json - Valid
```

---

# WhatIf Deployment Testing

## Purpose

Test deployment without creating policies.

---

## Procedure

Enable:

```text
WhatIf / Validate Only
```

Select a policy and click:

```text
Deploy Selected
```

---

## Expected Result

```text
WhatIf - Validated JSON Only
```

No policy is created.

---

# Deploying Policies

## Procedure

1. Disable WhatIf
2. Select policy
3. Click:

```text
Deploy Selected
```

---

## Expected Result

```text
Success - Created Configuration Policy
```

---

## Existing Policy Behavior

If the policy already exists:

```text
Skipped - Policy Already Exists
```

This prevents accidental overwrites.

---

# Assigning Policies After Deployment

## Procedure

Enter group name:

```text
MDE Pilot Devices
```

Enable:

```text
Assign After Deploy
```

Deploy policy.

---

## Expected Result

```text
Assigned - MDE Pilot Devices
```

---

## Common Failure

```text
Group Not Found
```

Verify the Entra ID group name is correct.

---

# Export Targeted Policy

## Purpose

Export a single Intune policy.

---

## Procedure

Click:

```text
Export Targeted
```

Enter the exact policy name.

Example:

```text
MDE - Firewall
```

---

## Expected Result

JSON is exported and can be stored under:

```text
Config\SettingsCatalog
```

---

# Export All Security Settings

## Purpose

Export all matching security-related policies.

---

## Procedure

Click:

```text
Export Security
```

---

## Output Location

```text
Exports\SecuritySettings\<timestamp>\
```

---

## Exported Policies

Examples:

* Firewall
* ASR
* Antivirus
* EDR
* Windows Security Experience
* AVC Update Controls

---

## Additional Output

```text
export-summary.txt
```

---

# Backup All Policies

## Purpose

Create backups before making changes.

### Backup All Policies

Creates timestamped backups of supported Microsoft Defender and security-related policies currently deployed in Intune.

The backup process:

1. Reads policy definitions from the local `Config\SettingsCatalog` folder
2. Searches Intune for matching deployed policies
3. Exports the live policy configuration and settings from Intune
4. Saves exported policies as JSON files
5. Generates a backup summary report

Backups are stored in:

```text
Backups\<timestamp>\

---

## Procedure

Click:

```text
Backup All Policies
```

---

## Output Location

```text
Backups\<timestamp>\
```

---

## Example

```text
Backups\2026-06-14_09-30
```

---

## Included Files

| File               | Purpose        |
| ------------------ | -------------- |
| backup-summary.txt | Backup summary |
| Policy JSON Files  | Policy backups |

---

# Generating Reports

## Purpose

Generate deployment evidence.

---

## Procedure

Click:

```text
Generate Report
```

---

## Output Location

```text
Reports\
```

---

## Report Contents

| Section              | Included |
| -------------------- | -------- |
| Deployment Results   | ✅        |
| Settings Inventory   | ✅        |
| Assignment Status    | ✅        |
| Zero Trust Checklist | ✅        |
| Operational Notes    | ✅        |

---

# Logs and Troubleshooting

## Log Location

```text
Logs\
```

---

## Common Log Messages

| Message  | Meaning               |
| -------- | --------------------- |
| Success  | Operation completed   |
| Skipped  | Policy already exists |
| Failed   | Deployment failed     |
| Assigned | Assignment successful |

---

# Common Deployment Scenarios

## Scenario 1: Validate New JSON

### Steps

1. Copy JSON into SettingsCatalog
2. Refresh JSON
3. Validate JSON

### Expected Result

Policy shows:

```text
Valid
```

---

## Scenario 2: Safe Deployment Test

### Steps

1. Enable WhatIf
2. Select policy
3. Deploy

### Expected Result

```text
WhatIf - Validated JSON Only
```

---

## Scenario 3: Production Deployment

### Steps

1. Disable WhatIf
2. Deploy policy

### Expected Result

```text
Success
```

---

## Scenario 4: Deploy and Assign

### Steps

1. Enter group name
2. Enable Assign After Deploy
3. Deploy

### Expected Result

```text
Assigned
```

---

## Scenario 5: Backup Before Changes

### Steps

1. Connect Graph
2. Backup All Policies

### Expected Result

Timestamped backup folder created.

---

## Scenario 6: Export Existing Environment

### Steps

1. Export Security
2. Review export folder

### Expected Result

All supported security policies exported.

---

# Expected Outcomes

| Action          | Expected Result  |
| --------------- | ---------------- |
| Connect Graph   | Graph Connected  |
| Refresh JSON    | Policies Loaded  |
| Validate JSON   | Validated        |
| Deploy Policy   | Created          |
| Assign Policy   | Assigned         |
| Export Policy   | JSON Exported    |
| Backup Policies | Backup Created   |
| Generate Report | Report Generated |

---

# Known Limitations

| Area       | Limitation                                           |
| ---------- | ---------------------------------------------------- |
| Firewall   | Settings Catalog only                                |
| Antivirus  | Advanced Endpoint Security AV profiles not supported |
| EDR        | Connector onboarding values excluded                 |
| Validation | Does not validate tenant compatibility               |
| Graph      | Some Defender APIs outside current scope             |

---

# Recommended Workflow

## Production Workflow

```text
Connect Graph
        ↓
Refresh JSON
        ↓
Validate JSON
        ↓
Backup All Policies
        ↓
WhatIf Test
        ↓
Deploy Policies
        ↓
Assign Policies
        ↓
Generate Report
        ↓
Review Results
```

---

# Summary

Shadow Deploy MDE provides a repeatable deployment workflow for Microsoft Defender for Endpoint using Microsoft Graph and Intune Settings Catalog policies.

Recommended operating model:

```text
Backup → Validate → Deploy → Assign → Report
```

As part of the Shadow Suite:

```text
Deploy → Validate → Investigate
```
