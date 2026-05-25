-- DRIVER PERFORMANCE INSIGHTS

-- On-Time Delivery Rate per Driver
SELECT 
	tr.driver_id,
	COUNT(de.event_id) AS total_deliveries,
	COUNT(CASE WHEN de.on_time_flag = TRUE THEN 1 END) AS on_time_deliveries,
	ROUND(
		(COUNT(CASE WHEN de.on_time_flag = TRUE THEN 1 END) * 100.0) / COUNT(de.event_id),
		2
	) AS on_time_delivery_rate
FROM trips tr
JOIN delivery_events de
	ON tr.trip_id = de.trip_id
GROUP BY tr.driver_id
ORDER BY on_time_delivery_rate DESC;


-- Average Fuel Efficiency (MPG) per Driver
SELECT 
	driver_id,
	COUNT(trip_id) AS total_trips,
	ROUND(AVG(average_mpg), 2) AS avg_driver_mpg
FROM trips
GROUP BY driver_id
ORDER BY avg_driver_mpg DESC;


-- Revenue Generated per Mile Driven per Driver
SELECT 
	tr.driver_id,
	SUM(tr.actual_distance_miles) AS total_distance,
	SUM(lo.revenue) AS total_revenue,
	ROUND(
		SUM(lo.revenue) / NULLIF(SUM(tr.actual_distance_miles), 0),
		2
	)AS revenue_per_mile
FROM trips tr
JOIN loads lo
	ON tr.load_id = lo.load_id
GROUP BY tr.driver_id
ORDER BY revenue_per_mile DESC;


-- Rank drivers by monthly on-time performance (Window Function)
WITH monthly_drivers AS (
	SELECT 
	    tr.driver_id,
	    DATE_TRUNC('MONTH', de.actual_date)::DATE AS month,
		COUNT(de.event_id) AS total_deliveries,
		COUNT(CASE WHEN de.on_time_flag = TRUE THEN 1 END) AS on_time_deliveries,
		ROUND(
			(COUNT(CASE WHEN de.on_time_flag = TRUE THEN 1 END) * 100.0) / COUNT(de.event_id),
			2
		) AS on_time_delivery_rate
	FROM trips tr
	JOIN delivery_events de
	    ON tr.trip_id = de.trip_id
	GROUP BY 
			tr.driver_id,
	    	month
)
SELECT 
	*,
	DENSE_RANK() OVER (
    	PARTITION BY month 
		ORDER BY on_time_delivery_rate DESC
    ) AS monthly_rank
FROM monthly_drivers
ORDER BY 
    	month,
	    monthly_rank;


-- Identify top 10% drivers by revenue per mile (Window Function)
WITH drivers_revenue AS (
	SELECT 
		tr.driver_id,
		ROUND(SUM(tr.actual_distance_miles), 2) AS total_distance_miles,
		ROUND(SUM(lo.revenue), 2) AS total_revenue,
		ROUND(
			SUM(lo.revenue) / NULLIF(SUM(tr.actual_distance_miles), 0), 2
		) AS revenue_per_mile
	FROM trips tr
	JOIN loads lo
		ON tr.load_id = lo.load_id
	GROUP BY tr.driver_id
),
ranked_drivers AS (
	SELECT 
		*,
		NTILE(10) OVER(
			ORDER BY revenue_per_mile DESC
		) AS revenue_bucket
	FROM drivers_revenue
)
SELECT *
FROM ranked_drivers
WHERE revenue_bucket = 1
ORDER BY revenue_per_mile DESC;


-- Compare each driver’s MPG against fleet average MPG (CTE + Window Avg)
WITH fleet_avg AS (
	SELECT 
		AVG(average_mpg) AS avg_mpg
	FROM trips
)
SELECT 
	tr.driver_id,
	ROUND(AVG(tr.average_mpg), 2) AS driver_avg_mpg,
	ROUND(fa.avg_mpg, 2) AS fleet_avg_mpg,
	ROUND(AVG(tr.average_mpg) - fa.avg_mpg, 2) AS mpg_difference
FROM trips tr
CROSS JOIN fleet_avg fa
GROUP BY 
	tr.driver_id,
	fa.avg_mpg
ORDER BY mpg_difference DESC;


-- Month-over-Month revenue trend per driver (Time Series + LAG)
WITH monthly_rev AS (
	SELECT 
		tr.driver_id,
		DATE_TRUNC('MONTH', tr.dispatch_date)::DATE AS month,
		ROUND(
			SUM(lo.revenue), 2
		) AS monthly_revenue
	FROM trips tr
	JOIN loads lo
		ON tr.load_id = lo.load_id
	GROUP BY 
		tr.driver_id,
		month
)
SELECT 
	*,
	LAG(monthly_revenue) OVER(PARTITION BY driver_id ORDER BY month) AS previous_month_revenue,
	ROUND(
		monthly_revenue - LAG(monthly_revenue) OVER(PARTITION BY driver_id ORDER BY month), 2
	) AS revenue_trend
FROM monthly_rev
ORDER BY 
	driver_id,
	month;


-- Which driver had the highest MPG in the most recent month?
WITH driver_monthly_mpg AS (
	SELECT 
		driver_id,
		DATE_TRUNC('MONTH', dispatch_date)::DATE AS month,
		ROUND(
			AVG(average_mpg), 2
		) AS avg_mpg
	FROM trips
	GROUP BY 
		driver_id,
		DATE_TRUNC('MONTH', dispatch_date)
)
SELECT *
FROM driver_monthly_mpg
WHERE month = (SELECT MAX(month) FROM driver_monthly_mpg)
ORDER BY avg_mpg DESC
LIMIT 1;