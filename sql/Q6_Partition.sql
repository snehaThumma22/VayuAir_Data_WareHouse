USE VayuAir;
GO
--Question 6: Partition SALES FACT table by date.


--choosing booking_date_key to use for partition.
--Understanding booking_date_key to create parition.
SELECT MIN(booking_date_key) AS earliest_date,
	   MAX(booking_date_key) AS latest_dates,
	   COUNT(*) AS total_rows,
	   COUNT(booking_date_key) AS no_booking_dates
FROM dw.FactTicketSales;


/* CREATE PARTITION FUNCTION - to decide which records goes into what partition
   CREATE PARTITION SCHEME - to decide where each parition is stored
   PARTITION ELIMIATION - VALIDATION */

CREATE PARTITION FUNCTION pf_TicketSales_BookingDate (INT)
AS RANGE RIGHT -- BOUNDARY IS ON THE RIGHT
FOR VALUES (20250101, 20260101);
GO

CREATE PARTITION SCHEME ps_TicketSales_BookingDate 
AS PARTITION pf_TicketSales_BookingDate
TO ([PRIMARY], [PRIMARY], [PRIMARY]);
GO

--Create a partitioned clustered index to move Fact table from a heap onto the partition scheme.
CREATE CLUSTERED INDEX CX_FactTicketSales_BookingDate
ON dw.FactTicketSales (booking_date_key, booking_id)
ON ps_TicketSales_BookingDate (booking_date_key);
GO

-- Verify the fact table is on the partition scheme.
SELECT
    i.name AS index_name,
    ps.name AS partition_scheme,
    p.partition_number,
    p.rows AS total_rows
FROM sys.partitions AS p
JOIN sys.indexes AS i
    ON p.object_id = i.object_id
    AND p.index_id = i.index_id
JOIN sys.partition_schemes AS ps
    ON i.data_space_id = ps.data_space_id
WHERE p.object_id = OBJECT_ID('dw.FactTicketSales')
    AND p.index_id = 1
ORDER BY p.partition_number;


-- Enable Include Actual Execution Plan in SSMS.
-- Execute the following two queries.
-- Inspect Actual Partition Count and Actual Partitions
-- Accessed in the clustered index operator properties.

--VALIDATE partition elimination.
--PARTITION COLUMN(booking_date_key)
SELECT COUNT(*)
FROM dw.FactTicketSales 
WITH (INDEX(CX_FactTicketSales_BookingDate))
WHERE booking_date_key >= 20250101 AND booking_date_key < 20260101;
--NON-PARTITION COLUMN(passenger_key)
SELECT COUNT(*)
FROM dw.FactTicketSales 
WITH (INDEX(CX_FactTicketSales_BookingDate))
WHERE passenger_key = 100;

--The first query filters directly on the partition key,
-- allowing SQL server to elimiate the irrelevant partitions and access only partition 2.
--The second query filters on a non-partition column, 
-- SQL server cannot determine which date partition contains the matching records 
-- and therefore access all three partitions using the selected index.
--An index hint was used to ensure both queries accessed the same partitioned clustered index.