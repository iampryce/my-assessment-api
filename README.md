# CashOnRails Assessment API

A small Laravel REST API for a payment transaction lifecycle assessment workload. It is intentionally simple: SQLite storage, JSON endpoints, automated tests, and a production-oriented Docker image.

## Requirements

- PHP 8.3 or newer
- Composer
- Docker, optional for container runs

## Local Setup

```bash
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate
php artisan db:seed
```

Run the test suite with:

```bash
php artisan test
```

Check code style with:

```bash
./vendor/bin/pint --test
```

## API

All endpoints are prefixed with `/api/v1`.

| Method | Path | Description |
| --- | --- | --- |
| GET | `/health` | Liveness check |
| GET | `/ready` | Database readiness check |
| POST | `/transactions` | Create a transaction |
| GET | `/transactions` | List paginated transactions |
| GET | `/transactions/{id}` | Retrieve a transaction |
| PATCH | `/transactions/{id}/status` | Update transaction status |
| DELETE | `/transactions/{id}` | Delete a transaction |

Amounts are stored as integer minor units to avoid floating-point inaccuracies. For example, NGN 1,250.00 is represented as `125000`.

Supported statuses are `pending`, `processing`, `successful`, and `failed`. Status updates use simple lifecycle rules: `pending` may become `processing`, and `processing` may become `successful` or `failed`.

An OpenAPI 3.1 specification is available in the repo at `openapi.yaml` and from a running app at:

```text
http://localhost:8080/openapi.yaml
```

Swagger UI is available from a running app at:

```text
http://localhost:8080/docs
```

## Example Request

```bash
curl -X POST http://localhost:8080/api/v1/transactions \
  -H 'Content-Type: application/json' \
  -d '{
    "customer_name": "Ada Okafor",
    "customer_email": "ada@example.com",
    "amount": 125000,
    "currency": "NGN",
    "description": "Invoice payment"
  }'
```

## Docker

Build the image:

```bash
docker build -t cashonrails-assessment-api .
```

Run the container:

```bash
docker run \
  -p 8080:8080 \
  --env-file .env \
  cashonrails-assessment-api
```

The container entrypoint creates the SQLite database file and required writable Laravel directories when needed. It does not run migrations automatically. For deployments, run migrations explicitly:

```bash
docker run --rm --env-file .env cashonrails-assessment-api php artisan migrate --force
```

The image serves the app with FrankenPHP, exposes port `8080`, and includes a Docker health check against `/api/v1/health`.

For local Compose usage:

```bash
docker compose up --build
```

The Compose service mounts a named volume at `/app/database` so SQLite data persists across container restarts during local development.

Run smoke checks against a running deployment with:

```bash
BASE_URL=http://localhost:8080 ./scripts/smoke-test.sh
```

## Environment

`.env.example` contains safe local defaults. In production set:

```text
APP_ENV=production
APP_DEBUG=false
LOG_CHANNEL=stderr
DB_CONNECTION=sqlite
DB_DATABASE=/app/database/database.sqlite
```

Do not bake environment-specific configuration, credentials, or secrets into the image.

## CI

The GitHub Actions workflow in `.github/workflows/ci.yml` installs Composer dependencies, prepares SQLite, runs migrations, checks formatting, runs the Pest suite, and builds the Docker image.
