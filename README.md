# AnalyticalRx Documentation

This repository contains the product requirements, architecture, data model, integration designs, and operating guides for AnalyticalRx.

## New to the team?

Start with the [New Teammate Onboarding Guide](team-setup/new-teammate-onboarding.md). It explains the product, recommends a short reading order, maps the code repositories, and points to the right local setup instructions.

Use the [documentation map](documentation-map.md) to find shared setup and each repository's run instructions. Complete shared AWS/database setup only if your task needs it,
then follow the README in your assigned repository.

Use [index.html](index.html) as the visual catalog for the full set of design and reference materials. It is a directory of documents, not a required reading sequence.

## Which source should I trust?

| Question | Use this source |
| --- | --- |
| What are we building, and what belongs in each phase? | [Product Requirements Document](prd/product-requirements-document.md) |
| What is implemented now? | The relevant application repository's code, tests, and README. |
| What should I work on next? | The live AnalyticalRx GitHub Project and the issue assigned to you. |
| What is the current backend API contract? | [Implemented backend API contract](https://github.com/analyticalrx/data-platform/blob/main/docs/ui-api-contract.md). The broader [UI API Contracts design](architecture/ui-api-contracts.md) is a draft for planned APIs. |
| How should a system or data boundary work? | The applicable architecture, ingestion, RBAC, or database design, noting its status and date. |
| What changed when the development proxy was removed? | [Developer connection changes](operations/development-proxy-retirement.md). |
| How do I connect to the Phase 1 dev database? | [Developer database guide](operations/teammate-rds-pgadmin-access-guide.md): daily Windows/Linux tunnel commands, saved pgAdmin updates, backend settings, and access outside working hours. See the [Database Operations Guide](operations/phase1-aws-postgres-dev-database.md) for AWS details. |

The product PRD describes intended scope; it does not mean every feature is already implemented. Planning snapshots and task drafts are not a live project status report.

## Run a repository

| Repository | Maintained setup instructions |
| --- | --- |
| Spring Boot backend | [Data Platform local setup](https://github.com/analyticalrx/data-platform/blob/main/README.md#local-setup) |
| Next.js frontend | [AnalyticalRx UI local setup](https://github.com/analyticalrx/analyticalrx-ui/blob/main/README.md#run-locally) |
| Webhook receiver | [Receiver Lambda README](https://github.com/analyticalrx/primerx-receiver-lambda-service/blob/main/README.md) |
| Webhook processor | [Processor Lambda README](https://github.com/analyticalrx/primerx-processing-lambda-service/blob/main/README.md) |
| Synthetic webhook simulator | [Simulator README](https://github.com/analyticalrx/webhook-test-simulator/blob/main/README.md) |

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

Follow the [documentation ownership rules](documentation-map.md#where-to-update-documentation).
Keep repository run instructions beside the code and link shared setup from here.

When changing a shared API, schema, security boundary, or product requirement, update the relevant source document and link the change to its GitHub issue. Add a review date to progress snapshots, and label proposed behavior separately from implemented behavior.
