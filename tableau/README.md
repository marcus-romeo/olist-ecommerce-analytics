# Tableau Dashboard Data

## Purpose

This Tableau layer supports a business-facing dashboard answering: **What distinguishes customers who make another purchase within 90 days from those who do not?** It complements the locked predictive-modeling work with descriptive cohort comparisons.

## Data sources and grain

`data/olist_repeat_purchase_tableau.csv` is a read-only export of PostgreSQL table `customer_initial_purchase_model_enriched`. It contains one row per eligible persistent `customer_unique_id`, representing the complete initial-purchase event and that customer's 90-day repeat outcome.

`data/model_summary_final_holdout.csv` contains the locked aggregate metrics from the final future-holdout evaluation. It is a one-row summary and must not be joined to the customer-level file.

`repeat_purchase_flag` is `1` when `repeat_purchase_90d` is `Yes`, otherwise `0`. Tableau will calculate filter-aware eligible-customer count, repeat-customer count, and repeat rate from the customer-level CSV.

## Planned descriptive comparisons

- Primary findings: primary product category and initial basket size (`products_ordered`)
- Supporting comparisons: payment installments and customer-to-seller distance
- Business context: first-order amount, retained despite relatively weak observed separation

These descriptive relationships are associations, not causal effects. Post-purchase fields are intentionally excluded. Model-summary metrics come only from the locked final future-holdout evaluation.
