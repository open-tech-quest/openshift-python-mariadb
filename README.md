# Red Hat Summit Connect - Open Tech Quest - OpenShift (Python + MariaDB)

![image](app/otq/static/open_tech_quest_banner.png)

Same look as `openshift-nginx-demo-app`, but the **challenge flag is read from a MariaDB database**
by a small Python (Flask + gunicorn) application.

| Component | Image |
|-----------|-------|
| App (build)   | `registry.access.redhat.com/hi/python:latest-builder` |
| App (runtime) | `registry.access.redhat.com/hi/python:latest` → `quay.io/open-tech-quest/openshift-python-mariadb-app` |
| Database      | `registry.access.redhat.com/hi/mariadb:latest` (used as-is, no custom image) |

```
Route (edge TLS) ─▶ Service ─▶ app (gunicorn :8080) ──SELECT flag──▶ Service ─▶ mariadb (:3306, PVC)
                                                                     ▲
                    Secret: challenge-flag, database(-root)-password ─┘ seeded by /docker-entrypoint-initdb.d
```

## Repository layout

```
app/                         Python application
  otq/__init__.py            Flask app: /, /healthz, /readyz
  otq/templates/index.html   Page (copied from the nginx demo app)
  otq/static/                Bootstrap, CSS, banner, favicon
Containerfile                Multi-stage build (hi/python builder -> hi/python runtime)
build.sh                     Multi-arch build + push (linux/amd64, linux/arm64)
chart/otq-python-mariadb/    Helm chart for OpenShift
  files/10-schema.sql        Database layout
  files/20-seed-challenge.sh Inserts the challenge flag from the Secret
```

## Database layout

Database `otq`, user `otq` (only `SELECT` is needed by the app, the entrypoint grants all on `otq`).

**Table `challenge`**

| Column       | Type           | Constraints                     | Description |
|--------------|----------------|---------------------------------|-------------|
| `id`         | `INT UNSIGNED` | PK, `AUTO_INCREMENT`            | |
| `name`       | `VARCHAR(64)`  | `NOT NULL`, `UNIQUE`            | Challenge identifier; the app selects the row via `CHALLENGE_NAME` |
| `flag`       | `VARCHAR(128)` | `NOT NULL`                      | Flag shown on the page |
| `created_at` | `TIMESTAMP`    | default `CURRENT_TIMESTAMP`     | |
| `updated_at` | `TIMESTAMP`    | `ON UPDATE CURRENT_TIMESTAMP`   | |

DDL: [chart/otq-python-mariadb/files/10-schema.sql](chart/otq-python-mariadb/files/10-schema.sql)

The app runs:

```sql
SELECT flag FROM challenge WHERE name = %s;
```

### How the flag gets into the database

1. Helm generates a random 16-character flag (plus DB passwords) into the Secret `<release>-otq-python-mariadb`.
   On `helm upgrade` the existing values are read back with `lookup`, so they stay stable.
   Set `challenge.flag` to use a fixed value instead.
2. The scripts in `files/` are mounted to `/docker-entrypoint-initdb.d` of the MariaDB container.
   The MariaDB entrypoint runs them **when the data directory is empty** (first start on a fresh PVC,
   or every restart with `mariadb.persistence.enabled=false`).

> Changing `challenge.flag` later does not update an already initialized PVC. Update the row manually
> or delete the PVC:
> `oc exec deploy/<release>-otq-python-mariadb-mariadb -- sh -c 'MYSQL_PWD=$MARIADB_PASSWORD mariadb -u otq otq -e "UPDATE challenge SET flag=\"NEW\" WHERE name=\"openshift-python-mariadb\""'`

## Build the multi-arch image (Podman Desktop on Mac)

```shell
podman login quay.io
./build.sh
```

Builds `linux/amd64` and `linux/arm64` into one manifest and pushes
`quay.io/open-tech-quest/openshift-python-mariadb-app:<YYYYMMDDHHMM>` and `:latest`.

Environment overrides: `REPOSITORY`, `VERSION`, `PLATFORMS`, `PUSH=false` (build only).

## Run locally with Podman

```shell
REPOSITORY=localhost/otq-app VERSION=dev PUSH=false ./build.sh

podman pod create --name otq -p 8080:8080
podman run -d --pod otq --name otq-db \
  -e MARIADB_ROOT_PASSWORD=rootpw -e MARIADB_DATABASE=otq \
  -e MARIADB_USER=otq -e MARIADB_PASSWORD=apppw \
  -e CHALLENGE_NAME=openshift-python-mariadb -e CHALLENGE_FLAG=LocalTestFlag123 \
  -v ./chart/otq-python-mariadb/files:/docker-entrypoint-initdb.d:ro,Z \
  registry.access.redhat.com/hi/mariadb:latest
podman run -d --pod otq --name otq-app -e DB_HOST=127.0.0.1 -e DB_PASSWORD=apppw localhost/otq-app:dev

open http://localhost:8080
podman pod rm -f otq
```

## Deploy on OpenShift with Helm

```shell
oc new-project otq-demo
helm install demo chart/otq-python-mariadb
```

Show URL and the expected flag:

```shell
echo "https://$(oc get route demo-otq-python-mariadb-app -o jsonpath='{.spec.host}')"
oc get secret demo-otq-python-mariadb -o jsonpath='{.data.challenge-flag}' | base64 -d; echo
```

Important values (see [values.yaml](chart/otq-python-mariadb/values.yaml)):

| Value | Default | |
|-------|---------|-|
| `challenge.name` | `openshift-python-mariadb` | Row the app displays |
| `challenge.flag` | `""` (random) | Fixed flag |
| `app.image.repository` / `tag` | `quay.io/open-tech-quest/openshift-python-mariadb-app` / `latest` | |
| `mariadb.persistence.enabled` | `true` | `false` = emptyDir |
| `mariadb.persistence.size` / `storageClass` | `1Gi` / default | |
| `route.enabled` / `route.host` | `true` / generated | Edge TLS |

All pods run under the default `restricted-v2` SCC (random UID, no privilege escalation, all capabilities dropped).

## App configuration (environment)

| Variable | Default |
|----------|---------|
| `DB_HOST` / `DB_PORT` | `localhost` / `3306` |
| `DB_NAME` / `DB_USER` / `DB_PASSWORD` | `otq` / `otq` / `""` |
| `CHALLENGE_NAME` | `openshift-python-mariadb` |
| `PORT` | `8080` |
| `GUNICORN_WORKERS` / `GUNICORN_THREADS` | `2` / `4` |

Endpoints: `/` (page, HTTP 503 with an error box if the DB is unavailable), `/healthz` (liveness), `/readyz` (checks DB).
