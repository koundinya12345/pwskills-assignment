-- 1. Rank the customers based on the total amount they've spent on rentals.
SELECT customer_id, first_name, last_name, email, total_amount_spent,
       RANK() OVER (ORDER BY total_amount_spent DESC) AS customer_rank
FROM (
    SELECT c.customer_id, c.first_name, c.last_name, c.email, 
           SUM(p.amount) AS total_amount_spent
    FROM customers c
    JOIN payments p ON c.customer_id = p.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.email
) AS customer_spending;

-- 2. Calculate the cumulative revenue generated by each film over time.
SELECT film_id, title, release_year, rental_date,
       SUM(amount) OVER (PARTITION BY film_id ORDER BY rental_date) AS cumulative_revenue
FROM rentals
JOIN payments USING(rental_id)
JOIN inventory USING(inventory_id)
JOIN films USING(film_id);

-- 3. Determine the average rental duration for each film, considering films with similar lengths.
SELECT film_id, title, length, AVG(rental_duration) AS avg_rental_duration
FROM (
    SELECT film_id, title, length, 
           EXTRACT(DAY FROM AVG(return_date - rental_date)) AS rental_duration
    FROM rentals
    JOIN inventory USING(inventory_id)
    JOIN films USING(film_id)
    GROUP BY film_id, title, length
) AS film_avg_rental_duration;

-- 4. Identify the top 3 films in each category based on their rental counts.
WITH ranked_films AS (
    SELECT film_id, title, category_id,
           ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY rental_count DESC) AS film_rank
    FROM (
        SELECT f.film_id, f.title, f.category_id, COUNT(*) AS rental_count
        FROM films f
        JOIN inventory i ON f.film_id = i.film_id
        JOIN rentals r ON i.inventory_id = r.inventory_id
        GROUP BY f.film_id, f.title, f.category_id
    ) AS film_rental_counts
)
SELECT category_id, title, rental_count
FROM (
    SELECT rf.category_id, rf.title, rental_count,
           RANK() OVER (PARTITION BY rf.category_id ORDER BY rf.film_rank) AS category_rank
    FROM ranked_films rf
    WHERE rf.film_rank <= 3
) AS top_films
WHERE category_rank <= 3;

-- 5. Calculate the difference in rental counts between each customer's total rentals and the average rentals across all customers.
SELECT c.customer_id, c.first_name, c.last_name, total_rentals,
       total_rentals - avg_rentals AS rental_count_difference
FROM (
    SELECT customer_id, COUNT(*) AS total_rentals
    FROM rentals
    GROUP BY customer_id
) AS customer_total_rentals
JOIN customers c ON customer_total_rentals.customer_id = c.customer_id
CROSS JOIN (
    SELECT AVG(total_rentals) AS avg_rentals
    FROM (
        SELECT COUNT(*) AS total_rentals
        FROM rentals
        GROUP BY customer_id
    ) AS customer_rentals
) AS average_rentals;

-- 6. Find the monthly revenue trend for the entire rental store over time.
SELECT EXTRACT(MONTH FROM rental_date) AS rental_month,
       EXTRACT(YEAR FROM rental_date) AS rental_year,
       SUM(amount) AS monthly_revenue
FROM payments
GROUP BY rental_month, rental_year
ORDER BY rental_year, rental_month;

-- 7. Identify the customers whose total spending on rentals falls within the top 20% of all customers.
SELECT customer_id, first_name, last_name, email, total_amount_spent
FROM (
    SELECT customer_id, first_name, last_name, email, total_amount_spent,
           NTILE(5) OVER (ORDER BY total_amount_spent DESC) AS customer_group
    FROM (
        SELECT c.customer_id, c.first_name, c.last_name, c.email,
               SUM(p.amount) AS total_amount_spent
        FROM customers c
        JOIN payments p ON c.customer_id = p.customer_id
        GROUP BY c.customer_id, c.first_name, c.last_name, c.email
    ) AS customer_spending
) AS top_customers
WHERE customer_group = 1;

-- 8. Calculate the running total of rentals per category, ordered by rental count.
SELECT category_id, title, rental_count,
       SUM(rental_count) OVER (PARTITION BY category_id ORDER BY rental_count DESC) AS running_total_rentals
FROM (
    SELECT f.category_id, f.title, COUNT(*) AS rental_count
    FROM films f
    JOIN inventory i ON f.film_id = i.film_id
    JOIN rentals r ON i.inventory_id = r.inventory_id
    GROUP BY f.category_id, f.title
) AS category_rental_counts;

-- 9. Find the films that have been rented less than the average rental count for their respective categories.
SELECT f.film_id, f.title, f.category_id, rental_count
FROM (
    SELECT film_id, COUNT(*) AS rental_count
    FROM inventory
    JOIN rentals USING(inventory_id)
    GROUP BY film_id
) AS film_rental_counts
JOIN films f ON film_rental_counts.film_id = f.film_id
WHERE rental_count < (
    SELECT AVG(rental_count)
    FROM (
        SELECT category_id, COUNT(*) AS rental_count
        FROM inventory
        JOIN rentals USING(inventory_id)
        JOIN films USING(film_id)
        GROUP BY category_id
    ) AS category_rental_counts
    WHERE f.category_id = category_rental_counts.category_id
);

-- 10. Identify the top 5 months with the highest revenue and display the revenue generated in each month.
SELECT rental_month, rental_year, monthly_revenue
FROM (
    SELECT EXTRACT(MONTH FROM rental_date) AS rental_month,
           EXTRACT(YEAR FROM rental_date) AS rental_year,
           SUM(amount) AS monthly_revenue,
           RANK() OVER (ORDER BY SUM(amount) DESC) AS revenue_rank
    FROM payments
    GROUP BY rental_month, rental_year
) AS top_months
WHERE revenue_rank <= 5;
