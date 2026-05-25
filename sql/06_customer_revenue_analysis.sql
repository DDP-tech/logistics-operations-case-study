-- CUSTOMER REVENUE ANALYSIS

-- Total Revenue per Customer
SELECT 
	cu.customer_id,
	ROUND(SUM(lo.revenue), 2) AS total_revenue
FROM customers cu
JOIN loads lo
	ON cu.customer_id = lo.customer_id
GROUP BY cu.customer_id
ORDER BY total_revenue DESC;


-- Average Revenue per Load per Customer
SELECT 
	cu.customer_id,
	cu.customer_name,
	COUNT(lo.load_id) AS total_loads,
	ROUND(SUM(lo.revenue), 2) AS total_revenue,
	ROUND(AVG(lo.revenue), 2) AS revenue_per_load
FROM customers cu
JOIN loads lo
	ON cu.customer_id = lo.customer_id
GROUP BY 
	cu.customer_id,
	cu.customer_name
ORDER BY revenue_per_load DESC;


-- Monthly revenue trend per customer (Time Series)
WITH monthly_revenue AS (
	SELECT 
		cu.customer_id,
		DATE_TRUNC('MONTH', lo.load_date)::DATE AS month,
		SUM(lo.revenue) AS current_month_revenue
	FROM customers cu
	JOIN loads lo
		ON cu.customer_id = lo.customer_id
	GROUP BY 
		cu.customer_id,
		DATE_TRUNC('MONTH', lo.load_date)
),
monthly_trend AS (
	SELECT 
		customer_id,
		month,
		LAG(current_month_revenue) OVER(
			PARTITION BY customer_id
			ORDER BY month
		) AS prev_month_revenue,
		current_month_revenue
	FROM monthly_revenue
)
SELECT 
	customer_id,
	month,
	ROUND(prev_month_revenue, 2) AS prev_month_revenue,
	ROUND(current_month_revenue, 2) AS current_month_revenue,
	ROUND(current_month_revenue - prev_month_revenue, 2) AS revenue_trend
FROM monthly_trend
WHERE prev_month_revenue IS NOT NULL
ORDER BY 
	customer_id,
	month;


-- Top customers by quarterly revenue (Window)
WITH customer_revenue AS (
	SELECT 
		cu.customer_id,
		cu.customer_name,
		DATE_TRUNC('QUARTER', lo.load_date)::DATE AS quarter,
		SUM(lo.revenue) AS quarterly_revenue
	FROM customers cu
	JOIN loads lo
		ON cu.customer_id = lo.customer_id
	GROUP BY 
		cu.customer_id,
		cu.customer_name,
		DATE_TRUNC('QUARTER', lo.load_date)
)
SELECT 
	customer_id,
	customer_name,
	quarter,
	ROUND(quarterly_revenue, 2) AS quarterly_revenue,
	quarterly_rank
FROM (
	SELECT 
		customer_id,
		customer_name,
		quarter,
		quarterly_revenue,
		DENSE_RANK() OVER(
			PARTITION BY quarter 
			ORDER BY quarterly_revenue DESC
		) AS quarterly_rank
	FROM customer_revenue
) t
WHERE quarterly_rank <= 5
ORDER BY 
	quarter,
	quarterly_revenue DESC;


-- Customer revenue share vs total revenue (CTE)
WITH customer_rev AS (
	SELECT 
		cu.customer_id,
		cu.customer_name,
		SUM(lo.revenue) AS customer_revenue
	FROM customers cu
	JOIN loads lo
		ON cu.customer_id = lo.customer_id
	GROUP BY 
		cu.customer_id,
		cu.customer_name
),
total_rev AS (
	SELECT 
		SUM(customer_revenue) AS total_revenue
	FROM customer_rev
)
SELECT 
	cr.customer_id,
	cr.customer_name,
	ROUND(cr.customer_revenue, 2) AS customer_revenue,
	ROUND(tr.total_revenue, 2) AS total_revenue,
	ROUND(cr.customer_revenue / tr.total_revenue * 100, 2) AS customer_revenue_percentage
FROM customer_rev cr
CROSS JOIN total_rev tr
ORDER BY customer_revenue_percentage DESC;


-- Revenue growth rate per customer (LAG)
WITH monthly_revenue AS (
	SELECT 
		cu.customer_id,
		cu.customer_name,
		DATE_TRUNC('MONTH', lo.load_date)::DATE AS month,
		SUM(lo.revenue) AS current_month_revenue
	FROM customers cu
	JOIN loads lo
		ON cu.customer_id = lo.customer_id
	GROUP BY 
		cu.customer_id,
		cu.customer_name,
		DATE_TRUNC('MONTH', lo.load_date)
),
monthly_trend AS (
	SELECT 
		customer_id,
		customer_name,
		month,
		LAG(current_month_revenue) OVER(
			PARTITION BY customer_id
			ORDER BY month
		) AS prev_month_revenue,
		current_month_revenue
	FROM monthly_revenue
)
SELECT 
	customer_id,
	customer_name,
	month,
	ROUND(prev_month_revenue, 2) AS prev_month_revenue,
	ROUND(current_month_revenue, 2) AS current_month_revenue,
	ROUND(current_month_revenue - prev_month_revenue, 2) AS revenue_trend,
	ROUND(
		(current_month_revenue - prev_month_revenue) 
		/ NULLIF(prev_month_revenue, 0) * 100, 2
	) AS revenue_growth_percentage
FROM monthly_trend
WHERE prev_month_revenue IS NOT NULL
ORDER BY 
	customer_id,
	month;


-- Which customer contributed the most revenue this year?
SELECT 
	customer_id,
	customer_name,
	year,
	ROUND(yearly_revenue, 2) AS yearly_revenue,
	yearly_rank
FROM (
	SELECT 
		customer_id,
		customer_name,
		year,
		yearly_revenue,
		DENSE_RANK() OVER(ORDER BY yearly_revenue DESC) AS yearly_rank
	FROM (
		SELECT 
			cu.customer_id,
			cu.customer_name,
			DATE_TRUNC('YEAR', lo.load_date)::DATE AS year,
			SUM(lo.revenue) AS yearly_revenue
		FROM customers cu
		JOIN loads lo
			ON cu.customer_id = lo.customer_id
		GROUP BY 
			cu.customer_id,
			cu.customer_name,
			DATE_TRUNC('YEAR', lo.load_date)
	) t
	WHERE year = (SELECT DATE_TRUNC('YEAR', MAX(load_date))::DATE FROM loads)
) rnk
WHERE yearly_rank = 1
ORDER BY 
	customer_id,
	customer_name;