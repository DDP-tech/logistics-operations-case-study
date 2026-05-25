-- FLEET UTILIZATION MONITORING

-- Total Miles Driven per Truck
SELECT
	truck_id,
	SUM(actual_distance_miles) AS total_miles
FROM trips
WHERE truck_id IS NOT NULL
GROUP BY truck_id
ORDER BY total_miles DESC;


-- Total Revenue Generated per Truck
SELECT 
	tr.truck_id,
	ROUND(SUM(lo.revenue), 2) AS total_revenue
FROM trips tr
LEFT JOIN loads lo
	ON tr.load_id = lo.load_id
WHERE tr.truck_id IS NOT NULL
GROUP BY tr.truck_id
ORDER BY total_revenue DESC;


-- Monthly Revenue per Truck
SELECT 
	tr.truck_id,
	DATE_TRUNC('MONTH', tr.dispatch_date)::DATE AS month,
	ROUND(SUM(lo.revenue), 2) AS monthly_revenue
FROM trips tr
LEFT JOIN loads lo
	ON tr.load_id = lo.load_id
WHERE tr.truck_id IS NOT NULL
GROUP BY 
	tr.truck_id,
	DATE_TRUNC('MONTH', tr.dispatch_date)
ORDER BY 
	tr.truck_id,
	month;


-- Rolling 3-month utilization per truck (Window Function)
WITH monthly_miles AS (
	SELECT
		truck_id,
		DATE_TRUNC('MONTH', dispatch_date)::DATE AS month,
		SUM(actual_distance_miles) AS total_miles
	FROM trips
	WHERE truck_id IS NOT NULL
	GROUP BY 
		truck_id,
		DATE_TRUNC('MONTH', dispatch_date)
)
SELECT 
	truck_id,
	month,
	total_miles,
	ROUND(
		AVG(total_miles) OVER(
			PARTITION BY truck_id 
			ORDER BY month
			ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2
	) AS rolling_3_month_avg_miles
FROM monthly_miles
ORDER BY 
	truck_id,
	month;


-- Revenue rank per truck within each month (Window Function)
WITH truck_revenue AS (
	SELECT 
		tr.truck_id,
		DATE_TRUNC('MONTH', tr.dispatch_date)::DATE AS month,
		ROUND(SUM(lo.revenue), 2) AS monthly_revenue
	FROM trips tr
	LEFT JOIN loads lo
		ON tr.load_id = lo.load_id
	WHERE tr.truck_id IS NOT NULL
	GROUP BY 
		tr.truck_id,
		DATE_TRUNC('MONTH', tr.dispatch_date)
)
SELECT 
	truck_id,
	month,
	monthly_revenue,
	DENSE_RANK() OVER(PARTITION BY month ORDER BY monthly_revenue DESC) AS monthly_revenue_rank
FROM truck_revenue
ORDER BY 
	month,
	monthly_revenue_rank;


-- Trucks operating below fleet average mileage (CTE)
WITH truck_miles AS (
	SELECT 
		truck_id,
		SUM(actual_distance_miles) AS total_miles
	FROM trips
	WHERE truck_id IS NOT NULL
	GROUP BY truck_id
),
fleet_avg AS (
	SELECT 
		AVG(total_miles) AS fleet_avg_miles
	FROM truck_miles
)
SELECT 
	tm.truck_id,
	tm.total_miles,
	ROUND(fa.fleet_avg_miles, 2) AS fleet_avg_miles,
	ROUND(tm.total_miles - fa.fleet_avg_miles, 2) AS utilization_difference,
	CASE
		WHEN tm.total_miles > fa.fleet_avg_miles THEN 'Above Average'
		WHEN tm.total_miles < fa.fleet_avg_miles THEN 'Below Average'
		ELSE 'Equal to Average'
	END AS utilization_status
FROM truck_miles tm
CROSS JOIN fleet_avg fa
ORDER BY tm.truck_id;


-- Monthly utilization growth rate per truck (LAG)
WITH monthly_miles AS (
	SELECT 
		truck_id,
		DATE_TRUNC('MONTH', dispatch_date)::DATE AS month,
		SUM(actual_distance_miles) AS current_month_miles
	FROM trips
	WHERE truck_id IS NOT NULL
	GROUP BY 
		truck_id,
		DATE_TRUNC('MONTH', dispatch_date)
)
SELECT 
	truck_id,
	month,
	prev_month_miles,
	current_month_miles,
	current_month_miles - prev_month_miles AS growth_miles,
	ROUND(
		((current_month_miles - prev_month_miles) 
		/ NULLIF(prev_month_miles, 0)) * 100, 2
	) AS miles_growth_pct
FROM (
	SELECT 
		truck_id,
		month,
		LAG(current_month_miles) OVER(PARTITION BY truck_id ORDER BY month) AS prev_month_miles,
		current_month_miles
	FROM monthly_miles
) t
WHERE prev_month_miles IS NOT NULL
ORDER BY 
	truck_id,
	month;