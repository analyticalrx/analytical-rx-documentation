# New Teammate Onboarding

Last reviewed: November 2, 2026

Audience: new engineers, data interns, and product contributors

Use this page as the first stop for understanding AnalyticalRx and finding the right project references. It gives the short product story, a recommended reading path, a map of the code repositories, and setup links. It does not replace the detailed technical designs.

## AnalyticalRx in a few minutes

AnalyticalRx is a multi-tenant pharmacy operations and analytics platform. The product is intended to bring pharmacy data together, give each role a safe view of its work and performance, and later support operational workflows.

- **Phase 1** builds the ingestion and data foundation, tenant and role access, audit visibility, and starter dashboards.
- **Phase 2** adds predefined workflows such as refill queues, tasks, doctor follow-ups, and alerts. These depend on source data being available and reliable.
- **Airtable is a product reference.** Its tables and screens help explain past workflow intent; they are not a live database dependency or a schema to copy directly.
- **PrimeRx/Micro Merchant is a source system.** Incoming webhook payloads may contain sensitive patient and prescription data. Keep real PHI out of local fixtures, logs, screenshots, task descriptions, and chat. Use your own approved AWS identity; never use or share someone else's credentials.

The product requirements document is the source for product scope and intended behavior. The live code and tests show what is implemented today. Current work and assignment status belong in the GitHub Project and issues; old task plans in this repository are snapshots, not a live status board.

## Your first day

Once your work email and GitHub account are active, follow these steps in order:

1. Confirm you can sign in to GitHub and open the repositories assigned to you. Clone only those repositories.
2. Open your first assigned GitHub issue. Confirm the goal, acceptance criteria, and reviewer with your mentor before changing code.
3. Read the short onboarding path below and the [documentation map](../documentation-map.md). Complete shared AWS/database setup only if your assignment needs it, then open the README in your assigned code repository.
4. Follow that README to install tools, configure the local environment, and run the listed checks. Ask your mentor if a command fails; don't copy credentials from another teammate.
5. Start with synthetic data. Keep real patient data and all secrets out of source files, logs, screenshots, and chat.

Most tasks do not need AWS or database access. If your issue does need it, your team lead must first provide an individual AWS identity and the specific permissions for that work. After that access is ready, use the database guide's Windows or Linux steps. Database access is not granted automatically when your work email is created.

## Recommended first reading

This path should take about one to two hours. Read the short sections listed here first; return to the full references when your work needs them.

1. [Product Requirements Document](../prd/product-requirements-document.md): read the executive summary, product principles, Phase 1 scope, Phase 2 scope, and non-goals.
2. [Overall platform diagram](../diagrams/overall-platform.svg): trace the major components and data flow.
3. [High-Level Design](../architecture/high-level-design.html): read the system boundary, deployment flow, security boundary, and build sequence.
4. [Webhook processing pipeline](../ingestion/webhook-processing-pipeline.html): understand why receipt, asynchronous processing, retries, idempotency, and PHI minimization are separate concerns.
5. [Canonical event schema review guide](../database/canonical-event-schema-review-guide.html): learn the tenant data model and its access/retention boundaries. Use the checked-in SQL schemas for exact DDL.
6. Read the role-specific references below only as needed:
   - Backend or API: [Data Platform Service Design](../architecture/data-platform-service-design.md), then the API-contract note below.
   - Frontend: [UI API Contracts](../architecture/ui-api-contracts.md), then `analyticalrx-ui/README.md` in the UI repository.
   - Data or ingestion: [PrimeRx ingestion pipeline](../ingestion/ingestion-pipeline-design.html), the schema review guide, and the receiver/processor repository READMEs.
   - Access control: [RBAC Standard](../architecture/role-based-access-control-standard.md) and [RBAC Role Summary](../architecture/rbac-role-summary.md).

### Which API contract should I use?

There are two UI contract documents with different roles:

- The [implemented Data Platform UI API Contract](https://github.com/analyticalrx/data-platform/blob/main/docs/ui-api-contract.md) describes the routes and response shapes currently implemented by the backend. Use it for integration work.
- [UI API Contracts](../architecture/ui-api-contracts.md) in this documentation repository is the broader design contract for planned dashboard and admin APIs. It is not a guarantee that every listed route is implemented.

Check the backend and frontend source when behavior differs from a design document, and raise the discrepancy with the issue owner before changing a shared contract.

## Repository map

The workspace contains several repositories. Clone only the ones needed for your assignment; each code repository has its own setup instructions.

| Repository | What it owns | First reference |
| --- | --- | --- |
| `analytical-rx-documentation` | Product scope, architecture, schema references, operations, and design artifacts. | This guide, then `README.md` and `index.html`. |
| `data-platform` | Spring Boot API, authentication, tenant/RBAC enforcement, database access, and task APIs. | [Repository README](https://github.com/analyticalrx/data-platform/blob/main/README.md); its implemented UI API contract is under `docs/`. |
| `analyticalrx-ui` | Next.js user interface and authenticated forwarding to the backend. | [Repository README](https://github.com/analyticalrx/analyticalrx-ui/blob/main/README.md). |
| `primerx-receiver-lambda-service` | PrimeRx webhook intake and queue publishing. | [Repository README](https://github.com/analyticalrx/primerx-receiver-lambda-service/blob/main/README.md). |
| `primerx-processing-lambda-service` | Queue event processing, PHI minimization, and database persistence. | [Repository README](https://github.com/analyticalrx/primerx-processing-lambda-service/blob/main/README.md) and the ingestion design. |
| `webhook-test-simulator` | Synthetic PrimeRx-shaped webhook payloads for safe local and test use. | [Repository README](https://github.com/analyticalrx/webhook-test-simulator/blob/main/README.md); start in dry-run mode. |

The [documentation map](../documentation-map.md) identifies the maintained home for
each topic. Shared AWS/database setup and system designs live here; run commands,
implemented API contracts, and service-specific migrations live beside their code.

The documentation is maintained in a separate repository from the application code. Changes to a design document do not change the running implementation; code changes do not automatically update the design.

## A mental model of the system

```text
PrimeRx / Micro Merchant
        |
        +--> webhook receiver --> SQS --> processor --> PostgreSQL tenant schema
                                      |                   |
                                      +--> audit/status   +--> restricted source references

User --> Next.js UI --> Spring Boot API --> control_plane + tenant-scoped data
                                      |
                                      +--> backend-enforced tenant, pharmacy, and role access
```

The diagram summarizes the intended boundaries. The webhook receiver accepts events and queues work; the processor validates, minimizes, and persists event data; the Spring Boot service serves authenticated application APIs; and the UI renders the user's allowed workspace. Normal dashboard APIs must not expose raw payloads, direct patient identifiers, or raw prescription identifiers.

## Setup path

1. Sign in to GitHub with your own account and clone only the repositories assigned to you. The [older teammate GitHub setup document](analyticalrx-teammate-setup-guide.docx) covers documentation-repository access and cloning only; confirm the repository URL and access with the current team owner before using it.
2. Follow the README in your assigned code repository for language/runtime versions, local configuration, and commands.
3. Use synthetic data for local development. The [webhook test simulator](https://github.com/analyticalrx/webhook-test-simulator/blob/main/README.md) runs in dry-run mode when no endpoint is configured.
4. Request AWS/database access only if your task needs it. Use your own approved IAM identity and the [pgAdmin/SSM access guide](../operations/teammate-rds-pgadmin-access-guide.md). The [database operations guide](../operations/phase1-aws-postgres-dev-database.md) documents the dev instance, tunnel, and start/stop utility. Some existing local environment notes refer to root-level credentials; do not copy or use those credentials.
5. Never commit `.env`, access keys, database passwords, JWT signing secrets, or real PHI. Do not point the simulator at a live endpoint unless the task explicitly calls for it and the owner has confirmed the target.

## Team lead preparation before Day One

- Confirm each intern's GitHub account and grant access only to the repositories they need.
- Choose a first issue for each intern and identify the person who will answer product and implementation questions.
- Provide individual development credentials. Do not send shared AWS keys, root credentials, database passwords, or JWT secrets in onboarding messages.
- Decide whether each first assignment needs AWS/database access. If it does, arrange an individual least-privilege IAM identity and access to the required secrets before the intern follows the database guide.
- Make sure their laptop has the language/runtime required by the assigned repository; AWS CLI and Session Manager are only needed for work that uses the dev database or AWS.
- Start their first data work with the synthetic webhook simulator and a dry run.

## How to find current work

- Use the live AnalyticalRx GitHub Project and issue assigned to you for the current scope, owner, acceptance criteria, and status.
- Use the PRD for product scope and intended behavior.
- Use implementation code and tests for behavior that exists today.
- Use design documents for architecture and constraints; check their status labels before treating recommendations as settled decisions.
- `project-tasks/` contains draft descriptions and historical issue-planning snapshots. Its status tables can become stale; do not use them to infer current work status.

Before starting a change, identify its issue, relevant repository, and acceptance criteria. If the issue and a design document disagree, surface the conflict before changing a shared API, schema, or security boundary.

## Reference material and older artifacts

- [Airtable documentation](../airtable/index.html) is archived workflow and interface research, not a current implementation spec.
- [PrimeRx Webhook Integration Guide](../PrimeRx%20Webhook%20Onboarding.pdf) is a vendor reference from June 2026. It uses both HTTP 200 and 2xx success language, and its sample event list does not fully match its supported-event list. Verify event names, authentication, delivery, and payload details against the current integration agreement and the ingestion design; vendor examples are not test fixtures.
- [PRD Readiness Review](../prd/prd-readiness-review.md), the data-platform progress tracker, and issue-gap plans are dated reviews/snapshots. Read their dates and status notes; use the current PRD, code, and GitHub Project for current facts.
- The client and Airtable presentations are for stakeholder context, not engineering acceptance criteria.

## First-week checklist

- [ ] Explain the Phase 1/Phase 2 boundary and the end-to-end data flow in your own words.
- [ ] Identify the repository and issue for your first task.
- [ ] Run the local setup and checks listed in that repository's README.
- [ ] Confirm which API/schema documents are implemented contracts versus design drafts.
- [ ] Use synthetic data and keep secrets and PHI out of commits, logs, and screenshots.
- [ ] Ask the issue owner to review your first small change before expanding its scope.
