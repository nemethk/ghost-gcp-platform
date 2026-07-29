# The demo

`infra/demo/` runs the same GitOps mechanism this repository uses on real
GKE, entirely on a laptop, with zero cloud spend: three
[vCluster](https://www.vcluster.com/)s (Test, Acceptance, Production) on
Docker, each running its own Flux instance, each bootstrapped against a
different path in this same repository. A `Makefile` brings each one up
(`make up-<env>`) or tears it down (`make down-<env>`); step-by-step usage
lives in `infra/demo/README.md`.

It's a genuine rehearsal of the real deployment mechanism, not a separate
toy version of it — the same Helm chart, the same Kustomize structure, and
the same Flux reconcile loop that would run against real GKE run here
too. What differs is only the edge of the system: `SelfSigned` TLS instead
of Let's Encrypt, a local MySQL container instead of Cloud SQL, `/etc/hosts`
instead of real DNS — see [ARCHITECTURE.md](ARCHITECTURE.md) §7 for the
full comparison.

## Confirming which version is actually running

Every response from Ghost carries a custom header:

```
x-chart-version: 0.2.0+a11db72e876c
```

The base version (`0.2.0`) comes directly from
`gitops/charts/ghost/Chart.yaml`'s own `version` field, reflected through
an `HTTPRoute` `ResponseHeaderModifier` filter — nothing to keep in sync by
hand, it's read straight from the chart at render time. The suffix after
the `+` is added automatically by Flux, since Ghost's `HelmRelease`
sources its chart directly from this repository's git history rather than
a packaged chart repository — it's the git revision Flux resolved at
install time.

This makes the header a direct, no-guesswork answer to "is this
environment actually running what I think it's running" — useful when
demonstrating a promotion live: tag a change, promote it to an
environment, and `curl -I` that environment to see the exact chart version
and git revision serving the response change in real time.

```bash
curl -sk -D - https://ghost.<env>.local/ -o /dev/null | grep x-chart-version
```
