-- ROUTE PROFITABILITY ASSESSMENT

-- Total Revenue per Route
SELECT 
	route_id,
	ROUND(
		SUM(revenue), 2
	) AS total_revenue
FROM loads
GROUP BY route_id
ORDER BY total_revenue DESC;


-- Total Fuel Cost per Route
SELECT 
	lo.route_id,
	ROUND(
		SUM(fp.total_cost), 2
	) AS total_fuel_cost
FROM loads lo
JOIN trips tr
	ON lo.load_id = tr.load_id
JOIN fuel_purchases fp
	ON tr.trip_id = fp.trip_id
GROUP BY lo.route_id
ORDER BY total_fuel_cost DESC;


-- Net Route Profitability (Revenue – Fuel Cost)
WITH route_revenue AS (
	SELECT
		route_id,
		SUM(revenue) AS total_revenue
	FROM loads
	GROUP BY route_id
),
route_fuel AS (
	SELECT 
		lo.route_id,
		SUM(fp.total_cost) AS fuel_cost
	FROM loads lo
	JOIN trips tr
		ON lo.load_id = tr.load_id
	JOIN fuel_purchases fp
		ON tr.trip_id = fp.trip_id
	GROUP BY lo.route_id
)
SELECT 
	rr.route_id,
	ROUND(rr.total_revenue, 2) AS total_revenue,
	ROUND(
		COALESCE(rf.fuel_cost, 0), 2
	) AS total_fuel_cost,
	ROUND(
		rr.total_revenue - COALESCE(rf.fuel_cost, 0), 2
	) AS net_profit
FROM route_revenue rr
LEFT JOIN route_fuel rf
	ON rr.route_id = rf.route_id
ORDER BY net_profit DESC;


-- Monthly Profit Trend per Route (Time Series)
WITH route_revenue AS (
	SELECT 
		lo.route_id,
		DATE_TRUNC('MONTH', tr.dispatch_date)::DATE AS month,
		SUM(lo.revenue) AS total_revenue
	FROM loads lo
	JOIN trips tr
		ON lo.load_id = tr.load_id
	GROUP BY 
		route_id,
		DATE_TRUNC('MONTH', tr.dispatch_date)
),
route_fuel AS (
	SELECT 
		lo.route_id,
		DATE_TRUNC('MONTH', tr.dispatch_date)::DATE AS month,
		SUM(fp.total_cost) AS fuel_cost
	FROM loads lo
	JOIN trips tr
		ON lo.load_id = tr.load_id
	JOIN fuel_purchases fp
		ON tr.trip_id = fp.trip_id
	GROUP BY 
		lo.route_id,
		DATE_TRUNC('MONTH', tr.dispatch_date)
),
route_profit AS (
	SELECT 
		rr.route_id,
		rr.month,
		ROUND(
			rr.total_revenue - COALESCE(rf.fuel_cost, 0), 2
		) AS net_profit
	FROM route_revenue rr
	LEFT JOIN route_fuel rf
		ON rr.route_id = rf.route_id
		AND rr.month = rf.month
)
SELECT 
	route_id,
	month,
	LAG(net_profit) OVER(PARTITION BY route_id ORDER BY month) AS previous_month_profit,
	net_profit,
	ROUND(
		net_profit - LAG(net_profit) OVER(PARTITION BY route_id ORDER BY month), 2
	) AS profit_trend
FROM route_profit
ORDER BY 
	route_id,
	month;


-- Top 5 most profitable routes per quarter (Window Function)
WITH route_revenue AS (
	SELECT
		lo.route_id,
		DATE_TRUNC('QUARTER', tr.dispatch_date)::DATE AS quarter,
		SUM(lo.revenue) AS total_revenue
	FROM loads lo
	JOIN trips tr
		ON lo.load_id = tr.load_id
	GROUP BY 
		route_id,
		DATE_TRUNC('QUARTER', tr.dispatch_date)
),
route_fuel AS (
	SELECT 
		lo.route_id,
		DATE_TRUNC('QUARTER', tr.dispatch_date)::DATE AS quarter,
		SUM(fp.total_cost) AS fuel_cost
	FROM loads lo
	JOIN trips tr
		ON lo.load_id = tr.load_id
	JOIN fuel_purchases fp
		ON tr.trip_id = fp.trip_id
	GROUP BY 
		lo.route_id,
		DATE_TRUNC('QUARTER', tr.dispatch_date)
),
route_profit AS (
	SELECT 
		rr.route_id,
		rr.quarter,
		ROUND(
			rr.total_revenue - COALESCE(rf.fuel_cost, 0), 2
		) AS net_profit
	FROM route_revenue rr
	LEFT JOIN route_fuel rf
		ON rr.route_id = rf.route_id
		AND rr.quarter = rf.quarter
),
final_route AS (
	SELECT
		route_id,
		quarter,
		net_profit,
		DENSE_RANK() OVER(PARTITION BY quarter ORDER BY net_profit DESC) AS rank_in_quarter
	FROM route_profit
)
SELECT *
FROM final_route
WHERE rank_in_quarter <= 5
ORDER BY 
	quarter,
	rank_in_quarter;


-- Routes with increasing fuel cost trend over last 3 months (LAG)
WITH route_fuel AS (
	SELECT 
		lo.route_id,
		DATE_TRUNC('MONTH', tr.dispatch_date)::DATE AS month,
		SUM(fp.total_cost) AS fuel_cost
	FROM loads lo
	JOIN trips tr
		ON lo.load_id = tr.load_id
	JOIN fuel_purchases fp
		ON tr.trip_id = fp.trip_id
	GROUP BY 
		lo.route_id,
		DATE_TRUNC('MONTH', tr.dispatch_date)
),
fuel_trend AS (
	SELECT 
		route_id,
		month,
		fuel_cost,
		LAG(fuel_cost, 1) OVER(PARTITION BY route_id ORDER BY month) AS prev_month_cost,
		LAG(fuel_cost, 2) OVER(PARTITION BY route_id ORDER BY month) AS prev_2_month_cost
	FROM route_fuel
),
max_month AS (
	SELECT 
		MAX(month) AS latest_month
	FROM route_fuel
)
SELECT 
	ft.route_id,
	ft.month,
	ft.fuel_cost,
	ft.prev_month_cost,
	ft.prev_2_month_cost
FROM fuel_trend ft
CROSS JOIN max_month mm
WHERE ft.month >= mm.latest_month - INTERVAL '2 MONTH'	-- Last 3 months filter
	AND ft.fuel_cost > ft.prev_month_cost
	AND ft.prev_month_cost > ft.prev_2_month_cost
ORDER BY
	ft.route_id,
	ft.month;


-- Compare route profitability vs company average (CTE)
WITH route_revenue AS (
	SELECT
		route_id,
		SUM(revenue) AS total_revenue
	FROM loads
	GROUP BY route_id
),
route_fuel AS (
	SELECT 
		lo.route_id,
		SUM(fp.total_cost) AS fuel_cost
	FROM loads lo
	JOIN trips tr
		ON lo.load_id = tr.load_id
	JOIN fuel_purchases fp
		ON tr.trip_id = fp.trip_id
	GROUP BY lo.route_id
),
route_profit AS (
	SELECT 
		rr.route_id,
		ROUND(rr.total_revenue, 2) AS total_revenue,
		ROUND(
			COALESCE(rf.fuel_cost, 0), 2
		) AS total_fuel_cost,
		ROUND(
			rr.total_revenue - COALESCE(rf.fuel_cost, 0), 2
		) AS net_profit
	FROM route_revenue rr
	LEFT JOIN route_fuel rf
		ON rr.route_id = rf.route_id
),
avg_profit AS (
	SELECT 
		ROUND(AVG(net_profit), 2) AS company_average
	FROM route_profit
)
SELECT 
	rp.route_id,
	rp.net_profit,
	ap.company_average,
	ROUND((rp.net_profit - ap.company_average), 2) AS difference,
	CASE
		WHEN rp.net_profit > ap.company_average THEN 'Above Average'
		WHEN rp.net_profit < ap.company_average THEN 'Below Average'
		ELSE 'Equal to Average'
	END AS difference_status
FROM route_profit rp
CROSS JOIN avg_profit ap
ORDER BY rp.route_id;


-- Which route generated the highest revenue last month?
WITH route_revenue AS (
    SELECT
        lo.route_id,
		DATE_TRUNC('MONTH', tr.dispatch_date)::DATE AS month,
        SUM(lo.revenue) AS total_revenue
    FROM loads lo
    JOIN trips tr
        ON lo.load_id = tr.load_id
    WHERE DATE_TRUNC('MONTH', tr.dispatch_date) = (
        SELECT DATE_TRUNC('MONTH', MAX(dispatch_date))
        FROM trips)
    GROUP BY 
		lo.route_id,
		DATE_TRUNC('MONTH', tr.dispatch_date)
)
SELECT
    route_id,
	month,
    total_revenue
FROM route_revenue
WHERE total_revenue = (
    SELECT MAX(total_revenue)
    FROM route_revenue);