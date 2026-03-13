# AKSAzureGitOpsLab

[![Build & Deploy to AKS](https://github.com/techytanveer/AKSAzureGitOpsLab/actions/workflows/deploy.yml/badge.svg?branch=main)](https://github.com/YOUR_GITHUB_USERNAME/AKSAzureGitOpsLab/actions/workflows/deploy.yml)
[![Docker](https://img.shields.io/badge/Docker-multi--stage-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![ACR](https://img.shields.io/badge/Azure%20Container%20Registry-aksdemoregistry-0078D4?logo=microsoftazure&logoColor=white)](https://azure.microsoft.com/en-us/products/container-registry)
[![AKS](https://img.shields.io/badge/Azure%20Kubernetes%20Service-aksazuregitopslab--cluster-0078D4?logo=microsoftazure&logoColor=white)](https://azure.microsoft.com/en-us/products/kubernetes-service)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.6-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![C++](https://img.shields.io/badge/C%2B%2B-17-00599C?logo=cplusplus&logoColor=white)](https://en.cppreference.com/w/cpp/17)
[![CMake](https://img.shields.io/badge/CMake-%3E%3D3.16-064F8C?logo=cmake&logoColor=white)](https://cmake.org/)
[![kubectl](https://img.shields.io/badge/kubectl-%3E%3D1.28-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/docs/reference/kubectl/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> A minimal **C++17 HTTP server** built with CMake, containerised via a multi-stage Docker build, and deployed to **Azure Kubernetes Service** through a fully automated **GitHub Actions** CI/CD pipeline. Infrastructure is managed with **Terraform**.

---

## Architecture

```
GitHub Actions
  ├── build job  →  docker build  →  push to ACR
  ├── deploy job →  kubectl apply →  AKS (2–10 pods, HPA)
  └── terraform  →  plan on PRs   →  infra review gate

AKS Cluster (aksazuregitopslab-cluster)
  └── Deployment: aksazuregitopslab  (port 8080)
        └── Service: LoadBalancer    (port 80)
              └── HPA: 2–10 replicas @ 60% CPU
```

## Project Structure

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
| CMake | ≥ 3.16 |
| GCC / Clang | C++17 support |

## 1. Provision Infrastructure

```bash
cd infra
terraform init
terraform apply          # creates RG + ACR + AKS (~8 min)
```

Resources created:

| Resource | Name |
|----------|------|
| Resource Group | `aksazuregitopslab-rg` |
| Container Registry | `aksdemoregistry.azurecr.io` |
| AKS Cluster | `aksazuregitopslab-cluster` |

## 2. Configure GitHub Secrets

Create a service principal:

```bash
az ad sp create-for-rbac \
  --name "aksazuregitopslab-sp" \
  --role contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>
```

Then add the following **Repository Secrets** under _Settings → Secrets and variables → Actions_:

| Secret | Where to find it |
|--------|-----------------|
| `ARM_CLIENT_ID` | `appId` from the SP output |
| `ARM_CLIENT_SECRET` | `password` from the SP output |
| `ARM_SUBSCRIPTION_ID` | Your Azure subscription ID |
| `ARM_TENANT_ID` | `tenant` from the SP output |

## 3. CI/CD Pipeline

| Trigger | Jobs run |
|---------|----------|
| Push to `main` | **build** → **deploy** |
| Pull request | **build** + **terraform plan** (no apply) |

```
push to main
  └─► build job
        ├── az acr login
        ├── docker build (multi-stage)
        └── push  ::<sha>  +  ::latest  →  ACR
              └─► deploy job
                    ├── az aks get-credentials
                    ├── sed  IMAGE_TAG  →  deployment.yaml
                    ├── kubectl apply -f k8s/
                    └── kubectl rollout status
```

## 4. Test Locally

```bash
# Build
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel

# Run
./build/server &

# Smoke test
curl http://localhost:8080/
# {"message":"Hello from AKS!","version":"1.0.0"}

curl http://localhost:8080/healthz
# {"status":"healthy","service":"aksazuregitopslab"}
```

## API Endpoints

| Method | Path | Response |
|--------|------|----------|
| `GET` | `/` | `{"message":"Hello from AKS!","version":"1.0.0"}` |
| `GET` | `/healthz` | `{"status":"healthy","service":"aksazuregitopslab"}` |
| `GET` | `/*` | `{"error":"not found"}` — HTTP 404 |

## Kubernetes Resources

| Resource | Details |
|----------|---------|
| Deployment | 2 replicas, rolling update (maxSurge 1, maxUnavailable 0) |
| Service | `LoadBalancer`, external port 80 → container 8080 |
| HPA | Min 2 / Max 10 pods, scale at 60% CPU |
| Probes | Readiness + Liveness on `GET /healthz` |

## Useful Commands

```bash
# Check rollout
kubectl rollout status deployment/aksazuregitopslab

# Get external IP
kubectl get svc aksazuregitopslab

# View logs
kubectl logs -l app=aksazuregitopslab --tail=50 -f

# Scale manually
kubectl scale deployment/aksazuregitopslab --replicas=4

# Describe HPA
kubectl get hpa aksazuregitopslab-hpa
```

## License

[MIT](LICENSE)
