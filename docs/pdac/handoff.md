# PdAC handoff

> Operational handoff for PdAC changes. This is a reusable record, **not evidence of a current deployment**. Fill in the current Project, Resource identities, manifest paths, Operations, workflow runs and verification results from live state before acting. Placeholder values are not deployable configuration.

## Current status — three Product Instances live via PdAC

- Objective: run Identity — SSO, Rute — AI Gateway and Frende — AI Chat in
  Project `prj_01m4qqme1ve00a5e8swvf4dghc`, with Frende signing in through
  Identity and reaching Rute purely by Resource-output references.
- Deployed resources (all **ACTIVE**):
  - Identity — SSO `pri_01m5crw6b7e008b4jz1d67xbkk` (`box-shared-sso-prod`,
    `identity-sso` 5.0.0) — `signIn`, `directoryAccess`, `logForwarding`
    READY/FRESH.
  - Rute — AI Gateway `pri_01m5d4phq5e0084pp43kcfg1z5` (`box-shared-gw-prod`,
    `rute-ai-gateway` 6.3.0, `developer`) — `routingConfiguration` READY/FRESH.
  - Frende — AI Chat `pri_01m5d50wc9e009st89p1kb56cv` (`box-shared-chat-prod`,
    `frende-ai-chat` 4.0.0, `developer`) — `modelEndpoint` and `signInLockout`
    READY/FRESH. Its three prepared model choices carry the Varde mark
    (`iconURL: /assets/logo.svg`) instead of the default generic icon.
- Manifests and pipeline: `resources/{identity-sso,rute-ai-gateway,frende-ai-chat}.yaml`
  (templates); `.github/workflows/varde-flyt-deploy.yml` (permanent, ordered,
  secret-less; push to `main` and dispatch); `.github/scripts/`
  (`render-manifest.sh`, `lib.sh`, `deploy.sh`, and the maintenance tools
  `identity-sso-bootstrap.sh` / `app-bootstrap.sh`). No temporary bootstrap
  workflow remains.
- Session credential: read-only (OBSERVATION) Gate in
  `.env.vfac-cli-read-access` — `validate`/`plan`/inspect only. The pipeline
  deploys with the **separate** write Gate (`VFAC_CREDENTIAL_ID` +
  `VFAC_CREDENTIAL_SECRET`, identity `b-bx-github-actions`).
- Integrations: Rute and Frende bind `human-identity` + `human-directory` to
  `box-shared-sso-prod`; Frende's single endpoint reads Rute's `serviceUrl`, and
  its `modelProviderApiKey` reads Rute's `serviceApiKey` — both by
  `valueFrom.resourceOutput`, nothing copied by hand and no API key created.
- Verified: the permanent workflow ran green for all three — plan `NO_CHANGE`,
  `health` ACTIVE/converged, `secretsToWrite: []`, with the Identity guard clean
  before and after. An ordinary push therefore keeps every stored secret.
- Remains (human): a real interactive Entra sign-in to the Rute console and to
  Frende, the first-administrator role, and the browser-level functional checks.
  A direct Rute `/v1/*` call from an external client is a separate test that
  needs a console-issued application key — it is **not** part of this integration.
- Next safe action: perform the interactive checks, then enable the directory
  administration handover if desired.

## Current objective

Record the current deployment or replacement objective: Product, version, profile,
region, target Resource and any predecessor that must stay operational.
For a side-by-side Scene replacement, the new service starts with separate
service data; presentations, access grants, MCP authorizations and data are
not automatically migrated. Keep the predecessor operational and retire it
only in a separate, explicitly approved task.

## Configuration and files

- `resources/<product>/<successor-resource>.yaml` should be compared with the
  verified live predecessor configuration when cloning an existing Resource.
  Record intentional differences, such as `metadata.name`, `metadata.key`
  and `productVersion`; never assume those are the only differences.
- `.github/workflows/<pdac-workflow>.yml` should keep preflight and deploy.
  Record the actual ordered Resource registry and its dependencies, which may
  include Signal, Identity, Rute, Kode, Scene and Kreo. Check any Product
  administrator addresses against the applicable `INITIAL_EMAIL_ADDRESS`.
- A predecessor-preservation guard must run before any mutation and again
  before its apply/upgrade dispatch. It requires the original exact Resource
  ID, `NO_CHANGE`, `ACTIVE`, convergence and `secretsToWrite: []`.
  A changed, missing or replaced predecessor stops the run.
- Check the exact provider Resource IDs and applicable readiness conditions.
  Existing manifests and naming conventions must not change without a
  separately reviewed reason.

For a Scene deployment using Varde Identity, record the administrator,
retention, `slideNetworkAccess`, `human-identity`/`human-directory`
and `log-workspace` bindings from the published Product contract. Confirm
whether Product secrets or a local administrator password are required
rather than copying credentials from another Resource.

## Resource identities

Project: `<project-id>`, `<project-name>`.

| Resource | Resource ID | Version |
| --- | --- | --- |
| Target or successor | `<target-resource-id>` | `<target-version>` |
| Protected predecessor, if any | `<predecessor-resource-id>` | `<predecessor-version>` |
| Identity, if bound | `<identity-resource-id>` | `<identity-version>` |
| Signal, if bound | `<signal-resource-id>` | `<signal-version>` |
| Rute, if bound | `<rute-resource-id>` | `<rute-version>` |
| Kode, if bound | `<kode-resource-id>` | `<kode-version>` |
| Other dependencies, if any | `<resource-id>` | `<version>` |

Use live Resource IDs, not names or examples, for preservation and deletion
checks. Remove inapplicable rows when completing a task handoff.

## Verification and deployment

Use read-only Project access for local inventory and validation. Run
mutations only through a separately authorized Project-administrator gate,
where the deployment's access model requires it. Verify the effective
identity and grants before relying on them. For an Actions-based workflow,
review main-only execution, `contents: read`, step-scoped Gate Secret
and `cancel-in-progress: false`.

Before deployment, validate every manifest against the live platform and
record each plan. For a new Resource, confirm `CREATE`, correct bindings,
`requiredSecrets` and `secretsToWrite`. For protected predecessors,
require `ACTIVE`, converged `NO_CHANGE` and no secret writes.
Check for active Operations or competing workflows. Validate workflow syntax
(e.g. `actionlint` and `bash -n`) and test the guard's failure cases:
wrong identity/key, unhealthy or non-converged Resource, secret writes,
missing secret-write metadata and missing predecessor.

Where Signal is involved, inventory existing insights and dashboards before
and after deployment. Preserve IDs, titles, revisions, approval metadata,
complete definitions and existing source mappings unless their change is
explicitly in scope. Record any new source and descriptor hash. A connected
source or a `READY` forwarding condition is **not** proof that an actual
sign-in or application event was received; query for the event after activity.

Record the evidence from this task:

- Creation/change commit: `<commit-sha>`.
- Preflight and deployment workflow: `<workflow-run-id>`, `<result>`.
- Affected Resource Operation: `<operation-id>`, `<final-status>`,
  `<completion-time>`.
- Target lifecycle and readiness: `<status>`, `<conditions>`, and
  `<provider-connections>`.
- Unchanged predecessors: exact original IDs, `NO_CHANGE`, no secret
  writes and no newly created Operations for protected Resources.
- Subsequent ordinary workflow, if run: `<workflow-run-id>`, whether
  all plans converged and applies were skipped.

Do not add persistent manual dispatch choices, secret-handling steps or
deletion logic to ordinary convergence merely to complete a one-time task.

Published outputs (only when actually returned by the deployment):

- sceneUrl: `<published-scene-url>`
- mcpUrl: `<published-mcp-url>`
- instanceIdentifier: `<resource-id>`

## Remaining work and next safe action

For a new Scene service, functional verification may include human SSO,
first-administrator role, separate authorization of the new MCP address,
and creating, revising, viewing and reopening a test presentation.
After activity, confirm `person.signed_in` and presentation events in
the new Signal source. Mark what has actually been tested, what awaits
user acceptance, and which URLs must be given to the tester.

An existing MCP connection does not automatically authorize a successor
service. Do not retire the predecessor solely because infrastructure
is `READY` or a workflow succeeded. Its eventual deletion, removal
from the Resource registry and manifest removal belong to a separate,
explicitly reviewed task after acceptance. Keep the preservation guard
until that retirement is completed and verified.

## Rotation and recovery — Identity SSO / Entra

The permanent pipeline never touches Entra and never rotates a secret. Entra
provisioning, the Identity bootstrap, recovery and rotation are **time-bounded
maintenance operations**, run from a temporary workflow that is created for the
task and removed once it is verified.

To create one (for a reviewed task):

1. Add a temporary workflow — `workflow_dispatch` only, `permissions:
   contents: read`, `if: github.ref == 'refs/heads/main'`, and where possible an
   `environment` with a required reviewer. Give the single run step step-scoped
   `VFAC_CREDENTIAL_SECRET`, `ENTRA_APP_SECRET` and `INITIAL_EMAIL_SECRET`; it
   runs `bash .github/scripts/identity-sso-bootstrap.sh` with `MODE` set.
2. Run it, verify, then **remove the workflow** (the script stays as the
   maintenance tool).

`MODE` values:

- `bootstrap` — first deployment. Creates or reuses the target app
  `box-shared-sso-prod` (exact name; more than one match stops the run), mints a
  **180-day** client secret, deploys Identity step 1 (no `/entra`), registers the
  published `entraRedirectUri`, grants Graph `User.Read.All` +
  `GroupMember.Read.All` with admin consent and the OIDC scopes `openid profile
  email`, sets `Assignment required = No`, then deploys Identity step 2 with
  `/entra`. Idempotent: if Identity is already configured and `directoryAccess`
  is READY/FRESH, it does nothing.
- `recover` — after an interrupted bootstrap. An existing app is reused and a
  **new** secret is minted (the previous secret was never stored and cannot be
  read back from Graph).
- `rotate` — mint a new 180-day secret on the existing app and apply
  `/entra/clientSecret`. **After** a successful apply, remove the old password
  credential on the target app in Entra; the platform will not do it for you.

The target client secret is never written to a manifest, a log, an artifact or a
job output; it exists only in the running step and then in the platform. The
permanent `varde-flyt-deploy.yml` applies the manifest **without** any secret, so
the stored secret is kept (verified: plan `NO_CHANGE`, `secretsToWrite: []`).

A `403`/`401` on a Graph call you were never granted is access you do not hold —
report it and stop; do not widen anything. A missing Graph permission stops the
preflight before any app is created.

## Rotation and recovery — Rute / Frende

Rute's OpenRouter credential and Frende's web-search (Tavily) credential are
product secrets too, sent only by the temporary bootstrap
`.github/scripts/app-bootstrap.sh`.

- **First configuration.** Run it from a temporary, `workflow_dispatch`-only
  workflow on `main`, with step-scoped `VFAC_CREDENTIAL_SECRET`,
  `OPENROUTER_API` and `TAVILY_API_KEY`. It plans and applies with the **same**
  `--secret` inputs: Rute `openRouterApiKey` (a root secret — **no leading
  slash**), Frende `searchProviderApiKey`, sent only when Frende is a `CREATE`.
  Frende's scraper needs no separate key (search and scraper are the same
  provider, so `scraperApiKey` is not used).
- **Recovery.** The stable keys (`box-shared-gw-prod`, `box-shared-chat-prod`)
  mean a re-run reuses the existing resources: a secret-less `plan` that succeeds
  means the resource already holds its secret, so nothing is written.
- **Rotation.** A new OpenRouter key is a re-run with `openRouterApiKey`; a new
  Tavily key likewise with `searchProviderApiKey`. Nothing rotates automatically,
  and the permanent pipeline never sends a product secret.
- **Order matters.** Frende reads Rute's outputs, so Rute must converge first; a
  Frende `plan` before Rute exists answers `MANIFEST_REFERENCE_NOT_FOUND`.

The permanent pipeline refuses `CREATE`: first creation always belongs to a
temporary bootstrap, never to an ordinary push.
