# Power BI Dashboard

**Status: fully specified and validated (Phase 6 + Phase 7). The
`.pbix` report file itself is still not built** — Power BI Desktop
project files are proprietary binaries that cannot be reliably
hand-authored outside Power BI Desktop, so none is fabricated here.
Everything needed to build the real report quickly in Power BI Desktop
is documented and validated instead, plus a non-binary HTML mockup so
the design can be reviewed visually before that build happens.

## What exists in this folder

| File | Contents |
|---|---|
| [`dashboard_pages.md`](dashboard_pages.md) | **The build blueprint.** Every page, every KPI card, every visual (with exact fields/measures), every slicer, tooltip, and navigation element — populated with real numbers computed from the synthetic test fixture |
| [`model_design.md`](model_design.md) | Power Query build steps + Phase 6 data-model validation results |
| [`dax_measures.md`](dax_measures.md) | Copy-paste-ready DAX (condensed; `docs/powerbi_measures.md` is authoritative for definitions/caveats) |
| [`testing_validation.md`](testing_validation.md) | Phase 7 KPI/filter/cross-filter/ranking/risk validation results |
| [`theme/ecommerce_theme.json`](theme/ecommerce_theme.json) | Power BI Desktop theme file (import via View → Themes → Browse for themes) |
| [`pbip/`](pbip/) | **A genuine, openable Power BI Project (.pbip)** — complete semantic model (TMDL) + a real, working report scaffold (PBIR). Open in Power BI Desktop, refresh, and Save As `.pbix`. See `pbip/README.md` for the exact steps and an honest confidence breakdown of what's fully solid vs. best-effort. |
| [`mockup/dashboard_mockup.html`](mockup/dashboard_mockup.html) | A static, navigable HTML/Chart.js preview of all 5 pages — open directly in a browser. Superseded by `pbip/` for anyone who wants the real, interactive file, but still useful for a quick visual review without opening Power BI Desktop. |

## Dashboard scope — specified, not yet built as a `.pbix`

A 5-page report (full detail in `dashboard_pages.md`):

1. **Executive Overview** — 6 KPIs, revenue/order trend, category & top-product breakdown, segment distribution, a DAX-driven dynamic insight text
2. **Transaction & Payment Health** — 6 KPIs, payment success/failure trend, payment-method performance, cancellation trend, transaction-status distribution; date/country/payment-method/segment slicers
3. **Customer Analytics** — 5 KPIs, RFM distribution & revenue, churn by segment, retention rate, top-customers table; date/country/RFM slicers
4. **Product & Revenue** — 4 KPIs, top products, category revenue+profit, Pareto analysis, product matrix, category contribution; date/category slicers
5. **Risk & Anomalies** — explicitly labeled **"Rule-Based Risk Monitoring"** (never "fraud detection" — no confirmed-fraud label exists in this data), 5 KPIs, risk distribution/trend/by-payment-method/by-country, high-value anomalies, duplicate candidates; date/country/payment-method slicers, plus one drillthrough page (Order Detail) and one tooltip page (risk signal detail)

## Data source & refresh instructions

Connect Power BI Desktop to **either**:
- **Live PostgreSQL** — Get Data → PostgreSQL database → point at
  `views/bi_ready/*` (enables scheduled refresh if published to the
  Power BI Service with a data gateway configured for the Postgres
  instance), **or**
- **Import `data/exports/*.csv`** — Get Data → Text/CSV, one query per
  file (fully portable, no gateway needed, but requires re-running
  `python/export_bi_data.py` and re-importing to refresh)

Either path produces the identical model (`docs/python_analytics.md`
§10 confirms the two sources reconcile). See `model_design.md` §1 for
the exact Power Query steps for each table, including the two
DimCustomer merges and the DimPaymentMethod Remove-Duplicates step.

**Known gap:** `FactOrderItems` currently has no CSV export (see
`model_design.md` §4) — the import (CSV) path can build every table
except `FactOrderItems`, which requires the live-PostgreSQL connection
until `python/export_bi_data.py` is extended with a line-item-grain
export.

## What's needed before an actual `.pbix` can be published

- [x] Star schema, relationships, DAX measures designed and validated (Phase 6)
- [x] Full page-by-page visual specification written and validated against real (synthetic) numbers (Phase 7)
- [x] HTML mockup for visual/layout review (Phase 7)
- [x] **Genuine `.pbip` Power BI Project generated** — complete semantic model + report scaffold (Phase 8, see `pbip/README.md`)
- [ ] Opened in actual Power BI Desktop, `DataFolderPath` parameter set, refreshed, and verified against `powerbi/testing_validation.md`
- [ ] Remaining charts (trend lines, category/product bars, RFM donuts, Pareto, matrix) added per `dashboard_pages.md` — the model/measures are ready; this is drag-and-drop, not a rebuild
- [ ] Real ~1M-row dataset loaded (everything above is validated only against the synthetic `data/sample/` fixture)
- [ ] Saved as the final `.pbix`
