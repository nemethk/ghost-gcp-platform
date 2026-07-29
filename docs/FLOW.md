# End-to-end flow: from a commit to a running change

This document walks through what actually happens, step by step, from a
developer pushing code to that code running in each environment. Two
different flows, depending on what changed — infrastructure or
application — since [AUTOMATION.md](AUTOMATION.md) explains, they're
handled by two different engines.

## Flow 1: an infrastructure change (Terraform)

```
developer                Cloud Build              GitHub                reviewer
    │                         │                       │                     │
    │  edit infra/gcp/...     │                       │                     │
    │  open PR                │                       │                     │
    ├─────────────────────────┼──────────────────────▶│                     │
    │                         │  push triggers the     │                     │
    │                         │  stage's plan trigger  │                     │
    │                         │◀──────────────────────┤                     │
    │                         │  terraform plan        │                     │
    │                         │  upload plan → GCS     │                     │
    │                         │  (named by commit SHA) │                     │
    │                         │                        │                     │
    │                         │                        │  review PR + plan   │
    │                         │                        │◀────────────────────┤
    │                         │                        │  approve, merge     │
    │                         │                        │◀────────────────────┤
    │                         │  merge to main triggers │                     │
    │                         │  the apply trigger      │                     │
    │                         │◀───────────────────────┤                     │
    │                         │                                              │
    │              ┌──────────┴──────────┐                                   │
    │              │ auto-apply stage?    │                                   │
    │              └──────────┬──────────┘                                   │
    │                    yes  │  no                                          │
    │                         │   └──▶ waits for a human to manually         │
    │                         │        run the (disabled) apply trigger      │
    │                         ▼                                              │
    │              download the exact plan file saved above (by SHA)         │
    │              terraform apply <that plan file>                          │
    │                         │                                              │
    │              stage's outputs published to GCS,                         │
    │              read by the next stage down the dependency chain          │
```

Which stages auto-apply and which need a manual run is covered in
[AUTOMATION.md](AUTOMATION.md)'s Production gate table — the shape of the
flow above is identical either way, only the "wait for a human" step
differs.

## Flow 2: an application change (Ghost / platform config)

This is the flow that actually demonstrates "automate the end-to-end
deployment process" — once code is merged, nothing runs a deploy command.

```
main ────●────────────●───────────────●──────────────────────▶
         │             │               │
         │ push         │ tag v1.4.2    │ PR: bump production's
         │              │               │ pinned tag to v1.4.2
         ▼              ▼               ▼
       Test         Acceptance      Production
    (tracks main,   (tracks any     (tracks only the exact
     redeploys      matching        pinned tag — changes only
     immediately)   semver tag,     via a reviewed PR)
                     picked up
                     automatically)
```

1. **A feature branch merges to `main`.** Flux's `GitRepository` for Test
   tracks `branch: main` directly — the very next reconcile (default poll
   interval, or forced with `flux reconcile source git`) fetches the new
   commit and redeploys. No tag, no PR beyond the one that merged the
   code.
2. **Once a change is considered a release candidate, someone cuts a
   tag** (`git tag vX.Y.Z && git push origin vX.Y.Z`). Acceptance's
   `GitRepository` tracks `semver: ">=0.0.0"` — a standing *rule*, not a
   specific pointer — so it picks up any new matching tag automatically,
   with no further action.
3. **After the tag has run cleanly in Acceptance**, someone opens a PR
   whose entire diff is Production's pinned tag value changing. This file
   is `CODEOWNERS`-gated, so it needs a specific approver on top of the
   baseline review.
4. **Merging that PR is what actually promotes to Production** — Flux's
   `GitRepository` for Production fetches the repository exactly as it
   existed at that tag and reconciles Production toward it, continuously
   (not a one-shot apply — later drift gets corrected too, same as every
   other environment).

The full mechanics of each step — including a worked example of promoting
a *specific* older tag rather than always the newest one, and the pitfalls
that come up when a tag's own config doesn't yet know it's the tag being
promoted — are in [BRANCHING.md](BRANCHING.md).

## Flow 3: first-time bootstrap (a cluster that doesn't exist yet)

The two flows above assume Flux is already running. The very first time an
environment is stood up, one extra step happens before Flow 2 can apply at
all:

```
terraform apply (4-gke-nonprod or 4-gke-production)
        │
        ▼
terraform apply (7-flux-bootstrap)
        │
        ▼
flux bootstrap installs Flux's own controllers,
commits its own GitRepository + Kustomization
config back to this repo, applies it once
        │
        ▼
from here on: Flow 2 — Flux reconciles from git,
Terraform never touches this environment's deploys again
```

This is a one-time, chicken-and-egg-breaking step — something has to
install Flux's controllers before Flux can start syncing itself from git.
After it completes once per environment, `flux bootstrap` is never run
again for that environment; every future change flows through Flow 2.

## Putting it together: one commit, three outcomes

A single commit touching `gitops/apps/base/ghost/` can be live in Test
within minutes, in Acceptance once someone decides to tag it, and never
reach Production until someone deliberately reviews and merges the pin
bump — same commit, three different speeds, controlled entirely by git
state (branch position, tag existence, pinned tag value), not by three
different deployment mechanisms.
