# Changelog

All notable changes to this project will be documented in this file.

---

# v1.0.0 – Initial Public Release

## Release Summary

Initial public release of the Microsoft Defender for Endpoint Deployment Tool.

This release introduces a PowerShell-based deployment and validation framework for Microsoft Defender for Endpoint security baselines using Microsoft Intune Settings Catalog policies. The tool is designed to simplify deployment, provide repeatable configurations, and improve operational consistency across Defender for Endpoint environments.

---

## Added

### Deployment Engine

* JSON-driven deployment model for Intune Settings Catalog policies
* Dynamic policy discovery from `Config\SettingsCatalog`
* Multi-policy deployment support
* WhatIf validation mode for safe testing
* Policy assignment after deployment
* Automatic policy naming standardization

### Microsoft Graph Integration

* Microsoft Graph authentication support
* Connect Graph button
* Disconnect Graph button
* Graph connection status indicator
* Forced interactive Graph authentication workflow
* Fresh Graph session initialization before connection attempts

### Validation Features

* JSON structure validation
* Settings Catalog validation checks
* Deployment result tracking
* Detailed deployment logging

### Export Features

* Export Targeted policy functionality
* Export All Security Settings functionality
* Security policy export summary generation
* Timestamped export folders

### Backup Features

* Backup All Policies functionality
* Timestamped backup folders
* Backup summary generation
* Automated policy export from Intune
* Multiple policy name matching logic for backup reliability

### Reporting

* HTML deployment report generation
* Deployment results reporting
* Settings inventory reporting
* Zero Trust alignment checklist
* Deployment status tracking
* Operational notes section

### User Interface

* Dark mode deployment dashboard
* Dynamic policy selection grid
* Improved action button layout
* Clear Results functionality
* Open Config folder shortcut
* Open Logs folder shortcut
* Open Reports folder shortcut
* Enhanced logging panel visibility

---

## Supported Policy Types

### Current Baseline Support

* Microsoft Defender Firewall
* Attack Surface Reduction (ASR)
* Endpoint Detection and Response (EDR)
* Microsoft Defender Antivirus
* Windows Security Experience
* AVC Update Controls
* Additional supported Settings Catalog policies

---

## Operational Enhancements

* Dynamic JSON loading without script modification
* Automatic policy discovery
* Assignment workflow integration
* Improved deployment visibility
* Deployment evidence generation
* Backup and recovery workflow support

---

## Known Limitations

### Firewall

Firewall policies must be exported from Intune Settings Catalog and imported as JSON.

### Antivirus

Full Endpoint Security Antivirus profile imports are not currently supported. Recommended deployment method is via supported Settings Catalog configurations.

### EDR

Connector onboarding secret settings are intentionally excluded from deployment exports due to tenant-specific configuration requirements.

### Existing Policies

The tool does not overwrite existing policies. Existing policies are skipped during deployment.

### MFA Enforcement

Graph authentication supports forced interactive sign-in. MFA enforcement is dependent on tenant Conditional Access policies and authentication requirements.

---

## Repository Structure

Recommended repository folders:

* Config
* SettingsCatalog
* Reports
* Logs
* Backups
* Exports

---

## Future Roadmap

### Planned Enhancements

* Shadow Deploy executive dashboard reporting
* Readiness scoring
* Enhanced Zero Trust assessments
* Deployment trend reporting
* Interactive report blades
* Expanded deployment validation
* Additional Defender policy coverage

---

Initial public release.
