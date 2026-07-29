# Running the demo

Three vClusters — Test, Acceptance, Production — running locally on Docker,
each with its own Flux instance, each deploying Ghost from this same
repository. No cloud account, no cloud spend. See
[`../../docs/DEMO.md`](../../docs/DEMO.md) for what this demonstrates and
[`../../docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) §7 for how it
differs from the real GKE track.

## Prerequisites

See [`../../docs/PREREQUISITES.md`](../../docs/PREREQUISITES.md) for the
full tool list. For the demo specifically, you need: Docker running,
`vcluster`, `kubectl`, `flux`, `sops`, `age`, and a logged-in `gh` CLI
(`gh auth login`) — `flux bootstrap` needs a GitHub token, and the Makefile
falls back to `gh auth token` automatically if `GITHUB_TOKEN` isn't already
set.

## First run

From this directory (`infra/demo/`):

```bash
make up-test
```

This single command, for one environment:

1. Creates the vCluster (`vcluster create --driver docker`).
2. Runs `flux bootstrap`, which installs Flux's controllers and points
   them at `gitops/clusters/demo/test/` in this repository.
3. Waits for the `namespaces` `Kustomization` to be ready.
4. Creates the `sops-age` secret from your local `age.agekey`, so Flux can
   decrypt the SOPS-encrypted database secret.
5. Creates the `mysql-credentials` secret, using the same database
   password Flux will decrypt for Ghost — so both sides match without
   anyone typing a password twice.
6. Applies the local MySQL deployment directly (outside Flux — see
   [`../../docs/AUTOMATION.md`](../../docs/AUTOMATION.md) for why the
   database is deliberately not Flux's responsibility).

From here, Flux takes over — `controllers`, `configs`, and `apps`
reconcile on their own, in that dependency order, with no further command.

Bring up all three environments the same way:

```bash
make up
```

which is exactly `up-test`, `up-acceptance`, and `up-production` run in
sequence — nothing different between the three beyond which environment
name is substituted in.

## Reaching Ghost in a browser

Each vCluster gets its own Docker bridge IP, which needs a one-time
`/etc/hosts` entry per environment — this is the one manual step in the
whole flow, and `make up` reminds you of it at the end:

```bash
kubectl --context vcluster-docker_test       get svc -n envoy-gateway-system
kubectl --context vcluster-docker_acceptance get svc -n envoy-gateway-system
kubectl --context vcluster-docker_production get svc -n envoy-gateway-system
```

Look for the `EXTERNAL-IP` on the `LoadBalancer` `Service` in each, then
add it to `/etc/hosts`:

```
<test-ip>        ghost.test.local
<acceptance-ip>  ghost.acceptance.local
<production-ip>  ghost.local
```

Then visit `https://ghost.test.local` (or `.acceptance.local` / `.local`).
The browser will warn about an untrusted certificate on first load —
expected, the demo uses a `SelfSigned` cert-manager issuer, not Let's
Encrypt (see [`../../docs/ROUTING.md`](../../docs/ROUTING.md)). Accept the
warning to continue.

**First visit to `/ghost/`** (the admin panel) shows Ghost's own one-time
setup wizard, not a login screen — there's no pre-seeded account. Fill in
a site title, your name, email, and a password to create the owner
account.

## Verifying which build is actually running

Every response carries an `x-chart-version` header — see
[`../../docs/DEMO.md`](../../docs/DEMO.md) for what it means and why it's
useful when demonstrating a promotion live:

```bash
curl -sk -D - https://ghost.test.local/ -o /dev/null | grep x-chart-version
```

## Day-to-day commands

| Command | What it does |
|---|---|
| `make up-<env>` | Full bring-up for one environment (`test`, `acceptance`, or `production`) |
| `make up` | All three, in sequence |
| `make down-<env>` / `make down` | Deletes the vCluster(s) entirely |
| `make pause-<env>` / `make pause` | Stops the underlying Docker containers in seconds, keeping all state — use this over `down`/`up` for day-to-day breaks |
| `make resume-<env>` / `make resume` | Starts a paused vCluster back up |
| `make clusters` | Just the raw vClusters — no Flux, no GitHub, no secrets, no MySQL. Useful for iterating on `vclusters/<env>.yaml` itself without the rest of the stack |
| `make status` | Lists every vCluster and its current state |

## Promoting a change through the environments

The demo runs the exact same promotion mechanism as real GKE — see
[`../../docs/BRANCHING.md`](../../docs/BRANCHING.md) for the full
walkthrough (push to `main` for Test, cut a tag for Acceptance, a
reviewed PR that bumps a pinned tag for Production) and
[`../../docs/FLOW.md`](../../docs/FLOW.md) for the end-to-end diagram.

## Troubleshooting

**A `Kustomization` is stuck on `dependency ... is not ready`:** normal
during the first minute or two after bootstrap — later stages wait for
earlier ones. Check progress with:

```bash
flux get kustomizations -A --context vcluster-docker_<env>
```

**Everything in `flux-system` is `CrashLoopBackOff` after a Docker
restart or a long idle period:** the vCluster's own virtual API server can
end up in a bad state after the host Docker daemon restarts. Rebuilding
the one environment is faster than debugging it:

```bash
make down-<env>
make up-<env>
```

**A Flux `Kustomization`'s `REVISION` seems to jump between two different
values on repeated checks:** this is the self-referential tag/ref issue
covered in detail in
[`../../docs/BRANCHING.md`](../../docs/BRANCHING.md) — not something to
fix by reconciling harder.

**`flux bootstrap` refuses with `sync path configuration ... would
overwrite path ... of existing Kustomization`:** it's refusing to silently
repoint an already-bootstrapped cluster to a different path — a safety
check, not a bug. `make down-<env>` and `make up-<env>` again for a clean
re-bootstrap.
