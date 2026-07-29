# Branching and promotion strategy

## Branching model

Trunk-based. One long-lived branch, `main`; everything else is a
short-lived feature branch, merged after one required review:

```
feature branch → PR → 1 review required → merge to main
```

No long-lived per-environment branches. Which environment deploys what
comes from *what each environment's Flux `GitRepository` tracks*, not from
which branch anything is on — the three environments track git
differently:

| Environment | `GitRepository.spec.ref` | What triggers a deploy |
|---|---|---|
| Test | `branch: main` | Every push to `main` |
| Acceptance | `semver: ">=0.0.0"` | Any new tag matching semver, picked up automatically |
| Production | `tag: vX.Y.Z` (pinned, exact) | Only a reviewed PR that edits this one field |

Test needs zero tagging discipline — just push to `main`. Acceptance and
Production are where tag discipline actually matters, and where most of
this document is aimed.

Releases here are git tags, not build artifacts: Ghost runs from the
official upstream image, so this repository's own content — the Helm
chart, Kustomize overlays, Flux config, and which Ghost image tag is
referenced — **is the deployable artifact**. What gets `git tag`'d is
literally what Flux applies to a cluster.

## Test

Every push to `main` deploys. No tagging step:

```bash
git commit -m "chore(chart): bump version to 0.2.0"
git pull --rebase origin main
git push origin main:main
```

## Acceptance

Cut a tag and push it — Acceptance's `semver: ">=0.0.0"` ref picks up any
new matching tag on its own, no PR required for this step:

```bash
git tag -a v0.2.0 -m "v0.2.0"
git push origin v0.2.0
```

## Production

Production tracks a pinned, exact tag — promoting to it always means
editing that one field. The order below matters and is explained after the
steps.

**1. Edit the pin file first**, before cutting anything:

`gitops/clusters/<demo-or-gke>/production/flux-system/gotk-sync.yaml`
```yaml
ref:
  tag: v0.2.0-production
```

**2. Commit and push that edit to `main`:**

```bash
git add gitops/clusters/<demo-or-gke>/production/flux-system/gotk-sync.yaml
git commit -m "fix(gitops): pin production to v0.2.0-production (app code == v0.2.0)"
git pull --rebase origin main
git push origin main:main
```

**3. Only now, cut the tag** — at the commit that already contains the
edit above:

```bash
git tag -a v0.2.0-production -m "Production pin for approved v0.2.0"
git push origin v0.2.0-production
```

**4. Confirm it actually reached `origin`:**

```bash
git ls-remote --tags origin | grep v0.2.0-production
```

**5. Point Production's live `GitRepository` at it** — this is the step
that actually makes Production start using it:

```bash
kubectl --context <cluster-context> -n flux-system patch gitrepository flux-system \
  --type=merge -p '{"spec":{"ref":{"tag":"v0.2.0-production"}}}'
```

**6.** `git tag -l` to confirm the full set of tags locally, as a final
sanity check.

### Why the edit has to land before the tag

A git tag is an immutable snapshot. Production's `Kustomization` is
self-referential — it reapplies its *own* defining manifest
(`gotk-sync.yaml`) from whatever commit it currently has fetched. If a tag
is cut *before* committing the edit that points `ref.tag` at that same tag
name, the tag's own frozen snapshot doesn't contain the self-reference —
it still has whatever ref was live before. That causes an oscillation:
resolve the tag → read the tag's old ref → flip back to that old ref →
fetch a different commit → read *that* commit's ref → flip again,
indefinitely — and no command can fix it from the git side once it starts,
because reading the fix requires the ref to already be correct.

Seen live, this looks like two consecutive checks of the same cluster
disagreeing with each other for no apparent reason:

```bash
$ flux get kustomizations -A
NAMESPACE    NAME          REVISION                 READY   MESSAGE
flux-system  controllers   v0.2.0-production@...    True    Applied revision: v0.2.0-production@...
flux-system  flux-system   v0.2.0-production@...    True    Applied revision: v0.2.0-production@...
flux-system  namespaces    v0.2.0-production@...    True    Applied revision: v0.2.0-production@...

$ flux get kustomizations -A        # moments later, no command run in between
NAMESPACE    NAME          REVISION                 READY   MESSAGE
flux-system  controllers   main@sha1:c1b3cce2       True    Applied revision: main@sha1:c1b3cce2
flux-system  flux-system   main@sha1:c1b3cce2       True    Applied revision: main@sha1:c1b3cce2
flux-system  namespaces    main@sha1:c1b3cce2       True    Applied revision: main@sha1:c1b3cce2
```

That's the failure mode this section's ordering avoids. Once the edit
genuinely lands before the tag, the same check stays stable:

```bash
$ flux get kustomizations -A
NAMESPACE    NAME          REVISION                        READY   MESSAGE
flux-system  apps          v0.2.0-production@sha1:a11db72e True    Applied revision: v0.2.0-production@sha1:a11db72e
flux-system  configs       v0.2.0-production@sha1:a11db72e True    Applied revision: v0.2.0-production@sha1:a11db72e
flux-system  controllers   v0.2.0-production@sha1:a11db72e True    Applied revision: v0.2.0-production@sha1:a11db72e
flux-system  flux-system   v0.2.0-production@sha1:a11db72e True    Applied revision: v0.2.0-production@sha1:a11db72e
flux-system  namespaces    v0.2.0-production@sha1:a11db72e True    Applied revision: v0.2.0-production@sha1:a11db72e

$ curl -sk -D - https://ghost.local/ -o /dev/null
HTTP/2 200
x-chart-version: 0.2.0+a11db72e876c
```

### If a ref ever points at something that doesn't exist

If `spec.ref` ends up pointing at a tag that's missing, deleted, or
misspelled (or step 3 above got skipped — a tag referenced but never
pushed), the `GitRepository` becomes **permanently stuck**, not just slow —
it can't fetch the commit that would fix its own `ref` field, because
fetching requires the *current*, broken ref to resolve first. Waiting or
reconciling harder does not help.

Recovery is the same live patch as step 5, pointed at a tag already
confirmed on `origin`:

```bash
kubectl --context <cluster-context> -n flux-system patch gitrepository flux-system \
  --type=merge -p '{"spec":{"ref":{"tag":"<a-tag-confirmed-on-origin>"}}}'
```

## Promoting a specific older tag, not the latest one

A realistic case that needs one more step than the walkthrough above:

```
main ← PR merged
  tag v0.2.0 cut, validated in Acceptance
main ← PR merged
  tag v0.2.1 cut, validated in Acceptance
main ← PR merged
  tag v0.2.2 cut, validated in Acceptance
Decision: deploy v0.2.1 to Production — not the latest, v0.2.2
```

This is exactly why Production tracks a pinned tag rather than a semver
range like Acceptance — it's what makes deploying a *specific* validated
version possible, not just always-newest. But `v0.2.1`'s own
`gotk-sync.yaml` doesn't self-reference (it was cut as an ordinary release
tag, before anyone knew it would later be chosen for Production), and the
normal fix — commit the edit to `main`, then tag that — doesn't work
either, since `main`'s current HEAD already contains `v0.2.2`'s changes;
tagging HEAD would promote the wrong code.

**Resolution: branch from the tag being promoted, not from `main`.**

```bash
# 1. Branch from the exact commit that was approved
git checkout -b production-pin-v0.2.1 v0.2.1

# 2. Edit gotk-sync.yaml's ref.tag to a NEW tag name — never the name
#    of the tag just branched from
#      ref: tag: v0.2.1-production

# 3. Commit — lands BEFORE the tag
git add gitops/clusters/<demo-or-gke>/production/flux-system/gotk-sync.yaml
git commit -m "fix(gitops): pin production to v0.2.1-production (app code == v0.2.1)"

# 4. Tag this commit and push
git tag -a v0.2.1-production -m "Production pin for approved v0.2.1"
git push origin v0.2.1-production

# 5. Confirm it landed
git ls-remote --tags origin | grep v0.2.1-production

# 6. Point Production at it directly — this branch is disconnected from
#    main's history, so nothing on main tells Flux to look at this new
#    tag on its own
kubectl --context <cluster-context> -n flux-system patch gitrepository flux-system \
  --type=merge -p '{"spec":{"ref":{"tag":"v0.2.1-production"}}}'

# 7. Clean up the now-disposable local branch
git branch -D production-pin-v0.2.1
```

Everything except the one pin file stays byte-for-byte identical to what
was actually validated at `v0.2.1`. The branch never needs to merge into
`main` — it exists solely to hold one commit worth tagging, and `main`
keeps moving forward through `v0.2.2` and beyond without it. The tag
itself is still fully visible and fetchable by name even though the commit
it points to is never an ancestor of `main`.

**When this branching step isn't needed:** only when the tag being pinned
is brand new and nothing has been pushed to `main` since it was cut — then
editing `gotk-sync.yaml` directly on `main` and tagging the resulting
commit (the plain Production walkthrough above) is simpler and works just
as well.

## Branch protection

**Baseline, on `main`, every PR:** require a pull request before merging,
require at least one approval.

**Additional, via `CODEOWNERS`, only for Production's pin file — both
tracks:**

```
gitops/clusters/demo/production/flux-system/gotk-sync.yaml   @platform-leads
gitops/clusters/gke/production/flux-system/gotk-sync.yaml    @platform-leads
```

A PR touching either file needs approval from that owner specifically, on
top of the baseline. Gating just this one file is equivalent to gating all
of Production: nothing else that changes on `main` takes effect there on
its own — it only reaches Production once it's part of a tag, and that tag
only reaches Production once someone bumps this pin through the reviewed
PR. There's no side door.

## Checklist

1. `git ls-remote --tags origin` — confirm any tag landed before depending
   on it.
2. Reconcile in dependency order rather than waiting on poll intervals:
   ```bash
   flux reconcile source git flux-system --context <cluster-context>
   flux reconcile kustomization namespaces --context <cluster-context> --with-source
   flux reconcile kustomization controllers --context <cluster-context> --with-source
   flux reconcile kustomization configs --context <cluster-context> --with-source
   flux reconcile kustomization apps --context <cluster-context> --with-source
   ```
3. `flux get kustomizations -A --context <cluster-context>` — check it
   **twice, a few seconds apart**. A table that says `Ready: True` once
   isn't proof the revision is stable; the oscillation failure mode above
   looks exactly like this on a single check.
