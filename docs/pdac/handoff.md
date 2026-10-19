# PdAC handoff

> Operational handoff for PdAC changes. This is a reusable record, **not evidence of a current deployment**. Fill in the current Project, Resource identities, manifest paths, Operations, workflow runs and verification results from live state before acting. Placeholder values are not deployable configuration.

## Current status — bootstrap, no deployment

- Objective: bootstrap this repository for Varde Flyt PdAC work. No deployment or
  change has been requested; the deployment playbook is reference only.
- Project: `prj_01m4qqme1ve00a5e8swvf4dghc` — name `vfac-black-box`, status
  `ACTIVE` — selected in the local `vfac` context (from the repository's
  `VFAC_PROJECT_ID`), and verified live with `vfac project show`.
- Resources deployed: **none**. `vfac get product-instances --output json`
  returns an empty list, so this Project holds no Product Instances and there are
  no Resource or Operation ids to find.
- Session credential: a read-only (OBSERVATION) Context Gate, read from the
  gitignored `.env.vfac-cli-read-access`. It discovers, validates, plans and
  inspects; it **cannot apply and cannot run a lifecycle command** — that refusal
  is the grant working, not a fault.
- Manifest and pipeline files touched: none. No `resources/` manifest and no CI
  workflow (`.github/workflows/`, GitLab, Jenkins, …) is committed here.
- CI/CD: the repository is on GitHub; no workflow is committed (`gh workflow
  list` is empty), so there is **no runnable deployment pipeline yet**, even
  though the GitHub repository already carries Actions variables and secrets
  (below). A GitHub remote does not prove CI/CD is wired up.
- Verified: `vfac 0.18.3` (the current release) is installed; `vfac doctor`,
  `vfac guide` and `vfac whoami` succeed with the read gate against the
  organization's endpoint; a Varde Flyt MCP server is connected and answers.
- Where ids, configuration and secrets live: the endpoint and read gate in the
  gitignored `.env.vfac-cli-read-access`; **GitHub Actions repository variables**
  — `VFAC_ENDPOINT`, `VFAC_CREDENTIAL_ID`, `VFAC_PROJECT_ID`, `ENTRA_APP_ID`,
  `ENTRA_TENANT_ID`, `INITIAL_EMAIL_ADDRESS`; **GitHub Actions repository
  secrets** — `VFAC_CREDENTIAL_SECRET`, `ENTRA_APP_SECRET`,
  `INITIAL_EMAIL_SECRET`, `MISTRAL_API_KEY`, `OPENROUTER_API`, `TAVILY_API_KEY`.
  Names only — no secret value was read. The Gate a deployment workflow would use
  (`VFAC_CREDENTIAL_ID` + `VFAC_CREDENTIAL_SECRET`) is a Project-administrator
  gate, **separate from this session's read gate**.
- Remains before a deployment could run: a write-capable (Project-administrator)
  Gate for whoever deploys; at least one committed manifest; a CI/CD workflow that
  runs the same `validate → plan → apply` path over it; and the Product secret
  values kept only in GitHub Actions repository secrets.
- Next safe action: wait for a task that names the deployment. This read gate can
  read the catalogue, `validate` and `plan`, but it cannot `apply` or run
  lifecycle; deploy through the repository's separate write gate.

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
