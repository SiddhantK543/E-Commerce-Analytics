# EcommerceAnalytics.pbip — Power BI Project

This is a genuine **Power BI Project (.pbip)** — Microsoft's git-friendly,
plain-text Power BI Desktop project format. It is not a mockup, not an
HTML file renamed, and not a fabricated binary. Opening it in Power BI
Desktop and choosing **File → Save As → Power BI file (.pbix)** is a
real compile step performed by Power BI Desktop itself, producing a
genuine `.pbix`.

## Read this first: what's guaranteed vs. best-effort

Being upfront about confidence levels, because that's what was asked for:

| Part | Format | Confidence | What this means |
|---|---|---|---|
| **Semantic Model** — 7 tables, 7 relationships, the full 50-measure DAX library, Power Query M sources | TMDL (plain text, stable, well-documented) | **High.** Every DAX expression's column and measure references were parsed and cross-checked against the model — 0 unresolved. Every M expression bracket-balanced. | This is the part with all the real work in it, and the part most likely to load cleanly. |
| **Report** — 5 pages, 79 visuals: KPI cards, slicers, titles, and the full chart layer (lines, bars, donuts, tables, matrix, Pareto combo) | PBIR (JSON, one file per visual) | **Good, not certain.** All 79 `visual.json` files validate against Microsoft's published PBIR schemas (`visualContainer` 2.0.0, `visualConfiguration` 2.0.0, `filterConfiguration` 1.1.0, `semanticQuery` 1.2.0) — 0 failures. All 116 field references resolve in the model — 0 unresolved. Layout checked for overlap and off-canvas — 0 of each. | The residual risk is *role names*: the schema validates that `Category`/`Series`/`Y`/`Values`/`Rows` are well-formed, but not that a given chart type expects exactly those names. If one visual shows an error icon, see Troubleshooting — the fix is seconds, and the field it needs is guaranteed present and correctly named. |
| Tooltip pages, drillthrough pages, page navigator, bookmarks | *Not generated* | — | These are multi-file constructs (a tooltip page needs its own page entry, page-type config, and per-visual tooltip bindings). They're polish, not content. `powerbi/dashboard_pages.md` specifies them if you want to add them by hand. |

**Bottom line:** the report opens populated, not blank. Every table,
relationship, measure and chart from `docs/powerbi_data_model.md`,
`docs/powerbi_measures.md` and `powerbi/dashboard_pages.md` is already
in place and wired.

## How to open it (step by step)

1. **Requirements:** Power BI Desktop, a reasonably recent version
   (TMDL-format .pbip has been the GA default since late 2024; if your
   Desktop is older, enable it under **File → Options → Preview
   features → "Power BI Project (.pbip) save option" / "TMDL"**).
2. **Unzip** the project. Keep `powerbi/pbip/` alongside the rest of the
   repo, because the model reads its CSVs from `<repo>/data/exports/`.
   **Avoid spaces and parentheses in the folder path** — Power Query
   handles them, but it's one less thing to debug.
3. **Open** `powerbi/pbip/EcommerceAnalytics.pbip` — Power BI Desktop
   opens the whole project (both the SemanticModel and the Report).
4. **Check the data folder path.** The `DataFolderPath` parameter is
   pre-set to an absolute path. If you unzipped somewhere else, go to
   **Transform data → Edit Parameters** and point it at the absolute
   path of `data/exports/` on your machine. It must be the folder that
   contains `bi_order_items.csv`, `bi_customer_rfm.csv`, and friends —
   **not** `data/sample/`, which holds differently-shaped raw CSVs the
   model does not read.
5. **Refresh** (Home → Refresh). This is the step that actually pulls
   the CSV data in — nothing is pre-loaded or cached in these text files.
6. **Verify:** Executive Overview → Total Revenue should read
   **$1,480.40** against the synthetic fixture. See
   `powerbi/testing_validation.md` for the full expected-value table.
7. **File → Save As → Power BI file (.pbix)** — this is your real,
   genuine `.pbix`.

`DimDate` already carries `dataCategory: Time`, so "Mark as date table"
is applied on open and the time-intelligence measures (Revenue MTD/YTD,
YoY) work without a manual step. Auto date/time is switched off, so the
model uses `DimDate` rather than generating hidden per-column date
tables.

## What's on each page

| Page | KPI cards | Charts |
|---|---|---|
| Executive Overview | 6 | Revenue trend, order-volume trend, revenue by category, Top 5 products, customers by segment, plus an `Executive Insight` DAX narrative card |
| Transaction & Payment Health | 6 | Success vs failure rate trend, orders by payment method, failure rate by method, potential lost revenue by method, cancellation trend, transaction-status donut |
| Customer Analytics | 5 | RFM donut, revenue by RFM, churned vs total by RFM, customer-revenue table, Top 5 customers, retention-rate card |
| Product & Revenue | 4 | Revenue trend, Top 10 products, revenue + profit by category, Pareto combo chart, category→product matrix, category share donut |
| Risk & Anomalies | 5 | Risk-flag donut, high-risk trend, risk by payment method, risk by country, high-value anomalies table, possible-duplicate table |

Every page carries a footer caption naming the dataset status, since the
committed fixture is synthetic. Remove those five text boxes once you've
refreshed against the full dataset.

Three visuals use a **Top N** visual-level filter (Top 5 products, Top 5
customers, Top 10 products). If any of them misbehaves, open the Filters
pane and delete the filter — the chart still works, it just shows all
rows.

The custom theme (`ecommerce_theme.json`) is registered and applied, so
the visuals pick up its palette.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| "File contents not found" / refresh error on any table | `DataFolderPath` doesn't match where you unzipped | Step 4 above |
| One chart shows an error icon or "Can't display this visual" | That chart type wants a different data-role name than the one written into its JSON | Note its title, delete it, insert the same chart type from the Visualizations pane, and drag the fields named in the table above. The measure/column is present and correctly named — this is a 20-second fix, and it's per-visual, so it can't cascade. |
| A KPI card shows an error icon | The measure is still valid — cross-checked | Delete the card, insert a Card visual, drag the same measure from `_Measures` |
| A page looks blank | Refresh hasn't been run yet, or the parameter path is wrong | Steps 4–5 above |
| Charts render but the numbers look tiny (revenue in the hundreds) | Expected. The committed CSVs are a 5-customer / 11-order fixture | Load the real dataset and re-run `python/export_bi_data.py`, then Refresh |
| A month axis is out of order | Shouldn't happen — `year_month_label` is `YYYY-MM`, so alphabetical order is chronological | — |
| You want to reconnect to live PostgreSQL instead of CSVs | This project uses CSV import mode by design (portable, no gateway needed) | Repoint the M queries at `views/bi_ready/*` through the PostgreSQL connector — a bigger change, not attempted here since CSV import was the documented Phase 6/7 approach |

## What's inside

```
EcommerceAnalytics.pbip                     <- open this in Power BI Desktop
EcommerceAnalytics.Report/                  <- 5 pages, 79 visuals, theme reference
  definition/pages/<Page>/visuals/<id>/visual.json
EcommerceAnalytics.SemanticModel/           <- tables, relationships, measures, M queries (TMDL)
```

See `docs/powerbi_data_model.md` and `docs/powerbi_measures.md` for
the authoritative design/business-definition documentation this
project implements.
