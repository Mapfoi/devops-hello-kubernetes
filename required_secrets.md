# Required GitHub Secrets

Документация по секретам для GitHub Actions.

Источник по аутентификации Terraform:  
https://yandex.cloud/docs/terraform/authentication#service-account-key

Источник по созданию ключа:  
https://yandex.cloud/docs/iam/operations/authentication/manage-authorized-keys#create-authorized-key

---

## Yandex Cloud

### `YC_SERVICE_ACCOUNT_JSON`

**Назначение:** содержимое файла авторизованного ключа сервисного аккаунта (`key.json`).

Terraform читает его как файл по пути из переменной окружения:

```bash
export YC_SERVICE_ACCOUNT_KEY_FILE="<path_to_key.json>"
```

([документация](https://yandex.cloud/docs/terraform/authentication#service-account-key))

#### Как создать ключ (официально)

```bash
yc iam key create \
  --service-account-name <имя_СА> \
  -o key.json
```

Либо в консоли: IAM → Сервисные аккаунты → Создать авторизованный ключ → **Скачать файл с ключами**.

#### Формат файла (из документации YC)

```json
{
  "id": "lfkoe35hsk58********",
  "service_account_id": "ajepg0mjt06s********",
  "created_at": "2019-03-20T10:04:56Z",
  "key_algorithm": "RSA_2048",
  "public_key": "-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----\n",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
}
```

Важно:

- `public_key` и `private_key` — **одна строка JSON**, переносы внутри PEM заданы как `\n` (два символа), не как реальные Enter.
- Файл должен быть валидным JSON «как после `yc iam key create -o key.json`».

#### Что положить в GitHub Secret

Содержимое файла `key.json` **целиком**, без изменений:

1. Откройте `key.json` в редакторе.
2. Скопируйте всё.
3. Settings → Secrets → `YC_SERVICE_ACCOUNT_JSON` → вставьте.

Проверка локально:

```bash
jq empty key.json && echo OK
# или
python -m json.tool key.json > /dev/null && echo OK
```

---

### `YC_CLOUD_ID`

```bash
yc config get cloud-id
```

Пример: `b1gxxxxxxxxxxxxxxxxx`

---

### `YC_FOLDER_ID`

```bash
yc config get folder-id
```

Пример: `b1gxxxxxxxxxxxxxxxxx`

---

### `YC_ACCESS_KEY` / `YC_SECRET_KEY`

Ключи для Object Storage (S3 backend Terraform state):

```bash
yc iam access-key create --service-account-name <имя_СА>
```

---

### `YC_KUBECONFIG` (опционально)

Если не задан — pipeline получает credentials через:

```bash
yc managed-kubernetes cluster get-credentials <cluster_id> --external --force
```

---

## Docker Hub

### `DOCKER_USERNAME` / `DOCKER_TOKEN`

Docker Hub → Account Settings → Security → Access Tokens.

---

## PostgreSQL

### `DB_PASSWORD`

Пароль пользователя Managed PostgreSQL.

---

## Больше не нужны

| Секрет | Почему |
|--------|--------|
| `SSH_PRIVATE_KEY` | Нет SSH / VM |
| `SSH_PUBLIC_KEY` | Нет cloud-init на VM |
