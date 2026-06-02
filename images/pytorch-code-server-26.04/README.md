# PyTorch Code Server 26.04

Standardized GPU development image for the new Aetna cluster.

Base image:

```text
nvcr.io/nvidia/pytorch:26.04-py3
```

Adds:

- code-server on port `8888`
- OpenSSH server on port `22`
- `sudo` for the existing `ubuntu` user
- default workspace at `/home/jovyan`

Local image built and tested as:

```text
local/pytorch-code-server:26.04-py3
```

Build:

```powershell
docker build -t local/pytorch-code-server:26.04-py3 .
```

Run locally:

```powershell
docker run --rm -p 8888:8888 local/pytorch-code-server:26.04-py3
```

Save as tar:

```powershell
docker save -o pytorch-code-server_26.04-py3.tar local/pytorch-code-server:26.04-py3
```

For GitHub, keep this build recipe in Git. Push the actual image to a container registry such as GHCR.

