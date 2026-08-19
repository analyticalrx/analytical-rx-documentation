# AnalyticalRx Product Requirements Document

Created: July 30, 2026  
Status: Draft for product and engineering review  
Primary audience: product owner, engineering, data engineering, security, and implementation leads  
Source context: client documentation, Airtable reverse engineering, PrimeRx/Micro Merchant discovery, ingestion design, canonical schema design, and GitHub issue planning

## 1. Executive Summary

### Problem Statement

Independent multi-pharmacy operators need a reliable way to understand performance across locations and act on operational issues before they become revenue, reimbursement, compliance, or customer-service problems.

Today, useful information is spread across PrimeRx/Micro Merchant, reports, Airtable, manual workflows, and staff follow-up processes. This makes it hard to answer why a pharmacy is growing, flat, or declining, and what each role should do next.

### Proposed Solution

Build AnalyticalRx as a role-based pharmacy operations and analytics platform. Phase 1 creates the data foundation, PrimeRx/Micro Merchant ingestion, canonical storage, restricted data handling, audit visibility, and starter dashboards for all roles. Phase 2 adds workflow execution: Doctor CRM, internal scheduling, predefined automations, daily refill queues, alerts, optional emails, and workflow-enhanced dashboards.

The product should use Airtable as a reference for workflow intent, not as a database to copy one-to-one.

### Success Criteria

Final KPI targets are `TBD` until the product owner confirms timeline, pilot users, and launch expectations. Proposed success criteria:

| Phase | Success Criteria |
| --- | --- |
| Phase 1 | PrimeRx/Micro Merchant data can be received through the agreed webhook, API, or SFTP path for at least one pharmacy. |
| Phase 1 | Incoming events/files are validated, audited, de-duplicated, and persisted into the canonical model. |
| Phase 1 | Starter dashboards exist for owner, store manager, pharmacist/technician, bookkeeper/finance, compliance/admin, and business development roles. |
| Phase 1 | Normal dashboard users cannot access restricted raw payloads, real Rx numbers, refill numbers, direct patient identifiers, or raw vendor responses. |
| Phase 2 | At least one predefined workflow runs on schedule and creates visible queue/task/alert output with audit history. |
| Phase 2 | Pharmacist/technician users can view today's refill queue and upcoming refill suggestions without manually checking source systems first. |
| Phase 2 | Business development users can manage doctor offices, visit history, pitch history, follow-ups, outcomes, and next actions. |

## 2. User Experience & Functionality

### User Personas

| Persona | Primary Need |
| --- | --- |
| Owner / Executive | Cross-store visibility, business trends, operational priorities, workflow completion, doctor outreach progress, and future performance insights. |
| Store Manager | Store-level performance, daily workload, blocked items, staff follow-up, task completion, and store execution status. |
| Pharmacist | Refill readiness, blocked items, verification status, operational exceptions, and workflow alerts for assigned stores. |
| Technician | Assigned work queue, refill preparation items, task updates, and operational follow-through. |
| Bookkeeper / Finance | Revenue, deposits, AR, close status, missing reports, financial exceptions, and finance-related reminders. |
| Compliance / Admin | User access, workflow settings, compliance items, documents, licenses, audit visibility, and administrative controls. |
| Business Development | Doctor outreach, offices, visits, pitch history, relationship status, follow-up dates, outcomes, and next actions. |

### Product Principles

- Build pharmacy-specific workflows from Airtable intent and client operations; do not rebuild a generic Airtable clone.
- Start with predefined workflows before building a fully configurable rule engine.
- Keep human verification in the loop for pharmacy operations; automations prepare work and suggest next steps, but staff verify clinical/operational actions.
- Enforce role-based work access through backend APIs, not only the frontend.
- Keep email optional, admin-enabled, and audited.
- Make automation traceable: every generated task, alert, email, or queue item should have a source, status, and audit trail.

### Phase 1 User Stories

#### Story 1: Data Ingestion And Audit

As an implementation/admin user, I want PrimeRx/Micro Merchant data to be received, validated, queued, processed, and audited so that the team can trust whether source data is flowing into AnalyticalRx.

Acceptance criteria:

- The system can receive data through the agreed Phase 1 path: webhook, API, SFTP, or an approved combination.
- Each received item creates an audit record with source, status, timestamps, and processing result.
- Duplicate, failed, skipped, retryable, processed, and enrichment-needed records are identifiable.
- Failures are visible to authorized admin/support users.
- Raw payload content is not logged or exposed in normal dashboards.

#### Story 2: Canonical Pharmacy Event Storage

As an engineering/data user, I want incoming pharmacy events mapped into a canonical data model so that dashboards and later workflows do not depend directly on raw vendor payload shape.

Acceptance criteria:

- Events are stored with tenant, pharmacy, audit, canonical event type, date/time, status, quantity, payment, drug, and payer relationships where available.
- Tenant-owned data tables are deployed inside one PostgreSQL schema per tenant.
- Drug details are stored in `drug`, linked by `drug_id`, and not duplicated as snapshots in the canonical event row.
- Payer details are stored in `payer` and linked through event payment rows.
- Cash payments use `payment_type = cash` and `payer_id = null`.
- Real `RxNo` and `RefillNo` are stored only in restricted operational tables for API enrichment.

#### Story 3: Role-Based Starter Dashboards

As a role-based user, I want a simple dashboard for my role so that I can see the most relevant starting view without waiting for full automation or advanced analytics.

Acceptance criteria:

- Owner dashboard shows company overview, store comparison, Rx volume, revenue/gross profit where available, trend summary, and priority exceptions.
- Store manager dashboard shows store performance, Rx volume, revenue, targets, status indicators, open issues, and assigned work summary.
- Pharmacist/technician dashboard shows assigned tasks, basic work queue, due items, status, and store-level operational visibility.
- Bookkeeper/finance dashboard shows financial period summary, revenue, close status, AR aging where available, and missing report indicators.
- Compliance/admin dashboard shows expiring documents, licenses, renewal status, compliance items, and basic administrative status.
- Business development dashboard shows doctor office list, visit/follow-up status, relationship stage, and basic outreach tracking where available.
- Empty, loading, partial-data, and source-delay states are handled clearly.

#### Story 4: Role-Based Access

As an admin, I want tenant, pharmacy, and role-based visibility rules so that users only see data they are authorized to access.

Acceptance criteria:

- Users can be assigned to tenant, store/pharmacy, and role scope.
- Phase 1 authentication uses username/password login with backend-issued JWT bearer tokens containing tenant-scoped role claims.
- Dashboard APIs enforce tenant, store, and role scope.
- Backend services select the tenant schema from authenticated tenant context, not from untrusted request parameters.
- The backend validates JWT claims and still resolves tenant schema and sensitive authorization from trusted server-side control-plane data.
- Restricted operational tables are not directly available to normal dashboard users.
- Finance, compliance, and admin views can be restricted by role.
- Access behavior is testable for each defined role.

#### Story 5: API/SFTP Enrichment And Backfill

As an implementation user, I want API/SFTP data to enrich or backfill missing webhook data so that dashboards are not empty or misleading when events are incomplete.

Acceptance criteria:

- The team documents which dashboard fields come from webhooks, API, SFTP, or manual/business inputs.
- API enrichment can update missing safe fields in lookup, canonical, and payment tables.
- API enrichment does not overwrite restricted source references outside the restricted operational boundary.
- SFTP historical/daily feed requirements are documented for PrimeRx implementation.
- Missing fields are visible as data quality/enrichment status instead of silently failing.

### Phase 2 User Stories

#### Story 6: Workflow Foundation

As an admin, I want predefined workflows that can be enabled or disabled by role, store, and user scope so that we can automate common operations without building a generic rule engine.

Acceptance criteria:

- Admin can view available workflow templates.
- Admin can enable or disable a workflow template.
- Admin can assign workflow access by role and store.
- Workflow run history records status, start time, end time, input count, output count, skipped count, and failure count.
- Workflow failures are visible to authorized admin/support users.
- Fully custom customer-built rule creation is not required in Phase 2.

#### Story 7: Internal Scheduling

As a manager or business development user, I want to schedule visits, follow-ups, tasks, and reminders inside AnalyticalRx so that planned work is visible and trackable.

Acceptance criteria:

- User can create a scheduled task with title, owner, due date/time, related store, related doctor office if applicable, priority, status, and notes.
- User can reschedule, complete, skip, or cancel an allowed task.
- Overdue tasks appear in role dashboards or queues.
- Scheduled tasks respect tenant, store, and role access.
- Task change history is auditable.

#### Story 8: Daily Refill Queue

As a pharmacist or technician, I want today's refills and upcoming refill suggestions prepared before I start my day so that I do not manually search for refill work across source systems.

Acceptance criteria:

- A scheduled workflow can prepare today's refill queue.
- The queue can show 3-day and 7-day upcoming refill views, with the default confirmed after Phase 1 data review.
- Queue item statuses include at least `suggested`, `needs_verification`, `ready`, `blocked`, `completed`, and `skipped`.
- Pharmacists can verify, block, ready, complete, or skip items according to role permissions.
- Technicians can update only the statuses allowed by role.
- Queue items link back to safe canonical tokens and restricted references only through backend services.
- Direct patient identifiers are not displayed unless explicitly approved by compliance.

#### Story 9: Doctor CRM

As a business development user, I want to manage doctor offices, visits, pitch history, follow-ups, and outcomes so that I can track what outreach is working and what action should happen next.

Acceptance criteria:

- User can create and edit doctor office profiles.
- User can record visit history with visit date, visitor, purpose, pitch used, objections, outcome, follow-up date, and next action.
- User can view relationship stage and assigned owner.
- User can see overdue follow-ups.
- User can schedule the next visit, call, or internal follow-up.
- Dashboard can show doctor CRM activity and follow-up status.
- Doctor CRM does not require automatic outbound doctor emails in the baseline release.
- Doctor activity is connected to prescription volume or revenue only when data quality supports that relationship.

Doctor CRM views:

| View | Primary Users | Purpose |
| --- | --- | --- |
| Doctor Office List | Business development, owner, manager | Browse and filter offices by stage, store, specialty, owner, next follow-up, and priority. |
| Doctor Profile | Business development, owner, manager | See office details, visit history, pitch history, outcomes, follow-up tasks, and relationship status. |
| Outreach Calendar | Business development, manager | Plan upcoming visits, calls, and optional emails. |
| Pitch Outcome View | Owner, business development | Review which messages or offers appear to create the best response. |
| Follow-Up Queue | Business development | Show today's and upcoming follow-ups, overdue contacts, and recommended next steps. |

#### Story 10: Alerts And Optional Emails

As a role-based user, I want alerts for due work, overdue work, blocked refill items, upcoming visits, and workflow failures so that important operational items are not missed.

Acceptance criteria:

- In-app alerts are supported for due work, overdue work, workflow failures, and blocked items.
- Alerts are scoped by tenant, store, role, and user assignment.
- Users can mark alerts as read or resolved where allowed.
- Alerts link to the relevant queue item, task, doctor record, or workflow run.
- Email sending is disabled by default.
- Internal workflow emails can be enabled by admin settings.
- Outbound doctor emails require explicit approval of sender rules, recipient rules, and template/content behavior.
- No patient-facing email automation is included in Phase 2.

Initial alert types:

- New refill queue prepared for the day.
- Upcoming refills that need verification.
- Blocked refill items requiring manager or pharmacist attention.
- Doctor follow-up due today or overdue.
- Scheduled doctor visit or call reminder.
- Scheduled doctor email ready to review or send.
- Compliance renewal due or overdue.
- Task overdue or blocked.
- Workflow failure, skipped records, or missing source data.

Email policy:

| Email Type | Default Behavior | Requirement |
| --- | --- | --- |
| Internal workflow emails | Optional | Admins can enable email alerts for internal users, such as overdue tasks or workflow failures. |
| Doctor outreach emails | Optional | Admins can enable outbound doctor emails only after confirming approved templates, sender identity, unsubscribe/communication rules if applicable, and customer preference. |
| Email drafts | Recommended first step | The product can prepare draft content or scheduled reminders before enabling auto-send. |
| Automatic sending | Disabled by default | Requires explicit admin enablement and customer/product confirmation. |

#### Story 11: Workflow-Enhanced Dashboards

As an owner or manager, I want role dashboards to show workflow status and completion so that I can understand whether the team is acting on operational priorities.

Acceptance criteria:

- Owner dashboard shows workflow completion, doctor outreach summary, refill readiness, overdue work, and automation health.
- Store manager dashboard shows store workload, blocked items, overdue tasks, and refill queue progress.
- Pharmacist/technician dashboard shows daily refill queue, upcoming refills, blocked items, and task queue.
- Business development dashboard shows doctor CRM follow-ups, pitch history, relationship stage, and overdue outreach.
- Admin dashboard shows automation enablement, workflow run health, alert settings, and audit visibility.

### Non-Goals

Phase 1 does not include:

- Full predictive forecasting or recommendation engine.
- Final payer contract strategy or guaranteed payer profitability interpretation.
- Full doctor outreach CRM automation.
- Full document vault with all compliance workflows.
- Full configurable automation rule builder.
- External SaaS billing, customer onboarding, and multi-customer support operations.
- Displaying direct patient identifiers in normal dashboards unless explicitly approved through compliance review.

Phase 2 does not include:

- Fully configurable customer-built automation rule engine.
- Replacing PrimeRx as the system of record for prescriptions, clinical verification, or dispensing workflow.
- Broad patient CRM inside AnalyticalRx.
- Patient-facing messages or patient outreach automation.
- Unapproved outbound doctor email automation.
- Advanced forecasting or ML recommendation engine.
- External SaaS billing and multi-customer commercialization workflows.

## 3. AI System Requirements

No AI/ML system is required for Phase 1 or Phase 2 baseline.

Future AI features may include workflow recommendations, doctor outreach suggestions, refill risk scoring, payer/drug insights, revenue forecasting, and performance root-cause summaries. These are future-phase concepts and should be scoped in a separate PRD after Phase 1 data quality and Phase 2 workflow data are proven.

### Tool Requirements

Not applicable for Phase 1 or Phase 2 baseline.

### Evaluation Strategy

Not applicable for Phase 1 or Phase 2 baseline.

If future AI features are approved, evaluation must include source traceability, accuracy benchmarks, user review, and privacy checks before production use.

## 4. Technical Specifications

### Architecture Overview

Phase 1 architecture:

1. PrimeRx/Micro Merchant sends events or files through approved webhook, API, or SFTP paths.
2. The ingestion layer validates inbound data, applies idempotency, records audit status, and stores restricted raw source details separately from normal dashboard data.
3. The processing layer maps safe fields into the canonical pharmacy event model.
4. PostgreSQL/RDS stores each tenant's owned data in one tenant-specific schema containing tenant, pharmacy, restricted operational reference, audit, drug, payer, canonical event, and payment tables.
5. The Spring backend service exposes JWT-secured tenant/role-scoped APIs.
6. The frontend application displays role-based starter dashboards and import/audit visibility.

Phase 2 architecture:

1. Phase 1 canonical data, task data, role assignments, and pharmacy mappings become workflow inputs.
2. A workflow component runs predefined scheduled or event-triggered workflows.
3. Workflow runs create queue items, tasks, alerts, optional emails, and workflow audit records.
4. Doctor CRM stores offices, visits, pitch history, follow-ups, outcomes, and next actions.
5. Dashboards show workflow status, due work, blocked items, overdue follow-ups, automation health, and completion progress.

### Core Components

| Component | Phase | Responsibility |
| --- | --- | --- |
| PrimeRx webhook receiver | Phase 1 | Receive events, validate requests, write audit records, and enqueue processing. |
| SQS / queue | Phase 1 | Buffer events for asynchronous processing and retries. |
| Processor Lambda/service | Phase 1 | Validate payloads, suppress PHI, map canonical events, upsert drug/payer/payment data, and update audit status. |
| PostgreSQL/RDS | Phase 1+ | Store canonical data, restricted references, audit records, application data, workflow data, CRM data, and dashboard read data. |
| Spring backend service | Phase 1+ | Provide APIs for RBAC, dashboards, audit views, CRM, workflows, tasks, alerts, and admin settings. |
| Frontend application | Phase 1+ | Provide role-based dashboards, audit views, CRM views, queues, workflow settings, and alerts. |
| Workflow scheduler/component | Phase 2 | Run predefined workflows, create tasks/queues/alerts, and record workflow audit history. |
| Email provider | Phase 2 optional | Send internal or approved outbound emails where explicitly enabled. Provider is `TBD`. |

### Integration Points

| Integration | Use |
| --- | --- |
| PrimeRx/Micro Merchant webhooks | Near-real-time event ingestion and later event-triggered workflow updates where reliable. |
| PrimeRx/Micro Merchant API | Enrichment, missing details, source lookup by restricted Rx/refill references, and backfill where allowed. |
| PrimeRx SFTP feeds | Historical/daily batch transfer, reconciliation, and dashboard/backfill support. |
| AWS API Gateway / Lambda / SQS | Initial serverless ingestion path. |
| AWS RDS PostgreSQL or Aurora PostgreSQL | Primary relational data store. |
| AWS S3 restricted archive | Optional raw payload archive with MVP default retention of 30 days, subject to legal/security review before production. |
| Email service | Optional Phase 2 notifications where enabled and approved. |

### Security & Privacy

- Role-based access must be enforced at API level, not only in the frontend.
- Phase 1 APIs use JWT bearer authentication. JWTs may contain tenant-scoped role claims, but they must not contain PHI, raw source payloads, real Rx numbers, real refill numbers, or database schema names.
- Users only see data for authorized tenant, store, role, and workflow scope.
- The backend must route each request/job to the tenant schema from authenticated tenant context or trusted job configuration. The client must not be allowed to choose arbitrary schemas.
- The backend must resolve tenant schema names from trusted control-plane configuration, not directly from JWT claims or request input.
- Normal dashboards must not expose restricted raw payloads, real Rx numbers, real refill numbers, direct patient identifiers, or raw vendor responses.
- Real `RxNo` and `RefillNo` may be stored only in restricted operational tables because API enrichment needs them.
- Raw payload archive, if enabled, defaults to 30-day MVP retention and must be revisited with legal/security before production.
- Doctor CRM must not store patient details.
- Email sending must be disabled by default and explicitly enabled by admin-approved settings.
- Workflow runs, task changes, alert generation, access events, and email attempts must be auditable.
- Production deployment requires AWS BAA and final security review before handling production PHI.

### Testing Requirements

| Test Area | Required Coverage |
| --- | --- |
| Ingestion | Valid event, invalid event, duplicate event, failed event, retryable event, enrichment-needed event. |
| Canonical mapping | Drug lookup, payer lookup, cash payment, insurance payment, canonical event creation, restricted reference storage. |
| RBAC | Verify each role can access only allowed stores, dashboards, CRM views, queues, alerts, and admin settings. |
| Dashboard UX | Verify loading, empty, partial data, error, and source-delay states. |
| Workflow scheduler | Verify scheduled workflows run once per schedule, create expected outputs, and record audit rows. |
| Refill queue | Verify today's queue, 3-day view, 7-day view, status transitions, blocked items, and skipped items. |
| Doctor CRM | Verify office creation, visit logging, follow-up scheduling, outcome tracking, and dashboard summary. |
| Alerts | Verify alert generation, read/resolved states, links to source work items, and role scoping. |
| Email | Verify disabled-by-default behavior, admin enablement, failure handling, and audit logging. |
| Privacy | Verify dashboards do not expose restricted source identifiers or direct patient identifiers. |

## 5. Risks & Roadmap

### Initial Phase 2 Workflow Templates

| Workflow | Trigger | Output | Primary Users |
| --- | --- | --- | --- |
| Daily Refill Preparation | Daily scheduled run before store opening, plus optional refresh during the day. | Today's refill queue, upcoming refill queue, verification tasks, blocked items, alerts. | Pharmacist, technician, store manager. |
| Doctor Follow-Up Scheduler | Daily scheduled run and manual scheduling from Doctor CRM. | Upcoming visit/call/email tasks, overdue follow-up alerts, pitch history reminders. | Business development, owner, store manager. |
| Doctor Email Reminder | Scheduled date/time if email sending is enabled. | Drafted or sent email, delivery status, follow-up task. | Business development, admin. |
| Compliance Renewal Reminder | Due date window for licenses, documents, SOPs, or compliance items. | Renewal tasks, alerts, escalation if overdue. | Compliance/admin, owner, manager. |
| Task Escalation | Task overdue or blocked beyond configured threshold. | Escalation alert to manager or owner. | Store manager, owner, assigned user. |

### Refill Queue Statuses

| Status | Meaning | Who Can Update |
| --- | --- | --- |
| Suggested | Automation identified the refill as due or upcoming. | System. |
| Verified | Staff reviewed the item and confirmed it should be prepared. | Pharmacist, authorized technician. |
| Preparing | Medication preparation is in progress. | Pharmacist, technician. |
| Ready | Medication is ready for pickup, delivery, or next operational step. | Pharmacist, authorized technician. |
| Blocked | Item cannot proceed because of an issue such as rejection, inventory, prior authorization, or missing information. | Pharmacist, technician, manager. |
| Completed | Work item is finished. | Pharmacist, technician, system if confirmed by source event. |
| Skipped | Item is intentionally not being worked. | Pharmacist, manager. |

### Phased Rollout

| Release | Scope | Exit Criteria |
| --- | --- | --- |
| MVP / Phase 1A | Ingestion foundation, canonical schema, restricted source references, audit visibility, API/SFTP enrichment planning. | At least one pharmacy's source data can enter the canonical model and audit statuses are visible. |
| MVP / Phase 1B | Spring backend service, RBAC foundation, frontend application, role-based starter dashboards. | All defined roles have starter dashboards with scoped, safe data and empty/error states. |
| Phase 2A | Workflow foundation, internal scheduling, tasks, audit records, basic in-app alerts. | Admin can enable a predefined workflow and users can see created tasks/alerts. |
| Phase 2B | Daily refill queue and upcoming refill suggestions. | Pharmacist/technician users can use today's queue and upcoming views with role-safe data. |
| Phase 2C | Doctor CRM and business development follow-up workflow. | Business development users can manage offices, visits, pitch history, follow-ups, and outcomes. |
| Phase 2D | Dashboard enhancements and optional email settings. | Dashboards show workflow status; optional email behavior is admin-controlled and audited. |
| Future Phase 3 | Analytics and decision support. | Payer/drug analysis, root-cause insights, forecasting, and recommendations are scoped after Phase 1 and Phase 2 data are stable. |
| Future Phase 4 | SaaS productization. | Multi-customer onboarding, support, billing, configuration, and SaaS operations are scoped separately. |

### Technical Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| PrimeRx data fields are incomplete or inconsistent | Dashboards and refill workflows may be incomplete. | Use API/SFTP enrichment, show data quality status, and gate workflows by data readiness. |
| Vendor pricing or setup delays | Phase 1 data availability and backfill may be delayed. | Track API/SFTP pricing and field availability as implementation dependencies. |
| Webhook events are delayed or incomplete | Workflow output may not match source system state. | Use SFTP/API reconciliation and show data freshness indicators. |
| RBAC gaps expose restricted data | Compliance and trust risk. | Enforce authorization in backend APIs and test every role. |
| Raw payload retention is legally insufficient | Production compliance risk. | Use 30-day MVP default only until legal/security confirms production retention policy. |
| Users do not trust automation output | Staff may ignore queues and alerts. | Show source, status, reason, and audit trail for each generated item. |
| Email rules are unclear | Unapproved or unwanted communication risk. | Disable email by default; require admin enablement and approval. |
| Workflow scope expands into custom rule builder | Timeline risk. | Keep predefined workflows only in Phase 2. |

### Open Decisions

- Phase 1 target completion date: `TBD`.
- Phase 2 target start date: `TBD`.
- Phase 2 pilot stores/users: `TBD`.
- First Phase 2 release slice priority: proposed `2A + 2B`, confirm.
- Email provider and approved email behavior: `TBD`.
- Default upcoming refill view: proposed 3-day and 7-day options, confirm after Phase 1 data review.
- Final production raw payload retention policy: legal/security review required.
- First doctor pitch categories or campaigns: `TBD`.
- Refill fields that can safely appear in AnalyticalRx without violating the HIPAA-minimized design: `TBD`.
- Queue statuses requiring pharmacist-only permission: `TBD`.
- Queue refresh frequency: once daily, several times per day, or every relevant source event: `TBD`.
- Admin control depth for workflow timing, thresholds, escalation rules, and role access: `TBD`.

### Implementation Handoff

Current Phase 1 work should continue through GitHub issues under the `Epic: Pharmacy Data Platform And Role-Based Dashboards`.

Recommended Phase 2 implementation issues after Phase 1 data readiness is validated:

1. Design Phase 2 workflow data model and audit schema.
2. Build workflow scheduler foundation.
3. Build internal task and scheduling APIs.
4. Build daily refill queue read model and workflow.
5. Build refill queue UI for pharmacist/technician roles.
6. Build Doctor CRM data model and APIs.
7. Build Doctor CRM UI.
8. Build in-app alert foundation.
9. Build optional email settings and audit trail.
10. Enhance role dashboards with workflow status.

Analytics, forecasting, and AI recommendations should remain backlog until Phase 2 workflow data proves useful and stable.
