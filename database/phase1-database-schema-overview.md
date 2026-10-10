# Phase 1 Database Schema Overview

This guide describes the deployed Phase 1 development database as verified on 10 October 2026. It is the quickest starting point for a reviewer. The detailed table definitions are in the SQL files and the full visual relationship map is in the PostgreSQL ERD.

## Design Boundaries

- One PostgreSQL database serves the platform.
- control_plane holds platform and tenant access metadata. It never holds pharmacy transaction data.
- Each customer tenant has its own PostgreSQL schema. The active development tenant is tenant_analyticalrx_dev.
- All relational primary and foreign keys are PostgreSQL bigint values. External source identifiers such as PrimeRx prescription, patient, payer, NDC, and pharmacy identifiers remain text.
- A user belongs to one tenant. Pharmacy visibility is granted explicitly through control_plane.user_pharmacy_access; roles determine what the user may do within that pharmacy scope.

## Control Plane

The control_plane schema currently has nine tables:

| Table | Purpose |
|---|---|
| tenant_registry | Platform registry of tenant IDs, keys, names, status, and schema names. |
| app_user | Tenant-scoped application users and password hashes. |
| user_pharmacy_access | Explicit pharmacy assignments for each user. |
| role_definition | Platform role catalogue. |
| permission_definition | Permission catalogue. |
| role_permission | Permissions granted to each role. |
| user_role | Roles assigned to a user. |
| permission_audit_event | Permission and role administration audit trail. |
| app_access_audit_event | Application access audit trail. |

## Tenant Data

The development tenant schema currently has twelve tables:

| Area | Tables | Purpose |
|---|---|---|
| Tenant and reference data | tenant, pharmacy, drug, payer | Tenant identity and normalized pharmacy, medication, and payer reference records. |
| Ingestion and processing | raw_payload_archive, source_rx_reference, ingestion_event, pharmacy_event, event_payment | Retain received source payloads, preserve external prescription references, trace ingestion, normalize pharmacy events, and represent one or more payments for each event. |
| Task management | task, task_comment, task_activity | Pharmacy-scoped operational tasks, discussion, and status history. |

pharmacy_event is the normalized operational record. event_payment carries payment amounts and points to a payer when the payment is insurance-backed. Cash payments have a null payer reference.

## Data Protection Boundary

raw_payload_archive.raw_payload contains the received source JSON and can contain PHI. It is restricted to ingestion, controlled support, and authorized recovery workflows. Dashboard and standard application APIs must query the normalized tables and must not return raw payload data.

The normalized tables intentionally retain only the fields needed for the current Phase 1 application and operational reporting. The raw archive supports traceability and recovery when a webhook is incomplete or a source API must fill missing information.

## Reading Order

1. Review the PostgreSQL ERD at ../diagrams/canonical-event-postgres-erd.svg for exact columns and relationships.
2. Read the table dictionary in canonical-event-table-dictionary.html for business meaning and access boundaries.
3. Review the control-plane schema at ../schemas/control_plane_schema.sql and tenant schema at ../schemas/mvp_canonical_event_schema.sql for the bootstrap definitions.
4. Review the migrations in ../schemas/migrations, especially the bigint conversion and task-management migration.

## Migration Record

The current documentation retains historical migrations because an existing development database was evolved in place:

- 2026-08-29-rename-event-model-tables.sql: renamed the former canonical event table names to pharmacy_event and event_payment.
- 2026-09-04-raw-payload-external-identifiers.sql: historical UUID-era raw-payload change; do not run it against the current schema.
- 2026-09-29-bigint-internal-ids.sql: converted internal relational identifiers to bigint.
- 2026-10-03-task-management.sql: added task, task comment, and task activity tables plus task permissions.
