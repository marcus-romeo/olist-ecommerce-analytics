# Enriched 17 Data Dictionary

`customer_initial_purchase_model_enriched` has one row for each eligible `customer_unique_id`. Every predictor summarizes that customer's complete initial-purchase event: every order whose `order_purchase_timestamp` equals the customer's earliest purchase timestamp. Customers must have a fully observable 90-day outcome window.

## Modeling predictors

| Column | Type | Definition |
|---|---|---|
| `customer_state` | Categorical (`character`) | State on the deterministic order-level customer record selected from the initial event. |
| `first_order_amount` | Numeric (`numeric`) | Sum of item `price + freight_value` across all orders in the complete initial-purchase event. |
| `freight_to_order_ratio` | Numeric (`numeric`) | Initial-event `freight_amount / first_order_amount` when the event total is positive; otherwise null. |
| `products_ordered` | Numeric count (`bigint`) | Count of item rows (`order_details.product_id`) across the initial event. |
| `unique_products_ordered` | Numeric count (`bigint`) | Count of distinct `product_id` values across the initial event. |
| `number_of_categories` | Numeric count (`bigint`) | Count of distinct initial-event product categories, using English translation when available, raw category otherwise, and `unknown_product_category` for missing category metadata. |
| `number_of_sellers` | Numeric count (`bigint`) | Count of distinct seller IDs across the initial-event item rows. |
| `payment_installments` | Numeric (`integer`) | Maximum `payment_installments` among payment records linked to the initial event. |
| `primary_category` | Categorical (`text`) | Initial-event category with the greatest summed item price; price ties resolve alphabetically. Uses English translation when available, raw category otherwise, and `unknown_product_category` for missing metadata. `missing_order_details` denotes no linked item detail. |
| `payment_type_group` | Categorical (`text`) | Compact group derived from all initial-event payment types: `credit_card`, `boleto`, `voucher`, `debit_card`, `credit_card_plus_voucher`, `other`, or `missing` when no payment record is linked. |
| `payment_record_count` | Numeric count (`bigint`) | Number of payment records linked to every order in the initial event. |
| `first_order_month` | Calendar categorical/integer (`smallint`) | Month number (1–12) extracted from `first_order_date`. |
| `first_order_weekday` | Calendar categorical/integer (`smallint`) | ISO weekday extracted from `first_order_date`: 1 = Monday through 7 = Sunday. |
| `total_product_weight_g` | Numeric (`bigint`) | Sum of `product_weight_g` across initial-event item rows, returned as null unless every linked product has a weight. |
| `total_product_volume_cm3` | Numeric (`numeric`) | Sum of length × height × width in cm³ across initial-event products, returned as null unless every linked product has all three dimensions. |
| `any_seller_same_state` | Boolean | True when at least one initial-event item's seller state equals the customer state; null when there are no linked item rows. |
| `avg_customer_seller_distance_km` | Numeric (`double precision`) | Item-weighted mean Haversine distance (km) from the customer's ZIP-prefix centroid to each initial-event seller's ZIP-prefix centroid. Null unless every linked item has both geocodes. Geolocation rows are averaged to one centroid per ZIP prefix before the calculation. |

## Identifier, chronology field, and target

| Column | Role / type | Definition |
|---|---|---|
| `customer_unique_id` | Identifier (`text`) | Persistent Olist customer identity used to group multiple order-level `customer_id` records and to define repeat purchase. It is unique in this final table, but is not the raw `customers` primary key. |
| `first_order_date` | Initial-event timestamp / chronological split field (`timestamp without time zone`) | Earliest `orders.order_purchase_timestamp` for the persistent customer identity. All orders at exactly this timestamp form the initial-purchase event. Used for chronological splits, not as a Model A predictor. |
| `repeat_purchase_90d` | Target (`text`: `Yes` / `No`) | `Yes` if the customer placed at least one order strictly after `first_order_date` and on or before `first_order_date + 90 days`; otherwise `No`. Only customers whose full timestamp-precise 90-day window is observable are included. |

## Audit-only columns retained in the physical table

`product_amount` and `freight_amount` are present for backward-compatible schema and auditability, but are deliberately excluded from the Original 8 and Enriched 17 model-feature lists. They are deterministically redundant with `first_order_amount` and `freight_to_order_ratio`.
