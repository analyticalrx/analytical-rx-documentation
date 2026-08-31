# AnalyticalRx Role Summary

Status: Draft for team review<br>
Purpose: Simple reference for user types, roles, and what each role means.

## User Types And Roles

| User type | Recommended role(s) | What this user normally does |
| --- | --- | --- |
| Pharmacy group owner | `OWNER_EXECUTIVE` | Reviews overall business performance across pharmacies and checks high-level priorities. |
| Executive operator | `OWNER_EXECUTIVE` | Tracks cross-store performance without necessarily managing users or settings. |
| Customer admin | `TENANT_ADMIN` | Manages users, role assignments, pharmacy access, tenant settings, and workflow settings. |
| Store manager | `STORE_MANAGER` | Manages one or more pharmacy locations, reviews store performance, workload, issues, and tasks. |
| Pharmacist in charge | `PHARMACIST`, optional `STORE_MANAGER` | Handles pharmacist work and may also manage store-level operations if assigned manager access. |
| Pharmacist | `PHARMACIST` | Reviews pharmacist dashboard, refill/work queues, due items, blocked items, and verification work. |
| Technician | `TECHNICIAN` | Works assigned pharmacy tasks and allowed operational queue/status updates. |
| Bookkeeper / finance user | `BOOKKEEPER_FINANCE` | Reviews revenue, payment, close, AR, and finance-related summaries. |
| Compliance officer / admin lead | `COMPLIANCE_ADMIN` | Reviews compliance dashboard, documents, licenses, renewal status, and compliance items. |
| Business development user | `BUSINESS_DEVELOPMENT` | Manages doctor office relationships, visits, pitch history, follow-ups, and outreach tasks. |
| AnalyticalRx platform admin | `INTERNAL_PLATFORM_ADMIN` | Internal AnalyticalRx user who manages platform setup, tenant metadata, users, and safe admin views. |
| Data engineer | No default customer role | Uses approved safe data access for data quality, analytics modeling, and reporting work. |
| QA tester | Role being tested | Uses only the role/scope needed for the test case in a non-production environment. |

## Role Meanings

| Role | Meaning |
| --- | --- |
| `OWNER_EXECUTIVE` | Tenant-level business role for owners and executives who need cross-store dashboards and business summaries. |
| `STORE_MANAGER` | Pharmacy-level operations role for managers responsible for assigned stores, tasks, workload, and operational issues. |
| `PHARMACIST` | Pharmacy-level clinical/operational role for pharmacist queues, refill readiness, blocked items, and verification work. |
| `TECHNICIAN` | Pharmacy-level operations role for technician task queues and allowed non-admin status updates. |
| `BOOKKEEPER_FINANCE` | Finance role for revenue, payment, AR, close, and financial summary dashboards. |
| `COMPLIANCE_ADMIN` | Compliance role for documents, licenses, renewal tracking, compliance items, and compliance/admin dashboard visibility. |
| `BUSINESS_DEVELOPMENT` | Outreach role for doctor CRM, office relationships, visits, follow-ups, pitch history, and next actions. |
| `TENANT_ADMIN` | Customer-side admin role for managing users, roles, pharmacy access, tenant settings, and workflow enablement inside one tenant. |
| `INTERNAL_PLATFORM_ADMIN` | AnalyticalRx internal role for cross-tenant platform administration and safe operational support views. |

## Simple Assignment Rules

- A user can have more than one role when their job needs it.
- Assign roles only for the tenant and pharmacies the user should access.
- `TENANT_ADMIN` does not automatically mean owner, finance, pharmacist, or business development access.
- `OWNER_EXECUTIVE` does not mean platform admin access.
- Normal customer users should not receive `INTERNAL_PLATFORM_ADMIN`.
- Data engineers should use approved safe-data access, not a broad customer dashboard role by default.

Detailed implementation rules are in [AnalyticalRx Role-Based Access Control Standard](role-based-access-control-standard.md).
