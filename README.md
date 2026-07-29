# ghost-gcp-platform

Migrating a Ghost blog — currently on-premise, behind an NGINX reverse
proxy, backed by a MySQL cluster — onto Kubernetes on Google Cloud (GKE),
across Test, Acceptance, and Production. Infrastructure is Terraform;
application delivery is Flux (GitOps) — one repository, one source of
truth for both.

A working local demo of the entire deployment mechanism runs on a laptop
with zero cloud spend — see [Quick start](#quick-start) below.

## Repository structure

```
.
├── infra/
│   ├── gcp/     # Terraform — real GCP infrastructure (see infra/gcp/README.md)
│   └── demo/    # local demo tooling — 3 vClusters on Docker (see infra/demo/README.md)
├── gitops/      # everything Flux manages (see gitops/README.md)
└── docs/        # architecture, process, and operations documentation
```

Each of the three linked READMEs above covers the "why" for its own part
of the tree in detail — this file is the map, not a repeat of that
content.

## Documentation

| Document | Covers |
|---|---|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | The comprehensive design: requirements, topology, compute, networking, data, assumptions |
| [`docs/ROUTING.md`](docs/ROUTING.md) | How a request reaches Ghost, from a public IP down to the pod |
| [`docs/IAC.md`](docs/IAC.md) | Terraform structure — vendored modules, stages, state flow |
| [`docs/AUTOMATION.md`](docs/AUTOMATION.md) | Cloud Build's pipeline and Flux's reconcile chain, and the boundary between them |
| [`docs/FLOW.md`](docs/FLOW.md) | End-to-end: what happens from a commit to a running change |
| [`docs/BRANCHING.md`](docs/BRANCHING.md) | Promotion strategy per environment, including tag-ordering rules and recovery steps |
| [`docs/MIGRATION.md`](docs/MIGRATION.md) | Step-by-step plan for the actual on-prem → GKE migration |
| [`docs/MONITORING.md`](docs/MONITORING.md) | The Prometheus/Loki/Grafana stack |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | What's deferred, why, and roughly how much effort each item is |
| [`docs/DEMO.md`](docs/DEMO.md) | What the local demo shows, and how to confirm what's actually running |
| [`docs/PREREQUISITES.md`](docs/PREREQUISITES.md) | Every CLI tool needed, and what each is for |

## Quick start

The fastest way to see this working: bring up the local demo.

```bash
cd infra/demo
make up-test
```

Full walkthrough, including how to reach Ghost in a browser and how to
promote a change through all three environments, is in
[`infra/demo/README.md`](infra/demo/README.md).

## Real GCP infrastructure

`infra/gcp/` is Terraform for the real infrastructure this design targets
— written to be reviewed and to pass `terraform validate` cleanly. See
[`infra/gcp/README.md`](infra/gcp/README.md) for the module/stage
structure, and [`docs/IAC.md`](docs/IAC.md) for the higher-level narrative
around it.
