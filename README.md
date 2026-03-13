# AKSAzureGitOpsLab — C++ Service on Azure Kubernetes Service

A minimal C++ HTTP server deployed to AKS via GitHub Actions.

```
AKSAzureGitOpsLab/
├── app/
│   └── main.cpp                  # C++17 HTTP server (port 8080)
├── k8s/
│   ├── deployment.yaml           # 2-replica Deployment
│   ├── service.yaml              # Azure LoadBalancer Service
│   └── hpa.yaml                  # HPA (2–10 replicas, 60% CPU)
├── infra/
│   └── main.tf                   # Terraform: Resource Group + ACR + AKS
├── .github/
│   └── workflows/
│       └── deploy.yml            # CI/CD pipeline
├── CMakeLists.txt
└── Dockerfile                    # Multi-stage build
```

## Prerequisites

| Tool | Version |
|------|---------|
| Azure CLI | ≥ 2.55 |
| kubectl | ≥ 1.28 |
| Terraform | ≥ 1.6 |
| Docker | ≥ 24 |

## 1. Provision infrastructure

```bash
cd infra
terraform init
terraform apply          # creates RG + ACR + AKS (~8 min)
```

## 2. Configure GitHub Secrets

Create a service principal and add the following **Repository Secrets**:

```bash
az ad sp create-for-rbac \
  --name "aksazuregitopslab-sp" \
  --role contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID> \
  --sdk-auth
```

| Secret | Description |
|--------|-------------|
| `AZURE_CREDENTIALS` | Full JSON output from `az ad sp create-for-rbac --sdk-auth` |
| `ARM_CLIENT_ID` | `clientId` from the JSON above |
| `ARM_CLIENT_SECRET` | `clientSecret` from the JSON above |
| `ARM_SUBSCRIPTION_ID` | Your Azure subscription ID |
| `ARM_TENANT_ID` | `tenantId` from the JSON above |

## 3. Deploy

Push to `main` — the workflow will:

1. **Build** the Docker image and push to ACR
2. **Deploy** to AKS via `kubectl apply`
3. **Wait** for the rollout to complete

Pull requests trigger a **Terraform plan** (no apply) so infra changes are reviewed before merge.

## 4. Test locally

```bash
# Build
cmake -B build && cmake --build build

# Run
./build/server &

curl http://localhost:8080/
# {"message":"Hello from AKS!","version":"1.0.0"}

curl http://localhost:8080/healthz
# {"status":"healthy","service":"aksazuregitopslab"}
```

## Endpoints

| Path | Response |
|------|----------|
| `GET /` | `{"message":"Hello from AKS!","version":"1.0.0"}` |
| `GET /healthz` | `{"status":"healthy","service":"aksazuregitopslab"}` |
