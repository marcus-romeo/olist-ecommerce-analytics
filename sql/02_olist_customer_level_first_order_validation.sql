-- 1. Check the total number of customers/rows in the dataset
SELECT COUNT(*) AS total_rows
FROM customer_first_purchase;
-- 2. Confirm that the dataset has exactly one row per unique customer
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customer_first_purchase;
-- 3. Find any customers who appear more than once
SELECT customer_unique_id, COUNT(*) AS row_count
FROM customer_first_purchase
GROUP BY customer_unique_id
HAVING COUNT(*) > 1;
-- 4. Check the date range of customers' first purchases
SELECT MIN(first_order_date) AS earliest_first_order, MAX(first_order_date) AS latest_first_order
FROM customer_first_purchase;
-- 5. Check for NULL values in the key columns
SELECT COUNT(*) FILTER (WHERE customer_unique_id IS NULL) AS customer_id_nulls, COUNT(*) FILTER (WHERE first_order_id IS NULL) AS order_id_nulls, COUNT(*) FILTER (WHERE first_order_date IS NULL) AS order_date_nulls, COUNT(*) FILTER (WHERE first_order_amount IS NULL) AS order_amount_nulls, COUNT(*) FILTER (WHERE products_ordered IS NULL) AS products_nulls, COUNT(*) FILTER (WHERE review_score IS NULL) AS review_nulls, COUNT(*) FILTER (WHERE delivery_days IS NULL) AS delivery_days_nulls, COUNT(*) FILTER (WHERE delivery_variance_days IS NULL) AS delivery_variance_nulls, COUNT(*) FILTER (WHERE delivery_status IS NULL) AS delivery_status_nulls
FROM customer_first_purchase;
-- 6. Check which first-order statuses are represented in the dataset
SELECT first_order_status, COUNT(*) AS customers
FROM customer_first_purchase
GROUP BY first_order_status
ORDER BY customers DESC;
-- 7. Check the distribution of first-order review scores
SELECT review_score, COUNT(*) AS customers
FROM customer_first_purchase
GROUP BY review_score
ORDER BY review_score;
-- 8. Check the distribution of delivery statuses
SELECT delivery_status, COUNT(*) AS customers
FROM customer_first_purchase
GROUP BY delivery_status
ORDER BY customers DESC;
-- 9. Check minimum and maximum values for important numerical variables
SELECT MIN(first_order_amount) AS min_order_amount, MAX(first_order_amount) AS max_order_amount, MIN(products_ordered) AS min_products, MAX(products_ordered) AS max_products, MIN(delivery_days) AS min_delivery_days, MAX(delivery_days) AS max_delivery_days, MIN(delivery_variance_days) AS min_delivery_variance, MAX(delivery_variance_days) AS max_delivery_variance
FROM customer_first_purchase;
-- 10. Look at a sample of actual customer records
SELECT *
FROM customer_first_purchase
LIMIT 20;
-- 11. Investigate why first-order amount is NULL
SELECT first_order_status, COUNT(*) AS customers
FROM customer_first_purchase
WHERE first_order_amount IS NULL
GROUP BY first_order_status
ORDER BY customers DESC;
-- 12. Investigate why product count is NULL
SELECT first_order_status, COUNT(*) AS customers
FROM customer_first_purchase
WHERE products_ordered IS NULL
GROUP BY first_order_status
ORDER BY customers DESC;
-- 13. Check whether NULL order amounts are caused by missing order-detail records
SELECT COUNT(*) AS missing_order_details
FROM customer_first_purchase c
LEFT JOIN order_details od ON c.first_order_id = od.order_id
WHERE c.first_order_amount IS NULL
AND od.order_id IS NULL;
-- 14. Investigate why delivery status is NULL
SELECT first_order_status, COUNT(*) AS customers
FROM customer_first_purchase
WHERE delivery_status IS NULL
GROUP BY first_order_status
ORDER BY customers DESC;
-- 15. Find delivered orders that are missing delivery information
SELECT first_order_id, first_order_date, first_order_status, delivery_days, delivery_variance_days, delivery_status
FROM customer_first_purchase
WHERE first_order_status = 'delivered'
AND delivery_status IS NULL;
-- 16. Verify delivered orders with missing delivery information against the original orders table
SELECT order_id, order_status, order_purchase_timestamp, order_delivered_customer_date, order_estimated_delivery_date
FROM orders
WHERE order_id IN (
    SELECT first_order_id
    FROM customer_first_purchase
    WHERE first_order_status = 'delivered'
    AND delivery_status IS NULL
);
