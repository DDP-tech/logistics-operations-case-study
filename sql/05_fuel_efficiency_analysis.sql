-- FUEL EFFICIENCY ANALYSIS

-- Average MPG per Route
SELECT 
	lo.route_id,
	ROUND(AVG(tr.average_mpg), 2) AS average_mpg
FROM loads lo
JOIN trips tr
	ON lo.load_id = tr.load_id
GROUP BY lo.route_id
ORDER BY 
	average_mpg DESC,
	lo.route_id;


-- Fuel Cost per Mile per Route
WITH trip_fuel AS (
	SELECT
		trip_id,
		SUM(total_cost) AS trip_fuel_cost
	FROM fuel_purchases
	GROUP BY trip_id
)
SELECT 
	lo.route_id,
	SUM(tr.actual_distance_miles) AS total_miles_per_route,
	ROUND(SUM(tf.trip_fuel_cost), 2) AS fuel_cost_per_route,
	ROUND(
		SUM(tf.trip_fuel_cost) / NULLIF(SUM(tr.actual_distance_miles), 0), 2
	) AS fuel_cost_per_mile
FROM loads lo
JOIN trips tr
	ON lo.load_id = tr.load_id
JOIN trip_fuel tf
	ON tr.trip_id = tf.trip_id
GROUP BY lo.route_id
ORDER BY 
	fuel_cost_per_mile DESC,
	lo.route_id;


-- MPG trend per route by month
WITH route_mpg AS (
	SELECT 
		lo.route_id,
		DATE_TRUNC('MONTH', tr.dispatch_date)::DATE AS month,
		AVG(tr.average_mpg) AS current_month_mpg
	FROM loads lo
	JOIN trips tr
		ON lo.load_id = tr.load_id
	GROUP BY 
		lo.route_id,
		DATE_TRUNC('MONTH', tr.dispatch_date)
),
route_trend AS (
	SELECT 
		route_id,
		month,
		LAG(current_month_mpg) OVER(
			PARTITION BY route_id
			ORDER BY month
		) AS previous_month_mpg,
		current_month_mpg
	FROM route_mpg
)
SELECT 
	route_id,
	month,
	ROUND(previous_month_mpg, 2) AS previous_month_mpg,
	ROUND(current_month_mpg, 2) AS current_month_mpg,
	ROUND(current_month_mpg - previous_month_mpg, 2) AS mpg_trend
FROM route_trend
WHERE previous_month_mpg IS NOT NULL
ORDER BY 
	route_id,
	month;


-- Rank routes by fuel efficiency
WITH route_avg AS (
	SELECT 
		lo.route_id,
		ROUND(AVG(tr.average_mpg), 2) AS average_mpg
	FROM loads lo
	JOIN trips tr
		ON lo.load_id = tr.load_id
	GROUP BY lo.route_id
)
SELECT 
	route_id,
	average_mpg,
	DENSE_RANK() OVER(ORDER BY average_mpg DESC) AS fuel_efficiency_rank
FROM route_avg
ORDER BY average_mpg DESC;


-- Routes with MPG below fleet median
WITH route_mpg AS (
	SELECT 
		lo.route_id,
		AVG(tr.average_mpg) AS average_mpg
	FROM loads lo
	JOIN trips tr
		ON lo.load_id = tr.load_id
	GROUP BY 
		lo.route_id
),
median_mpg AS (
	SELECT PERCENTILE_CONT(0.5)
		WITHIN GROUP (ORDER BY average_mpg) AS fleet_median
	FROM route_mpg
)
SELECT
	rm.route_id,
	ROUND(rm.average_mpg, 4) AS average_mpg,
	ROUND(mm.fleet_median::NUMERIC, 4) AS fleet_median
FROM route_mpg rm
CROSS JOIN median_mpg mm
WHERE rm.average_mpg < mm.fleet_median
ORDER BY rm.average_mpg DESC;


-- Rolling average MPG per route
WITH route_mpg AS (
	SELECT 
		lo.route_id,
		DATE_TRUNC('MONTH', tr.dispatch_date)::DATE AS month,
		AVG(tr.average_mpg) AS average_mpg
	FROM loads lo
	JOIN trips tr
		ON lo.load_id = tr.load_id
	GROUP BY 
		lo.route_id,
		DATE_TRUNC('MONTH', tr.dispatch_date)
)
SELECT 
	route_id,
	month,
	ROUND(average_mpg, 4) AS average_mpg,
	ROUND(
		AVG(average_mpg) OVER(
			PARTITION BY route_id
			ORDER BY month
			ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 4
	) AS rolling_average_mpg
FROM route_mpg
ORDER BY
	route_id,
	month;
