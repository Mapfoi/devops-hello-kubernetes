# Required GitHub Secrets

Документация по секретам, которые необходимо добавить в GitHub-репозиторий:

**Settings → Secrets and variables → Actions → New repository secret**

---

## Yandex Cloud

### `YC_SERVICE_ACCOUNT_JSON`


| Поле             | Значение                                                               |
| ---------------- | ---------------------------------------------------------------------- |
| **Назначение**   | Аутентификация Terraform и Yandex Cloud CLI в GitHub Actions           |
| **Где получить** | Создать ключ сервисного аккаунта                                       |
| **Команда**      | `yc iam key create --service-account-name <sa-name> --output key.json` |


Пример значения:

```json
{
  "id": "aje••••••••••••",
  "service_account_id": "aje••••••••••••",
  "created_at": "2026-01-01T00:00:00Z",
  "key_algorithm": "RSA_2048",
  "public_key": "-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----\n",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
}
```

> Вставьте **весь JSON-файл** целиком как значение секрета.

**Рекомендуемый способ (избегает поломки JSON в GitHub Secrets):**

```bash
# Linux / macOS / Git Bash
base64 -w0 key.json
# скопируйте ОДНУ строку base64 в секрет YC_SERVICE_ACCOUNT_JSON
```

```powershell
# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("key.json"))
```

Pipeline принимает и raw JSON, и base64 (`scripts/write-yc-sa-key.py`).

**Если Terraform падает с ошибками ключа** (`unmarshal`, `invalid Timestamp`, `invalid character '\n'`):

1. Пересоздайте ключ: `yc iam key create --service-account-name <sa> --output key.json`
2. Запишите секрет как **base64** (команды выше), не вставляйте pretty-printed JSON вручную.

Необходимые роли сервисного аккаунта (минимум):

- `editor` (или набор: `k8s.admin`, `compute.admin`, `vpc.admin`, `mdb.admin`, `iam.serviceAccounts.user`)
- `storage.editor` — для S3 backend Terraform state

---

### `YC_CLOUD_ID`


| Поле             | Значение                                                            |
| ---------------- | ------------------------------------------------------------------- |
| **Назначение**   | Идентификатор облака Yandex Cloud                                   |
| **Где получить** | Yandex Cloud Console → Cloud information / `yc config get cloud-id` |


Пример:

```text
b1gxxxxxxxxxxxxxxxxx
```

---

### `YC_FOLDER_ID`


| Поле             | Значение                                                           |
| ---------------- | ------------------------------------------------------------------ |
| **Назначение**   | Идентификатор каталога, в котором создаётся инфраструктура         |
| **Где получить** | Yandex Cloud Console → Folder settings / `yc config get folder-id` |


Пример:

```text
b1gxxxxxxxxxxxxxxxxx
```

---

### `YC_ACCESS_KEY`


| Поле             | Значение                                                               |
| ---------------- | ---------------------------------------------------------------------- |
| **Назначение**   | Access Key для S3-совместимого Object Storage (Terraform remote state) |
| **Где получить** | `yc iam access-key create --service-account-name <sa-name>`            |


Пример:

```text
YCAJExxxxxxxxxxxxxxxx
```

---

### `YC_SECRET_KEY`


| Поле             | Значение                                               |
| ---------------- | ------------------------------------------------------ |
| **Назначение**   | Secret Key для Object Storage (пара к `YC_ACCESS_KEY`) |
| **Где получить** | Выводится один раз при создании access-key             |


Пример:

```text
YCM••••••••••••••••••••••••••••••
```

---

### `YC_KUBECONFIG` (опционально)


| Поле             | Значение                                                   |
| ---------------- | ---------------------------------------------------------- |
| **Назначение**   | Готовый kubeconfig для доступа GitHub Actions к Kubernetes |
| **Где получить** | После создания кластера                                    |


Команды:

```bash
yc managed-kubernetes cluster get-credentials devops-k8s-cluster --external --force
cat ~/.kube/config
```

> Если секрет не задан, pipeline сам получает kubeconfig через  
> `yc managed-kubernetes cluster get-credentials` после `terraform apply`.

Пример (фрагмент):

```yaml
apiVersion: v1
kind: Config
clusters:
  - cluster:
      server: https://xx.xx.xx.xx
      certificate-authority-data: LS0t...
    name: yc-devops-k8s-cluster
users:
  - name: yc-devops-k8s-cluster
    user:
      exec: ...
```

---

## Docker Hub

### `DOCKER_USERNAME`


| Поле             | Значение                               |
| ---------------- | -------------------------------------- |
| **Назначение**   | Логин Docker Hub для push/pull образов |
| **Где получить** | Docker Hub → Account Settings          |


Пример:

```text
mapfoi
```

---

### `DOCKER_TOKEN`


| Поле             | Значение                                                                    |
| ---------------- | --------------------------------------------------------------------------- |
| **Назначение**   | Access Token для аутентификации в Docker Hub (вместо пароля)                |
| **Где получить** | Docker Hub → Account Settings → Security → Access Tokens → New Access Token |


Права токена: **Read, Write, Delete** (или минимум Read & Write).

Пример:

```text
dckr_pat_xxxxxxxxxxxxxxxxxxxxxxxx
```

---

## PostgreSQL

### `DB_PASSWORD`


| Поле             | Значение                                                                             |
| ---------------- | ------------------------------------------------------------------------------------ |
| **Назначение**   | Пароль пользователя Managed PostgreSQL; передаётся в Terraform и в Kubernetes Secret |
| **Где получить** | Задаёте сами при создании БД / храните в менеджере паролей                           |


Пример:

```text
StrongPassword123!
```

Требования: достаточно сложный пароль (буквы, цифры, спецсимволы), без пробелов.

---

## Секреты, которые больше НЕ нужны

После миграции на Kubernetes следующие секреты из VM-архитектуры **не используются**:


| Секрет            | Почему не нужен                                  |
| ----------------- | ------------------------------------------------ |
| `SSH_PRIVATE_KEY` | Нет SSH на VM — деплой через `kubectl`           |
| `SSH_PUBLIC_KEY`  | Нет cloud-init / SSH-ключей на compute instances |


Их можно удалить из GitHub Secrets.

---

## Kubernetes Secret (внутри кластера)

Создаётся автоматически в CI (не GitHub Secret):


| Ключ          | Источник                             |
| ------------- | ------------------------------------ |
| `DB_HOST`     | Terraform output `db_host`           |
| `DB_PORT`     | Terraform output `db_port` (`6432`)  |
| `DB_NAME`     | Terraform output `db_name` (`db1`)   |
| `DB_USER`     | Terraform output `db_user` (`user1`) |
| `DB_PASSWORD` | GitHub Secret `DB_PASSWORD`          |


Имя ресурса: `app-db-secret` в namespace `devops-app`.

---

## Чеклист перед первым деплоем

- `YC_SERVICE_ACCOUNT_JSON`
- `YC_CLOUD_ID`
- `YC_FOLDER_ID`
- `YC_ACCESS_KEY`
- `YC_SECRET_KEY`
- `DOCKER_USERNAME`
- `DOCKER_TOKEN`
- `DB_PASSWORD`
- (опционально) `YC_KUBECONFIG`
- Object Storage bucket для Terraform state существует (см. `terraform/backend.tf`)

