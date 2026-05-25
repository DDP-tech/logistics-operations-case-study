-- SEASONAL DEMAND PATTERN ANALYSIS

-- Monthly Load Volume
SELECT 
	TO_CHAR(DATE_TRUNC('MONTH', load_date)::DATE, 'Mon-YYYY') AS month,
	COUNT(*) AS load_volume
FROM loads
GROUP BY DATE_TRUNC('MONTH', load_date)
ORDER BY DATE_TRUNC('MONTH', load_date);


-- Monthly Revenue Trend
SELECT 
	TO_CHAR(revenue_month, 'Mon-YYYY') AS month,
	ROUND(
		LAG(current_month_revenue) OVER(
			ORDER BY revenue_month), 2
	) AS previous_month_revenue,
	ROUND(current_month_revenue, 2) AS current_month_revenue,
	ROUND(
		current_month_revenue 
		- 
		LAG(current_month_revenue) OVER(
			ORDER BY revenue_month), 2
	) AS monthly_revenue_trend
FROM (
	SELECT 
		DATE_TRUNC('MONTH', load_date)::DATE AS revenue_month,
		SUM(revenue) AS current_month_revenue
	FROM loads
	GROUP BY DATE_TRUNC('MONTH', load_date)
) t
ORDER BY revenue_month;


-- Monthly Trip Volume
SELECT 
	TO_CHAR(DATE_TRUNC('MONTH', dispatch_date)::DATE, 'Mon-YYYY') AS month,
	COUNT(*) AS trip_volume
FROM trips
GROUP BY DATE_TRUNC('MONTH', dispatch_date)
ORDER BY DATE_TRUNC('MONTH', dispatch_date);


-- Quarter-wise shipment trend
SELECT 
	CONCAT(
		'Q', EXTRACT(QUARTER FROM load_date),
		'-', EXTRACT(YEAR FROM load_date)
	) AS quarter,
	COUNT(*) AS load_volume
FROM loads
GROUP BY 
	EXTRACT(QUARTER FROM load_date),
	EXTRACT(YEAR FROM load_date)
ORDER BY 
	EXTRACT(YEAR FROM load_date),
	EXTRACT(QUARTER FROM load_date);


-- Month-over-Month load growth (LAG)
WITH monthly_load AS (
	SELECT 
		DATE_TRUNC('MONTH', load_date)::DATE AS load_month,
		COUNT(load_id) AS current_month_load
	FROM loads
	GROUP BY DATE_TRUNC('MONTH', load_date)
)
SELECT 
	TO_CHAR(load_month, 'Mon-YYYY') AS month,
	LAG(current_month_load) OVER(
			ORDER BY load_month
	) AS previous_month_load,
	current_month_load AS current_month_load,
	current_month_load 
	- 
	LAG(current_month_load) OVER(
		ORDER BY load_month
	) AS monthly_load_growth
FROM monthly_load
ORDER BY load_month;


-- Peak shipment month identification (Window)
WITH monthly_load AS (
	SELECT 
		DATE_TRUNC('MONTH', load_date)::DATE AS month,
		COUNT(load_id) AS total_monthly_load
	FROM loads
	GROUP BY DATE_TRUNC('MONTH', load_date)
)
SELECT 
	TO_CHAR(month, 'Mon-YYYY') AS load_month,
	total_monthly_load,
	month_rank
FROM (
	SELECT 
		month,
		total_monthly_load,
		DENSE_RANK() OVER(
			ORDER BY total_monthly_load DESC
		) AS month_rank
	FROM monthly_load
) t
WHERE month_rank = 1
ORDER BY month;


-- Revenue contribution by season (CTE)
WITH seasonal_rev AS (
	SELECT 
		CASE
			WHEN EXTRACT(MONTH FROM load_date) IN (12, 1, 2) THEN 'Winter'
			WHEN EXTRACT(MONTH FROM load_date) IN (3, 4) THEN 'Spring'
			WHEN EXTRACT(MONTH FROM load_date) IN (5, 6) THEN 'Summer/Pre-monsoon'
			WHEN EXTRACT(MONTH FROM load_date) IN (7, 8, 9) THEN 'Monsoon/Rainy'
			WHEN EXTRACT(MONTH FROM load_date) IN (10, 11) THEN 'Autumn/Post-monsoon'
			ELSE 'Unknown'
		END AS season,
		SUM(revenue) AS seasonal_revenue
	FROM loads
	GROUP BY season
),
total_rev AS (
	SELECT
		SUM(revenue) AS total_revenue
	FROM loads
)
SELECT 
	season,
	ROUND(seasonal_revenue, 2) AS seasonal_revenue,
	ROUND(total_revenue, 2) AS total_revenue,
	ROUND(
		100.0 * seasonal_revenue
		/ total_revenue, 2
	) AS seasonal_revenue_contribution
FROM seasonal_rev
CROSS JOIN total_rev
ORDER BY seasonal_revenue_contribution DESC;


-- Which month had the highest load volume?
WITH monthly_load AS (
	SELECT 
		DATE_TRUNC('MONTH', load_date)::DATE AS month,
		COUNT(load_id) AS load_volume
	FROM loads
	GROUP BY DATE_TRUNC('MONTH', load_date)
)
SELECT 
	TO_CHAR(month, 'Mon-YYYY') AS load_month,
	load_volume,
	load_rank
FROM (
	SELECT 
		month,
		load_volume,
		DENSE_RANK() OVER(
			ORDER BY load_volume DESC
		) AS load_rank
	FROM monthly_load
) t
WHERE load_rank = 1
ORDER BY month;