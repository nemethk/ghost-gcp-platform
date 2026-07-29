# Automation: Cloud Build + Flux

Two automation engines, each owning a different half of "end-to-end
deployment," and never overlapping:

```
Terraform + Cloud Build  →  provisions infrastructure
                             (projects, network, GKE, Cloud SQL,
                              the vCluster and Flux installs themselves)

Flux                     →  delivers the application
                             (Ghost's Helm chart, platform controllers,
                              everything under gitops/)
```

Cloud Build creates the target (a GKE cluster, a vCluster) and installs
Flux into it — once. From that point on, Flux owns every deploy to that
target, forever. Re-running `terraform apply` is idempotent against Flux's
*installation*; it never touches anything Flux manages. There's no GitHub
Actions anywhere in this design — Cloud Build replaces it for
infrastructure, and Flux's pull-based reconciliation replaces it for
application delivery, so nothing needs a CI runner performing a deploy
step at all.

## Cloud Build: the Terraform pipeline

Every one of the eight stages in `infra/gcp/stages/` (see
[IAC.md](IAC.md)) gets a **plan trigger** and an **apply trigger** — 16
triggers total, all created by the `1-cloudbuild` stage, all living in the
`nonprod` project regardless of which project the stage they serve
provisions resources in.

```
push to a branch  ──▶  plan trigger  ──▶  terraform plan
                                           ──▶ upload plan file to GCS,
                                               named by commit SHA

push to main       ──▶  apply trigger  ──▶  download that exact plan
   (if enabled)                              file by commit SHA
                                           ──▶  terraform apply <plan-file>
```

The apply trigger runs the **plan that was already reviewed**, not a fresh
one computed at apply time — there's no drift between what a reviewer
looked at and what actually gets applied.

### The Production gate

Most stages auto-apply on merge to `main`. Two are deliberately excluded
from that — every stage that could touch Production, plus the pipeline's
own configuration stage, requires a human to manually run the apply
trigger:

| Stage | Auto-apply? |
|---|---|
| `1-cloudbuild` | No — this stage configures the delivery pipeline itself; a bad change here deserves a human look before it takes effect |
| `2-projects`, `3-networking`, `5-databases`, `7-flux-bootstrap` | No — touch resources shared with or reachable from Production |
| `4-gke-production` | No — Production's own cluster |
| `4-gke-nonprod`, `6-vcluster` | Yes — touch only Test/Acceptance |

A `disabled = true` apply trigger still exists and is still runnable
on-demand (Cloud Console, or `gcloud builds triggers run`) — the point
isn't that it can't run, it's that it doesn't run *automatically*. This is
the infrastructure-layer equivalent of the application-layer approval gate
described in [BRANCHING.md](BRANCHING.md) — two independent gates,
consistent in intent, applied at both layers.

### Least-privilege, per stage

Each stage has its own automation service account, scoped only to the
roles that stage actually needs (`roles/container.admin`,
`roles/cloudsql.admin`, `roles/compute.networkAdmin`, and similar) — never
`roles/editor` or `roles/owner`. A compromised or misconfigured trigger for
one stage can't reach resources outside that stage's own narrow grant.

## Flux: the application delivery pipeline

Flux is installed into every environment — every vCluster, and directly
into the Production GKE cluster — by Terraform's `flux-bootstrap` module,
once. After that, a **git push is the entire deployment mechanism**: no
`kubectl apply`, no pipeline step performs the deploy.

Each environment's Flux instance reconciles a chain of `Kustomization`
objects, ordered by explicit dependency so Flux won't attempt the next one
until the previous reports ready:

```
namespaces  →  controllers  →  configs  →  apps
```

- **`namespaces`** — the namespaces every later stage assumes exist.
- **`controllers`** — cert-manager, Envoy Gateway, and (on real GKE) the
  Secrets Store CSI driver. Installing a `ClusterIssuer` before
  cert-manager's own CRD exists would fail outright — this is a real
  ordering requirement, not caution for its own sake.
- **`configs`** — the `ClusterIssuer`, the `Gateway`, storage classes —
  objects that *use* what `controllers` just installed, so they can't
  reconcile until it's ready.
- **`apps`** — Ghost itself, last, since it depends on everything above
  (a working Gateway to attach its `HTTPRoute` to, a `ClusterIssuer` for
  its certificate, a database secret that's already decryptable).

### Two ways a `HelmRelease` sources its chart

Ghost's own chart lives in this same repository, so its `HelmRelease`
sources directly from the `GitRepository` object Flux already has —
whatever commit (or tag) that `GitRepository` is currently resolved to
*is* the version of the chart that gets installed, with no separate
version field to keep in sync:

```yaml
spec:
  chart:
    spec:
      chart: ./gitops/charts/ghost
      sourceRef:
        kind: GitRepository
        name: flux-system
```

cert-manager, Envoy Gateway, and the monitoring stack come from real
upstream Helm repositories instead, so their `HelmRelease`s source from a
`HelmRepository`/`OCIRepository` object — see `gitops/sources/` for all
four.

### Secrets: SOPS in the demo, Secret Manager on real GKE

Flux's `kustomize-controller` decrypts SOPS-encrypted secrets at reconcile
time, given a `sops-age` Kubernetes `Secret` holding the private key —
this is how the local demo keeps Ghost's database password out of plain
git, with zero cloud dependency. Real GKE's equivalent path is Secret
Manager, bridged in via the Secrets Store CSI driver instead — see
[ARCHITECTURE.md](ARCHITECTURE.md) §5.

### Promotion: which commit each environment tracks

*Not* controlled by branches — there's one long-lived branch, `main`.
Each environment's Flux `GitRepository` tracks a different **git
reference**, which is what actually gates promotion. Full detail,
including the tag-cutting mechanics and a worked example, is in
[BRANCHING.md](BRANCHING.md).

## What's deliberately outside both

The demo's local MySQL container is applied directly by
`infra/demo/Makefile`, outside Flux entirely — matching the principle that
whatever *provisions* the database is infrastructure (Terraform's job on
real GKE), not application delivery. Flux's remit is exactly the platform
controllers and Ghost, nothing else.
