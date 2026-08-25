# Data

This project does not ship the raw dataset in the repository (it is
~356MB, too large and unnecessary to version-control).

## Where to get it

| Property | Details |
|---|---|
| Source | [Kaggle — Global E-Commerce Dataset +1M Records](https://www.kaggle.com/datasets/akrambelha/global-e-commerce-dataset-1m-records-20242026) |
| Records | ~1 million orders (2024–2026) |
| Type | Synthetically generated |
| Format | PostgreSQL dump (`.sql`) |
| Size | ~356MB |
| Tables | 10 relational tables (matching `schema/create_tables.sql`) |

## Expected local layout

Download the dataset from Kaggle and place it as follows (this path is
git-ignored — see `.gitignore` — so it will never be committed):

```
data/
├── README.md          ← this file (tracked in git)
├── raw/                ← place the downloaded Kaggle dump here (git-ignored)
│   └── ecommerce_db.sql
└── sample/             ← small, clearly-labeled sample data for development
    └── (see below)
```

## Loading the raw data

1. Create the database and run the schema:
   ```bash
   createdb ecommerce_db
   psql -U postgres -d ecommerce_db -f schema/create_tables.sql
   ```
2. Load the raw dump into staging tables (NOT directly into the
   constrained tables — the raw dump contains duplicate primary keys,
   see `sql/data_quality/01_duplicate_records.sql`):
   ```sql
   CREATE TABLE orders_staging AS TABLE orders WITH NO DATA;
   -- repeat for customers_staging, products_staging, order_items_staging, etc.
   ```
   ```bash
   psql -U postgres -d ecommerce_db -f data/raw/ecommerce_db.sql
   ```
3. Run the data-quality checks in `sql/data_quality/` against the
   staging tables to see what needs resolving.
4. Deduplicate from staging into the final constrained tables:
   ```sql
   INSERT INTO orders
   SELECT DISTINCT ON (order_id) *
   FROM orders_staging
   ORDER BY order_id;
   ```
5. Build the date dimension and BI-ready views:
   ```bash
   psql -U postgres -d ecommerce_db -f views/bi_ready/00_run_all_views.sql
   ```

## Sample data

`data/sample/` is reserved for a small, clearly-labeled subset of the
dataset (a few thousand rows) for local development and CI without
needing the full 356MB download. **As of this phase, no sample data has
been generated or committed** — this is scaffolding only. When a sample
is added, it must:

- Be explicitly labeled as a sample (e.g. `orders_sample_5000rows.csv`)
- Never be presented as, or substituted for, real analytical results
- Be small enough to commit directly to git (a few MB at most)

## A note on data realism

As documented throughout this project (see `docs/data_dictionary.md`
and `insights/key_findings.md`), the source dataset is **synthetically
generated** and several columns show unrealistically flat/uniform
distributions (e.g. shipping delivery times, product profit margins,
payment method usage). This is called out transparently everywhere it
affects an analysis, rather than hidden. All SQL/Python logic is
written to be correct and production-ready regardless — the
methodology, not the specific figures, is the portfolio deliverable.
