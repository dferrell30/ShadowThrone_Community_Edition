# 🦇 Shadow Verify

## Defender Validation Framework

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207%2B-5391FE?style=for-the-badge\&logo=powershell\&logoColor=white)
![Windows](https://img.shields.io/badge/Platform-Windows-0078D6?style=for-the-badge\&logo=windows\&logoColor=white)
![Microsoft Defender](https://img.shields.io/badge/Microsoft-Defender%20for%20Endpoint-5E5E5E?style=for-the-badge\&logo=microsoft\&logoColor=white)
![Shadow Suite](https://img.shields.io/badge/Shadow%20Suite-v2.0-6F2DBD?style=for-the-badge)
![License](https://img.shields.io/badge/License-Shadow%20Suite%20Community-blueviolet?style=for-the-badge)

---

## Validate. Verify. Defend.

Shadow Verify is a Microsoft Defender validation framework designed to help security teams validate prevention controls, detection visibility, telemetry generation, alerting workflows, and analyst readiness.

Originally developed as the **MDE Test Framework**, Shadow Verify has been rebuilt as part of the **Shadow Suite** with enhanced reporting, guided validation experiences, analyst-focused workflows, and improved operational visibility.

---

# 🛡️ The Problem

Defender can appear healthy.

Devices can show as onboarded.

Policies can show as deployed.

That does **not** guarantee that:

* Prevention controls are working
* Telemetry is being generated
* Alerts are visible
* Analysts can validate security outcomes

Shadow Verify helps answer those questions safely and consistently.

---

# 🎯 Who Shadow Verify Is For

* Security Engineers
* Microsoft Defender Administrators
* Blue Team Analysts
* Security Consultants
* Microsoft Security Architects
* Lab and Validation Environments
* Organizations validating Defender deployments

---

# 📑 Table of Contents

* Overview
* What Shadow Verify Validates
* Features
* Guided Validation Experiences
* Architecture
* Quick Start
* Validation Categories
* Expected Outcomes
* Reporting
* Repository Structure
* Roadmap
* Requirements
* Licensing
* Disclaimers

---

# 📘 Overview

Deploying Microsoft Defender is only the first step.

The more important question is:

> Are your security controls actually working?

Shadow Verify provides a structured validation framework that helps organizations verify:

* Defender platform readiness
* Antivirus protection
* EDR telemetry visibility
* Attack Surface Reduction coverage
* Alert visibility
* Microsoft Graph access
* Analyst verification workflows

---

# 🔍 What Shadow Verify Validates

Shadow Verify is a defensive validation platform.

It is **not** an offensive tool.

It safely validates:

✅ Defender Antivirus Detection

✅ Endpoint Detection & Response Telemetry

✅ Attack Surface Reduction Configuration

✅ Microsoft Graph Visibility

✅ Defender Sensor Health

✅ Alert Retrieval

✅ Analyst Verification Workflows

✅ Guided Security Validation

---

# ⚙️ Features

## Core Validation

* Defender sensor validation
* Microsoft Defender Antivirus validation
* EICAR malware simulation
* EDR telemetry generation
* ASR configuration inspection
* Microsoft Graph validation
* Alert retrieval validation

## Guided Validation Experiences

Shadow Verify includes analyst-focused validation workflows.

Current guided experiences include:

### ASR Office Child Process Validation

Validates:

> Block all Office applications from creating child processes

Includes:

* Rule verification guidance
* Expected behavior by mode
* Validation workflow
* Device Timeline verification
* Advanced Hunting examples
* Portal confirmation guidance

Future guided experiences include:

* Credential Theft Protection
* Script Obfuscation Protection
* Executable Download Protection
* Office Process Injection Protection
* Network Protection Validation

---

# 🏗️ Architecture

Shadow Verify is organized into validation domains.

## Platform Health

* Defender Sensor Status
* Defender Services
* Antivirus Readiness

## Prevention Validation

* EICAR Detection Validation
* ASR Configuration Validation

## Detection & Telemetry

* Benign EDR Simulation
* Timeline Artifact Generation

## Cloud Visibility

* Microsoft Graph Connectivity
* Alert Retrieval

## Guided Validation

* Analyst Workflows
* Security Portal Verification
* Advanced Hunting Guidance

## Reporting

* HTML Reporting
* JSON Reporting
* Validation Scorecards

---

# 📸 Example Output

## Shadow Verify Console

![GUI Overview](./images/gui-overview.png)

![GUI Validation](./images/gui-run.png)

---

## Shadow Verify Reporting

![Report Summary](./images/report-summary.png)

![Report Details](./images/report-details.png)

---

# 🚀 Quick Start

Run PowerShell as Administrator.

## Clone Repository

```powershell
git clone https://github.com/YOURUSERNAME/ShadowVerify.git
cd ShadowVerify
```

## Execution Policy (If Required)

```powershell
Set-ExecutionPolicy Bypass -Scope CurrentUser
```

## Launch Shadow Verify

```powershell
.\Invoke-ShadowVerify.ps1
```

---

# 🧪 Validation Categories

## Platform Health

Validates:

* Defender sensor status
* Defender services
* Antivirus readiness

---

## Prevention Validation

Validates:

* EICAR detection
* Antivirus response
* ASR configuration

---

## Detection & Telemetry

Validates:

* EDR visibility
* Timeline artifacts
* Telemetry generation

---

## Cloud Visibility

Validates:

* Microsoft Graph access
* Alert retrieval
* Security portal visibility

---

## Guided Validation

Provides:

* Step-by-step validation workflows
* Analyst verification guidance
* Portal confirmation steps
* Advanced Hunting examples

---

# 🔍 Expected Outcomes

| Test                  | Expected Result                 | Where To Verify                          | Why It Matters               |
| --------------------- | ------------------------------- | ---------------------------------------- | ---------------------------- |
| EICAR Validation      | File detected or quarantined    | security.microsoft.com / Device Timeline | Confirms AV protection       |
| EDR Simulation        | Telemetry generated             | Device Timeline / Advanced Hunting       | Confirms EDR visibility      |
| Graph Validation      | Alerts returned                 | Microsoft Graph / Defender Portal        | Confirms cloud visibility    |
| ASR Configuration     | Rules identified                | Defender Policy Configuration            | Confirms protection coverage |
| Guided ASR Validation | Verification workflow completed | Defender Portal                          | Confirms analyst readiness   |

---

# 📊 Reporting

Shadow Verify generates:

## HTML Report

Includes:

* Validation Summary
* Pass / Verify / Fail Status
* Validation Score
* Guided Testing Experiences
* Interactive Validation Blades
* Verification Guidance

---

## JSON Report

Includes:

* Structured validation results
* Automation-friendly output
* Integration-ready format

---

# 📁 Repository Structure

```text
ShadowVerify/
├── README.md
├── CHANGELOG.md
├── LICENSE
├── SECURITY.md
├── Invoke-ShadowVerify.ps1
├── MDETestFramework.psm1
├── shadowverify.png
├── images/
├── docs/
│   └── PLAYBOOK.md
└── logs/
```

---

# 🛣️ Roadmap

## v2.0

* Shadow Suite branding
* Guided ASR validation
* Interactive report blades
* Validation scorecards
* Enhanced reporting

## v2.1

* Expanded ASR validation experiences
* Additional guided workflows
* Enhanced verification reporting

## Future

* Network Protection validation
* SmartScreen validation
* Web Content Filtering validation
* Device Control validation
* Controlled Folder Access validation
* Defender control maturity assessments

---

# 🧰 Requirements

* Windows endpoint
* Microsoft Defender for Endpoint onboarded
* PowerShell 5.1 or later
* Microsoft Graph PowerShell SDK (optional)
* Appropriate Graph permissions (optional)

---

# ⚖️ Licensing

Shadow Verify is licensed under the Shadow Suite Community License.

The Shadow Verify name, branding, and Shadow Suite identity are protected.

Refer to the LICENSE file for full terms and conditions.

---

# ⚠️ Disclaimers

Shadow Verify is intended for:

* Security validation
* Educational use
* Authorized testing
* Enterprise readiness assessments

Do not use this tool in unauthorized environments.

Some validation activities may generate Defender telemetry, detections, alerts, or security events.

Always perform testing in approved environments.

---

# ⚖️ Professional Disclaimer

This project is an independent work developed in a personal capacity.

The views, opinions, code, and content expressed in this repository are solely my own and do not reflect the views, policies, or positions of any employer, client, or affiliated organization.

This project is not affiliated with or endorsed by Microsoft.

---

## 🦇 Shadow Verify

### Defender Validation Framework

**Validate. Verify. Defend.**
