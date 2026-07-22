#!/usr/bin/env ruby
# Generate an Airtable interface/automation review report from Airtable MCP page metadata.

require "cgi"
require "json"

INPUT_PATH = ARGV[0] || "/tmp/analyticalrx_airtable_pages.json"
OUTPUT_PATH = ARGV[1] || "Airtable_Interface_Automation_Report.html"

data = JSON.parse(File.read(INPUT_PATH))

AUTOMATIONS = [
  ["Copy Values from Financial Periods/Rx Metrics to KPI Scorecard", "OFF", "When a record is created in Financial Periods", "Find records where Store and Month match, then create a KPI Scorecard record.", "KPI scorecard population/sync"],
  ["New-Store Onboarding Auto-Clone", "OFF", "When a record matches conditions", "Find records, then perform one additional action.", "Clone onboarding steps/tasks when a new store is added or reaches a setup status"],
  ["Monday Owner Digest Email", "OFF", "At a scheduled time", "Find records, then perform five additional actions.", "Weekly owner digest email"],
  ["KPI Status Alert and Notification", "OFF", "When a record matches conditions", "Find records, then perform one additional action.", "KPI threshold/status notification"],
  ["Doctor Office Follow-Up Notification", "OFF", "When a record matches conditions", "Find records, then perform one additional action.", "Doctor outreach follow-up reminder"],
  ["Lapse Risk Alert Automation", "OFF", "When a record matches conditions", "Find records, then perform one additional action.", "Doctor office relationship lapse-risk alert"],
  ["Compliance to Unified Calendar Feed", "OFF", "When a record is created", "Create a record.", "Compliance calendar event creation"],
  ["Scheduled Task Generation from Templates", "OFF", "At a scheduled time", "Find records, then perform three additional actions.", "Recurring/scheduled task generation from templates"],
  ["Compliance due soon notification", "OFF", "At a scheduled time", "Find records, then perform two additional actions.", "Upcoming compliance due-date notification"],
  ["Document/license expiring - weekly", "OFF", "At a scheduled time", "Find records, then perform three additional actions.", "Weekly expiring document/license notification"],
  ["Task overdue - daily notification", "OFF", "At a scheduled time", "Find records, then perform two additional actions.", "Daily overdue task notification"],
  ["Recurring Task Generator", "OFF", "When a record matches conditions", "Find records, then perform one additional action.", "Recurring task creation"],
  ["Task Completion Update", "OFF", "When a record matches conditions", "Update a record.", "Automatic task completion/status update"],
  ["Daily Task Due Email Notification", "OFF", "At a scheduled time", "Find records, then perform two additional actions.", "Daily due-task notification"]
].freeze

def h(value)
  CGI.escapeHTML(value.to_s)
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

interface_count = data.fetch("interfaces", []).length
page_count = data.fetch("interfaces", []).sum { |interface| interface.fetch("pages", []).length }
element_count = data.fetch("interfaces", []).sum { |interface| interface.fetch("pages", []).sum { |page| page.fetch("dashboardElements", []).length } }

html = +"<!doctype html>\n"
html << <<~HTML
  <html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Airtable Interface And Automation Report</title>
    <style>
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

      nav a {
        color: var(--accent);
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
      }

      p {
        margin: 0 0 13px;
      }

      ul, ol {
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

      th, td {
        border: 1px solid var(--line);
        padding: 8px 10px;
        vertical-align: top;
      }

      th {
        background: var(--panel);
        text-align: left;
      }

      a {
        color: var(--accent);
      }

      .lead {
        color: var(--muted);
        font-size: 18px;
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

      .meta {
        color: var(--muted);
        font-size: 14px;
      }
    </style>
  </head>
  <body>
    <main>
      <nav><a href="index.html">Back to design index</a></nav>

      <header>
        <h1>Airtable Interface And Automation Report</h1>
        <p class="lead">Detailed review of Airtable interface page metadata from MCP plus automation findings visible from screenshots.</p>
      </header>

      <section>
        <h2>Source And Scope</h2>
        <p>Interface data in this report comes from Airtable MCP <code>list-pages-for-base</code>. It includes page names, page types, dashboard elements, source tables, visible fields, and aggregation configuration. No underlying record values were fetched.</p>
        <p>Automation data in this report comes from the Airtable automation screenshot only. Airtable MCP CLI version <code>0.2.6</code> did not expose a tool for listing automation definitions, and the direct metadata endpoint check did not return automation configuration.</p>
        <div class="callout warn">
          <p>Before implementation, each Airtable automation should be opened in the UI and reviewed step by step for exact trigger conditions, field mappings, recipients, email bodies, scripts, and external integrations.</p>
        </div>
      </section>

      <section>
        <h2>Interface Summary</h2>
        <table>
          <thead>
            <tr>
              <th>Metric</th>
              <th>Count</th>
            </tr>
          </thead>
          <tbody>
            <tr><td>Interfaces</td><td>#{interface_count}</td></tr>
            <tr><td>Pages</td><td>#{page_count}</td></tr>
            <tr><td>Dashboard elements</td><td>#{element_count}</td></tr>
            <tr><td>Standalone forms</td><td>#{data.fetch("standaloneForms", []).length}</td></tr>
          </tbody>
        </table>
      </section>
HTML

data.fetch("interfaces", []).each do |interface|
  html << "    <section>\n"
  html << "      <h2>#{h(interface["name"])}</h2>\n"
  html << "      <p class=\"meta\">Interface ID: <code>#{h(interface["id"])}</code></p>\n"

  interface.fetch("pages", []).each do |page|
    tables = page.fetch("tablesByTableId", {}).values.map { |table| table["name"] }.uniq
    html << "      <h3>#{h(page["name"])} <span class=\"meta\">(#{h(page["pageType"])})</span></h3>\n"
    html << "      <p class=\"meta\">Page ID: <code>#{h(page["id"])}</code>. Source tables: #{tables.map { |table| "<code>#{h(table)}</code>" }.join(", ")}.</p>\n"
    html << "      <table>\n"
    html << "        <thead><tr><th>Element</th><th>Type</th><th>Source table</th><th>Aggregation / display logic</th><th>Displayed fields</th></tr></thead>\n"
    html << "        <tbody>\n"

    page.fetch("dashboardElements", []).each do |element|
      fields = visible_fields(page, element)
      html << "          <tr>\n"
      html << "            <td>#{h(element["title"] || element["id"])}</td>\n"
      html << "            <td><code>#{h(element["elementType"])}</code></td>\n"
      html << "            <td><code>#{h(table_name(page.fetch("tablesByTableId", {}), element["sourceTableId"]))}</code></td>\n"
      html << "            <td>#{h(aggregation_summary(page, element))}</td>\n"
      html << "            <td>#{fields.map { |field| "<code>#{h(field)}</code>" }.join(", ")}</td>\n"
      html << "          </tr>\n"
    end

    html << "        </tbody>\n"
    html << "      </table>\n"
  end

  html << "    </section>\n"
end

html << <<~HTML
    <section>
      <h2>Automation Summary From Screenshot</h2>
      <p>The screenshot shows <strong>14 visible automations</strong>. Every visible automation appears to be switched <code>OFF</code>. One automation was selected and exposed its step cards: trigger <code>When a record is created</code> in <code>Financial Periods</code>, action <code>Find records</code>, then action <code>Create record</code> in <code>KPI Scorecard</code>.</p>
      <table>
        <thead>
          <tr>
            <th>Automation</th>
            <th>Status</th>
            <th>Visible trigger</th>
            <th>Visible steps</th>
            <th>Software equivalent</th>
          </tr>
        </thead>
        <tbody>
HTML

AUTOMATIONS.each do |name, status, trigger, steps, equivalent|
  html << "          <tr>\n"
  html << "            <td>#{h(name)}</td>\n"
  html << "            <td><code>#{h(status)}</code></td>\n"
  html << "            <td>#{h(trigger)}</td>\n"
  html << "            <td>#{h(steps)}</td>\n"
  html << "            <td>#{h(equivalent)}</td>\n"
  html << "          </tr>\n"
end

html << <<~HTML
        </tbody>
      </table>
    </section>

    <section>
      <h2>Implementation Notes</h2>
      <ul>
        <li>Interfaces map to role-specific dashboard routes in AnalyticalRx.</li>
        <li>Dashboard elements map to saved chart/KPI definitions that query typed application tables.</li>
        <li>Big-number elements become KPI cards with configured aggregation functions.</li>
        <li>Chart elements become reusable chart widgets with source table, x-axis, measure, and date-bucket configuration.</li>
        <li>Levels elements become record-list or drill-down tables with a controlled visible-field list.</li>
        <li>Automations should become backend workflow rules, scheduled jobs, and notification templates, not frontend-only behavior.</li>
      </ul>
    </section>

    <section>
      <h2>Remaining Gaps</h2>
      <ol>
        <li>Exact automation trigger conditions and field mappings are not available from the current MCP tool list.</li>
        <li>Email recipients, notification channels, and message templates are not visible in the screenshots.</li>
        <li>Any Airtable script actions or external integrations must be opened in the Airtable UI and documented separately.</li>
        <li>Record filters applied to individual interface elements may need validation in the Airtable UI before implementation.</li>
        <li>Record values were not fetched because the base may contain sensitive operational, staff, or health-related data.</li>
      </ol>
    </section>
  </main>
</body>
</html>
HTML

File.write(OUTPUT_PATH, html)
puts "Wrote #{OUTPUT_PATH}"
