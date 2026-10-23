# Logistics Operations Analytics

## Project Overview

This project is a SQL-based operational analysis of a third-party logistics (3PL) transportation network. It turns raw Transportation Management System (TMS) data into practical insight for operations, finance, fleet management, safety and compliance, sales and strategic planning teams.

The analysis looks at eight areas of logistics performance: driver reliability, route profitability, fleet utilization, the effect of maintenance on capacity, fuel efficiency, customer revenue, safety risk and seasonal demand.
All queries were written in PostgreSQL (hosted on Supabase) against a relational logistics database covering loads, trips, drivers, trucks, routes, customers and operational events.

---

## Objectives

The project set out to:

* Compare drivers on on-time delivery, fuel efficiency and revenue per mile.
* Separate profitable routes from those where fuel cost eats the margin.
* Check whether trucks are used evenly or whether some are under- or over-used.
* Measure what maintenance costs in money and in lost truck hours.
* Look at fuel efficiency patterns across routes.
* Find the highest-value customers and see how revenue is spread across the customer base.
* Assess safety risk from incident records, including preventable incidents.
* Check whether shipment demand follows a seasonal pattern.

---

## Database Architecture

The database models a simplified TMS of the kind used by freight companies. It has 14 tables across master, transactional and operational data, including:

* Drivers
* Trucks
* Trailers
* Customers
* Facilities
* Routes
* Loads
* Trips
* Fuel Purchases
* Maintenance Records
* Delivery Events
* Safety Incidents
* Driver Monthly Metrics
* Truck Utilization Metrics

Together they follow a shipment from booking through trip, fuel purchases, delivery, maintenance and safety events. Trips link to loads one-to-one, and fuel purchases, delivery events and incidents link many-to-one to trips. For that reason each metric is aggregated separately before joining, so totals are never double counted.

---

## Analytical Framework

The project uses these SQL techniques:

* Window functions (RANK, DENSE_RANK, NTILE, rolling frames) for ranking and benchmarking
* Common Table Expressions (CTEs) to break complex logic into clear steps
* Time-series analysis with LAG and DATE_TRUNC to track trends month to month and quarter to quarter
* Multi-table joins to build cross-domain metrics such as maintenance cost per mile and incidents per 100 trips
* Comparison against fleet and company averages and medians

The work is organised into eight modules, each tied to a stakeholder group in a logistics company.

---

## Analytical Modules

1. Driver Performance Analysis
2. Route Profitability Assessment
3. Fleet Utilization Monitoring
4. Maintenance Cost Impact Analysis
5. Fuel Efficiency Analysis
6. Customer Revenue Analysis
7. Safety Risk Assessment
8. Seasonal Demand Pattern Analysis

Every module answers a separate operational question and ends with findings that the relevant team can act on.

---

## Key Findings

* **Delivery reliability:** The fleet on-time rate is 55.68%, so almost half of delivery events miss their window. Drivers sit in a narrow band (51.61% to 58.98%), which points to a systemic issue and not a few weak performers. DRV00108 is best, and DRV00133 and DRV00074 trail the fleet by about four points.

* **Route profitability:** Route RTE00016 earns the highest profit after fuel ($8.46M) and also the highest December 2024 revenue. Seven routes lose money once fuel is deducted, led by RTE00010 (−$1.42M). Fuel cost has risen three months in a row on seven routes, most sharply on RTE00028 (+95% from October to December 2024).

* **Maintenance:** Truck TRK00003 has both the highest maintenance cost ($90,161.42) and the most downtime (1,133.1 hours), which makes it a candidate for overhaul or replacement.

* **Fleet utilization:** Mileage is fairly even across the fleet, but 44 of 92 trucks run below the 1,301,480-mile average. TRK00040 is the lowest at 1,178,515 miles.

* **Fuel efficiency:** MPG barely varies by route (6.47 to 6.54), yet fuel cost per mile ranges from $0.39 to $13.69, with RTE00015 the highest. Because fuel cost per route is almost constant, the per-mile figures should be validated before use.

* **Customers:** Revenue of $262.5M is spread widely across 200 customers. No customer holds more than 0.59% and the top ten together hold 5.7%, so there is little concentration risk. Revenue per load ranges from $2,695 to $3,294.

* **Safety:** DRV00058 has the most incidents (7) and the highest rate (1.06 per 100 trips). Of 170 incidents, 64 (37.6%) were preventable. Incidents rose from 54 in 2023 to 60 in 2024, though the change is small enough to be normal variation.

* **Demand:** Volume is steady at about 2,370 loads a month across all three years. The busiest month was August 2022 (2,496 loads), but the peak shifts from year to year, so a rolling forecast fits better than a fixed seasonal plan.

---

## Technologies Used

* PostgreSQL
* SQL (window functions, CTEs, aggregations, time-series analysis)
* pgAdmin for writing and running queries
* Supabase (hosted PostgreSQL)
* Relational database modeling

### Data Environment

The dataset sits in a **Supabase** project, which provides managed PostgreSQL. I connected to it from **pgAdmin** and ran all queries there.

The connection used a **read-focused analyst role, not an administrator account**. That mirrors how analysts usually work inside a company: no control over the database itself, only the ability to query the tables and schema that already exist. Every result in this project therefore comes from queries alone, with no changes to the data or its structure.

---

## Repository Structure

The repository contains:

* SQL queries for each analysis
* The database schema for the logistics dataset
* The project report with findings and recommendations

---

## Author

[Divyadarshan Pattanayak](www.linkedin.com/in/divyadarshan-pattanayak-2a3a3437a)

Date: October 2026
