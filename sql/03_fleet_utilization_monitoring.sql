-- FLEET UTILIZATION MONITORING

-- Total Miles Driven per Truck
SELECT 
	truck_id,
	SUM(actual_distance_miles) AS total_miles_driven
FROM trips
WHERE truck_id IS NOT NULL
GROUP BY truck_id
ORDER BY total_miles_driven DESC;


-- Total Revenue Generated per Truck
SELECT 
	tr.truck_id,
	ROUND(SUM(lo.revenue), 2) AS total_revenue
FROM trips tr
JOIN loads lo
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
JOIN loads lo
	ON tr.load_id = lo.load_id
WHERE tr.truck_id IS NOT NULL
GROUP BY 
	tr.truck_id,
	DATE_TRUNC('MONTH', tr.dispatch_date)
ORDER BY 
	tr.truck_id,
	month;


-- Rolling 3-month utilization per truck
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


-- Revenue rank per truck within each month
WITH truck_revenue AS (
	SELECT 
		tr.truck_id,
		DATE_TRUNC('MONTH', tr.dispatch_date)::DATE AS month,
		ROUND(SUM(lo.revenue), 2) AS monthly_revenue
	FROM trips tr
	JOIN loads lo
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
	DENSE_RANK() OVER(
		PARTITION BY month
		ORDER BY monthly_revenue DESC
	) AS monthly_revenue_rank
FROM truck_revenue
ORDER BY 
	month,
	monthly_revenue_rank;


-- Trucks operating below fleet average mileage
WITH truck_miles AS (
	SELECT 
		truck_id,
		SUM(actual_distance_miles) AS truck_total_miles
	FROM trips 
	WHERE truck_id IS NOT NULL
	GROUP BY truck_id
),
fleet_avg AS (
	SELECT 
		AVG(truck_total_miles) AS fleet_avg_miles
	FROM truck_miles
)
SELECT 
	tm.truck_id,
	tm.truck_total_miles,
	ROUND(fa.fleet_avg_miles, 2) AS fleet_avg_miles,
	ROUND(tm.truck_total_miles - fa.fleet_avg_miles, 2) AS miles_difference
FROM truck_miles tm
CROSS JOIN fleet_avg fa
WHERE tm.truck_total_miles < fa.fleet_avg_miles
ORDER BY tm.truck_total_miles;


-- Monthly utilization growth rate per truck
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
	previous_month_miles,
	current_month_miles,
	current_month_miles - previous_month_miles AS growth_miles,
	ROUND(
		((current_month_miles - previous_month_miles)
		/ NULLIF(previous_month_miles, 0)) * 100, 2
	) AS miles_growth_rate
FROM (
	SELECT 
		truck_id,
		month,
		LAG(current_month_miles) OVER(PARTITION BY truck_id ORDER BY month) AS previous_month_miles,
		current_month_miles
	FROM monthly_miles
) t
WHERE previous_month_miles IS NOT NULL
ORDER BY 
	truck_id,
	month;
