# Routing: from a public IP to Ghost

How a request actually reaches Ghost, layer by layer, for both the real
GKE track and the local demo. Both tracks use the same mechanism — the
[Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/), implemented by
[Envoy Gateway](https://gateway.envoyproxy.io/) — only the edge (DNS,
load balancer, TLS issuer) differs.

## Real GKE

```
Browser
   │  DNS lookup: ghost.<env>.example.com
   ▼
GoDaddy DNS  ──▶  A record  ──▶  reserved GCP external IP
   │
   ▼
GCP external Load Balancer
   (provisioned automatically from the Gateway's LoadBalancer Service,
    pinned to the reserved IP via Gateway.spec.addresses)
   │
   ▼
Envoy proxy pod  (envoy-gateway-system namespace)
   │
   ├─▶ port 80  (HTTP listener)
   │      only used for ACME HTTP-01 challenge routes —
   │      cert-manager temporarily attaches an HTTPRoute here
   │      to prove domain control to Let's Encrypt
   │
   └─▶ port 443  (HTTPS listener)
          TLS terminated here, using the Secret cert-manager
          populated from the Let's Encrypt certificate
          │
          ▼
        HTTPRoute match (hostname + path prefix "/")
          │
          ▼
        Ghost Kubernetes Service (ClusterIP, port 2368)
          │
          ▼
        Ghost pod
```

**TLS issuance**: the `Gateway` resource carries a
`cert-manager.io/cluster-issuer` annotation. cert-manager's own Gateway API
integration watches for this, creates a `Certificate` automatically, and
solves it via HTTP-01 — no separate `Certificate` resource authored by
hand, and no DNS-level access needed (see
[ARCHITECTURE.md](ARCHITECTURE.md) §4 for why HTTP-01 over DNS-01).

**Static IP**: `Gateway.spec.addresses` pins the Envoy proxy's
`LoadBalancer` Service to a Terraform-reserved external IP
(`infra/gcp/stages/3-networking`), rather than accepting GCP's default
ephemeral one — this is what makes the GoDaddy A record trustworthy
long-term, since an ephemeral IP isn't guaranteed to survive the
`Service`/`Gateway` being deleted and recreated.

## Local demo

```
Browser
   │  DNS lookup: ghost.test.local  (or .acceptance.local / .local)
   ▼
/etc/hosts   (manually mapped, once per environment, to that
              vCluster's own Docker bridge IP — each environment
              gets a distinct IP, since each is a separate vCluster)
   │
   ▼
vCluster's LoadBalancer Service  (Docker bridge, vCluster's
                                   own docker-driver networking)
   │
   ▼
Envoy proxy pod
   │
   └─▶ port 443  (HTTPS listener — no port 80; there's no ACME
          challenge to serve locally, since TLS uses a SelfSigned
          issuer, not Let's Encrypt)
          │
          ▼
        HTTPRoute match (hostname + path prefix "/")
          │
          ▼
        Ghost Kubernetes Service (ClusterIP, port 2368)
          │
          ▼
        Ghost pod
```

Reaching a demo environment always needs one manual, one-time step per
environment: adding its bridge IP to `/etc/hosts`. Find the IP with:

```bash
kubectl --context vcluster-docker_<env> -n envoy-gateway-system get svc
```

The browser will also warn about an untrusted certificate on first load —
expected, since the demo's `SelfSigned` issuer has no public certificate
authority behind it. Accepting the warning is the local-only equivalent of
a real trust chain.

## What stays identical between the two tracks

- **The Gateway API resources themselves** — `GatewayClass`, `Gateway`,
  `HTTPRoute` — are the same shapes, same Envoy Gateway implementation,
  same reconciliation model.
- **Ghost's own Service and pod** — completely unaware of which track it's
  running on; the chart never hardcodes a hostname, storage class, or TLS
  detail — see [ARCHITECTURE.md](ARCHITECTURE.md) §7.

## What differs, and why

| | Real GKE | Local demo |
|---|---|---|
| DNS | GoDaddy A record → real GCP IP | `/etc/hosts`, manual, per environment |
| Load balancer | Real GCP external LB | vCluster's Docker-bridge LB |
| TLS issuer | Let's Encrypt (HTTP-01) | `SelfSigned` |
| HTTP (port 80) listener | Yes — needed for ACME challenges | No — nothing needs it |
| IP stability | Reserved, Terraform-managed | Docker bridge IP, stable per vCluster instance |

Every difference traces back to one root cause: real GKE needs a publicly
verifiable certificate and a stable public IP; the local demo, running on
`localhost`-only names with no public reachability, needs neither — and
skipping ACME entirely removes the one listener (port 80) that would
otherwise have no purpose there.
