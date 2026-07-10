# CI/CD — GitHub Actions

Mirrors the observability pipeline: existing service principal (**client-secret**,
`ARM_*` env vars, no `azure/login` step), an **azurerm remote-state backend**, and
two workflows — `terraform-plan` (plan on PRs) and `terraform-apply` (gated manual
`apply`/`destroy`). Stage 2 reads Stage 1 via remote state, so the pipeline chains.

## Reusing the same credentials

You already created the SPN, the state storage account, and the `azure-poc`
environment for observability. Reuse all of them:

- **Same repo as observability?** The repo variables and the `AZURE_CLIENT_SECRET`
  secret are already set. You only add **one** new variable: `LW_STORAGE_ACCOUNT_NAME`.
  Also **rename these two workflow files** (e.g. `lakewatch-plan.yml`,
  `lakewatch-apply.yml`) so they don't clobber the observability workflows — the
  `paths:` filters are already scoped to `1-workspace/**` and `2-unity-catalog/**`,
  so both pipelines coexist cleanly.
- **New repo for Lakewatch?** Re-set the same variables + secret on the new repo
  (identical values). Because the SPN is subscription-scoped, it already has the
  Azure rights — nothing new to grant except the Unity Catalog role below.

### Repo variables (non-secret)
- `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`  *(reused)*
- `TF_STATE_RG`, `TF_STATE_SA`, `TF_STATE_CONTAINER`  *(reused)*
- `LW_STORAGE_ACCOUNT_NAME` — **new.** Globally-unique ADLS Gen2 account name for
  the telemetry landing zone (3–24 lowercase alphanumeric).

### Repo secret
- `AZURE_CLIENT_SECRET`  *(reused)*

```bash
# the only new variable to set:
gh variable set LW_STORAGE_ACCOUNT_NAME -b "clbllakewatchtel01" -R your-org/your-repo
```

## State isolation
Both stacks use **distinct state keys** (`lakewatch-workspace.tfstate`,
`lakewatch-uc.tfstate`) set in each `backend.tf`, so they can live in the same
state storage account/container as observability without collision. Prefer this
directory-based isolation over a long-lived parallel branch — see the branch note.

## The one new SPN requirement (most likely Stage 2 failure)
Stage 1 (Azure resources) works with the SPN's existing **Contributor** on the
subscription and **Storage Blob Data Contributor** on the state SA. Stage 2 creates
**Unity Catalog** objects (storage credential, external location, catalog), which
requires the SPN to be a **Unity Catalog metastore admin** (or hold CREATE
STORAGE CREDENTIAL / EXTERNAL LOCATION / CATALOG). Add the SPN as a metastore admin
in the account console (Catalog settings) before the first Stage 2 apply.

## Triggering
- **Plan:** opens automatically as a status check on any PR touching
  `1-workspace/**`, `2-unity-catalog/**`, or the workflows. Stage-2 plan only
  succeeds once Stage 1 has been applied at least once.
- **Apply / Destroy:** Actions → **terraform-apply** → *Run workflow* → pick
  `apply` or `destroy`, then approve the `azure-poc` environment gate. Apply runs
  stage 1 → 2; destroy runs 2 → 1.

## Branch note
Consistent with the trunk-based model: develop this on your new feature branch,
open a PR (plan runs), merge, then run `terraform-apply`. The stack is isolated by
its own state keys, so it doesn't clash with observability. If you also want plan
to run on direct pushes to your branch, add to `terraform-plan.yml`:

```yaml
on:
  push:
    branches: [ your-branch-name ]
  pull_request:
    paths: [ ... ]
```

> If you put this in a **subdirectory** of a shared repo rather than the repo root,
> prefix the `paths:` filters and the `working-directory:` values accordingly.
