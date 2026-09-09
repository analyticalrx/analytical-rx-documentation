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
