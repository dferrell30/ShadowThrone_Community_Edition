# Security Policy

## Supported Version

| Version | Supported |
|---|---|
| Shadow Throne v1.0 | Yes |

## Reporting a Vulnerability

Please do not publish exploit details publicly before maintainers have had an opportunity to review.

Open a private security advisory if available, or contact the maintainer directly through the project contact method listed in the repository.

## Scope

Shadow Throne and the Shadow Suite tools are defensive administration and validation tools. They may request Microsoft Graph permissions depending on the launched module. Review each tool's permissions before use in production.

## Safe Use

- Run only from a trusted workstation.
- Review scripts before execution.
- Use least-privilege administrative accounts where possible.
- Validate in a test tenant before production use.
- Do not publish tenant-specific reports, logs, exports, or backups.
