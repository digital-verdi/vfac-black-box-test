# vfac-black-box-test

**From intent to infrastructure. With control.**

An open demonstration of **Product Deployment as Code** (PdAC) on **Varde Flyt AI
Cloud** — part of the platform's demo for potential partners and investors.

An AI agent proposes a change, Git versions it, and `vfac` validates, plans and
submits the deployment. The Control Plane provisions the resources. Every change is
reviewable before it happens.

### Target picture

```text
   ┌──────────────┐
   │   AI AGENT   │  reads the live platform, proposes a change
   └───────┬──────┘
           │
           ▼
   ┌──────────────┐
   │    GITHUB    │  versions the Product Instance manifest
   └───────┬──────┘
           │
           ▼
   ┌──────────────┐
   │     vfac     │  validate · plan · apply — the one control surface
   └───────┬──────┘
           │
           ▼
   ┌──────────────┐
   │   CONTROL    │  Varde Flyt AI Cloud — products are chosen
   │    PLANE     │  from the catalogue; provisions the resources
   └───────┬──────┘
           │
           ▼
   ┌──────────────┐
   │     YOUR     │  Product Instances — the resources you own
   │   PROJECT    │
   └──────────────┘
```

*Identity — SSO is deployed through exactly this path today — see Status.*

## Status

- **Live now.** Three Product Instances are deployed in the demo Project and kept
  converged by the pipeline on every push to `main` — **Identity — SSO**, **Rute —
  AI Gateway** and **Frende — AI Chat**. Frende signs people in through Identity
  and reaches Rute purely by Resource-output references.
- **Pending.** Interactive Entra sign-in and the browser-level functional checks;
  everything the published interfaces allow is automated.

## Explore

- [resources/identity-sso.yaml](resources/identity-sso.yaml),
  [resources/rute-ai-gateway.yaml](resources/rute-ai-gateway.yaml),
  [resources/frende-ai-chat.yaml](resources/frende-ai-chat.yaml) — the committed
  Product Instance manifests (templates; tenant values are rendered from the
  pipeline configuration, and no secret is ever in them).
- [.github/workflows/varde-flyt-deploy.yml](.github/workflows/varde-flyt-deploy.yml)
  — the declarative pipeline: an ordered resource list, `validate → plan → apply
  --wait`, carrying no product secret.
- [AGENTS.md](AGENTS.md) — how the agent that works in this repository is instructed.
- [docs/pdac/handoff.md](docs/pdac/handoff.md) — the current handoff record, plus
  the rotation and recovery procedure for the Entra service.
- [docs/pdac/lessons-learned.md](docs/pdac/lessons-learned.md) — Product-specific
  gotchas, written down once.
- [docs/pdac/cli-quickstart.md](docs/pdac/cli-quickstart.md) — the operator path:
  install, sign-in, `validate`/`plan`/`apply`, and how secrets are passed.
- [docs/standards/naming-conventions.md](docs/standards/naming-conventions.md) and
  [docs/standards/resource-abbreviations.md](docs/standards/resource-abbreviations.md)
  — naming guidance (non-normative).

For the platform's own, authoritative instructions, run `vfac guide`. Platform:
<https://dv-preview.cloud.vardeflyt.no>
