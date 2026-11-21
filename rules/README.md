# Extension catalog

This directory contains optional extension packages. Built-in enforcement
remains in the native runtime and is not downloaded from this catalog.

`catalogs/github-core.json` indexes versioned manifests using relative URLs
and SHA256 digests. Initial policy setup attempts a metadata sync.
Package installation is explicit; refresh the catalog with:

```bash
agentd --catalog-sync
agentd --catalog-install agent-governance-core
agentd --catalog-install secret-exfiltration-defense
agentd --catalog-install production-db-defense
agentd --catalog-install supply-chain-defense
agentd --catalog-install mcp-tool-defense
systemctl --user restart safeguard.service
```

The starter package contains one executable command rule (`910100`) and one
metadata-only rule (`910101`). Metadata alone does not enforce a decision.
For offline use, point `SAFEGUARD_DEFAULT_CATALOG_URL` at an absolute local
catalog path before the first invocation.

When editing a manifest, update its digest in the catalog and exercise the
real daemon with both matching and allowed inputs. The `schema` identifiers
in governance skill outputs describe their local document formats; they are
not remote services.
