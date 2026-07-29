# gitops

Everything Flux manages — controllers, configuration, and the Ghost
application itself — across both tracks (the local demo and real GKE) and
all three environments (Test, Acceptance, Production). Sibling of
`infra/gcp/` (Terraform); see
[`../docs/AUTOMATION.md`](../docs/AUTOMATION.md) for the boundary between
the two.

```
gitops/
├── clusters/                    # ROUTING ONLY — which Kustomizations a
│   ├── demo/{test,acceptance,production}/    given cluster applies, never
│   │   └── flux-system/            application manifests themselves
│   └── gke/{test,acceptance,production}/
│       └── flux-system/
│
├── namespaces/                  # shared by both platform/ and apps/ —
│                                 #   the ghost namespace lives here too,
│                                 #   not nested under platform/
│
├── platform/
│   ├── controllers/             # the tools: cert-manager, Envoy Gateway,
│   │   ├── all/                 #   monitoring stack, Gateway API CRDs —
│   │   └── gke/                 #   shared by every cluster (all/) plus
│   │                             #   gke-exclusive extras (gke/)
│   └── configs/                 # config that USES those tools: ClusterIssuer,
│       ├── all/                 #   Gateway, alerts, storage classes — same
│       └── gke/                 #   all/ + gke/ split
│
├── sources/                     # Flux Source objects (HelmRepository/
│                                 #   OCIRepository) — consumed only by
│                                 #   platform/'s controllers
│
├── charts/
│   └── ghost/                   # the Helm chart itself — environment-agnostic,
│                                 #   same chart for demo and real GKE
│
└── apps/
    ├── base/
    │   └── ghost/                # env-agnostic HelmRelease + dashboard
    ├── demo/{test,acceptance,production}/    # per-env patches: values,
    │                                          #   secrets.enc.yaml
    └── gke/{test,acceptance,production}/     # per-env patches: values,
                                               #   secret-provider-class.yaml
```

## Why `clusters/` holds only routing, never application manifests

Each environment's `clusters/{demo,gke}/<env>/` directory is a set of Flux
`Kustomization` objects, chained by `dependsOn`:

```
namespaces  →  controllers  →  configs  →  apps
```

None of these `Kustomization` objects contain a Kubernetes resource
directly — each one's `spec.path` points somewhere else in this tree
(`platform/controllers/...`, `platform/configs/...`, `apps/{demo,gke}/<env>`).
This is what keeps six environments (three per track) from becoming six
copies of the same manifests: the manifests exist once, and each
environment's `clusters/` directory only decides *which* of them apply and
in *what order*. `flux-system/` inside each environment's folder is Flux's
own self-referential bootstrap output — never hand-edited directly, except
for the one field ([`gotk-sync.yaml`](../docs/BRANCHING.md)'s `ref:`) that
controls promotion.

## Why `namespaces/` sits at the top level, not inside `platform/`

It creates the `ghost` namespace (consumed by `apps/`) alongside
`cert-manager`, `envoy-gateway-system`, and `monitoring` (consumed by
`platform/`) — genuinely shared by both siblings, not platform-exclusive.
Nesting it under `platform/` would misrepresent that the `ghost` namespace
belongs there too. It's also the root of the whole dependency chain —
every other `Kustomization` in every environment depends on it, directly
or transitively.

## Why `controllers/` and `configs/` are split, not one folder

Ordering. `configs/` objects (a `ClusterIssuer`, a `Gateway`) need their
corresponding controller's CRDs and webhooks already installed and
running, or they fail outright on first apply — not a style preference,
a real dependency that `dependsOn` encodes explicitly. `controllers/` is
*what runs*; `configs/` is *how it's configured for this use case*.

## Why `all/` and `gke/`, nested under both `controllers/` and `configs/`

Two axes, not one. The primary split (`controllers` vs `configs`) is the
ordering-driven one above; `all` vs `gke` is layered on top of it,
separating what every cluster runs from what's exclusive to real GKE
(Secrets Store CSI, Filestore storage classes — neither has a local-demo
equivalent). Nesting rather than a flat sibling naming convention
(`controllers-gke` alongside `controllers`) makes the relationship
explicit in the tree itself: `controllers/gke/` reads unambiguously as
"the gke flavor of controllers," not a same-looking but unrelated folder.

## Why `sources/` is a top-level folder, not inside `platform/`

Every `HelmRepository`/`OCIRepository` object here (cert-manager,
Envoy Gateway, Grafana, Prometheus Community) is consumed exclusively by
`platform/`'s controllers today — none of `apps/`'s `HelmRelease`s use
one; Ghost's own chart sources directly from this repository's git
history instead (see [`../docs/AUTOMATION.md`](../docs/AUTOMATION.md)).
`sources/` sits at the top level anyway, matching `namespaces/`, on the
principle that a folder's location should reflect its actual scope: if a
future consumer outside `platform/` ever needed a `HelmRepository`, moving
it under `platform/` now would have to be undone later. Keeping it flat
costs nothing today and avoids that rework.

## Why `apps/base/` + per-track, per-env patches, not one folder per environment

`apps/base/ghost/` is the environment-agnostic core: Ghost's `HelmRelease`
and its Grafana dashboard, no per-env values baked in. Every environment
references it as a Kustomize base and layers only its own divergence on
top — a `ghost-values.yaml` strategic-merge patch, plus whatever's
genuinely environment-specific (`secrets.enc.yaml` on the demo track,
`secret-provider-class.yaml` on real GKE). Six environments end up sharing
one definition of *what* Ghost is, differing only in *how it's configured
here* — the same principle `platform/`'s `all`/`gke` split uses, applied
one layer further down.

## Why `charts/ghost/` lives here, not in a separate repository

Ghost runs from the official upstream container image — there's no
application source being compiled in this repository. What *is* built
here is the deployment shape around that image: the chart, the overlays,
the Flux config. Keeping the chart in this same repository means a single
git tag is the complete, coherent, deployable unit — chart and
environment config promote together, never independently out of sync. See
[`../docs/BRANCHING.md`](../docs/BRANCHING.md) for what that buys, and
what it would cost to split later if the chart ever needed to be reused
outside this platform.
