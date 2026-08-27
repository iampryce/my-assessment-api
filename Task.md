# Implementation Specification — Laravel Assessment API

## 1. Objective

Create a small, production-structured **Laravel REST API** that will serve as the application workload for the CashOnRails DevOps / Platform Engineer final-stage assessment.

The application itself should remain intentionally simple. The purpose is **not to test Laravel development ability**, but to provide candidates with a realistic application that they can:

* containerise and run;
* deploy to Huawei Cloud;
* provision infrastructure for using Terraform;
* integrate into CI/CD;
* monitor and operate;
* evolve into a reusable platform deployment pattern.

The API should therefore prioritise:

* clean Laravel conventions;
* Docker support;
* SQLite for minimal infrastructure dependency;
* automated test coverage;
* predictable health endpoints;
* clear configuration;
* simple developer setup.

---

# 2. Technology Requirements

Use:

* **PHP:** current Laravel-supported stable PHP version.
* **Framework:** current stable Laravel release.
* **Database:** SQLite.
* **Web/API:** RESTful JSON API.
* **Testing:** PHPUnit or Pest using Laravel's standard testing facilities.
* **Containerisation:** Docker.
* **Dependency management:** Composer.

Do not introduce unnecessary infrastructure such as:

* MySQL;
* PostgreSQL;
* Redis;
* Kafka;
* RabbitMQ;
* Kubernetes;
* external authentication providers.

Those concerns belong to the infrastructure assessment rather than the starter application.

---

# 3. Application Domain

Implement a simple **Payment Transactions API**.

The API should model a minimal payment transaction lifecycle without implementing any real payment processing.

A transaction should contain:

```text
id
reference
customer_name
customer_email
amount
currency
status
description
created_at
updated_at
```

### Field Requirements

`reference`

* Unique.
* String.
* Preferably generated automatically if omitted.

`customer_name`

* Required.
* String.

`customer_email`

* Required.
* Valid email address.

`amount`

* Required.
* Positive numeric value.
* Store in a way that avoids floating-point inaccuracies.

`currency`

* Required.
* Three-character ISO-style currency code.
* Example: NGN, USD, GBP.

`status`

Allowed values:

```text
pending
processing
successful
failed
```

Default:

```text
pending
```

`description`

* Optional.
* String.

---

# 4. API Endpoints

Use an `/api/v1` prefix.

## Health Check

```http
GET /api/v1/health
```

Expected successful response:

```json
{
  "status": "ok"
}
```

Return:

```text
HTTP 200
```

This endpoint must not require authentication.

The endpoint should be suitable for:

* Docker health checks;
* cloud load balancer health checks;
* Kubernetes readiness/liveness exercises;
* CI/CD smoke testing.

---

## Readiness Check

Implement:

```http
GET /api/v1/ready
```

This endpoint should verify that the application can access its configured database.

Successful example:

```json
{
  "status": "ready",
  "database": "ok"
}
```

Return:

```text
HTTP 200
```

If the database is unavailable, return an appropriate `5xx` response.

Keep the implementation simple and deterministic.

---

# 5. Transaction Endpoints

## Create Transaction

```http
POST /api/v1/transactions
```

Example request:

```json
{
  "customer_name": "Ada Okafor",
  "customer_email": "ada@example.com",
  "amount": 125000,
  "currency": "NGN",
  "description": "Invoice payment"
}
```

Expected:

```text
HTTP 201
```

Example response:

```json
{
  "data": {
    "id": 1,
    "reference": "TXN-...",
    "customer_name": "Ada Okafor",
    "customer_email": "ada@example.com",
    "amount": 125000,
    "currency": "NGN",
    "status": "pending",
    "description": "Invoice payment",
    "created_at": "...",
    "updated_at": "..."
  }
}
```

---

## List Transactions

```http
GET /api/v1/transactions
```

Requirements:

* Return paginated results.
* Default Laravel pagination is acceptable.
* Support optional status filtering.

Example:

```http
GET /api/v1/transactions?status=successful
```

---

## Retrieve Transaction

```http
GET /api/v1/transactions/{id}
```

Return:

```text
HTTP 200
```

for an existing record.

Return:

```text
HTTP 404
```

for a non-existent transaction.

---

## Update Transaction Status

Use:

```http
PATCH /api/v1/transactions/{id}/status
```

Example request:

```json
{
  "status": "successful"
}
```

Only allow:

```text
pending
processing
successful
failed
```

Invalid statuses should return:

```text
HTTP 422
```

---

## Delete Transaction

Implement:

```http
DELETE /api/v1/transactions/{id}
```

Return:

```text
HTTP 204
```

upon successful deletion.

---

# 6. API Behaviour

All API responses should use JSON.

Use consistent error handling.

For validation failures, rely on Laravel's normal API validation conventions.

Example:

```json
{
  "message": "The given data was invalid.",
  "errors": {
    "customer_email": [
      "The customer email field must be a valid email address."
    ]
  }
}
```

Do not return HTML error pages for API routes.

---

# 7. Application Structure

Follow normal Laravel architecture.

Prefer:

```text
app/
├── Http/
│   ├── Controllers/
│   ├── Requests/
│   └── Resources/
├── Models/
└── Services/
```

Use dedicated Form Request classes for validation where reasonable.

Example:

```text
StoreTransactionRequest
UpdateTransactionStatusRequest
```

Use an API Resource for transaction responses if appropriate.

Avoid unnecessary architectural complexity.

Do not introduce:

* repository patterns solely for abstraction;
* CQRS;
* event sourcing;
* microservices;
* elaborate domain-driven-design structures.

The starter application should remain easy for candidates to understand quickly.

---

# 8. SQLite Configuration

SQLite must be the default database.

The application should work after:

```bash
php artisan migrate
```

without requiring an external database server.

Use a database file such as:

```text
database/database.sqlite
```

The Docker image or container startup process should ensure that the required SQLite database file exists.

The application should be configurable through environment variables using Laravel conventions.

Example:

```text
DB_CONNECTION=sqlite
```

Tests should use either:

```text
:memory:
```

or an isolated test SQLite database.

Tests must never depend on the development database.

---

# 9. Database Migration

Create a migration for the transactions table.

Suggested schema:

```text
id
reference - unique string
customer_name - string
customer_email - string
amount - unsigned big integer
currency - string(3)
status - string
description - nullable text
timestamps
```

For simplicity, represent `amount` using the smallest currency unit.

For example:

```text
NGN 1,250.00
```

may be represented as:

```text
125000
```

This avoids floating-point calculations.

Document this convention in the README.

---

# 10. Model Factory

Provide a Laravel factory for transactions.

Example:

```php
Transaction::factory()->count(10)->create();
```

Factory-generated records should include valid:

* references;
* names;
* email addresses;
* amounts;
* currencies;
* statuses.

---

# 11. Seeder

Provide a simple database seeder.

Example behaviour:

```text
php artisan db:seed
```

should create approximately 10-20 sample transactions.

Seed data is for demonstration only and should not be required by the tests.

---

# 12. Test Suite

Testing is a major requirement of this implementation.

The project should have a focused, meaningful automated test suite.

Prefer feature/API tests over excessive unit tests.

At minimum, test the following.

## Health Tests

Test:

```text
GET /api/v1/health
```

Assertions:

* response is HTTP 200;
* JSON contains `status = ok`.

Test:

```text
GET /api/v1/ready
```

Assertions:

* HTTP 200 when database access works;
* response indicates database availability.

---

## Transaction Creation Tests

Test successful creation.

Verify:

* HTTP 201;
* transaction is persisted;
* status defaults to `pending`;
* reference is generated;
* correct JSON structure is returned.

---

## Validation Tests

Test creation failure when:

* customer name is missing;
* email is missing;
* email format is invalid;
* amount is missing;
* amount is zero or negative;
* currency is missing;
* currency is invalid.

Expected:

```text
HTTP 422
```

---

## List Tests

Verify:

```text
GET /api/v1/transactions
```

returns:

* HTTP 200;
* paginated data;
* expected transaction records.

Also test status filtering.

---

## Retrieve Tests

Verify:

* existing transaction returns HTTP 200;
* unknown transaction returns HTTP 404.

---

## Status Update Tests

Verify valid transitions can update a transaction.

At minimum test:

```text
pending -> processing
processing -> successful
processing -> failed
```

If implementing unrestricted status updates, document this decision.

Prefer implementing simple lifecycle rules.

Reject unsupported statuses with:

```text
HTTP 422
```

---

## Delete Tests

Verify:

* HTTP 204;
* record is removed from the database.

---

# 13. Test Isolation

All tests must be isolated.

Use Laravel facilities such as:

```php
RefreshDatabase
```

Tests must:

* not require external APIs;
* not require network connectivity;
* not depend on manually created data;
* run consistently in Docker;
* run consistently locally.

The full suite should execute using a single straightforward command.

For example:

```bash
php artisan test
```

---

# 14. Docker Requirements

Create a production-oriented `Dockerfile`.

The Docker image should:

* use an appropriate PHP base image;
* install required PHP extensions;
* install Composer dependencies;
* copy the Laravel application;
* configure sensible permissions;
* expose the application port;
* run the application without requiring manual container intervention.

Avoid creating an unnecessarily large image.

A multi-stage build is encouraged where useful.

---

# 15. Docker Runtime

The application should be runnable with:

```bash
docker build -t cashonrails-assessment-api .
```

and subsequently:

```bash
docker run \
  -p 8080:8080 \
  --env-file .env \
  cashonrails-assessment-api
```

After startup:

```http
GET http://localhost:8080/api/v1/health
```

should return HTTP 200.

Use an appropriate production-capable PHP serving approach.

Do not rely on:

```bash
php artisan serve
```

for the intended production container unless there is a clearly documented reason.

---

# 16. Container Startup

Provide an entrypoint/startup script if necessary.

It may perform safe initialization tasks such as:

* ensuring the SQLite file exists;
* ensuring required directories exist;
* setting permissions;
* caching Laravel configuration if appropriate.

Do not automatically perform destructive operations.

Database migration behaviour should be clearly documented.

Prefer explicitly executing:

```bash
php artisan migrate --force
```

during deployment rather than hiding potentially consequential migrations inside every container startup.

---

# 17. Docker Compose

Optionally provide:

```text
docker-compose.yml
```

or:

```text
compose.yaml
```

for local development.

Since SQLite is used, the Compose definition should remain minimal.

Example conceptual structure:

```text
services:
  api:
    build: .
    ports:
      - "8080:8080"
```

Do not add unnecessary infrastructure services.

---

# 18. Docker Health Check

Configure a container health check against:

```text
/api/v1/health
```

or document how orchestration systems should configure it.

The readiness endpoint should remain distinct so infrastructure candidates can reason about:

* liveness;
* readiness;
* dependency failure.

---

# 19. Environment Configuration

Provide:

```text
.env.example
```

with safe defaults.

It should contain no credentials or secrets.

At minimum include settings such as:

```text
APP_NAME
APP_ENV
APP_KEY
APP_DEBUG
APP_URL

LOG_CHANNEL
LOG_LEVEL

DB_CONNECTION
```

`APP_DEBUG` should default to an appropriate non-production value in `.env.example`, but production instructions must explicitly require:

```text
APP_DEBUG=false
```

---

# 20. Logging

Use Laravel's standard structured logging capabilities.

Ensure application logs go to:

```text
stdout/stderr
```

when running inside Docker wherever practical.

Avoid designs that require a cloud environment to read log files from inside the container filesystem.

This allows candidates to integrate the application with cloud-native logging and observability.

---

# 21. Configuration Principles

The container must not contain environment-specific configuration.

The same image should be usable for:

```text
development
staging
production
```

by changing environment variables and deployment configuration.

No:

* cloud credentials;
* API secrets;
* passwords;
* environment-specific hostnames

should be hardcoded.

---

# 22. Security Baseline

Implement a basic application security baseline.

At minimum:

* validation of all write operations;
* no debug output in production;
* no secrets committed to Git;
* appropriate Laravel mass-assignment controls;
* database files not downloadable over HTTP;
* dependencies installed without development packages in production Docker stage;
* avoid running the application container as root where reasonably possible.

Do not build authentication unless it is required to make the application coherent.

The DevOps/Platform candidate should focus on infrastructure security rather than spend time reverse-engineering authentication.

---

# 23. CI-Friendly Design

The repository should work naturally with CI systems.

A typical pipeline should be able to execute:

```bash
composer install
php artisan test
docker build .
```

without manual intervention.

Keep test execution independent from Huawei Cloud.

The basic application should therefore allow candidates to construct a CI/CD workflow around:

```text
Checkout
   ↓
Install dependencies
   ↓
Run test suite
   ↓
Build Docker image
   ↓
Scan image
   ↓
Push image
   ↓
Deploy infrastructure/application
   ↓
Smoke test
```

---

# 24. README Requirements

Create a concise but complete `README.md`.

It must explain:

## Application

* what the API represents;
* key endpoints;
* amount storage convention;
* transaction statuses.

## Local Development

Example:

```bash
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate
php artisan serve
```

## Testing

Example:

```bash
php artisan test
```

## Docker

Document:

```bash
docker build
docker run
```

and expected local URL.

## Database

Explain:

* SQLite is intentional;
* how migrations work;
* how to seed sample data.

## Deployment Context

Include a short statement similar to:

> This application is intentionally infrastructure-neutral and uses SQLite to minimise application dependencies. It is designed as the workload for a DevOps / Platform Engineering technical assessment. Candidates are expected to determine the appropriate cloud architecture, persistence strategy, networking, scalability, observability and deployment model.

This is important because the candidate should not interpret SQLite as the required production database architecture.

---

# 25. Suggested Repository Structure

Produce approximately:

```text
my-platform-app/
│
├── app/
│   ├── Http/
│   │   ├── Controllers/
│   │   │   └── TransactionController.php
│   │   ├── Requests/
│   │   │   ├── StoreTransactionRequest.php
│   │   │   └── UpdateTransactionStatusRequest.php
│   │   └── Resources/
│   │       └── TransactionResource.php
│   │
│   └── Models/
│       └── Transaction.php
│
├── database/
│   ├── factories/
│   ├── migrations/
│   └── seeders/
│
├── routes/
│   └── api.php
│
├── tests/
│   ├── Feature/
│   │   ├── HealthCheckTest.php
│   │   └── TransactionApiTest.php
│   └── Unit/
│
├── Dockerfile
├── .dockerignore
├── .env.example
├── composer.json
├── README.md
└── compose.yaml
```

Exact structure may follow the conventions of the Laravel version being used.

---

# 26. Explicit Non-Goals

Do **not** implement:

* a frontend;
* payment-gateway integrations;
* real card processing;
* OAuth;
* user registration;
* administrative dashboards;
* event streaming;
* complex queues;
* cloud-specific SDK integrations;
* Terraform;
* Kubernetes manifests;
* Huawei Cloud configuration.

The starter repository should stop at:

```text
Application
+
Tests
+
Docker image
```

The **candidate** will be responsible for everything after that boundary.

---

# 27. Acceptance Criteria

The implementation is complete only when all of the following work.

### Local application

```bash
composer install
php artisan migrate
php artisan test
```

All tests must pass.

### Docker build

```bash
docker build -t cashonrails-assessment-api .
```

must succeed.

### Docker runtime

The resulting container must start successfully and expose the API.

The following must succeed:

```http
GET /api/v1/health
```

and return:

```json
{
  "status": "ok"
}
```

### API

All required transaction endpoints must function and be covered by automated tests.

### Repository

The repository must contain no:

* credentials;
* generated secrets;
* committed `.env`;
* unnecessary dependencies;
* cloud-specific infrastructure.

---

# 28. Quality Expectations for the Implementation Agent

While implementing this specification:

1. Prefer standard Laravel functionality over custom abstractions.
2. Keep the source code easy for another engineer to understand quickly.
3. Write the tests while implementing the API rather than adding superficial tests afterward.
4. Ensure tests verify behaviour, validation and persistence rather than only HTTP status codes.
5. Run the complete test suite before considering the task complete.
6. Build and execute the Docker image and verify the health endpoint from the running container.
7. Fix any failing tests, container errors or undocumented setup requirements.
8. Keep the application deliberately small; do not expand the domain without a requirement in this specification.

The final result should be a **small, clean, tested and containerised Laravel workload that gives DevOps / Platform Engineering candidates enough application context to demonstrate infrastructure engineering without turning the assessment into a Laravel development exercise.**
