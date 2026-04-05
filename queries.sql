-- 1. List all rented films with rental date, return date, and customer ID
SELECT 
    f.title, 
    r.rental_date, 
    r.return_date, 
    r.customer_id 
FROM rental r
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id;

-- 2. Total revenue by store
SELECT 
    s.store_id, 
    SUM(p.amount) AS total_revenue
FROM payment p
JOIN rental r ON p.rental_id = r.rental_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN store s ON i.store_id = s.store_id
GROUP BY s.store_id;

-- 3. Top 10 most rented films
SELECT 
    f.title, 
    COUNT(r.rental_id) AS rental_count
FROM rental r
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
GROUP BY f.film_id
ORDER BY rental_count DESC
LIMIT 10;

-- 4. Average rental duration per film
SELECT 
    f.title, 
    AVG(JULIANDAY(r.return_date) - JULIANDAY(r.rental_date)) AS avg_rental_duration
FROM rental r
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
GROUP BY f.film_id;

-- 5. Customers with no rentals
SELECT 
    c.customer_id, 
    c.first_name, 
    c.last_name
FROM customer c
LEFT JOIN rental r ON c.customer_id = r.customer_id
WHERE r.rental_id IS NULL;

-- 6. Actor appearing in the most films
SELECT 
    a.first_name || ' ' || a.last_name AS actor_name, 
    COUNT(fa.film_id) AS films_count
FROM film_actor fa
JOIN actor a ON fa.actor_id = a.actor_id
GROUP BY a.actor_id
ORDER BY films_count DESC
LIMIT 1;

-- 7. Top 5 customers by total spending
SELECT 
    c.first_name || ' ' || c.last_name AS customer_name, 
    SUM(p.amount) AS total_spent
FROM payment p
JOIN customer c ON p.customer_id = c.customer_id
GROUP BY c.customer_id
ORDER BY total_spent DESC
LIMIT 5;

-- 8. Number of rentals per month in 2006
SELECT 
    strftime('%Y-%m', r.rental_date) AS rental_month, 
    COUNT(r.rental_id) AS rental_count
FROM rental r
WHERE strftime('%Y', r.rental_date) = '2006'
GROUP BY rental_month
ORDER BY rental_month;

-- 9. Revenue by film and category
SELECT 
    c.name AS category_name, 
    f.title, 
    SUM(p.amount) AS total_revenue
FROM payment p
JOIN rental r ON p.rental_id = r.rental_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
JOIN film_category fc ON f.film_id = fc.film_id
JOIN category c ON fc.category_id = c.category_id
GROUP BY c.category_id, f.film_id
ORDER BY c.category_id, total_revenue DESC;

-- 10. Customer rental count and total spending
SELECT 
    c.first_name || ' ' || c.last_name AS customer_name,
    COUNT(r.rental_id) AS rental_count,
    SUM(p.amount) AS total_spent
FROM payment p
JOIN rental r ON p.rental_id = r.rental_id
JOIN customer c ON p.customer_id = c.customer_id
GROUP BY c.customer_id
ORDER BY rental_count DESC;

-- 11. Rank films by revenue within each category
SELECT 
    c.name AS category_name,
    f.title,
    SUM(p.amount) AS total_revenue,
    RANK() OVER (PARTITION BY c.category_id ORDER BY SUM(p.amount) DESC) AS revenue_rank
FROM payment p
JOIN rental r ON p.rental_id = r.rental_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
JOIN film_category fc ON f.film_id = fc.film_id
JOIN category c ON fc.category_id = c.category_id
GROUP BY c.category_id, f.film_id
ORDER BY category_name, revenue_rank;

-- 12. Films that were never rented
SELECT 
    f.title
FROM film f
LEFT JOIN inventory i ON f.film_id = i.film_id
LEFT JOIN rental r ON i.inventory_id = r.inventory_id
GROUP BY f.film_id
HAVING COUNT(r.rental_id) = 0;

-- 13. Revenue percentage contribution of each film within its category
WITH CategoryRevenue AS (
    SELECT 
        fc.category_id,
        f.film_id,
        SUM(p.amount) AS film_revenue
    FROM payment p
    JOIN rental r ON p.rental_id = r.rental_id
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film f ON i.film_id = f.film_id
    JOIN film_category fc ON f.film_id = fc.film_id
    GROUP BY fc.category_id, f.film_id
),
CategoryTotalRevenue AS (
    SELECT 
        fc.category_id,
        SUM(p.amount) AS category_revenue
    FROM payment p
    JOIN rental r ON p.rental_id = r.rental_id
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film f ON i.film_id = f.film_id
    JOIN film_category fc ON f.film_id = fc.film_id
    GROUP BY fc.category_id
)
SELECT 
    c.name AS category_name,
    f.title,
    cr.film_revenue,
    cr.film_revenue / ctr.category_revenue * 100 AS revenue_percentage
FROM CategoryRevenue cr
JOIN CategoryTotalRevenue ctr ON cr.category_id = ctr.category_id
JOIN film f ON cr.film_id = f.film_id
JOIN category c ON cr.category_id = c.category_id
ORDER BY category_name, revenue_percentage DESC;

-- 14. Customers spending above average
WITH AverageSpending AS (
    SELECT AVG(amount) AS avg_spending
    FROM payment
),
CustomerSpending AS (
    SELECT 
        c.customer_id, 
        c.first_name || ' ' || c.last_name AS customer_name, 
        SUM(p.amount) AS total_spent
    FROM payment p
    JOIN customer c ON p.customer_id = c.customer_id
    GROUP BY c.customer_id
)
SELECT 
    cs.customer_name,
    cs.total_spent
FROM CustomerSpending cs, AverageSpending avg
WHERE cs.total_spent > avg.avg_spending
ORDER BY cs.total_spent DESC;

-- 15. Monthly revenue growth
WITH MonthlyRevenue AS (
    SELECT 
        strftime('%Y-%m', r.rental_date) AS rental_month,
        SUM(p.amount) AS total_revenue
    FROM payment p
    JOIN rental r ON p.rental_id = r.rental_id
    GROUP BY rental_month
)
SELECT 
    rental_month,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY rental_month) AS previous_month_revenue,
    ((total_revenue - LAG(total_revenue) OVER (ORDER BY rental_month)) / LAG(total_revenue) OVER (ORDER BY rental_month)) * 100 AS growth_percentage
FROM MonthlyRevenue
ORDER BY rental_month;

-- 16. Staff member with the most rentals
SELECT 
    s.first_name || ' ' || s.last_name AS staff_name, 
    COUNT(r.rental_id) AS rental_count
FROM rental r
JOIN staff s ON r.staff_id = s.staff_id
GROUP BY s.staff_id
ORDER BY rental_count DESC
LIMIT 1;

-- 17. Films with more than 10 actors
SELECT 
    f.title
FROM film f
JOIN film_actor fa ON f.film_id = fa.film_id
GROUP BY f.film_id
HAVING COUNT(fa.actor_id) > 10;

-- 18. Films with rental rate above average
SELECT 
    f.title,
    f.rental_rate
FROM film f
WHERE f.rental_rate > (
    SELECT AVG(rental_rate) FROM film
);
