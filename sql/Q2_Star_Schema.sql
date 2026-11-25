USE VayuAir;
GO

--Grain: One row in sales fact table represents one "booking" asssociated with a flight.
/* Question 2: Create star schema and write the DDL */

--Understanding the number of records in bronze layer.
SELECT 'bronze_airports' AS table_name, COUNT(*) AS rows FROM dbo.bronze_airports
UNION ALL
SELECT 'bronze_aircraft' AS table_name, COUNT(*) AS rows FROM dbo.bronze_aircraft
UNION ALL
SELECT 'bronze_bookings' AS table_name, COUNT(*) AS rows FROM dbo.bronze_bookings
UNION ALL
SELECT 'bronze_flights' AS table_name, COUNT(*) AS rows FROM dbo.bronze_flights
UNION ALL
SELECT 'bronze_passengers' AS table_name, COUNT(*) AS rows FROM dbo.bronze_passengers
UNION ALL
SELECT 'stg_passenger_updates' AS table_name, COUNT(*) AS rows FROM dbo.stg_passenger_updates;

/* Checking uniqueness of the primary keys in the bronze layer tables */

--bronze_bookings: Check if booking_id is unique
SELECT booking_id,
	COUNT(booking_id) AS count_id
FROM dbo.bronze_bookings
GROUP BY booking_id
HAVING COUNT(booking_id) > 1;

--bronze_bookings: Check nulls in booking_id
SELECT COUNT(*),
	COUNT(DISTINCT booking_id) AS unique_id,
	COUNT(*) - COUNT(booking_id) AS null_booking_ids
FROM dbo.bronze_bookings;

--bronze_bookings: Check unique flight_ids
SELECT COUNT(DISTINCT flight_id) 
FROM dbo.bronze_bookings;

--bronze_flights: Check count of flight_id with out null
SELECT COUNT(flight_id) 
FROM dbo.bronze_flights;

--bronze_flights: Check if flight id has nulls
SELECT COUNT(*) AS total_rows,
	   COUNT(DISTINCT flight_id) AS unique_flight_ids,
	   COUNT(*) - COUNT(flight_id) AS null_flight_ids
FROM dbo.bronze_flights;

--Join flights and bookings
SELECT COUNT(*) AS joined_rows
FROM dbo.bronze_bookings AS b
INNER JOIN dbo.bronze_flights AS f
ON b.flight_id = f.flight_id;

--Check first row from bookings and flights
SELECT TOP 1 * FROM dbo.bronze_bookings;
SELECT TOP 1 * FROM dbo.bronze_flights;

--Create schema for dim and facts
GO
CREATE SCHEMA dw;
GO

/* STAR SCHEMA 
   CREATE DIMENSION & FACT TABLES */

--Table DimPassenger
CREATE TABLE dw.DimPassenger(
	passenger_key INT IDENTITY(1, 1) PRIMARY KEY,
	passenger_id INT NOT NULL
);
--Change the Constraint to Unique
ALTER TABLE dw.DimPassenger
ADD CONSTRAINT UQ_DimPassenger_passenger_id
UNIQUE (passenger_id);


--Table DimFlight
CREATE TABLE dw.DimFlight(
	flight_key INT IDENTITY(1, 1) PRIMARY KEY,
	flight_id INT NOT NULL
);
--Change the Constraint to Unique
ALTER TABLE dw.DimFlight
ADD CONSTRAINT UQ_DimFlight_flight_id
UNIQUE (flight_id);


--Table DimAirport
CREATE TABLE dw.DimAirport(
	airport_key INT IDENTITY(1, 1) PRIMARY KEY,
	airport_code CHAR(3) NOT NULL UNIQUE
);


--Table DimAircraft
--Find length of aircraft code for Table DimAircraft
SELECT MAX(LEN(aircraft_code))
FROM dbo.bronze_flights

CREATE TABLE dw.DimAircraft(
	aircraft_key INT IDENTITY(1, 1) PRIMARY KEY,
	aircraft_code VARCHAR(4) NOT NULL UNIQUE
);


--Create Table DimDate
CREATE TABLE dw.DimDate(
	date_key INT PRIMARY KEY,
	full_date DATE NOT NULL UNIQUE
);


--Table FactTicketSales
CREATE TABLE dw.FactTicketSales(
	passenger_key INT NOT NULL,
	flight_key INT NOT NULL,
	booking_date_key INT NOT NULL,
	travel_date_key INT NOT NULL,
	flight_date_key INT NOT NULL,
	origin_airport_key INT NOT NULL,
	dest_airport_key INT NOT NULL,
	aircraft_key INT NOT NULL,
	booking_id INT NOT NULL UNIQUE,
	fare_amount DECIMAL(12,2), 
	tax_amount DECIMAL(12,2),
	miles_earned INT,

	CONSTRAINT FK_FactTicketSales_DimPassenger
	FOREIGN KEY (passenger_key)
	REFERENCES dw.DimPassenger(passenger_key),

	FOREIGN KEY (flight_key)
	REFERENCES dw.DimFlight(flight_key),

	FOREIGN KEY (booking_date_key)
	REFERENCES dw.DimDate(date_key),

	FOREIGN KEY (travel_date_key)
	REFERENCES dw.DimDate(date_key),

	FOREIGN KEY (flight_date_key)
	REFERENCES dw.DimDate(date_key),

	FOREIGN KEY (origin_airport_key)
	REFERENCES dw.DimAirport(airport_key),

	FOREIGN KEY (dest_airport_key)
	REFERENCES dw.DimAirport(airport_key),

	FOREIGN KEY (aircraft_key)
	REFERENCES dw.DimAircraft(aircraft_key)
);

--Continuing Q3 by adding dimension columns in the Dim tables from bronze layer.
--Add dimensions to DimPassenger
ALTER TABLE dw.DimPassenger
ADD passenger_name NVARCHAR(50),
	home_airport_code NVARCHAR(50),
	frequent_flyer_tier NVARCHAR(50),
	signup_date DATE;

--Add dimensions to DimFlight
ALTER TABLE dw.DimFlight
ADD flight_number NVARCHAR(50),
	origin_airport_code NVARCHAR(50),
	dest_airport_code NVARCHAR(50),
	aircraft_code NVARCHAR(50),
	flight_date DATE;
SELECT TOP 1 * FROM dw.DimFlight;

--Add dimensions to DimAirport
ALTER TABLE dw.DimAirport
ADD airport_name NVARCHAR(50),
	city NVARCHAR(50),
	country NVARCHAR(50),
	region NVARCHAR(50);
SELECT TOP 1 * FROM dw.DimAirport;

--Add dimensions to DimAircraft
ALTER TABLE dw.DimAircraft
ADD manufacturer NVARCHAR(50),
	[model] NVARCHAR(50),
	seat_capacity smallint;
SELECT TOP 1 * FROM dw.DimAircraft;





