# ghost

A Helm chart for [Ghost](https://ghost.org/), behind a
[Gateway API](https://gateway-api.sigs.k8s.io/) `HTTPRoute`, talking to an
external MySQL endpoint. Environment-agnostic by design — the same chart
deploys identically on the local demo (vCluster) and real GKE; every
environment-specific value comes in through `values.yaml`, never
hardcoded into a template. See
[`../../../docs/ARCHITECTURE.md`](../../../docs/ARCHITECTURE.md) §7 for
what varies between the two tracks and why.

## Values reference

| Key | Default | Notes |
|---|---|---|
| `replicaCount` | `1` | Fixed, not tunable per environment — see "Why exactly one replica" below |
| `image.repository` / `image.tag` | `ghost` / `6.39.0` | The official upstream image — nothing custom-built |
| `serviceAccount.gcpServiceAccountEmail` | `""` | Empty on the demo track. Real GKE sets this to the Workload Identity-bound GCP service account email — see [`../../../docs/ARCHITECTURE.md`](../../../docs/ARCHITECTURE.md) §5 |
| `updateStrategy` | `Recreate` | Not `RollingUpdate` — the content PVC is `ReadWriteOnce`, mounted by one pod at a time; a rolling update would try to mount it into the new pod before the old one releases it |
| `service.type` / `service.port` | `ClusterIP` / `2368` | Ghost's own default port |
| `httpRoute.enabled` | `true` | Set `false` only if Ghost should be reachable purely in-cluster |
| `httpRoute.gatewayName` | `ghost` | Which platform-owned `Gateway` this app's `HTTPRoute` attaches to — see [`../../../docs/ROUTING.md`](../../../docs/ROUTING.md) |
| `httpRoute.hostname` | `localhost` | Real FQDN on real GKE; `localhost` is a structurally valid value on the demo track too — Gateway API's hostname type only requires an RFC-1123 DNS subdomain, which `localhost` satisfies |
| `persistence.enabled` | `true` | Ghost's content directory (uploaded images, themes) |
| `persistence.storageClassName` | `""` (cluster default) | Set per environment — local-path on the demo track, Filestore-backed on real GKE |
| `persistence.accessMode` | `ReadWriteOnce` | `ReadWriteOnce` everywhere today, since `replicaCount` is always `1` — `ReadWriteMany` is available via Filestore if that ever changes |
| `ghost.url` | `https://localhost:9443` | Ghost's own `url` config key — the externally-visible URL, used to generate absolute links in content |
| `ghost.database.host` / `.port` / `.name` / `.user` | `mysql` / `3306` / `ghost` / `ghost` | External MySQL connection — Cloud SQL on real GKE, the local demo's MySQL container on the demo track |
| `ghost.database.existingSecret` | `""` | Name of a pre-existing `Secret` holding the database password. This chart never creates or contains the secret itself — see below |
| `ghost.database.passwordKey` | `database-password` | Key within that `Secret` |
| `ghost.database.secretProviderClass` | `""` | Name of a `SecretProviderClass` syncing Secret Manager into `existingSecret` above. Empty on the demo track — no CSI volume mounted at all when unset |
| `resources` | `100m`/`256Mi` requests, `500m`/`512Mi` limits | Vertical scaling only — see below |
| `podDisruptionBudget.enabled` | `false` | See "Why the PDB defaults off" below |
| `probes.liveness` / `probes.readiness` | 30s/15s, 10s/10s | Standard liveness/readiness timing |

## Why exactly one replica, no HPA

Not a limitation of this chart — a constraint of Ghost itself. Ghost's own
documentation is explicit: it doesn't support load-balanced clustering or
multi-server setups of any description, and running multiple instances
causes real failures (405 errors, instances needing constant restarts),
not just the duplicate-scheduled-post risk this repository's own scheduler
research already expected. There is no `HorizontalPodAutoscaler` in this
chart for the same reason — availability comes from Kubernetes' own fast
rescheduling on failure, not redundant replicas. Real capacity comes from
vertical `resources` (set per environment in each `apps/<track>/<env>/`
overlay) and, per Ghost's own recommended path, a cache/CDN layer in
front. See [`../../../docs/ROADMAP.md`](../../../docs/ROADMAP.md) for the
full reasoning and the cache/CDN follow-up.

## Why the PodDisruptionBudget defaults off

With `replicaCount: 1`, a PDB's `maxUnavailable` can only meaningfully be
`0` — which blocks every voluntary node drain (upgrades, maintenance) for
as long as this is the only replica. A real tradeoff, not a free
availability win, so it's off by default and left as a deliberate,
per-environment decision rather than a chart default.

## Secrets: this chart never creates them

`ghost.database.existingSecret` must already exist before this chart is
installed — created out of band. On the demo track, a
Makefile-generated, never-committed `Secret`; on real GKE, synced from
Secret Manager by the Secrets Store CSI driver via
`ghost.database.secretProviderClass`. See
[`../../../docs/AUTOMATION.md`](../../../docs/AUTOMATION.md) for how each
track wires this.
