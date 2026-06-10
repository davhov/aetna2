# Baseline User PyTorch Code Server

Use this manifest as the copy/paste baseline for one user workload on the new Aetna cluster only.

Do not apply this to the old production cluster and do not use `aetna-2.yaml` for this onboarding flow. Use the new-cluster kubeconfig:

```text
local.yaml
```

```text
k8s/baseline-user-pytorch-code-server.yaml
```

Replace every `USER_ID` with a lowercase namespace-safe identifier such as `daho03`, `igvo01`, or `mopu01`.

The automated onboarding script is:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\onboard-pytorch-code-server-user.ps1 -Kubeconfig .\local.yaml
```

Ubuntu/bash version:

```bash
./scripts/onboard-pytorch-code-server-user.sh --kubeconfig ./local.yaml
```

If `kubectl` is not in `PATH`, pass it explicitly:

```bash
./scripts/onboard-pytorch-code-server-user.sh --kubeconfig ./local.yaml --kubectl /path/to/kubectl
```

For example, entering first name `Igor` and surname `Vozniak` creates `igvo01` if that namespace is free. If `igvo01` already exists, the script tries `igvo02`, then `igvo03`, up to `igvo99`.

Non-interactive example:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\onboard-pytorch-code-server-user.ps1 -Kubeconfig .\local.yaml -FirstName Igor -LastName Vozniak
```

Dry-run example:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\onboard-pytorch-code-server-user.ps1 -Kubeconfig .\local.yaml -FirstName Igor -LastName Vozniak -DryRun
```

After applying the manifest, the browser URL is:

```text
https://usg-demo-4.sb.dfki.de:32004/USER_ID-code-server/
```

Example for `daho03`:

```text
https://usg-demo-4.sb.dfki.de:32004/daho03-code-server/
```

The baseline creates:

- Namespace `USER_ID`
- Rancher local User `USER_ID`, with the initial Rancher UI password stored in `cattle-local-user-passwords/USER_ID` and `mustChangePassword: true`
- Rancher GlobalRoleBinding `USER_ID-standard-user`, granting the built-in `user` global role
- Rancher ClusterRoleTemplateBinding `USER_ID-local-cluster-member`, granting `cluster-member` visibility on cluster `local`
- ServiceAccount `USER_ID`
- RoleBinding `USER_ID-edit`, bound to the built-in namespace-scoped `edit` ClusterRole
- PVC `USER_ID-geneva-local-storage`, `500Gi`, StorageClass `asr-geneva-local-path`
- Deployment `USER_ID-pytorch-code-server`
- Service `USER_ID-pytorch-code-server`
- Ingress `USER_ID-code-server`

Important defaults:

- Image: `ghcr.io/davhov/pytorch-code-server:26.04-py3`
- GPU: default is one GPU through `nvidia.com/gpu: "1"`. The onboarding portal supports GPU modes `0`, `1` through `10`, and `P`; `0` omits GPU requests, numeric values request that many GPUs, and `P` runs privileged without a GPU request/limit so all device-visible GPUs can be seen.
- Node pinning: `asr-geneva`
- No `runtimeClassName`
- Ingress is intentionally open, with no login prompt
- `/dev/shm` is memory-backed and limited to `16Gi`
- Rancher UI login password: initial password `qweasd123`; Rancher forces the user to change it after first login. The password is not stored on the `User` CRD directly; it is seeded through the Rancher local-user password Secret.

The Rancher cluster-member binding makes the `local` cluster and cluster-scoped Rancher navigation visible. The ServiceAccount and namespace RoleBinding provide normal namespace-level Kubernetes workload rights. They do not grant cluster-admin permissions.

The RoleBinding includes both:

- ServiceAccount `USER_ID`
- Kubernetes User `USER_ID`

This lets service-account based access and username-based Rancher/Kubernetes access see the same namespace-scoped services. Admins can see all namespaces and services from Rancher; a normal user identity matching `USER_ID` should only need access to its own namespace resources.

The script refuses to run unless the kubeconfig points to the new Rancher-proxied cluster endpoint `https://usg-demo-4.sb.dfki.de:32004/k8s/clusters/local`.

## Web Onboarding Portal

The in-cluster onboarding portal is deployed on the new cluster at:

```text
https://usg-demo-4.sb.dfki.de:32004/onboarding/
```

It provides a DFKI-branded page with:

- list of users created by the onboarding flow
- first-name and surname fields
- deployment name field
- storage type selection
- storage amount selection
- GPU mode selection: `0`, `1` through `10`, or `P` for privileged/no GPU request mode
- an `Open` link for each deployment
- a `Del` button for offboarding a user namespace and all deployments in it

The portal creates the same Namespace, PVC, Deployment, Service, and Ingress pattern as the scripts.
It also creates the matching Rancher local User `USER_ID`, seeds the default Rancher UI password through `cattle-local-user-passwords/USER_ID`, sets `mustChangePassword: true`, and grants the Rancher `user` plus `local` cluster-member bindings required for the user to see the cluster in Rancher.

User IDs are generated from the first two characters of the first name plus the first two characters of the surname plus a numeric suffix. For example, `Igor Vozniak` becomes `igvo01` if that namespace is free.

Deployment naming:

- Deployment name `main` preserves the original naming pattern:
  - Deployment and Service: `USER_ID-pytorch-code-server`
  - PVC: `USER_ID-geneva-local-storage`
  - Ingress URL: `https://usg-demo-4.sb.dfki.de:32004/USER_ID-code-server/`
- Any other deployment name creates a second named workspace in the same namespace:
  - Deployment and Service: `USER_ID-DEPLOYMENT-pytorch-code-server`
  - PVC: `USER_ID-DEPLOYMENT-geneva-local-storage`
  - Ingress URL: `https://usg-demo-4.sb.dfki.de:32004/USER_ID-DEPLOYMENT-code-server/`

Offboarding from the portal deletes the whole user namespace. That removes the ServiceAccount, RoleBinding, PVCs, Deployments, Services, and Ingresses for that user. Kubernetes namespace deletion is asynchronous, so the namespace may remain visible in `kubectl` briefly while it is terminating.
Offboarding also deletes the matching Rancher local User `USER_ID`, its deterministic Rancher access bindings, and its local-user password Secret.

Operational note:

- The portal ServiceAccount is granted a narrow `bind` permission on the built-in `edit` ClusterRole so it can create each user's namespace-scoped `USER_ID-edit` RoleBinding.
- The portal form posts to `/onboarding/`; using `/` breaks behind the ingress rewrite and must not be changed back.
- Future server/storage placement is controlled from `STORAGE_TYPES` in `k8s/onboarding-portal.yaml`. Add another entry there with a label, StorageClass, and node name when another worker/storage target is ready.

## GPU Usage Dashboard

The new cluster has the same Rancher-style GPU usage dashboard pattern as production:

```text
k8s/gpu-usage-dashboard.yaml
```

It creates:

- Namespace `kube-utils`
- Deployment/Service `k8s-gpu-usage`
- ConfigMap `k8s-gpu-usage-custom-app`
- RBAC for the dashboard ServiceAccount
- Role/RoleBinding allowing authenticated users to open the `k8s-gpu-usage` service proxy
- Rancher `NavLink` named `gpu-usage-dashboard`

Rancher NavLink target:

```text
https://usg-demo-4.sb.dfki.de:32004/k8s/clusters/local/api/v1/namespaces/kube-utils/services/http:k8s-gpu-usage:80/proxy/
```

The dashboard uses the new cluster's GPU Operator host-driver layout and collects from `gpu-operator` pods labeled `app=nvidia-dcgm-exporter`.

## Rancher Sidebar Code-Server Links

The new cluster runs a small controller that publishes one Rancher sidebar entry for all onboarded code-server deployments:

```text
k8s/code-server-navlink-controller.yaml
```

It creates a single Rancher `NavLink` named `code-server-links` with label `Code Server Links`. The target is the controller's service proxy:

```text
https://usg-demo-4.sb.dfki.de:32004/k8s/clusters/local/api/v1/namespaces/kube-utils/services/http:code-server-links:80/proxy/
```

The page discovers Deployments labeled `aetna.dfki.de/user-id` and renders direct code-server URLs with the default workspace:

```text
https://usg-demo-4.sb.dfki.de:32004/USER_ID-DEPLOYMENT-code-server/?folder=/home/jovyan
```

The visible row label is:

```text
USER_ID - DEPLOYMENT
```

The dashboard filters in the browser with the logged-in Rancher session. Admin users such as `daho03` see links from all namespaces; onboarded users see only rows where the namespace or `aetna.dfki.de/user-id` label matches their Rancher username. The controller also removes old per-service `NavLink` objects labeled `aetna.dfki.de/code-server-navlink=true`, because Rancher `NavLink` objects are cluster-scoped and do not provide per-user visibility.
