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
- ServiceAccount `USER_ID`
- RoleBinding `USER_ID-edit`, bound to the built-in namespace-scoped `edit` ClusterRole
- PVC `USER_ID-geneva-local-storage`, `500Gi`, StorageClass `asr-geneva-local-path`
- Deployment `USER_ID-pytorch-code-server`
- Service `USER_ID-pytorch-code-server`
- Ingress `USER_ID-code-server`

Important defaults:

- Image: `ghcr.io/davhov/pytorch-code-server:26.04-py3`
- GPU: one GPU through `nvidia.com/gpu: "1"`
- Node pinning: `asr-geneva`
- No `runtimeClassName`
- Ingress is intentionally open, with no login prompt
- `/dev/shm` is memory-backed and limited to `16Gi`

The ServiceAccount and RoleBinding provide normal namespace-level Kubernetes rights. They do not grant cluster-admin permissions.

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
- GPU count selection
- an `Open` link for each deployment
- a `Del` button for offboarding a user namespace and all deployments in it

The portal creates the same Namespace, PVC, Deployment, Service, and Ingress pattern as the scripts.

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

Operational note:

- The portal ServiceAccount is granted a narrow `bind` permission on the built-in `edit` ClusterRole so it can create each user's namespace-scoped `USER_ID-edit` RoleBinding.
- The portal form posts to `/onboarding/`; using `/` breaks behind the ingress rewrite and must not be changed back.
- Future server/storage placement is controlled from `STORAGE_TYPES` in `k8s/onboarding-portal.yaml`. Add another entry there with a label, StorageClass, and node name when another worker/storage target is ready.
