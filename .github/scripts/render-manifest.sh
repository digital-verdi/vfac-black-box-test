#!/usr/bin/env bash
#
# Render resources/identity-sso.yaml, substituting the tenant-specific,
# non-secret values that come from the GitHub Actions configuration:
#   ADMIN_EMAIL       <- vars.INITIAL_EMAIL_ADDRESS
#   ENTRA_TENANT_ID   <- vars.ENTRA_TENANT_ID
#   ENTRA_CLIENT_ID   <- vars.TARGET_ENTRA_APP_ID
#
# No secret is ever rendered: the one-time password and the Entra client secret
# travel beside the manifest as `--secret NAME=env:VAR`.
#
# Usage: render-manifest.sh [template] [output] [with_entra: true|false]
# `with_entra=false` drops the `entra:` group, producing the product's published
# step-1 bootstrap manifest.
set -euo pipefail

tpl="${1:-resources/identity-sso.yaml}"
out="${2:-/tmp/resource.yaml}"
with_entra="${3:-true}"

python3 - "$tpl" "$out" "$with_entra" <<'PY'
import os, sys
tpl, out, with_entra = sys.argv[1], sys.argv[2], sys.argv[3] == "true"
lines = open(tpl, encoding="utf-8").read().splitlines(keepends=True)
docs, skip = [], False
for ln in lines:
    if "# vfac-bootstrap:entra:begin" in ln: skip = True; continue
    if "# vfac-bootstrap:entra:end" in ln: skip = False; continue
    if skip and not with_entra: continue
    docs.append(ln)
text = "".join(docs)
for key in ("ADMIN_EMAIL", "ENTRA_TENANT_ID", "ENTRA_CLIENT_ID"):
    text = text.replace("${%s}" % key, os.environ.get(key, ""))
open(out, "w", encoding="utf-8").write(text)
PY
