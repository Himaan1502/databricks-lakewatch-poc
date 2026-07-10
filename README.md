# Databricks Lakewatch — Azure Workspace Foundation

Terraform to stand up a **Lakewatch-ready** Azure Databricks workspace, then the
Unity Catalog data landing zone for the PoC. Lakewatch itself is enabled by
Databricks (private preview) — this gets your account/workspace qualified and ready.

> **CI/CD:** state lives in an Azure Storage backend (`backend.tf` in each stage),
> and GitHub Actions in `.github/workflows/` run `plan` on PRs and a gated
> `apply`/`destroy`, reusing the same service principal as the observability
> pipeline. See `CICD.md`. Stage 2 reads Stage 1 from remote state, so no manual
> value copying. For a purely local run, `terraform init -backend-config=backend.hcl`.

## What Stage 1 creates
- Premium Azure Databricks workspace (required for Unity Catalog + security features)
- VNet injection with two delegated subnets + NSG
- Secure cluster connectivity (no public IP on compute)
- ADLS Gen2 storage (hierarchical namespace) as the security telemetry landing zone
- Databricks Access Connector (managed identity) + Storage Blob Data Contributor role

New Azure workspaces are **Unity Catalog-enabled automatically**, so UC comes on with
the workspace.

## Prerequisites
- Terraform >= 1.5, Azure CLI
- `az login` as a user with Contributor + User Access Administrator on the subscription
  (the role assignment needs UAA or Owner)
- **First-time only:** the first person to sign in to the Databricks *account* console
  must be a Microsoft Entra ID Global Administrator. After that, add normal account admins.

## Run order

```bash
# Stage 1 — workspace + storage + networking
cd 1-workspace
cp backend.hcl.example backend.hcl             # reuse your existing state SA
cp terraform.tfvars.example terraform.tfvars   # then edit values
terraform init -backend-config=backend.hcl
terraform plan
terraform apply

# Grab the details for the email:
terraform output
```

```bash
# Stage 2 — Unity Catalog landing zone (run when you start the PoC)
cd ../2-unity-catalog
cp backend.hcl.example backend.hcl              # same state SA as Stage 1
cp terraform.tfvars.example terraform.tfvars    # state coordinates (not Stage 1 outputs)
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Stage 2 reads Stage 1's outputs from remote state automatically — you no longer
paste workspace/connector values by hand.

## After Stage 1 — three console checks (account/workspace admin)
These are Lakewatch prerequisites that live in settings, not Terraform:
1. **Serverless** compute is enabled (on by default in most regions).
2. **Genie / AI features** are enabled for the workspace.
3. **Unity Catalog metastore** is assigned to the workspace's region. There is one
   metastore per region per account — if the region already had one, the workspace is
   attached to it; if not, create/assign one in the account console (Catalog settings).

## The one detail Terraform can't output: your Databricks Account ID
Get it from the account console at **accounts.azuredatabricks.net** — click your
profile (top right); the account ID is shown there. Include it in the email.

## Details to send Ashish (map to `terraform output`)
- Databricks Account ID — from the account console (above)
- Workspace name — `workspace_name`
- Workspace URL — `workspace_url`
- Workspace ID — `workspace_id`
- Azure region — `location`
- Azure subscription ID — the one you deployed into
- Resource group — `resource_group`

## Notes / hardening
- To fully lock down networking, set `public_network_access_enabled = false` and add
  front-end + back-end Private Link endpoints with private DNS (not included here).
- Consider running the Security Analysis Tool (SAT) against the workspace and applying
  the Databricks AI Security Framework (DASF) — both are referenced on the Lakewatch page.
- Pin/upgrade providers to current versions: `terraform init -upgrade`. Argument names can
  shift across provider majors; validate with `terraform plan` before applying.
