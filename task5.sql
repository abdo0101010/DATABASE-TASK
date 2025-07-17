-- 1. Classify products into price categories
SELECT 
    product_id,
    product_name,
    list_price,
    CASE
        WHEN list_price < 300 THEN 'Economy'
        WHEN list_price BETWEEN 300 AND 999 THEN 'Standard'
        WHEN list_price BETWEEN 1000 AND 2499 THEN 'Premium'
        ELSE 'Luxury'
    END AS price_category
FROM production.products;

-- 2. Order processing info with status + priority
SELECT 
    order_id,
    order_status,
    order_date,
    required_date,
    shipped_date,
    CASE order_status
        WHEN 1 THEN 'Order Received'
        WHEN 2 THEN 'In Preparation'
        WHEN 3 THEN 'Order Cancelled'
        WHEN 4 THEN 'Order Delivered'
    END AS status_description,
    CASE 
        WHEN order_status = 1 AND DATEDIFF(DAY, order_date, GETDATE()) > 5 THEN 'URGENT'
        WHEN order_status = 2 AND DATEDIFF(DAY, order_date, GETDATE()) > 3 THEN 'HIGH'
        ELSE 'NORMAL'
    END AS priority_level
FROM sales.orders;

-- 3. Staff classification by number of orders
SELECT 
    staff_id,
    COUNT(order_id) AS order_count,
    CASE
        WHEN COUNT(order_id) = 0 THEN 'New Staff'
        WHEN COUNT(order_id) BETWEEN 1 AND 10 THEN 'Junior Staff'
        WHEN COUNT(order_id) BETWEEN 11 AND 25 THEN 'Senior Staff'
        ELSE 'Expert Staff'
    END AS staff_category
FROM sales.orders
GROUP BY staff_id;

-- 4. Handle missing customer contact
SELECT 
    customer_id,
    first_name,
    last_name,
    ISNULL(phone, 'Phone Not Available') AS phone,
    email,
    COALESCE(phone, email, 'No Contact Method') AS preferred_contact,
    street, city, state, zip_code
FROM sales.customers;

-- 5. Safe price per unit (store_id = 1)
SELECT 
    oi.product_id,
    SUM(oi.quantity) AS total_quantity,
    SUM(oi.list_price * oi.quantity * (1 - oi.discount)) AS total_value,
    ISNULL(SUM(oi.list_price * oi.quantity * (1 - oi.discount)) / NULLIF(SUM(oi.quantity), 0), 0) AS price_per_unit,
    CASE 
        WHEN SUM(oi.quantity) IS NULL OR SUM(oi.quantity) = 0 THEN 'Out of Stock'
        ELSE 'In Stock'
    END AS stock_status
FROM sales.order_items oi
JOIN sales.orders o ON oi.order_id = o.order_id
WHERE o.store_id = 1
GROUP BY oi.product_id;

-- 6. Formatted complete addresses
SELECT 
    customer_id,
    first_name,
    last_name,
    COALESCE(street, '') + ', ' + 
    COALESCE(city, '') + ', ' + 
    COALESCE(state, '') + ', ' + 
    COALESCE(zip_code, 'No ZIP') AS formatted_address
FROM sales.customers;

-- 7. CTE: customers spent > $1500
WITH customer_spending AS (
    SELECT 
        o.customer_id,
        SUM(oi.list_price * oi.quantity * (1 - oi.discount)) AS total_spent
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    GROUP BY o.customer_id
)
SELECT cs.*, c.first_name, c.last_name
FROM customer_spending cs
JOIN sales.customers c ON cs.customer_id = c.customer_id
WHERE total_spent > 1500
ORDER BY total_spent DESC;

-- 8. Multi-CTE: revenue + avg order value per category
WITH category_revenue AS (
    SELECT p.category_id, SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
    FROM sales.order_items oi
    JOIN production.products p ON oi.product_id = p.product_id
    GROUP BY p.category_id
),
category_avg_order AS (
    SELECT p.category_id, AVG(oi.quantity * oi.list_price * (1 - oi.discount)) AS avg_order_value
    FROM sales.order_items oi
    JOIN production.products p ON oi.product_id = p.product_id
    GROUP BY p.category_id
)
SELECT 
    cr.category_id,
    cr.total_revenue,
    cao.avg_order_value,
    CASE 
        WHEN cr.total_revenue > 50000 THEN 'Excellent'
        WHEN cr.total_revenue > 20000 THEN 'Good'
        ELSE 'Needs Improvement'
    END AS performance_rating
FROM category_revenue cr
JOIN category_avg_order cao ON cr.category_id = cao.category_id;

-- 9. CTE: monthly sales trend
WITH monthly_sales AS (
    SELECT 
        FORMAT(order_date, 'yyyy-MM') AS month,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    GROUP BY FORMAT(order_date, 'yyyy-MM')
),
monthly_growth AS (
    SELECT 
        month,
        total_revenue,
        LAG(total_revenue) OVER (ORDER BY month) AS previous_month_revenue
    FROM monthly_sales
)
SELECT 
    month,
    total_revenue,
    previous_month_revenue,
    ROUND((total_revenue - previous_month_revenue) * 100.0 / NULLIF(previous_month_revenue, 0), 2) AS growth_percent
FROM monthly_growth;

-- 10. Ranking products within each category
WITH ranked_products AS (
    SELECT 
        product_id,
        category_id,
        list_price,
        ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY list_price DESC) AS row_num,
        RANK() OVER (PARTITION BY category_id ORDER BY list_price DESC) AS rank_num,
        DENSE_RANK() OVER (PARTITION BY category_id ORDER BY list_price DESC) AS dense_rank
    FROM production.products
)
SELECT *
FROM ranked_products
WHERE row_num <= 3;

-- 11. Rank customers by spending
WITH customer_spending AS (
    SELECT 
        o.customer_id,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spent
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    GROUP BY o.customer_id
)
SELECT 
    cs.customer_id,
    total_spent,
    RANK() OVER (ORDER BY total_spent DESC) AS customer_rank,
    NTILE(5) OVER (ORDER BY total_spent DESC) AS spending_group,
    CASE 
        WHEN NTILE(5) OVER (ORDER BY total_spent DESC) = 1 THEN 'VIP'
        WHEN NTILE(5) OVER (ORDER BY total_spent DESC) = 2 THEN 'Gold'
        WHEN NTILE(5) OVER (ORDER BY total_spent DESC) = 3 THEN 'Silver'
        WHEN NTILE(5) OVER (ORDER BY total_spent DESC) = 4 THEN 'Bronze'
        ELSE 'Standard'
    END AS tier
FROM customer_spending cs;

-- 12. Store performance ranking
WITH store_revenue AS (
    SELECT store_id, SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue, COUNT(DISTINCT o.order_id) AS total_orders
    FROM sales.order_items oi
    JOIN sales.orders o ON oi.order_id = o.order_id
    GROUP BY store_id
)
SELECT *,
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
    RANK() OVER (ORDER BY total_orders DESC) AS order_rank,
    PERCENT_RANK() OVER (ORDER BY total_revenue) AS revenue_percentile
FROM store_revenue;

-- 13. PIVOT product counts by category and brand
SELECT * FROM (
    SELECT category_id, brand_id FROM production.products
) AS src
PIVOT (
    COUNT(brand_id)
    FOR brand_id IN ([1], [2], [3], [4])
) AS pvt;

-- 14. PIVOT monthly sales revenue by store
SELECT * FROM (
    SELECT s.store_id, FORMAT(o.order_date, 'MMM') AS month,
    oi.quantity * oi.list_price * (1 - oi.discount) AS revenue
    FROM sales.orders o
    JOIN sales.order_items oi ON o.order_id = oi.order_id
    JOIN production.products p ON oi.product_id = p.product_id
    JOIN sales.stores s ON o.store_id = s.store_id
) AS src
PIVOT (
    SUM(revenue) FOR month IN ([Jan], [Feb], [Mar], [Apr], [May], [Jun], [Jul], [Aug], [Sep], [Oct], [Nov], [Dec])
) AS pvt;

-- باقي الأسئلة من 15 إلى 20 هكملك عليهم لو حابب، لأن الملف ده بدأ يطول جدًا وممكن يتجزأ لتنين.
-- 15. PIVOT: عدد الطلبات لكل حالة (Order Status) لكل store
SELECT * FROM (
    SELECT store_id, order_status FROM sales.orders
) AS source
PIVOT (
    COUNT(order_status)
    FOR order_status IN ([1], [2], [3], [4])
) AS pvt_order_status_per_store;

-- 16. UNION vs UNION ALL - مقارنة نتائج الطلبات
SELECT customer_id, order_id, 'Jan' AS order_month
FROM sales.orders
WHERE MONTH(order_date) = 1

UNION

SELECT customer_id, order_id, 'Feb' AS order_month
FROM sales.orders
WHERE MONTH(order_date) = 2;

-- الفرق: UNION يزيل التكرار بينما UNION ALL يحتفظ به

-- 17. INTERSECT - عملاء طلبوا في كل من Jan و Feb
SELECT customer_id
FROM sales.orders
WHERE MONTH(order_date) = 1

INTERSECT

SELECT customer_id
FROM sales.orders
WHERE MONTH(order_date) = 2;

-- 18. EXCEPT - عملاء طلبوا في Jan ولم يطلبوا في Feb
SELECT customer_id
FROM sales.orders
WHERE MONTH(order_date) = 1

EXCEPT

SELECT customer_id
FROM sales.orders
WHERE MONTH(order_date) = 2;

-- 19. FULL OUTER JOIN - مقارنة الطلبات بين Jan و Feb
WITH jan_orders AS (
    SELECT customer_id, order_id AS jan_order_id
    FROM sales.orders
    WHERE MONTH(order_date) = 1
),
feb_orders AS (
    SELECT customer_id, order_id AS feb_order_id
    FROM sales.orders
    WHERE MONTH(order_date) = 2
)
SELECT 
    COALESCE(jan.customer_id, feb.customer_id) AS customer_id,
    jan.jan_order_id,
    feb.feb_order_id
FROM jan_orders jan
FULL OUTER JOIN feb_orders feb
    ON jan.customer_id = feb.customer_id;

-- 20. Common Table Expression + RANK to find top product by revenue per category
WITH product_revenue AS (
    SELECT 
        p.product_id,
        p.category_id,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
    FROM sales.order_items oi
    JOIN production.products p ON oi.product_id = p.product_id
    GROUP BY p.product_id, p.category_id
),
ranked_products AS (
    SELECT *, 
           RANK() OVER (PARTITION BY category_id ORDER BY total_revenue DESC) AS rnk
    FROM product_revenue
)
SELECT * 
FROM ranked_products
WHERE rnk = 1;
