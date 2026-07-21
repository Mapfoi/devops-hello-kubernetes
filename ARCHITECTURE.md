# Architecture: VM → Kubernetes Migration

## 1. Старая архитектура (VM)

```text
GitHub
   |
GitHub Actions
   |
   +--> Docker build / push → Docker Hub
   |
   +--> Terraform
          |
          +--> Compute VM (Application)  — docker run через SSH
          |
          +--> Compute VM (Monitoring) — docker compose (Prometheus + Grafana)
          |
          +--> Managed PostgreSQL
```

### Как это работало

1. CI собирал Docker-образ и пушил в Docker Hub.
2. Terraform создавал две VM и Managed PostgreSQL.
3. Через SSH на app VM выполнялся `docker pull` + `docker run`.
4. Мониторинг копировался на вторую VM через `scp` и поднимался `docker compose`.
5. Переменные БД писались в `/etc/environment` через cloud-init.

### Проблемы

- Ручное управление контейнерами (`docker run` / SSH).
- Нет автоматического восстановления и rolling update.
- Нет горизонтального масштабирования приложения.
- Две VM нужно обслуживать отдельно (патчи, Docker, SSH-ключи).

---

## 2. Новая архитектура (Kubernetes)

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
          +--> Managed PostgreSQL  (вне кластера)
                    ^
                    |
              Kubernetes Pods (env from Secret)
```

### Назначение компонентов

| Компонент | Назначение |
|-----------|------------|
| **Managed Kubernetes** | Оркестрация контейнеров, self-healing, rolling updates |
| **Node Group** | Worker nodes с autoscaling `min=2`, `max=5` |
| **Deployment** | Желаемое состояние приложения (≥ 2 replicas) |
| **Pod** | Экземпляр контейнера Flask + gunicorn |
| **Service (ClusterIP)** | Стабильный внутренний VIP для Pod'ов |
| **Ingress + NLB** | Внешний HTTP-доступ через Load Balancer |
| **HPA** | Автомасштабирование Pod'ов по CPU/Memory |
| **Secret** | `DB_*` credentials для подключения к PostgreSQL |
| **ConfigMap** | Несекретная конфигурация приложения |
| **Prometheus Operator** | Сбор метрик с `/metrics` |
| **Grafana** | Дашборды и визуализация |
| **Managed PostgreSQL** | Внешнее хранилище данных (не в кластере) |

---

## 3. Поток CI/CD

```text
git push (main)
        |
        v
   [build]  Docker build → Docker Hub (tag: git SHA + latest)
        |
        v
   [infrastructure]  terraform apply
        |                 - IAM / Security Groups
        |                 - Managed Kubernetes + Node Group
        |                 - Managed PostgreSQL
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

**Больше нет:** SSH, `docker run`, `scp`, cloud-init с Docker.

---

## 4. Процесс деплоя приложения

1. Новый образ публикуется в Docker Hub с тегом commit SHA.
2. CI подставляет образ в `deployment.yaml` и делает `kubectl apply`.
3. Deployment запускает Rolling Update:
   - `maxUnavailable: 0`, `maxSurge: 1` — без даунтайма.
4. Новые Pod'ы проходят **readinessProbe** (`GET /health`).
5. Service переключает трафик на Ready Pod'ы.
6. Старые Pod'ы завершаются после drain.

Проверка:

```bash
kubectl -n devops-app get pods
kubectl -n devops-app rollout status deployment/app
```

---

## 5. Подключение к PostgreSQL

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

PostgreSQL **не** переносится в Kubernetes — остаётся Managed-сервисом Yandex Cloud.

---

## 6. Структура репозитория

```text
.
├── .github/workflows/     # CI/CD (deploy, destroy, start, stop)
├── app/                   # Flask + Dockerfile
├── terraform/             # Managed K8s + PostgreSQL + IAM
│   ├── versions.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── backend.tf
│   ├── iam.tf
│   ├── cluster.tf
│   ├── node_group.tf
│   └── database.tf
├── kubernetes/            # Manifests приложения
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

## 7. Масштабирование

| Уровень | Механизм | Параметры |
|---------|----------|-----------|
| Pods | HPA | min 2, max 10 (CPU 70% / Memory 80%) |
| Nodes | Node Group autoscaling | min 2, max 5 |

---

## 8. Управление окружением

| Workflow | Действие |
|----------|----------|
| `deploy.yml` | Build → Terraform → kubectl / Helm deploy |
| `stop.yml` | Останавливает Managed K8s (+ PostgreSQL) |
| `start.yml` | Запускает кластер обратно |
| `destroy.yml` | Удаляет Helm/LB ресурсы и `terraform destroy` |
