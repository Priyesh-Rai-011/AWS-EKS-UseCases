# UMS — User Management System

Spring Boot REST API backed by PostgreSQL. Demonstrates a containerised
Java service that will later run on EKS with an EBS-backed Postgres volume.

---

## What it does

Full CRUD for users. Each user has: id, name, email, created_at.
Two run modes controlled by `APP_PROFILE` env var:

| Profile | Datasource |
|---------|-----------|
| `dev`   | localhost:5432 (or Docker Compose service name) |
| `prod`  | env vars `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` |

---

## Program Flow

```
HTTP Request
     │
     ▼
┌─────────────────────────────────────────────────────────┐
│                    Spring Boot App                       │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │              UserController                      │   │
│  │  /api/users  GET / POST / PUT / DELETE           │   │
│  │  /api/users/{id}                                 │   │
│  │  /api/users/health                               │   │
│  └──────────────────┬───────────────────────────────┘   │
│                     │  calls                            │
│                     ▼                                   │
│  ┌──────────────────────────────────────────────────┐   │
│  │              UserService                         │   │
│  │  - findAll()     - findById(id)                  │   │
│  │  - create(user)  - update(id, user)              │   │
│  │  - delete(id)                                    │   │
│  │                                                  │   │
│  │  Business rules:                                 │   │
│  │    duplicate email → 409 CONFLICT                │   │
│  │    unknown id      → 404 NOT FOUND               │   │
│  └──────────────────┬───────────────────────────────┘   │
│                     │  calls                            │
│                     ▼                                   │
│  ┌──────────────────────────────────────────────────┐   │
│  │              UserRepository                      │   │
│  │  Spring Data JPA (extends JpaRepository)         │   │
│  │  Auto-generates SQL from method names            │   │
│  │    findByEmail(email)                            │   │
│  │    existsByEmail(email)                          │   │
│  └──────────────────┬───────────────────────────────┘   │
│                     │  JDBC / Hibernate                 │
└─────────────────────┼───────────────────────────────────┘
                      │
                      ▼
          ┌───────────────────────┐
          │      PostgreSQL       │
          │   database: umsdb    │
          │   table:    users    │
          │                      │
          │  id          BIGSERIAL│
          │  name        VARCHAR  │
          │  email       VARCHAR  │  ← UNIQUE index
          │  created_at  TIMESTAMP│
          └───────────────────────┘
```

---

## Layer Responsibilities

```
┌─────────────────────────────────────────────────┐
│  Controller  — HTTP in/out, request validation   │
│  (@RestController, @Valid, HTTP status codes)    │
├─────────────────────────────────────────────────┤
│  Service     — business logic, error throwing    │
│  (@Service, ResponseStatusException)             │
├─────────────────────────────────────────────────┤
│  Repository  — DB queries, zero SQL written      │
│  (Spring Data JPA, JpaRepository<User, Long>)   │
├─────────────────────────────────────────────────┤
│  Model       — DB table mapped as Java class     │
│  (@Entity, @Table, @Column, @PrePersist)         │
└─────────────────────────────────────────────────┘
```

---

## Docker Architecture (local)

```
  Your Machine
  ─────────────────────────────────────────────────────────
  │                                                       │
  │   docker-compose up --build                           │
  │                                                       │
  │   ┌──────────────────────┐   ┌─────────────────────┐ │
  │   │     ums-app          │   │     ums-postgres     │ │
  │   │  container           │   │  container           │ │
  │   │                      │   │                      │ │
  │   │  Java 17 JRE Alpine  │──▶│  postgres:16-alpine  │ │
  │   │  port 8080           │   │  port 5432           │ │
  │   │  APP_PROFILE=dev     │   │  DB: umsdb           │ │
  │   └──────────────────────┘   └──────────┬──────────┘ │
  │          │                              │            │
  │   localhost:8080              named volume:          │
  │   (your browser/curl)         postgres_data          │
  │                               (data persists         │
  │                                across restarts)      │
  └─────────────────────────────────────────────────────--┘

  Network: docker-compose default bridge
  ums-app reaches postgres by service name "postgres" (not localhost)
  → SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/umsdb
```

---

## Dockerfile — Multi-Stage Build

```
  Maven image (build stage)          JRE Alpine image (runtime stage)
  ──────────────────────────         ─────────────────────────────────
  pom.xml                            Non-root user (appuser)
    → mvn dependency:go-offline      COPY app.jar from build stage
  src/                               EXPOSE 8080
    → mvn package -DskipTests        ENTRYPOINT java -jar app.jar
    → target/*.jar
                                     Final image: ~180 MB (not ~500 MB)
                                     No Maven, no source code in image
```

---

## API Reference

Base URL: `http://localhost:8080`

| Method | Path              | Body              | Response        |
|--------|-------------------|-------------------|-----------------|
| GET    | /api/users        | —                 | 200 `[User]`    |
| GET    | /api/users/{id}   | —                 | 200 `User`      |
| POST   | /api/users        | `{name, email}`   | 201 `User`      |
| PUT    | /api/users/{id}   | `{name, email}`   | 200 `User`      |
| DELETE | /api/users/{id}   | —                 | 204             |
| GET    | /api/users/health | —                 | 200 `"UP"`      |

**User JSON:**
```json
{
  "id": 1,
  "name": "Priyesh Rai",
  "email": "priyesh@example.com",
  "createdAt": "2026-04-20T10:30:00"
}
```

**Error responses:**
- `404` — user id not found
- `409` — email already exists
- `400` — validation failed (blank name, invalid email)

---

## Quick Start

```bash
# Full Docker (app + postgres)
cd 01_local_app
docker-compose up --build

# App only (Postgres already running locally)
cd ums-app
mvn spring-boot:run

# Test
curl http://localhost:8080/api/users/health
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Priyesh Rai","email":"priyesh@example.com"}'
curl http://localhost:8080/api/users
```

---

## Profile Config

```
application.properties
  └── spring.profiles.active = ${APP_PROFILE:dev}
        │
        ├── dev  → application-dev.properties
        │          hardcoded localhost:5432 creds
        │          ddl-auto=update  (auto-creates tables)
        │          show-sql=true
        │
        └── prod → application-prod.properties
                   reads DB_URL / DB_USERNAME / DB_PASSWORD from env
                   ddl-auto=validate  (never modifies schema)
                   show-sql=false
```

---

## Next Steps (EKS)

```
Local Docker Compose                EKS
────────────────────                ──────────────────────────────────
postgres container          →       RDS or Postgres Pod + EBS volume
docker named volume         →       PersistentVolumeClaim (EBS CSI)
APP_PROFILE env var         →       Kubernetes Secret → env injection
docker-compose port 8080    →       Service + Ingress (ALB)
```
