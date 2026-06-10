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

- `k8s/onboarding-portal.yaml`: in-cluster DFKI-branded web portal exposed at `https://us..-4.......de:32004/onboarding/`.
- `k8s/baseline-user-pytorch-code-server.yaml`: copy/paste baseline for one user workspace.
- `k8s/code-server-navlink-controller.yaml`: controller that publishes the filtered Rancher `Code Server Links` dashboard for onboarded code-server deployments.
- `scripts/onboard-pytorch-code-server-user.ps1`: Windows onboarding script.
- `scripts/onboard-pytorch-code-server-user.sh`: Ubuntu/bash onboarding script.
- `docs/onboarding-pytorch-code-server.md`: operator documentation and naming rules.

The portal creates namespaces, namespace-scoped user rights, PVCs, Deployments, Services, and direct `us....-4` ingress links. It also supports named deployments per user, GPU modes `0`, `1` through `10`, and `P`, plus offboarding through the `Del` button. The `Code Server Links` dashboard shows all links to admins such as `daho03`, while normal onboarded users see only their own namespace links.

The portal also creates a Rancher local user named `USER_ID`, plus the matching `cattle-local-user-passwords/USER_ID` password Secret for the initial Rancher UI password `qweasd123`. `mustChangePassword: true` is set on the Rancher User. Each user receives the Rancher `user` global role plus `cluster-member` access on the `local` cluster so the cluster appears in Rancher, while Kubernetes workload rights remain namespace-scoped. Code-server itself remains open/no-login.

## GPU Usage Dashboard

The new cluster GPU dashboard is defined in:

```text
k8s/gpu-usage-dashboard.yaml
```

It deploys `kube-utils/k8s-gpu-usage` and a Rancher `NavLink` named `gpu-usage-dashboard`, matching the production cluster pattern. The new cluster uses GPU Operator host-driver mode, so the dashboard collects through `gpu-operator` pods labeled `app=nvidia-dcgm-exporter`.
