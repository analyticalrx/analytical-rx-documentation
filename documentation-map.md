# Documentation map and ownership

Reviewed: 2026-11-02

Start with the [team onboarding guide](team-setup/new-teammate-onboarding.md).
Complete [shared database access](operations/teammate-rds-pgadmin-access-guide.md)
only when your assignment needs it, then follow the README of your assigned code
repository. This catalog links to the maintained document for each topic.

## Shared setup and system knowledge

These documents are maintained in `analytical-rx-documentation` by contributors
responsible for the shared platform, product, or integration being changed.

| Need | Maintained document |
| --- | --- |
| Understand the product and phases | [Product requirements](prd/product-requirements-document.md) |
| Join the team and find your repository | [New teammate onboarding](team-setup/new-teammate-onboarding.md) |
| Get approved AWS access and connect pgAdmin | [Developer database guide](operations/teammate-rds-pgadmin-access-guide.md) |
| Understand the database schedule and access outside working hours | [Development schedule](operations/dev-schedule/README.md) |
| Understand the new direct SSM connection | [Development proxy retirement](operations/development-proxy-retirement.md) |
| Inspect AWS database resources and access rules | [Database operations](operations/phase1-aws-postgres-dev-database.md) |
| Understand service responsibilities | [Data Platform service design](architecture/data-platform-service-design.md) |
| Understand tenant and role boundaries | [RBAC standard](architecture/role-based-access-control-standard.md) |
| Understand shared database design and baseline SQL | [Schema overview](database/phase1-database-schema-overview.md), [control-plane SQL](schemas/control_plane_schema.sql), [canonical-event SQL](schemas/mvp_canonical_event_schema.sql) |
| Understand webhook processing | [Webhook pipeline](ingestion/webhook-processing-pipeline.html) |
| Find planned API behavior | [UI API design draft](architecture/ui-api-contracts.md) |
| Browse diagrams and other references | [Visual documentation index](index.html) |

Shared SQL describes the baseline/design. Applied service migrations live with
the service that changes the database; consult those migrations and the current
code for deployed schema behavior. Do not run baseline SQL as an upgrade procedure.

## Run, change, and troubleshoot a repository

Each repository's maintainers update these instructions alongside code changes.
Runtime versions, environment-variable names, start/test/build commands, local
troubleshooting, and service-specific migrations belong beside that code.

| Repository | Start or build | Further reference |
| --- | --- | --- |
| Data Platform backend | [Backend README](https://github.com/analyticalrx/data-platform/blob/main/README.md#local-setup) | [Backend docs](https://github.com/analyticalrx/data-platform/blob/main/docs/README.md), [implemented API contract](https://github.com/analyticalrx/data-platform/blob/main/docs/ui-api-contract.md), [applied ID migration](https://github.com/analyticalrx/data-platform/blob/main/database/bigint-id-migration-plan.md) |
| AnalyticalRx UI | [UI README](https://github.com/analyticalrx/analyticalrx-ui/blob/main/README.md#run-locally) | [UI docs](https://github.com/analyticalrx/analyticalrx-ui/blob/main/docs/README.md) |
| Webhook receiver Lambda | [Receiver README](https://github.com/analyticalrx/primerx-receiver-lambda-service/blob/main/README.md) | Shared [webhook pipeline](ingestion/webhook-processing-pipeline.html) |
| Webhook processor Lambda | [Processor README](https://github.com/analyticalrx/primerx-processing-lambda-service/blob/main/README.md) | Shared [database operations](operations/phase1-aws-postgres-dev-database.md) |
| Synthetic webhook simulator | [Simulator README](https://github.com/analyticalrx/webhook-test-simulator/blob/main/README.md) | Start in dry-run mode using synthetic data |

The implemented API contract belongs in the backend repository so code and its
contract can be reviewed together. The frontend links to that contract. Product
and API design drafts describe intended scope and may include unimplemented work.

## Where to update documentation

| Your change | Update here |
| --- | --- |
| Backend startup, configuration, or troubleshooting | Backend README or backend `docs/` |
| Frontend startup, configuration, or UI behavior | UI README or UI `docs/` |
| Lambda build or runtime settings | That Lambda repository's README/docs |
| Implemented API route, request, response, or permission | Backend implemented API contract; update affected frontend integration notes |
| Applied backend database migration | Backend `database/` and its migration notes; link shared design changes when needed |
| AWS access, database tunnel, secrets setup, or operating schedule | Shared `operations/` guide and its scripts/policies |
| Cross-service architecture, shared schema, RBAC standard, or product scope | Shared architecture/database/PRD document |
| Where a reader should begin | This map and the relevant README/index link |

Maintain the full instructions in one location and link to them from other
repositories. A short prerequisite reminder is useful; copied command sequences
and complete design documents drift. If a shared change affects multiple repos,
link the companion pull requests or commits so reviewers can follow the update.

Keep existing Markdown/HTML formats. When relocating a document, leave a short
pointer at its former Markdown path and update incoming links. Retain dated
snapshots as history with an explicit date/status; GitHub issues and the Project
own current work status. Existing historical versions remain available in Git.
