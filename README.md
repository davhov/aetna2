# Aetna 2 Platform Assets

This repository contains platform assets for the new Aetna Kubernetes cluster.

## PyTorch Code Server Image

The GPU development image is built from:

```text
images/pytorch-code-server-26.04/
```

Published image:

```text
ghcr.io/davhov/pytorch-code-server:26.04-py3
```

## User Onboarding

The onboarding project creates open, no-login PyTorch code-server workspaces on the new cluster.

Main files:

- `k8s/onboarding-portal.yaml`: in-cluster DFKI-branded web portal exposed at `https://usg-demo-4.sb.dfki.de:32004/onboarding/`.
- `k8s/baseline-user-pytorch-code-server.yaml`: copy/paste baseline for one user workspace.
- `scripts/onboard-pytorch-code-server-user.ps1`: Windows onboarding script.
- `scripts/onboard-pytorch-code-server-user.sh`: Ubuntu/bash onboarding script.
- `docs/onboarding-pytorch-code-server.md`: operator documentation and naming rules.

The portal creates namespaces, namespace-scoped user rights, PVCs, Deployments, Services, and direct `usg-demo-4` ingress links. It also supports named deployments per user and offboarding through the `Del` button.

Use the new-cluster kubeconfig only:

```text
local.yaml
```

Do not use the old production kubeconfig for this onboarding flow.
