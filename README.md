# Olist 90-Day Repeat-Purchase Prediction

> **Status:** In progress — corrected original-feature baseline results are complete; enriched Model A feature engineering is ready for time-aware validation. Tableau is planned for a later stage.

Can customer and first-purchase characteristics in historical order data help predict whether a customer will place another order within 90 days?

This portfolio project uses the Olist Brazilian e-commerce dataset to build and evaluate a customer-level repeat-purchase prediction workflow. PostgreSQL and SQL are used to understand, prepare, and validate the data. Python, pandas, and scikit-learn are used to create a chronological train/test split, preprocess the model features, train three baseline classifiers, and evaluate their out-of-sample performance.

## Current Results

The corrected original-feature baselines use the complete initial-purchase-event definition, the timestamp-precise 90-day eligibility rule, and the same chronological complete-case split. The latest 20% test period has a 1.31% repeat-purchase rate.

| Model | Test ROC-AUC | Test Average Precision | Positive predictions at 0.50 |
|---|---:|---:|---:|
| Logistic Regression | 0.5098 | 0.0165 | 0 |
| Random Forest | 0.5125 | 0.0138 | 25 |
| Gradient Boosting | 0.5336 | 0.0150 | 12 |

All predicted positives from the two tree models are false positives at the unchanged 0.50 threshold; Logistic Regression predicts none. The weak test ranking results and the difference between training and test performance make these useful reference baselines, not successful predictive models. Average Precision is interpreted relative to the 1.31% test-set positive prevalence.

## Business Question

**Can customer and first-purchase characteristics help predict whether a customer will place another order within 90 days of their initial purchase?**

The prediction point is immediately after the customer places the initial order. The model therefore uses only information available at that point, such as customer state, order value, product counts, seller counts, payment installments, and the freight-to-order-value ratio.

Post-purchase information such as reviews, delivery time, delivery status, and final order status is excluded from the predictive feature set to reduce target leakage.

## Repeat-Purchase Definition

A customer is classified as a 90-day repeat purchaser when:

- the customer places at least one additional order;
- the additional order timestamp is strictly later than the initial-purchase timestamp; and
- the additional order is placed on or before the end of that customer's 90-day observation window.

Orders sharing the initial-purchase timestamp are treated as part of the initial purchase rather than repeat orders.

Customers whose initial purchases occur too close to the end of the source data are excluded because their full 90-day outcomes cannot be observed.

## Approach

The project is organized around the CRISP-DM framework:

1. **Business understanding**
   Define a repeat-purchase prediction question and an initial-purchase prediction point.

2. **Data understanding**
   Inspect order, customer, item, payment, product, review, and delivery data in PostgreSQL.

3. **Data preparation**
   Build a one-row-per-customer dataset, define individual 90-day observation windows, construct the outcome, and prepare leakage-aware model features.

4. **Modeling**
   Use pandas and scikit-learn to preprocess the data and train Logistic Regression, Random Forest, and Gradient Boosting baselines.

5. **Evaluation**
   Test on a later chronological period and evaluate the imbalanced outcome with a confusion matrix, ROC-AUC, and precision-recall analysis.

6. **Presentation and deployment**
   Tableau visualization and presentation work is planned for a later stage. This project is not currently deployed as a production system.

## Modeling Design

The current model uses:

- one row per unique customer;
- eight first-purchase predictors;
- an approximately 80/20 chronological train/test split;
- numeric feature standardization;
- one-hot encoding for customer state;
- preprocessing fitted only on the training data;
- Logistic Regression, Random Forest, and Gradient Boosting baselines; and
- ROC-AUC and Average Precision alongside threshold-based classification metrics.

The chronological split uses customers with earlier first-purchase dates for training and customers with later first-purchase dates for testing. This more closely represents predicting outcomes for future customers than a random split would.

## Analytical Practices Demonstrated

- Customer-level analytical dataset design
- Explicit outcome and observation-window definitions
- SQL validation after major transformation steps
- Leakage-aware feature selection
- Chronological out-of-sample testing
- Training-only preprocessing
- Evaluation appropriate for a highly imbalanced target
- Numbered, rerunnable PostgreSQL build scripts
- Git and GitHub version control

## Repository Structure

```text
olist-ecommerce-analytics/
├── README.md
├── requirements.txt
├── sql/
│   ├── 01–08  Complete initial-purchase events, 90-day cohort, target, and validation
│   ├── 09–12  Analytical and initial-purchase modeling datasets and validation
│   ├── 13     Returning-versus-nonreturning descriptive analysis
│   └── 14–15  Enriched, leakage-safe initial-purchase Model A dataset and validation
└── notebooks/
    ├── 101_olist_initial_purchase_logistic_regression.ipynb
    ├── 102_olist_initial_purchase_random_forest.ipynb
    └── 103_olist_initial_purchase_gradient_boosting.ipynb
```

The SQL scripts create the PostgreSQL analytical tables and are intended to be run in numerical order. Build scripts use `DROP TABLE IF EXISTS` followed by `CREATE TABLE AS`, allowing the workflow to be rerun after its source tables are available.

The baseline notebooks load the original SQL modeling table, complete Python preprocessing and a chronological split, and evaluate Logistic Regression, Random Forest, and Gradient Boosting. The enriched SQL table is prepared for a later, time-aware validation comparison; no enriched-model results are claimed yet.

## Tools

**Used in the current workflow**

- PostgreSQL
- SQL
- Python
- pandas
- scikit-learn
- Jupyter Notebook
- matplotlib
- Git and GitHub

**Planned**

- Tableau

## Current Status and Next Steps

- [x] Build and validate the customer-level first-purchase dataset
- [x] Define complete customer-specific 90-day observation windows
- [x] Create and validate the repeat-purchase target
- [x] Create a leakage-aware initial-purchase modeling dataset
- [x] Implement a chronological train/test split
- [x] Train and evaluate Logistic Regression, Random Forest, and Gradient Boosting baselines
- [x] Correct the complete initial-purchase event definition and timestamp-precise 90-day eligibility rule
- [x] Build a leakage-safe enriched Model A feature dataset
- [ ] Compare original and enriched feature sets with time-aware validation
- [ ] Develop Tableau visualizations and presentation materials
- [ ] Summarize final findings, limitations, and recommendations

## Limitations

The current positive class is rare, and the initial-purchase feature set provides little separation between repeat purchasers and non-repeat purchasers. The present results should therefore be interpreted as a weak baseline assessment of the available signal, not evidence that the model is ready for customer targeting or operational use.

This remains an in-progress portfolio project focused on developing and demonstrating a careful analytics workflow.
