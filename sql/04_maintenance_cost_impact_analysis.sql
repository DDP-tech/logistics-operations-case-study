-- MAINTENANCE COST IMPACT ANALYSIS

-- Total Maintenance Cost per Truck
SELECT 
	truck_id,
	ROUND(SUM(total_cost), 2) AS total_maintenance_cost
FROM maintenance_records
GROUP BY truck_id
ORDER BY total_maintenance_cost DESC;


-- Total Downtime Hours per Truck
SELECT 
	truck_id,
	ROUND(SUM(downtime_hours), 2) AS total_downtime_hours
FROM maintenance_records
GROUP BY truck_id
ORDER BY total_downtime_hours DESC;


-- Maintenance Cost per Mile Driven
WITH truck_miles AS (
	SELECT 
		truck_id,
		SUM(actual_distance_miles) AS total_miles
	FROM trips 
	GROUP BY truck_id
),
maintenance_cost AS (
	SELECT 
		truck_id,
		SUM(total_cost) AS total_cost
	FROM maintenance_records
	GROUP BY truck_id
)
SELECT 
	tm.truck_id,
	tm.total_miles,
	ROUND(mc.total_cost, 2) AS total_maintenance_cost,
	ROUND(
		mc.total_cost / NULLIF(tm.total_miles, 0), 4
	) AS cost_per_mile
FROM truck_miles tm
JOIN maintenance_cost mc
	ON tm.truck_id = mc.truck_id
ORDER BY cost_per_mile DESC;


-- Maintenance cost trend over time (Time Series)
WITH maintenance_cost AS (
	SELECT 
		truck_id,
		DATE_TRUNC('MONTH', maintenance_date)::DATE AS month,
		SUM(total_cost) AS current_month_cost
	FROM maintenance_records
	GROUP BY 
		truck_id,
		DATE_TRUNC('MONTH', maintenance_date)
),
maintenance_cost_trend AS (
	SELECT 
		truck_id,
		month,
		LAG(current_month_cost) OVER(PARTITION BY truck_id ORDER BY month) AS prev_month_cost,
		current_month_cost
	FROM maintenance_cost
)
SELECT 
	truck_id,
	month,
	ROUND(prev_month_cost, 2) AS prev_month_cost,
	ROUND(current_month_cost, 2) AS current_month_cost,
	ROUND(
		current_month_cost - prev_month_cost, 2
	) AS monthly_cost_trend
FROM maintenance_cost_trend
WHERE prev_month_cost IS NOT NULL
ORDER BY 
	truck_id,
	month;

SELECT MAX(maintenance_date) FROM maintenance_records;

-- Top 5 trucks with highest downtime in last 6 months (Window)
SELECT 
	truck_id,
	ROUND(total_downtime, 2) AS total_downtime,
	downtime_rank
FROM (
	SELECT 
		truck_id,
		SUM(downtime_hours) AS total_downtime,
		DENSE_RANK() OVER(ORDER BY SUM(downtime_hours) DESC) AS downtime_rank
	FROM maintenance_records
	WHERE maintenance_date >= (SELECT MAX(maintenance_date) FROM maintenance_records) - INTERVAL '6 MONTH'
	GROUP BY truck_id
) AS ranked_trucks
WHERE downtime_rank <= 5
ORDER BY total_downtime DESC;


-- Downtime impact on monthly trip count (CTE + Join)
WITH monthly_downtime AS (
	SELECT 
		truck_id,
		DATE_TRUNC('MONTH', maintenance_date)::DATE AS downtime_month,
		SUM(downtime_hours) AS current_month_downtime
	FROM maintenance_records
	GROUP BY 
		truck_id,
		DATE_TRUNC('MONTH', maintenance_date)
),
monthly_trips AS (
	SELECT 
		truck_id,
		DATE_TRUNC('MONTH', dispatch_date)::DATE AS trip_month,
		COUNT(trip_id) AS current_month_trips
	FROM trips
	GROUP BY 
		truck_id,
		DATE_TRUNC('MONTH', dispatch_date)
),
monthly_operations AS (
	SELECT 
		md.truck_id,
		md.downtime_month AS operational_month,
		md.current_month_downtime,
		mt.current_month_trips
	FROM monthly_downtime md
	JOIN monthly_trips mt
		ON md.truck_id = mt.truck_id
		AND md.downtime_month = mt.trip_month
),
final_operations AS (
	SELECT 
		truck_id,
		operational_month,
		LAG(current_month_downtime) OVER(
			PARTITION BY truck_id 
			ORDER BY operational_month
		) AS prev_month_downtime,
		current_month_downtime,
		LAG(current_month_trips) OVER(
			PARTITION BY truck_id
			ORDER BY operational_month
		) AS prev_month_trips,
		current_month_trips
	FROM monthly_operations
)
SELECT
	truck_id,
	operational_month,
	ROUND(prev_month_downtime, 2) AS prev_month_downtime,
	ROUND(current_month_downtime, 2) AS current_month_downtime,
	ROUND(current_month_downtime - prev_month_downtime, 2) AS downtime_change,
	prev_month_trips,
	current_month_trips,
	current_month_trips - prev_month_trips AS trips_change,
	ROUND(current_month_downtime / NULLIF(current_month_trips, 0), 2) AS downtime_per_trip
FROM final_operations
ORDER BY 
	truck_id,
	operational_month;


-- Maintenance cost vs revenue generated comparison (Join)
WITH truck_maintenance AS (
	SELECT 
		truck_id,
		SUM(total_cost) AS total_maintenance_cost
	FROM maintenance_records
	GROUP BY truck_id
),
truck_revenue AS (
	SELECT 
		tr.truck_id,
		SUM(lo.revenue) AS total_revenue
	FROM trips tr
	JOIN loads lo
		ON tr.load_id = lo.load_id
	GROUP BY tr.truck_id
)
SELECT 
	tm.truck_id,
	ROUND(tr.total_revenue, 2) AS total_revenue,
	ROUND(tm.total_maintenance_cost, 2) AS total_maintenance_cost,
	ROUND(tr.total_revenue - tm.total_maintenance_cost, 2) AS net_operational_profit
FROM truck_maintenance tm
JOIN truck_revenue tr
	ON tm.truck_id = tr.truck_id
ORDER BY net_operational_profit DESC;


-- Which truck had zero downtime last quarter?
WITH latest_quarter AS (
	SELECT 
		DATE_TRUNC('QUARTER', MAX(maintenance_date))::DATE AS recent_quarter
	FROM maintenance_records
),
quarterly_downtime AS (
	SELECT 
		truck_id,
		SUM(downtime_hours) AS total_downtime
	FROM maintenance_records
	WHERE DATE_TRUNC('QUARTER', maintenance_date) = (
		SELECT recent_quarter FROM latest_quarter)
	GROUP BY truck_id
)
SELECT 
	tr.truck_id,
	COALESCE(qd.total_downtime, 0) AS total_downtime
FROM trucks tr
LEFT JOIN quarterly_downtime qd
	ON tr.truck_id = qd.truck_id
WHERE COALESCE(qd.total_downtime, 0) = 0
ORDER BY tr.truck_id;