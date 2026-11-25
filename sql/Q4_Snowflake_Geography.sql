USE VayuAir;
GO

/* Question 4: Snowflake geography: Normalize airport dimension into 3 linked tables
aiport, city & country */


--BUILD SNOWFLAKE GEOGRAPHY FOR airport DIMENSION

/* Understand bronze_airport table
   Check columns in bronze_airports */

SELECT * FROM dbo.bronze_airports;

SELECT DISTINCT country, region FROM dbo.bronze_airports;
SELECT DISTINCT region FROM dbo.bronze_airports;

--Check country by region, with countries appearing in more than 1 region.
SELECT country,
	   COUNT(DISTINCT region) AS region_count
FROM dbo.bronze_airports
GROUP BY country
HAVING COUNT(DISTINCT region) > 1;

--Check null values in region columns.
SELECT
	   COUNT(*) AS total_rows,
	   COUNT(DISTINCT region) AS region_count,
	   COUNT(*) - COUNT(region) AS null_regions
FROM dbo.bronze_airports;


/* CREATE Table DimCountry
   INSERT values into DimCountry
   VERIFY the rows in DimCountry */
CREATE TABLE dw.DimCountry(
			 country_key INT IDENTITY(1,1) PRIMARY KEY,
			 country VARCHAR(50) NOT NULL UNIQUE,
			 region VARCHAR(50) NOT NULL
			 );

INSERT INTO dw.DimCountry (country, region)
SELECT DISTINCT country, region FROM dbo.bronze_airports;

SELECT COUNT(*) AS countries
FROM dw.DimCountry;


/* CREATE Table DimCity 
   INSERT values into DimCity 
   VERIFY the rows in DimCity  */
CREATE TABLE dw.DimCity(
			 city_key INT IDENTITY(1,1) PRIMARY KEY,
			 country_key INT NOT NULL,
			 city VARCHAR(50) NOT NULL,

			 FOREIGN KEY (country_key)
			 REFERENCES dw.DimCountry(country_key),

			 CONSTRAINT UQ_DimCity_city_country
			 UNIQUE (city, country_key)
			 );

--Check if there is any unique city with country for null.
SELECT DISTINCT a.city,
	   dc.country_key
FROM dbo.bronze_airports AS a
LEFT JOIN dw.DimCountry as dc
ON a.country = dc.country
WHERE dc.country_key IS NULL;

SELECT * FROM dw.DimCountry;
SELECT * FROM dw.DimCity;

INSERT INTO dw.DimCity (city, country_key)
SELECT DISTINCT a.city,
				dc.country_key
FROM dbo.bronze_airports AS a
LEFT JOIN dw.DimCountry as dc
ON a.country = dc.country;

SELECT COUNT(*) AS total_cities
FROM dw.DimCity;
SELECT COUNT(*) AS total_rows
FROM dw.DimAirport;

--Adding a column into DimAirport with Null values
ALTER TABLE dw.DimAirport
ADD city_key INT NULL;
GO

SELECT * FROM dw.DimAirport;

--Drop the Geaography columns as city_key is added.
ALTER TABLE dw.DimAirport
DROP COLUMN city, country, region;

--Update city_key column in DimAirport with composite constraint(city, country_key)
UPDATE da
SET da.city_key = dci.city_key
FROM dw.DimAirport AS da
LEFT JOIN dbo.bronze_airports as a
ON da.airport_code = a.airport_code
LEFT JOIN dw.DimCountry as dc
ON a.country = dc.country
LEFT JOIN dw.DimCity as dci 
ON a.city = dci.city 
AND dc.country_key = dci.country_key


SELECT COUNT(*) AS missing_city_keys
FROM dw.DimAirport 
WHERE city_key IS NULL

--Change the constraint to Not Null after populating city_key column.
ALTER TABLE dw.DimAirport
ALTER COLUMN city_key INT NOT NULL;

--Add FK constraint to city_key column
ALTER TABLE dw.DimAirport
ADD CONSTRAINT FK_DimAirport_city_key
FOREIGN KEY (city_key)
REFERENCES dw.DimCity(city_key)

--Hierarchy check.
SELECT
    da.airport_code,
    dci.city,
    dc.country,
    dc.region
FROM dw.DimAirport AS da
LEFT JOIN dw.DimCity AS dci
    ON da.city_key = dci.city_key
LEFT JOIN dw.DimCountry AS dc
    ON dci.country_key = dc.country_key;


--Retrieve airport_code, city, country and count the rows to check null.
SELECT COUNT(city) AS cities,
	   COUNT(country) AS countries
FROM (SELECT da.airport_code,
	   dci.city,
	   dc.country
FROM dw.DimAirport AS da
LEFT JOIN dw.DimCity as dci
ON da.city_key = dci.city_key
LEFT JOIN dw.DimCountry as dc
ON dci.country_key = dc.country_key) AS t;




/*
SnowFlake Schema:
Advantages: Helps structure data, reduces data duplication by seperating airport, 
city, country into tables like DimAiport, DimCity, DimCountry.

Trade off: Requires additional joins increasing query complexity and potentially
impacting the performance of the query.
*/