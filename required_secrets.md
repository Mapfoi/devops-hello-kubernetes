# Required GitHub Secrets

Documentation of secrets for GitHub Actions.

Terraform authentication reference:  
https://yandex.cloud/docs/terraform/authentication#service-account-key

Authorized key creation reference:  
https://yandex.cloud/docs/iam/operations/authentication/manage-authorized-keys#create-authorized-key

---

## Yandex Cloud

### `YC_SERVICE_ACCOUNT_JSON`

**Purpose:** contents of the service account authorized key file (`key.json`).

Terraform reads it as a file from the path in the environment variable:

```bash
export YC_SERVICE_ACCOUNT_KEY_FILE="<path_to_key.json>"
```

([documentation](https://yandex.cloud/docs/terraform/authentication#service-account-key))

#### How to create the key (official)

```bash
yc iam key create \
  --service-account-name <SA_NAME> \
  -o key.json
```

Or in the console: IAM → Service accounts → Create authorized key → **Download key file**.

#### File format (from YC docs)

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

Important:

- `public_key` and `private_key` are a **single JSON string**; PEM line breaks are encoded as `\n` (two characters), not real Enter newlines.
- The file must be valid JSON “as produced by `yc iam key create -o key.json`”.

#### What to put in the GitHub Secret

The entire `key.json` file contents, unchanged:

1. Open `key.json` in an editor.
2. Copy everything.
3. Settings → Secrets → `YC_SERVICE_ACCOUNT_JSON` → paste.

Local validation:

```bash
jq empty key.json && echo OK
```

#### Service account `hello-k8s-sa` (manual, not via Terraform)

Terraform does **not** create IAM and does **not** assign roles.  
An already existing SA is used (default: `hello-k8s-sa`).

Folder roles (assign once in the console / CLI):

| Role | Why |
|------|-----|
| `editor` (or broader) | Terraform create/update of resources |
| `k8s.clusters.agent` | Managed Kubernetes master |
| `vpc.publicAdmin` | Public IPs / cluster networking |
| `load-balancer.admin` | NLB for Ingress |
| `alb.editor` | ALB (if needed) |
| `certificate-manager.certificates.downloader` | Certificates |
| `container-registry.images.puller` | Image pulls on nodes |
| `viewer` | Node group SA duties |
| `storage.editor` | Terraform S3 state (if same SA) |

```bash
FOLDER_ID=$(yc config get folder-id)
SA_ID=$(yc iam service-account get hello-k8s-sa --format json | jq -r .id)

for ROLE in editor k8s.clusters.agent vpc.publicAdmin load-balancer.admin \
            alb.editor certificate-manager.certificates.downloader \
            container-registry.images.puller viewer storage.editor; do
  yc resource-manager folder add-access-binding "$FOLDER_ID" \
    --role "$ROLE" \
    --subject "serviceAccount:$SA_ID"
done
```

---

### `YC_CLOUD_ID`

```bash
yc config get cloud-id
```

Example: `b1gxxxxxxxxxxxxxxxxx`

---

### `YC_FOLDER_ID`

```bash
yc config get folder-id
```

Example: `b1gxxxxxxxxxxxxxxxxx`

---

### `YC_ACCESS_KEY` / `YC_SECRET_KEY`

Keys for Object Storage (S3 backend for Terraform state):

```bash
yc iam access-key create --service-account-name <SA_NAME>
```

---

### `YC_KUBECONFIG` (optional)

If not set, the pipeline obtains credentials via:

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

Password for the Managed PostgreSQL user.

---

## No longer needed

| Secret | Why |
|--------|-----|
| `SSH_PRIVATE_KEY` | No SSH / VM |
| `SSH_PUBLIC_KEY` | No cloud-init on VM |
