# infra/gcp

Real-cloud Terraform for GCP (sibling of `infra/demo/`, the local vCluster
demo). Code-only for this assignment — reviewable and `terraform
validate`-clean, not meant to be `apply`'d against real GCP.

```
infra/gcp/
├── stage-links.sh              # copies each stage's provider.tf + tfvars from
│                                #   the previous stage's GCS outputs bucket
├── modules/
│   ├── vendir.yml               # declares which cloud-foundation-fabric modules
│   ├── vendir.lock.yml          #   to vendor and at which tagged ref — `vendir sync`
│   ├── fabric/                  # vendored output, committed, never hand-edited
│   │   └── modules/{net-vpc,net-vpc-firewall,net-cloudnat,cloudsql-instance,
│   │                gke-cluster-autopilot,iam-service-account,project,gcs}
│   ├── custom/                  # hand-authored — no Fabric equivalent exists
│   │   ├── cloudbuild-triggers/     # plan/apply trigger pair + GCS plan bucket
│   │   ├── vcluster/                # installs the vcluster Helm chart
│   │   └── flux-bootstrap/          # installs flux2 + initial GitRepository/Kustomization
│   └── wrappers/                # hand-authored, narrows a Fabric module's surface
│       ├── networking/              # thin wrapper: fabric net-vpc + net-vpc-firewall + net-cloudnat
│       ├── gke/                     # thin wrapper: fabric gke-cluster-autopilot
│       └── cloudsql/                # thin wrapper: fabric cloudsql-instance
│                                     # (no dns/ wrapper — DNS stays at GoDaddy, not GCP)
└── stages/
    ├── 0-bootstrap/             # Cloud Build GitHub connection, automation SAs,
    │                            #   state + outputs GCS buckets (home: nonprod project)
    ├── 1-cloudbuild/            # plan/apply trigger pair per downstream stage
    ├── 2-projects/              # adopts the two existing GCP projects (nonprod,
    │                            #   production) — project_reuse, no
    │                            #   folder hierarchy, no project creation
    ├── 3-networking/            # both VPCs + one reserved external IP per environment
    ├── 4-gke-nonprod/           # shared GKE Autopilot cluster (Test + Acceptance)
    ├── 4-gke-production/        # dedicated GKE Autopilot cluster
    ├── 5-databases/             # Cloud SQL + Ghost's per-environment GSA
    │                            #   (Workload Identity, scoped Secret Manager access)
    ├── 6-vcluster/              # vcluster Helm installs onto 4-gke-nonprod
    └── 7-flux-bootstrap/        # flux2 into vcluster-test/-acceptance and
                                  #   directly into 4-gke-production
```

## Why vendor instead of writing GKE/Cloud SQL/VPC from scratch

`GoogleCloudPlatform/cloud-foundation-fabric` already has reviewed, maintained
modules for exactly this (VPC with Private Service Access for Cloud SQL,
Cloud NAT, GKE Autopilot, Cloud SQL, IAM service accounts, project
adoption). Rewriting them would be re-deriving well-trodden GCP provider
quirks for no benefit. [vendir](https://carvel.dev/vendir/) makes the reuse
declarative and reviewable: `modules/vendir.yml` pins an exact tag,
`modules/vendir.lock.yml` pins the resolved commit SHA, and `vendir sync`
re-fetches deterministically — no manual copy-paste, no silent drift from
upstream.

The vendored tree is committed (vendir's own convention, matching a classic
vendor directory) so `terraform validate` needs no network access and the
single public repo stays self-contained. It's also never hand-edited — a
version bump means editing the `ref` in `vendir.yml` and re-running `vendir
sync`, not patching files in `fabric/`.

## Why thin wrappers instead of calling `fabric/` directly

Several stages need the same VPC/GKE/Cloud SQL shape with different
inputs (project, region, CIDRs). `modules/wrappers/{networking,gke,cloudsql}`
pin this project's naming and defaults once and expose only the inputs a
stage actually varies — Fabric's own modules have a much larger surface
(shared VPC, PSC, IPv6, factory-config, ...) that isn't relevant here. This
mirrors `CLAUDE.md`'s "environments are parameterized inputs to shared
modules, not copy-pasted per-env code." `wrappers/` is this repo's own
addition on top of the vendored/custom split below — it doesn't exist in
the Fabric FAST reference, which has its stages call `fabric/` directly.

`modules/custom/` holds the pieces with no Fabric equivalent: the Cloud Build
trigger pair and the two Helm-chart installers (`vcluster`, `flux-bootstrap`)
that install workloads onto a cluster rather than provision GCP resources.

## Why numbered stages instead of flat per-environment roots

Each stage is its own Terraform root: own state, own least-privilege
automation service account, own Cloud Build trigger pair, and its outputs
published to a GCS bucket for the next stage to consume via
`stage-links.sh` — the same pattern Google's own Fabric FAST reference
architecture uses. The numbering is the dependency order (`3-networking`
needs `2-projects`'s project IDs; `4-gke-*` needs `3-networking`'s VPC;
`7-flux-bootstrap` needs `6-vcluster`'s contexts for Test/Acceptance).

This repo's topology is a flat two-project split (`nonprod`, `production`),
not a multi-team org, so two stages from the usual Fabric FAST set don't
apply and are intentionally absent: no `1-resman` (nothing to build
a folder hierarchy for) and no `2-project-factory` (project-factory can only
*create* projects — it has no wired-through toggle for adopting existing
ones without forking the vendored module — so `2-projects` calls the plain
`project` module directly with `project_reuse = { use_data_source = true }`
instead).
