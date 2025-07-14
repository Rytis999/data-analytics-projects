
-- Rental Analysis Project: SQL Queries for Car Rental Business
-- Author: Rytis Rimašauskas
-- Description: This SQL script contains various queries used to analyze a fictional car rental dataset.
-- Focus areas include: rental frequency, revenue analysis, customer activity, and temporal trends.

-- 1. Count how many times each car (make & model) was rented
SELECT cars.make, cars.model, COUNT(*) AS rental_count
FROM cars
INNER JOIN rentals ON cars.car_id = rentals.car_id
GROUP BY cars.make, cars.model
ORDER BY rental_count DESC;

-- 2. Find customers who rented more than once
SELECT customers.full_name, COUNT(*)
FROM customers 
INNER JOIN rentals ON customers.customer_id = rentals.customer_id
GROUP BY customers.full_name
HAVING COUNT(*) >= 2;

-- 3. Calculate the average rental price per car brand (make)
SELECT cars.make, ROUND( AVG(rentals.total_price), 0) AS average_price
FROM cars 
INNER JOIN rentals ON cars.car_id = rentals.car_id
WHERE rentals.rental_date IS NOT NULL
GROUP BY cars.make 
ORDER BY average_price DESC;

-- 4. Top 5 customers by total spending on rentals
SELECT customers.full_name, SUM(rentals.total_price) AS total_price
FROM customers
INNER JOIN rentals ON customers.customer_id = rentals.customer_id
GROUP BY customers.full_name
ORDER BY total_price DESC
LIMIT 5;

-- 5. Total rentals by car make and model
SELECT cars.make, cars.model, COUNT(*) AS total_rentals
FROM cars 
INNER JOIN rentals ON cars.car_id = rentals.car_id
GROUP BY cars.make, cars.model
ORDER BY total_rentals DESC;

-- 6. List all customers who returned their cars (i.e., return_date is not null)
SELECT DISTINCT customers.full_name 
FROM customers
INNER JOIN rentals ON customers.customer_id = rentals.customer_id
WHERE rentals.return_date IS NOT NULL;

-- 7. Rental frequency by car make
SELECT cars.make, COUNT(*) AS rental_count
FROM cars 
INNER JOIN rentals ON cars.car_id = rentals.car_id
GROUP BY cars.make
ORDER BY rental_count DESC;

-- 8. Customer who made the most expensive rental
SELECT customers.full_name, MAX(rentals.total_price) AS max_price 
FROM customers 
INNER JOIN rentals ON customers.customer_id = rentals.customer_id
GROUP BY customers.full_name
ORDER BY max_price DESC
LIMIT 1;

-- 9. Year with the highest total rental revenue
SELECT EXTRACT(YEAR FROM rental_date) AS Year, SUM(total_price) AS all_sum
FROM rentals 
GROUP BY Year 
ORDER BY all_sum DESC 
LIMIT 1;

-- 10. Number of customers registered each year
SELECT EXTRACT(YEAR FROM customers.registered_at) AS Year,
       COUNT(customers.full_name) AS Registered_Customers
FROM customers
GROUP BY Year
ORDER BY Year;
