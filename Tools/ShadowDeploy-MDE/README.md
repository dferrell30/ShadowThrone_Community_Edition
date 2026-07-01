# 🌑 Shadow Deploy MDE

![Status](https://img.shields.io/badge/status-v1.0-blue)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue)
![Microsoft Graph](https://img.shields.io/badge/Microsoft%20Graph-Enabled-0078D4)


### Shadow Suite Deployment Framework for Microsoft Defender for Endpoint

A lightweight, JSON-driven deployment and configuration framework for Microsoft Defender for Endpoint (MDE) using Microsoft Graph and Microsoft Intune Settings Catalog.

Shadow Deploy MDE simplifies Defender policy deployment by enabling repeatable, consistent security baselines across environments while providing deployment validation, export capabilities, backup workflows, assignment automation, and operational reporting from a single interface.

> **Deploy → Validate → Assign → Report → Improve**

Shadow Deploy for Microsoft Defender for Endpoint is part of the Shadow Suite and provides a centralized deployment experience for Microsoft Defender for Endpoint security controls using Microsoft Intune Settings Catalog policies.

The project was built to help administrators streamline deployment workflows, improve visibility into deployed configurations, and create repeatable deployment, reporting, export, and backup processes.

Key capabilities include:

Defender for Endpoint policy deployment
Settings Catalog JSON import support
Policy assignment management
Security policy export capabilities
Environment backup workflows
Deployment reporting
Microsoft Graph integration
Operational visibility and validation support

Shadow Deploy focuses on helping administrators answer:

What security controls have been deployed?

Where have they been assigned?

How can they be documented and maintained over time?

For organizations seeking post-deployment validation, Shadow Verify can be used as a companion framework to validate controls, telemetry, and security visibility after deployment.

---

## 🌑 Part of the Shadow Suite

Shadow Deploy MDE is the deployment component of the Shadow Suite.

| Tool                  | Purpose                                                    |
| --------------------- | ---------------------------------------------------------- |
| **Shadow Deploy MDE** | Deploy Defender for Endpoint security baselines            |
| **Shadow Verify**     | Validate Defender controls, telemetry, and visibility      |
| **Shadow Trace Ops**  | Investigate identity, endpoint, cloud, and security events |

Together they provide:

```text
Deploy → Validate → Investigate
```

---

## 📸 Dashboard

> Add your latest screenshot here.

![Shadow Deploy MDE](https://github.com/user-attachments/assets/6bd8f83f-083a-4b30-b26f-c6ee7029cab6)

---

# 🚀 Overview

Deploying Microsoft Defender for Endpoint manually can be:

* Time-consuming
* Inconsistent across environments
* Difficult to validate
* Difficult to back up
* Difficult to reproduce across tenants

Shadow Deploy MDE provides a repeatable deployment framework that:

* Uses JSON-based policy configurations
* Automates deployment through Microsoft Graph
* Supports repeatable security baselines
* Simplifies policy export and backup
* Supports assignment after deployment
* Generates operational reporting

---

# 🔧 Features

## Deployment

* ✅ JSON-driven deployment model
* ✅ Microsoft Graph integration
* ✅ Multi-policy deployment
* ✅ Dynamic JSON discovery
* ✅ WhatIf deployment validation
* ✅ Assignment after deployment

## Graph Integration

* ✅ Connect Graph
* ✅ Disconnect Graph
* ✅ Graph status indicator
* ✅ Fresh interactive authentication
* ✅ MFA-compatible authentication flow

## Validation

* ✅ JSON validation
* ✅ Deployment readiness checks
* ✅ Deployment logging
* ✅ Status tracking

## Export & Backup

* ✅ Export Targeted Policy
* ✅ Export All Security Settings
* ✅ Backup All Policies
* ✅ Timestamped export folders
* ✅ Timestamped backup folders
* ✅ Export summaries
* ✅ Backup summaries

## Reporting

* ✅ HTML deployment reporting
* ✅ Settings inventory reporting
* ✅ Zero Trust alignment visibility
* ✅ Deployment evidence generation

---

# 🎯 Supported Policies

| Policy Type                             | Supported |
| --------------------------------------- | --------- |
| 🔥 Microsoft Defender Firewall          | ✅         |
| 🛡️ Attack Surface Reduction (ASR)      | ✅         |
| 📡 Endpoint Detection & Response (EDR)  | ✅         |
| 🛡️ Microsoft Defender Antivirus        | ✅         |
| 🪟 Windows Security Experience          | ✅         |
| 🔄 AVC Update Controls                  | ✅         |
| ⚙️ Additional Settings Catalog Policies | ✅         |

---

# 📊 Current Capabilities

| Capability                   | Included |
| ---------------------------- | -------- |
| Deploy Policies              | ✅        |
| Validate JSON                | ✅        |
| WhatIf Validation            | ✅        |
| Assign After Deploy          | ✅        |
| Export Targeted Policy       | ✅        |
| Export All Security Settings | ✅        |
| Backup All Policies          | ✅        |
| Generate HTML Reports        | ✅        |
| Dynamic JSON Discovery       | ✅        |
| Connect / Disconnect Graph   | ✅        |
| Logging                      | ✅        |

---

# 📁 Repository Structure

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

# 🧠 How It Works

```text
Create Policy in Intune
        ↓
Export Policy to JSON
        ↓
Store JSON in SettingsCatalog
        ↓
Validate JSON
        ↓
Deploy Policy
        ↓
Assign Policy
        ↓
Generate Report
```

---

# 🔁 Deployment Workflow

Recommended operational flow:

```text
Backup → Validate → WhatIf → Deploy → Assign → Report
```

### Typical Workflow

1. Connect Graph
2. Refresh JSON List
3. Validate JSON
4. Backup Existing Policies
5. Test with WhatIf
6. Deploy Policies
7. Assign Policies
8. Generate Report
9. Review Results

---

# 📦 Export Features

## Export Targeted

Export a single Intune policy to reusable JSON.

Use cases:

* Create reusable baselines
* Version control policy configurations
* Replicate policies across environments

---

## Export All Security Settings

Exports all matching security-related Settings Catalog policies.

Output:

```text
Exports\SecuritySettings\<timestamp>\
```

Includes:

* Firewall
* ASR
* Antivirus
* EDR
* Windows Security Experience
* AVC Update Controls
* Additional matching security policies

---

# 💾 Backup Features

## Backup All Policies

Creates timestamped backups of deployed MDE policies.

Example:

```text
Backups\2026-06-13_21-45\
```

Includes:

```text
backup-summary.txt
```

and exported JSON policy backups.

---

# 📊 Reporting

Shadow Deploy MDE generates deployment reports that include:

* Deployment Results
* Settings Inventory
* Zero Trust Alignment Checklist
* Assignment Status
* Deployment Evidence
* Operational Notes

Reports are stored in:

```text
Reports\
```

---

# ⚠️ Known Limitations

## Firewall Policies

Firewall policies must originate from exported Settings Catalog configurations.

### Supported

* Settings Catalog Firewall Policies

### Not Supported

* Endpoint Security Firewall Profiles

---

## Defender Antivirus

Supported via:

* Settings Catalog AV controls
* AV Configuration policies

Not currently supported:

* Tenant-specific onboarding values
* Connector onboarding values
* Certain Endpoint Security AV profile settings

---

## Endpoint Detection & Response (EDR)

Connector onboarding values are intentionally excluded.

Do not include:

```text
device_vendor_msft_windowsadvancedthreatprotection_onboarding_fromconnector
```

These values are tenant-specific and may cause deployment failures.

---

## Settings Catalog Dependency

Policies should originate from exported Settings Catalog configurations.

Hand-built JSON may fail due to:

* Invalid template references
* Missing setting types
* Incorrect schema structure
* Tenant-specific values

---

## Graph API Constraints

Shadow Deploy MDE uses Microsoft Graph Intune configuration endpoints.

Some Defender capabilities use alternate APIs and are outside the scope of this release.

---

## Validation Scope

Current validation verifies:

* JSON structure
* Settings presence
* Deployment readiness

Current validation does not verify:

* Tenant compatibility
* Setting-level Graph restrictions
* Endpoint Security template compatibility

---

# 🧪 Companion Project

Shadow Deploy MDE is designed to work alongside:

## MDE-Test-Framework

https://github.com/dferrell30/MDE-Test-Framework

This companion framework validates Defender controls after deployment.

Together:

```text
Deploy → Test → Validate → Repeat
```

---

# 🗺️ Roadmap

## Current Release

* Deployment Engine
* Assignment Support
* Backup Workflows
* Export Features
* Reporting
* Validation

## Planned Enhancements

* Shadow Deploy Executive Dashboard
* Readiness Scoring
* Interactive Report Blades
* Enhanced Zero Trust Assessments
* Additional Defender Policy Coverage
* Deployment Trend Reporting

---

# ⚠️ Disclaimer

This project is intended for defensive security validation and educational use only.

* Do not use in unauthorized environments
* Do not use for offensive or malicious purposes
* Always test in approved lab or enterprise environments
* Review policies before production deployment

Some actions may generate security telemetry and alerts.

---

# ⚖️ Professional Disclaimer

This project is an independent work developed in a personal capacity.

* It is not affiliated with or endorsed by Microsoft
* No employer has reviewed or approved this work
* No proprietary or confidential resources were used

All code and content are solely my own and provided under the included MIT License.

---

# 🤝 Feedback

Feedback, ideas, and suggestions are welcome.

If you find the project useful:

* ⭐ Star the repository
* 🐞 Open issues
* 💡 Submit enhancement requests
* 🔄 Share deployment experiences

---

# 📣 Author

Built to simplify Microsoft Defender for Endpoint deployment, validation, and operational readiness workflows.

**Shadow Deploy MDE** — Part of the Shadow Suite.
