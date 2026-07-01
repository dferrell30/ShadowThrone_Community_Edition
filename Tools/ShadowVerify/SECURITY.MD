# Security Policy

## Supported Versions

| Version                  | Supported |
| ------------------------ | --------- |
| 2.x                      | ✅ Yes     |
| 1.x (MDE Test Framework) | ❌ No      |

---

## Reporting a Vulnerability

If you discover a security vulnerability, please do not publicly disclose the issue before it can be reviewed.

Please report vulnerabilities by opening a private security advisory through GitHub or by contacting the maintainer directly.

When reporting a vulnerability, include:

* Description of the issue
* Impact assessment
* Reproduction steps
* Screenshots or logs (if applicable)
* Suggested remediation (if known)

---

## Scope

This project is intended for:

* Defensive security validation
* Microsoft Defender testing
* Security research
* Educational use

The project is not intended to provide offensive capabilities or exploit development functionality.

---

## Security Considerations

Shadow Verify generates security telemetry and validation artifacts designed to assist administrators in validating Microsoft Defender controls.

Users should:

* Test only in authorized environments
* Review generated telemetry before making security decisions
* Validate findings independently when appropriate
* Understand that alert generation may vary by licensing, configuration, and environment

---

## Supported Environments

Shadow Verify is primarily tested against:

* Microsoft Defender for Endpoint
* Windows 10
* Windows 11
* PowerShell 5.1+
* PowerShell 7+

Behavior may vary depending on:

* Licensing
* Tenant configuration
* Alert tuning
* Security policy configuration

---

## Responsible Disclosure

Please provide maintainers a reasonable opportunity to investigate and remediate reported vulnerabilities before public disclosure.

---

## Contact

For security-related concerns regarding Shadow Verify or other Shadow Suite projects, please use GitHub Security Advisories or contact the repository maintainer directly.

---

© 2026 Shadow Suite

Validate. Verify. Defend.
