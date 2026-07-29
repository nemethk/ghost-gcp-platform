# Roadmap: deferred, not dropped

Not everything in the assignment's scope was worth building for this
delivery. This document lists what's deferred, why, and a rough size for
each — so a decision to build any of them later is a scoped conversation,
not a surprise. GitOps itself isn't on this list: Flux is core to the
design, not a future upgrade.

One item below is marked differently from the rest — Ghost's own
multi-replica horizontal scaling is **ruled out**, not deferred. That
distinction matters and is explained in its own row.

| Item | Why deferred | Rough estimate |
|---|---|---|
| Hub-and-spoke network topology | Considered and set aside for the current scope — see its own section below | 1–2 days, only if the trigger condition below actually materializes |
| Application-level alerting (Ghost error rate, latency, availability) | Flux's own pipeline alerting (deploy success/failure) is already built and posts to Slack — see [MONITORING.md](MONITORING.md). What's missing is alert rules defined against the Prometheus/Loki data already being collected (e.g. Ghost 5xx rate, pod not-ready duration) | 0.5–1 day |
| Slack alert noise reduction | The existing pipeline `Alert` fires on every `Kustomization`/`HelmRelease` event at `info` severity — useful for a demo, too noisy for real on-call use. Needs severity filtering (only alert on failure) and possibly per-environment channels | 0.5 day |
| vCluster Platform UI (central dashboard across Test/Acceptance) | Real payoff for a live demo, but adds its own control plane and login flow — bigger scope than a drop-in swap for the plain CLI | 0.5–1 day |
| Flux image-automation (auto-bump Ghost's image tag on new upstream release) | Nice-to-have; a manual tag bump in the chart values is fine at this scale | 0.5 day |
| Automated promotion (bot-opened PR to bump Production's pinned tag) | The manual PR is the deliberate approval gate — automating the PR's *creation* (not its merge) is a later efficiency win, not a missing safeguard | 0.5–1 day |
| SOPS key rotation with cloud KMS backing | The demo uses a single locally-generated age key; real production secret management needs Cloud KMS-backed keys, not a file on someone's laptop | 0.5 day |
| Inline `terraform plan` diff as a PR comment | Cloud Build doesn't have this out of the box the way GitHub Actions does — an accepted UX gap for keeping the pipeline inside GCP's boundary (see [AUTOMATION.md](AUTOMATION.md)). A small Cloud Build custom step or Cloud Function could close it | 0.5–1 day |
| Split Test/Acceptance into their own GCP projects | A cost/isolation tradeoff for the customer to decide, not a technical blocker — `5-databases` already provisions each environment's Cloud SQL independently, so the database layer needs no rework | ~0.5 day |
| Backup / disaster recovery policy | Cloud SQL has automated backups by default, but retention/PITR policy, cross-region copies, and content-volume backup (Filestore snapshot or equivalent) haven't been decided — an open question, not a design yet | TBD — analysis pending |
| GKE cluster HA topology — regional vs. zonal | [ARCHITECTURE.md](ARCHITECTURE.md) covers isolation *between* environments, not each cluster's own control-plane/node distribution across zones — directly relevant to "maximizing availability," not yet decided | TBD — analysis pending |
| Ghost multi-replica horizontal scaling | **Ruled out, not deferred** — see below | N/A |
| Read-through HTTP cache / CDN in front of Ghost | Ghost's own recommended scale/HA path — see below | TBD — needs an Envoy Gateway feature check or a Cloud CDN design |

## Ghost horizontal scaling: ruled out, with a source

Ghost's own documentation is explicit: "Ghost doesn't support load-balanced
clustering or multi-server setups of any description, there should only be
one Ghost instance per site" — running multiple instances causes real
failures (405 errors, instances needing constant restarts for content to
display reliably), not a theoretical risk. The same documentation names
the actual recommended path for scale and availability instead: a cache
or CDN in front of the blog, since the pages Ghost generates are
essentially static.

This repository follows that guidance directly — every environment runs
Ghost at a single replica, and scale is handled vertically (resource
requests/limits per environment) rather than horizontally. Building real
clustering anyway would mean forking and permanently maintaining a patch
against Ghost's own scheduler internals, against every future upstream
version — not a scoped infrastructure task, and not something this
migration should take on.

The cache/CDN row above is the follow-up this constraint points to: Envoy
Gateway's `BackendTrafficPolicy` was checked directly against its own
documentation rather than assumed, and response caching isn't a feature it
currently exposes (only compression, rate-limiting, retries, and
circuit-breaking are). Closing this gap needs either a newer Envoy Gateway
capability or a separate mechanism — Cloud CDN in front of a GCP HTTPS
load balancer is the most likely candidate, though that would sit
alongside, not replace, the Gateway API data plane this repository
otherwise uses throughout.

## Hub-and-spoke: considered, set aside for now

A hub-and-spoke network topology — a central "hub" VPC peered to
per-environment "spoke" VPCs, typically used to centralize egress, shared
firewall/security policy, or hybrid on-prem connectivity across many
projects — was evaluated against this project's actual shape and
deliberately not adopted.

**Why not now:** this repository has two GCP projects, each with its own
VPC and its own Cloud NAT already. There's no shared resource to
centralize, and Test/Acceptance/Production are *deliberately* isolated
from each other per the assignment's own workload-isolation requirement
(see [ARCHITECTURE.md](ARCHITECTURE.md) §2). Peering the VPCs together to
build a hub would work against that isolation goal, not serve it — real
added complexity (a hub VPC, peering connections, coordinated routing and
firewall rules across the hub) with no problem here for it to solve.

**When it would become worth it:** if this platform grew to host multiple
independent applications or teams sharing common egress/security tooling,
or — more relevant to this specific migration — if a real cutover needed
hybrid connectivity back to the client's on-prem network (a VPN or Cloud
Interconnect) during a transition period, rather than a clean DNS-only
handover via the existing GoDaddy record. Either trigger is a real,
nameable condition, not a vague "at scale" — worth revisiting if either
one actually materializes, not before.
