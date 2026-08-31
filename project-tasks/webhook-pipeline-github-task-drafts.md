# Webhook Processing Pipeline - GitHub Task Drafts

These are draft GitHub project tasks for the first implementation slice of the PrimeRx webhook processing pipeline.

Target MVP architecture:

```text
PrimeRx Webhook
  -> AWS API Gateway
  -> Receiver Lambda
  -> SQS Queue
  -> Processor Lambda
  -> Audit / Canonical Output
```

The first implementation should stay intentionally narrow. The goal is to receive PrimeRx webhook events reliably, acknowledge quickly, queue work asynchronously, process events safely, and produce an auditable normalized output. If cold starts, volume, or timeout behavior become real problems later, we can revisit runtime choices after we have measurements.

---

## Task 1: Create HLD For MVP Webhook Processing Pipeline

### Objective

Create the high-level design for the MVP webhook processing pipeline so the implementation team has a shared architecture, boundaries, assumptions, and build sequence before coding starts.

### Background

PrimeRx supports webhook notifications for selected pharmacy events. For the MVP, webhooks should be treated as a near-real-time event trigger, not as the complete source of historical analytics data. The pipeline should receive webhook payloads, place them into a queue, process them asynchronously, minimize PHI exposure, and write audit-ready normalized results.

### Scope

Document the MVP architecture using the following AWS components:

- AWS API Gateway as the public webhook endpoint.
- Receiver Lambda as the thin intake handler.
- Amazon SQS as the asynchronous queue between intake and processing.
- Processor Lambda as the business processing worker.
- Audit output for receipt, queueing, processing, failure, and PHI minimization decisions.

### Required Content

The HLD should include:

- MVP architecture diagram.
- Component responsibilities.
- Request flow from PrimeRx webhook to processor output.
- PHI boundary and handling assumptions.
- Expected event envelope shape at a high level.
- Retry and duplicate-handling assumptions.
- Basic operational and monitoring expectations.
- Open questions for PrimeRx that may affect implementation.
- Out-of-scope items for the first build.

### Important Design Decisions

- The receiver Lambda should do minimal work before returning a success response.
- The processor Lambda should handle heavier validation, normalization, enrichment placeholders, and ingestion status updates.
- The queue boundary should protect the receiver from downstream failures.
- The first version does not need to solve historical backfill or full API enrichment.
- The first version must assume webhook payloads may contain PHI until proven otherwise.

### Acceptance Criteria

- HLD clearly shows API Gateway, receiver Lambda, SQS, and processor Lambda.
- HLD explains what each component owns and what it does not own.
- HLD defines the PHI handling policy for the MVP.
- HLD defines the minimum event lifecycle: received, accepted, queued, processed, failed, duplicate.
- HLD lists assumptions and open questions separately.
- HLD is reviewed by the team before implementation tasks are started.

### Dependencies

- Current PrimeRx webhook onboarding information.
- Current product architecture documentation.

### Suggested Labels

`architecture`, `mvp`, `webhook`, `aws`, `documentation`

---

## Task 2: Build AWS API Gateway Webhook Endpoint

### Objective

Create the public AWS API Gateway endpoint that PrimeRx will call when sending webhook events.

### Background

PrimeRx webhooks are expected to send HTTP POST requests with JSON payloads to a vendor-provided endpoint. API Gateway should be the public entry point for this traffic and route webhook requests to the receiver Lambda.

### Scope

Create an API Gateway endpoint for webhook intake:

- HTTP method: `POST`
- Path: recommended initial path `/webhooks/primerx`
- Integration target: receiver Lambda
- Payload type: JSON
- Response behavior: return a successful response only after the receiver Lambda has accepted the event for queueing

### Implementation Notes

The endpoint should be designed so the URL can later be shared with PrimeRx.

The first version should support:

- A single webhook path for PrimeRx events.
- Request forwarding to the receiver Lambda.
- Basic access logs.
- Configurable stage/environment naming such as `dev`, `test`, and `prod`.

Do not hardcode production-only values. The endpoint should be deployable in a non-production environment first.

### Security Notes

PrimeRx authentication/signing details are not fully confirmed yet. For the MVP implementation:

- Support a configurable shared secret or header-based validation if available.
- Keep validation logic in the receiver Lambda, not inside hardcoded API Gateway rules.
- Do not expose internal AWS details in error responses.
- Do not log full request bodies in API Gateway access logs.

### Deliverables

- API Gateway route for PrimeRx webhook POST requests.
- Integration between API Gateway and receiver Lambda.
- Environment-specific endpoint output.
- Basic API Gateway logging enabled without full PHI payload logging.
- Infrastructure code or documented setup steps, depending on the project standard chosen.

### Acceptance Criteria

- A `POST /webhooks/primerx` endpoint exists in AWS.
- The endpoint invokes the receiver Lambda.
- A valid test request reaches the receiver Lambda.
- Invalid HTTP methods are rejected or not exposed.
- API Gateway logs request metadata without logging full PHI payloads.
- Endpoint configuration is reproducible for at least one non-production environment.

### Test Cases

- Send a valid JSON POST request and confirm the receiver Lambda is invoked.
- Send malformed JSON and confirm the request fails safely.
- Send a GET request and confirm it is not accepted as a webhook event.
- Confirm access logs do not contain full webhook payload bodies.

### Dependencies

- AWS account/environment access.
- Receiver Lambda placeholder or deployed function.
- Agreed environment naming convention.

### Suggested Labels

`backend`, `aws`, `api-gateway`, `webhook`, `mvp`

---

## Task 3: Build Receiver Lambda For Webhook Intake

### Objective

Build the receiver Lambda that accepts PrimeRx webhook requests from API Gateway, performs lightweight validation, wraps the payload in an internal event envelope, sends it to SQS, and returns a fast response.

### Background

The receiver Lambda is the first code boundary after API Gateway. It should not perform heavy business processing. Its main responsibility is to safely accept the event and hand it off to the queue.

### Scope

The receiver Lambda should:

- Accept webhook requests from API Gateway.
- Parse the request body as JSON.
- Validate basic request shape.
- Validate source/auth header if a shared secret or equivalent mechanism is configured.
- Create an internal event envelope.
- Send the event envelope to SQS.
- Return a fast success response once the event is queued.
- Return safe error responses for invalid requests.

### Internal Event Envelope

The receiver should create an envelope similar to:

```json
{
  "source": "primerx",
  "receivedAt": "ISO-8601 timestamp",
  "requestId": "api/lambda correlation id",
  "eventType": "value if available",
  "pharmacyId": "value if available",
  "rawPayload": {},
  "headers": {
    "allowedHeaderOnly": "value"
  },
  "processingStatus": "received"
}
```

Exact field names can change during implementation, but the envelope must support correlation, auditing, deduplication, and downstream processing.

### PHI Handling Notes

At this stage, assume the raw webhook payload may contain PHI.

For the first version:

- Do not write the full payload to general application logs.
- Do not print request body in errors.
- Store the payload only in the queue message or approved restricted storage path.
- Log only safe metadata such as request ID, event type if non-sensitive, timestamp, and processing status.

### Error Handling

The receiver should distinguish:

- Invalid JSON.
- Missing required request information.
- Failed source/auth validation.
- SQS send failure.
- Unexpected internal error.

Errors should return safe responses without leaking payload content.

### Deliverables

- Receiver Lambda source code.
- Configuration for SQS queue URL/name.
- Configuration for optional shared secret/header validation.
- Unit tests for request parsing and validation.
- Integration test or script that sends a sample webhook through API Gateway.

### Acceptance Criteria

- Valid webhook JSON is accepted and sent to SQS.
- Receiver returns a success response only after SQS accepts the message.
- Invalid JSON is rejected.
- Failed validation is rejected if validation is configured.
- SQS failure returns a non-success response.
- Logs do not include full webhook payload body.
- Receiver can run in a non-production environment.
- Unit tests cover valid request, invalid JSON, missing body, auth failure, and SQS failure.

### Test Cases

- Valid PrimeRx-like webhook payload.
- Empty body.
- Malformed JSON body.
- Missing configured validation header.
- Wrong configured validation header.
- Simulated SQS send failure.

### Dependencies

- API Gateway endpoint task.
- SQS queue task.
- AWS permissions for Lambda to send messages to SQS.

### Suggested Labels

`backend`, `aws`, `lambda`, `webhook`, `security`, `phi`, `mvp`

---

## Task 4: Create SQS Queue For Webhook Events

### Objective

Create the Amazon SQS queue that buffers webhook events between the receiver Lambda and processor Lambda.

### Background

SQS is the asynchronous boundary between webhook intake and processing. It prevents downstream processing failures from blocking webhook receipt and gives us retry behavior, buffering, and failure isolation.

### Scope

Create the queue infrastructure for webhook events:

- Main webhook event queue.
- Dead-letter queue for messages that repeatedly fail processing.
- Queue permissions for receiver Lambda to send messages.
- Queue permissions for processor Lambda to consume messages.
- Visibility timeout appropriate for processor Lambda execution.
- Retention period appropriate for debugging and recovery.

### Queue Type

For MVP, use a standard SQS queue unless ordering requirements are confirmed by PrimeRx.

Reasoning:

- Webhook systems may deliver events more than once.
- PrimeRx event ordering may not be guaranteed.
- Processor Lambda must be idempotent either way.
- Standard queue is simpler for MVP and supports higher throughput.

If strict per-prescription ordering becomes required later, evaluate FIFO queue behavior separately.

### Message Body Expectations

The queue message should contain the internal event envelope created by the receiver Lambda.

The message should include enough information for:

- Correlation.
- Processing/ingestion status.
- Event type routing.
- Duplicate detection.
- PHI minimization.
- Future API enrichment.

### PHI Handling Notes

Because queue messages may contain raw webhook payloads:

- Restrict queue access to only required AWS principals.
- Do not allow broad read access.
- Do not log full message bodies in processor logs.
- Ensure retention settings are intentional.
- Treat the queue as part of the restricted ingestion boundary.

### Deliverables

- Main SQS queue.
- Dead-letter queue.
- Redrive policy from main queue to DLQ.
- IAM permissions for receiver and processor Lambdas.
- Queue configuration documented in infrastructure code or setup notes.

### Acceptance Criteria

- Receiver Lambda can send messages to the main queue.
- Processor Lambda can receive and delete messages from the main queue.
- Failed messages are retried according to queue/Lambda behavior.
- Messages that exceed retry threshold move to DLQ.
- Queue access is restricted to required services/roles.
- Queue name and URL are available to deployment configuration.

### Test Cases

- Send a test message to the queue.
- Confirm processor Lambda receives the message.
- Simulate processor failure and confirm retry behavior.
- Simulate repeated processor failure and confirm message lands in DLQ.
- Confirm unauthorized users/services cannot read queue messages.

### Dependencies

- AWS environment access.
- Receiver Lambda IAM role.
- Processor Lambda IAM role.

### Suggested Labels

`backend`, `aws`, `sqs`, `data-pipeline`, `phi`, `mvp`

---

## Task 5: Build Processor Lambda For Webhook Events

### Objective

Build the processor Lambda that consumes webhook event messages from SQS, validates and normalizes events, applies PHI minimization rules, handles duplicates safely, and writes audit-ready output.

### Background

The processor Lambda owns the heavier work that should not happen inside the receiver Lambda. It should be safe to retry because SQS/Lambda processing is at-least-once. Duplicate messages must not create duplicate downstream results.

### Scope

The processor Lambda should:

- Consume messages from the webhook SQS queue.
- Parse the internal event envelope.
- Validate required envelope fields.
- Classify the event type if available.
- Apply PHI minimization rules.
- Generate or evaluate an idempotency key.
- Normalize the event into the initial canonical webhook event format.
- Write processing/ingestion status.
- Handle unknown or unsupported event types safely.
- Fail intentionally when a message should be retried.
- Avoid logging raw PHI payloads.

### Initial Processing States

Support these statuses at minimum:

- `received`
- `processing`
- `processed`
- `failed`
- `duplicate`
- `unsupported_event_type`
- `phi_suppressed`

### PHI Minimization Requirements

The processor must assume raw payloads may contain PHI.

For MVP:

- Drop direct patient identifiers from normalized output unless explicitly approved.
- Do not write patient name, address, phone, DOB, prescription images, notes, or member IDs to analytics output.
- Convert sensitive values only if an approved transformation exists.
- Keep raw payload handling inside the restricted ingestion boundary.
- Record that PHI minimization was applied.

### Idempotency Requirements

The processor must be safe if the same SQS message or webhook event is processed more than once.

The implementation should define an idempotency key using available fields such as:

- PrimeRx event ID if available.
- Event type.
- Pharmacy/store identifier.
- Prescription/fill identifier if available and approved for use.
- Event timestamp.
- Receiver request ID as fallback only when no better key exists.

If the same idempotency key is seen again, the processor should mark the event as duplicate and avoid duplicate downstream writes.

### Output Expectations

For the first version, output can be a simple audit/canonical record as long as it is structured and queryable.

The normalized record should include:

- Source system.
- Received timestamp.
- Processed timestamp.
- Event type.
- Store/pharmacy identifier if available.
- Processing status.
- Idempotency key.
- PHI minimization result.
- Error reason if failed.
- Safe non-PHI event attributes.

### Deliverables

- Processor Lambda source code.
- SQS event source mapping.
- Processor configuration.
- Initial canonical event output writer.
- Audit status writer.
- Unit tests for parsing, validation, PHI suppression, idempotency, and unsupported event types.
- Integration test for receiver-to-SQS-to-processor flow.

### Acceptance Criteria

- Processor Lambda consumes messages from SQS.
- Valid event envelopes are processed successfully.
- Invalid envelopes fail safely.
- Duplicate events are detected and do not create duplicate output.
- PHI minimization is applied before analytics/canonical output.
- Unknown event types are handled without crashing the whole pipeline.
- Processing/ingestion status is written for success and failure cases.
- Logs do not include raw webhook payloads.
- Tests cover happy path, invalid message, duplicate message, unsupported event type, and PHI suppression.

### Test Cases

- Valid event envelope with known event type.
- Valid event envelope with unknown event type.
- Duplicate event envelope.
- Event envelope missing required metadata.
- Event payload containing sample PHI fields.
- Processor failure that causes SQS retry.
- Repeated processor failure that routes to DLQ.

### Dependencies

- SQS queue task.
- Receiver Lambda task.
- Initial storage/audit decision.
- PHI field policy from HLD.

### Suggested Labels

`backend`, `aws`, `lambda`, `sqs`, `data-pipeline`, `phi`, `testing`, `mvp`

---

## Task 6: Add End-To-End MVP Test For Webhook Pipeline

### Objective

Create an end-to-end test that proves a PrimeRx-like webhook event can travel through API Gateway, receiver Lambda, SQS, and processor Lambda.

### Background

Before integrating with PrimeRx, the team needs a repeatable local or non-production test that proves the pipeline works with a sample webhook payload.

### Scope

Create a test/demo flow that:

- Sends a sample PrimeRx-like webhook payload to API Gateway.
- Confirms receiver Lambda accepts and queues the event.
- Confirms SQS receives the event envelope.
- Confirms processor Lambda processes the message.
- Confirms audit/canonical output is written.
- Confirms no full PHI payload is written to general logs.

### Deliverables

- Sample webhook payload JSON.
- Test script or documented curl command.
- Expected response example.
- Expected audit/canonical output example.
- Troubleshooting notes for common failures.

### Acceptance Criteria

- A developer can run the test against a non-production endpoint.
- Test payload reaches the receiver Lambda.
- Test payload creates an SQS message.
- Processor Lambda consumes the message.
- Output record is created with processed status.
- Duplicate test execution does not create duplicate canonical output if the same idempotency key is used.
- Logs are checked for accidental raw payload/PHI output.

### Suggested Labels

`testing`, `aws`, `webhook`, `data-pipeline`, `mvp`

---

# Follow-Up Storage / Schema Task Drafts

These tasks should come after the basic webhook intake path is agreed, but before the processor Lambda is considered complete. The goal is to define where processed webhook events go, how we audit the pipeline, and how we avoid storing PHI in canonical/dashboard-facing storage.

Target storage concept:

```text
Raw PrimeRx webhook payload
  -> restricted ingestion boundary only

Webhook processing audit
  -> operational database records for traceability

Canonical processed event
  -> safe dashboard-ready canonical database records
```

Important identifier handling decision:

```text
Restricted operational tables
  -> may store real RxNo, RefillNo, tenant_id, and pharmacy_id for API enrichment/reconciliation

Canonical/dashboard tables
  -> should use prescription_reference_token / fill_reference_token instead of raw RxNo
```

PrimeRx API enrichment needs real source identifiers such as `RxNo`, `RefillNo`, and pharmacy identifier. A hash/token alone is not enough for API lookup. Therefore the system needs a restricted source-reference layer for backend integration jobs, while dashboards and analytics should use tokenized references.

For MVP, keep the storage design small and explicit. We do not need to model the full pharmacy business domain yet. We need enough structure to prove that webhook events can be received, processed, deduplicated, PHI-minimized, audited, and queried later by dashboards or reconciliation jobs.

---

## Task 7: Define MVP Storage Architecture For Processed Webhook Events

### Objective

Define the MVP storage architecture for processed PrimeRx webhook events, including where raw payloads may live, where ingestion records are stored, and where PHI-minimized pharmacy event records are stored.

### Background

The webhook pipeline can receive and process events, but the system still needs a clear destination for processed outputs. Without a defined storage model, the processor Lambda will either log too much, create ad hoc records, or mix raw webhook data with dashboard-ready canonical data. This task should establish the storage boundaries before persistence is implemented.

### Scope

Define the storage approach for three categories of data:

- Raw webhook payloads.
- Ingestion records.
- PHI-minimized pharmacy event records.
- Restricted source-reference records required for later API enrichment.

The design should answer:

- Which data is allowed in general application logs?
- Which data is allowed in SQS messages?
- Which data is allowed in restricted raw storage?
- Which data is allowed in the operational audit database?
- Which data is allowed in the canonical/dashboard database tables?
- Where real `RxNo` and `RefillNo` are stored for later PrimeRx API enrichment.
- Where tokenized prescription/fill references are stored for dashboards and later analytics.
- How the target tenant schema is selected for writes.
- How long each category should be retained for MVP.
- Which AWS services should be used for MVP.

### Recommended MVP Direction

Use this as the starting recommendation unless the team identifies a better reason to change it:

- SQS for temporary event buffering.
- Optional restricted S3 bucket for raw payload archive if raw retention is required.
- PostgreSQL-compatible database for audit and canonical processed records.
- CloudWatch logs for metadata-only operational logs, not raw payloads.

PostgreSQL can be AWS RDS PostgreSQL or Aurora PostgreSQL depending on cost, operations preference, and environment maturity. For the first implementation, the schema should stay portable and not rely on database-specific behavior unless needed.

SaaS isolation decision: tenant-owned tables should be created inside one PostgreSQL schema per tenant. The processor must route writes to the tenant schema from trusted tenant configuration, not from untrusted payload fields alone.

### PHI Boundary

Assume PrimeRx webhook payloads may contain PHI until PrimeRx confirms otherwise.

The storage architecture must clearly separate:

- Restricted raw/event intake data.
- Safe audit metadata.
- Dashboard-ready canonical records.
- Restricted source identifiers required for API enrichment.

Direct patient identifiers should not be stored in canonical dashboard tables unless explicitly approved later.

`RxNo` and `RefillNo` should be treated as restricted source identifiers. They may be stored in a restricted operational table with tenant/pharmacy isolation and strict backend-only access, but canonical/dashboard tables should use HMAC/tokenized references.

### Key Design Questions

- Do we need to persist full raw webhook payloads outside SQS for MVP?
- If yes, should raw payloads go to restricted S3 with encryption and short retention?
- What is the minimum ingestion record needed to troubleshoot webhook processing?
- What is the minimum canonical record needed for dashboards and future analytics?
- What restricted table owns real `RxNo`, `RefillNo`, `tenant_id`, and `pharmacy_id`?
- What HMAC/token strategy creates `prescription_reference_token` and `fill_reference_token`?
- What retention period should we use for raw, audit, and canonical data?
- Who or what services can read each data category?

### Deliverables

- Short storage architecture decision document.
- Diagram showing raw, audit, and canonical storage boundaries.
- Recommended AWS services for MVP.
- Retention and access assumptions.
- List of out-of-scope storage concerns for later phases.

### Acceptance Criteria

- [ ] Storage architecture distinguishes raw payloads, ingestion records, and pharmacy event records.
- [ ] PHI boundary is explicitly documented.
- [ ] MVP database recommendation is documented.
- [ ] Raw payload retention decision is documented.
- [ ] Restricted source-reference storage for `RxNo`, `RefillNo`, `tenant_id`, and `pharmacy_id` is documented.
- [ ] Tokenized prescription/fill reference strategy for canonical/dashboard tables is documented.
- [ ] Tenant-schema write routing is documented.
- [ ] Audit retention decision is documented.
- [ ] Canonical event retention decision is documented.
- [ ] Processor Lambda persistence responsibilities are clearly defined.
- [ ] Open questions are listed separately from decisions.

### Suggested Labels

`architecture`, `database`, `phi`, `data-pipeline`, `mvp`

---

## Task 8: Define Ingestion Event And Idempotency Schema

### Objective

Define the database schema for webhook/API ingestion records and idempotency tracking so the pipeline can be traced, retried safely, and protected from duplicate event processing.

### Background

Webhook delivery is usually at-least-once. SQS/Lambda processing is also at-least-once. This means the same event may be processed multiple times. The system needs a durable way to track event lifecycle, identify duplicates, and troubleshoot failures without exposing PHI in logs.

### Scope

Design the operational schema for:

- Webhook/API receipt tracking.
- Queue/processing status.
- Link to restricted source identifiers needed for API enrichment.
- Link to raw payload archive metadata when raw retention is enabled.
- Idempotency keys.
- Duplicate detection.
- Failure reasons.
- PHI minimization status.

This task is about the schema and lifecycle model, not full processor implementation.

### Proposed Table: `ingestion_event`

Initial fields to consider:

```text
id
tenant_id
pharmacy_id
source_system
source_event_id
source_event_type
idempotency_key
source_rx_reference_id
raw_payload_archive_id
receiver_request_id
received_at
queued_at
processing_started_at
processed_at
status
failure_reason
duplicate_of
phi_suppression_status
raw_payload_reference
created_at
updated_at
```

### Status Model

Support these statuses at minimum:

```text
received
queued
processing
processed
failed
duplicate
unsupported_event_type
needs_enrichment
```

The team can refine names, but status values must be consistent enough for operations queries and dashboard/debug views. PHI suppression should be tracked separately through `phi_suppression_status`.

### Idempotency Requirements

Define how the idempotency key is created.

Preferred key priority:

- PrimeRx event ID if available.
- Vendor event type + tenant ID + pharmacy/store identifier + source event timestamp.
- Vendor event type + tenant ID + pharmacy/store identifier + `RxNo` + `RefillNo`, stored only in the restricted operational layer.
- Receiver request ID only as a fallback when no stable event identity exists.

The schema should support:

- Unique constraint on idempotency key where possible.
- Duplicate event linking through `duplicate_of`.
- Safe retry behavior.
- Reprocessing decisions later if needed.

### PHI Handling Requirements

Audit records should not store raw patient identifiers.

Avoid storing:

- Patient name.
- Patient street address.
- Patient phone.
- Patient DOB.
- Patient insurance member ID.
- Prescription images.
- Free-text notes that may contain PHI.

If an identifier is needed for debugging or continuity, define whether it should be dropped, hashed, tokenized, or replaced with a reference.

`RxNo` and `RefillNo` are allowed only in the restricted `source_rx_reference` table because backend jobs need them for PrimeRx API enrichment. Analytics-facing tables should use `prescription_reference_token` and `fill_reference_token`.

The token should be generated using a keyed hash such as:

```text
HMAC_SHA256(secret, tenant_id + pharmacy_id + rx_no + refill_no)
```

### Example Queries To Support

The schema should support queries like:

- How many webhook events were received today?
- How many failed processing?
- Which event types are failing most often?
- How many duplicates were detected?
- Which messages were moved to DLQ?
- Did PHI minimization run for this event?
- What was the lifecycle for a given idempotency key?
- Which restricted source reference should be used for API enrichment?

### Deliverables

- Database schema proposal for webhook/API ingestion and idempotency.
- Status lifecycle definition.
- Idempotency key strategy.
- Restricted source-reference strategy for `RxNo` and `RefillNo`.
- Token strategy for PHI-minimized prescription/fill references.
- PHI exclusion list for ingestion records.
- Example operational queries.

### Acceptance Criteria

- [ ] Proposed `ingestion_event` fields are documented.
- [ ] Required indexes/unique constraints are documented.
- [ ] Status lifecycle is documented.
- [ ] Idempotency key strategy is documented.
- [ ] Restricted handling of `RxNo` and `RefillNo` is documented.
- [ ] `tenant_id` and `pharmacy_id` are included in the source-reference model.
- [ ] Prescription/fill token strategy is documented.
- [ ] Duplicate handling behavior is documented.
- [ ] PHI fields excluded from ingestion records are documented.
- [ ] Example operational queries are included.
- [ ] Schema is reviewed before processor persistence work begins.

### Suggested Labels

`database`, `data-pipeline`, `idempotency`, `phi`, `mvp`

---

## Task 9: Define Pharmacy Event And Payment Schema

### Objective

Define the PHI-minimized `pharmacy_event` and `event_payment` schema that stores processed PrimeRx webhook/API events in a stable format for dashboards, reconciliation, and future analytics work.

### Background

PrimeRx webhook payloads are vendor-specific. The product should not make dashboards or analytics depend directly on raw PrimeRx field names. A canonical processed event table gives the system a stable internal model even if webhook payload shape changes later.

### Scope

Design the first processed event model for webhook/API events.

This schema should capture safe event-level business facts, not the full prescription analytics model. The goal is to create a clean destination for processor Lambda output without duplicating drug or payer attributes.

### Proposed Table: `pharmacy_event`

Initial fields to consider:

```text
id
tenant_id
pharmacy_id
source_system
source_event_type
canonical_event_type
prescription_reference_token
fill_reference_token
event_timestamp
business_date
drug_id
rx_status
claim_status
fulfillment_status
queue_status
days_supply
quantity_ordered
quantity_dispensed
quantity_remaining
prescriber_npi
total_amount
ingredient_cost_amount
dispensing_fee_amount
other_fee_amount
tax_amount
discount_amount
amount_due
reversal_flag
rejection_code
rejection_reason_category
enrichment_status
data_quality_status
ingestion_event_id
created_at
updated_at
```

Drug attributes such as NDC and drug name belong in `drug`. Payer attributes such as payer name, BIN, and PCN belong in `payer`. Payer/payment amounts belong in `event_payment`, linked through `pharmacy_event_id`.

The final schema may remove fields if PrimeRx does not provide them through webhook payloads. It may also leave some fields nullable until API enrichment is added.

### Canonical Model Principles

- Keep raw PrimeRx payload fields out of canonical/dashboard tables.
- Store event-level business facts in stable internal names.
- Use safe tokens or approved references instead of direct patient identifiers.
- Do not store raw `RxNo` in canonical/dashboard-facing tables.
- Use `prescription_reference_token` and `fill_reference_token` generated from restricted source identifiers.
- Allow nullable fields where webhook payloads are incomplete.
- Link each pharmacy event back to the `ingestion_event` record.
- Keep the schema extensible for API enrichment later.

### PHI Handling Requirements

The canonical table should not include direct patient identifiers.

Do not include:

- Patient first name.
- Patient last name.
- Full date of birth.
- Full address.
- Phone number.
- Email.
- Insurance member ID.
- Free-text notes.
- Prescription images.

If patient or prescription continuity is required, use only approved tokens, hashes, or source references after the PHI policy is reviewed.

Raw `RxNo` and `RefillNo` should remain available only in `source_rx_reference` for API enrichment and reconciliation. The `pharmacy_event` table should store tokenized references and link back to the ingestion/source-reference path.

### Open Data Questions

The schema should call out fields that depend on PrimeRx payload/API details:

- Does webhook payload include stable event ID?
- Does webhook payload include pharmacy/store ID?
- Does webhook payload include prescription/fill identifiers?
- Can we store real `RxNo` and `RefillNo` in restricted operational tables under tenant/pharmacy isolation?
- Can PrimeRx suppress PHI fields in webhook payloads?
- Are financial fields included in webhook events or only available through API lookup?
- Are drug/payer/prescriber fields included directly or only through enrichment?

### Deliverables

- `pharmacy_event` schema proposal.
- `event_payment` schema proposal.
- Field definitions and nullable/required guidance.
- PHI exclusion list.
- Tokenized prescription/fill reference strategy.
- Mapping notes from webhook envelope to `pharmacy_event`, `drug`, `payer`, and `event_payment`.
- Open questions for fields requiring PrimeRx confirmation.

### Acceptance Criteria

- [ ] `pharmacy_event` table is documented.
- [ ] `event_payment` table is documented.
- [ ] Field definitions are documented.
- [ ] Required vs nullable fields are identified.
- [ ] PHI-excluded fields are explicitly listed.
- [ ] Link from `pharmacy_event` to `ingestion_event` is defined.
- [ ] Raw `RxNo` is excluded from canonical/dashboard-facing tables.
- [ ] `prescription_reference_token` / `fill_reference_token` strategy is defined.
- [ ] Mapping assumptions from webhook payload/envelope are documented.
- [ ] Open PrimeRx data questions are documented.

### Suggested Labels

`database`, `analytics`, `canonical-model`, `phi`, `mvp`

---

## Task 10: Update Processor Lambda To Persist Ingestion, Pharmacy Event, And Payment Records

### Objective

Update the processor Lambda so processed webhook events are written to the approved `ingestion_event`, `source_rx_reference`, `pharmacy_event`, and `event_payment` tables.

### Background

After the ingestion and processed event schema is approved, the processor Lambda should write structured records instead of only logging processing results. This closes the loop from webhook receipt to durable, queryable, PHI-minimized output.

### Scope

Implement processor persistence for:

- Ingestion lifecycle updates.
- Restricted source-reference persistence for real `RxNo`, `RefillNo`, `tenant_id`, and `pharmacy_id`.
- Idempotency checks.
- Duplicate event handling.
- PHI minimization result.
- Pharmacy event write.
- Event payment row writes.
- Failure status updates.

### Expected Processing Flow

```text
SQS message received
  -> parse internal event envelope
  -> create/update ingestion_event record
  -> store restricted source identifiers for API enrichment
  -> compute idempotency key
  -> check duplicate status
  -> apply PHI minimization
  -> generate PHI-minimized prescription/fill tokens
  -> upsert safe drug and payer lookup rows
  -> map safe fields to pharmacy_event
  -> write pharmacy_event
  -> write event_payment rows when payment details exist
  -> mark ingestion_event record processed
```

If processing fails:

```text
SQS message received
  -> create/update ingestion_event record
  -> failure occurs
  -> write safe failure reason
  -> allow retry or route to DLQ based on failure type
```

### Implementation Notes

- Database writes should be idempotent.
- Duplicate events should not create duplicate `pharmacy_event` or `event_payment` records.
- Real `RxNo` and `RefillNo` should be written only to restricted operational tables.
- Canonical/dashboard tables should receive tokenized prescription/fill references only.
- Ingestion status should be updated even when pharmacy event mapping fails.
- Logs should contain correlation IDs and safe metadata only.
- Raw payloads should not be written to general logs.
- Database connection handling must work safely inside Lambda.

### Persistence Requirements

The processor should support:

- Insert or update `ingestion_event` when processing starts if one does not already exist.
- Persist `tenant_id`, `pharmacy_id`, `RxNo`, and `RefillNo` in the restricted source-reference layer for later API enrichment.
- Generate `prescription_reference_token` and `fill_reference_token` for canonical/dashboard-facing records.
- Update ingestion status as processing moves forward.
- Enforce idempotency before writing canonical output.
- Insert `pharmacy_event` only after PHI minimization.
- Insert `event_payment` rows only from safe payment components.
- Mark duplicates clearly.
- Write failure reason without raw payload or PHI.

### Deliverables

- Processor Lambda database persistence code.
- Restricted source-reference persistence code.
- Drug and payer lookup upsert code.
- Pharmacy event and payment persistence code.
- Database migration or setup script for required tables.
- Configuration for database connection secrets.
- Unit tests for persistence behavior.
- Integration test with sample SQS event.
- Documentation for local/non-production testing.

### Acceptance Criteria

- [ ] Processor writes `ingestion_event` records.
- [ ] Processor writes restricted source-reference records containing `tenant_id`, `pharmacy_id`, `RxNo`, and `RefillNo`.
- [ ] Processor writes `pharmacy_event` records.
- [ ] Processor writes `event_payment` records when payment components exist.
- [ ] Canonical records use tokenized prescription/fill references instead of raw `RxNo`.
- [ ] Processor detects duplicate events using the approved idempotency strategy.
- [ ] Duplicate processing does not create duplicate canonical output.
- [ ] Processor updates ingestion status on success.
- [ ] Processor updates ingestion status on failure.
- [ ] Processor writes PHI minimization status.
- [ ] Processor logs safe metadata only.
- [ ] Tests cover success, failure, duplicate, unsupported event type, and PHI suppression.

### Suggested Labels

`backend`, `lambda`, `database`, `data-pipeline`, `phi`, `mvp`
