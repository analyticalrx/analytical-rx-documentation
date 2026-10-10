#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "fileutils"

OUTPUT_DIR = File.expand_path("../diagrams/dashboard-mockups", __dir__)
FileUtils.mkdir_p(OUTPUT_DIR)

WIDTH = 960
HEIGHT = 540

COLORS = {
  bg: "#eef2f7",
  window: "#ffffff",
  sidebar: "#111827",
  sidebar_muted: "#9ca3af",
  active: "#2563eb",
  ink: "#111827",
  muted: "#64748b",
  line: "#d8dee9",
  panel: "#f8fafc",
  green: "#0f766e",
  green_soft: "#d1fae5",
  amber: "#b45309",
  amber_soft: "#fef3c7",
  red: "#b91c1c",
  red_soft: "#fee2e2",
  blue_soft: "#dbeafe"
}.freeze

DASHBOARDS = [
  {
    slug: "owner",
    title: "Owner Dashboard",
    role: "OWNER",
    nav: "Overview",
    subtitle: "Cross-store performance and source health",
    date: "Sep 1 - Sep 3",
    scope: "All assigned pharmacies",
    group: "day",
    freshness: "Partial",
    freshness_tone: :amber,
    freshness_detail: "Payment enrichment pending",
    cards: [
      ["Prescription Events", "1,284", "+8.4% vs previous period", :green],
      ["Total Amount", "USD 98,642.25", "Partial source coverage", :amber],
      ["Rejected Claims", "37", "Needs attention", :amber]
    ],
    chart: {
      type: :line,
      title: "Prescription Event Trend",
      series: [["Sep 1", 401], ["Sep 2", 428], ["Sep 3", 455]]
    },
    table: {
      title: "Store Comparison",
      columns: ["Pharmacy", "Rx", "Amount", "Rejected"],
      rows: [
        ["Main Street", "542", "42.8k", "12"],
        ["Northside", "388", "31.4k", "9"],
        ["West End", "354", "24.4k", "16"]
      ]
    },
    warning: "Payment totals are partial until API/SFTP enrichment is complete."
  },
  {
    slug: "store-manager",
    title: "Store Manager Dashboard",
    role: "STORE_MANAGER",
    nav: "Stores",
    subtitle: "Daily activity, store workload, and exceptions",
    date: "Sep 1 - Sep 3",
    scope: "Main Street Pharmacy",
    group: "day",
    freshness: "Partial",
    freshness_tone: :amber,
    freshness_detail: "Latest event 09:55 UTC",
    cards: [
      ["Filled", "384", "Selected store", :green],
      ["Picked Up", "318", "Selected store", :green],
      ["Needs Enrichment", "23", "Review queue", :amber]
    ],
    chart: {
      type: :bar,
      title: "Status Breakdown",
      series: [["Filled", 384], ["Picked Up", 318], ["Rejected", 12]]
    },
    table: {
      title: "Exceptions",
      columns: ["Event", "Type", "Date", "Status"],
      rows: [
        ["928a8f5f", "claim rejected", "Sep 3", "needs review"],
        ["b4f831cc", "missing payer", "Sep 3", "pending"],
        ["16d9b811", "partial payment", "Sep 2", "partial"]
      ]
    },
    warning: "Only assigned pharmacies should appear in the filters and results."
  },
  {
    slug: "pharmacist",
    title: "Pharmacist Dashboard",
    role: "PHARMACIST",
    nav: "Work Queue",
    subtitle: "Safe operational state for assigned pharmacies",
    date: "Sep 3",
    scope: "Assigned pharmacies",
    group: "status",
    freshness: "Partial",
    freshness_tone: :amber,
    freshness_detail: "Workflow queue planned for Phase 2",
    cards: [
      ["Verification Pending", "18", "From verification status", :amber],
      ["Blocked Claims", "7", "Needs pharmacist review", :amber],
      ["Upcoming Refills", "Phase 2", "Unavailable for Phase 1", :neutral]
    ],
    chart: nil,
    table: {
      title: "Work Status",
      columns: ["Status", "Count", "Source"],
      rows: [
        ["filled", "44", "pharmacy_event"],
        ["verification pending", "18", "verification_status"],
        ["blocked", "7", "claim_status"]
      ]
    },
    warning: "Do not display patient identifiers, real RxNo, or real RefillNo."
  },
  {
    slug: "technician",
    title: "Technician Dashboard",
    role: "TECHNICIAN",
    nav: "Work Queue",
    subtitle: "Assigned operational work and safe status counts",
    date: "Sep 3",
    scope: "Assigned pharmacies",
    group: "status",
    freshness: "Partial",
    freshness_tone: :amber,
    freshness_detail: "Task queue planned for Phase 2",
    cards: [
      ["Ready", "32", "Ready status count", :green],
      ["Blocked", "5", "Requires help", :amber],
      ["Assigned Tasks", "Phase 2", "Unavailable for Phase 1", :neutral]
    ],
    chart: nil,
    table: {
      title: "Status Summary",
      columns: ["Status", "Count", "Allowed Action"],
      rows: [
        ["ready", "32", "view"],
        ["blocked", "5", "view/update allowed status"],
        ["completed", "81", "view"]
      ]
    },
    warning: "Technician writes must stay limited to approved status updates."
  },
  {
    slug: "bookkeeper",
    title: "Bookkeeper Dashboard",
    role: "BOOKKEEPER",
    nav: "Finance",
    subtitle: "Revenue, payment, and missing finance data",
    date: "Sep 1 - Sep 30",
    scope: "Finance scope",
    group: "payer",
    freshness: "Partial",
    freshness_tone: :amber,
    freshness_detail: "Financial values only where source data exists",
    cards: [
      ["Total Amount", "USD 98,642.25", "Partial source coverage", :amber],
      ["Amount Due", "USD 14,220.75", "Review", :amber],
      ["Missing Payment Data", "41", "Needs enrichment", :amber]
    ],
    chart: {
      type: :donut,
      title: "Payment Split",
      series: [["Insurance", 74650], ["Cash", 9820], ["Patient Pay", 14172]]
    },
    table: {
      title: "Payer Summary",
      columns: ["Payer", "Billed", "Paid", "Events"],
      rows: [
        ["Example Payer", "20.4k", "18.8k", "215"],
        ["Cash", "9.8k", "9.8k", "94"],
        ["Patient Pay", "14.1k", "14.1k", "188"]
      ]
    },
    warning: "Finance dashboard values may be incomplete until enrichment is complete."
  },
  {
    slug: "compliance-admin",
    title: "Compliance / Admin Dashboard",
    role: "COMPLIANCE_ADMIN",
    nav: "Admin",
    subtitle: "Safe pipeline status, audit, and compliance placeholders",
    date: "Sep 1 - Sep 3",
    scope: "Tenant or assigned pharmacies",
    group: "status",
    freshness: "Fresh",
    freshness_tone: :green,
    freshness_detail: "Latest event 09:55 UTC",
    cards: [
      ["Events Processed", "1,248", "Pipeline status", :green],
      ["Events Failed", "9", "Review failures", :amber],
      ["Raw Payload Retention", "30 days", "Metadata only", :green]
    ],
    chart: {
      type: :bar,
      title: "Pipeline Status",
      series: [["Processed", 1248], ["Failed", 9], ["Needs Enrich", 41]]
    },
    table: {
      title: "Recent Failures",
      columns: ["Source", "Type", "Failure", "Status"],
      rows: [
        ["PrimeRx", "claim billed", "missing pharmacy", "failed"],
        ["PrimeRx", "payment", "missing payer", "needs enrichment"],
        ["SFTP", "daily feed", "not received", "delayed"]
      ]
    },
    warning: "Admin views show safe metadata, not raw payload content."
  },
  {
    slug: "business-development",
    title: "Business Development Dashboard",
    role: "BUSINESS_DEVELOPMENT",
    nav: "Outreach",
    subtitle: "Safe prescriber trend and future Doctor CRM space",
    date: "Sep 1 - Sep 30",
    scope: "Assigned territory",
    group: "prescriber",
    freshness: "Partial",
    freshness_tone: :amber,
    freshness_detail: "Doctor CRM planned for Phase 2",
    cards: [
      ["Prescriber Trend", "Available", "Where source supports it", :green],
      ["Doctor CRM", "Phase 2", "Placeholder", :neutral],
      ["Patient Details", "Excluded", "Restricted by design", :amber]
    ],
    chart: nil,
    table: {
      title: "Safe Prescriber Trend",
      columns: ["Prescriber NPI", "Events", "Latest Event"],
      rows: [
        ["1234567890", "84", "Sep 3"],
        ["2345678901", "63", "Sep 2"],
        ["3456789012", "57", "Sep 1"]
      ]
    },
    warning: "Doctor office records and pitch history are Phase 2 modules."
  }
].freeze

def esc(value)
  CGI.escapeHTML(value.to_s)
end

def text(x, y, value, size: 12, color: COLORS[:ink], weight: 400, anchor: "start")
  %(<text x="#{x}" y="#{y}" font-family="Inter, Arial, sans-serif" font-size="#{size}" fill="#{color}" font-weight="#{weight}" text-anchor="#{anchor}">#{esc(value)}</text>)
end

def multiline(x, y, lines, size: 12, color: COLORS[:ink], weight: 400, gap: 18)
  lines.each_with_index.map do |line, index|
    text(x, y + (index * gap), line, size: size, color: color, weight: weight)
  end.join("\n")
end

def rect(x, y, w, h, fill:, stroke: COLORS[:line], rx: 10, opacity: 1)
  %(<rect x="#{x}" y="#{y}" width="#{w}" height="#{h}" rx="#{rx}" fill="#{fill}" stroke="#{stroke}" opacity="#{opacity}"/>)
end

def line(x1, y1, x2, y2, color: COLORS[:line], width: 1)
  %(<line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}" stroke="#{color}" stroke-width="#{width}"/>)
end

def tone(tone_name)
  case tone_name
  when :green
    [COLORS[:green_soft], COLORS[:green], COLORS[:green]]
  when :amber
    [COLORS[:amber_soft], COLORS[:amber], COLORS[:amber]]
  when :red
    [COLORS[:red_soft], COLORS[:red], COLORS[:red]]
  else
    [COLORS[:panel], COLORS[:line], COLORS[:muted]]
  end
end

def pill(x, y, label, tone_name = :neutral)
  fill, stroke, color = tone(tone_name)
  width = [label.length * 7 + 24, 64].max
  [
    rect(x, y, width, 24, fill: fill, stroke: stroke, rx: 12),
    text(x + 12, y + 16, label, size: 11, color: color, weight: 700)
  ].join("\n")
end

def kpi_card(x, y, w, title, value, sub, tone_name)
  fill, stroke, color = tone(tone_name)
  [
    rect(x, y, w, 78, fill: COLORS[:window], stroke: stroke, rx: 12),
    %(<rect x="#{x}" y="#{y}" width="5" height="78" rx="2.5" fill="#{color}"/>),
    text(x + 18, y + 22, title, size: 12, color: COLORS[:muted], weight: 700),
    text(x + 18, y + 48, value, size: 22, color: COLORS[:ink], weight: 800),
    text(x + 18, y + 66, sub, size: 11, color: COLORS[:muted], weight: 500)
  ].join("\n")
end

def nav_item(y, label, active)
  fill = active ? "#1d4ed8" : "transparent"
  color = active ? "#ffffff" : COLORS[:sidebar_muted]
  [
    %(<rect x="34" y="#{y}" width="132" height="30" rx="8" fill="#{fill}"/>),
    text(50, y + 20, label, size: 12, color: color, weight: active ? 800 : 600)
  ].join("\n")
end

def line_chart(x, y, w, h, chart)
  values = chart[:series].map { |(_, value)| value }
  min = values.min
  max = values.max
  range = [max - min, 1].max
  points = chart[:series].each_with_index.map do |(_, value), index|
    px = x + 34 + (index * ((w - 68).to_f / ([chart[:series].length - 1, 1].max)))
    py = y + h - 38 - (((value - min).to_f / range) * (h - 78))
    [px.round(1), py.round(1)]
  end
  path = points.each_with_index.map { |(px, py), index| "#{index.zero? ? "M" : "L"} #{px} #{py}" }.join(" ")
  circles = points.map { |px, py| %(<circle cx="#{px}" cy="#{py}" r="4" fill="#{COLORS[:active]}"/>) }.join("\n")
  labels = chart[:series].each_with_index.map do |(label, value), index|
    px, py = points[index]
    [
      text(px, y + h - 15, label, size: 10, color: COLORS[:muted], anchor: "middle"),
      text(px, py - 10, value, size: 10, color: COLORS[:ink], weight: 700, anchor: "middle")
    ].join("\n")
  end.join("\n")
  [
    rect(x, y, w, h, fill: COLORS[:window], stroke: COLORS[:line], rx: 12),
    text(x + 18, y + 25, chart[:title], size: 13, color: COLORS[:ink], weight: 800),
    line(x + 28, y + h - 36, x + w - 24, y + h - 36),
    line(x + 28, y + 44, x + 28, y + h - 36),
    %(<path d="#{path}" fill="none" stroke="#{COLORS[:active]}" stroke-width="3"/>),
    circles,
    labels
  ].join("\n")
end

def bar_chart(x, y, w, h, chart)
  max = [chart[:series].map { |(_, value)| value }.max, 1].max
  bar_w = ((w - 80).to_f / chart[:series].length).floor - 16
  bars = chart[:series].each_with_index.map do |(label, value), index|
    bx = x + 42 + (index * (bar_w + 28))
    bh = ((value.to_f / max) * (h - 88)).round
    by = y + h - 38 - bh
    [
      %(<rect x="#{bx}" y="#{by}" width="#{bar_w}" height="#{bh}" rx="5" fill="#{COLORS[:active]}"/>),
      text(bx + (bar_w / 2), y + h - 15, label, size: 10, color: COLORS[:muted], anchor: "middle"),
      text(bx + (bar_w / 2), by - 8, value, size: 10, color: COLORS[:ink], weight: 700, anchor: "middle")
    ].join("\n")
  end.join("\n")
  [
    rect(x, y, w, h, fill: COLORS[:window], stroke: COLORS[:line], rx: 12),
    text(x + 18, y + 25, chart[:title], size: 13, color: COLORS[:ink], weight: 800),
    line(x + 28, y + h - 36, x + w - 24, y + h - 36),
    bars
  ].join("\n")
end

def donut_chart(x, y, w, h, chart)
  total = chart[:series].sum { |(_, value)| value }
  colors = [COLORS[:active], COLORS[:green], COLORS[:amber]]
  legend = chart[:series].each_with_index.map do |(label, value), index|
    ly = y + 62 + (index * 27)
    [
      %(<circle cx="#{x + 210}" cy="#{ly - 4}" r="5" fill="#{colors[index]}"/>),
      text(x + 224, ly, "#{label}: #{((value.to_f / total) * 100).round}%", size: 11, color: COLORS[:ink], weight: 600)
    ].join("\n")
  end.join("\n")
  [
    rect(x, y, w, h, fill: COLORS[:window], stroke: COLORS[:line], rx: 12),
    text(x + 18, y + 25, chart[:title], size: 13, color: COLORS[:ink], weight: 800),
    %(<circle cx="#{x + 88}" cy="#{y + 94}" r="48" fill="none" stroke="#{COLORS[:active]}" stroke-width="18" stroke-dasharray="210 302" transform="rotate(-90 #{x + 88} #{y + 94})"/>),
    %(<circle cx="#{x + 88}" cy="#{y + 94}" r="48" fill="none" stroke="#{COLORS[:green]}" stroke-width="18" stroke-dasharray="27 302" stroke-dashoffset="-210" transform="rotate(-90 #{x + 88} #{y + 94})"/>),
    %(<circle cx="#{x + 88}" cy="#{y + 94}" r="48" fill="none" stroke="#{COLORS[:amber]}" stroke-width="18" stroke-dasharray="65 302" stroke-dashoffset="-237" transform="rotate(-90 #{x + 88} #{y + 94})"/>),
    %(<circle cx="#{x + 88}" cy="#{y + 94}" r="29" fill="#ffffff"/>),
    text(x + 88, y + 90, "Split", size: 11, color: COLORS[:muted], weight: 700, anchor: "middle"),
    text(x + 88, y + 108, "USD", size: 13, color: COLORS[:ink], weight: 800, anchor: "middle"),
    legend
  ].join("\n")
end

def data_table(x, y, w, h, table)
  col_count = table[:columns].length
  available_w = w - 32
  first_col_w = col_count > 2 ? [available_w * 0.38, 98].max : available_w / col_count.to_f
  other_col_w = col_count > 1 ? (available_w - first_col_w) / (col_count - 1).to_f : available_w
  col_x = []
  cursor = x + 16
  col_count.times do |index|
    col_x << cursor
    cursor += index.zero? ? first_col_w : other_col_w
  end
  header_y = y + 50
  column_text = table[:columns].each_with_index.map do |column, index|
    text(col_x[index], header_y, column, size: 10, color: COLORS[:muted], weight: 800)
  end.join("\n")
  rows = table[:rows].each_with_index.map do |row, row_index|
    row_y = y + 76 + (row_index * 25)
    cells = row.each_with_index.map do |cell, index|
      text(col_x[index], row_y, cell, size: 10, color: COLORS[:ink], weight: index.zero? ? 700 : 500)
    end
    [line(x + 16, row_y - 16, x + w - 16, row_y - 16), cells].join("\n")
  end.join("\n")
  [
    rect(x, y, w, h, fill: COLORS[:window], stroke: COLORS[:line], rx: 12),
    text(x + 18, y + 25, table[:title], size: 13, color: COLORS[:ink], weight: 800),
    column_text,
    rows
  ].join("\n")
end

def placeholder_panel(x, y, w, h, table)
  [
    rect(x, y, w, h, fill: COLORS[:window], stroke: COLORS[:line], rx: 12),
    text(x + 18, y + 25, table[:title], size: 13, color: COLORS[:ink], weight: 800),
    rect(x + 18, y + 48, w - 36, h - 68, fill: COLORS[:panel], stroke: COLORS[:line], rx: 10),
    multiline(x + 36, y + 78, table[:rows].flatten, size: 11, color: COLORS[:ink], weight: 600, gap: 22)
  ].join("\n")
end

def chart_panel(x, y, w, h, chart)
  return placeholder_panel(x, y, w, h, { title: "Phase 1 Placeholder", rows: [["No chart for this starter view", "Use the table area for safe status data"]] }) unless chart

  case chart[:type]
  when :line
    line_chart(x, y, w, h, chart)
  when :bar
    bar_chart(x, y, w, h, chart)
  when :donut
    donut_chart(x, y, w, h, chart)
  else
    placeholder_panel(x, y, w, h, { title: chart[:title], rows: chart[:series] })
  end
end

def dashboard_svg(dashboard)
  nav_items = ["Overview", "Stores", "Work Queue", "Finance", "Admin", "Outreach"].each_with_index.map do |item, index|
    nav_item(126 + (index * 38), item, item == dashboard[:nav])
  end.join("\n")

  cards = dashboard[:cards].each_with_index.map do |(title, value, sub, tone_name), index|
    kpi_card(225 + (index * 226), 205, 210, title, value, sub, tone_name)
  end.join("\n")

  main_panel = if dashboard[:chart]
                 [
                   chart_panel(225, 302, 400, 132, dashboard[:chart]),
                   data_table(642, 302, 278, 132, dashboard[:table])
                 ].join("\n")
               else
                 data_table(225, 302, 695, 132, dashboard[:table])
               end

  <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" width="#{WIDTH}" height="#{HEIGHT}" viewBox="0 0 #{WIDTH} #{HEIGHT}" role="img" aria-label="#{esc(dashboard[:title])} mockup">
      <defs>
        <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
          <feDropShadow dx="0" dy="8" stdDeviation="12" flood-color="#0f172a" flood-opacity="0.14"/>
        </filter>
      </defs>
      <rect width="#{WIDTH}" height="#{HEIGHT}" fill="#{COLORS[:bg]}"/>
      <rect x="18" y="18" width="924" height="504" rx="18" fill="#{COLORS[:window]}" filter="url(#shadow)"/>
      <rect x="18" y="18" width="924" height="32" rx="18" fill="#{COLORS[:panel]}"/>
      <circle cx="42" cy="34" r="5" fill="#ef4444"/>
      <circle cx="60" cy="34" r="5" fill="#f59e0b"/>
      <circle cx="78" cy="34" r="5" fill="#22c55e"/>
      <rect x="110" y="26" width="285" height="16" rx="8" fill="#e5e7eb"/>

      <rect x="18" y="50" width="170" height="472" fill="#{COLORS[:sidebar]}"/>
      #{text(42, 82, "AnalyticalRx", size: 17, color: "#ffffff", weight: 900)}
      #{text(42, 104, "Role dashboards", size: 11, color: COLORS[:sidebar_muted], weight: 600)}
      #{nav_items}

      <rect x="188" y="50" width="754" height="472" fill="#f8fafc"/>
      <rect x="205" y="68" width="720" height="82" rx="14" fill="#ffffff" stroke="#d8dee9"/>
      #{text(225, 98, dashboard[:title], size: 22, color: COLORS[:ink], weight: 900)}
      #{text(225, 122, dashboard[:subtitle], size: 12, color: COLORS[:muted], weight: 600)}
      #{pill(704, 83, dashboard[:role], :neutral)}
      #{pill(704, 114, "#{dashboard[:freshness]} data", dashboard[:freshness_tone])}

      <rect x="225" y="152" width="695" height="40" rx="10" fill="#ffffff" stroke="#d8dee9"/>
      #{text(242, 177, "Date: #{dashboard[:date]}", size: 11, color: COLORS[:ink], weight: 700)}
      #{text(390, 177, "Scope: #{dashboard[:scope]}", size: 11, color: COLORS[:ink], weight: 700)}
      #{text(700, 177, "Group: #{dashboard[:group]}", size: 11, color: COLORS[:ink], weight: 700)}

      #{cards}
      #{main_panel}

      <rect x="225" y="456" width="695" height="42" rx="12" fill="#fff7ed" stroke="#f59e0b"/>
      #{text(244, 481, dashboard[:warning], size: 12, color: COLORS[:amber], weight: 700)}
    </svg>
  SVG
end

DASHBOARDS.each do |dashboard|
  path = File.join(OUTPUT_DIR, "#{dashboard[:slug]}-dashboard-mockup.svg")
  File.write(path, dashboard_svg(dashboard))
end

readme = <<~MD
  # Dashboard Mockups

  Status: Initial visual guide for Phase 1 UI/API integration

  These compact SVG mockups show how the sample dashboard API responses in `architecture/ui-api-contracts.md` can translate into app-like dashboard screens.

  Each mockup uses the same placement rules:

  - `filters` -> filter bar
  - `dataFreshness` -> header status pill
  - `cards[]` -> KPI cards
  - `charts[]` -> main chart panel
  - `tables[]` -> table panel
  - `warnings[]` -> alert strip
  - `emptyState` -> placeholder card or panel

  ## Phase 1 Dashboard Mockups

  | Dashboard | SVG |
  | --- | --- |
  | Owner / Executive | [owner-dashboard-mockup.svg](owner-dashboard-mockup.svg) |
  | Store Manager | [store-manager-dashboard-mockup.svg](store-manager-dashboard-mockup.svg) |
  | Pharmacist | [pharmacist-dashboard-mockup.svg](pharmacist-dashboard-mockup.svg) |
  | Technician | [technician-dashboard-mockup.svg](technician-dashboard-mockup.svg) |
  | Bookkeeper / Finance | [bookkeeper-dashboard-mockup.svg](bookkeeper-dashboard-mockup.svg) |
  | Compliance / Admin | [compliance-admin-dashboard-mockup.svg](compliance-admin-dashboard-mockup.svg) |
  | Business Development | [business-development-dashboard-mockup.svg](business-development-dashboard-mockup.svg) |

  ## Regenerate

  From the documentation repository root:

  ```bash
  ruby scripts/generate_dashboard_mockups.rb
  ```
MD

File.write(File.join(OUTPUT_DIR, "README.md"), readme)

puts "Generated #{DASHBOARDS.length} dashboard mockups in #{OUTPUT_DIR}"
