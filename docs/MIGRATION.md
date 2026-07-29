# Migration: on-prem to GKE

Step-by-step plan for moving the current on-premise deployment — Ghost
behind an NGINX reverse proxy, backed by a MySQL cluster, already running
across Test, Acceptance, and Production — onto the GKE-based platform this
repository builds.

## What's known about the current environment, and what isn't

The only confirmed facts about the source environment: Ghost, behind
NGINX as a reverse proxy, with a MySQL cluster for persistent data, run
across three environments today. Everything else — MySQL version and
replication topology, Ghost version, current traffic volume, content
volume size, existing backup arrangements, current DNS TTLs — is
**unknown at the time of writing** and must be confirmed during Phase 0
below, not assumed. Every step in this plan that depends on one of these
unknowns says so explicitly, with the safer of the reasonable options
chosen by default.

## Migration principles

- **Lowest-risk environment first.** Test migrates before Acceptance,
  Acceptance before Production — the same ordering this repository already
  uses everywhere else (see [BRANCHING.md](BRANCHING.md)). Problems surface
  and get fixed on an environment nobody depends on, before they can affect
  the customer-facing one.
- **Parallel run, not a big-bang switch.** The GKE-based environment is
  stood up and validated *before* any traffic is redirected to it. The
  on-prem environment keeps running, untouched, until DNS is deliberately
  cut over — and stays available as an immediate rollback target for a
  defined soak period after that.
- **One environment fully migrated and stable before the next starts.**
  Not parallelized across environments — each migration's lessons (a
  MySQL export quirk, a content-path assumption that didn't hold) directly
  informs the next one.
- **DNS cutover is the only irreversible-feeling step, and it isn't
  actually irreversible.** Reverting a GoDaddy A record back to the
  on-prem IP is a five-minute action at any point until on-prem is
  formally decommissioned in Phase 4.

## Phase 0: Target infrastructure readiness (once, before any environment migrates)

Prerequisite for all three environment migrations below — not repeated per
environment.

1. Confirm the two GCP projects (`nonprod`, `production`) are provisioned
   and reachable — see [IAC.md](IAC.md) for the adoption mechanism
   (`project_reuse`, not project creation).
2. Apply Terraform stages `0-bootstrap` through `7-flux-bootstrap`, in
   order — the dependency chain and which stages require manual approval
   are covered in [AUTOMATION.md](AUTOMATION.md). At the end of this phase:
   both GKE clusters exist, both vClusters (Test, Acceptance) are running
   inside the shared cluster, Cloud SQL exists for all three environments,
   and Flux is installed everywhere but has nothing to deploy yet.
3. Confirm DNS access at the current registrar (GoDaddy) — whoever runs
   the cutover in each environment's Phase below needs the ability to
   change an A record, not just view it.
4. Reserve and note each environment's external IP
   (`infra/gcp/stages/3-networking`'s output) — these are what the A
   records will eventually point at.

```
Phase 0 output:
  ┌─────────────────────────────┐   ┌──────────────────────────────────┐
  │ production (GCP project)    │   │ nonprod (GCP project)            │
  │  GKE cluster: running       │   │  GKE cluster: running            │
  │  Cloud SQL: running, empty  │   │  vCluster test: running          │
  │  Flux: installed, idle      │   │  vCluster acceptance: running    │
  └─────────────────────────────┘   │  Cloud SQL x2: running, empty    │
                                    │  Flux x2: installed, idle        │
                                    └──────────────────────────────────┘
  On-prem: unchanged, still serving all production traffic
```

## Phase 1 – 3: migrate one environment (repeat for Test, Acceptance, Production, in that order)

### Step 1: Data migration — MySQL

The safest default, absent confirmed detail about the current cluster's
replication capability, is a **logical dump and restore during a
maintenance window**:

```bash
mysqldump --single-transaction --routines --triggers \
  -h <on-prem-mysql-host> -u <user> -p ghost > ghost-<env>.sql

mysql -h <cloud-sql-private-ip> -u <user> -p ghost < ghost-<env>.sql
```

`--single-transaction` avoids locking the source database for the
duration of the dump on InnoDB tables — confirm the on-prem cluster
actually uses InnoDB before relying on this flag.

**If the current MySQL cluster supports binlog-based replication** (not
confirmed either way), [Cloud SQL's own migration
tooling](https://cloud.google.com/database-migration/docs/mysql) can
replicate continuously and cut over with a much shorter window than a full
dump/restore — worth checking for Production specifically, where minimizing
downtime matters most, even if the simpler dump/restore is used for Test
and Acceptance.

Either way, the destination is already provisioned and reachable: Cloud
SQL's private IP, reachable only from inside the environment's own VPC via
Private Service Access — see [ARCHITECTURE.md](ARCHITECTURE.md) §5.

### Step 2: Data migration — Ghost content

Ghost's uploaded images and theme files (typically `content/images/` and
`content/themes/` on the source server) copy across as files, not a
database operation:

```bash
rsync -avz /path/to/ghost/content/ <migration-jump-host>:/mnt/staging/
```

then loaded onto the new environment's persistent volume — a `kubectl cp`
into a temporary pod mounting the same PVC, or, on real GKE, directly onto
the Filestore share the PVC is backed by (see
[ARCHITECTURE.md](ARCHITECTURE.md) §5 for local-path-vs-Filestore per
environment). Confirm the actual on-prem content path before scripting
this — Ghost's default layout is assumed here, not confirmed against the
real server.

### Step 3: Deploy Ghost, pointed at the migrated data

With data in place, promote this environment through the normal GitOps
flow — no special "migration mode," the same mechanism every future
deploy uses:

- **Test:** push to `main` — deploys immediately (see
  [FLOW.md](FLOW.md)).
- **Acceptance:** cut and push a tag.
- **Production:** the full reviewed-PR pin-bump procedure in
  [BRANCHING.md](BRANCHING.md).

Ghost's database and Secret Manager (or SOPS, on the demo track)
credentials must already be updated to point at the freshly-loaded Cloud
SQL instance before this step — see [AUTOMATION.md](AUTOMATION.md) for how
secrets are wired per track.

### Step 4: Validate before touching DNS

With Ghost running on GKE but DNS still pointed at on-prem, validate
directly against the new environment's reserved IP, bypassing DNS
entirely:

```bash
curl -sk -H "Host: ghost.<env>.example.com" https://<reserved-ip>/
```

Confirm: the homepage loads, an existing post (migrated from the old
database) renders correctly, an existing uploaded image (migrated
content) loads, and the admin panel (`/ghost/`) logs in against the
migrated user data. Anything wrong here is cheap to fix — nothing
customer-facing has moved yet.

### Step 5: DNS cutover

Update the GoDaddy A record for this environment's hostname to the
reserved GKE IP from Phase 0. Propagation depends on the current record's
TTL — check it beforehand and, if practical, lower it a day ahead of the
planned cutover so the change takes effect quickly rather than over the
old TTL's full window.

```
Before:  ghost.<env>.example.com  →  <on-prem IP>
After:   ghost.<env>.example.com  →  <reserved GKE IP>
```

### Step 6: Soak period, on-prem left running as the rollback target

Leave the on-prem instance for this environment running and untouched for
an agreed soak period (a realistic default: 48 hours for Test/Acceptance,
one full business week for Production, longer if the CTO or team wants
more confidence before Phase 4). If anything surfaces, rollback is
reverting the one A record back to the on-prem IP — no data was deleted,
nothing was torn down yet.

### Step 7: Move to the next environment

Only after this environment's soak period completes without incident.
Test → Acceptance → Production, never in parallel — see "Migration
principles" above for why.

## Phase 4: Decommission on-prem

Only after **all three** environments have completed their soak period on
GKE:

1. Take a final MySQL and content backup of each on-prem environment, kept
   for an agreed retention period — not because it's expected to be
   needed, but because deleting the only copy of years of blog content on
   the same day traffic moves off it is an avoidable risk for a
   near-zero cost.
2. Decommission the on-prem NGINX/Ghost/MySQL infrastructure per its own
   existing runbook (outside this repository's scope — this document
   covers the GKE side of the migration, not on-prem teardown procedure).
3. Remove any now-unused firewall rules, VPN routes, or other network
   paths that existed solely to reach the on-prem environment.

## Full timeline

```
Phase 0 ──▶ Test migration ──▶ Acceptance migration ──▶ Production migration ──▶ Phase 4
(once)      (data, deploy,      (data, deploy,             (data, deploy,          (decommission
             validate,           validate,                  validate,               on-prem,
             cutover, soak)      cutover, soak)              cutover, soak)          all envs)
```

## Risk summary

| Risk | Mitigation |
|---|---|
| MySQL dump/restore window longer than acceptable, especially for Production | Confirm the on-prem cluster's replication capability during Phase 0; use Cloud SQL's continuous-replication migration path for Production if it's supported, rather than defaulting to dump/restore everywhere |
| Content migration misses files (wrong path assumed) | Validate Step 4 explicitly checks a real uploaded image, not just that the homepage renders |
| DNS cutover doesn't propagate quickly | Lower the record's TTL ahead of the planned cutover window, not on the day of |
| Migrated environment breaks after cutover, once on-prem traffic has stopped | Soak period keeps on-prem running and rollback-ready — Step 6 is not optional, especially for Production |
| Credentials for the new Cloud SQL instance leak into logs or shell history during a manual dump/restore | Use Secret Manager references in the actual migration tooling/scripts rather than plaintext flags where the tooling supports it; treat the migration window itself as needing the same secret-handling discipline as steady-state operation |
