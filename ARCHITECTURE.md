# Architecture: VM → Kubernetes Migration

## 1. Previous architecture (VM)

```text
GitHub
   |
GitHub Actions
   |
   +--> Docker build / push → Docker Hub
   |
   +--> Terraform
          |
          +--> Compute VM (Application)  — docker run over SSH
          |
          +--> Compute VM (Monitoring) — docker compose (Prometheus + Grafana)
          |
          +--> Managed PostgreSQL
```

### How it worked

1. CI built a Docker image and pushed it to Docker Hub.
2. Terraform created two VMs and Managed PostgreSQL.
3. Via SSH on the app VM, `docker pull` + `docker run` were executed.
4. Monitoring was copied to the second VM via `scp` and started with `docker compose`.
5. DB variables were written to `/etc/environment` via cloud-init.

### Problems

- Manual container management (`docker run` / SSH).
- No automatic recovery or rolling updates.
- No horizontal scaling of the application.
- Two VMs had to be maintained separately (patches, Docker, SSH keys).

---

## 2. New architecture (Kubernetes)

```text
GitHub
   |
GitHub Actions
   |
   +--> Docker Build / Push → Docker Hub
   |
   +--> Terraform
          |
          +--> Yandex Managed Kubernetes Cluster
          |         |
          |         +--> Namespace (devops-app)
          |         +--> Deployment (app, replicas ≥ 2)
          |         +--> Pods (gunicorn :8080)
          |         +--> Service (ClusterIP)
          |         +--> Ingress (nginx → Yandex NLB)
          |         +--> HorizontalPodAutoscaler
          |         +--> Monitoring (Prometheus Operator + Grafana)
          |
          +--> Managed PostgreSQL  (outside the cluster)
                    ^
                    |
              Kubernetes Pods (env from Secret)
```

### Component roles

| Component | Purpose |
|-----------|---------|
| **Managed Kubernetes** | Container orchestration, self-healing, rolling updates |
| **hello-k8s-sa** | Existing SA (IAM managed manually); Terraform only reads it via data source |
| **Node Group** | Worker nodes with autoscaling `min=2`, `max=5` |
| **Deployment** | Desired application state (≥ 2 replicas) |
| **Pod** | Flask + gunicorn container instance |
| **Service (ClusterIP)** | Stable internal VIP for Pods |
| **Ingress + NLB** | External HTTP access via Load Balancer |
| **HPA** | Pod autoscaling based on CPU/Memory |
| **Secret** | `DB_*` credentials for PostgreSQL |
| **ConfigMap** | Non-secret application configuration |
| **Prometheus Operator** | Metrics scraping from `/metrics` |
| **Grafana** | Dashboards and visualization |
| **Managed PostgreSQL** | External data store (not in the cluster) |

---

## 3. CI/CD flow

```text
git push (main)
        |
        v
   [build]  Docker build → Docker Hub (tag: git SHA + latest)
        |
        v
   [infrastructure]  terraform apply
        |                 - Security Groups
        |                 - Managed Kubernetes + Node Group
        |                 - Managed PostgreSQL
        |                 (IAM is assigned manually, not by Terraform)
        v
   [deploy]
        |-- yc get-credentials / kubeconfig
        |-- helm: ingress-nginx (LoadBalancer)
        |-- kubectl apply: namespace, configmap
        |-- kubectl create secret (DB_*)
        |-- kubectl apply: deployment, service, ingress, hpa
        |-- kubectl rollout status deployment/app
        |-- helm: kube-prometheus-stack
        |-- helm: grafana
        v
   Application + Monitoring available
```

**No longer used:** SSH, `docker run`, `scp`, cloud-init with Docker.

---

## 4. Application deployment process

1. A new image is published to Docker Hub tagged with the commit SHA.
2. CI substitutes the image in `deployment.yaml` and runs `kubectl apply`.
3. Deployment starts a Rolling Update:
   - `maxUnavailable: 0`, `maxSurge: 1` — zero downtime.
4. New Pods pass the **readinessProbe** (`GET /health`).
5. Service switches traffic to Ready Pods.
6. Old Pods terminate after drain.

Verification:

```bash
kubectl -n devops-app get pods
kubectl -n devops-app rollout status deployment/app
```

---

## 5. PostgreSQL connectivity

```text
Managed PostgreSQL (Yandex MDB)
        ^
        |  private FQDN :6432
        |
 Kubernetes Secret (app-db-secret)
        |
        |  envFrom.secretRef
        v
 Flask container (DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD)
```

PostgreSQL is **not** moved into Kubernetes — it remains a Managed service in Yandex Cloud.

---

## 6. Repository structure

```text
.
├── .github/workflows/     # CI/CD (deploy, destroy, start, stop)
├── app/                   # Flask + Dockerfile
├── terraform/             # Managed K8s + PostgreSQL (IAM is manual)
│   ├── versions.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── backend.tf
│   ├── sa.tf              # data source: existing hello-k8s-sa (IAM managed manually)
│   ├── cluster.tf
│   ├── node_group.tf
│   └── database.tf
├── kubernetes/            # Application manifests
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── hpa.yaml
│   └── monitoring/
├── helm/                  # Prometheus, Grafana, Ingress NGINX
├── ARCHITECTURE.md
├── required_secrets.md
└── README.md
```

---

## 7. Scaling

| Level | Mechanism | Parameters |
|-------|-----------|------------|
| Pods | HPA | min 2, max 10 (CPU 70% / Memory 80%) |
| Nodes | Node Group autoscaling | min 2, max 5 |

---

## 8. Environment management

| Workflow | Action |
|----------|--------|
| `deploy.yml` | Build → Terraform → kubectl / Helm deploy |
| `stop.yml` | Stops Managed K8s (+ PostgreSQL) |
| `start.yml` | Starts the cluster again |
| `destroy.yml` | Removes Helm/LB resources and runs `terraform destroy` |
