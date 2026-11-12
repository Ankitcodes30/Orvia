# Security Policy

## Supported Versions

Only the latest public production release branch and security maintenance releases receive security patches.

| Version | Supported          |
| ------- | ------------------ |
| 3.0.7+x | :white_check_mark: |
| < 3.0.7 | :x:                |

## Reporting a Vulnerability

The Orvia project takes security and user privacy seriously. If you discover a vulnerability or potential security risk in Orvia, please follow responsible disclosure practices.

**Do not report vulnerabilities via public GitHub issues, discussions, or pull requests.**

### Preferred Reporting Channels

1. **GitHub Private Vulnerability Reporting**:
   Use GitHub's built-in private advisory system at [GitHub Security Advisories](https://github.com/Ankitcodes30/Orvia/security/advisories/new).
2. **Email Security Contact**:
   Send an encrypted or confidential email to:  
   `ankitkumbhare301@gmail.com`  
   Subject line: `[SECURITY] Potential vulnerability in Orvia: <short summary>`

### What to Include

Please provide as much relevant technical information as possible to help us reproduce and remediate the issue quickly:
- Application version and build number (e.g. `3.0.7+7`)
- Operating system and version (Android, Windows 10/11)
- Type of issue (e.g. In-App Update verification, Path Traversal, Cleartext Network Traffic, FileProvider scope)
- Step-by-step reproduction instructions or proof-of-concept (PoC)
- Impact assessment and potential threat scenario
- Proposed patch or mitigation if available

## Response & Triage SLA

Our team is committed to timely investigation and communication:
- **Acknowledgment:** Within 48 hours of initial receipt.
- **Initial Triage & Assessment:** Within 7 business days confirming validity and assigning severity (CVSS).
- **Remediation & Patch:** Target fix developed and verified within 14–30 days depending on complexity and release lifecycle.
- **Public Disclosure:** Coordinated release with reporter attribution following safe distribution of the patch.

## Security Architecture & Best Practices

Orvia incorporates multi-layered defense-in-depth protections:
- **Update Transport & Integrity:** Release manifests and update packages require strict SHA-256 verification and cryptographic signature validation prior to staging or execution.
- **Archive Extraction Boundary Enforcement:** ZIP updates strictly guard against Zip Slip path traversal vulnerabilities through canonical target path enforcement (`p.isWithin`).
- **Network Security:** Cleartext HTTP traffic is explicitly disallowed (`usesCleartextTraffic="false"`, `network_cfg.xml`). Core metadata, scrobbling, and geolocation APIs operate exclusively over verified HTTPS endpoints.
- **Plugin Sandboxing:** Rust-based plugin identifiers are restricted to strict alphanumeric, hyphen, and underscore characters to eliminate directory traversal across plugin extraction routines.
- **Least-Privilege File Sharing:** FileProvider configurations isolate private database and preferences directories, exposing only designated update and export staging paths.

