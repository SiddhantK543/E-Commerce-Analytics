# Dashboard Mockup

`dashboard_mockup.html` is a **static HTML/Chart.js preview**, not a
Power BI file. Open it directly in any browser (no server needed) to
see a navigable, tabbed preview of all 5 pages described in
`powerbi/dashboard_pages.md`.

## Why a mockup instead of a `.pbix`

A `.pbix` is a proprietary binary/zip container Power BI Desktop
writes internally; it cannot be reliably hand-authored outside Power
BI Desktop itself. Rather than fabricate a fake or corrupt `.pbix`,
this mockup gives a real, honest visual preview of the design using
the exact numbers computed from the synthetic test fixture, so the
layout, KPI hierarchy, chart choices, and color palette can be
reviewed before building the real report in Power BI Desktop.

## What this mockup is NOT

- Not connected to live data — every number is hard-coded from the
  validation queries in `powerbi/testing_validation.md`
- Not a substitute for the actual DAX measures — see
  `powerbi/dax_measures.md` for the real formulas
- Not built with Power BI's rendering engine — chart choices
  (Chart.js) approximate, but do not pixel-match, actual Power BI
  visuals

## What it IS useful for

- Reviewing page layout, KPI card hierarchy, and navigation before
  investing time in Power BI Desktop
- Confirming the color palette (`powerbi/theme/ecommerce_theme.json`)
  reads well across chart types
- A sanity check that the numbers in `powerbi/dashboard_pages.md` are
  internally consistent (e.g. category revenue sums to total revenue)
