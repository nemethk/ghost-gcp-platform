# Infrastructure as Code

All real GCP infrastructure is Terraform, under `infra/gcp/`. This document
covers the higher-level shape — how a change flows between stages, and how
one set of modules serves three environments without being copy-pasted
three times. For the detailed reasoning behind vendoring, the wrapper
modules, and the stage numbering, see
[`infra/gcp/README.md`](../infra/gcp/README.md) — this document doesn't
repeat that, it builds on top of it.

## Why Terraform, briefly

The assignment asks for infrastructure "managed from a consolidated
codebase." Terraform is the industry-standard way to satisfy that for GCP
specifically: declarative, plan-before-apply, and — the reason it matters
here — composable into small, reviewable modules rather than one large
script.

## Not hand-rolled: vendored modules

None of the GCP resource logic (VPC, GKE, Cloud SQL, IAM) is written from
scratch. It's vendored from Google's own [Cloud Foundation
Fabric](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric)
modules — reviewed, maintained, and already handling the non-obvious parts
(Private Service Access wiring, Autopilot-specific fields, IAM condition
syntax) correctly. `infra/gcp/modules/fabric/` is the vendored output,
pinned to an exact tag and committed to this repository (so `terraform
validate` needs no network access), never hand-edited — a version bump
means re-running the vendoring tool, not patching files.

A thin layer of **wrapper modules**
(`infra/gcp/modules/wrappers/{networking,gke,cloudsql}`) sits on top,
narrowing each Fabric module's much larger surface down to the handful of
inputs this project actually varies (project, region, CIDRs). This is
where this repository's own naming and defaults live — not duplicated
Fabric logic.

## Stages, not one flat root

Infrastructure is split into **eight numbered stages**
(`infra/gcp/stages/0-bootstrap/` through `7-flux-bootstrap/`), each its own
Terraform root with its own state file. The numbering is dependency order,
not an arbitrary convention:

```
0-bootstrap        Cloud Build GitHub connection, per-stage automation
                    service accounts, state + outputs buckets
     │
1-cloudbuild        plan/apply trigger pair for every stage below
     │
2-projects          adopts the two existing GCP projects
     │
3-networking        both VPCs, reserved external IPs
     │
     ├── 4-gke-nonprod        shared GKE cluster (Test + Acceptance)
     └── 4-gke-production     dedicated GKE cluster
              │
         5-databases          Cloud SQL per environment, Ghost's GSA
              │
         6-vcluster           vcluster Helm installs (Test + Acceptance only)
              │
         7-flux-bootstrap     Flux installed into every environment
```

**Why split at all, instead of one `terraform apply` for everything:** each
stage gets its own state, its own least-privilege automation service
account, and its own Cloud Build trigger pair. A change to networking
doesn't require re-planning the database layer, and — more importantly — a
mistake in one stage's automation service account can't reach resources
outside that stage's own narrow IAM grant. `infra/gcp/README.md` covers the
full permission-scoping detail.

## How one stage's output becomes the next stage's input

Each stage publishes its outputs to a GCS bucket after every successful
apply. The next stage down the dependency chain reads them back via
Terraform's `terraform_remote_state` data source — `3-networking`'s VPC
self-link becomes `4-gke-nonprod`'s network input, `4-gke-nonprod`'s
cluster reference becomes `6-vcluster`'s target, and so on. `infra/gcp/stage-links.sh`
automates pulling a stage's provider configuration and pinned variable
values from the previous stage's bucket, so Cloud Build never needs
hand-maintained state references baked into each stage.

```
3-networking  --apply-->  outputs bucket  --stage-links.sh-->  4-gke-nonprod
```

This is what keeps eight stages from becoming eight places to
hand-copy the same VPC ID or project number — it's read once, at the
source, and threaded through automatically.

## Environments are parameterized inputs, not forked code

Test, Acceptance, and Production don't get three copies of the Terraform
that provisions them. `5-databases`, for example, is a single root with a
`for_each` over the three environments — the CIDR ranges, machine tier, and
naming differ per environment because they're **inputs**, the module logic
underneath is identical. The one deliberate exception is topology itself:
`4-gke-nonprod` and `4-gke-production` are two separate stages, not one
parameterized module, because Production's dedicated-cluster shape is a
structurally different decision from Test/Acceptance's shared-cluster
shape — see [ARCHITECTURE.md](ARCHITECTURE.md) §2 for why.

## What Terraform does *not* own

Terraform provisions the GKE clusters, the vClusters, and installs Flux
into each of them — once. From that point on, everything under `gitops/`
is exclusively Flux's territory; re-running `terraform apply` never touches
a live application deployment. See [AUTOMATION.md](AUTOMATION.md) for the
full boundary and [FLOW.md](FLOW.md) for how a change actually reaches a
running environment end to end.

## Deliverable note: code-only for this assignment

This Terraform is written to be reviewed and to pass `terraform validate`
cleanly — it is **not** meant to be `apply`'d as part of this assignment
(no real GCP billing account is being spent against it). The local demo
(`infra/demo/`) is the actual working, runnable proof of the deployment
mechanism — see [DEMO.md](DEMO.md).
