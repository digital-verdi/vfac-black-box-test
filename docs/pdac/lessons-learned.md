# PDAC lessons learned

- Kreo 2.1.3 plans an SSO/Rute deployment without Product secret inputs when its
  AI credential references Rute's serviceApiKey. Its Identity sign-in binding
  is varde-identity, not human-identity. Only configure model groups the
  deployed Rute actually offers: a published example may name standard, which
  might not be available in the target Project. Neither a copied gateway key nor a local OTP is needed.
- Kreo 2.1.3 validate/plan accept defaultModel or smallModel outside ai.models,
  despite the documented membership requirement. When deploying Kreo with this contract,
  use a reviewed repository-level model-membership guard. An observed
  deployment required the single-frontier form and no smallModel. This is
  evidence of missing early validation, not proof about runtime enforcement.
  Treat console SSO and public app publishing as separate acceptance tests;
  infrastructure readiness alone proves neither administrator role nor app access.

- Permanently retiring a Product means removing its registry entry before
  teardown, then removing its manifest and Product-specific invariants after
  SUCCEEDED. Otherwise a later generic deploy can create an empty replacement.
  Keep deletion as a temporary, exact-ID, manually dispatched maintenance step;
  restore ordinary deployment and remove its inputs and delete checks afterward.
  Preserve naming standards, Git history and shared services. An ACTIVE Resource
  does not override the user's finding that the application failed acceptance.

- Side-by-side Kode generations use distinct stable keys and separate service
  data. Keep the predecessor pinned and require NO_CHANGE with its original
  Resource ID before the generic apply/upgrade branches; availability of a newer
  release is not permission to upgrade the predecessor.
  On explicit retirement, exclude the predecessor from ordinary deployment
  before deleting it, then remove its manifest and protection guard after
  successful teardown. Otherwise a later push can recreate an empty service.
- Kode 6.1.0 GitHub App metadata belongs in PdAC, checked against the repository's
  GITHB_APP_NAME and GITHB_APP_ID variables. The published contract accepts no
  private-key setting: an administrator uploads the original PEM in Kode, chooses
  the installation and grants developer access. Keep GITHB_APP_PRIVATE_KEY_PEM
  out of the workflow environment; having a GitHub secret is not a supported
  Product secret input or permission to copy it into a manifest or artifact.
- Kode 6.2.0 adds explicit GitHub App key slots. An App naming slot1 requires
  githubAppSlot1PrivateKey beside both plan and apply; preserve the original PEM
  line breaks and never put the key in the manifest. Key validity in GitHub and
  installation/developer access are separate from the Resource readiness gate.
  An explicitly approved bootstrap used a temporary manual step in the existing
  workflow and a repository secret, rather than the guide's separate
  secret-workflow/environment pattern. Keep that exception scoped to bootstrap,
  remove its secret reference afterwards, and never resend the key on a push.

- A non-destructive Product upgrade can still change its log descriptor hash.
  Insights pinned to the predecessor descriptor then exclude new records. Check
  events, types, units and delivery semantics before revising filters. Keep IDs,
  calculations and dashboard references stable, explicitly label the cutover,
  and obtain human approval. Historical logs remain stored but are not silently
  combined with a different release's records.
- Published dashboards compute the approved insight revision, not an unapproved
  replacement draft. A successful dashboard preview during review therefore
  proves that existing published cards still work, not that the new filters are
  published. Preview drafts separately and verify approvedRevision and published
  dashboards again after human approval.

- Replacing Signal requires an application-configuration backup, not just a
  Product manifest. Preserve complete insight analyses, dashboard layouts and
  source/descriptor mappings before deleting the workspace. Recreated objects
  and reconnected sources receive new IDs; map them explicitly and obtain new
  human approvals. Configuration backup does not preserve log history.
- Signal provider replacement is two-phase for every logging consumer:
  disconnect log-workspace with its required logging setting disabled, wait for
  provider teardown, then connect the successor and restore the exact original
  logging settings. Identity, Rute, Kode and Scene keep their Resource identities.
  Ordinary deployment must be paused throughout the transition so it cannot
  reattach the predecessor or recreate a deleted workspace.
- Keep dashboard restoration below the released per-dashboard card limit.
  Split the AI gateway dashboard by traffic/performance and consumption/privacy,
  retaining card sizes and relative ordering rather than silently dropping cards.
- Restored hourly Signal analyses retain completed-hour semantics. Immediately
  after reconnection, rolling stat/grouped views can show new activity while
  hourly graphs still return no-data; ratio graphs may return no-match until a
  measured denominator exists. Keep that distinction instead of treating an
  empty graph as proof of broken forwarding or replacing unknowns with zero.
- Persist each newly created insight/dashboard ID before the next mutation.
  Read definitions back and compare against the source-mapped backup so a
  resumed restoration avoids duplicates and does not silently change metrics.

- A PdAC checkout can inherit a previously stored personal `vfac` session and
  context. Export the intended Context Gate variables before the
  startup checks so diagnostics describe the intended machine identity rather
  than an unrelated cached user identity.
- When `.env.vfac-read-access` is used as a gitignored local credential file for
  read access to the platform, never display or commit its values. Its presence
  does not mean a shell has exported the variables it contains, and its name
  does not replace checking the live grants with `vfac whoami`.
- A GitHub remote does not prove that CI/CD is configured. Check both committed
  workflow files and the repository's workflow inventory before relying on an
  automated deployment path.
- Repository variables and secrets can exist before any workflow consumes them.
  Inventory their names separately from confirming that a runnable deployment
  pipeline exists.
- Signal and Identity intentionally form a mutual dependency: Signal consumes
  Identity's `human-identity` and `directory` interfaces, while Identity sends
  logs to Signal's `log-workspace` interface. To remove the pair, first apply
  Identity with log forwarding disabled and `log-workspace` disconnected. Then
  disconnect or delete Signal, and only then delete Identity if both Resources
  are being removed. This avoids a provider deletion hold caused by the
  reciprocal connections.
- A Product version change plans as `UPGRADE_REQUIRED`; `apply` must not perform
  it as an implicit configuration update. The deployment workflow invokes the
  explicit lifecycle upgrade, waits for its Operation, and replans before the
  normal apply path. Post-deploy freshness is required only for a Resource that
  changed in the current run. An unchanged dependency can remain healthy and
  `READY` after its observation becomes `STALE`, so requiring global freshness
  makes unrelated deployments wait and fail without improving their safety.
- Rute consumes Identity's `human-identity` and `human-directory` interfaces
  and Signal's `log-workspace` interface. Disconnect or delete Rute before
  removing either provider. Its OpenRouter credential is needed only on create
  or deliberate rotation; normal PdAC convergence must remain secret-less.
- Kode consumes Rute's `serviceUrl` and credential `serviceApiKey` outputs,
  Identity's `human-identity` and `human-directory` interfaces, and Signal's
  `log-workspace` interface. Delete or disconnect Kode before removing any of
  those providers. Recreating Kode destroys its hosts, workspaces and stored
  data, releases its key only after the delete Operation succeeds, and creates
  a new Product Instance when the same manifest is applied again.
- Kode 5.0.0 could remain `FRESH + UNKNOWN` with
  `logForwarding: not_delivered_yet` after a successful create, causing the
  strict PdAC readiness gate to time out. A clean 5.0.1 create acknowledged the
  first forwarded batch during provisioning and reached `FRESH + READY`; keep
  the readiness gate strict so this regression remains observable.
- A Kode Resource on Product version `5.0.1` was retired after failing
  application acceptance. Reintroduce a retired Product only as an explicit
  deployment task against a version verified to address the observed
  problems; do not restore a retired manifest implicitly.
- Kode 5.1.0 verifies that the configured gateway model is one Rute actually
  publishes. Upgrade and wait for Rute before creating Kode; otherwise Kode can
  report `gateway_model_unknown` even when its output references resolve.
- Bootstrap, Product-secret rotation, Entra provisioning and destructive
  recreation are time-bounded maintenance operations, not permanent PdAC
  dispatch choices. Add the narrowly scoped operation for a reviewed task,
  remove it after successful verification and keep the durable workflow focused
  on secret-less convergence. A shared ordered Resource registry should drive
  deployment and readiness checks so adding a Product does not require another
  copy of the orchestration logic.
- Incompatible Rute and Kode generations must be replaced in dependency order:
  delete Kode before Rute, create and fully verify Rute before Kode, and only
  then switch the durable PdAC registry. Kode references Rute's `serviceUrl` and
  credential `serviceApiKey` outputs, so teardown or creation in the opposite
  order leaves an invalid dependency graph. Use new stable keys for the
  incompatible generation instead of trying to reuse deleted state.
- Rute 6.0.0 expresses a one-million-token promise with a custom
  `contextGuarantee` on the model group. Provider restrictions belong on the
  model entry: keep `only` and `order` identical so the guarantee and priority
  are explicit and reviewable. Rute can enforce context and an allowlist, but
  not a maximum OpenRouter price; verify provider prices immediately before a
  routing change when cost is part of the selection criteria.
- Kode 5.3.0 reads deployment-time `agentGateway` fields only on its first
  start. Changing them later does not update its internal gateway and produces
  `deployment_gateway_not_applied`. Add further Rute model groups through
  Kode's AI gateways page instead, unless destructive reconstruction is an
  explicit part of the task.
- Scene 5.0.0 declares no readiness conditions. Register an empty condition
  list and verify its lifecycle status and both Identity connections rather
  than inventing a sign-in condition. With `Varde Identity`, first-admin
  provisioning happens on the person's first SSO sign-in and needs no password.
  Disconnect or delete Scene before removing its Identity provider.
- Kode 6.0.0 replaces `agentGateway.model` with `models` and `defaultModel`;
  translate a single `frontier` into `models: [frontier]` and
  `defaultModel: frontier`. Unlike 5.3.0, this gateway configuration is managed
  on every start, so future model-list changes belong in PdAC rather than a
  manual gateway edit. Keep credentials as Resource-output references.
- During destructive replacement, temporarily remove both the old and new
  targets from ordinary push deployment. Otherwise a queued or later push can
  recreate a deleted predecessor or create a successor before teardown ends.
  The manual exact-ID operation owns replacement; restore only the new targets
  to the durable register after verification, then remove all temporary logic.
- Scene 5.1.2 offers `developer` and reports sign-in, directory and log-forwarding
  conditions. Its optional `log-workspace` binding enables service log forwarding
  without a configuration switch or Product secret. Require `logForwarding`
  readiness only when that binding is present; an unbound Scene may report
  `UNKNOWN / binding_not_ready` without a failed SSO deployment.
