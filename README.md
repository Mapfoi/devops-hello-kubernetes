# devops-hello-kubernetes

Production-style DevOps project: containerized Flask app on **Yandex Managed Kubernetes** with Terraform, GitHub Actions, Managed PostgreSQL, Prometheus and Grafana.

## Architecture

```text
GitHub Actions → Docker Hub → Terraform (Managed K8s + PostgreSQL)
                                    ↓
                         kubectl / Helm deploy
                                    ↓
              Deployment → Service → Ingress (NLB) → Internet
                                    ↓
                         Managed PostgreSQL
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for VM → Kubernetes migration details.

## Quick start

1. Configure GitHub Secrets — see [required_secrets.md](required_secrets.md).
2. Ensure Object Storage bucket from `terraform/backend.tf` exists.
3. Push to `main` (or run **Deploy to Kubernetes** workflow manually).

```bash
git push origin main
```

Pipeline will:

1. Build & push Docker image  
2. `terraform apply` (Kubernetes cluster + PostgreSQL)  
3. `kubectl apply` + Helm (Ingress, app, Prometheus, Grafana)  
4. Wait for rolling update  

## Application

- Flask + gunicorn on port `8080`
- Metrics: `GET /metrics`
- Health: `GET /health`
- Visits counter stored in Managed PostgreSQL

## Useful commands

```bash
# After yc managed-kubernetes cluster get-credentials ...
kubectl -n devops-app get pods,svc,ingress,hpa
kubectl -n devops-app rollout status deployment/app
kubectl -n ingress-nginx get svc ingress-nginx-controller
```

## Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| Deploy to Kubernetes | push to main / manual | Full CI/CD |
| Stop Environment | manual | Stop K8s (+ DB) to save cost |
| Start Environment | manual | Start cluster again |
| Destroy Infrastructure | manual | Tear down everything |

## License

Educational / portfolio project.
