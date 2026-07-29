# Prerequisites

CLI tools needed to work with this repository — running the local demo,
validating the Terraform, or operating a real GKE environment. Not every
tool is needed for every task; the table notes which.

| Tool | Needed for | Verify |
|---|---|---|
| [Docker](https://www.docker.com/) | Running the local demo — vCluster's `docker` driver needs a running Docker daemon | `docker version` |
| [vcluster CLI](https://www.vcluster.com/) | Creating/managing the local demo's virtual clusters | `vcluster version` |
| [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) | Talking to any cluster or vCluster — demo and real GKE alike | `kubectl version --client` |
| [Helm](https://helm.sh/) | Linting/rendering the Ghost chart locally (`helm lint`, `helm template`) | `helm version` |
| [Flux CLI](https://fluxcd.io/flux/installation/) | Bootstrapping Flux, reconciling, inspecting `Kustomization`/`HelmRelease` state | `flux version` |
| [Terraform](https://developer.hashicorp.com/terraform/install) | Validating/planning the real-GCP infrastructure under `infra/gcp/` | `terraform version` |
| [gcloud CLI](https://cloud.google.com/sdk/docs/install) | GCP authentication for Terraform, one-time Cloud Build bootstrap steps | `gcloud version` |
| [gh CLI](https://cli.github.com/) | GitHub authentication — `flux bootstrap` uses it as a token fallback, useful for repo/release inspection generally | `gh auth status` |
| [SOPS](https://github.com/getsops/sops) | Encrypting/decrypting the secrets committed under `gitops/` | `sops --version` |
| [age](https://github.com/FiloSottile/age) | Generating and holding the key SOPS encrypts against (`age-keygen`) | `age --version` |
| [vendir](https://carvel.dev/vendir/) | Re-vendoring the Fabric Terraform modules under `infra/gcp/modules/fabric/` — only needed to bump a module version, not for day-to-day work | `vendir version` |
| [Go](https://go.dev/) | Not used directly by this repository — needed only if installing SOPS, age, or vendir via `go install` rather than a package manager/prebuilt binary | `go version` |

## Authentication, not just installation

Two of the tools above need to actually be logged in, not just installed,
before anything in this repository works against a real target:

```bash
gh auth login
gcloud auth login
gcloud auth application-default login   # Terraform reads these credentials
```

`flux bootstrap` additionally needs a GitHub token with repo scope
available as `GITHUB_TOKEN` — `infra/demo/Makefile` falls back to
`gh auth token` automatically if it isn't already set, so a working `gh
auth login` covers this too.

## What you don't need

No language runtime for Ghost itself (it runs from the official upstream
container image, never built locally), no cloud billing account to
exercise the local demo, and no GCP project access at all unless you're
actually planning to run `terraform plan`/`apply` against real
infrastructure rather than just reading or validating the code.
