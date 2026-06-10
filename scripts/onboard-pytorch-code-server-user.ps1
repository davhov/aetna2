param(
  [string]$FirstName,
  [string]$LastName,
  [string]$Kubeconfig = ".\local.yaml",
  [string]$Kubectl = "kubectl",
  [string]$OutputDir = ".\generated\onboarding",
  [int]$StorageGi = 500,
  [string]$GpuCount = "1",
  [string]$NodeName = "asr-geneva",
  [string]$StorageClass = "asr-geneva-local-path",
  [string]$HostName = "usg-demo-4.sb.dfki.de",
  [int]$ExternalPort = 32004,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$expectedNewClusterServer = "https://usg-demo-4.sb.dfki.de:32004/k8s/clusters/local"

function Normalize-NamePart {
  param([string]$Value, [string]$FieldName)

  if ([string]::IsNullOrWhiteSpace($Value)) {
    throw "$FieldName is required."
  }

  $normalized = $Value.Trim().ToLowerInvariant() -replace "[^a-z0-9]", ""
  if ($normalized.Length -lt 2) {
    throw "$FieldName must contain at least two ASCII letters or digits after normalization."
  }

  return $normalized.Substring(0, 2)
}

function Invoke-Kubectl {
  param([string[]]$Arguments)

  $output = & $Kubectl @Arguments 2>&1
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    throw "kubectl failed ($exitCode): $($output -join [Environment]::NewLine)"
  }
  return $output
}

if ([string]::IsNullOrWhiteSpace($FirstName)) {
  $FirstName = Read-Host "First name"
}

if ([string]::IsNullOrWhiteSpace($LastName)) {
  $LastName = Read-Host "Last name"
}

$resolvedKubeconfig = Resolve-Path -LiteralPath $Kubeconfig -ErrorAction Stop
$server = (& $Kubectl --kubeconfig $resolvedKubeconfig.Path config view --minify -o jsonpath="{.clusters[0].cluster.server}" 2>&1)
if ($LASTEXITCODE -ne 0) {
  throw "Could not inspect kubeconfig '$($resolvedKubeconfig.Path)': $server"
}

if ($server -ne $expectedNewClusterServer) {
  throw "Refusing to run: this onboarding script is for the new cluster only. Expected kubeconfig server '$expectedNewClusterServer', got '$server'. Use .\local.yaml."
}

$namePrefix = Normalize-NamePart -Value $FirstName -FieldName "First name"
$surnamePrefix = Normalize-NamePart -Value $LastName -FieldName "Last name"
$basePrefix = "$namePrefix$surnamePrefix"

$selectedUserId = $null
for ($i = 1; $i -le 99; $i++) {
  $candidate = "{0}{1:00}" -f $basePrefix, $i
  $existing = & $Kubectl --kubeconfig $resolvedKubeconfig.Path get namespace $candidate --ignore-not-found -o name 2>$null
  if ([string]::IsNullOrWhiteSpace($existing)) {
    $selectedUserId = $candidate
    break
  }
}

if (-not $selectedUserId) {
  throw "Could not find a free username for prefix '$basePrefix' in suffix range 01-99."
}

$userId = $selectedUserId
$pvcName = "$userId-geneva-local-storage"
$appName = "$userId-pytorch-code-server"
$ingressName = "$userId-code-server"
$ingressPath = "/$userId-code-server(/|$)(.*)"
$browserUrl = "https://${HostName}:${ExternalPort}/$userId-code-server/"
$outputPath = Join-Path $OutputDir "$userId-pytorch-code-server.yaml"

$gpuMode = $GpuCount.Trim().ToUpperInvariant()
if ($gpuMode -notin @("0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "P")) {
  throw "GpuCount must be 0, 1 through 10, or P."
}

$gpuResourceBlock = ""
if ($gpuMode -match "^[1-9]$|^10$") {
  $gpuResourceBlock = @"
          resources:
            requests:
              nvidia.com/gpu: "$gpuMode"
            limits:
              nvidia.com/gpu: "$gpuMode"
"@
} elseif ($gpuMode -eq "P") {
  $gpuResourceBlock = @"
          securityContext:
            privileged: true
"@
}

$manifest = @"
apiVersion: v1
kind: Namespace
metadata:
  name: $userId
  labels:
    aetna.dfki.de/onboarded-user: "true"
    aetna.dfki.de/user-id: $userId
  annotations:
    aetna.dfki.de/first-name: $FirstName
    aetna.dfki.de/last-name: $LastName
    aetna.dfki.de/storage-type: geneva-local-storage
    aetna.dfki.de/storage-size: ${StorageGi}Gi
    aetna.dfki.de/url: $browserUrl
---
apiVersion: management.cattle.io/v3
kind: User
metadata:
  name: $userId
  labels:
    aetna.dfki.de/onboarded-user: "true"
    aetna.dfki.de/user-id: $userId
displayName: "$FirstName $LastName"
description: Aetna onboarded user $userId
username: $userId
enabled: true
mustChangePassword: true
---
apiVersion: management.cattle.io/v3
kind: ClusterRoleTemplateBinding
metadata:
  name: $userId-local-cluster-member
  namespace: local
clusterName: local
roleTemplateName: cluster-member
userName: $userId
userPrincipalName: local://$userId
---
apiVersion: v1
kind: Secret
metadata:
  name: $userId
  namespace: cattle-local-user-passwords
  annotations:
    cattle.io/password-hash: bcrypt
  labels:
    aetna.dfki.de/onboarded-user: "true"
    aetna.dfki.de/user-id: $userId
type: Opaque
data:
  password: JDJiJDEyJDRHbFNKZkZQckxmY3YuUEltZkFMR2U0SzFyWjRJVHlIMS4wV0J0cmszUC9QL0VXT2JVNFRl
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $userId
  namespace: $userId
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $userId-edit
  namespace: $userId
subjects:
  - kind: ServiceAccount
    name: $userId
    namespace: $userId
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: $userId
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $pvcName
  namespace: $userId
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${StorageGi}Gi
  storageClassName: $StorageClass
  volumeMode: Filesystem
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $appName
  namespace: $userId
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: $appName
  template:
    metadata:
      labels:
        app: $appName
    spec:
      nodeSelector:
        kubernetes.io/hostname: $NodeName
      containers:
        - name: pytorch-code-server
          image: ghcr.io/davhov/pytorch-code-server:26.04-py3
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
$gpuResourceBlock
          volumeMounts:
            - name: data-volume
              mountPath: /home/jovyan
            - name: dshm
              mountPath: /dev/shm
      volumes:
        - name: data-volume
          persistentVolumeClaim:
            claimName: $pvcName
        - name: dshm
          emptyDir:
            medium: Memory
            sizeLimit: 16Gi
---
apiVersion: v1
kind: Service
metadata:
  name: $appName
  namespace: $userId
spec:
  type: ClusterIP
  selector:
    app: $appName
  ports:
    - name: http
      port: 80
      targetPort: http-port
      protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $ingressName
  namespace: $userId
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/rewrite-target: /`$2
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  ingressClassName: nginx
  rules:
    - host: $HostName
      http:
        paths:
          - path: $ingressPath
            pathType: ImplementationSpecific
            backend:
              service:
                name: $appName
                port:
                  number: 80
"@

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
Set-Content -Path $outputPath -Value $manifest -Encoding ascii

Write-Host "Generated user id: $userId"
Write-Host "Namespace: $userId"
Write-Host "PVC: $pvcName"
Write-Host "Deployment/Service: $appName"
Write-Host "Ingress: $ingressName"
Write-Host "URL: $browserUrl"
Write-Host "Manifest: $outputPath"

if ($DryRun) {
  Write-Host "Dry run only. Nothing was applied to Kubernetes."
  exit 0
}

Invoke-Kubectl -Arguments @("--kubeconfig", $resolvedKubeconfig.Path, "apply", "-f", $outputPath) | Write-Host
Write-Host "Applied onboarding manifest for $userId."
Write-Host "Check status:"
Write-Host "  kubectl --kubeconfig $($resolvedKubeconfig.Path) -n $userId get deploy,pod,svc,ingress,pvc -o wide"
Write-Host "Open:"
Write-Host "  $browserUrl"
