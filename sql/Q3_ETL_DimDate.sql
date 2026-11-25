USE VayuAir;
GO
/* LOAD DIMENSIONS INTO Dim Tables
Question 3: Load dimensions and fact from bronze layer tables. Load Dimension DimDate */


/* INSERT VALUES IN DIMENSION & FACT TABLES */

--Insert surrogate keys into Table DimPassenger
--Check nulls in bronze_passengers
SELECT COUNT(*) AS total_rows,
	   COUNT(DISTINCT passenger_id) AS unique_passenger_ids,
	   COUNT(*) - COUNT( passenger_id) AS null_passenger_ids
FROM dbo.bronze_passengers;

INSERT INTO dw.DimPassenger (passenger_id)
SELECT passenger_id FROM dbo.bronze_passengers;

--VALIDATING INSERTED VALUES IN DimPassenger
SELECT COUNT(*) AS total_passengers
FROM dw.DimPassenger;

--Insert surrogate keys into Table DimFlight
--Check null flight_ids in bronze_flights
SELECT COUNT(*) AS total_rows,
	   COUNT(DISTINCT flight_id) AS unique_flight_ids,
	   COUNT(*) - COUNT(flight_id) AS null_flight_ids
FROM dbo.bronze_flights;

INSERT dw.DimFlight (flight_id)
SELECT flight_id FROM dbo.bronze_flights;

--VALIDATING INSERTED VALUES IN DimFlight
SELECT COUNT(*) AS total_flights
FROM dw.DimFlight;


--Insert surrogate keys into Table DimAirport
--Get All Unique airport_codes
SELECT origin_airport_code AS airport_code
FROM dbo.bronze_flights
UNION 
SELECT dest_airport_code AS airport_code
FROM dbo.bronze_flights;

--Check Unique airport_codes from bronze_airports
SELECT COUNT(*),
	COUNT(DISTINCT airport_code) 
FROM dbo.bronze_airports;

--Get origin airport_codes from bronze_flights not matching in bronze_airport
SELECT origin_airport_code 
FROM dbo.bronze_flights
EXCEPT
SELECT airport_code
FROM dbo.bronze_airports;

--Get destination airport_codes from bronze_flights not matching in bronze_airport
SELECT dest_airport_code 
FROM dbo.bronze_flights
EXCEPT
SELECT airport_code
FROM dbo.bronze_airports;

INSERT INTO dw.DimAirport (airport_code)
SELECT airport_code FROM dbo.bronze_airports;

--VALIDATING INSERTED VALUES IN DimAirport
SELECT COUNT(*) AS total_rows FROM dw.DimAirport;


--Insert surrogate keys into Table DimAircraft
--Check NULL values in airport codes in bronze_aircraft
SELECT COUNT(*) AS total_rows,
COUNT( DISTINCT aircraft_code) AS unique_aircraft_codes,
COUNT(*) - COUNT(aircraft_code) AS null_airport_codes
FROM dbo.bronze_aircraft;

--Get aircraft codes from bronze_flights not matching in bronze_aircraft
SELECT aircraft_code FROM dbo.bronze_flights
EXCEPT
SELECT aircraft_code FROM dbo.bronze_aircraft;

INSERT INTO dw.DimAircraft (aircraft_code)
SELECT aircraft_code FROM dbo.bronze_aircraft;

--VALIDATING INSERTED VALUES IN DimAircraft
SELECT COUNT(*) AS total_rows FROM dw.DimAircraft;


--Update dimensions date into Dim tables.
UPDATE dp
SET dp.passenger_name = bp.passenger_name,
	dp.home_airport_code = bp.home_airport_code,
	dp.frequent_flyer_tier = bp.frequent_flyer_tier,
	dp.signup_date = bp.signup_date
FROM dw.DimPassenger AS dp
LEFT JOIN dbo.bronze_passengers AS bp
ON dp.passenger_id = bp.passenger_id;

UPDATE df
SET df.flight_number = bf.flight_number,
	df.origin_airport_code = bf.origin_airport_code,
	df.dest_airport_code = bf.dest_airport_code,
	df.aircraft_code = bf.aircraft_code,
	df.flight_date = bf.flight_date
FROM dw.DimFlight AS df
LEFT JOIN dbo.bronze_flights AS bf
ON df.flight_id = bf.flight_id;

UPDATE da
SET da.airport_name = ba.airport_name,
	da.city = ba.city,
	da.country = ba.country,
	da.region = ba.region
FROM dw.DimAirport AS da
LEFT JOIN dbo.bronze_airports AS ba
ON da.airport_code = ba.airport_code;

UPDATE dac
SET dac.[model] = bac.[model],
	dac.manufacturer = bac.manufacturer,
	dac.seat_capacity = bac.seat_capacity
FROM dw.DimAircraft AS dac
LEFT JOIN dbo.bronze_aircraft AS bac
ON dac.aircraft_code = bac.aircraft_code;

SELECT TOP 1 * FROM dw.FactTicketSales;
SELECT COUNT(*) FROM dw.DimPassenger;


--Insert values into Table DimDate
INSERT INTO dw.DimDate (date_key, full_date)
	   SELECT CAST(CONVERT(VARCHAR(8), full_date, 112) AS INT)
			  AS date_key, --"Convert" is used to change datatype of date
			  full_date
		FROM (
			SELECT booking_date AS full_date
			FROM dbo.bronze_bookings
			UNION
			SELECT travel_date AS full_date
			FROM dbo.bronze_bookings
			UNION
			SELECT flight_date AS full_date
			FROM dbo.bronze_flights
		) AS dates;


--VALIDATING INSERTED VALUES IN DimDate
SELECT COUNT(*) AS total_dates
FROM dw.DimDate;

--Insert values into Table FactTicketSales
INSERT INTO dw.FactTicketSales (booking_id, 
								passenger_key, 
								flight_key,
								booking_date_key,
								travel_date_key,
								flight_date_key,
								origin_airport_key,
								dest_airport_key,
								aircraft_key,
								fare_amount,
								tax_amount,
								miles_earned)
SELECT b.booking_id,
	   p.passenger_key,
	   f.flight_key,
	   bd.date_key AS booking_date_key,
	   td.date_key AS travel_date_key,
	   fd.date_key AS flight_date_key,
	   oc.airport_key AS origin_airport_key,
	   dc.airport_key AS dest_airport_key,
	   da.aircraft_key AS aircraft_key,
	   b.fare_amount,
	   b.tax_amount,
	   b.miles_earned
FROM dbo.bronze_bookings AS b
JOIN dw.DimPassenger AS p
ON b.passenger_id = p.passenger_id
JOIN dw.DimDate AS bd
ON b.booking_date = bd.full_date
JOIN dw.DimDate AS td
ON b.travel_date = td.full_date
JOIN dw.DimFlight AS f
ON b.flight_id = f.flight_id
JOIN dbo.bronze_flights AS bf
ON b.flight_id = bf.flight_id
JOIN dw.DimDate AS fd
ON bf.flight_date = fd.full_date
JOIN dw.DimAirport AS oc
ON oc.airport_code = bf.origin_airport_code
JOIN dw.DimAirport AS dc
ON dc.airport_code = bf.dest_airport_code
JOIN dw.DimAircraft AS da
ON da.aircraft_code = bf.aircraft_code;

--VALIDATING INSERTED VALUES IN FactTicketSales with bronze_bookings
SELECT COUNT(*) AS fact_total_rows FROM dw.FactTicketSales;
SELECT COUNT(*) AS bookings_total_rows FROM dbo.bronze_bookings;

--Check all rows of FK and validate count
SELECT COUNT(*) AS fact_total_rows,
	   COUNT(passenger_key) AS passenger_rows,
	   COUNT(flight_key) AS flight_rows,
	   COUNT(booking_date_key) AS booking_date_rows,
	   COUNT(travel_date_key) AS travel_date_rows,
	   COUNT(flight_date_key) AS flight_date_rows,
	   COUNT(origin_airport_key) AS origin_airport_key,
	   COUNT(dest_airport_key) AS dest_airport_key,
	   COUNT(aircraft_key) AS aircraft_key
FROM dw.FactTicketSales;









