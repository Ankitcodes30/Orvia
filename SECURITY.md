# Security Policy

## Supported versions

Security fixes are applied to the latest `3.x` release and the `main` branch.
Older releases are not supported.

## Report a vulnerability

**Do not open a public issue for a security vulnerability.**

Preferred: use GitHub's private vulnerability reporting:

<https://github.com/Ankitcodes30/Orvia/security/advisories/new>

Fallback: email **ankitkumbhare301@gmail.com** with the subject
`Orvia security report`.

Include:

- A clear description of the issue and its impact.
- Affected version, platform, and component.
- Reproduction steps or a proof of concept.
- Relevant logs or screenshots, with secrets and personal data removed.
- Whether you want public credit.

Do not include live API keys, signing material, or other people's data.

## What to expect

- Acknowledgement target: within 3 business days.
- Initial triage target: within 7 business days.
- We will confirm the issue, discuss a fix, and coordinate disclosure.
- There is no bug bounty program; fixes and credit are provided on a best-effort
  basis.
- Please allow reasonable time for a fix before public disclosure.

## Scope

In scope:

- Orvia application code in this repository.
- The Rust plugin runtime, installer, and bridge.
- Local data handling, backup/restore, and import/export.
- Release workflow and distributed build configuration.
- Plugin sandbox escapes or host-boundary issues.

Out of scope:

- Vulnerabilities in third-party plugins that do not cross the Orvia host
  boundary. Report those to the plugin publisher.
- Vulnerabilities in upstream Flutter, Rust, Isar, or other dependencies that are
  already fixed upstream.
- Issues that require a rooted device, physical access, or a modified app build.
- Social engineering, spam, or denial-of-service against third-party services.

## Security model and known limitations

- Plugins run as WebAssembly components in a Rust host. They have no direct
  filesystem or database access; network access goes through the host HTTP
  function, and storage is scoped per plugin.
- Plugin packages are **not** signature-verified by the in-repo installer.
  `publisher.key_id` is metadata only. Repository trust and HTTPS are the current
  distribution boundary.
- Plugin API keys are masked in the UI but stored in the local app database. They
  are not hardware-backed secrets.
- Android release APKs are signed and verified by the release workflow. Windows
  and Linux artifacts are not code-signed by that workflow, and the workflow does
  not publish checksums. Verify provenance from the official release page.
- The app is experimental. Treat plugin compatibility and security guarantees as
  evolving.

## Safe harbor

We will not pursue legal action for good-faith research that:

- Stays within your own accounts and devices.
- Avoids accessing, modifying, or deleting other people's data.
- Avoids disrupting services or other users.
- Gives us a reasonable opportunity to fix the issue before disclosure.

## Related documents

- [Contributing](CONTRIBUTING.md)
- [Plugin security model](docs/plugins/overview.md#security-model)
- [Plugin packaging security](docs/plugins/manifest-and-packaging.md#security)
- [Release process](docs/operations/release.md)
