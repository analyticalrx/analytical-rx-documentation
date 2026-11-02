# AnalyticalRx Documentation

This repository contains the product requirements, architecture, data model, integration designs, and operating guides for AnalyticalRx.

## New to the team?

Start with the [New Teammate Onboarding Guide](team-setup/new-teammate-onboarding.md). It explains the product, recommends a short reading order, maps the code repositories, and points to the right local setup instructions.

Use [index.html](index.html) as the visual catalog for the full set of design and reference materials. It is a directory of documents, not a required reading sequence.

## Which source should I trust?

| Question | Use this source |
| --- | --- |
| What are we building, and what belongs in each phase? | [Product Requirements Document](prd/product-requirements-document.md) |
| What is implemented now? | The relevant application repository's code, tests, and README. |
| What should I work on next? | The live AnalyticalRx GitHub Project and the issue assigned to you. |
| What is the current backend API contract? | `data-platform/docs/ui-api-contract.md` in the Data Platform repository. The broader [UI API Contracts design](architecture/ui-api-contracts.md) is a draft for planned APIs. |
| How should a system or data boundary work? | The applicable architecture, ingestion, RBAC, or database design, noting its status and date. |
| How do I connect to the Phase 1 dev database? | [Teammate RDS/pgAdmin Guide](operations/teammate-rds-pgadmin-access-guide.md) and [Database Operations Guide](operations/phase1-aws-postgres-dev-database.md). |

The product PRD describes intended scope; it does not mean every feature is already implemented. Planning snapshots and task drafts are not a live project status report.

## Browse by subject

- `prd/` - product scope and dated PRD review.
- `architecture/` - system, service, API, and access-control designs.
- `ingestion/` - PrimeRx webhook and batch/API data-flow designs.
- `database/` and `schemas/` - schema guides, SQL definitions, migrations, and ERD references.
- `operations/` - AWS database access, local tunnel, lifecycle, and IAM material.
- `team-setup/` - onboarding and teammate setup resources.
- `diagrams/` - editable D2 sources and rendered SVG diagrams.
- `airtable/` - archived product research. Airtable is a reference for product intent, not a live dependency or schema source.
- `project-tasks/` - task description drafts and planning snapshots. Check GitHub for current assignment and status.
- `presentations/` - stakeholder and client context, not engineering acceptance criteria.

## Keeping docs useful

When changing a shared API, schema, security boundary, or product requirement, update the relevant source document and link the change to its GitHub issue. Add a review date to progress snapshots, and label proposed behavior separately from implemented behavior.
