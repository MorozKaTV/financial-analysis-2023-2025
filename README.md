# The Daily Grind — Financial Analysis 2023-2025

SQL data-cleaning layer for a margin analysis of a coffee retailer. Three yearly
order extracts are combined, audited, cleaned and joined into a single analysis-ready table
that feeds a Power BI dashboard.

**Stack:** PostgreSQL 18.6 · pgAdmin 4 · Power BI · VS Code + SQLTools

---

## Contents

- [Repository layout](#repository-layout)
- [The brief](#the-brief)
- [The data](#the-data)
- [Data-quality audit](#data-quality-audit)
- [Results](#results)
- [Notes on scope](#notes-on-scope)

---

## Repository layout

```
├─ Pricing-Analysis-2023-2025.pptx  Presentation: brief, methodology, findings, recommendations
├─ sql/
│  ├─ 00_schema.sql        Table definitions and data types for the five source tables
│  └─ 01_clean_orders.sql  Data-quality audit (Steps 1-9) + the cleaning query (Step 10).
│                          Step 3 creates the orders_combined view the audit reads from.
├─ data/                   Source CSVs, exactly as received
├─ docs/                   The original brief
└─ images/                 Power BI dashboard screenshots
```

---

## The brief

The Director of Operations reported a falling profit margin across the portfolio, attributed
to rising COGS and tariffs, and asked for three things from the 2023-2025 order data:

1. Identify all products with a Gross Margin % (GMP) below 30% in **Q3 2025**.
2. Build a dashboard showing **year-over-year GMP and Revenue by Category, Product and Region**.
3. Provide data-backed recommendations on which items need a **price increase** or
   **discontinuation**.

This repository covers the data preparation. The analysis and the recommendations live in the
Power BI report and the accompanying presentation — see [Results](#results).

---

## The data

| Table | Grain | Rows | Notes |
|---|---|---:|---|
| `customers` | one row per customer | 200 | `Region` ∈ {East, North, South, West} |
| `products` | one row per product | 50 | `ProductCategory` ∈ {Accessories, Consumables, Grinders & Brewers, Merchandise, Subscriptions} |
| `orders_2023` | one row per order line | 1,603 | |
| `orders_2024` | one row per order line | 1,570 | |
| `orders_2025` | one row per order line | 1,283 | `OrderDate` arrives as `M/D/YYYY` — see below |

The 2025 extract's `OrderDate` ships as `M/D/YYYY` (e.g. `1/13/2025`) rather than the ISO
`YYYY-MM-DD` the other two years use, so it won't load into a `date` column as-is. This was
originally caught and fixed by hand outside SQL, which left the pipeline unreproducible; it's
now parsed in code with `TO_DATE(OrderDate, 'FMMM/FMDD/YYYY')` in Step 3, so the pipeline runs
unmodified from the raw file.

---

## Data-quality audit

Steps 1-9 of [`sql/01_clean_orders.sql`](sql/01_clean_orders.sql) are the profiling queries
used to audit the raw data. They are kept in the file, commented out, with each finding
recorded directly beneath the query that produced it.

| # | Check | Finding | Decision |
|---|---|---|---|
| 1 | Duplicate IDs in `customers` / `products` | None — 200 and 50 distinct | No action |
| 2 | Valid values in `Region` / `ProductCategory` | 4 and 5 expected values, no misspellings | No action |
| 4 | Duplicate `OrderID` after combining | None — 4,456 rows, 4,456 distinct IDs | No action |
| 5 | Null values | 65 rows: **24 null `CustomerID`**, **41 null `Revenue`**, nothing elsewhere | See below |
| 6 | `Quantity` outliers (IQR method) | None. MIN 1, MAX 4, AVG ≈ 2.5, STDDEV ≈ 1.1 | No action |
| 7 | Negative or zero `Revenue` / `COGS` | None — minimums are 15.23 and 5.39. Gross margin is also never ≤ 0 (minimum 1.83) | No action |
| 8 | `OrderDate` range | 2023-01-02 to 2025-11-30, nothing out of range | No action |
| 9 | Row count after the joins | 4,432 (Matches the expected 4,456 − 24) | No action  |

**Handling the nulls.** The 24 rows with no `CustomerID` are dropped by the `INNER JOIN` in
Step 10 — an order that cannot be attributed to a customer is unusable for the regional
breakdown the brief asks for. The 41 rows with no `Revenue` 
are recovered using `COALESCE(Revenue, Price * Quantity)`. That
substitution assumes list price with no discounts, returns or currency differences, which
holds for this dataset

**Net effect: 4,456 → 4,432 rows.**

---

## Results

The cleaned table is loaded into Power BI, where the year-over-year margin analysis and the
pricing recommendations were built.

📑 **Presentation:** [Pricing-Analysis-2023-2025.pptx](Pricing-Analysis-2023-2025.pptx)

The Power BI report, filtered to Q3 2025:

![Revenue & Margin dashboard: margin and revenue by product, region and category](images/Page%201%20Financial%20Analysis%20dashboard.png)

![Product analysis: revenue by product, and pricing and margin analysis with recommended prices](images/Page%202%20Financial%20Analysis%20dashboard.png)

### Recommendations

Six products fell below the 30% gross margin target in Q3 2025. Raise each price to bring
its margin back to 30%.

| Product | Q3 2025 Margin | Current Price | Recommended Price | Change |
|---|---:|---:|---:|---:|
| Minimalist Keychain | 11.98% | $27.37 | $34.41 | +25.74% |
| Chemex Filters (100 pack) | 12.00% | $24.10 | $30.30 | +25.72% |
| Logo Hoodie (Black) | 12.03% | $15.23 | $19.14 | +25.67% |
| Gooseneck Electric Kettle | 25.52% | $34.87 | $37.10 | +6.40% |
| Branded Ceramic Mug (Large) | 27.99% | $43.20 | $44.44 | +2.87% |
| Pour-Over Starter Kit | 28.97% | $105.23 | $106.78 | +1.47% |

---

## Notes on scope

This repository is the data-preparation layer only. It deliberately contains no analytical
queries — the aggregation, the year-over-year comparisons and the visualisations are all done
in Power BI
