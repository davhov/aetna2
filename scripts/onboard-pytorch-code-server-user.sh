#!/usr/bin/env bash
set -euo pipefail

KUBECONFIG_PATH="./local.yaml"
KUBECTL="kubectl"
OUTPUT_DIR="./generated/onboarding"
STORAGE_SIZE="500Gi"
GPU_COUNT="1"
FIRST_NAME=""
LAST_NAME=""
DRY_RUN="false"

EXPECTED_NEW_CLUSTER_SERVER="https://usg-demo-4.sb.dfki.de:32004/k8s/clusters/local"
HOST_NAME="usg-demo-4.sb.dfki.de"
EXTERNAL_PORT="32004"
IMAGE="ghcr.io/davhov/pytorch-code-server:26.04-py3"

STORAGE_TYPE="geneva-local-storage"
STORAGE_CLASS="asr-geneva-local-path"
NODE_NAME="asr-geneva"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/onboard-pytorch-code-server-user.sh [options]

Options:
  --first-name NAME       First name, for example Igor
  --last-name NAME        Surname, for example Vozniak
  --kubeconfig PATH       New-cluster kubeconfig, default ./local.yaml
  --kubectl PATH          kubectl binary path, default kubectl
  --storage-size SIZE     PVC size, default 500Gi. Examples: 500Gi, 1Ti
  --storage-type TYPE     Storage type, default geneva-local-storage
  --gpu-count COUNT       GPU count, default 1
  --output-dir PATH       Generated manifest directory
  --dry-run               Generate YAML only, do not apply
  -h, --help              Show this help

This script is for the new Aetna cluster only. It refuses to run unless the
kubeconfig server is:
  https://usg-demo-4.sb.dfki.de:32004/k8s/clusters/local
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --first-name)
      FIRST_NAME="${2:-}"; shift 2 ;;
    --last-name)
      LAST_NAME="${2:-}"; shift 2 ;;
    --kubeconfig)
      KUBECONFIG_PATH="${2:-}"; shift 2 ;;
    --kubectl)
      KUBECTL="${2:-}"; shift 2 ;;
    --storage-size)
      STORAGE_SIZE="${2:-}"; shift 2 ;;
    --storage-type)
      STORAGE_TYPE="${2:-}"; shift 2 ;;
    --gpu-count)
      GPU_COUNT="${2:-}"; shift 2 ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"; shift 2 ;;
    --dry-run)
      DRY_RUN="true"; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2 ;;
  esac
done

case "$STORAGE_TYPE" in
  geneva-local-storage)
    STORAGE_CLASS="asr-geneva-local-path"
    NODE_NAME="asr-geneva"
    ;;
  *)
    echo "Unsupported storage type: $STORAGE_TYPE" >&2
    echo "Supported values: geneva-local-storage" >&2
    exit 2
    ;;
esac

if [[ -z "$FIRST_NAME" ]]; then
  read -r -p "First name: " FIRST_NAME
fi

if [[ -z "$LAST_NAME" ]]; then
  read -r -p "Last name: " LAST_NAME
fi

normalize_part() {
  local value="$1"
  local field="$2"
  local normalized
  normalized="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"
  if [[ ${#normalized} -lt 2 ]]; then
    echo "$field must contain at least two ASCII letters or digits after normalization." >&2
    exit 2
  fi
  printf '%s' "${normalized:0:2}"
}

if [[ ! -f "$KUBECONFIG_PATH" ]]; then
  echo "Kubeconfig not found: $KUBECONFIG_PATH" >&2
  exit 2
fi

SERVER="$("$KUBECTL" --kubeconfig "$KUBECONFIG_PATH" config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
if [[ "$SERVER" != "$EXPECTED_NEW_CLUSTER_SERVER" ]]; then
  echo "Refusing to run: this onboarding script is for the new cluster only." >&2
  echo "Expected kubeconfig server: $EXPECTED_NEW_CLUSTER_SERVER" >&2
  echo "Actual kubeconfig server:   $SERVER" >&2
  echo "Use ./local.yaml." >&2
  exit 3
fi

NAME_PREFIX="$(normalize_part "$FIRST_NAME" "First name")"
SURNAME_PREFIX="$(normalize_part "$LAST_NAME" "Last name")"
BASE_PREFIX="${NAME_PREFIX}${SURNAME_PREFIX}"

USER_ID=""
for i in $(seq 1 99); do
  candidate="$(printf '%s%02d' "$BASE_PREFIX" "$i")"
  existing="$("$KUBECTL" --kubeconfig "$KUBECONFIG_PATH" get namespace "$candidate" --ignore-not-found -o name 2>/dev/null || true)"
  if [[ -z "$existing" ]]; then
    USER_ID="$candidate"
    break
  fi
done

if [[ -z "$USER_ID" ]]; then
  echo "Could not find a free username for prefix '$BASE_PREFIX' in suffix range 01-99." >&2
  exit 4
fi

PVC_NAME="${USER_ID}-${STORAGE_TYPE}"
APP_NAME="${USER_ID}-pytorch-code-server"
INGRESS_NAME="${USER_ID}-code-server"
BROWSER_URL="https://${HOST_NAME}:${EXTERNAL_PORT}/${USER_ID}-code-server/"
OUTPUT_PATH="${OUTPUT_DIR}/${USER_ID}-pytorch-code-server.yaml"

mkdir -p "$OUTPUT_DIR"

cat > "$OUTPUT_PATH" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${USER_ID}
  labels:
    aetna.dfki.de/onboarded-user: "true"
    aetna.dfki.de/user-id: ${USER_ID}
  annotations:
    aetna.dfki.de/first-name: ${FIRST_NAME}
    aetna.dfki.de/last-name: ${LAST_NAME}
    aetna.dfki.de/storage-type: ${STORAGE_TYPE}
    aetna.dfki.de/storage-size: ${STORAGE_SIZE}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${USER_ID}
  namespace: ${USER_ID}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${USER_ID}-edit
  namespace: ${USER_ID}
subjects:
  - kind: ServiceAccount
    name: ${USER_ID}
    namespace: ${USER_ID}
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: ${USER_ID}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${PVC_NAME}
  namespace: ${USER_ID}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${STORAGE_SIZE}
  storageClassName: ${STORAGE_CLASS}
  volumeMode: Filesystem
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
  namespace: ${USER_ID}
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
    spec:
      nodeSelector:
        kubernetes.io/hostname: ${NODE_NAME}
      containers:
        - name: pytorch-code-server
          image: ${IMAGE}
          imagePullPolicy: Always
          env:
            - name: DEFAULT_WORKSPACE
              value: /home/jovyan
          ports:
            - name: http-port
              containerPort: 8888
              protocol: TCP
            - name: ssh-port
              containerPort: 22
              protocol: TCP
          resources:
            requests:
              nvidia.com/gpu: "${GPU_COUNT}"
            limits:
              nvidia.com/gpu: "${GPU_COUNT}"
          volumeMounts:
            - name: data-volume
              mountPath: /home/jovyan
            - name: dshm
              mountPath: /dev/shm
      volumes:
        - name: data-volume
          persistentVolumeClaim:
            claimName: ${PVC_NAME}
        - name: dshm
          emptyDir:
            medium: Memory
            sizeLimit: 16Gi
---
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}
  namespace: ${USER_ID}
spec:
  type: ClusterIP
  selector:
    app: ${APP_NAME}
  ports:
    - name: http
      port: 80
      targetPort: http-port
      protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${INGRESS_NAME}
  namespace: ${USER_ID}
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/rewrite-target: /\$2
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  ingressClassName: nginx
  rules:
    - host: ${HOST_NAME}
      http:
        paths:
          - path: /${USER_ID}-code-server(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: ${APP_NAME}
                port:
                  number: 80
EOF

echo "Generated user id: $USER_ID"
echo "Namespace: $USER_ID"
echo "PVC: $PVC_NAME"
echo "Deployment/Service: $APP_NAME"
echo "Ingress: $INGRESS_NAME"
echo "URL: $BROWSER_URL"
echo "Manifest: $OUTPUT_PATH"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Dry run only. Nothing was applied to Kubernetes."
  exit 0
fi

"$KUBECTL" --kubeconfig "$KUBECONFIG_PATH" apply -f "$OUTPUT_PATH"
echo "Applied onboarding manifest for $USER_ID."
echo "Check status:"
echo "  kubectl --kubeconfig $KUBECONFIG_PATH -n $USER_ID get deploy,pod,svc,ingress,pvc -o wide"
echo "Open:"
echo "  $BROWSER_URL"
