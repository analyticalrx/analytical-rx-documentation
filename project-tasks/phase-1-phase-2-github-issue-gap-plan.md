# Phase 1 / Phase 2 GitHub Issue Gap Plan

This document maps the current PRD against the existing task drafts and identifies what should exist in GitHub Issues.

Current GitHub API status: Codex can authenticate with `GITHUB_TOKEN` and access the `analytical-rx` organization, the `analytical-rx-documentation` repository, and the `Analytical Rx` GitHub Project.

## Issue Creation Completed

The missing Phase 1 and Phase 2 issues were created in GitHub and added to the `Analytical Rx` Project as `Todo`.

The parent epic `#40: Epic: Pharmacy Data Platform And Role-Based Dashboards` was also created in GitHub, added to the project as `Todo`, and configured with native GitHub sub-issue links for issues `#26` through `#39` and `#41`.

| Issue | Project status | Labels |
| --- | --- | --- |
| #40: Epic: Pharmacy Data Platform And Role-Based Dashboards | Todo | `epic`, `data-platform` |
| #26: Define Phase 1 API/SFTP Backfill And Enrichment Plan | Todo | `mvp`, `data-platform` |
| #27: Design Phase 1 Spring Backend Service For RBAC, Dashboard APIs, And PostgreSQL | Todo | `mvp`, `data-platform` |
| #28: Provision Phase 1 AWS PostgreSQL Database And Tenant Schema Template | Todo | `mvp`, `data-platform` |
| #29: Build Spring Boot Core Service Auth And Tenant/Pharmacy RBAC Foundation | Todo | `mvp`, `data-platform` |
| #30: Build Internal Admin Module For User Permissions And Pipeline Audit Views | Todo | `mvp`, `data-platform` |
| #41: Build Phase 1 Frontend Application And Role-Based Dashboard Screens | Todo | `mvp`, `data-platform` |
| #31: Define Phase 1 Role-Level Starter Dashboard Requirements | Todo | `mvp`, `data-platform` |
| #32: Build Dashboard Read Models And APIs For Phase 1 Starter Metrics | Todo | `mvp`, `data-platform` |
| #33: Create Phase 1 Demo And Data Readiness Checklist | Todo | `mvp`, `data-platform` |
| #34: Design Phase 2 Workflow Automation Architecture | Todo | `phase-2`, `workflow` |
| #35: Build Doctor CRM Foundation | Todo | `phase-2`, `crm` |
| #36: Build Internal Scheduling And Follow-Up Tasks | Todo | `phase-2`, `workflow` |
| #37: Build Daily And Upcoming Refill Queue | Todo | `phase-2`, `refill` |
| #38: Build Alerts And Optional Email Notification Foundation | Todo | `phase-2`, `notifications` |
| #39: Enhance Role Dashboards With Workflow Status | Todo | `phase-2`, `dashboard` |

## Project Status Update Completed

The GitHub Project now has a `Backlog` status option. The analytics/data-engineering issues and analytics epic have been moved to `Backlog`.

Live project status after update:

| Issue | Current project status | Reason |
| --- | --- | --- |
| #11: Review Analytics Documentation And Validate Future Data Engineering Direction | Backlog | Data engineering review should wait until Phase 1 ingestion and source availability are clearer. |
| #12: Define Analytics Data Inventory And Source Coverage | Backlog | Needed later for analytics readiness, but not required before Phase 1 ingestion and starter dashboards are live. |
| #13: Define Analytics Data Model | Backlog | Analytics model should wait until the Phase 1 canonical event pipeline and source field coverage are stable. |
| #14: Define Data Quality And Reconciliation Rules | Backlog | Important, but should follow initial ingestion and canonical persistence. |
| #15: Build Revenue Analytics Feature Mart | Backlog | Phase 3-oriented analytics work, not immediate Phase 1 delivery. |
| #16: Build Refill And Adherence Feature Mart | Backlog | Requires stable refill data and PHI-safe tokenization; should wait until Phase 2 refill workflow data shape is clearer. |
| #17: Build Baseline Forecasting Proof Of Concept | Backlog | Forecasting is explicitly future/Phase 3, not Phase 1 or Phase 2 baseline. |
| #21: Epic: Future Analytics Data Engineering Backlog | Backlog | Parent epic for analytics/data-engineering work. |

Issue `#23: Define PrimeRx SFTP Historical And Daily Feed Specification` remains `Todo` because it supports Phase 1 backfill/SFTP planning and should not be treated as future analytics backlog.

## Existing Draft Coverage

The existing webhook pipeline task draft already covers these Phase 1 backend/integration items:

| Existing draft | PRD area covered |
| --- | --- |
| Task 1: Create HLD For MVP Webhook Processing Pipeline | Phase 1 architecture foundation. |
| Task 2: Build AWS API Gateway Webhook Endpoint | Webhook receiver endpoint. |
| Task 3: Build Receiver Lambda For Webhook Intake | Webhook intake and initial validation. |
| Task 4: Create SQS Queue For Webhook Events | Async buffering for webhook processing. |
| Task 5: Build Processor Lambda For Webhook Events | Event processing and PHI minimization. |
| Task 6: Add End-To-End MVP Test For Webhook Pipeline | Pipeline verification. |
| Task 7: Define MVP Storage Architecture For Processed Webhook Events | Storage boundary and canonical destination. |
| Task 8: Define Webhook Audit And Idempotency Schema | Import/audit/idempotency foundation. |
| Task 9: Define Canonical Processed Webhook Event Schema | Canonical event model. |
| Task 10: Update Processor Lambda To Persist Audit And Canonical Event Records | Persistence into audit/canonical tables. |

## Phase 1 Issues Created

These issues now exist in GitHub.

### #26: Define PrimeRx API/SFTP Backfill And Enrichment Plan

**Phase:** Phase 1  
**Type:** Integration planning  
**Labels:** `mvp`, `data-platform`

**Description:**  
Define how API and SFTP data will support Phase 1 historical backfill, missing field enrichment, and reconciliation. This should translate confirmed PrimeRx/Micro Merchant capabilities into a concrete Phase 1 data plan.

**Scope:**
- Identify which Phase 1 dashboard fields come from webhooks, API, SFTP, or manual/business inputs.
- Define minimum historical backfill needed for starter dashboards.
- Define how missed webhook events or incomplete webhook payloads are enriched.
- Define what SFTP files/specifications we need to request from PrimeRx.
- Document what fields are required for Phase 2 refill workflow readiness, even if not implemented in Phase 1.

**Acceptance criteria:**
- [ ] Source-to-field mapping exists for Phase 1 dashboard needs.
- [ ] API enrichment use cases are documented.
- [ ] SFTP backfill use cases are documented.
- [ ] Required SFTP field specification draft is created.
- [ ] Known gaps are documented without blocking Phase 1.

### #27: Design Phase 1 Spring Backend Service For RBAC, Dashboard APIs, And PostgreSQL

**Phase:** Phase 1  
**Type:** Architecture / backend service design  
**Labels:** `mvp`, `data-platform`

**Description:**  
Design the Phase 1 application service that powers role-based access, starter dashboard APIs, business read models, and PostgreSQL access.

**Technology Direction:**
- Java Spring Boot service.
- Container image deployed in AWS.
- Username/password login with backend-issued JWT bearer tokens.
- JWT tokens include tenant-scoped role claims, but not PHI, raw source identifiers, or database schema names.
- PostgreSQL/RDS as the application database.
- One PostgreSQL schema per tenant for tenant-owned data.
- Role-based access, tenant schema routing, and pharmacy scoping handled in the service layer.

**Scope:**
- Define service boundaries and responsibilities.
- Define module structure for authentication, authorization, tenants/pharmacies, dashboard APIs, audit views, and database access.
- Define JWT bearer token claims, expiry, signing secret, and role-change behavior.
- Define RBAC model for Phase 1 roles.
- Define dashboard API groups for all Phase 1 starter dashboards.
- Define how authenticated tenant context maps to the active tenant schema.
- Define how the service reads canonical event data without exposing restricted raw/source payloads.
- Define container build, runtime configuration, secrets, logging, health checks, and deployment approach.

**Acceptance criteria:**
- [ ] Service boundary is clearly documented.
- [ ] Spring Boot is confirmed or a clearly justified alternative is documented.
- [ ] JWT bearer auth model is documented.
- [ ] RBAC model covers all Phase 1 roles.
- [ ] Tenant schema routing model is documented.
- [ ] Starter dashboard API groups are listed.
- [ ] Restricted data access rules are documented.
- [ ] PostgreSQL connection, migration, and credential strategy is documented.
- [ ] AWS container deployment path is documented.

### #28: Provision Phase 1 AWS PostgreSQL Database And Tenant Schema Template

**Phase:** Phase 1  
**Type:** Infrastructure/database  
**Labels:** `mvp`, `data-platform`

**Description:**  
Create the Phase 1 PostgreSQL/RDS database environment and apply the approved tenant-schema canonical event model, including tenant, pharmacy, restricted source reference, audit, drug, payer, payment, and canonical event tables.

**Scope:**
- Create or configure the Phase 1 AWS database environment.
- Create the tenant schema template and document how new tenant schemas will be provisioned.
- Apply the current schema and migrations inside the target tenant schema.
- Verify foreign keys, indexes, and tenant schema ownership.
- Confirm database credentials and access boundaries for receiver/processor services.
- Confirm that restricted source tables are not exposed to dashboard queries.

**Acceptance criteria:**
- [ ] Database exists in the agreed AWS environment.
- [ ] Current canonical tenant schema applies successfully.
- [ ] Migration scripts run cleanly inside the target tenant schema.
- [ ] New tenant provisioning path is documented.
- [ ] Processor Lambda can connect using least-necessary credentials.
- [ ] Dashboard/query role cannot access restricted raw/source tables.

### #29: Build Spring Boot Core Service Auth And Tenant/Pharmacy RBAC Foundation

**Phase:** Phase 1  
**Type:** Backend/security  
**Labels:** `mvp`, `data-platform`

**Description:**  
Build the Phase 1 Spring Boot core service foundation and authentication module so dashboards and workflow data are scoped by tenant schema, pharmacy, and role.

**Scope:**
- Define Phase 1 roles: owner/executive, store manager, pharmacist, technician, bookkeeper/finance, compliance/admin, business development, internal admin.
- Implement username/password login that returns a signed JWT bearer access token.
- Include tenant-scoped role claims in the JWT without including PHI, raw `RxNo`, raw `RefillNo`, raw payload references, or database schema names.
- Validate JWT signature, issuer, audience, expiry, and permission version on protected APIs.
- Define tenant and pharmacy assignment rules.
- Implement or document how APIs choose the tenant schema from authenticated tenant context and enforce pharmacy/role scope.
- Define restricted-source access rules for backend-only tables.
- Provide seed/admin setup path for the first customer.

**Acceptance criteria:**
- [ ] Phase 1 roles are defined in code/config.
- [ ] Login returns a signed JWT bearer token with tenant-scoped role claims.
- [ ] Protected APIs require a valid JWT bearer token.
- [ ] Users can be assigned to tenant and pharmacy scope.
- [ ] Tenant schema is selected server-side from authenticated tenant context.
- [ ] Tenant schema is resolved from trusted control-plane data, not from a JWT schema claim or request parameter.
- [ ] Dashboard APIs enforce scope.
- [ ] Restricted raw/source data is not available to normal roles.
- [ ] Basic admin setup path exists.

### #30: Build Internal Admin Module For User Permissions And Pipeline Audit Views

**Phase:** Phase 1  
**Type:** Backend/frontend  
**Labels:** `mvp`, `data-platform`

**Description:**  
Build an internal admin module inside the Phase 1 Spring core service for AnalyticalRx platform administrators to manage user access across tenants/pharmacies and review pipeline/import audit activity.

This is not a separate application. It should be part of the same core service and frontend experience, restricted to internal/admin users.

**Scope:**
- Show all tenants and pharmacies available to an internal platform admin.
- Show users and their assigned roles across tenants and pharmacies.
- Allow authorized internal admins to review and manage user-to-tenant, user-to-pharmacy, and role assignments.
- Track who changed permissions, what changed, and when.
- Show pipeline/import audit activity across tenants for internal admins.
- Show tenant-scoped audit activity for tenant admins/support users.
- Show event/file/API processing counts by status: received, accepted, rejected, retried, enriched, skipped, failed, persisted.
- Show recent failures and retryable errors without exposing PHI/raw payloads in the normal UI.

**Acceptance criteria:**
- [ ] Internal platform admin can list tenants, pharmacies, users, and role assignments.
- [ ] Internal platform admin can update user role assignments where authorized.
- [ ] Tenant admin cannot access another tenant's users, schema, pharmacies, or audit records.
- [ ] Permission changes are recorded with actor, target user, tenant, pharmacy, old/new values, timestamp, and reason/comment where provided.
- [ ] Authorized admin/support user can see recent pipeline/import activity.
- [ ] Status counts and failures are visible by tenant, pharmacy, source type, and date range.
- [ ] PHI/raw payload content is not shown in the normal audit UI.
- [ ] Failed/retryable items are identifiable.
- [ ] All admin actions are protected by RBAC and auditable.

### #41: Build Phase 1 Frontend Application And Role-Based Dashboard Screens

**Phase:** Phase 1  
**Type:** Frontend  
**Labels:** `mvp`, `data-platform`

**Description:**  
Build the Phase 1 frontend application foundation that users will interact with for role-based dashboards, pipeline visibility, and later workflow features.

This issue owns frontend implementation. It should use the dashboard requirements defined in #31 and consume the backend APIs built in #32.

**Scope:**
- Choose and document the frontend framework and project structure.
- Create the main authenticated layout for AnalyticalRx.
- Add role-aware navigation for owner, store manager, pharmacist/technician, bookkeeper/finance, compliance/admin, and business development users.
- Create shared UI components for dashboard pages, metric panels, tables, filters, status badges, empty states, loading states, and error states.
- Add route-level access checks so users only see pages allowed for their role and tenant/pharmacy access.
- Define API client patterns for calling the Phase 1 backend service.
- Build starter dashboard screens for all Phase 1 roles.
- Add an entry point for the Phase 1 internal admin and pipeline audit module from #30.
- Keep restricted raw payload / PHI screens out of normal dashboard navigation.

**Acceptance criteria:**
- [ ] A frontend application can be started locally by the team with documented commands.
- [ ] The application has a consistent main layout and navigation model.
- [ ] Role-based routes and navigation behavior are defined for all Phase 1 roles.
- [ ] Shared dashboard UI components exist and can be reused by the dashboard implementation issue.
- [ ] API client structure is ready for backend integration.
- [ ] Loading, empty, and error states are represented in the shared UI patterns.
- [ ] Restricted raw data is not reachable from normal role dashboard navigation.

### #31: Define Phase 1 Role-Level Starter Dashboard Requirements

**Phase:** Phase 1  
**Type:** Product/design
**Labels:** `mvp`, `data-platform`

**Description:**  
Define the Phase 1 role-level starter dashboard requirements so backend and frontend teams know exactly what each dashboard must show first.

This issue is a product/design definition task. It should not build backend APIs or frontend screens. Backend dashboard APIs are covered by #32. Frontend dashboard screens are covered by #41.

**Scope:**
- Define each Phase 1 dashboard role and its starter purpose.
- Define the minimum metrics, tables, filters, and empty states needed for each role.
- Define which data can come from webhook/API/SFTP-backed canonical records in Phase 1.
- Define which dashboard elements can be placeholders until real source data is available.
- Define role and pharmacy visibility rules at a product level.

**Acceptance criteria:**
- [ ] Each Phase 1 role has a documented starter dashboard definition.
- [ ] Each dashboard has a minimum list of summary cards, tables/lists, filters, and states.
- [ ] Role and pharmacy visibility expectations are documented.
- [ ] Placeholder sections are clearly marked so the team does not overbuild Phase 1.
- [ ] Backend API work can proceed in #32 without guessing dashboard requirements.
- [ ] Frontend screen work can proceed in #41 without guessing dashboard layout/content intent.

### #32: Build Dashboard Read Models And APIs For Phase 1 Starter Metrics

**Phase:** Phase 1  
**Type:** Backend/API  
**Labels:** `mvp`, `data-platform`

**Description:**  
Create backend query/read models that provide stable data for Phase 1 starter dashboards without making frontend components query raw PrimeRx data directly.

This issue owns backend read models and API contracts only. It should implement the dashboard requirements defined in #31 and provide stable APIs for the frontend work in #41.

**Scope:**
- Owner/company overview read model.
- Store overview read model.
- Daily sales/KPI read model.
- Finance starter read model.
- Compliance/document status read model.
- Task/business-development starter read model where data exists.
- Tenant schema selection based on authenticated tenant context.

**Acceptance criteria:**
- [ ] Dashboard APIs do not depend on raw PrimeRx payload shape.
- [ ] Dashboard APIs enforce tenant/pharmacy/role access.
- [ ] Dashboard APIs select tenant schema server-side and never trust a schema value from request input.
- [ ] APIs handle missing source fields gracefully.
- [ ] APIs are documented for frontend use.
- [ ] APIs support initial demo data and real canonical records.

### #33: Create Phase 1 Demo/Data Readiness Checklist

**Phase:** Phase 1  
**Type:** QA/product  
**Labels:** `mvp`, `data-platform`

**Description:**  
Create a checklist that defines what must be true before Phase 1 can be shown as a working product foundation.

**Scope:**
- Ingestion path working.
- Canonical persistence working.
- Audit view working.
- Starter dashboards working for all roles.
- Role access verified.
- Known gaps documented.
- Synthetic/test webhook data supported.

**Acceptance criteria:**
- [ ] Checklist exists and is reviewed by engineering/product.
- [ ] Demo data path is defined.
- [ ] Required Phase 1 dashboard views are listed.
- [ ] Required API/SFTP/vendor gaps are listed.
- [ ] Security/PHI review items are listed.

## Phase 2 Issues Created

These have been created as planned Phase 2 issues. They should remain `Todo` until the team is ready to actively design or implement Phase 2.

### #34: Design Phase 2 Workflow Automation Architecture

**Phase:** Phase 2  
**Type:** Architecture/product  
**Labels:** `phase-2`, `workflow`

**Description:**  
Design the automation component that will run predefined workflows, create queues/tasks/alerts, support optional emails, and record workflow audit status.

**Acceptance criteria:**
- [ ] Predefined workflow model is documented.
- [ ] Workflow run/audit status model is documented.
- [ ] Admin enable/disable behavior is documented.
- [ ] Role access behavior is documented.
- [ ] Email and alert behavior is documented.

### #35: Build Doctor CRM Foundation

**Phase:** Phase 2  
**Type:** Product/frontend/backend  
**Labels:** `phase-2`, `crm`

**Description:**  
Build the Doctor CRM module for doctor offices, visits, pitch history, follow-ups, relationship status, assigned owners, outcomes, and next actions.

**Acceptance criteria:**
- [ ] Doctor office records can be created and viewed.
- [ ] Visit history and pitch history can be recorded.
- [ ] Follow-ups can be scheduled.
- [ ] Relationship status can be tracked.
- [ ] Business development dashboard can show CRM activity.

### #36: Build Internal Scheduling And Follow-Up Tasks

**Phase:** Phase 2  
**Type:** Workflow/product  
**Labels:** `phase-2`, `workflow`

**Description:**  
Build internal scheduling for doctor visits, calls, follow-up tasks, refill workflow tasks, and reminders.

**Acceptance criteria:**
- [ ] Users can schedule internal follow-ups.
- [ ] Follow-ups appear in role dashboards/queues.
- [ ] Overdue follow-ups are visible.
- [ ] Scheduling respects tenant/pharmacy/role access.

### #37: Build Daily And Upcoming Refill Queue

**Phase:** Phase 2  
**Type:** Workflow/product  
**Labels:** `phase-2`, `refill`

**Description:**  
Build the refill workflow that prepares today's refill queue and upcoming refill suggestions for pharmacists and technicians.

**Acceptance criteria:**
- [ ] Today's refill queue is generated.
- [ ] Upcoming refill queue supports configurable 3-day/7-day style windows.
- [ ] Pharmacist and technician roles can view permitted queue items.
- [ ] Authorized users can update statuses.
- [ ] Blocked/overdue items generate alerts.

### #38: Build Alerts And Optional Email Notification Foundation

**Phase:** Phase 2  
**Type:** Workflow/notifications  
**Labels:** `phase-2`, `notifications`

**Description:**  
Build in-app alerts as baseline and optional email alerts for internal workflow notifications. Doctor outreach email sending must remain disabled by default and admin-enabled only.

**Acceptance criteria:**
- [ ] In-app alerts can be generated by workflows.
- [ ] Internal email alerts can be enabled/disabled by admin.
- [ ] Doctor outreach emails are disabled by default.
- [ ] Email attempts are audited.
- [ ] Failed notifications are visible to admin/support users.

### #39: Enhance Role Dashboards With Workflow Status

**Phase:** Phase 2  
**Type:** Frontend/product  
**Labels:** `phase-2`, `dashboard`

**Description:**  
Enhance Phase 1 dashboards with workflow status, queue completion, alerts, CRM activity, overdue work, blocked items, and automation health.

**Acceptance criteria:**
- [ ] Owner dashboard shows workflow/CRM summary.
- [ ] Store manager dashboard shows store workload and blocked items.
- [ ] Pharmacist/technician dashboard shows refill queue status.
- [ ] Business development dashboard shows doctor CRM follow-ups and pitch context.
- [ ] Admin dashboard shows automation health and settings.

## Active Epic Structure

| Epic | Child issues |
| --- | --- |
| #40: Pharmacy Data Platform And Role-Based Dashboards | #26 through #39 and #41 |
| Phase 1 - Data Foundation And Starter Dashboards | Existing #1 through #10, #23, #26 through #33, and #41. Tenant-owned database tables use one schema per tenant. |
| Phase 2 - Workflow Automation And Doctor CRM | #34 through #39 |
| Backlog - Data Engineering And Analytics | #11 through #17 and #21 |
