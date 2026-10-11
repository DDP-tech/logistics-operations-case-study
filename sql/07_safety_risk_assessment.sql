-- SAFETY RISK ASSESSMENT

-- Incident Count per Driver
SELECT 
	driver_id,
	COUNT(*) AS total_incidents
FROM safety_incidents
WHERE driver_id IS NOT NULL
GROUP BY driver_id
ORDER BY 
	total_incidents DESC,
	driver_id;


-- Preventable Incident Rate per Driver
SELECT 
	driver_id,
	SUM(
		CASE
			WHEN preventable_flag = TRUE THEN 1
			ELSE 0
		END) AS preventable_incidents,
	COUNT(*) AS total_incidents,
	ROUND(
		100.0 * SUM(
			CASE
				WHEN preventable_flag = TRUE THEN 1
				ELSE 0
			END)
			/ COUNT(*), 2
	) AS preventable_rate_pct
FROM safety_incidents
WHERE driver_id IS NOT NULL
GROUP BY driver_id
ORDER BY 
	preventable_rate_pct DESC,
	driver_id;


-- Monthly incident trend
WITH monthly_total AS (
	SELECT 
		DATE_TRUNC('MONTH', incident_date)::DATE AS incident_month,
		COUNT(*) AS current_month_incidents
	FROM safety_incidents
	GROUP BY DATE_TRUNC('MONTH', incident_date)
),
previous_total AS (
	SELECT 
		incident_month,
		LAG(current_month_incidents) OVER(
			ORDER BY incident_month
		) AS previous_month_incidents,
		current_month_incidents
	FROM monthly_total
)
SELECT 
	TO_CHAR(pt.incident_month, 'Mon-YYYY') AS incident_month,
	pt.previous_month_incidents,
	pt.current_month_incidents,
	pt.current_month_incidents - pt.previous_month_incidents AS monthly_incident_trend
FROM previous_total pt
WHERE pt.previous_month_incidents IS NOT NULL
ORDER BY pt.incident_month;


-- Rank drivers by incident frequency
SELECT 
	driver_id,
	COUNT(*) AS total_incidents,
	DENSE_RANK() OVER(ORDER BY COUNT(*) DESC) AS incident_frequency_rank
FROM safety_incidents
WHERE driver_id IS NOT NULL
GROUP BY driver_id
ORDER BY 
	total_incidents DESC,
	driver_id;


-- Preventable vs non-preventable ratio
WITH incident_counts AS (
	SELECT 
		SUM(
			CASE
				WHEN preventable_flag = TRUE THEN 1
				ELSE 0
			END) AS preventable_incidents,
		SUM(
			CASE
				WHEN preventable_flag = FALSE THEN 1
				ELSE 0
			END) AS non_preventable_incidents
	FROM safety_incidents
)
SELECT 
	preventable_incidents,
	non_preventable_incidents,
	ROUND(
		preventable_incidents::NUMERIC / NULLIF(non_preventable_incidents, 0), 2
	) AS preventable_to_non_preventable_ratio
FROM incident_counts;


-- Incident rate per 100 trips
WITH trip_count AS (
	SELECT 
		driver_id,
		COUNT(*) AS total_trips
	FROM trips
	WHERE driver_id IS NOT NULL
	GROUP BY driver_id
),
incident_count AS (
	SELECT 
		driver_id,
		COUNT(*) AS total_incidents
	FROM safety_incidents
	WHERE driver_id IS NOT NULL
	GROUP BY driver_id
)
SELECT 
	tc.driver_id,
	COALESCE(ic.total_incidents, 0) AS total_incidents,
	tc.total_trips,
	ROUND(
		100.0 * COALESCE(ic.total_incidents, 0) / NULLIF(tc.total_trips, 0), 2
	) AS incidents_per_100_trips
FROM trip_count tc
LEFT JOIN incident_count ic
	ON tc.driver_id = ic.driver_id
ORDER BY 
	incidents_per_100_trips DESC,
	tc.driver_id;
