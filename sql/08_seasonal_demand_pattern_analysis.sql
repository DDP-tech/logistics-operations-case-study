-- SEASONAL DEMAND PATTERN ANALYSIS

-- Monthly Load Volume
SELECT 
	TO_CHAR(DATE_TRUNC('MONTH', load_date)::DATE, 'Mon-YYYY') AS load_month,
	COUNT(*) AS load_volume
FROM loads
GROUP BY DATE_TRUNC('MONTH', load_date)
ORDER BY DATE_TRUNC('MONTH', load_date);


-- Monthly Revenue Trend
WITH monthly_total AS (
	SELECT 
		DATE_TRUNC('MONTH', load_date)::DATE AS load_month,
		SUM(revenue) AS current_month_revenue
	FROM loads
	GROUP BY DATE_TRUNC('MONTH', load_date)
),
previous_total AS (
	SELECT 
		load_month,
		LAG(current_month_revenue) OVER(
			ORDER BY load_month
		) AS previous_month_revenue,
		current_month_revenue
	FROM monthly_total
)
SELECT 
	TO_CHAR(pt.load_month, 'Mon-YYYY') AS load_month,
	ROUND(pt.previous_month_revenue, 2) AS previous_month_revenue,
	ROUND(pt.current_month_revenue, 2) AS current_month_revenue,
	ROUND(pt.current_month_revenue - pt.previous_month_revenue, 2) AS revenue_trend
FROM previous_total pt
ORDER BY pt.load_month;


-- Monthly Trip Volume
SELECT 
	TO_CHAR(DATE_TRUNC('MONTH', dispatch_date)::DATE, 'Mon-YYYY') AS trip_month,
	COUNT(*) AS trip_volume
FROM trips
GROUP BY DATE_TRUNC('MONTH', dispatch_date)
ORDER BY DATE_TRUNC('MONTH', dispatch_date);


-- Quarter-wise shipment trend
WITH quarterly_total AS (
	SELECT 
		DATE_TRUNC('QUARTER', load_date)::DATE AS load_quarter,
		COUNT(*) AS current_quarter_load_volume
	FROM loads
	GROUP BY DATE_TRUNC('QUARTER', load_date)
),
previous_total AS (
	SELECT 
		load_quarter,
		LAG(current_quarter_load_volume) OVER(
			ORDER BY load_quarter
		) AS previous_quarter_load_volume,
		current_quarter_load_volume
	FROM quarterly_total
)
SELECT 
	CONCAT(
		'Q', EXTRACT(QUARTER FROM pt.load_quarter),
		'-', EXTRACT(YEAR FROM pt.load_quarter)
	) AS load_quarter,
	pt.previous_quarter_load_volume,
	pt.current_quarter_load_volume,
	pt.current_quarter_load_volume - pt.previous_quarter_load_volume AS load_volume_trend
FROM previous_total pt
ORDER BY pt.load_quarter;


-- Month-over-Month load growth
WITH monthly_total AS (
	SELECT 
		DATE_TRUNC('MONTH', load_date)::DATE AS load_month,
		COUNT(*) AS current_month_load_volume
	FROM loads
	GROUP BY DATE_TRUNC('MONTH', load_date)
),
previous_total AS (
	SELECT 
		load_month,
		LAG(current_month_load_volume) OVER(
			ORDER BY load_month
		) AS previous_month_load_volume,
		current_month_load_volume
	FROM monthly_total
)
SELECT 
	TO_CHAR(pt.load_month, 'Mon-YYYY') AS load_month,
	pt.previous_month_load_volume,
	pt.current_month_load_volume,
	pt.current_month_load_volume - pt.previous_month_load_volume AS load_volume_growth
FROM previous_total pt
ORDER BY pt.load_month;


-- Peak shipment month identification
WITH monthly_total AS (
	SELECT 
		DATE_TRUNC('MONTH', load_date)::DATE AS load_month,
		COUNT(*) AS load_volume
	FROM loads
	GROUP BY DATE_TRUNC('MONTH', load_date)
)
SELECT 
	TO_CHAR(load_month, 'Mon-YYYY') AS peak_load_month,
	load_volume,
	load_volume_rank
FROM (
	SELECT 
		load_month,
		load_volume,
		DENSE_RANK() OVER(
			ORDER BY load_volume DESC
		) AS load_volume_rank
	FROM monthly_total
) t
WHERE load_volume_rank = 1
ORDER BY load_month;


-- Revenue contribution by season
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
		SUM(seasonal_revenue) AS total_revenue
	FROM seasonal_rev
)
SELECT 
	sr.season,
	ROUND(sr.seasonal_revenue, 2) AS seasonal_revenue,
	ROUND(tr.total_revenue, 2) AS total_revenue,
	ROUND(
		100.0 * sr.seasonal_revenue
		/ tr.total_revenue, 2
	) AS revenue_contribution_pct
FROM seasonal_rev sr
CROSS JOIN total_rev tr
ORDER BY revenue_contribution_pct DESC;


-- Which month had the highest load volume?
SELECT 
	TO_CHAR(DATE_TRUNC('MONTH', load_date)::DATE, 'Mon-YYYY') AS load_month,
	COUNT(*) AS load_volume
FROM loads
GROUP BY DATE_TRUNC('MONTH', load_date)
ORDER BY 
	load_volume DESC,
	DATE_TRUNC('MONTH', load_date) ASC
LIMIT 1;
