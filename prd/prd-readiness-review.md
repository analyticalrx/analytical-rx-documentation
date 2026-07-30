# AnalyticalRx PRD Readiness Review

Created: July 30, 2026  
Reviewed document: `prd/product-requirements-document.md`

## 1. Review Decision

The current PRD is professional enough for stakeholder alignment and client-facing explanation. It clearly explains the problem, background, product goals, phase boundaries, Phase 1 commitments, and Phase 2 direction.

Earlier HTML PRD drafts were useful for stakeholder alignment, but maintaining multiple PRD versions creates drift. Engineering should use the unified Markdown PRD and GitHub issues for implementation detail.

## 2. PRD Scorecard

| Area | Status | Review Notes | Required Action |
| --- | --- | --- | --- |
| Problem statement | Strong | The core question is clear: why each pharmacy is growing, flat, or declining, and what should the team do next. | Keep as-is. Add measurable success criteria near the top. |
| Background and Airtable context | Strong | Airtable is correctly positioned as product intent, not a database to copy. | Keep as-is. Link to Airtable reference docs for details. |
| Phase 1 scope | Mostly ready | Phase 1 is clear: ingestion, canonical storage, RBAC foundation, audit visibility, and starter dashboards. | Add implementation user stories and dashboard-level acceptance criteria. |
| Phase 2 scope | Needs structure | Direction is strong but broad: doctor CRM, automation, refill queues, alerts, optional emails, and dashboard enhancements. | Use `product-requirements-document.md` as the delivery version and keep Phase 2 under the same PRD. |
| Success metrics | Missing | The PRD describes outcomes, but not measurable KPIs. | Confirm target values with product owner. Until confirmed, keep targets as proposed/TBD. |
| User stories | Missing | Roles are defined, but requirements are not consistently written as user stories. | Add role-based stories for dashboards, refill queue, doctor CRM, admin workflows, and audit visibility. |
| Technical specifications | Split across docs | Architecture, schema, ingestion, and GitHub issues contain the technical detail. | PRD should summarize the implementation contract and link to deep docs. |
| Risks and dependencies | Partial | Assumptions are listed, but not a prioritized risk table. | Add risks for data availability, BAA/PHI, vendor pricing, workflow trust, and email approval. |

## 3. What Is Working Well

- The document has a good reader flow: problem, background, goals, phases, phase details, appendices.
- Phase 1 is correctly marked as in progress.
- Starter dashboards for all roles are correctly included in Phase 1.
- Phase 2 is correctly framed as workflow execution and automation, not first-time dashboard creation.
- Airtable is treated as a reference for intent, not a migration source.
- Advanced analytics and forecasting are not overpromised in Phase 1 or Phase 2.
- Privacy direction is sound: dashboards should avoid direct patient identifiers, while restricted source references stay in operational storage.

## 4. Main Implementation Gaps

| Gap | Why It Matters | Recommended Fix |
| --- | --- | --- |
| No measurable KPI section | The team cannot objectively know whether a phase is successful. | Add 3-5 phase-level KPIs with current targets marked as proposed/TBD. |
| User stories are implicit | Engineering and QA need role-specific behavior to implement and test. | Add `As a user...` stories with acceptance criteria. |
| Phase 2 is too broad as one block | Doctor CRM, automation, refill queues, alerts, and dashboard upgrades should not ship as one undivided release. | Split Phase 2 into smaller release slices. |
| Data dependencies need gates | Refill queues and workflow automation depend on reliable source fields and role/store mappings. | Add data-readiness gates before each workflow is enabled. |
| Email behavior needs policy language | Outbound communication can create compliance, consent, and reputational risk. | Keep email optional, admin-enabled, audited, and disabled by default until approved. |
| Testing requirements are not explicit | Dashboard, workflow, and RBAC behavior can regress without testable requirements. | Add tests for RBAC, data freshness, workflow run output, audit records, and empty/error states. |

## 5. Recommended PRD Changes

1. Keep the unified Markdown PRD as the product narrative and implementation source of truth.
2. Add a concise success criteria section near the top of the main PRD.
3. Use the unified Markdown PRD for engineering handoff.
4. Use issue-level acceptance criteria for execution detail.
5. Convert confirmed Phase 2 stories into GitHub issues only after Phase 1 data availability is proven.
6. Keep unknown timing, pricing, and KPI targets as `TBD` instead of creating false commitments.

## 6. Proposed Success Criteria To Confirm

These are proposed targets, not final commitments.

| Phase | Proposed Success Criteria |
| --- | --- |
| Phase 1 | PrimeRx/Micro Merchant events or files are ingested into the canonical model for at least one pharmacy. |
| Phase 1 | Starter dashboards exist for all defined roles. |
| Phase 1 | Normal dashboard users cannot access restricted raw payloads, real Rx numbers, refill numbers, or direct patient identifiers. |
| Phase 1 | Import/audit visibility shows received, processed, failed, duplicate, skipped, and enrichment-needed records. |
| Phase 2 | At least one predefined workflow can run on schedule and create visible queue/task/alert output. |
| Phase 2 | Daily refill queue prepares today's items and upcoming refill suggestions without manual source-system lookup. |
| Phase 2 | Doctor CRM supports offices, visits, pitch history, follow-ups, outcomes, and next actions. |

## 7. Clarifying Questions

These should be answered before calling the PRD final for implementation planning.

- What is the target Phase 1 completion date?
- What is the target Phase 2 start date?
- Which measurable business KPI matters most first: reduced manual reporting time, dashboard adoption, fewer missed refills, faster follow-up, revenue visibility, or something else?
- Which Phase 2 release should come first if capacity is limited: Doctor CRM, refill queue, automation foundation, or alerts?
- Which users will pilot Phase 2 workflows first?
- What email behavior is approved for the first release: no emails, internal emails only, draft doctor emails, or admin-approved outbound emails?

## 8. Team Handoff Guidance

Recommended reading path for the team:

1. Unified Markdown PRD: `prd/product-requirements-document.md`
2. PRD readiness review: `prd/prd-readiness-review.md`
3. Schema review guide: `database/canonical-event-schema-review-guide.html`
4. GitHub issues under the Phase 1 / Phase 2 epic

## 9. Final Review Note

The PRD is clear and professional for explaining direction. For implementation, the team should use the unified Markdown PRD, schema docs, and GitHub issues with concrete acceptance criteria.
