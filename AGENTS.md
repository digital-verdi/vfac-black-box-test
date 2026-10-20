# AGENTS.md

## What this repo is

Repository for **Varde Flyt**, demonstrating **Product Deployment as Code**
(PdAC): the agent context and docs, the committed Product Instance manifest(s)
under `resources/`, and the GitHub Actions pipeline under `.github/workflows/`
that deploys them. There is still no application source code, package manifest,
build, tests, or lint — do not invent or run build/test tooling.

## Layout

- `resources/identity-sso.yaml` — the committed manifest **template** for the
  Identity SSO Product Instance. Tenant-specific, non-secret values are rendered
  from GitHub Actions config; never add a secret to it.
- `.github/workflows/varde-flyt-deploy.yml` — the permanent declarative pipeline
  (push to `main`). `.github/scripts/` holds the manifest renderer and the
  one-off Entra/Identity maintenance tool.
- `docs/pdac/handoff.md` — reusable handoff template, mostly `<placeholder>` /
  `<resource-id>` tokens. It is **not** evidence of a current deployment; never
  treat placeholders as real IDs or deployable configuration.
- `docs/pdac/lessons-learned.md` — accumulated Product-specific gotchas
  (Rute/Kode/Scene/Signal/Identity/Kreo). Read before any Varde Flyt work;
  append new findings here.
- `docs/pdac/cli-quickstart.md` — the operator path: install, sign-in,
  `validate`/`plan`/`apply`, and how secrets are passed.
- `docs/standards/*` — naming guidance (see below).
- `README.md` — the public entry page for the demo. Keep it short and accurate;
  it is not the place for operator detail.

## Varde Flyt PdAC workflow

- Start every session with `vfac doctor`, `vfac guide` and `vfac whoami`, in that
  order. `vfac guide` is served by the deployment and is authoritative for how
  the platform behaves now.
- Platform and Product knowledge comes from the Varde Flyt MCP server when one is
  configured, and from `vfac guide` when not. State and actions always come from
  `vfac`. Record no MCP address, token, or client configuration here.
- Select a Project (`vfac context set --project prj_…`) before any Product
  command, and read the Product id, version, region, service profile,
  configuration, dependencies and outputs from the platform on every run — never
  hardcode them, and never write them into these files.
- Pass secrets only as `--secret NAME=env:VARIABLE`, only on a run that sets one
  (first deploy, first use of a setting, or a rotation). Never put a Gate Secret,
  another secret value, or a copied credential output in a manifest, a prompt, or
  any committed file.
- `npm install -g @varde-flyt/vfac` installs the CLI; in this image the global npm
  prefix is not writable by the agent user, so the install needs `sudo`.
- Deployment configuration lives in **GitHub Actions repository variables** and
  its secrets in **GitHub Actions repository secrets**; the permanent pipeline
  `.github/workflows/varde-flyt-deploy.yml` consumes them on every push to
  `main`. Refer to a secret by name only; never read its value. Its Gate is
  separate from any session credential.
- Nothing here is platform truth: read the live Project, Product and Resource
  state again before acting on anything these files say.

## Doc conventions that are easy to get wrong

- `naming-conventions.md` and `resource-abbreviations.md` are explicitly
  **non-normative** (the platform does not read or validate them). Do not
  restate them as enforced rules.
- The real rule is display-name vs ID: display names are mutable; platform IDs
  (`ten_`, `prj_`, `prd_`, `pri_`, `op_`) are immutable identity. Never derive
  auth, ownership, or automation identity from a display name.
- Relative links such as `../../CONVENTIONS.md`, `../../SECURITY.md` and
  `../index.md` point outside this repo. Those files are not present — do not
  "fix" the links by creating stubs.
- Prose is English; `.gitignore` comments and Product vocabulary (Varde Flyt,
  Rute, Kode, Scene, Signal, Identity, Kreo) are Norwegian.

## Secrets

- `.env` and `.env.*` are gitignored. A gitignored `.env.vfac-cli-read-access`
  holds this Project's read-only CLI Context Gate (source it to authenticate
  `vfac`); never display, echo, or commit its values.
- The docs repeat as a hard rule: never place credentials, GitHub App PEM
  private keys, or Product secrets in a manifest, workflow env, artifact, or
  name.

## Commits

- Substantive changes use conventional-commit prefixes (e.g.
  `docs(pdac): add generic handoff and lessons learned`). Keep shared history
  intact; do not rewrite it.
