# AnalyticalRx Role-Based Access Control Standard

Status: Draft standard for Phase 1 and Phase 2 implementation<br>
Primary audience: backend, frontend, data engineering, QA, security, and implementation leads<br>
Related docs:

- [Product Requirements Document](../prd/product-requirements-document.md)
- [Data Platform Service Design](data-platform-service-design.md)
- [Canonical Event Schema Review Guide](../database/canonical-event-schema-review-guide.html)
- [Canonical Event Table Dictionary](../database/canonical-event-table-dictionary.html)

## 1. Purpose

This document defines the standard role-based access control model for AnalyticalRx. Every API, background job, frontend screen, dashboard, and admin tool should use this document as the source of truth for access decisions.

The goal is to make access predictable across the product:

- Users see only the tenants and pharmacies assigned to them.
- Users see only the modules their role allows.
- Normal dashboard users never receive restricted raw payloads, real Rx numbers, refill numbers, direct patient identifiers, or raw vendor responses.
- Backend APIs enforce access. The frontend may hide UI, but it must not be the only access control layer.
- Non-human services use service permissions, not customer user roles.

## 2. Access Control Principles

All implementation should follow these rules.

| Principle | Standard |
| --- | --- |
| Deny by default | If a role, tenant, pharmacy, module, action, or field is not explicitly allowed, the API must deny access. |
| Backend enforcement | Every API must check authorization server-side before reading or writing data. |
| Tenant isolation | Every request must resolve tenant access from authenticated context and trusted control-plane data. |
| Pharmacy scope | Pharmacy filters must be intersected with the user's allowed pharmacy scope. |
| Roles are additive | A user can have multiple roles. Role permissions add together, but restricted data rules still apply. |
| Admin is not owner | `TENANT_ADMIN` manages users/settings. It does not automatically grant all owner/finance/business views unless those roles are also assigned. |
| Owner is not platform admin | `OWNER` has tenant business visibility. It must not manage other tenants or platform-wide settings. |
| No schema names in client trust | JWTs and request paths may include tenant keys, but database schema names must be resolved server-side. |
| No restricted fields in dashboards | Dashboard APIs must use safe tables/views and return only approved fields. |
| Re-check sensitive permissions | User/role management, workflow settings, email settings, and sensitive admin actions must re-check current control-plane state, not only JWT claims. |
| Audit sensitive actions | Login, permission changes, admin actions, workflow setting changes, optional email actions, and sensitive read attempts should create audit records. |

## 3. Key Terms

| Term | Meaning |
| --- | --- |
| Tenant | A customer organization or pharmacy group. A tenant may own one or more pharmacy locations. |
| Pharmacy | A store/location under a tenant. Most operational users are scoped to one or more pharmacies. |
| Role | A named business or platform responsibility such as `STORE_MANAGER` or `BOOKKEEPER`. |
| Permission | A concrete action such as `dashboard.owner.read` or `tenant.users.manage`. Roles map to permissions. |
| Scope | The tenant, pharmacy, module, and data boundary where a permission applies. |
| Control plane | Shared non-PHI metadata for users, tenants, roles, assignments, and audit records. |
| Tenant schema | Tenant-owned pharmacy data schema in PostgreSQL, for example `tenant_analyticalrx_dev`. |
| Restricted source data | Raw payload metadata, real `RxNo`, `RefillNo`, raw vendor response references, and any PHI-adjacent source data used only by backend processing. |
| Safe dashboard data | PHI-minimized tables and views such as `pharmacy_event`, `event_payment`, `drug`, `payer`, and approved aggregates. |

## 4. Scope Dimensions

Every authorization decision should evaluate these dimensions.

| Dimension | Examples | Enforcement rule |
| --- | --- | --- |
| Principal type | End user, internal admin, service principal, background job | Do not mix user roles and service permissions. |
| Tenant | `valley-corporation`, `tenant_analyticalrx_dev` | User must be assigned to the tenant or have approved internal cross-tenant access. |
| Pharmacy | One store, many stores, all stores in tenant | Query filters must be limited to allowed pharmacies. |
| Role | Owner, manager, pharmacist, technician, finance, compliance, business development | Role must allow the requested module/action. |
| Module | Dashboard, user admin, ingestion status, finance, workflow, Doctor CRM, alerts | Module must be enabled for the role and tenant. |
| Action | Read, create, update, delete, approve, retry, export, manage settings | Write/manage actions require stricter checks than read actions. |
| Data class | Safe dashboard data, restricted source reference, raw payload archive, control-plane metadata | Restricted data is blocked for normal dashboard users even if their role is broad. |

## 5. Role Assignment Model

The backend should model access as assignments, not as one global role per user.

Recommended assignment shape:

```text
user_id
tenant_id
role_code
pharmacy_id nullable
status
created_by
created_at
updated_at
```

Rules:

- A user may have multiple roles in the same tenant.
- A role may be tenant-wide or pharmacy-scoped.
- `pharmacy_id = null` means tenant-wide only when the role explicitly supports tenant-wide scope.
- If a role is pharmacy-scoped and `pharmacy_id` is null, the assignment is invalid unless the backend treats it as all assigned pharmacies through a separate mapping.
- Internal platform roles should be stored separately or clearly marked as platform scope.
- Changes to assignments must increment a `permissions_version` value so stale JWTs can be rejected or refreshed for sensitive actions.

## 6. JWT And Current User Context

Phase 1 uses username/password login with backend-issued JWT bearer tokens.

JWTs may include:

- user ID
- email/username
- tenant keys
- tenant-scoped role claims
- allowed pharmacy IDs or pharmacy scope hints
- internal platform role claims
- permissions version
- token issue/expiry timestamps

JWTs must not include:

- PHI
- raw source payloads
- real `RxNo`
- real `RefillNo`
- raw vendor response data
- database schema names
- database credentials

For every authenticated request, the backend must build a trusted `CurrentUserContext`:

```text
user_id
tenant_id
tenant_key
resolved_tenant_schema_name
roles
allowed_pharmacy_ids
internal_roles
permissions_version
```

The tenant schema name must come from `control_plane.tenant_registry`, not directly from the JWT or request body.

## 7. Customer-Facing Business Roles

These are roles assigned to customer users inside a tenant.

### `OWNER`

Meaning: Tenant-level business owner or executive who needs cross-store visibility and business performance context.

Default scope:

- Tenant-wide.
- Usually all pharmacies in the tenant.

Allowed:

- Read owner/executive dashboard.
- Read cross-store summaries.
- Read store comparison metrics.
- Read high-level revenue/gross profit summaries where available.
- Read workflow completion summaries.
- Read Doctor CRM summary and outreach progress.
- Read data freshness indicators.
- Read operational exception summaries.

Not allowed by this role alone:

- Manage platform-wide tenants.
- Manage other tenants.
- Manage users or role assignments unless also assigned `TENANT_ADMIN`.
- Read restricted raw payload archive.
- Read real `RxNo` or `RefillNo`.
- Read direct patient identifiers.
- Change workflow or email settings unless also assigned an admin role.

Typical users:

- Pharmacy group owner.
- Executive operator.
- Senior client stakeholder.

Recommended assignment:

- Assign `OWNER` tenant-wide.
- Add `TENANT_ADMIN` only if this person should manage tenant users/settings.
- Add `BOOKKEEPER` only if this person needs detailed finance views beyond executive summaries.

### `STORE_MANAGER`

Meaning: Store/location manager responsible for operational performance and assigned work at one or more pharmacies.

Default scope:

- Assigned pharmacies only.

Allowed:

- Read store manager dashboard for assigned pharmacies.
- Read assigned-store Rx volume, revenue, trend, and status indicators where available.
- Read assigned-store open issues, task summaries, workload, blocked items, overdue tasks, and refill queue progress.
- Read pharmacist/technician work summaries for assigned pharmacies.
- Create and update internal tasks for assigned pharmacies.
- View Doctor CRM records related to assigned pharmacies when enabled.
- View business development follow-ups for assigned pharmacies when enabled.
- View workflow status for assigned pharmacies.

Not allowed by this role alone:

- View unassigned pharmacy data.
- Manage tenant users or role assignments.
- Read finance/bookkeeper-specific details unless also assigned `BOOKKEEPER`.
- Read restricted source references or raw payload archive.
- Override pharmacist-only clinical decisions unless explicitly granted by workflow permission and pharmacy policy.
- Manage outbound email settings.

Typical users:

- Store manager.
- Operations lead responsible for specific stores.

Recommended assignment:

- Assign `STORE_MANAGER` for each pharmacy they manage.
- Add `PHARMACIST` only if the user also performs pharmacist workflow actions.
- Add `BUSINESS_DEVELOPMENT` only if the user owns outreach work.

### `PHARMACIST`

Meaning: Licensed pharmacy user responsible for clinical/operational verification, refill readiness, and pharmacy work queues.

Default scope:

- Assigned pharmacies only.

Allowed:

- Read pharmacist dashboard for assigned pharmacies.
- Read daily refill queue and upcoming refill suggestions when Phase 2 workflows are enabled.
- Read assigned tasks, due items, blocked items, and operational exceptions.
- Update allowed workflow statuses such as verified, preparing, ready, blocked, completed, or skipped according to configured pharmacy policy.
- Perform pharmacist-only verification actions when those workflows are enabled.
- Add safe internal notes to workflow/task records if approved by the product/security policy.

Not allowed by this role alone:

- View unassigned pharmacy data.
- Manage tenant users or roles.
- Read owner, finance, compliance, or business development dashboards unless separately assigned.
- Read restricted raw payload archive.
- Read real `RxNo` or `RefillNo` from `source_rx_reference`.
- Export bulk data.
- Manage workflow definitions or email settings.

Typical users:

- Pharmacist.
- Pharmacist in charge.

Recommended assignment:

- Assign `PHARMACIST` to the pharmacies where the user works.
- Add `STORE_MANAGER` only if the user also manages store-level operations.
- Avoid assigning finance/admin roles unless required by job responsibility.

### `TECHNICIAN`

Meaning: Pharmacy technician or staff user working assigned queues and operational tasks.

Default scope:

- Assigned pharmacies only.

Allowed:

- Read technician dashboard for assigned pharmacies.
- Read assigned task queue.
- Read daily refill queue and upcoming refill suggestions when enabled.
- Update non-clinical workflow statuses allowed by tenant policy, for example preparing, ready, blocked, or completed.
- Add safe task status updates where enabled.

Not allowed by this role alone:

- View unassigned pharmacy data.
- Access finance/admin/compliance/business development dashboards.
- Manage users, roles, workflows, or email settings.
- Perform pharmacist-only verification unless explicitly approved by policy and represented as a specific permission.
- Read restricted raw payload archive.
- Read real `RxNo` or `RefillNo`.
- Export bulk data.

Typical users:

- Pharmacy technician.
- Pharmacy operations assistant.

Recommended assignment:

- Assign `TECHNICIAN` to assigned pharmacies only.
- Keep write actions limited to operational status updates.

### `BOOKKEEPER`

Meaning: Finance/bookkeeping user responsible for revenue, payment, close, AR, and financial reconciliation views.

Default scope:

- Tenant-wide finance scope or assigned pharmacies, depending on customer setup.

Allowed:

- Read bookkeeper/finance dashboard.
- Read financial period summaries.
- Read revenue, paid amount, amount due, payment breakdown, close status, and AR indicators where available.
- Read payer/payment summaries from safe tables and aggregates.
- Read missing report indicators and reconciliation gaps.
- Export finance reports only if export permission is explicitly enabled.

Not allowed by this role alone:

- Manage users or role assignments.
- Manage workflows or email settings.
- View restricted raw payload archive.
- Read real `RxNo` or `RefillNo`.
- Read direct patient identifiers.
- Perform pharmacist/technician operational actions.
- Manage Doctor CRM unless separately assigned.

Typical users:

- Bookkeeper.
- Finance manager.
- Accounting support user.

Recommended assignment:

- Assign tenant-wide when the finance user supports the whole pharmacy group.
- Assign pharmacy-scoped when the customer wants location-level finance separation.
- Add `OWNER` only for finance leaders who should also see executive dashboards.

### `COMPLIANCE_ADMIN`

Meaning: Compliance or administrative user responsible for licenses, documents, compliance status, audit visibility, and operational governance.

Default scope:

- Tenant-wide or assigned pharmacies.

Allowed:

- Read compliance/admin dashboard.
- Manage compliance documents, license records, renewal status, and compliance checklist items when those modules exist.
- Read tenant-scoped ingestion/import status summaries.
- Read workflow/audit summaries needed for compliance review.
- Manage compliance reminder workflows when enabled.

Not allowed by this role alone:

- Manage platform-wide settings.
- Manage tenant users or role assignments unless also assigned `TENANT_ADMIN`.
- Read restricted raw payload archive.
- Read real `RxNo` or `RefillNo`.
- Read direct patient identifiers.
- Access detailed finance views unless also assigned `BOOKKEEPER`.
- Send outbound doctor emails unless email permissions are explicitly enabled.

Typical users:

- Compliance officer.
- Administrative lead.
- License/document manager.

Recommended assignment:

- Assign `COMPLIANCE_ADMIN` tenant-wide if one compliance user supports all stores.
- Assign pharmacy-scoped if compliance work is location-specific.
- Add `TENANT_ADMIN` only if this user should manage user access.

### `BUSINESS_DEVELOPMENT`

Meaning: User responsible for doctor office relationships, outreach tasks, visits, follow-ups, pitch history, and relationship outcomes.

Default scope:

- Assigned pharmacies or assigned doctor-office territory when implemented.

Allowed:

- Read business development dashboard.
- Create and edit doctor office profiles.
- Read and update visit history, pitch history, follow-up tasks, outcomes, relationship stage, and next action.
- Use outreach calendar for visits, calls, and optional emails.
- Create internal scheduled tasks related to doctor outreach.
- View prior pitch notes and outcomes that are safe for the assigned tenant/scope.

Not allowed by this role alone:

- View finance/bookkeeper dashboards.
- Manage tenant users or role assignments.
- Read restricted raw payload archive.
- Read real `RxNo` or `RefillNo`.
- Read direct patient identifiers.
- Send automatic outbound doctor emails unless email sending is explicitly enabled and the user has email permission.
- Change global email sender/template rules.

Typical users:

- Business development representative.
- Marketing/outreach coordinator.
- Manager responsible for provider relationships.

Recommended assignment:

- Assign `BUSINESS_DEVELOPMENT` to the relevant tenant and pharmacy/territory scope.
- Add `STORE_MANAGER` if the same user manages store operations.

### `TENANT_ADMIN`

Meaning: Customer-side tenant administrator who manages user access, tenant-level settings, pharmacy mappings, and workflow/email enablement inside one tenant.

Default scope:

- Tenant-wide.

Allowed:

- Read tenant admin dashboard/admin area.
- Manage tenant users.
- Assign and remove tenant roles within allowed role set.
- Assign pharmacy scopes.
- Manage tenant-level settings.
- Enable or disable predefined workflows.
- Configure workflow thresholds and schedules when available.
- Enable optional internal emails or outbound doctor emails only after product/security-approved settings exist.
- View tenant permission audit history.
- View tenant-scoped ingestion/import status summaries.

Not allowed by this role alone:

- Access other tenants.
- Manage platform-level tenant registry.
- Grant internal platform roles.
- Read restricted raw payload archive.
- Read real `RxNo` or `RefillNo`.
- Read direct patient identifiers.
- Read finance dashboards unless also assigned `BOOKKEEPER` or `OWNER`.
- Read business development dashboards unless also assigned `BUSINESS_DEVELOPMENT` or `OWNER`.

Typical users:

- Customer admin.
- Trusted owner/operator who manages access.
- AnalyticalRx implementation owner for a tenant during setup, only if approved.

Recommended assignment:

- Assign sparingly.
- Prefer one or two tenant admins per customer.
- Pair with `OWNER`, `COMPLIANCE_ADMIN`, or `BOOKKEEPER` only when the user needs those product views.

## 8. Internal Platform Roles

Internal roles are for AnalyticalRx team members and should not be assigned to customer users.

### `INTERNAL_PLATFORM_ADMIN`

Meaning: AnalyticalRx internal administrator who can manage platform metadata across tenants.

Default scope:

- Platform-wide, subject to company policy.

Allowed:

- Manage tenant registry and tenant onboarding metadata.
- Manage internal/admin user access when approved.
- View cross-tenant admin summaries.
- View pipeline/import status summaries across tenants.
- View permission audit history.
- Support tenant setup and troubleshooting.
- Run approved admin actions needed for operations.

Not allowed by this role by default:

- Read raw PrimeRx payloads.
- Read real `RxNo` or `RefillNo`.
- Read direct patient identifiers.
- Access production data outside approved support process.
- Use customer dashboards for business browsing.
- Bypass audit logging.

Important:

- `INTERNAL_PLATFORM_ADMIN` is not a replacement for AWS IAM permissions.
- AWS infrastructure access must be controlled separately through IAM.
- Production break-glass access should be separate, named, time-limited, approved, and audited.

### Internal Data Engineering Access

For Phase 1, do not create a broad customer-facing `DATA_ENGINEER` role unless the product needs it. Data engineering access should be handled as an internal approved access path.

Allowed with approval:

- Read dashboard-safe tables/views such as `pharmacy_event`, `event_payment`, `drug`, `payer`, and approved aggregates.
- Read de-identified/tokenized analytics extracts.
- Review data quality and reconciliation outputs.

Not allowed by default:

- Read raw payload archive.
- Read `source_rx_reference`.
- Read real `RxNo` or `RefillNo`.
- Read direct patient identifiers.
- Manage customer users or roles.

Implementation guidance:

- If an app role is needed later, create a separate `INTERNAL_DATA_READER` or `INTERNAL_DATA_ENGINEER` role after security review.
- Until then, use database/IAM access controls and documented approvals for data engineering tasks.

## 9. Service Principals

Service principals are not human product roles. They should use AWS IAM roles and database credentials/roles appropriate to their function.

| Service principal | Purpose | Allowed data/actions | Not allowed |
| --- | --- | --- | --- |
| `WEBHOOK_RECEIVER_SERVICE` | Receive PrimeRx/Micro Merchant webhooks and enqueue processing work. | Validate request, create `ingestion_event`, optionally create `raw_payload_archive` metadata, enqueue SQS message. | Query dashboards, read restricted source references, update `pharmacy_event`, return raw payloads. |
| `WEBHOOK_PROCESSOR_SERVICE` | Process queued events into safe records. | Read queued event payload, update `ingestion_event`, upsert `source_rx_reference`, `drug`, `payer`, write `pharmacy_event`, write `event_payment`. | Expose raw payloads to dashboards, log PHI, grant user access. |
| `API_ENRICHMENT_WORKER` | Use PrimeRx API to fill missing safe fields. | Read `source_rx_reference`, call PrimeRx API, update safe fields in `drug`, `payer`, `pharmacy_event`, `event_payment`, update enrichment status. | Return raw source identifiers to frontend, write direct patient identifiers to dashboard tables, change user access. |
| `DATA_PLATFORM_SERVICE` | User-facing Spring backend APIs. | Authenticate users, issue/validate JWTs, resolve tenant schema, enforce RBAC, read safe dashboard tables/views, manage permitted admin actions. | Trust client-provided schema names, return restricted fields to normal users, skip RBAC checks. |
| `WORKFLOW_AUTOMATION_SERVICE` | Phase 2 predefined workflow runner. | Create tasks, queue items, alerts, workflow run records, optional email actions when enabled. | Read raw payloads, bypass role/pharmacy scope, auto-send external emails without enabled settings. |
| `REPORTING_DATA_JOB` | Build safe aggregates and data quality outputs. | Read safe event/payment/lookup tables and write approved aggregates. | Read `source_rx_reference` or raw payload archive unless explicitly approved for a controlled reconciliation task. |

## 10. Data Access Classes

All APIs and jobs should classify the data they touch.

| Data class | Examples | Default access |
| --- | --- | --- |
| Public application metadata | Login page configuration, app version, health checks without tenant data | Public or authenticated depending on endpoint. |
| User self metadata | `/api/v1/me`, own tenants, own roles, own pharmacy scope | Authenticated user only. |
| Tenant dashboard-safe data | `pharmacy_event`, `event_payment`, `drug`, `payer`, safe aggregates | Role and pharmacy scoped. |
| Tenant admin metadata | Tenant users, assignments, workflow settings, permission audit | `TENANT_ADMIN` for own tenant, `INTERNAL_PLATFORM_ADMIN` by policy. |
| Ingestion status metadata | `ingestion_event` summaries, failure counts, data freshness | `TENANT_ADMIN`, `COMPLIANCE_ADMIN`, internal platform/admin support; limited owner freshness summary allowed. |
| Restricted source reference | `source_rx_reference`, real `RxNo`, real `RefillNo` | Backend enrichment/processor services only by default. |
| Raw payload archive metadata | `raw_payload_archive`, S3 pointer/hash/retention metadata | Receiver/processor/admin support by explicit need. Not normal dashboards. |
| Raw payload content | Original PrimeRx/API/SFTP files or raw webhook JSON | Restricted operational storage only. No normal API exposure. |
| Direct patient identifiers | Name, DOB, address, phone, email, insurance member ID, notes | Out of Phase 1 dashboards. Requires explicit compliance-approved design before use. |

## 11. API Permission Catalog

Use permission codes internally even if the frontend only knows roles.

### Authentication And Current User

| Permission | APIs | Roles |
| --- | --- | --- |
| `auth.login` | `POST /api/v1/auth/login` | Public credential flow. |
| `auth.logout` | `POST /api/v1/auth/logout` | Authenticated user. |
| `me.read` | `GET /api/v1/me` | Authenticated user. |
| `tenant.list_assigned` | `GET /api/v1/tenants` | Authenticated user; returns assigned tenants only. |
| `pharmacy.list_assigned` | `GET /api/v1/tenants/{tenantKey}/pharmacies` | Any tenant-assigned role; returns assigned pharmacies only. |

### Phase 1 Dashboards

| Permission | API | Allowed roles | Scope |
| --- | --- | --- | --- |
| `dashboard.owner.read` | `GET /api/v1/tenants/{tenantKey}/dashboards/owner` | `OWNER` | Assigned pharmacies. |
| `dashboard.store_manager.read` | `GET /api/v1/tenants/{tenantKey}/dashboards/store-manager` | `STORE_MANAGER` | Assigned pharmacies. |
| `dashboard.pharmacist.read` | `GET /api/v1/tenants/{tenantKey}/dashboards/pharmacist` | `PHARMACIST`, `STORE_MANAGER` | Assigned pharmacies. |
| `dashboard.technician.read` | `GET /api/v1/tenants/{tenantKey}/dashboards/technician` | `TECHNICIAN`, `PHARMACIST`, `STORE_MANAGER` | Assigned pharmacies. |
| `dashboard.bookkeeper.read` | `GET /api/v1/tenants/{tenantKey}/dashboards/bookkeeper` | `BOOKKEEPER` | Assigned pharmacies. |
| `dashboard.compliance.read` | `GET /api/v1/tenants/{tenantKey}/dashboards/compliance-admin` | `COMPLIANCE_ADMIN`, `TENANT_ADMIN` | Assigned pharmacies. |
| `dashboard.business_development.read` | `GET /api/v1/tenants/{tenantKey}/dashboards/business-development` | `BUSINESS_DEVELOPMENT`, `STORE_MANAGER` | Assigned pharmacies/territory. |

Rules:

- A dashboard API must still apply pharmacy filters even when a role can view the dashboard.
- `TENANT_ADMIN` does not automatically get all dashboard permissions.
- Dashboard APIs must not return restricted source references or raw payload references.
- Dashboard APIs must support safe empty states when source data is incomplete.

### Tenant Admin APIs

Recommended Phase 1 tenant admin APIs should be tenant-scoped.

| Permission | APIs | Allowed roles | Scope |
| --- | --- | --- | --- |
| `tenant.users.read` | List/view tenant users | `TENANT_ADMIN` | Own tenant only. |
| `tenant.users.manage` | Create/update/deactivate tenant users | `TENANT_ADMIN` | Own tenant only. |
| `tenant.roles.read` | List role assignments | `TENANT_ADMIN` | Own tenant only. |
| `tenant.roles.manage` | Add/remove role assignments | `TENANT_ADMIN` | Own tenant only, allowed customer roles only. |
| `tenant.settings.read` | Read tenant settings | `TENANT_ADMIN`, `COMPLIANCE_ADMIN`, `OWNER` | Own tenant only. |
| `tenant.settings.manage` | Update tenant settings | `TENANT_ADMIN` | Own tenant only. |
| `pipeline.status.read` | View ingestion/import status summary | `TENANT_ADMIN`, `COMPLIANCE_ADMIN`, `INTERNAL_PLATFORM_ADMIN` | Tenant-scoped unless internal. |
| `permission_audit.read` | View permission change history | `TENANT_ADMIN`, `INTERNAL_PLATFORM_ADMIN` | Tenant-scoped unless internal. |

Rules:

- Tenant admins can assign only customer-facing roles, not internal platform roles.
- Tenant admins cannot grant access to tenants they do not administer.
- Tenant admins cannot grant a pharmacy scope outside their tenant.
- Every role assignment change must create a permission audit record.

### Internal Platform Admin APIs

Existing service design lists internal admin endpoints under `/api/v1/admin/...`. These should be protected by internal roles only.

| Permission | APIs | Allowed roles | Scope |
| --- | --- | --- | --- |
| `platform.tenants.read` | `GET /api/v1/admin/tenants` | `INTERNAL_PLATFORM_ADMIN` | Cross-tenant by policy. |
| `platform.tenants.manage` | Create/update tenant registry | `INTERNAL_PLATFORM_ADMIN` | Cross-tenant by policy. |
| `platform.users.read` | `GET /api/v1/admin/users` | `INTERNAL_PLATFORM_ADMIN` | Cross-tenant by policy. |
| `platform.users.manage` | Create/update/deactivate platform-managed users | `INTERNAL_PLATFORM_ADMIN` | Cross-tenant by policy. |
| `platform.roles.manage` | Manage internal or cross-tenant role assignments | `INTERNAL_PLATFORM_ADMIN` | Cross-tenant by policy. |
| `platform.pipeline_status.read` | `GET /api/v1/admin/pipeline-audit` | `INTERNAL_PLATFORM_ADMIN` | Safe metadata only. |
| `platform.permission_audit.read` | `GET /api/v1/admin/permission-audit` | `INTERNAL_PLATFORM_ADMIN` | Cross-tenant by policy. |

Rules:

- Internal admin APIs must not be reachable by customer tenant admins.
- Internal admin views should show safe operational metadata unless a separate approved break-glass path exists.
- Internal actions must be audited.

### Phase 2 Workflow And Doctor CRM APIs

These permissions should guide Phase 2 implementation.

| Permission | Module/API area | Allowed roles | Scope |
| --- | --- | --- | --- |
| `workflow.settings.read` | Workflow settings | `TENANT_ADMIN`, `COMPLIANCE_ADMIN`, `OWNER` | Tenant or assigned pharmacies. |
| `workflow.settings.manage` | Enable/disable predefined workflows, thresholds, schedules | `TENANT_ADMIN` | Own tenant only. |
| `workflow.run.read` | Workflow run status and failures | `TENANT_ADMIN`, `COMPLIANCE_ADMIN`, `STORE_MANAGER`, `OWNER` | Tenant or assigned pharmacies. |
| `task.read` | Task/queue list and details | Role assigned to task/module | Tenant and pharmacy scoped. |
| `task.create` | Create internal scheduled task | `STORE_MANAGER`, `BUSINESS_DEVELOPMENT`, `TENANT_ADMIN`, `OWNER` | Assigned tenant/pharmacy/module. |
| `task.update_status` | Update task or queue item status | Assigned owner role, `STORE_MANAGER`, `PHARMACIST`, `TECHNICIAN` for allowed statuses | Assigned task and pharmacy. |
| `refill_queue.read` | Daily refill queue and upcoming refills | `PHARMACIST`, `TECHNICIAN`, `STORE_MANAGER`, `OWNER` | Assigned pharmacies. |
| `refill_queue.verify` | Verify refill queue item | `PHARMACIST`, approved `TECHNICIAN` only if policy allows | Assigned pharmacies. |
| `doctor_crm.read` | Doctor office list, profile, pitch/visit history | `BUSINESS_DEVELOPMENT`, `STORE_MANAGER`, `OWNER` | Assigned pharmacies/territory. |
| `doctor_crm.manage` | Create/update doctor office records and outreach tasks | `BUSINESS_DEVELOPMENT`, `STORE_MANAGER`, `OWNER` | Assigned pharmacies/territory. |
| `email.settings.manage` | Enable email, sender rules, templates | `TENANT_ADMIN` | Own tenant only. |
| `email.send_or_schedule` | Schedule/send optional outreach email when enabled | `BUSINESS_DEVELOPMENT`, `TENANT_ADMIN` | Own tenant/approved templates only. |

Rules:

- Email sending is disabled by default.
- Outbound doctor emails require tenant-level enablement, approved sender identity, approved template behavior, and audit logging.
- Workflow automations prepare work and suggest next actions. Clinical/operational actions still require human verification.

## 12. Standard Role Bundles By User Type

Use these defaults when setting up users.

| User type | Recommended roles | Scope | Notes |
| --- | --- | --- | --- |
| Pharmacy group owner | `OWNER` | Tenant-wide, all pharmacies | Add `TENANT_ADMIN` only if they manage users/settings. Add `BOOKKEEPER` only for detailed finance views. |
| Executive operator | `OWNER` | Tenant-wide or assigned pharmacies | Good for cross-store visibility without user-management power. |
| Customer admin | `TENANT_ADMIN` | Tenant-wide | Add business roles separately if they also need dashboards. |
| Store manager | `STORE_MANAGER` | Assigned pharmacies | Add `PHARMACIST` only if they perform pharmacist workflow actions. |
| Pharmacist in charge | `PHARMACIST`, optional `STORE_MANAGER` | Assigned pharmacies | Use `STORE_MANAGER` only when responsible for store operations. |
| Pharmacist | `PHARMACIST` | Assigned pharmacies | No finance/admin/business roles by default. |
| Technician | `TECHNICIAN` | Assigned pharmacies | Keep writes limited to approved status updates. |
| Bookkeeper | `BOOKKEEPER` | Tenant-wide or assigned pharmacies | Add `OWNER` only for finance leaders needing executive dashboards. |
| Compliance officer | `COMPLIANCE_ADMIN` | Tenant-wide or assigned pharmacies | Add `TENANT_ADMIN` only if they manage user access. |
| Business development user | `BUSINESS_DEVELOPMENT` | Assigned pharmacies/territory | Add `STORE_MANAGER` only if also managing store operations. |
| AnalyticalRx platform admin | `INTERNAL_PLATFORM_ADMIN` | Platform-wide by policy | Internal only. Not for customer users. |
| Data engineer | No default customer role | Approved safe-data access path | Use safe canonical/aggregate data. Do not grant raw/source-reference access by default. |
| QA tester | Role being tested | Dev tenant only | Assign the exact role/scope needed for the test case. Avoid broad admin access. |

## 13. Frontend Navigation Rules

The frontend should not hardcode role assumptions. It should call `/api/v1/me` after login and build navigation from returned capabilities.

`/api/v1/me` should return:

- current user display metadata
- assigned tenants
- allowed pharmacies per tenant
- assigned roles per tenant
- navigation capabilities
- feature flags/modules enabled for the tenant

Frontend rules:

- Hide screens the user cannot access.
- Still expect API calls to be denied if the user lacks permission.
- Do not store restricted source identifiers in browser state.
- Do not expose database schema names in route params, local storage, or logs.
- Do not infer access from dashboard URLs alone.

## 14. Backend Enforcement Rules

Every API handler should follow this flow.

```text
1. Validate JWT signature, issuer, audience, expiry, and token status.
2. Load or validate current user context.
3. Resolve tenant from path/context.
4. Confirm user is assigned to tenant.
5. Resolve tenant schema name from control_plane.tenant_registry.
6. Check role permission for the endpoint/action.
7. Intersect requested pharmacy filters with allowed pharmacy scope.
8. Apply server-side data-class restrictions.
9. Query only approved tables/views.
10. Audit sensitive actions.
```

For read APIs:

- Return only fields approved for the role.
- Apply date and pharmacy filters server-side.
- If the user has no matching pharmacy scope, return empty or forbidden according to endpoint policy.

For write APIs:

- Check role and action permission.
- Check tenant and pharmacy ownership of the target record.
- Check allowed state transitions.
- Re-check current permissions from the control plane for sensitive writes.
- Create audit records for user management, role changes, workflow settings, email actions, and sensitive admin operations.

## 15. Database/Table Access Standard

Application roles should not map directly to unrestricted database users. The backend service should enforce product RBAC and query the database through controlled service access.

| Table group | Tables | Normal dashboard users | Tenant admins/compliance | Internal/platform services |
| --- | --- | --- | --- | --- |
| Control plane | `control_plane.app_user`, `tenant_registry`, assignments, permission audit | Own `/me` data only | Tenant-scoped user/settings APIs | Internal admin APIs by policy |
| Safe lookup | `pharmacy`, `drug`, `payer` | Read through approved APIs/views | Read through approved APIs/views | Read/write as needed by services |
| Safe events | `pharmacy_event`, `event_payment` | Read through role-scoped dashboard APIs | Read summaries through approved APIs | Processor/enrichment/reporting read/write as needed |
| Ingestion status | `ingestion_event` | No raw row access; data freshness summary only if needed | Tenant-scoped status summaries | Receiver/processor/internal admin safe metadata |
| Restricted source refs | `source_rx_reference` | No access | No access by default | Processor/API enrichment only |
| Raw archive metadata | `raw_payload_archive` | No access | Summary only if explicitly approved | Receiver/processor/internal support by policy |
| Raw archive content | S3 raw payload files | No access | No access by default | Controlled operational access only |

## 16. Field-Level Restrictions

These fields must not be returned by normal dashboard APIs:

- real `RxNo`
- real `RefillNo`
- patient first name
- patient last name
- full date of birth
- full address
- phone number
- email
- insurance member ID
- prescription images
- free-text notes that may contain PHI
- raw webhook payload
- raw API response
- raw SFTP source row
- raw payload S3 object path unless explicitly approved for admin support

Allowed dashboard-facing identifiers:

- tenant key
- pharmacy ID and display name
- `prescription_reference_token`
- `fill_reference_token`
- `drug_id`
- `payer_id`
- event IDs such as `pharmacy_event.id`
- workflow/task IDs

## 17. Role And Permission Test Matrix

Every role should have tests for at least these cases.

| Test case | Expected result |
| --- | --- |
| User without tenant assignment calls tenant API | Denied. |
| User assigned to Tenant A calls Tenant B API | Denied without leaking sensitive tenant data. |
| User filters by unassigned pharmacy | Denied or silently narrowed, but never returns unassigned data. |
| Technician calls finance dashboard | Denied. |
| Bookkeeper calls technician workflow update | Denied. |
| Tenant admin assigns a customer role in own tenant | Allowed and audited. |
| Tenant admin grants `INTERNAL_PLATFORM_ADMIN` | Denied. |
| Owner reads owner dashboard for assigned tenant | Allowed. |
| Store manager reads assigned-store dashboard | Allowed. |
| Store manager reads unassigned-store data | Denied. |
| Pharmacist updates pharmacist-allowed refill status | Allowed. |
| Technician attempts pharmacist-only verification | Denied unless explicit permission allows it. |
| Dashboard response includes raw `RxNo` or `RefillNo` | Test fails. |
| Dashboard response includes raw payload reference/content | Test fails. |
| Internal platform admin accesses internal admin summary | Allowed and audited. |
| Internal platform admin accesses raw payload content through normal API | Denied. |
| JWT contains schema name or restricted source ID | Test fails. |
| Role assignment changes while old token exists | Sensitive action requires refresh or re-check. |

## 18. Implementation Checklist

Every new API or service must define:

- Principal type: user, internal admin, or service.
- Required permission code.
- Allowed roles.
- Tenant scope rule.
- Pharmacy scope rule.
- Data class touched.
- Allowed fields returned.
- Write/state transition rules.
- Audit requirement.
- Tests for allowed and denied access.

Use this checklist during pull request review:

- Does the API check JWT and current user context?
- Does it resolve tenant schema server-side?
- Does it intersect pharmacy filters with assigned pharmacies?
- Does it check role permission before querying?
- Does it avoid returning restricted fields?
- Does it audit sensitive reads/writes?
- Does it include negative RBAC tests?
- Does it avoid relying only on frontend hiding?

## 19. Decisions For Phase 1

These are current standards unless changed by product/security review.

| Decision | Current standard |
| --- | --- |
| Phase 1 auth | Username/password login with backend-issued JWT bearer token. |
| Tenant isolation | One PostgreSQL schema per tenant for tenant-owned pharmacy data. |
| Control plane | Shared non-PHI control-plane schema for users, tenant registry, role assignments, and permission audit. |
| Dashboard roles | Starter dashboards for all customer-facing roles in Phase 1. |
| Tenant admin | Can manage users/settings inside own tenant, but does not automatically get all business dashboards. |
| Restricted Rx refs | Real `RxNo` and `RefillNo` only in `source_rx_reference`, not dashboards. |
| Raw payload archive | Separate restricted archive, not merged into `ingestion_event`. |
| Service access | Receiver, processor, enrichment worker, and data platform service use service permissions, not human roles. |
| Email | Disabled by default. Enable only through admin-approved settings. |

## 20. Open Items For Product/Security Review

These do not block Phase 1 starter RBAC, but they should be confirmed before production or Phase 2 workflow expansion.

| Item | Why it matters |
| --- | --- |
| Patient identifiers in operational refill queues | Phase 2 refill workflows may eventually need patient-identifying context. This requires a compliance-approved design before implementation. |
| Technician clinical verification limits | Pharmacies may differ on which technician actions are allowed. Status permissions should be configurable before production workflow rollout. |
| Export permissions | Bulk export increases data leakage risk. Export should be a separate permission, not automatically included in read roles. |
| Break-glass production access | Internal emergency access should be separate from `INTERNAL_PLATFORM_ADMIN`. |
| Data engineering role | If the app needs an internal data engineering role, define it separately with safe-data-only permissions. |
| External doctor email rules | Sender identity, templates, unsubscribe/communication rules, and audit behavior must be approved before enabling outbound email. |
