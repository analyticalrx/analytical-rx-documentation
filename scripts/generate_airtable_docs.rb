#!/usr/bin/env ruby
# Generate the consolidated Airtable documentation set.

require "cgi"
require "fileutils"
require "json"

SCHEMA_PATH = ARGV[0] || "/tmp/analyticalrx_airtable_schema.json"
PAGES_PATH = ARGV[1] || "/tmp/analyticalrx_airtable_pages.json"
OUTPUT_DIR = "airtable"
SCREENSHOT_DIR = "assets/automation-screenshots"

schema = JSON.parse(File.read(SCHEMA_PATH))
pages = JSON.parse(File.read(PAGES_PATH))
FileUtils.mkdir_p(File.join(OUTPUT_DIR, SCREENSHOT_DIR))

def h(value)
  CGI.escapeHTML(value.to_s)
end

def code(value)
  "<code>#{h(value)}</code>"
end

def list(items)
  "<ul>\n#{items.map { |item| "        <li>#{item}</li>" }.join("\n")}\n      </ul>"
end

def ordered_list(items)
  "<ol>\n#{items.map { |item| "        <li>#{item}</li>" }.join("\n")}\n      </ol>"
end

def common_css(extra = "")
  <<~CSS
    :root {
      --ink: #1f2933;
      --muted: #5f6c7b;
      --line: #d9e2ec;
      --panel: #f8fafc;
      --code: #eef2f7;
      --accent: #0f766e;
      --accent-soft: #ccfbf1;
      --warn: #9a3412;
      --warn-soft: #ffedd5;
      --risk: #b91c1c;
      --risk-soft: #fee2e2;
    }

    body {
      margin: 0;
      font-family: Georgia, "Times New Roman", serif;
      color: var(--ink);
      background: #ffffff;
      line-height: 1.56;
    }

    main {
      max-width: 1240px;
      margin: 0 auto;
      padding: 44px 24px 72px;
    }

    nav {
      margin-bottom: 28px;
      font-family: Arial, sans-serif;
      font-size: 14px;
    }

    nav a,
    a {
      color: var(--accent);
    }

    nav a {
      text-decoration: none;
      font-weight: 700;
    }

    header {
      max-width: 980px;
      padding-bottom: 22px;
      border-bottom: 1px solid var(--line);
    }

    h1 {
      margin: 0 0 10px;
      font-size: 34px;
      line-height: 1.15;
      letter-spacing: 0;
    }

    h2 {
      margin: 34px 0 12px;
      font-size: 23px;
      line-height: 1.25;
      letter-spacing: 0;
    }

    h3 {
      margin: 24px 0 10px;
      font-size: 18px;
      line-height: 1.25;
      letter-spacing: 0;
    }

    p {
      margin: 0 0 13px;
    }

    ul,
    ol {
      margin: 0 0 18px;
      padding-left: 24px;
    }

    li {
      margin: 5px 0;
    }

    code {
      padding: 2px 5px;
      border-radius: 4px;
      background: var(--code);
      font-family: "SFMono-Regular", Consolas, monospace;
      font-size: 0.92em;
    }

    table {
      width: 100%;
      border-collapse: collapse;
      margin: 18px 0;
      font-size: 13px;
    }

    th,
    td {
      border: 1px solid var(--line);
      padding: 8px 10px;
      vertical-align: top;
    }

    th {
      background: var(--panel);
      text-align: left;
    }

    .lead {
      color: var(--muted);
      font-size: 18px;
    }

    .meta {
      color: var(--muted);
      font-size: 14px;
    }

    .callout {
      margin: 16px 0;
      padding: 14px 18px;
      border-left: 4px solid var(--accent);
      border-radius: 6px;
      background: var(--accent-soft);
    }

    .warn {
      border-left-color: var(--warn);
      background: var(--warn-soft);
    }

    .risk {
      border-left-color: var(--risk);
      background: var(--risk-soft);
    }

    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: 14px;
    }

    .link-card {
      display: block;
      min-height: 112px;
      padding: 18px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--panel);
      text-decoration: none;
      color: var(--ink);
    }

    .link-card:hover {
      border-color: var(--accent);
      box-shadow: 0 8px 24px rgba(15, 118, 110, 0.12);
    }

    .link-card strong {
      display: block;
      margin-bottom: 8px;
      font-size: 17px;
    }

    .link-card span {
      display: block;
      color: var(--muted);
      font-size: 14px;
    }

    .badge,
    .tag {
      display: inline-block;
      margin-bottom: 10px;
      padding: 3px 8px;
      border-radius: 999px;
      background: var(--accent-soft);
      color: var(--accent);
      font-family: Arial, sans-serif;
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
    }

    .tag {
      margin: 0 0 0 6px;
    }

    .badge.secondary,
    .tag.warn {
      background: var(--warn-soft);
      color: var(--warn);
      border-left: 0;
    }

    .tag.risk {
      background: var(--risk-soft);
      color: var(--risk);
      border-left: 0;
    }

    .diagram {
      padding: 14px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--panel);
    }

    .diagram img,
    .screenshot img {
      display: block;
      width: 100%;
      height: auto;
    }

    .screenshot {
      margin: 18px 0;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--panel);
      overflow: hidden;
    }

    .screenshot figcaption {
      padding: 10px 12px;
      font-family: Arial, sans-serif;
      font-size: 13px;
      color: var(--muted);
    }

    .toc {
      columns: 2;
      column-gap: 36px;
      font-family: Arial, sans-serif;
      font-size: 14px;
    }

    @media (max-width: 760px) {
      .toc {
        columns: 1;
      }

      table {
        font-size: 12px;
      }
    }
    #{extra}
  CSS
end

def document(title, lead, body, extra_css = "")
  <<~HTML
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>#{h(title)}</title>
      <style>
    #{common_css(extra_css)}
      </style>
    </head>
    <body>
      <main>
        <nav><a href="../index.html">Back to design index</a> | <a href="index.html">Airtable docs</a></nav>
        <header>
          <h1>#{h(title)}</h1>
          <p class="lead">#{h(lead)}</p>
        </header>
    #{body}
      </main>
    </body>
    </html>
  HTML
end

TABLE_PURPOSES = {
  "Pharmacies" => "Store master record and central hub for most operational, compliance, financial, and dashboard data.",
  "People" => "Staff directory, user-role source, assignee lookup, and notification recipient source.",
  "Tasks" => "Operational task tracking across stores, compliance, onboarding, reporting, and recurring work.",
  "Compliance Items" => "Compliance requirement tracker with due dates, owners, documents, and renewal behavior.",
  "Compliance Logs" => "Operational compliance log entries such as counts, temperatures, exceptions, and supporting documents.",
  "SOPs" => "Standard operating procedure library with versioning, owner, status, scope, and attachments.",
  "SOP Acknowledgments" => "Employee acknowledgment tracking for SOP versions and due dates.",
  "Documents" => "Document metadata, attachments, permission levels, expiration dates, and compliance links.",
  "Doctor Offices" => "Prescriber office CRM for outreach stage, assigned rep, follow-up, referral status, and lapse risk.",
  "Doctor Visits" => "Visit history and next-action tracking for doctor office outreach.",
  "Employee Licenses" => "Employee credential and license expiration tracking.",
  "Vendors" => "Vendor contacts, contracts, renewal dates, spend, and performance tracking.",
  "Financial Periods" => "Monthly financial performance facts and calculated margins by store.",
  "Rx Metrics" => "Monthly pharmacy operations metrics by store.",
  "AR Aging" => "Accounts receivable aging by payer and month.",
  "Onboarding Steps" => "New store onboarding checklist records.",
  "KPI Scorecard" => "Target versus actual KPI tracking and dashboard source data.",
  "Task Templates" => "Reusable task definitions for scheduled task generation.",
  "Daily Sales" => "Daily store sales, prescription volume, vaccine count, and front-end sales snapshot."
}.freeze

MODULES = [
  ["Store and staff master data", "Pharmacies, People", "Tenant, pharmacy/store, and staff/user models. Most records hang off a pharmacy and often a person."],
  ["Task management", "Tasks, Task Templates, Onboarding Steps", "Assigned tasks, due dates, priority, status, recurrence/templates, proof documents, and store-specific views."],
  ["Compliance operations", "Compliance Items, Compliance Logs, Employee Licenses", "Due dates, owners, renewal tracking, license data, cost, logs, exceptions, and reminders."],
  ["SOP and document control", "SOPs, SOP Acknowledgments, Documents", "Secure file metadata, SOP versioning, acknowledgment tracking, and document expiration reminders."],
  ["Doctor outreach / local growth", "Doctor Offices, Doctor Visits", "CRM-style workflow for prescriber offices, visits, follow-ups, referral status, and assigned reps."],
  ["Vendor and contract tracking", "Vendors", "Vendor contracts, contacts, renewal dates, annual value, auto-renew flags, and ratings."],
  ["Financial and KPI reporting", "Financial Periods, Rx Metrics, AR Aging, KPI Scorecard, Daily Sales", "Starter dashboard inputs that can later be replaced or enriched from PrimeRx API, webhooks, SFTP, POS, or accounting feeds."]
].freeze

AUTOMATIONS = [
  {
    id: "auto-01",
    screenshot: "airtable-automation-01.png",
    name: "Copy Values from Financial Periods/Rx Metrics to KPI Scorecard",
    confidence: "Medium",
    status: "OFF",
    trigger: "When a record is created in Financial Periods.",
    observed_actions: "Find matching Rx Metrics records using Store and Month, then create a KPI Scorecard record. The exact target field mapping is not visible.",
    intent: "When monthly financial data is entered or imported for a pharmacy, automatically prepare KPI scorecard records so dashboards can show revenue, margin, DIR fee, payroll, and prescription performance without manual copying.",
    tables: "Financial Periods, Rx Metrics, KPI Scorecard, Pharmacies",
    trigger_type: "Record-created event plus a manual re-sync button for a month/store. Later, update-triggered recalculation should also be supported.",
    idempotency: "tenant_id + pharmacy_id + month + kpi_name. Use upsert, not blind insert.",
    mappings: [
      "Monthly Revenue: Financial Periods.Total Revenue or sum of revenue fields.",
      "Rx Volume: likely Rx Metrics.New Rx + Rx Metrics.Refills. Confirm exact meaning.",
      "Gross Margin %: Financial Periods.Gross Margin %.",
      "EBITDA Margin %: likely Financial Periods.EBITDA / Financial Periods.Total Revenue.",
      "Payroll % of Revenue: likely Financial Periods.Payroll / Financial Periods.Total Revenue.",
      "DIR Fees %: likely Financial Periods.DIR Fees / Financial Periods.Total Revenue or Rx Metrics.DIR Fees / Rx Revenue. Confirm denominator.",
      "New Rx Patients: not directly present. Rx Metrics.New Rx may not mean unique new patients.",
      "New Active Offices: may require Doctor Offices data, not Financial Periods/Rx Metrics."
    ],
    implementation: [
      "Load the related pharmacy and month when a financial period is created.",
      "Find matching Rx Metrics by same tenant, pharmacy, and month.",
      "Create or update one KPI Scorecard row per KPI definition unless the client confirms Airtable only uses one generic row.",
      "Calculate Actual, Target, Variance, Variance %, Status, Prior Period Actual, and Growth % in backend code or database logic.",
      "If matching Rx Metrics is missing, create financial-only KPI rows and log missing Rx dependencies, or skip Rx-dependent KPIs based on product decision.",
      "Keep formula ownership in the application, not in the dashboard layer."
    ],
    validation: [
      "Exact Airtable create-record field mapping for KPI Scorecard.",
      "Whether the automation creates one KPI row or multiple KPI rows per month/store.",
      "Target values and thresholds for On Track, Needs Attention, and Off Track.",
      "Whether updates to Financial Periods or Rx Metrics should re-run the sync."
    ]
  },
  {
    id: "auto-02",
    screenshot: "airtable-automation-02.png",
    name: "New-Store Onboarding Auto-Clone",
    confidence: "Medium",
    status: "OFF",
    trigger: "When a record matches conditions. The source table is not visible, but intent suggests Pharmacies or Onboarding Steps.",
    observed_actions: "Find records where New Store is empty, repeat for each record, then create records in Onboarding Steps.",
    intent: "When a pharmacy enters onboarding, clone a standard checklist of onboarding steps for that specific store.",
    tables: "Pharmacies, Onboarding Steps, People",
    trigger_type: "Record-created or status-changed rule on pharmacy/store. Clean trigger: pharmacy status changes to Onboarding.",
    idempotency: "tenant_id + pharmacy_id + onboarding_template_id, or tenant_id + pharmacy_id + step_title + sequence.",
    mappings: [
      "Onboarding Steps.Step Title copies from template step title.",
      "Onboarding Steps.New Store links to the newly onboarding pharmacy.",
      "Category, Sequence, Document, and Notes copy from the template row.",
      "Status defaults to Not Started.",
      "Assignee should resolve from role/store rules.",
      "Due Date should be calculated from onboarding start date plus an offset; current Airtable table does not expose a clear offset field."
    ],
    implementation: [
      "Separate reusable onboarding templates from generated store-specific onboarding steps.",
      "Provide a manual Generate onboarding checklist action in addition to the automatic trigger.",
      "Prevent duplicate checklist generation for the same store/template version.",
      "Log skipped templates when no responsible user can be resolved.",
      "Allow admins to regenerate missing steps without deleting completed steps."
    ],
    validation: [
      "Exact source table and trigger condition.",
      "How template rows are identified today. New Store is empty appears to be the template marker.",
      "Whether due dates are copied, calculated, or manually filled after clone.",
      "Whether onboarding applies to all pharmacies or only pharmacies with status Onboarding."
    ]
  },
  {
    id: "auto-03",
    screenshot: "airtable-automation-03.png",
    name: "Monday Owner Digest Email",
    confidence: "Medium",
    status: "OFF",
    trigger: "Every week on Monday at 5:15 PM IST.",
    observed_actions: "Five find-record actions followed by a send-email action. Visible searches include overdue tasks, upcoming due items, off-track KPI records, and expiration records.",
    intent: "Send owners a weekly summary of operational risk, compliance risk, task backlog, KPI exceptions, and expiring business records.",
    tables: "Tasks, Compliance Items, KPI Scorecard, Documents, Employee Licenses, Vendors, People, Pharmacies",
    trigger_type: "Weekly scheduled tenant job.",
    idempotency: "tenant_id + automation_key + monday_date + recipient_user_id.",
    mappings: [
      "Overdue tasks: Due Date before today and status not complete/cancelled.",
      "Upcoming tasks or compliance items: records due within the configured upcoming window. Screenshot appears to show a 30-day condition, but it is truncated.",
      "Off-track KPIs: KPI Scorecard rows where Status is Off Track.",
      "Expiring documents: Documents where Expiration Date is within the configured threshold.",
      "Expiring employee licenses: Employee Licenses where Expiration Date is within the configured threshold.",
      "Expiring vendor contracts: Vendors where Contract End is within the configured threshold."
    ],
    implementation: [
      "Generate one digest per tenant, or one per owner/admin if owners only manage certain stores.",
      "Group results by store and then by category.",
      "Include counts and top urgent items in the email body. Link each item back to the app.",
      "Store rendered digest metadata in notification history for audit and resend.",
      "Do not send empty digests unless the client wants a nothing-due confirmation.",
      "Use a configurable tenant timezone and send time. Do not hard-code IST."
    ],
    validation: [
      "Exact five Airtable find-record queries.",
      "Email subject/body and whether the owner digest is one email or multiple emails.",
      "Who should receive it: owner/admins, operations managers, bookkeepers, store managers, or another group.",
      "Whether the digest should include all stores or only stores assigned to each recipient."
    ]
  },
  {
    id: "auto-04",
    screenshot: "airtable-automation-04.png",
    name: "KPI Status Alert and Notification",
    confidence: "Medium",
    status: "OFF",
    trigger: "When a record matches conditions where Status is Off Track.",
    observed_actions: "Find people where Role is Operations Manager, then send an email.",
    intent: "Alert the operations team when a KPI becomes off track so the issue can be reviewed before the next owner digest.",
    tables: "KPI Scorecard, People, Pharmacies",
    trigger_type: "Record state-change rule on KPI Scorecard status.",
    idempotency: "tenant_id + kpi_scorecard_id + status + status_changed_at_date + recipient_user_id.",
    mappings: [
      "Recipient lookup: People.Role includes Operations Manager.",
      "Alert context: KPI, Store, Month, Actual, Target, Variance, Variance %, Status."
    ],
    implementation: [
      "Trigger only on transition into Off Track, not on every save while already off track.",
      "Resolve recipients by role and store visibility.",
      "Include KPI name, store, month, actual, target, variance, and dashboard link.",
      "Throttle notifications so one bad import does not send many duplicate emails.",
      "Add alert history on the KPI record or in a notification log."
    ],
    validation: [
      "Whether Needs Attention should also notify or only Off Track.",
      "Whether alerts go to operations managers, owners, store managers, or all of them.",
      "Whether the Airtable warning icon means the recipient lookup is currently broken."
    ]
  },
  {
    id: "auto-05",
    screenshot: "airtable-automation-05.png",
    name: "Doctor Office Follow-Up Notification",
    confidence: "Medium",
    status: "OFF",
    trigger: "When a record matches conditions where Next Follow-up is today.",
    observed_actions: "Find a person where Full Name matches Assigned Rep, then send an email.",
    intent: "Remind the assigned representative to follow up with a doctor office on the scheduled follow-up date.",
    tables: "Doctor Offices, Doctor Visits, People, Pharmacies",
    trigger_type: "Daily scheduled reminder or record state rule. Scheduled reminder is safer for date-based triggers.",
    idempotency: "tenant_id + doctor_office_id + follow_up_date + recipient_user_id.",
    mappings: [
      "Doctor Offices.Assigned Rep should become a user/person reference, not a string name match.",
      "Reminder context: office name, doctor name, specialty, store, last visit date, next action, next follow-up."
    ],
    implementation: [
      "Send only when Next Follow-up equals today in tenant timezone.",
      "After a visit is logged, update the office's next follow-up date from the Doctor Visit record.",
      "Track notification history so repeated same-day reminders do not spam the representative.",
      "Support escalation if follow-up becomes overdue."
    ],
    validation: [
      "Whether the source record is Doctor Offices or Doctor Visits.",
      "Whether reminders send at start of day, exact time, or immediately when Next Follow-up becomes today.",
      "Whether reminders should also notify a manager if overdue."
    ]
  },
  {
    id: "auto-06",
    screenshot: "airtable-automation-06.png",
    name: "Lapse Risk Alert Automation",
    confidence: "Medium",
    status: "OFF",
    trigger: "When a record matches conditions where Lapse Risk is At Risk.",
    observed_actions: "Find records related to Assigned Rep, then send an email. The find-record label is truncated and ambiguous.",
    intent: "Alert the assigned representative or manager when a doctor office relationship is at risk of lapsing.",
    tables: "Doctor Offices, Doctor Visits, People, Tasks",
    trigger_type: "Record state-change rule on Doctor Office lapse risk plus a scheduled daily reconciliation job to catch formula-derived changes.",
    idempotency: "tenant_id + doctor_office_id + lapse_risk_status + recipient_user_id + alert_period.",
    mappings: [
      "Likely risk inputs: Last Visit Date, Days Since Last Visit, Lapse Risk, Assigned Rep, Est Monthly Rx.",
      "Recipient lookup: assigned rep and optionally store manager or operations manager."
    ],
    implementation: [
      "Define lapse risk explicitly in software instead of relying on hidden Airtable formulas.",
      "Trigger only when risk moves from normal to At Risk, or once per configured reminder period while still at risk.",
      "Email should include office, doctor, store, last visit date, days since last visit, estimated monthly Rx, and next recommended action.",
      "Consider creating a follow-up task automatically if no open task already exists."
    ],
    validation: [
      "Exact formula for Lapse Risk.",
      "Whether alert recipients are assigned reps, managers, or both.",
      "Whether an automatic task should be created or only email should be sent.",
      "Whether the warning icon indicates a broken recipient lookup."
    ]
  },
  {
    id: "auto-07",
    screenshot: "airtable-automation-07.png",
    name: "Compliance to Unified Calendar Feed",
    confidence: "High",
    status: "OFF",
    trigger: "When a record is created in Compliance Items.",
    observed_actions: "Create a record in Tasks.",
    intent: "Every compliance requirement should become a trackable task/calendar item so it appears in operational views and reminders.",
    tables: "Compliance Items, Tasks, People, Pharmacies",
    trigger_type: "Record-created rule on Compliance Items.",
    idempotency: "tenant_id + compliance_item_id + task_source.",
    mappings: [
      "Tasks.Title: Compliance Items.Requirement.",
      "Tasks.Description: issuing authority, license number, renewal lead time, cost, and notes when present.",
      "Tasks.Store: Compliance Items.Store.",
      "Tasks.Category: Compliance.",
      "Tasks.Priority: default based on due date or category.",
      "Tasks.Status: Open or To Do. We should choose one canonical status.",
      "Tasks.Assignee: Compliance Items.Owner.",
      "Tasks.Due Date: Compliance Items.Due Date.",
      "Tasks.Recurrence: Compliance Items.Frequency.",
      "Tasks.Source: Compliance."
    ],
    implementation: [
      "Create the compliance task immediately after compliance item creation.",
      "If owner is empty, route to a tenant compliance admin queue instead of failing silently.",
      "When the compliance item due date changes, decide whether to update the linked task due date.",
      "Keep a direct source reference from task to compliance item."
    ],
    validation: [
      "Exact Airtable field mappings for created task.",
      "Whether a compliance item creates one task only or recurring future tasks too.",
      "Whether this feeds an actual calendar integration or just Airtable task dashboards."
    ]
  },
  {
    id: "auto-08",
    screenshot: "airtable-automation-08.png",
    name: "Scheduled Task Generation from Templates",
    confidence: "Medium",
    status: "OFF",
    trigger: "Every day at 11:30 AM IST.",
    observed_actions: "Find task templates from a grid view, repeat over each record, find active stores, find people by responsible role, then create records in Tasks.",
    intent: "Generate routine operational tasks from reusable task templates.",
    tables: "Task Templates, Tasks, Pharmacies, People",
    trigger_type: "Daily scheduled tenant job.",
    idempotency: "tenant_id + template_id + pharmacy_id + scheduled_period_start.",
    mappings: [
      "Process templates where Template Active is checked.",
      "If Store Scope is All Stores, generate one task per active pharmacy.",
      "Resolve assignee by Responsible Role and store assignment.",
      "Calculate due date as scheduled date plus Days Offset.",
      "Set task title, description, category, priority, recurrence/frequency, and source from the template."
    ],
    implementation: [
      "Use a recurrence engine so daily/weekly/monthly/quarterly/annual templates generate in the correct period.",
      "Maintain a generated-task link back to the template.",
      "Before creating a task, check for an existing task for the same template, store, and period.",
      "If multiple users match the responsible role, assignment behavior needs product confirmation.",
      "If no user matches the responsible role, create the task unassigned and log a configuration warning."
    ],
    validation: [
      "Exact grid view used by Airtable's first find-record action.",
      "Whether the job runs daily but only creates tasks on frequency boundaries.",
      "Whether templates are global, tenant-specific, or store-specific.",
      "Exact behavior for missed runs and backfills."
    ]
  },
  {
    id: "auto-09",
    screenshot: "airtable-automation-09.png",
    name: "Compliance due soon notification",
    confidence: "Medium",
    status: "OFF",
    trigger: "Every day at 12:30 PM IST.",
    observed_actions: "Find compliance records where due date is on or before a configured day threshold, repeat over records, find related owner/assignee records, then send an email.",
    intent: "Notify responsible users when compliance requirements are due soon or due now.",
    tables: "Compliance Items, People, Pharmacies, Tasks",
    trigger_type: "Daily scheduled tenant job.",
    idempotency: "tenant_id + compliance_item_id + due_date + reminder_stage + recipient_user_id.",
    mappings: [
      "Use Renewal Lead Time Days when present; otherwise use a tenant default.",
      "Include Requirement, Store, Category, Due Date, Owner, and item/task link.",
      "Exclude Completed and N/A statuses."
    ],
    implementation: [
      "Send reminders for On Track, Due Soon, or Overdue records.",
      "Escalate overdue items after a configurable number of days.",
      "Update status to Due Soon or Overdue through a separate calculation rule if needed.",
      "Avoid duplicate emails for the same compliance item and reminder stage."
    ],
    validation: [
      "Exact due-soon threshold. Screenshot text is truncated.",
      "Whether notification goes to Compliance Item Owner, store manager, operations manager, or all.",
      "Whether compliance reminders should create tasks, send email only, or both."
    ]
  },
  {
    id: "auto-10",
    screenshot: "airtable-automation-10.png",
    name: "Document/license expiring - weekly",
    confidence: "Medium",
    status: "OFF",
    trigger: "Every week on Monday at 12:30 PM IST.",
    observed_actions: "Find documents expiring before a 60-day threshold, find licenses expiring by another threshold, find vendor contracts ending by a threshold, then send an email.",
    intent: "Give owners/operators a weekly view of expiring business-critical documents, employee licenses, and vendor contracts.",
    tables: "Documents, Employee Licenses, Vendors, People, Pharmacies",
    trigger_type: "Weekly scheduled tenant job.",
    idempotency: "tenant_id + automation_key + monday_date + recipient_user_id.",
    mappings: [
      "Documents: Expiration Date and Permission Level.",
      "Employee Licenses: Expiration Date, License Type, Status, Employee.",
      "Vendors: Contract End, Vendor Name, Store, Auto-Renew, Annual Value."
    ],
    implementation: [
      "Use configurable thresholds by record type.",
      "Group output by store and source table.",
      "Highlight expired records separately from expiring-soon records.",
      "Respect document permission level when linking records in email.",
      "Include auto-renew vendor contracts but clearly mark them.",
      "Consider creating renewal tasks automatically if the client wants enforcement, not just reminders."
    ],
    validation: [
      "Exact thresholds for each source table.",
      "Recipients and whether they vary by store.",
      "Whether document permissions affect who can receive links."
    ]
  },
  {
    id: "auto-11",
    screenshot: "airtable-automation-11.png",
    name: "Task overdue - daily notification",
    confidence: "Medium",
    status: "OFF",
    trigger: "Every day at 12:30 PM IST.",
    observed_actions: "Find tasks where due date is before today and other status filters apply, repeat over each record, find assignee records, then send an email.",
    intent: "Remind assignees or managers about tasks that are past due and still open.",
    tables: "Tasks, People, Pharmacies",
    trigger_type: "Daily scheduled tenant job.",
    idempotency: "tenant_id + task_id + overdue_date + recipient_user_id.",
    mappings: [
      "Active statuses: likely Open, To Do, In Progress, and Blocked.",
      "Excluded statuses: Done, Completed, and Cancelled.",
      "Email context: title, store, category, priority, due date, overdue days, app link."
    ],
    implementation: [
      "Send to assigned users first.",
      "Escalate to store manager or operations manager after a configured number of overdue days.",
      "Use notification history to avoid repeat emails more frequently than intended.",
      "For unassigned overdue tasks, route to store manager or operations queue."
    ],
    validation: [
      "Exact status filter in Airtable.",
      "Whether blocked tasks notify assignees, managers, or both.",
      "Whether reminders continue every day until completed."
    ]
  },
  {
    id: "auto-12",
    screenshot: "airtable-automation-12.png",
    name: "Recurring Task Generator",
    confidence: "Medium",
    status: "OFF",
    trigger: "When a task record matches conditions where Status is Done and Recurrence is set.",
    observed_actions: "Find records where Task Title or Title matches, then create a record in Tasks.",
    intent: "When a recurring task is completed, create the next instance automatically.",
    tables: "Tasks, Task Templates",
    trigger_type: "Record state-change rule on Task completion.",
    idempotency: "tenant_id + completed_task_id + recurrence + next_due_date.",
    mappings: [
      "Daily: next due date is current due date plus 1 day.",
      "Weekly: next due date is current due date plus 1 week.",
      "Monthly: next due date is same day next month, with end-of-month handling.",
      "Quarterly: next due date is plus 3 months.",
      "Annual or Yearly: next due date is plus 1 year.",
      "Biennial: next due date is plus 2 years.",
      "One-time or None: do not generate a next task."
    ],
    implementation: [
      "Trigger only once when task transitions into completed state.",
      "Copy title, description, store, category, priority, assignee, recurrence, source, and related links.",
      "Set new task status to Open or To Do.",
      "Do not copy proof-of-completion attachments to the next task unless requested.",
      "Link previous and next tasks so users can view recurrence history.",
      "Prevent duplicate next tasks if a completed task is edited again."
    ],
    validation: [
      "Whether Airtable finds a Task Template row or an existing Task row before creating the next task.",
      "Whether next due date is based on completed date or original due date.",
      "Whether recurrence stops after a configured end date or count."
    ]
  },
  {
    id: "auto-13",
    screenshot: "airtable-automation-13.png",
    name: "Task Completion Update",
    confidence: "Low",
    status: "OFF",
    trigger: "When a task record matches conditions where Status is Done.",
    observed_actions: "Update record: Status. The screenshot does not show the new value or any other field update.",
    intent: "Ambiguous. It may normalize task status, stamp completion metadata, or update a related task/status field.",
    tables: "Tasks",
    trigger_type: "Record state-change rule on Task status.",
    idempotency: "tenant_id + task_id + completion_status_transition.",
    mappings: [
      "If task is marked Done, set Completed At to current date/time if empty.",
      "If Airtable uses both Done and Completed, normalize to one canonical completed status.",
      "If a task has related tasks, confirm whether completing one task should update a parent or linked task."
    ],
    implementation: [
      "Do not implement a rule that simply says when Status is Done, update Status without confirming the intended new value.",
      "Use a transition guard so the rule only fires when status changes from non-complete to complete.",
      "Write completion actor, completed timestamp, and source of update in audit logs."
    ],
    validation: [
      "Exact update-record field mapping.",
      "Whether the action sets Completed At, changes Done to Completed, or updates another linked record.",
      "Whether this automation overlaps with Recurring Task Generator."
    ]
  },
  {
    id: "auto-14",
    screenshot: "airtable-automation-14.png",
    name: "Daily Task Due Email Notification",
    confidence: "Medium",
    status: "OFF",
    trigger: "Every day at 2:30 PM IST.",
    observed_actions: "Find tasks where due date is today and status filters apply, repeat over each task, find assignee records, then send an email.",
    intent: "Remind assigned users about tasks due today.",
    tables: "Tasks, People, Pharmacies",
    trigger_type: "Daily scheduled tenant job.",
    idempotency: "tenant_id + task_id + due_date + recipient_user_id.",
    mappings: [
      "Find tasks where Due Date equals today in tenant timezone.",
      "Exclude completed/cancelled tasks.",
      "Send to assignees. If no assignee exists, route to store manager or operations queue.",
      "Email context: title, store, category, priority, due date, app link."
    ],
    implementation: [
      "Do not send both due-today and overdue emails for the same task on the same day.",
      "Consider batching multiple due-today tasks for the same recipient into one email.",
      "Use configurable send time per tenant.",
      "Write delivery attempts and suppression decisions to notification history."
    ],
    validation: [
      "Exact status filter in Airtable.",
      "Whether notification should happen at 2:30 PM or earlier in the user's workday.",
      "Whether multiple tasks should be sent as one digest or one email per task."
    ]
  }
].freeze

def table_by_id(schema)
  schema.fetch("tables").to_h { |table| [table.fetch("id"), table] }
end

def field_type_detail(field, tables_by_id)
  type = field.fetch("type")
  options = field["options"] || {}
  case type
  when "singleSelect", "multipleSelects"
    choices = Array(options["choices"]).map { |choice| choice["name"] }.compact
    choices.empty? ? type : "#{type}: #{choices.join(", ")}"
  when "multipleRecordLinks"
    linked = tables_by_id.dig(options["linkedTableId"], "name") || options["linkedTableId"]
    linked ? "#{type}: links to #{linked}" : type
  else
    type
  end
end

def field_name(tables_by_id, table_id, field_id)
  table = tables_by_id[table_id]
  return field_id unless table

  field = table.fetch("fields", []).find { |candidate| candidate["id"] == field_id }
  field ? field["name"] : field_id
end

def table_name(tables_by_id, table_id)
  tables_by_id.dig(table_id, "name") || table_id
end

def visible_fields(page, element)
  tables_by_id = page.fetch("tablesByTableId", {})
  element.fetch("visibleFieldIdsByTableId", {}).flat_map do |table_id, field_ids|
    field_ids.map do |field_id|
      "#{table_name(tables_by_id, table_id)}.#{field_name(tables_by_id, table_id, field_id)}"
    end
  end
end

def aggregation_summary(page, element)
  config = element["config"] || {}
  tables_by_id = page.fetch("tablesByTableId", {})

  case element["elementType"]
  when "bigNumber"
    if config["summaryType"] == "rowCount"
      "Record count"
    elsif config["fieldId"]
      field = field_name(tables_by_id, element["sourceTableId"], config["fieldId"])
      "#{config["summaryFunction"] || "summary"} of #{field}"
    else
      config["summaryType"].to_s
    end
  when "chart"
    x_axis = config["xAxisFieldId"] ? field_name(tables_by_id, element["sourceTableId"], config["xAxisFieldId"]) : nil
    slice = config["sliceFieldId"] ? field_name(tables_by_id, element["sourceTableId"], config["sliceFieldId"]) : nil
    y_axis = Array(config["yAxisAggregations"]).map do |aggregation|
      if aggregation["type"] == "rowCount"
        "record count"
      else
        field = field_name(tables_by_id, element["sourceTableId"], aggregation["fieldId"])
        "#{aggregation["function"] || aggregation["type"]} of #{field}"
      end
    end
    parts = []
    parts << "#{config["chartType"]} chart"
    parts << "x-axis: #{x_axis}" if x_axis
    parts << "slice: #{slice}" if slice
    parts << "measure: #{y_axis.join(", ")}" unless y_axis.empty?
    parts << "date bucket: #{config["dateBucketUnit"]}" if config["dateBucketUnit"]
    parts.join("; ")
  when "pivotTable"
    row = config.dig("rowDimension", "fieldId") ? field_name(tables_by_id, element["sourceTableId"], config.dig("rowDimension", "fieldId")) : nil
    column = config.dig("columnDimension", "fieldId") ? field_name(tables_by_id, element["sourceTableId"], config.dig("columnDimension", "fieldId")) : nil
    summary = if config["summary"] && config.dig("summary", "fieldId")
      "#{config.dig("summary", "function")} of #{field_name(tables_by_id, element["sourceTableId"], config.dig("summary", "fieldId"))}"
    else
      "record count or configured summary"
    end
    "pivot table; rows: #{row || "none"}; columns: #{column || "none"}; summary: #{summary}"
  when "levels"
    "record list / hierarchy"
  else
    config["type"] || element["elementType"]
  end
end

tables = schema.fetch("tables")
tables_by_id = table_by_id(schema)
interface_count = pages.fetch("interfaces", []).length
page_count = pages.fetch("interfaces", []).sum { |interface| interface.fetch("pages", []).length }
element_count = pages.fetch("interfaces", []).sum { |interface| interface.fetch("pages", []).sum { |page| page.fetch("dashboardElements", []).length } }

index_body = <<~HTML
  <section>
    <h2>Review Scope</h2>
    <p>This Airtable review is organized into one index and three detail documents: tables, interfaces, and automations.</p>
    <p>The table and interface material comes from Airtable metadata. No underlying record values were fetched. Automation material comes from screenshots because the current Airtable MCP tooling exposed interface/page metadata but not full automation definitions.</p>
    <p>The client is using Airtable temporarily and may stop the subscription. We are treating this material as an archived product reference for Phase 1 and later phases, not as a live system dependency, migration source, or database schema to copy directly.</p>
    <div class="callout risk">
      <p>Do not fetch Airtable records until the client confirms whether the base contains PHI, whether Airtable is covered by the right HIPAA configuration, and what data we are allowed to migrate or inspect.</p>
    </div>
  </section>

  <section>
    <h2>Airtable Docs</h2>
    <div class="grid">
      <a class="link-card" href="tables.html">
        <span class="badge">Tables</span>
        <strong>Airtable Tables</strong>
        <span>All 19 tables, field types, linked relationships, views, security notes, and product module mapping.</span>
      </a>
      <a class="link-card" href="interfaces.html">
        <span class="badge">Interfaces</span>
        <strong>Airtable Interfaces</strong>
        <span>Role-oriented dashboards, visible widgets, aggregations, chart logic, source tables, and implementation implications.</span>
      </a>
      <a class="link-card" href="automations.html">
        <span class="badge">Automations</span>
        <strong>Airtable Automations</strong>
        <span>All observed automations, screenshots, trigger/action interpretation, replication details, idempotency, and validation gaps.</span>
      </a>
    </div>
  </section>

  <section>
    <h2>Base Summary</h2>
    <table>
      <tbody>
        <tr><th>Tables</th><td>#{tables.length}</td></tr>
        <tr><th>Interfaces</th><td>#{interface_count}</td></tr>
        <tr><th>Interface pages</th><td>#{page_count}</td></tr>
        <tr><th>Dashboard elements</th><td>#{element_count}</td></tr>
        <tr><th>Visible automations</th><td>#{AUTOMATIONS.length}</td></tr>
      </tbody>
    </table>
    <p>The base is not only an analytics dashboard. It is a lightweight pharmacy operating system covering stores, employees, tasks, compliance, SOPs, documents, doctor outreach, vendors, financial reporting, and KPI tracking.</p>
  </section>

  <section>
    <h2>Setup Diagram</h2>
    <div class="diagram">
      <img src="../diagrams/airtable-setup-overview.svg" alt="Airtable setup overview and software mapping">
    </div>
    <p class="meta">Editable source: <a href="../diagrams/airtable-setup-overview.d2"><code>diagrams/airtable-setup-overview.d2</code></a></p>
  </section>

  <section>
    <h2>Main Product Modules Found</h2>
    <table>
      <thead><tr><th>Module</th><th>Airtable tables</th><th>What this means for our product</th></tr></thead>
      <tbody>
        #{MODULES.map { |module_name, table_names, meaning| "<tr><td>#{h(module_name)}</td><td>#{h(table_names).gsub(/([^,]+)/) { code($1.strip) }}</td><td>#{h(meaning)}</td></tr>" }.join("\n        ")}
      </tbody>
    </table>
  </section>

  <section>
    <h2>Phase 1 Direction</h2>
    #{ordered_list([
      "Use Pharmacies and People as the store and staff foundation.",
      "Build role-specific dashboards around Daily Sales, KPI Scorecard, Tasks, Financial Periods, Compliance Items, and Documents.",
      "Replicate the core workflow automations as backend scheduled jobs and record-triggered rules.",
      "Start with operational visibility and manual/imported dashboard data before advanced analytics.",
      "Use the remaining Airtable modules and workflow ideas as a future-phase backlog reference, even if the Airtable subscription is discontinued.",
      "Later enrich Daily Sales, Rx Metrics, AR, payer, and drug-level reporting from PrimeRx API, webhooks, and SFTP feeds."
    ])}
  </section>

  <section>
    <h2>Important Security Notes</h2>
    #{list([
      "Metadata review did not pull record values, so no patient, staff, vendor, or document record contents were copied into this repository.",
      "#{code("People")}, #{code("Doctor Offices")}, #{code("Vendors")}, and attachment fields may contain personal or sensitive business contact data.",
      "#{code("Compliance Logs")} include drug names and controlled-substance style fields. We need client confirmation before importing records.",
      "Attachment fields can contain unknown document content. Files should move to restricted object storage with metadata in the database.",
      "Notes/comments fields should be reviewed carefully because free text can contain PHI even when the schema itself does not require it."
    ])}
  </section>
HTML

File.write(File.join(OUTPUT_DIR, "index.html"), document("Airtable Documentation Index", "Entry point for Airtable tables, interfaces, automations, and software replication notes.", index_body))

table_rows = tables.sort_by { |table| table["name"] }.map do |table|
  field_count = table.fetch("fields", []).length
  view_count = table.fetch("views", []).length
  purpose = TABLE_PURPOSES[table["name"]] || "Purpose to confirm."
  "<tr><td>#{code(table["name"])}</td><td>#{field_count}</td><td>#{view_count}</td><td>#{h(purpose)}</td></tr>"
end.join("\n        ")

relationship_rows = tables.sort_by { |table| table["name"] }.flat_map do |table|
  table.fetch("fields", []).map do |field|
    next unless field["type"] == "multipleRecordLinks"

    linked_table_name = tables_by_id.dig(field.dig("options", "linkedTableId"), "name") || field.dig("options", "linkedTableId")
    "<tr><td>#{code(table["name"])}</td><td>#{code(field["name"])}</td><td>#{code(linked_table_name)}</td></tr>"
  end.compact
end.join("\n        ")

table_sections = tables.sort_by { |table| table["name"] }.map do |table|
  fields = table.fetch("fields", []).map do |field|
    "<tr><td>#{code(field["name"])}</td><td>#{h(field_type_detail(field, tables_by_id))}</td></tr>"
  end.join("\n        ")
  views = table.fetch("views", []).map { |view| code(view["name"]) }.join(", ")
  <<~HTML
    <section id="#{h(table["name"].downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, ""))}">
      <h2>#{h(table["name"])}</h2>
      <p>#{h(TABLE_PURPOSES[table["name"]] || "Purpose to confirm with client.")}</p>
      <p class="meta">Fields: #{table.fetch("fields", []).length}. Views: #{views.empty? ? "none visible in metadata" : views}.</p>
      <table>
        <thead><tr><th>Field</th><th>Type / options</th></tr></thead>
        <tbody>
          #{fields}
        </tbody>
      </table>
    </section>
  HTML
end.join("\n")

tables_body = <<~HTML
  <section>
    <h2>Source And Scope</h2>
    <p>This document uses Airtable base metadata only: table names, field names, field types, select options, linked-record relationships, and view names. It does not include record values.</p>
    <p>Airtable is a temporary reference prototype. These tables capture product intent and future module ideas; they are not a migration source and should not be copied one-to-one into the AnalyticalRx database.</p>
    <div class="callout warn">
      <p>Fields and relationships here describe the current Airtable setup. They should guide our product model, but we should not build a generic Airtable clone.</p>
    </div>
  </section>

  <section>
    <h2>Table Inventory</h2>
    <table>
      <thead><tr><th>Table</th><th>Fields</th><th>Views</th><th>Product purpose</th></tr></thead>
      <tbody>
        #{table_rows}
      </tbody>
    </table>
  </section>

  <section>
    <h2>Product Module Mapping</h2>
    <table>
      <thead><tr><th>Module</th><th>Airtable tables</th><th>Software implication</th></tr></thead>
      <tbody>
        #{MODULES.map { |module_name, table_names, meaning| "<tr><td>#{h(module_name)}</td><td>#{h(table_names).gsub(/([^,]+)/) { code($1.strip) }}</td><td>#{h(meaning)}</td></tr>" }.join("\n        ")}
      </tbody>
    </table>
  </section>

  <section>
    <h2>Linked Relationships</h2>
    <p>These linked-record fields are the clearest relationship hints in the Airtable model.</p>
    <table>
      <thead><tr><th>Source table</th><th>Field</th><th>Links to</th></tr></thead>
      <tbody>
        #{relationship_rows}
      </tbody>
    </table>
  </section>

  <section>
    <h2>Data And Security Notes</h2>
    #{list([
      "#{code("People")} has emails, phones, roles, employment status, and staff links. Access should be role-restricted.",
      "#{code("Doctor Offices")} has doctor, contact, outreach, and referral information. Treat it as sensitive business relationship data.",
      "#{code("Documents")}, #{code("Compliance Items")}, #{code("SOPs")}, #{code("Tasks")}, and related attachment fields should move to secure object storage with metadata in the database.",
      "#{code("Compliance Logs")} may include drug and controlled-substance operational information. Do not import records until the client confirms allowed scope.",
      "Financial, AR, KPI, and sales tables should be visible only to owner/bookkeeper/admin roles unless the client explicitly allows broader access.",
      "Free-text fields such as notes and comments can contain PHI or sensitive context even when the field name does not imply it."
    ])}
  </section>

  #{table_sections}
HTML

File.write(File.join(OUTPUT_DIR, "tables.html"), document("Airtable Tables", "Schema-level review of Airtable tables, fields, linked relationships, and software implications.", tables_body))

interface_summary_rows = pages.fetch("interfaces", []).flat_map do |interface|
  interface.fetch("pages", []).map do |page|
    source_tables = page.fetch("tablesByTableId", {}).values.map { |table| table["name"] }.uniq.join(", ")
    "<tr><td>#{h(interface["name"])}</td><td>#{h(page["name"])}</td><td>#{code(page["pageType"])}</td><td>#{page.fetch("dashboardElements", []).length}</td><td>#{h(source_tables)}</td></tr>"
  end
end.join("\n        ")

interface_sections = pages.fetch("interfaces", []).map do |interface|
  page_sections = interface.fetch("pages", []).map do |page|
    tables_for_page = page.fetch("tablesByTableId", {}).values.map { |table| table["name"] }.uniq
    element_rows = page.fetch("dashboardElements", []).map do |element|
      fields = visible_fields(page, element)
      "<tr><td>#{h(element["title"] || element["id"])}</td><td>#{code(element["elementType"])}</td><td>#{code(table_name(page.fetch("tablesByTableId", {}), element["sourceTableId"]))}</td><td>#{h(aggregation_summary(page, element))}</td><td>#{fields.map { |field| code(field) }.join(", ")}</td></tr>"
    end.join("\n          ")
    <<~HTML
      <h3>#{h(page["name"])} <span class="tag">#{h(page["pageType"])}</span></h3>
      <p class="meta">Page ID: #{code(page["id"])}. Source tables: #{tables_for_page.map { |name| code(name) }.join(", ")}.</p>
      <table>
        <thead><tr><th>Element</th><th>Type</th><th>Source table</th><th>Aggregation / display logic</th><th>Displayed fields</th></tr></thead>
        <tbody>
          #{element_rows}
        </tbody>
      </table>
    HTML
  end.join("\n")
  <<~HTML
    <section>
      <h2>#{h(interface["name"])}</h2>
      <p class="meta">Interface ID: #{code(interface["id"])}.</p>
      #{page_sections}
    </section>
  HTML
end.join("\n")

interfaces_body = <<~HTML
  <section>
    <h2>Source And Scope</h2>
    <p>Interface data comes from Airtable MCP <code>list-pages-for-base</code>. It includes page names, page types, dashboard elements, source tables, visible fields, and aggregation configuration. No underlying record values were fetched.</p>
    <p>Because Airtable is temporary, these interfaces should be used as a reference for dashboard intent, role-based navigation, and future product phases. They are not a UI contract that must be copied exactly.</p>
  </section>

  <section>
    <h2>Interface Summary</h2>
    <table>
      <tbody>
        <tr><th>Interfaces</th><td>#{interface_count}</td></tr>
        <tr><th>Pages</th><td>#{page_count}</td></tr>
        <tr><th>Dashboard elements</th><td>#{element_count}</td></tr>
        <tr><th>Standalone forms</th><td>#{pages.fetch("standaloneForms", []).length}</td></tr>
      </tbody>
    </table>
    <table>
      <thead><tr><th>Interface</th><th>Page</th><th>Type</th><th>Elements</th><th>Source tables</th></tr></thead>
      <tbody>
        #{interface_summary_rows}
      </tbody>
    </table>
  </section>

  <section>
    <h2>Product Implications</h2>
    #{list([
      "Airtable is already being used as a role-oriented product surface, not just as a backend spreadsheet.",
      "The software should have role-specific routes and permissions for owner, bookkeeper, technician, KPI, and daily sales workflows.",
      "Daily Sales is a concrete Phase 1 dashboard candidate because it has clear KPI cards, trends, store filters, and date filters.",
      "Bookkeeper and owner dashboards depend heavily on Financial Periods, KPI Scorecard, Daily Sales, Tasks, Documents, Doctor Offices, and Doctor Visits.",
      "Technician views depend heavily on Tasks, Compliance Logs, and People.",
      "Dashboard widgets should be saved definitions over typed application tables, not custom one-off screens."
    ])}
  </section>

  #{interface_sections}
HTML

File.write(File.join(OUTPUT_DIR, "interfaces.html"), document("Airtable Interfaces", "Role-oriented Airtable interface pages, widgets, source tables, and dashboard implementation notes.", interfaces_body))

automation_summary_rows = AUTOMATIONS.map do |automation|
  screenshot_path = "#{SCREENSHOT_DIR}/#{automation.fetch(:screenshot)}"
  confidence_class = automation.fetch(:confidence) == "Low" ? "risk" : (automation.fetch(:confidence) == "Medium" ? "warn" : "")
  "<tr><td><a href=\"##{h(automation.fetch(:id))}\">#{h(automation.fetch(:name))}</a></td><td><a href=\"#{h(screenshot_path)}\">#{h(automation.fetch(:screenshot))}</a></td><td><span class=\"tag #{confidence_class}\">#{h(automation.fetch(:confidence))}</span></td><td>#{code(automation.fetch(:status))}</td><td>#{h(automation.fetch(:trigger))}</td><td>#{h(automation.fetch(:intent))}</td></tr>"
end.join("\n        ")

automation_sections = AUTOMATIONS.map do |automation|
  screenshot_path = "#{SCREENSHOT_DIR}/#{automation.fetch(:screenshot)}"
  confidence_class = automation.fetch(:confidence) == "Low" ? "risk" : (automation.fetch(:confidence) == "Medium" ? "warn" : "")
  <<~HTML
    <section id="#{h(automation.fetch(:id))}">
      <h2>#{h(automation.fetch(:name))} <span class="tag #{confidence_class}">#{h(automation.fetch(:confidence))}</span></h2>
      <figure class="screenshot">
        <a href="#{h(screenshot_path)}"><img src="#{h(screenshot_path)}" alt="#{h(automation.fetch(:name))} screenshot"></a>
        <figcaption>Source screenshot: #{h(automation.fetch(:screenshot))}</figcaption>
      </figure>
      <table>
        <tbody>
          <tr><th>Observed status</th><td>#{code(automation.fetch(:status))}</td></tr>
          <tr><th>Observed trigger</th><td>#{h(automation.fetch(:trigger))}</td></tr>
          <tr><th>Observed actions</th><td>#{h(automation.fetch(:observed_actions))}</td></tr>
          <tr><th>Product intent</th><td>#{h(automation.fetch(:intent))}</td></tr>
          <tr><th>Primary tables</th><td>#{h(automation.fetch(:tables)).split(",").map { |table| code(table.strip) }.join(", ")}</td></tr>
          <tr><th>Backend trigger type</th><td>#{h(automation.fetch(:trigger_type))}</td></tr>
          <tr><th>Suggested idempotency key</th><td>#{code(automation.fetch(:idempotency))}</td></tr>
        </tbody>
      </table>
      <h3>Likely Field Mapping / Logic</h3>
      #{list(automation.fetch(:mappings).map { |item| h(item) })}
      <h3>Implementation Details</h3>
      #{list(automation.fetch(:implementation).map { |item| h(item) })}
      <h3>Validation Needed</h3>
      #{list(automation.fetch(:validation).map { |item| h(item) })}
    </section>
  HTML
end.join("\n")

automations_body = <<~HTML
  <section>
    <h2>Source And Scope</h2>
    <p>Automation data comes from the Airtable automation screenshots captured from the client base. Airtable MCP CLI version <code>0.2.6</code> did not expose a tool for listing full automation definitions, and the direct metadata endpoint check did not return automation configuration.</p>
    <div class="callout warn">
      <p>Every visible automation appears to be switched <code>OFF</code>, and some action cards show warning indicators. Treat this as a future-phase workflow reference for intended behavior, not proof that the current Airtable automations are active, complete, or production requirements to copy exactly.</p>
    </div>
  </section>

  <section>
    <h2>Software Building Blocks Needed</h2>
    <table>
      <tbody>
        <tr><th>Rule engine</th><td>Runs record-triggered rules when a source record is created or updated.</td></tr>
        <tr><th>Scheduler</th><td>Runs tenant-scoped daily and weekly jobs in the tenant's configured timezone.</td></tr>
        <tr><th>Task service</th><td>Creates and updates operational tasks from templates, compliance items, onboarding steps, and recurring task rules.</td></tr>
        <tr><th>Notification service</th><td>Sends email notifications from templates and resolves recipients from tenant users, roles, stores, and notification groups.</td></tr>
        <tr><th>KPI calculation service</th><td>Creates or updates KPI scorecard rows from financial periods and prescription metrics.</td></tr>
        <tr><th>Audit and run logs</th><td>Stores automation runs, source records evaluated, outputs, skipped records, notifications, and errors.</td></tr>
      </tbody>
    </table>
  </section>

  <section>
    <h2>Cross-Cutting Rules</h2>
    #{list([
      "Every automation must be scoped by tenant_id and, where applicable, pharmacy_id.",
      "Dates should be stored in UTC, while business schedules run in tenant timezone.",
      "Each scheduled job needs an idempotency key so re-runs do not create duplicate tasks or send duplicate emails.",
      "Record-triggered automations need an idempotency key based on source record and intended output.",
      "All recipients should be resolved from users, roles, or notification groups. Do not migrate hard-coded personal email addresses from Airtable.",
      "Each automation should support enabled, disabled, and dry_run modes per tenant.",
      "Automation failures should not block the user-facing workflow that created or updated the source record.",
      "Each automation should write run logs even when zero records are matched.",
      "Notification emails should avoid exposing unnecessary PHI."
    ])}
  </section>

  <section>
    <h2>Automation Inventory</h2>
    <table>
      <thead><tr><th>Automation</th><th>Screenshot</th><th>Confidence</th><th>Status</th><th>Trigger</th><th>Product intent</th></tr></thead>
      <tbody>
        #{automation_summary_rows}
      </tbody>
    </table>
  </section>

  #{automation_sections}

  <section>
    <h2>Suggested Minimal Database Support</h2>
    <table>
      <tbody>
        <tr><th>automation_rules</th><td>Tenant-scoped rule configuration: key, name, trigger type, schedule, timezone, enabled flag, dry-run flag, and rule-specific JSON config.</td></tr>
        <tr><th>automation_runs</th><td>One row per execution with start/end timestamps, status, matched count, created count, updated count, notification count, skipped count, and error summary.</td></tr>
        <tr><th>automation_run_items</th><td>Optional detail rows per source record processed. Useful when a digest or scheduled job handles many records.</td></tr>
        <tr><th>notification_templates</th><td>Tenant-scoped email templates for owner digest, KPI alert, follow-up reminder, due-soon reminder, overdue reminder, and due-today reminder.</td></tr>
        <tr><th>notification_deliveries</th><td>Delivery log with recipient, subject, channel, source automation, source record, delivery status, provider message id, and sent timestamp.</td></tr>
        <tr><th>role_notification_settings</th><td>Defines who receives each notification class by tenant, pharmacy, role, and notification type.</td></tr>
      </tbody>
    </table>
  </section>

  <section>
    <h2>Phase 1 Replication Priority</h2>
    #{ordered_list([
      "Build task creation/update foundation first: Tasks, Task Templates, assignments, due dates, status transitions, and recurrence.",
      "Implement compliance-to-task creation because it is simple and high value.",
      "Implement due-today and overdue task reminders because they validate scheduler, recipient resolution, and notification logs.",
      "Implement scheduled task generation from templates after duplicate prevention is in place.",
      "Implement KPI scorecard sync after Financial Periods and Rx Metrics import paths are defined.",
      "Implement doctor-office follow-up and lapse-risk alerts after the doctor office module is modeled.",
      "Implement owner digest last because it aggregates many other modules and depends on their data quality."
    ])}
  </section>

  <section>
    <h2>Open Client Questions</h2>
    #{ordered_list([
      "Which currently OFF Airtable automations are actually used by the business today?",
      "Can the client export or screen-share the detailed step configuration for each automation, including filters, field mappings, email bodies, and recipients?",
      "What timezone should production schedules use for each pharmacy group?",
      "Should reminders be one email per item or one batched digest per user?",
      "Which roles should receive owner/operator alerts, and should recipients vary by store?",
      "Should automations create tasks, send emails, or both for compliance and expiration workflows?",
      "What are the exact KPI formulas and target thresholds?",
      "Should task statuses be normalized? Airtable currently shows both Done and Completed.",
      "Should recurring tasks be based on original due date or actual completion date?",
      "Do any Airtable automations include scripts or integrations that are not visible in the screenshots?"
    ])}
  </section>
HTML

File.write(
  File.join(OUTPUT_DIR, "automations.html"),
  document(
    "Airtable Automations",
    "Detailed automation replication plan using screenshot evidence, field dependencies, idempotency, notification behavior, and validation gaps.",
    automations_body,
    "    .screenshot img { max-height: 680px; object-fit: contain; background: #ffffff; }\n"
  )
)

puts "Wrote #{File.join(OUTPUT_DIR, "index.html")}"
puts "Wrote #{File.join(OUTPUT_DIR, "tables.html")}"
puts "Wrote #{File.join(OUTPUT_DIR, "interfaces.html")}"
puts "Wrote #{File.join(OUTPUT_DIR, "automations.html")}"
