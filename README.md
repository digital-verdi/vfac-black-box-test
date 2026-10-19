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

*The manifest and the deploy workflow are this repository's next step — see Status.*

## Status

- **Inspect now.** How the agent is instructed ([AGENTS.md](AGENTS.md)), the naming
  guidance ([docs/standards/](docs/standards/naming-conventions.md)), and the
  operational record ([docs/pdac/handoff.md](docs/pdac/handoff.md),
  [docs/pdac/lessons-learned.md](docs/pdac/lessons-learned.md)).
- **Next demonstration.** A committed **Product Instance manifest** and a GitHub
  Actions workflow that runs `vfac` over it. Neither is committed yet, and the demo
  Project currently holds no deployed Resources.

## Explore

- [AGENTS.md](AGENTS.md) — how the agent that works in this repository is instructed.
- [docs/standards/naming-conventions.md](docs/standards/naming-conventions.md) and
  [docs/standards/resource-abbreviations.md](docs/standards/resource-abbreviations.md)
  — naming guidance (non-normative).
- [docs/pdac/handoff.md](docs/pdac/handoff.md) — the current handoff record:
  objective, state and next safe action.
- [docs/pdac/lessons-learned.md](docs/pdac/lessons-learned.md) — Product-specific
  gotchas, written down once.
- [docs/pdac/cli-quickstart.md](docs/pdac/cli-quickstart.md) — the operator path:
  install, sign-in, `validate`/`plan`/`apply`, and how secrets are passed.
- **Workflows** — none committed yet, so there is no pipeline to run here today.

For the platform's own, authoritative instructions, run `vfac guide`. Platform:
<https://dv-preview.cloud.vardeflyt.no>
