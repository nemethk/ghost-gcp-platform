ENVS             := test acceptance production
GITHUB_OWNER     ?= nemethk
GITHUB_REPO      ?= ghost-gcp-platform
SOPS_AGE_KEY_FILE := $(CURDIR)/../../age.agekey
export SOPS_AGE_KEY_FILE
# Project-local, isolated kubeconfig — for demo purpose only.
KUBECONFIG       := $(CURDIR)/kubeconfig
export KUBECONFIG
# Falls back to gh's already-authenticated token so flux bootstrap doesn't
# prompt interactively — only used if GITHUB_TOKEN isn't already set, and
# only actually runs `gh auth token` for targets that reference it.
GITHUB_TOKEN     ?= $(shell gh auth token)
export GITHUB_TOKEN

.PHONY: up clusters down pause resume status

# Just the raw vClusters — no Flux, no GitHub, no secrets, no MySQL. Useful
# for iterating on demo/vclusters/<env>.yaml itself (node scheduling, ports,
# resource limits) without touching the rest of the stack each time.
clusters: $(addprefix cluster-,$(ENVS))

cluster-%:
	@echo "==> $*: creating vCluster (--upgrade: safe to re-run if it already exists)"
	@vcluster create $* --driver docker --values vclusters/$*.yaml --upgrade

# Full flow for a single environment — e.g. `make up-test` to verify Flux on
# one cluster before rolling out to all three. `up` itself is just this,
# applied to every environment — same recipe either way, nothing duplicated
# between the two.
up-%: cluster-%
	@ctx=vcluster-docker_$*; \
	echo "==> $*: flux bootstrap (ingress-nginx, cert-manager, and the ClusterIssuer are Flux-managed from here — see gitops/platform/controllers/ and gitops/platform/configs/cert-manager/demo/)"; \
	flux bootstrap github \
		--owner=$(GITHUB_OWNER) --repository=$(GITHUB_REPO) --personal \
		--private=false --reconcile \
		--path=gitops/clusters/demo/$* --branch=main --context=$$ctx || exit 1; \
	echo "==> $*: waiting for the ghost namespace (gitops/namespaces/) — bootstrap only forces the root sync, not this downstream Kustomization"; \
	flux reconcile kustomization namespaces --context $$ctx --namespace flux-system --with-source || exit 1; \
	echo "==> $*: sops-age decryption secret (local key, not committed)"; \
	kubectl --context $$ctx create secret generic sops-age \
		--namespace flux-system \
		--from-file=age.agekey=$(SOPS_AGE_KEY_FILE) \
		--dry-run=client -o yaml | kubectl --context $$ctx apply -f - || exit 1; \
	echo "==> $*: mysql-credentials (root password generated; ghost password matches the SOPS-encrypted secret Flux will decrypt)"; \
	ghost_db_password=$$(sops -d --extract '["stringData"]["database-password"]' ../../gitops/apps/demo/$*/secrets.enc.yaml) || exit 1; \
	kubectl --context $$ctx create secret generic mysql-credentials \
		--namespace ghost \
		--from-literal=mysql-root-password=$$(openssl rand -hex 16) \
		--from-literal=database-password=$$ghost_db_password \
		--dry-run=client -o yaml | kubectl --context $$ctx apply -f - || exit 1; \
	echo "==> $*: mysql"; \
	kubectl --context $$ctx apply --namespace ghost -f mysql.yaml || exit 1

up: $(addprefix up-,$(ENVS))
	@echo "Reached via vind's built-in LoadBalancer (LB.md) — add each"
	@echo "environment's own bridge IP to /etc/hosts first:"
	@echo "  kubectl --context vcluster-docker_test       get svc -n envoy-gateway-system"
	@echo "  kubectl --context vcluster-docker_acceptance get svc -n envoy-gateway-system"
	@echo "  kubectl --context vcluster-docker_production get svc -n envoy-gateway-system"
	@echo "Test:        https://ghost.test.local"
	@echo "Acceptance:  https://ghost.acceptance.local"
	@echo "Production:  https://ghost.local"

down-%:
	@echo "==> $*: deleting vCluster"
	@vcluster delete $* --driver docker

down: $(addprefix down-,$(ENVS))

# Fast iteration: stops/starts the underlying Docker containers in seconds,
# without losing cluster state — use this instead of down/up between test
# runs. e.g. `make pause-acceptance` to free up resources for one cluster
# without touching the other two.
pause-%:
	@vcluster pause $* --driver docker

pause: $(addprefix pause-,$(ENVS))

resume-%:
	@vcluster resume $* --driver docker

resume: $(addprefix resume-,$(ENVS))

status:
	@vcluster list --driver docker
