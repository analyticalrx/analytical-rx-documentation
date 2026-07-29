# Analytics Data Engineering - Task Drafts

These are draft GitHub project tasks for the analytics/data-engineering workstream. This is intentionally separate from the webhook processing pipeline task list.

The goal is not to jump directly into ML. The first goal is to prove data readiness: what fields are actually available, what can be safely stored, what needs API enrichment, and what baseline analytics can be produced from the first canonical event records.

---

## Review Of Search-Provided Predictive Architecture

The searched architecture has useful business direction, but it should not be treated as implementation-ready yet.

### Useful Ideas

- Revenue prediction should consider payer/PBM behavior, rejected claims, reversals, drug cost, copay, and insurer paid amounts.
- Refill and adherence analytics should consider days supply, pickup date, refill lag, and recurring prescription patterns.
- Demand forecasting should eventually use store, drug/service, seasonality, and local market context.
- PHI handling, tokenization, encryption, access control, and auditability are non-negotiable.

### Concerns

- It assumes raw webhook events alone are enough for revenue prediction. They probably are not.
- PBM clawback/DIR prediction likely requires data beyond webhooks: remittance data, payer statements, DIR fee reports, acquisition cost, claim reversals, payment timing, and adjustment history.
- Patient-level adherence prediction is PHI-heavy and should not be the first analytics deliverable unless tokenization and compliance boundaries are fully defined.
- SageMaker Feature Store and serverless inference are likely premature for MVP. Start with SQL feature marts and baseline forecasts. Move to SageMaker only after we prove field coverage, data quality, and forecast value.
- The first analytics work should be data inventory, canonical modeling, data quality, feature marts, and baseline forecasting.

---

## Current Field Availability Assessment

This assessment is based on the local PrimeRx/Micro Merchant OpenAPI file and the webhook information already captured from the PrimeRx webhook onboarding PDF.

### API Field Coverage

The API appears to expose several important analytics fields.

Confirmed in visible API schemas:

- Drug identifiers:
  - `DrugNDC`
  - `NDC`
  - `DrugName`
- Insurance / payer identifiers:
  - `InsuranceName`
  - `InsuranceBIN`
  - `InsurancePCN`
  - `PriInsName`
  - `PriInsBin`
  - `PriInsPCN`
  - `SecInsName`
  - `SecInsBin`
  - `SecInsPCN`
  - `TerInsName`
  - `TerInsBin`
  - `TerInsPCN`
- Financial fields:
  - `CoPay`
  - `PatientCopay`
  - `TotalRxAmount`
  - `Amount`
  - `AmountDue`
  - `IngredientCost`
  - `OtherFees`
  - `OtherAmounts`
  - `Discounts`
  - `Tax`
  - `PriInsPaid`
  - `SecInsPaid`
  - `TerInsPaid`
  - `TotalInsPaid`
- Prescription/refill fields:
  - `RxNo`
  - `RefillNo`
  - `TotalRefills`
  - `DaysSupply`
  - `DispenseDate`
  - `DateFilled`
  - `PickedUp`
  - `PickUpDate`
  - `PickUpTime`
  - `Status`
  - `OrderStatus`
  - `RefillStatus`
  - `RefillQueueStatus`
- Prescriber/patient/pharmacy related structures:
  - `Patient`
  - `Doctor`
  - `Drug`
  - `Pharmacy`
  - `PatientInsurance`

### Webhook Field Coverage

The webhook documentation appears useful for near-real-time event triggering and some event-level fields.

Captured webhook sample fields include:

- `Event`
- `RxNo`
- `RefillNo`
- `AuthRefills`
- `DaysSupply`
- `DateFilled`
- `DateOrdered`
- `Status`
- `QtyOrdered`
- `QtyDispensed`
- `QtyRemaining`
- `PickedUp`
- `DatePicked`
- `TimePicked`
- `DeliveryMethod`
- `TotalRxAmount`
- `PrimaryInsurancePaid`
- `SecondaryInsurancePaid`
- `TertiaryInsurancePaid`
- `PatientCopay`
- `BillType`
- `CopayPaid`
- `QueueName`
- nested `Drug`
- nested `Patient`
- nested `Prescriber`
- nested `Pharmacy`
- nested `RxPayRecords`

Supported webhook events captured in our docs include:

- `RxSaved`
- `RxDelivery`
- `RxBilled`
- `RxFiled`
- `RxReversed`
- `RxShipped`
- `RxTransmissionRejected`
- `RxDeleted`
- patient create/update events

### Important Distinction

The API appears more reliable for analytics enrichment fields such as NDC, BIN, PCN, payer name, paid amounts, copay, and ingredient cost.

The webhook appears better for event awareness: something happened, when it happened, and what prescription/fill may need follow-up processing.

Recommended MVP pattern:

```text
Webhook event
  -> tells us what changed
  -> processor stores restricted source reference: tenant_id, pharmacy_id, RxNo, RefillNo
  -> processor stores analytics-safe prescription/fill tokens
  -> API enrichment fills in NDC, payer, BIN/PCN, paid amounts, copay, ingredient cost, pickup/refill details
```

Important identifier handling decision:

- PrimeRx API enrichment needs real source identifiers such as `RxNo`, `RefillNo`, and pharmacy identifier.
- A hash/token alone cannot be used to call the vendor API.
- Real `RxNo` and `RefillNo` may be stored only in a restricted operational/source-reference layer.
- Analytics tables and feature marts should use `prescription_reference_token` and `fill_reference_token`.
- Tokens should be generated with tenant/pharmacy context, for example: `HMAC_SHA256(secret, tenant_id + pharmacy_id + rx_no + refill_no)`.

### Unknowns To Confirm

- Whether all API fields are available to this customer in production.
- Whether webhook payloads always include nested `Drug`, `RxPayRecords`, payer, or financial values.
- Whether webhook payloads can suppress PHI fields.
- Whether NDC/BIN/PCN fields are available in every prescription event or only through API lookup.
- Whether acquisition cost is available, and whether `IngredientCost` is sufficient for gross margin analytics.
- Whether DIR fees, clawbacks, PBM adjustments, remittance timing, and final net reimbursement are available anywhere in PrimeRx/Micro Merchant.
- Whether rejected/reversed claims have stable reason codes and reversal timestamps.
- Whether PrimeRx confirms `RxNo` + `RefillNo` + pharmacy identifier is sufficient for later detail lookup in production.

---

## Task 11: Define Analytics Data Inventory And Source Coverage

### Objective

Create a complete inventory of analytics-relevant fields available from PrimeRx webhooks, PrimeRx/Micro Merchant API endpoints, and any future bulk/export files.

### Background

Before building forecasting or revenue analytics, we need to know which fields are actually available and where they come from. The API appears to expose NDC, BIN, PCN, payer, paid amount, copay, ingredient cost, pickup, and refill fields. The webhook payload appears useful for near-real-time event triggering and some prescription/financial fields, but it may not be sufficient by itself.

### Scope

Build a field inventory covering:

- Webhook payload fields.
- API response fields.
- Fields that require API enrichment after webhook receipt.
- Fields that require bulk/export or another source.
- Fields that contain PHI.
- Fields safe for analytics after transformation.
- Fields needed for revenue, refill/adherence, and forecasting.

### Required Field Categories

Inventory these field groups:

- Store/pharmacy identifiers.
- Tenant identifiers.
- Prescription/fill identifiers.
- Drug identifiers including NDC.
- Payer/insurance identifiers including BIN and PCN.
- Financial fields including paid amounts, copay, total amount, ingredient cost, fees, discounts, and tax.
- Claim lifecycle fields including billed, rejected, reversed, deleted, rebilled, and adjusted.
- Refill/adherence fields including days supply, dispense date, pickup date, refill number, refills remaining, and refill status.
- Prescriber identifiers.
- Patient continuity fields, using only approved tokens or pseudonymous identifiers.
- Restricted source-reference fields required for API enrichment, including real `RxNo` and `RefillNo`.

### Deliverables

- Source coverage matrix.
- Field classification: PHI, sensitive financial, safe analytics, unknown.
- Mapping from webhook/API field names to canonical analytics names.
- Missing field list for PrimeRx/vendor follow-up.
- Recommendation on which fields must come from API enrichment rather than webhook payloads.
- Recommendation on which source identifiers stay restricted versus which tokenized identifiers are exposed to analytics.

### Acceptance Criteria

- [ ] Field inventory includes webhook and API sources separately.
- [ ] `tenant_id` and `pharmacy_id` requirements are documented.
- [ ] Restricted handling of real `RxNo` and `RefillNo` is documented.
- [ ] Tokenized prescription/fill reference strategy is documented.
- [ ] NDC availability is documented.
- [ ] BIN/PCN/payer availability is documented.
- [ ] Paid amount/copay/ingredient cost availability is documented.
- [ ] Pickup/refill field availability is documented.
- [ ] Rejection/reversal field availability is documented.
- [ ] PHI classification is completed.
- [ ] Missing fields required for revenue prediction are listed.
- [ ] Data engineer can use the matrix to design mappings and feature tables.

### Suggested Labels

`analytics`, `data-engineering`, `data-discovery`, `primerx`, `mvp`

---

## Task 12: Define Canonical Analytics Data Model

### Objective

Define the MVP canonical analytics schema that will support revenue analysis, refill/adherence analysis, and baseline forecasting without tying dashboards directly to raw PrimeRx webhook/API field names.

### Background

The webhook pipeline creates processed event records, but analytics requires stable dimensional and fact tables. The first version should focus on prescription/fill, payer, drug, prescriber, store, and financial facts. It should avoid storing direct patient identifiers in analytics tables.

### Proposed MVP Tables

Consider these tables for the first analytics model:

```text
dim_pharmacy
dim_drug
dim_payer
dim_prescriber
dim_patient_token
source_prescription_reference_restricted
fact_prescription_event
fact_claim_financial
fact_refill_activity
fact_daily_store_metrics
```

### Design Requirements

- Every table must include tenant/pharmacy isolation fields.
- Direct patient identifiers must be excluded.
- Real `RxNo` and `RefillNo` must be excluded from analytics-facing fact tables.
- Real `RxNo` and `RefillNo` may be stored in a restricted source-reference table used only by backend enrichment/reconciliation jobs.
- Analytics fact tables should use `prescription_reference_token` and `fill_reference_token`.
- Patient continuity, if required, must use an approved pseudonymous token.
- Raw PrimeRx payload fields must not leak into analytics tables.
- Fact tables must link back to source/audit records where useful.
- Nullable fields should be allowed where webhook data is incomplete and API enrichment is pending.

### Deliverables

- Schema proposal for dimensions and fact tables.
- Field definitions.
- Primary keys and foreign keys.
- Tenant/pharmacy isolation approach.
- PHI exclusion policy.
- Restricted source-reference table design for `tenant_id`, `pharmacy_id`, `RxNo`, and `RefillNo`.
- Prescription/fill token strategy.
- Mapping from canonical processed webhook event to analytics tables.
- List of fields requiring API enrichment.

### Acceptance Criteria

- [ ] MVP analytics tables are documented.
- [ ] Field definitions are documented.
- [ ] Tenant/pharmacy isolation is defined.
- [ ] PHI-excluded fields are listed.
- [ ] Patient token strategy is documented.
- [ ] Prescription/fill token strategy is documented.
- [ ] Restricted source-reference table for `tenant_id`, `pharmacy_id`, `RxNo`, and `RefillNo` is documented.
- [ ] Mapping from webhook/API data to analytics tables is documented.
- [ ] Required API enrichment fields are identified.
- [ ] Schema supports revenue, refill/adherence, and baseline forecasting use cases.

### Suggested Labels

`analytics`, `database`, `canonical-model`, `phi`, `mvp`

---

## Task 13: Define Data Quality And Reconciliation Rules

### Objective

Define the data quality and reconciliation checks needed before analytics and forecasting outputs can be trusted.

### Background

Webhook and API data can be incomplete, duplicated, delayed, out of order, or inconsistent with source-system reports. Before dashboards or ML models are built, the data engineer should define quality rules that catch issues early.

### Scope

Define rules for:

- Duplicate events.
- Missing required fields.
- Invalid dates.
- Out-of-order events.
- Impossible financial values.
- Unknown payer/drug/store mappings.
- Missing NDC/BIN/PCN when expected.
- Missing restricted source identifiers required for API enrichment.
- Reversal and rejection consistency.
- Daily volume anomalies.
- API/webhook reconciliation.

### Example Rules

- `RxNo` and `RefillNo` must exist for prescription-level events unless event type is patient-only.
- `event_timestamp` cannot be in the future beyond an allowed clock-skew window.
- `TotalInsPaid + PatientCopay` should not be negative.
- `DaysSupply` must be positive when present.
- `NDC` must match expected format when present.
- Duplicate idempotency keys should not create duplicate facts.
- Tokenized prescription/fill references should map back to a restricted source-reference record for backend enrichment only.
- Reversed claims should link to prior billed/filled claim where possible.
- Daily store event count should be compared against historical range.

### Deliverables

- Data quality rules document.
- Exception categories and severity.
- Proposed exception table or report shape.
- Reconciliation approach between webhook events, API reads, and future bulk/export reports.
- Sample SQL checks or pseudocode.

### Acceptance Criteria

- [ ] Required-field rules are documented.
- [ ] Financial sanity rules are documented.
- [ ] Date/timestamp rules are documented.
- [ ] Duplicate and idempotency checks are documented.
- [ ] Checks for missing `tenant_id`, `pharmacy_id`, `RxNo`, and `RefillNo` are documented where required by event type.
- [ ] Checks confirm analytics-facing outputs use tokenized references, not raw `RxNo`.
- [ ] Reversal/rejection checks are documented.
- [ ] Unknown mapping checks are documented.
- [ ] Exception reporting approach is documented.
- [ ] Daily reconciliation approach is documented.

### Suggested Labels

`analytics`, `data-quality`, `reconciliation`, `data-engineering`, `mvp`

---

## Task 14: Build Revenue Analytics Feature Mart

### Objective

Design and build the first revenue analytics feature mart for store, payer, drug, and prescription-level revenue analysis.

### Background

Revenue forecasting should not begin with complex ML. First, the team needs dashboard-ready and model-ready features derived from canonical prescription and claim financial records.

### Scope

Create SQL views or tables that calculate revenue and margin features by store, payer, drug, and time window.

### Feature Groups

Include features such as:

- RX count by tenant/store/day/payer/drug.
- Gross amount.
- Insurer paid amount.
- Patient copay.
- Total Rx amount.
- Ingredient cost.
- Estimated gross profit.
- Rejection count and rate.
- Reversal count and rate.
- Payer mix.
- Drug mix.
- Rolling 7/30/60/90-day metrics.
- Store-level daily and weekly totals.

### Notes

Do not call this final PBM/DIR prediction yet. True net revenue prediction may require additional data that is not confirmed available, including DIR fees, PBM adjustments, remittance reports, and acquisition cost accuracy.

### Deliverables

- Revenue feature mart schema or SQL views.
- Field definitions.
- Example output dataset.
- Sample queries for dashboards.
- Missing field report for true net revenue/clawback prediction.

### Acceptance Criteria

- [ ] Feature mart produces daily store-level revenue metrics.
- [ ] Feature mart produces payer-level revenue metrics.
- [ ] Feature mart produces drug-level revenue metrics.
- [ ] Rolling window metrics are available.
- [ ] Rejection/reversal metrics are included if source fields are available.
- [ ] Estimated gross profit logic is documented.
- [ ] Missing fields for true net revenue prediction are documented.
- [ ] Output is safe for analytics and excludes direct patient identifiers.
- [ ] Output uses tokenized prescription/fill references and does not expose raw `RxNo`.

### Suggested Labels

`analytics`, `data-engineering`, `revenue`, `feature-mart`, `mvp`

---

## Task 15: Build Refill And Adherence Feature Mart

### Objective

Design and build the first refill/adherence feature mart using PHI-minimized patient continuity tokens and prescription refill activity.

### Background

Refill behavior can indicate revenue erosion, but this area is PHI-sensitive. The MVP should avoid exposing direct patient identifiers and should start with tokenized patient continuity and store/drug-level aggregates.

### Scope

Create features for refill timing and adherence-like behavior using approved tokens and safe aggregates.

### Feature Groups

Include features such as:

- Tokenized patient continuity ID.
- Tenant ID.
- Store/pharmacy ID.
- Drug/NDC.
- Prescription/fill reference token.
- Days supply.
- Expected refill date.
- Actual refill/pickup date.
- Refill lag days.
- Refill lag variance.
- Refill count.
- Refills remaining.
- Maintenance medication flag if available.
- Store/drug-level refill lag aggregates.
- Store/drug-level adherence trend metrics.

### PHI Rules

- Do not store patient name, DOB, phone, address, email, insurance member ID, or notes.
- Use only approved patient tokens or hashed identifiers.
- Prefer store/drug-level aggregates for early dashboard work.
- Patient-level predictions should be deferred until compliance and access rules are approved.

### Deliverables

- Refill/adherence feature schema or SQL views.
- Field definitions.
- PDC/refill lag calculation proposal.
- Sample aggregate outputs.
- List of data gaps that affect adherence modeling.

### Acceptance Criteria

- [ ] Refill feature mart excludes direct patient identifiers.
- [ ] Refill feature mart excludes raw `RxNo` and uses prescription/fill reference tokens.
- [ ] Patient continuity uses approved token strategy.
- [ ] Expected refill date logic is documented.
- [ ] Refill lag calculation is documented.
- [ ] Store/drug-level aggregate outputs are available.
- [ ] Data gaps for adherence prediction are documented.
- [ ] Output is safe for analytics use.

### Suggested Labels

`analytics`, `data-engineering`, `refill`, `adherence`, `phi`, `mvp`

---

## Task 16: Build Baseline Forecasting Proof Of Concept

### Objective

Build a baseline forecasting proof of concept using the revenue and refill feature marts before investing in full SageMaker ML infrastructure.

### Background

The first forecasting goal should be simple, measurable, and explainable. This task should prove whether available data can support useful predictions before moving to SageMaker Feature Store, complex ML pipelines, or serverless model endpoints.

### MVP Forecast Targets

Start with one or more of:

- Store-level daily revenue forecast.
- Store-level weekly revenue forecast.
- Store-level RX volume forecast.
- Payer-level revenue trend.
- Rejection/reversal trend.
- Refill lag / missed refill trend.

### Modeling Approach

Start with simple baselines:

- Moving average.
- Same-day-of-week seasonal average.
- Simple regression or tree-based model if enough rows exist.

Do not start with complex patient-level adherence prediction or PBM clawback prediction unless source data proves adequate.

### Deliverables

- Training dataset definition.
- Forecast target definition.
- Baseline model notebook or script.
- Evaluation metrics.
- Feature importance or driver summary where available.
- Recommendation on next modeling step.

### Acceptance Criteria

- [ ] Forecast target is clearly defined.
- [ ] Training dataset is generated from approved feature marts.
- [ ] Baseline model is implemented.
- [ ] Baseline forecast metrics are reported.
- [ ] Forecast output is compared against actuals.
- [ ] Limitations and missing data are documented.
- [ ] Recommendation is made on whether SageMaker/Feature Store is needed next.

### Suggested Labels

`analytics`, `forecasting`, `ml`, `data-engineering`, `mvp`
