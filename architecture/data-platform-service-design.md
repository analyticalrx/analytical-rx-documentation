# AnalyticalRx Data Platform Service Design

Created: August 18, 2026
Status: Draft for engineering review
Primary audience: backend, frontend, data engineering, security, and implementation leads
Related PRD: `prd/product-requirements-document.md`
Related epic: GitHub issue `#40: Epic: Pharmacy Data Platform And Role-Based Dashboards`

## 1. Purpose

The Data Platform Service is the Phase 1 backend application that turns the ingestion and canonical database foundation into a usable product surface.

It should provide:

- username/password authentication that returns a JWT bearer access token
- tenant, pharmacy, and role-based access control
- tenant schema routing
- dashboard APIs for all Phase 1 starter dashboards
- internal admin APIs for users, role assignments, and pipeline audit visibility
- safe read models over canonical pharmacy data
- extension points for Phase 2 workflows, alerts, refill queues, and Doctor CRM

This service should be implemented as a Java 21 Spring Boot application and deployed as a container in AWS.

## 2. Service Boundary

### This Service Owns

- Application authentication, JWT issuing, JWT validation, and token lifecycle rules.
- User, role, tenant, and pharmacy access resolution.
- Backend authorization checks for every dashboard and admin API.
- Dashboard API contracts and read models.
- Internal admin APIs for managing users and reviewing pipeline/import audit status.
- Safe access to tenant schemas through PostgreSQL/RDS Proxy.
- API response shaping for the frontend application.
- App-level audit records for login, permission changes, admin actions, and sensitive read attempts.

### This Service Does Not Own

- PrimeRx webhook receipt. That remains API Gateway plus receiver Lambda.
- SQS event buffering.
- Webhook event processing and canonical persistence. That remains processor Lambda/service.
- PrimeRx SFTP file transfer jobs.
- Raw payload storage.
- Full analytics warehouse or ML forecasting.
- Fully configurable workflow/rule builder.
- Final production security/compliance policy.

### Boundary Summary

```text
PrimeRx / Micro Merchant
  -> ingestion pipeline
  -> canonical tenant schema
  -> Data Platform Service
  -> role-based frontend dashboards
```

The Data Platform Service reads safe, processed data. It must not make normal dashboards depend on raw PrimeRx payloads or raw vendor responses.

## 3. Architecture Overview

See the rendered diagram:

- `diagrams/data-platform-service.svg`
- editable source: `diagrams/data-platform-service.d2`

High-level flow:

1. User signs in through the frontend.
2. Frontend calls the Data Platform Service.
3. Service authenticates the user and resolves allowed tenants, pharmacies, and roles.
4. Service resolves the tenant schema from trusted server-side configuration.
5. Service queries dashboard-safe tables in the selected tenant schema.
6. Service returns role-scoped dashboard data.
7. Internal admins can access permission management and pipeline audit views, without raw PHI payload exposure.

## 4. Key Design Decisions

| Decision | Recommendation | Reason |
| --- | --- | --- |
| Backend framework | Java 21 + Spring Boot 3.x | Strong typing, mature security, good AWS/container support, good team handoff. |
| Deployment | Container in AWS, preferably ECS Fargate for Phase 1 | Long-running API service, predictable behavior, no Lambda cold-start concern for user-facing dashboards. |
| Database | Existing AWS RDS PostgreSQL through RDS Proxy | Already provisioned and documented for Phase 1. |
| Tenant isolation | One PostgreSQL schema per tenant for tenant-owned pharmacy data | Matches the current SaaS isolation decision. |
| Platform metadata | Add a non-PHI `control_plane` schema | Needed for login, users, tenant registry, schema mapping, role assignments, and cross-tenant internal admin views. |
| Dashboard queries | Explicit SQL read models using Spring JDBC or jOOQ | Dashboard queries are aggregation-heavy and should be clear, testable, and not hidden behind complex ORM behavior. |
| Auth | Username/password login with backend-issued JWT bearer access tokens containing role claims | Meets Phase 1 need while keeping APIs stateless. Tokens must be short-lived and must not contain PHI or raw source identifiers. |
| Raw data access | Not available to normal dashboard APIs | Prevents accidental PHI exposure and keeps dashboards tied to canonical data. |

## 5. Important Assumption To Confirm

Tenant-owned pharmacy data should remain inside one schema per tenant, but the platform still needs a small shared `control_plane` schema.

The `control_plane` schema should store only platform metadata:

- users
- password hashes
- tenants
- tenant schema names
- pharmacy access assignments
- role assignments
- permission audit records
- login/token audit records

It should not store raw webhook payloads, patient details, prescription payloads, Rx numbers, refill numbers, or dashboard event facts.

Without this shared control plane, a single user who belongs to multiple tenants or an internal admin who manages multiple tenants would be hard to model cleanly.

## 6. AWS Runtime Design

### Recommended Phase 1 Runtime

```text
Frontend application
  -> HTTPS
  -> Application Load Balancer or API Gateway
  -> ECS Fargate service running Spring Boot
  -> RDS Proxy
  -> RDS PostgreSQL
```

For local development:

```text
Developer laptop
  -> Spring Boot local app
  -> SSM port forwarding tunnel
  -> RDS Proxy
  -> RDS PostgreSQL
```

### Runtime Configuration

Environment variables:

| Variable | Purpose |
| --- | --- |
| `SPRING_PROFILES_ACTIVE` | `local`, `dev`, `stage`, or `prod`. |
| `DB_SECRET_ID` | AWS Secrets Manager secret for app database credentials. Current dev secret: `analytical-rx/phase1/dev/postgres/app-rw`. |
| `AWS_REGION` | `us-east-1` for current Phase 1 dev. |
| `JWT_SIGNING_SECRET_ID` | Secret containing JWT signing key or private key. Required for bearer token auth. |
| `JWT_ACCESS_TOKEN_TTL_MINUTES` | Access token lifetime. Recommended Phase 1 default: 15 to 30 minutes. |
| `JWT_ISSUER` | Expected token issuer, for example `analyticalrx-api`. |
| `JWT_AUDIENCE` | Expected token audience, for example `analyticalrx-frontend`. |
| `CONTROL_PLANE_SCHEMA` | Usually `control_plane`. |
| `DEFAULT_TENANT_KEY` | Optional local/dev convenience only. Must not be used for production routing. |
| `LOG_LEVEL` | Runtime logging level. |

Existing database secret:

| Field | Value |
| --- | --- |
| Secret name | `analytical-rx/phase1/dev/postgres/app-rw` |
| Database user | `analyticalrx_app_rw` |
| Host | RDS Proxy endpoint |
| Database | `analyticalrx` |
| SSL | required |

Longer term, create separate database users/secrets for:

- ingestion processor writer
- API enrichment worker
- dashboard service reader/writer
- migration runner
- break-glass/admin DBA

For Phase 1 development, the current app read/write secret can be used until least-privilege database roles are finalized.

## 7. JWT Bearer Auth Model

Phase 1 authentication should use username/password login and backend-issued JWT bearer access tokens.

### Login Flow

1. User submits email/username and password to `POST /api/v1/auth/login`.
2. Service verifies the password hash from `control_plane.app_user`.
3. Service loads active tenant, pharmacy, and role assignments from the control plane.
4. Service issues a signed JWT access token.
5. Frontend sends the token on API calls:

   ```text
   Authorization: Bearer <access_token>
   ```

6. Spring Security validates token signature, issuer, audience, expiry, and required claims.
7. Service builds the current user context and enforces RBAC on every API call.

### Token Claims

Recommended access token claims:

```json
{
  "iss": "analyticalrx-api",
  "aud": "analyticalrx-frontend",
  "sub": "user-uuid",
  "email": "user@example.com",
  "display_name": "User Name",
  "tenant_access": [
    {
      "tenant_key": "valley-corporation",
      "roles": ["OWNER_EXECUTIVE"],
      "pharmacy_ids": ["pharmacy-uuid-1", "pharmacy-uuid-2"]
    }
  ],
  "internal_roles": ["INTERNAL_PLATFORM_ADMIN"],
  "permissions_version": 4,
  "iat": 1787049000,
  "exp": 1787050800,
  "jti": "token-uuid"
}
```

Claim rules:

- Include role claims because the frontend and backend both need to understand the user's allowed product surface.
- Include tenant key and allowed pharmacy IDs only as authorization context.
- Do not include database schema names in the token.
- Do not include PHI, raw payload references, real `RxNo`, real `RefillNo`, patient details, insurance member IDs, or raw vendor identifiers.
- Keep token claims small enough for normal HTTP header limits.

### Authorization Rules

The JWT role claims are necessary, but they are not the full security model.

For every tenant-scoped request, the service must:

1. Validate the JWT.
2. Confirm the requested tenant exists in the user's token claims.
3. Resolve the actual database schema name from `control_plane.tenant_registry`.
4. Enforce pharmacy-level scope from token claims and/or the latest control-plane assignment state.
5. Enforce role permission for the requested API.
6. Query only dashboard-safe tables/views unless the caller is an authorized internal/admin workflow.

For sensitive admin actions, the service should re-check current role assignment state from `control_plane` instead of relying only on token claims.

### Expiry And Role Changes

Recommended Phase 1 behavior:

- Use short-lived access tokens, initially 15 to 30 minutes.
- Store a `permissions_version` on the user or assignment set.
- Increment `permissions_version` when roles, tenant access, pharmacy scope, or user status changes.
- Reject tokens with stale `permissions_version` for sensitive actions, or refresh authorization context from the database.
- Disable users by setting `app_user.status` and rejecting further token use after the next permission check.

Refresh tokens are optional for Phase 1. If added, keep them separate from access tokens and protect them with stronger storage rules, such as secure HTTP-only cookies or server-side token records.

### Frontend Token Handling

- Use HTTPS in deployed environments.
- Send the JWT only in the `Authorization` header.
- Prefer in-memory access token storage if practical.
- Do not log tokens in browser logs, server logs, analytics tools, or support screenshots.
- Treat the `/api/v1/me` response as the source for role-aware navigation, not hardcoded frontend role assumptions.

## 8. Database Access Model

### Schemas

| Schema | Purpose |
| --- | --- |
| `control_plane` | Platform metadata, users, roles, tenant registry, assignment records, app audit. No PHI. |
| `tenant_template` | Template/review schema for tenant-owned pharmacy tables. |
| `tenant_analyticalrx_dev` | Current dev tenant schema. |
| `tenant_<customer_key>` | Future tenant-owned pharmacy data schema. |

### Tenant Schema Resolution

The frontend may request a tenant by tenant key, for example:

```text
/api/v1/tenants/valley-corporation/dashboards/owner
```

The service must treat `valley-corporation` only as a public tenant key. It must then:

1. Authenticate the user.
2. Check that the user is assigned to that tenant.
3. Resolve the actual schema name from `control_plane.tenant_registry`.
4. Validate the schema name against an allowlisted pattern and stored registry value.
5. Execute queries only against that resolved schema.

The service must never accept a raw schema name from request input.

### Query Safety

For schema-per-tenant access, use one of these patterns:

| Pattern | Use |
| --- | --- |
| Schema-qualified SQL from trusted tenant registry | Recommended for Phase 1 dashboard read models. |
| Transaction-scoped `SET LOCAL search_path` | Acceptable if every request uses transactions and connections are safely reset. |
| Hibernate schema multi-tenancy | Possible later, but likely unnecessary for Phase 1 dashboard aggregation queries. |

Recommended Phase 1 approach:

- Use explicit SQL with schema names resolved from `control_plane`.
- Only interpolate schema identifiers after server-side lookup and strict validation.
- Continue to bind all values, dates, IDs, filters, and search text as SQL parameters.

## 9. Proposed Control Plane Tables

These tables are not part of the current canonical event schema. They should be added for the core service.

### `control_plane.app_user`

Stores users who can sign in.

Key fields:

- `id`
- `email`
- `display_name`
- `password_hash`
- `status`
- `last_login_at`
- `created_at`
- `updated_at`

### `control_plane.tenant_registry`

Maps tenant keys to database schemas.

Key fields:

- `id`
- `tenant_key`
- `display_name`
- `schema_name`
- `status`
- `created_at`
- `updated_at`

### `control_plane.user_tenant_access`

Defines which users can access which tenant.

Key fields:

- `id`
- `user_id`
- `tenant_id`
- `status`
- `created_at`
- `updated_at`

### `control_plane.user_role_assignment`

Defines role assignments inside a tenant and optional pharmacy scope.

Key fields:

- `id`
- `user_id`
- `tenant_id`
- `role_code`
- `pharmacy_id`
- `scope_type`
- `status`
- `created_at`
- `updated_at`

`pharmacy_id` should reference the tenant schema's `pharmacy.id` logically. Because each tenant has its own schema, this may be stored as UUID plus tenant ID instead of a normal cross-schema foreign key.

### `control_plane.permission_audit`

Tracks permission changes.

Key fields:

- `id`
- `actor_user_id`
- `target_user_id`
- `tenant_id`
- `pharmacy_id`
- `action`
- `old_value`
- `new_value`
- `reason`
- `created_at`

### `control_plane.app_access_audit`

Tracks login and sensitive app access events.

Key fields:

- `id`
- `user_id`
- `tenant_id`
- `action`
- `resource_type`
- `resource_id`
- `status`
- `ip_address`
- `user_agent`
- `created_at`

## 10. Phase 1 Roles And Access Rules

Detailed role definitions, role bundles, service principals, API permission codes, field restrictions, and RBAC test cases are maintained in [AnalyticalRx Role-Based Access Control Standard](role-based-access-control-standard.md). The table below is the short service-design summary.

| Role | Tenant Scope | Pharmacy Scope | Initial Access |
| --- | --- | --- | --- |
| `OWNER_EXECUTIVE` | Assigned tenant | Usually all pharmacies in tenant | Owner dashboard, cross-store summaries, high-level exceptions. |
| `STORE_MANAGER` | Assigned tenant | Assigned pharmacies | Store dashboard, assigned-store metrics, open issues, task summaries. |
| `PHARMACIST` | Assigned tenant | Assigned pharmacies | Pharmacist/technician dashboard, refill/work queue visibility when available, operational exceptions. |
| `TECHNICIAN` | Assigned tenant | Assigned pharmacies | Technician dashboard, assigned work, allowed operational status updates. |
| `BOOKKEEPER_FINANCE` | Assigned tenant | Assigned pharmacies or tenant-wide finance scope | Finance dashboard, financial period summaries, AR/close indicators where available. |
| `COMPLIANCE_ADMIN` | Assigned tenant | Tenant or assigned pharmacies | Compliance/admin dashboard, documents, licenses, compliance status. |
| `BUSINESS_DEVELOPMENT` | Assigned tenant | Assigned pharmacies or doctor-office scope | Doctor office list, visits/follow-up starter dashboard where available. |
| `TENANT_ADMIN` | Assigned tenant | Tenant-wide | Manage tenant users and tenant-level settings, but not other tenants. |
| `INTERNAL_PLATFORM_ADMIN` | Platform | Cross-tenant by internal policy | Manage tenants, users, roles, and pipeline audit views across tenants. |

Access rules:

- Default deny.
- Backend APIs enforce role, tenant, and pharmacy scope.
- Frontend route hiding is useful, but not sufficient.
- Owner and internal admin are not the same role.
- Tenant admin and internal platform admin are not the same role.
- Restricted source tables are backend-only unless explicitly exposed through safe admin/audit summaries.

## 11. Service Module Structure

Recommended package structure:

```text
com.analyticalrx.platform
  auth
    login, password hashing, JWT issuing, JWT validation, current user
  tenancy
    tenant registry, tenant resolver, schema resolver
  rbac
    roles, permissions, access evaluator, method guards
  dashboard
    dashboard controllers, response DTOs, read model services
  canonical
    safe repository/query helpers for canonical event tables
  admin
    user management, role assignment, internal admin views
  audit
    app audit writer, pipeline audit read APIs
  database
    datasource, migrations, tenant schema utilities
  common
    errors, pagination, filters, date ranges, API envelopes
```

Implementation direction:

- Use `Spring Security` for authentication and authorization.
- Use `BCrypt` or `Argon2` for password hashes.
- Use `JdbcTemplate`, `NamedParameterJdbcTemplate`, or `jOOQ` for dashboard queries.
- Use Flyway or Liquibase for `control_plane` migrations and tenant schema migrations.
- Use Testcontainers for local integration tests if practical.

## 12. API Design

### Common API Rules

All authenticated APIs should use:

- `Authorization: Bearer <access_token>`
- tenant key from path or selected server-side context
- date filters for dashboard APIs
- optional pharmacy filters where the role allows multiple pharmacies
- stable response DTOs that do not expose database table names
- data freshness and data quality metadata
- empty and partial data states

Common filter query parameters:

| Parameter | Meaning |
| --- | --- |
| `startDate` | Inclusive dashboard start date. |
| `endDate` | Inclusive dashboard end date. |
| `pharmacyIds` | Optional list of pharmacy IDs, restricted to the user's allowed scope. |
| `groupBy` | Optional grouping such as `day`, `week`, `month`, `store`, `drug`, or `payer`, where supported. |
| `status` | Optional status filter for task/audit/dashboard records. |
| `search` | Optional search text for safe list views only. |

### Auth APIs

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/api/v1/auth/login` | Sign in with username/email and password and return a signed JWT access token. |
| `POST` | `/api/v1/auth/logout` | Client discards token; server records logout or revokes token ID if denylist support is implemented. |
| `GET` | `/api/v1/me` | Return current user, tenants, roles, allowed pharmacies, and navigation capabilities from the validated JWT plus control-plane state. |

### Tenant And Pharmacy APIs

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/v1/tenants` | Return tenants visible to the current user. |
| `GET` | `/api/v1/tenants/{tenantKey}/pharmacies` | Return pharmacies visible to the current user in that tenant. |

### Dashboard APIs

Use one API per role dashboard, with reusable response shape.

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/v1/tenants/{tenantKey}/dashboards/owner` | Owner/executive dashboard. |
| `GET` | `/api/v1/tenants/{tenantKey}/dashboards/store-manager` | Store manager dashboard. |
| `GET` | `/api/v1/tenants/{tenantKey}/dashboards/pharmacist` | Pharmacist dashboard. |
| `GET` | `/api/v1/tenants/{tenantKey}/dashboards/technician` | Technician dashboard. |
| `GET` | `/api/v1/tenants/{tenantKey}/dashboards/bookkeeper` | Bookkeeper/finance dashboard. |
| `GET` | `/api/v1/tenants/{tenantKey}/dashboards/compliance-admin` | Compliance/admin dashboard. |
| `GET` | `/api/v1/tenants/{tenantKey}/dashboards/business-development` | Business development dashboard. |

Recommended response shape:

```json
{
  "dashboardId": "owner",
  "tenantKey": "valley-corporation",
  "generatedAt": "2026-08-18T10:30:00Z",
  "filters": {
    "startDate": "2026-08-01",
    "endDate": "2026-08-18",
    "pharmacyIds": []
  },
  "dataFreshness": {
    "latestEventAt": "2026-08-18T09:42:00Z",
    "status": "partial"
  },
  "cards": [],
  "charts": [],
  "tables": [],
  "warnings": []
}
```

The frontend should not need to know whether the data came from webhook, API, SFTP, or manual inputs. The API can expose freshness and source coverage, but it should hide raw source implementation details.

### Internal Admin APIs

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/v1/admin/tenants` | Internal admin tenant list. |
| `GET` | `/api/v1/admin/users` | User search/list. |
| `POST` | `/api/v1/admin/users` | Create user. |
| `PATCH` | `/api/v1/admin/users/{userId}` | Update user status/profile. |
| `GET` | `/api/v1/admin/role-assignments` | List role assignments. |
| `POST` | `/api/v1/admin/role-assignments` | Add role assignment. |
| `DELETE` | `/api/v1/admin/role-assignments/{assignmentId}` | Remove/deactivate role assignment. |
| `GET` | `/api/v1/admin/pipeline-audit` | Pipeline/import status counts and recent failures. |
| `GET` | `/api/v1/admin/permission-audit` | Permission change history. |

Admin APIs must never return raw payloads, direct patient identifiers, real `RxNo`, or real `RefillNo` in normal responses.

## 13. Dashboard Read Models

Phase 1 dashboards should be starter dashboards. Some widgets can be empty or partial until source feeds are finalized.

### Owner / Executive Dashboard

Purpose:

- cross-store visibility
- high-level revenue and prescription volume trends
- store comparison
- source/data quality exceptions

Initial data:

- total prescription/fill event volume
- event trend by day/week/month
- store comparison
- claim/reversal/rejection counts where available
- payment totals where available
- freshness/status warnings

### Store Manager Dashboard

Purpose:

- store-level operational view
- daily activity
- exceptions and incomplete data

Initial data:

- selected-store event volume
- filled/picked-up/rejected/reversed counts where available
- payment totals where available
- enrichment-needed count
- failed/partial records requiring review

### Pharmacist Dashboard

Purpose:

- pharmacy work visibility without exposing unnecessary PHI
- prescription/refill operational state where available

Initial data:

- refill/fill events by status
- verification status counts where available
- blocked or rejected claim counts
- upcoming refill queue placeholder until Phase 2 workflow is built

### Technician Dashboard

Purpose:

- assigned work queue starter view
- due/blocked operational items where available

Initial data:

- task/work queue placeholder if task tables are not implemented yet
- fill status counts where available
- ready/blocked/completed summary where available
- compliance/fridge log placeholder based on Airtable reference, not PrimeRx canonical events

### Bookkeeper / Finance Dashboard

Purpose:

- financial starter view
- revenue/payment summary by store and period

Initial data:

- total amount, amount due, tax, discount, other fee where available
- payer payment rows grouped by payment type and payer
- cash vs insurance payment split
- claim reversal/rejection counts
- missing/enrichment-needed payment data

### Compliance / Admin Dashboard

Purpose:

- platform and source health
- compliance/document starter view

Initial data:

- pipeline audit counts
- failed/retryable event counts
- raw payload retention status summary
- document/license placeholders from Airtable reference until those tables are implemented

### Business Development Dashboard

Purpose:

- doctor office and outreach visibility
- Phase 1 starter screen aligned with Airtable intent

Initial data:

- doctor CRM placeholder until CRM tables are implemented
- store/prescriber-level prescription trend only if safe and source data supports it
- no patient details

## 14. Restricted Data Rules

Normal dashboard responses must not include:

- raw webhook payload
- raw API response
- patient name
- patient DOB
- patient address
- patient phone/email
- insurance member ID
- real `RxNo`
- real `RefillNo`
- free-text notes that may contain PHI
- raw payload archive reference

Allowed dashboard-facing identifiers:

- tenant key
- pharmacy ID/display name
- canonical event ID where needed
- prescription reference token
- fill reference token
- drug lookup ID and safe drug descriptors
- payer lookup ID and safe payer descriptors

Restricted source references may be used by backend jobs for enrichment but should not be returned by dashboard APIs.

## 15. Phase 2 Extension Points

The Phase 1 service should not implement full Phase 2, but it should avoid choices that block it.

Future modules:

- workflow templates
- workflow runs
- internal scheduling
- refill queue
- alerts
- optional emails
- Doctor CRM

Design now for:

- role-aware navigation
- app audit records
- reusable dashboard response components
- tenant schema routing
- safe links between dashboard items and future workflow/task records

Do not build:

- custom rule builder
- patient-facing messaging
- advanced ML/forecasting
- automatic doctor emails by default

## 16. Testing Strategy

### Unit Tests

- password hashing and login validation
- tenant resolver
- schema name validation
- RBAC access evaluator
- date/filter validation
- dashboard response mapping

### Integration Tests

- login and `/me`
- owner can view all assigned pharmacies
- store manager cannot view unassigned pharmacy
- technician cannot call finance/admin APIs
- tenant admin cannot view another tenant
- internal platform admin can view cross-tenant admin summaries
- dashboard APIs do not return restricted fields
- tenant schema query uses resolved schema only

### Database Tests

- control plane migrations run cleanly
- tenant schema migrations run cleanly
- dashboard read queries work against `tenant_analyticalrx_dev`
- missing data returns empty/partial state instead of failure
- payment rows with `payment_type = cash` do not require payer

### Security Tests

- invalid tenant key returns not found or forbidden without leaking tenant existence unnecessarily
- schema injection attempts fail
- role escalation attempts fail
- raw payload references are not returned from normal APIs
- direct patient identifiers are not returned from dashboard APIs
- sensitive admin actions create audit records

## 17. Local Development Flow

1. Start the RDS tunnel using the documented SSM flow:

   ```powershell
   .\operations\start-phase1-db-tunnel.ps1 -EnvFile .env
   ```

2. Run the Spring Boot service locally with:

   ```bash
   ./gradlew bootRun
   ```

3. Local app connects to:

   ```text
   localhost:5433 -> SSM tunnel -> RDS Proxy -> RDS PostgreSQL
   ```

4. Local profile should use:

   ```text
   DB_SECRET_ID=analytical-rx/phase1/dev/postgres/app-rw
   CONTROL_PLANE_SCHEMA=control_plane
   ```

5. The service should expose:

   ```text
   GET /actuator/health
   GET /api/v1/me
   ```

## 18. Build And Deployment Flow

Recommended first implementation:

1. Create Spring Boot repo or service module.
2. Add Gradle/Maven build.
3. Add Dockerfile for Java 21 runtime.
4. Add GitHub Actions workflow:
   - run tests
   - build container image
   - push image to ECR
   - deploy to ECS Fargate dev service
5. Run migrations as a separate migration job, not as an uncontrolled side effect in every app startup.
6. Configure ECS task role with:
   - read database secret
   - write CloudWatch logs
   - read JWT signing/validation secret
7. Attach app service to:
   - current VPC
   - app subnets
   - `analytical-rx-phase1-app-sg`
8. Connect to RDS through:
   - `analytical-rx-phase1-rds-proxy.proxy-c6ry4mqo6ydb.us-east-1.rds.amazonaws.com`

## 19. Observability

Minimum Phase 1 observability:

- structured JSON logs
- request ID on every request
- tenant key and role in logs where safe
- no PHI in logs
- login failure count
- API error count
- dashboard response latency
- database query latency
- pipeline audit read latency
- health check endpoint

Recommended admin-visible operational metrics:

- events received
- events processed
- events failed
- events duplicate
- events needing enrichment
- latest successful ingestion time
- latest successful dashboard data time

## 20. Implementation Start Point

Start here:

1. Create the Spring Boot skeleton with health check and local profile.
2. Add `control_plane` migration for users, tenants, roles, and audit.
3. Seed one internal admin user and one dev tenant mapped to `tenant_analyticalrx_dev`.
4. Implement JWT login, JWT validation, and `/api/v1/me`.
5. Implement tenant resolver and RBAC evaluator.
6. Implement one read-only dashboard API first, preferably owner or daily sales, using canonical event data.
7. Add integration tests for tenant/pharmacy scoping.
8. Add remaining starter dashboard APIs.
9. Add internal admin audit views.
10. Connect frontend after the API contract stabilizes.

## 21. Review Questions

These are the decisions the team should confirm before implementation goes too far:

1. Are we comfortable adding a shared non-PHI `control_plane` schema for users, roles, tenant registry, and schema mapping?
2. Should Phase 1 use only short-lived access tokens, or should we also add refresh tokens?
3. Should dashboard query implementation start with Spring JDBC/JdbcTemplate, or should we use jOOQ from day one for stronger SQL typing?
4. Should the first deployed container runtime be ECS Fargate, or does the team prefer AWS App Runner for a simpler initial deployment?
5. Which dashboard should be implemented first as the vertical slice: owner overview, daily sales, or pipeline audit?
6. Should tenant admins be allowed to create users in Phase 1, or should only internal platform admins manage users initially?
7. Do we need a separate database role for dashboard reads before the first demo, or is the existing app read/write secret acceptable for dev?

## 22. Recommended First Vertical Slice

The first slice should prove the whole service pattern without trying to build every dashboard.

Recommended slice:

```text
JWT login
  -> /api/v1/me
  -> tenant schema resolution
  -> owner dashboard API
  -> read canonical event/payment data
  -> enforce tenant/pharmacy role scope
  -> frontend displays cards/table with empty/partial states
```

Why this slice:

- proves auth
- proves RBAC
- proves tenant schema routing
- proves RDS Proxy connection
- proves canonical read model
- gives frontend a stable response pattern
- avoids waiting for every Airtable-style module to exist

Once this works, the remaining dashboard APIs should follow the same pattern.
