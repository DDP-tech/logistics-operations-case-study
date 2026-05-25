-- SAFETY RISK ASSESSMENT

-- Incident Count per Driver
SELECT 
	driver_id,
	COUNT(*) AS total_incidents
FROM safety_incidents
WHERE driver_id IS NOT NULL
GROUP BY driver_id
ORDER BY total_incidents DESC;


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
ORDER BY preventable_rate_pct DESC;


-- Monthly incident trend (Time Series)
WITH monthly_incidents AS (
	SELECT 
		DATE_TRUNC('MONTH', incident_date)::DATE AS incident_month,
		COUNT(*) AS current_month_incidents
	FROM safety_incidents
	GROUP BY 
		DATE_TRUNC('MONTH', incident_date)
),
monthly_trends AS (
	SELECT 
		incident_month,
		LAG(current_month_incidents) OVER(
			ORDER BY incident_month
		) AS prev_month_incidents,
		current_month_incidents
	FROM monthly_incidents
)
SELECT 
	TO_CHAR(incident_month, 'Mon-YYYY') AS incident_month,
	prev_month_incidents,
	current_month_incidents,
	monthly_incident_change
FROM (
	SELECT 
		incident_month,
		prev_month_incidents,
		current_month_incidents,
		current_month_incidents - prev_month_incidents AS monthly_incident_change
	FROM monthly_trends
	WHERE prev_month_incidents IS NOT NULL
	ORDER BY incident_month
) t;


-- Rank drivers by incident frequency (Window)
SELECT 
	driver_id,
	COUNT(*) AS total_incidents,
	DENSE_RANK() OVER(
		ORDER BY COUNT(*) DESC
	) AS incident_frequency_rank
FROM safety_incidents
WHERE driver_id IS NOT NULL
GROUP BY driver_id
ORDER BY total_incidents DESC;


-- Preventable vs non-preventable ratio (CTE)
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


-- Incident rate per 100 trips (Join)
WITH trip_counts AS (
	SELECT
		driver_id,
		COUNT(*) AS total_trips
	FROM trips
	WHERE driver_id IS NOT NULL
	GROUP BY driver_id
),
incident_counts AS (
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
FROM trip_counts tc
LEFT JOIN incident_counts ic
	ON tc.driver_id = ic.driver_id
ORDER BY incidents_per_100_trips DESC;