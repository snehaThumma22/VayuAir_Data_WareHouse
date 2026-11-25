USE VayuAir;
GO
/* Question 5: Rebuild passenger dimension as 
   Slowly Changing Dimension SCD - Type 2*/

--Understand stg_passenger_updates data
SELECT COUNT(*) AS total_rows,
	   COUNT(DISTINCT passenger_id) AS unique_passenger_id
FROM dbo.stg_passenger_updates

SELECT * 
FROM dbo.stg_passenger_updates AS s
LEFT JOIN dw.DimPassenger AS p
ON s.passenger_id = p.passenger_id;

SELECT 
	COUNT(CASE WHEN dp.passenger_id IS NOT NULL THEN 1 END) AS existing_passengers, -- IS NOT NULL for existing passengers
	COUNT (CASE WHEN dp.passenger_id IS NULL THEN 1 END) AS new_passengers  -- IS NULL for new passengers
FROM dbo.stg_passenger_updates AS s
LEFT JOIN dw.DimPassenger AS dp
ON s.passenger_id = dp.passenger_id;

--Identifying existing passengers whose data is changed.
SELECT s.passenger_id,
	   p.home_airport_code AS old_home_airport_code,
	   p.frequent_flyer_tier AS old_frequent_flyer_tier,
	   s.home_airport_code AS new_home_airport_code,
	   s.frequent_flyer_tier AS new_frequent_flyer_tier
FROM dbo.stg_passenger_updates as s
LEFT JOIN dbo.bronze_passengers as p
ON s.passenger_id = p.passenger_id
WHERE p.passenger_id IS NOT NULL AND ( p.home_airport_code <> s.home_airport_code OR p.frequent_flyer_tier <> s.frequent_flyer_tier)


SELECT COUNT(CASE WHEN home_airport_code IS NOT NULL THEN 1 END) AS total_airport_code,
	   COUNT(CASE WHEN frequent_flyer_tier IS NOT NULL THEN 1 END) AS total_flyer_tier
FROM dbo.bronze_passengers

SELECT COUNT(CASE WHEN home_airport_code IS NOT NULL THEN 1 END) AS total_airport_code,
	   COUNT(CASE WHEN frequent_flyer_tier IS NOT NULL THEN 1 END) AS total_flyer_tier
FROM dbo.stg_passenger_updates


/* CREATE table DimPassenger_SCD2 to incorporate history and activity columns.
   INSERT values into DimPassenger_SCD2
   VALIDATING inserted values */
SELECT
    COUNT(*) AS total_passengers,
    MIN(passenger_key) AS minimum_key,
    MAX(passenger_key) AS maximum_key,
    COUNT(DISTINCT passenger_key) AS unique_keys
FROM dw.DimPassenger;

CREATE TABLE dw.DimPassenger_SCD2 (
			 passenger_key INT IDENTITY(1,1) PRIMARY KEY,
			 passenger_id INT NOT NULL,
			 passenger_name NVARCHAR(50) NOT NULL,
			 home_airport_code NVARCHAR(50) NOT NULL,
			 frequent_flyer_tier NVARCHAR(50) NOT NULL,
			 signup_date DATE NOT NULL,
			 effective_from DATE NOT NULL,
			 effective_to DATE NULL,
			 is_current BIT NOT NULL);

--Check values to insert into the scd type 2 table.
SELECT dp.passenger_key,
	   dp.passenger_id,
	   p.passenger_name,
	   p.home_airport_code,
	   p.frequent_flyer_tier,
	   p.signup_date,
	   p.signup_date AS effective_from,
	   CAST(NULL AS DATE) AS effective_to,
	   CAST(1 AS BIT) AS is_current
FROM dw.DimPassenger as dp
LEFT JOIN dbo.bronze_passengers as p
ON dp.passenger_id = p.passenger_id;

SELECT COUNT(*) AS unmatched_passengers
FROM dw.DimPassenger AS dp
LEFT JOIN dbo.bronze_passengers AS p
    ON dp.passenger_id = p.passenger_id
WHERE p.passenger_id IS NULL;


SET IDENTITY_INSERT dw.DimPassenger_SCD2 ON;
--Insert
INSERT INTO dw.DimPassenger_SCD2(
			passenger_key,
			passenger_id,
			passenger_name,
			home_airport_code,
			frequent_flyer_tier,
			signup_date,
			effective_from,
			effective_to,
			is_current)
SELECT dp.passenger_key,
	   dp.passenger_id,
	   p.passenger_name,
	   p.home_airport_code,
	   p.frequent_flyer_tier,
	   p.signup_date,
	   p.signup_date AS effective_from,
	   CAST(NULL AS DATE) AS effective_to,
	   CAST(1 AS BIT) AS is_current
FROM dw.DimPassenger as dp
LEFT JOIN dbo.bronze_passengers as p
ON dp.passenger_id = p.passenger_id;

SET IDENTITY_INSERT dw.DimPassenger_SCD2 OFF;

--Validate current and historical records
SELECT COUNT(*) AS total_records,
	   COUNT(CASE WHEN is_current = 1 THEN 1 END) AS current_records,
	   COUNT(CASE WHEN is_current = 0 THEN 1 END) AS historical_records
FROM dw.DimPassenger_SCD2;


SELECT COUNT(*) AS invalid_records
FROM dw.DimPassenger_SCD2
WHERE effective_from <> signup_date OR effective_to IS NOT NULL;

SELECT COUNT(*)
FROM dw.DimPassenger as dp
LEFT JOIN dw.DimPassenger_SCD2 as dps
ON dp.passenger_key = dps.passenger_key 
AND dp.passenger_id = dps.passenger_id
WHERE dps.passenger_key IS NULL;

SELECT dps.passenger_key,
	   dps.passenger_id,
	   dps.frequent_flyer_tier AS old_tier,
	   dp.frequent_flyer_tier AS new_tier,
	   dps.home_airport_code AS old_airport,
	   dp.home_airport_code AS new_airport
FROM dw.DimPassenger_SCD2 AS dps
LEFT JOIN dBO.stg_passenger_updates AS dp
ON dps.passenger_id = dp.passenger_id
WHERE dps.is_current = 1 AND dp.passenger_id IS NOT NULL
	  AND (dps.home_airport_code <> dp.home_airport_code OR dps.frequent_flyer_tier <> dp.frequent_flyer_tier);


SELECT COUNT(*) AS invalid_date_ranges
FROM dw.DimPassenger_SCD2 AS dps
LEFT JOIN dBO.stg_passenger_updates AS dp
ON dps.passenger_id = dp.passenger_id
WHERE dps.is_current = 1 AND dp.passenger_id IS NOT NULL
	  AND (dps.home_airport_code <> dp.home_airport_code OR dps.frequent_flyer_tier <> dp.frequent_flyer_tier)
	  AND (dps.effective_from >= CAST(GETDATE() AS DATE));

/* Storing the existing passengers changed data in temporary table
#ChangedPassenger before expiring them. */

/* Queries for checking the data

DECLARE @ProcessingDate DATE = CAST(GETDATE() AS DATE);

SELECT sp.passenger_id,
	   sp.passenger_name,
	   sp.home_airport_code,
	   sp.frequent_flyer_tier,
	   dps.signup_date,
	   @ProcessingDate AS effective_from,
	   CAST(NULL AS DATE) AS effective_to,
	   CAST(1 AS BIT) AS is_current
INTO #ChangedPassenger
FROM dbo.stg_passenger_updates AS sp
LEFT JOIN dw.DimPassenger_SCD2 AS dps
ON sp.passenger_id = dps.passenger_id
WHERE dps.is_current = 1 
	  AND (dps.home_airport_code <> sp.home_airport_code 
			OR dps.frequent_flyer_tier <> sp.frequent_flyer_tier);

--Validate the existing passengers changed data in Temporary Table.
SELECT COUNT(*) AS total_rows
FROM #ChangedPassenger


--UPDATE the existing passenger version by expiring them.
UPDATE dps
SET dps.is_current = 0,
	dps.effective_to = @ProcessingDate
FROM dw.DimPassenger_SCD2 AS dps
LEFT JOIN #ChangedPassenger AS cp
ON dps.passenger_id = cp.passenger_id
WHERE dps.is_current = 1 AND cp.passenger_id IS NOT NULL;

--INSERT the data into SCD type 2 from Temporary table.
INSERT INTO dw.DimPassenger_SCD2(
			passenger_id,
			passenger_name,
			home_airport_code,
			frequent_flyer_tier,
			signup_date,
			effective_from,
			effective_to,
			is_current)
SELECT cp.passenger_id,
	   cp.passenger_name,
	   cp.home_airport_code,
	   cp.frequent_flyer_tier,
	   cp.signup_date,
	   cp.effective_from,
	   cp.effective_to,
	   cp.is_current
FROM #ChangedPassenger AS cp */


SET XACT_ABORT ON;
BEGIN TRY
	BEGIN TRANSACTION;
	DECLARE @ProcessingDate DATE = CAST(GETDATE() AS DATE);

	DROP TABLE IF EXISTS #ChangedPassenger;

	--Temporary Table
	SELECT sp.passenger_id,
	   sp.passenger_name,
	   sp.home_airport_code,
	   sp.frequent_flyer_tier,
	   dps.signup_date,
	   @ProcessingDate AS effective_from,
	   CAST(NULL AS DATE) AS effective_to,
	   CAST(1 AS BIT) AS is_current
	INTO #ChangedPassenger
	FROM dbo.stg_passenger_updates AS sp
	LEFT JOIN dw.DimPassenger_SCD2 AS dps
	ON sp.passenger_id = dps.passenger_id
	WHERE dps.is_current = 1 
		  AND (dps.home_airport_code <> sp.home_airport_code 
				OR dps.frequent_flyer_tier <> sp.frequent_flyer_tier);
	--Validation of Temporary table
	DECLARE @ChangedCount INT;

	SELECT @ChangedCount = COUNT(*)
	FROM #ChangedPassenger;

	IF @ChangedCount <> 200
		THROW 50001, 'Unexpected number of changed passengers', 1;

	--UPDATE the existing passenger version by expiring them.
	UPDATE dps
	SET dps.is_current = 0,
		dps.effective_to = @ProcessingDate
	FROM dw.DimPassenger_SCD2 AS dps
	LEFT JOIN #ChangedPassenger AS cp
	ON dps.passenger_id = cp.passenger_id
	WHERE dps.is_current = 1 AND cp.passenger_id IS NOT NULL;

	DECLARE @ExpiredCount INT = @@ROWCOUNT;

	IF @ExpiredCount <> 200
		THROW 50002, 'Unexpected number of expired passengers', 1;

	INSERT INTO dw.DimPassenger_SCD2(
				passenger_id,
				passenger_name,
				home_airport_code,
				frequent_flyer_tier,
				signup_date,
				effective_from,
				effective_to,
				is_current)
	SELECT cp.passenger_id,
		   cp.passenger_name,
		   cp.home_airport_code,
		   cp.frequent_flyer_tier,
		   cp.signup_date,
		   cp.effective_from,
		   cp.effective_to,
		   cp.is_current
	FROM #ChangedPassenger AS cp;

	DECLARE @InsertedCount INT = @@ROWCOUNT;

	IF @InsertedCount <> 200
		THROW 50003, 'Unexpected number of inserted passengers', 1;
	--Validate current and historical versions.
	SELECT
		passenger_id,
		COUNT(*) AS total_versions,
		SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END) AS current_versions,
		SUM(CASE WHEN is_current = 0 THEN 1 ELSE 0 END) AS historical_versions
	FROM dw.DimPassenger_SCD2
	WHERE passenger_id IN (
		SELECT passenger_id
		FROM #ChangedPassenger
	)
	GROUP BY passenger_id;

	IF EXISTS (
		SELECT passenger_id
		FROM dw.DimPassenger_SCD2
		WHERE passenger_id IN (
			SELECT passenger_id
			FROM #ChangedPassenger
		)
		GROUP BY passenger_id
		HAVING COUNT(*) <> 2
			OR SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END) <> 1
			OR SUM(CASE WHEN is_current = 0 THEN 1 ELSE 0 END) <> 1
	)
		THROW 50004, 'Invalid SCD2 passenger versions', 1;
	IF EXISTS (
		SELECT 1
		FROM dw.DimPassenger_SCD2 AS old
		LEFT JOIN dw.DimPassenger_SCD2 AS new
			ON old.passenger_id = new.passenger_id
			AND new.is_current = 1
		WHERE old.is_current = 0
		  AND old.passenger_id IN (
			  SELECT passenger_id
			  FROM #ChangedPassenger
		  )
		  AND (
			  old.effective_to IS NULL
			  OR new.effective_from IS NULL
			  OR old.effective_to <> new.effective_from
			  OR new.passenger_id IS NULL
			  OR new.effective_to IS NOT NULL
		  )
	)
		THROW 50005, 'Invalid SCD2 effective dates', 1;

	COMMIT TRANSACTION;
END TRY
BEGIN CATCH
	IF @@TRANCOUNT >0
		ROLLBACK TRANSACTION;

	THROW;
END CATCH;

--Validate SCD Type 2 with currents and historical rows.
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END) AS current_rows,
    SUM(CASE WHEN is_current = 0 THEN 1 ELSE 0 END) AS historical_rows
FROM dw.DimPassenger_SCD2;


/* NEW PASSENGERS DATA FROM stg_passenger_updates*/

SELECT COUNT(*) AS new_passengers
FROM dbo.stg_passenger_updates as s
LEFT JOIN dw.DimPassenger_SCD2 as dps
ON s.passenger_id = dps.passenger_id
WHERE dps.passenger_id IS NULL;

SELECT s.passenger_id, 
	s.passenger_name,
	s.home_airport_code,
	s.frequent_flyer_tier,
	@ProcessingDate AS signup_date,
	@ProcessingDate AS effective_from,
	CAST(NULL AS DATE) AS effective_to,
	CAST(1 AS BIT) AS is_current
FROM dbo.stg_passenger_updates AS s
LEFT JOIN dw.DimPassenger_SCD2 as dps 
ON s.passenger_id = dps.passenger_id 
WHERE dps.passenger_id IS NULL;


-- UPDATE NEW PASSENGERS INTO SCD type 2 TABLE.
SET XACT_ABORT ON;
BEGIN TRY 
	BEGIN TRANSACTION;
	DECLARE @ProcessingDate_new DATE = CAST(GETDATE() AS DATE);

	INSERT INTO dw.DimPassenger_SCD2 (
		passenger_id,
		passenger_name,
		home_airport_code,
		frequent_flyer_tier,
		signup_date,
		effective_from,
		effective_to,
		is_current
	)
	SELECT s.passenger_id, 
		   s.passenger_name,
		   s.home_airport_code,
		   s.frequent_flyer_tier,
		   @ProcessingDate_new AS signup_date,
		   @ProcessingDate_new AS effective_from,
		   CAST(NULL AS DATE) AS effective_to,
		   CAST(1 AS BIT) AS is_current
	FROM dbo.stg_passenger_updates AS s
	LEFT JOIN dw.DimPassenger_SCD2 as dps 
	ON s.passenger_id = dps.passenger_id 
	WHERE dps.passenger_id IS NULL;

	DECLARE @InsertedCount_new INT = @@ROWCOUNT;

	IF @InsertedCount_new <> 50
		THROW 50006, 'Unexpected number of inserted passengers', 1;

	COMMIT TRANSACTION;
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0
		ROLLBACK TRANSACTION;
	THROW;
END CATCH;

--Validate SCD Tye 2 table records.
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END) AS current_rows,
    SUM(CASE WHEN is_current = 0 THEN 1 ELSE 0 END) AS historical_rows
FROM dw.DimPassenger_SCD2;

SELECT
    s.passenger_id,
    COUNT(*) AS total_versions,
    SUM(CASE WHEN dps.is_current = 1 THEN 1 ELSE 0 END) AS current_versions
FROM dbo.stg_passenger_updates AS s
LEFT JOIN dw.DimPassenger_SCD2 AS dps
ON s.passenger_id = dps.passenger_id
WHERE dps.signup_date = @ProcessingDate
GROUP BY s.passenger_id
HAVING COUNT(*) <> 1
    OR SUM(CASE WHEN dps.is_current = 1 THEN 1 ELSE 0 END) <> 1;

--Validate FACT table relationship
SELECT COUNT(*) AS unmatched_passenger_keys
FROM dw.FactTicketSales AS f
LEFT JOIN dw.DimPassenger_SCD2 AS dps
ON f.passenger_key = dps.passenger_key
WHERE dps.passenger_key IS NULL;

  
/* FK passenger_key migration FROM 
   DimPassenger table to DimPassenger_SCD2 
   Dropping the FK pointing to old dim
   Create FK pointing to the new SCD2 dim */

ALTER TABLE dw.FactTicketSales
DROP CONSTRAINT FK_FactTicketSales_DimPassenger;

ALTER TABLE dw.FactTicketSales
WITH CHECK
ADD CONSTRAINT FK_FactTicketSales_DimPassenger_SCD2
FOREIGN KEY (passenger_key)
REFERENCES dw.DimPassenger_SCD2(passenger_key);

--Verify 40K FACT table records.
SELECT COUNT(*) AS total_fact_records
FROM dw.FactTicketSales;


/*
Original passenger versions use signup_date as effective_from.
The old effective_to equals the new effective_from.
Staging does not provide signup_date for new passengers, so the processing date is used as an exercise assumption. */