# Olist 90-Day Repeat-Purchase Prediction

> **Status:** In progress — Logistic Regression baseline complete; Random Forest next; Tableau planned for a later stage.

Can customer and first-purchase characteristics in historical order data help predict whether a customer will place another order within 90 days?

This portfolio project uses the Olist Brazilian e-commerce dataset to build and evaluate a customer-level repeat-purchase prediction workflow. PostgreSQL and SQL are used to understand, prepare, and validate the data. Python, pandas, and scikit-learn are used to create a chronological train/test split, preprocess the model features, train a Logistic Regression baseline, and evaluate its out-of-sample performance.

## Current Results

The Logistic Regression baseline shows very limited predictive value on the later, out-of-sample testing period:

| Metric | Result |
|---|---:|
| ROC-AUC | Approximately 0.506 |
| PR-AUC | Approximately 0.015 |
| Testing-set repeat-purchase rate | Approximately 1.31% |
| Positive predictions at the 0.50 threshold | 0 |

At the default classification threshold of 0.50, the model predicts every testing customer as a non-repeat purchaser. Its ROC-AUC is close to random ranking, and its PR-AUC is only slightly above the testing-set positive rate.

These results make the model a useful reference point for future comparisons, but not a successful predictive model.

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
   Use pandas and scikit-learn to preprocess the data and train a Logistic Regression baseline.

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
- Logistic Regression as the initial baseline; and
- ROC-AUC and PR-AUC alongside threshold-based classification metrics.

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
│   ├── 01–08  First-purchase cohort, 90-day windows, target, and validation
│   ├── 09–12  Analytical and initial-purchase modeling datasets and validation
│   └── 13     Returning-versus-nonreturning descriptive analysis
└── notebooks/
    └── 101_olist_initial_purchase_logistic_regression.ipynb
```

The SQL scripts create the PostgreSQL analytical tables and are intended to be run in numerical order. Build scripts use `DROP TABLE IF EXISTS` followed by `CREATE TABLE AS`, allowing the workflow to be rerun after its source tables are available.

The notebook loads the final SQL modeling table, completes the Python preprocessing and chronological split, trains the Logistic Regression baseline, and evaluates the saved results.

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

- Random Forest
- Tableau

## Current Status and Next Steps

- [x] Build and validate the customer-level first-purchase dataset
- [x] Define complete customer-specific 90-day observation windows
- [x] Create and validate the repeat-purchase target
- [x] Create a leakage-aware initial-purchase modeling dataset
- [x] Implement a chronological train/test split
- [x] Train and evaluate the Logistic Regression baseline
- [ ] Train and compare a Random Forest model
- [ ] Compare model performance against the baseline
- [ ] Develop Tableau visualizations and presentation materials
- [ ] Summarize final findings, limitations, and recommendations

## Limitations

The current positive class is rare, and the initial-purchase feature set provides little separation between repeat purchasers and non-repeat purchasers. The present results should therefore be interpreted as a weak baseline assessment of the available signal, not evidence that the model is ready for customer targeting or operational use.

This remains an in-progress portfolio project focused on developing and demonstrating a careful analytics workflow.
