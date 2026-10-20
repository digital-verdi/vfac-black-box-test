# vfac CLI quickstart

The operator path for deploying a Varde Flyt Product. `vfac guide` is the
platform's own, authoritative version of this — read it in the target Project.

> State and actions come from `vfac`; platform and Product knowledge also comes
> from the Varde Flyt MCP server when one is connected. Never hardcode a Product
> id, version, region, service profile, configuration or output — read it from the
> platform on every run.

## Sign in

```bash
export VFAC_ENDPOINT=https://<organization>.cloud.vardeflyt.no
export VFAC_CREDENTIAL_ID=cg_...            # the Gate Key id — an identifier
export VFAC_CREDENTIAL_SECRET=...           # a secret; never log, commit or paste it

npm install -g @varde-flyt/vfac
vfac doctor          # endpoint, Project, API, sign-in — first thing to run
vfac guide           # the platform's own instructions, served by the deployment
vfac whoami          # what this credential may do, and where

vfac project list
vfac context set --project prj_...
```

A credential whose permissions in a Project all end in `.read` is an OBSERVATION
credential: it can discover, `validate`, `plan` and inspect, and it can apply
nothing and run no lifecycle command. This repository's agent holds one; an
`apply` needs a Project-administrator Gate.

## The three verbs

```bash
vfac validate -f resource.yaml
vfac plan     -f resource.yaml --output json
vfac apply    -f resource.yaml --wait
```

- `validate` checks the document alone — it does not say whether a deployment
  would succeed.
- `plan` describes the deployment: read its `action` (`CREATE`, `UPDATE`,
  `NO_CHANGE`, `UPGRADE_REQUIRED`, `RECREATE_REQUIRED`) and the Resource's
  `health`.
- `apply` performs it. `--wait` waits for the Operation to settle and exits
  non-zero if it fails.

**Decide from the action a plan reports, not from the exit code.** A plan that
REFUSES still exits `0`; a non-zero exit is a real failure — read both. And
`NO_CHANGE` means "nothing needed applying", never "it works": check that the
Resource converged.

## Secrets

A secret is passed beside the manifest, never inside it, and only on a run that
sets one — the first deployment, the first use of a setting, or a rotation. `NAME`
is the setting's name, or its path when it sits inside a group.

```bash
vfac plan  -f resource.yaml --secret /group/setting=env:VARIABLE --output json
vfac apply -f resource.yaml --secret /group/setting=env:VARIABLE --wait
```

Plan with the same `--secret` inputs the apply will carry. An ordinary push
carries none.

## Follow the operation

```bash
vfac get operations --resource pri_...
vfac get operation op_...
```

Read `phase` (queued/working/succeeded/failed), the `steps`, and on failure
`failure.cause`, `failure.code` and `failure.retryable`.

## Lifecycle

```bash
vfac lifecycle suspend|resume|upgrade|reconcile|delete pri_...
```

`delete` is irreversible and needs `--yes`.

## In this repository

The committed manifest is `resources/identity-sso.yaml` — a template rendered by
`.github/scripts/render-manifest.sh` from GitHub Actions configuration (no secret
is ever in it). The pipeline `.github/workflows/varde-flyt-deploy.yml` runs
`validate → plan → apply --wait` on every push to `main`, carries no product
secret, and therefore converges without redeploying. The deployed state and the
Entra rotation/recovery procedure are in `docs/pdac/handoff.md`.
