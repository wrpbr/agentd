# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in agentd, please report it responsibly.

Open a private security advisory on GitHub via the [Security tab](https://github.com/wrpbr/agentd/security/advisories/new).

Please include:

- Description of the vulnerability
- Steps to reproduce
- Affected versions
- Potential impact

Include a minimal reproduction with synthetic inputs. Remove credentials,
private commands, and local paths from attachments before sharing them.

## Trust boundary

Safeguard evaluates known patterns and configured rules. It is not an OS
sandbox and cannot constrain processes that bypass the host agent's hooks.
Keep the agent's filesystem, network, and credential capabilities scoped.
Catalog integrity checks detect changes relative to a trusted catalog; they
do not establish that every rule in a catalog is safe or complete.

## Scope

The following are in scope:

- Bypass of hook enforcement (tool calls executing without policy evaluation)
- Daemon socket permission issues allowing unauthorized access
- Rule engine regex denial-of-service (catastrophic backtracking)
- Catalog package integrity bypass (SHA256 check circumvention)
- Information disclosure through audit logs or state files

The following are out of scope:

- Issues in Claude Code itself (report to Anthropic)
- Issues in bats-core test framework (report upstream)
- Social engineering or phishing

## Supported Versions

| Version | Supported |
|---------|-----------|
| main branch (source install) | Yes |
| Older commits | Best effort |

## Disclosure Policy

We follow coordinated disclosure. Please allow up to 90 days for a fix before public disclosure.
