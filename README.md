Project Overview:
Building an airline ticketing sales data warehouse in SQL Server.

-------------------------------------------------
Vayu Air - Data Modelling & Warehouse Engineering.
--------------------------------------------------
Project Over view:
The project implements an airline ticket sales data warehouse using Microsoft SQL Server as a part of Data Engineering learning assignment.
The project demonstrates dimensional modelling, star and snowflake schemas, ETL loading, Slowly changing dimension Type 2 and fact table partitioning.

Tools & Technologies:
 1. Microsoft SQL Server
 2. SQL Server Management Studio(SSMS)
 3. T-SQl
 4. GitHub

Prerequisites:
1. Create the VayuAir Database.
2. Import the bronze source tables and stg_passenger_updates using the provided the assigment dataset.
3. Ensure the dw schema  does not already exist before the initial execution.

Execution Order:
### Execute the .sql scripts in the following order:

 1. `Q2_Star_Schema.sql`
 2. `Q3_ETL_DimDate.sql`
 3. `Q4_Snowflake_Geography.sql`
 4. `Q5_SCD_Type2.sql`
 5. `Q6_Partition.sql`

The scripts are designed for an initial warehouse build in a fresh DB containing the source tables.

-------------------------------------------------------------------------------------------

Question 1:
Grain: One row in sales fact table represents one "booking" asssociated with a flight.

### Dimension Keys

| Source Business Key | Dimension Key (Surrogate Key) |
|---|---|
| aircraft_code | aircraft_code_key |
| origin_airport_code | origin_airport_code_key |
| dest_airport_code | dest_airport_code_key |
| passenger_id | passenger_key |
| flight_id | flight_key |
| flight_date | flight_date_key |
| booking_date | booking_date_key |
| travel_date | travel_date_key |


### Degenerate Dimension: Retained in the Fact table without seperate dimension table.
 1. booking id 

### Descriptive Dimension Attributes:
1. fare_class
2. booking_status
3. flight_number

### Additive Measures:
1. fare_amount
2. tax_amount
3. miles_earned

- Additive measures: fare_amount, tax_amount, miles_earned
- Non-additive measures: fare_amount per miles_earned ( a calculated ratio) - Can not be further aggregated into a meaningful value.

-------------------------------------------------------------------------------------------
Question 2: 
- Created the dw schema to organise the data warehouse tables.
- The star schema contains one central fact table and five dimension tables.
| Dimension table | Primary key |
|---|---|
|DimAircraft | aircraft_key|
|DimAirport  | airport_key|
|DimFlight   | flight_key|
|DimPassenger  | passenger_key|
|DimDate  | date_key|

Fact Table: dw.FactTicketSales 
- Surrogate keys are used to identify the dimension records.
- Business keys are retained in dimension tables.
- 8 FK relationships connect Fact table to the 5 Dimension tables.
- booking_id is retained in Fact table as a degenerate dimension.
- Only additive measures are stored in the Facts table.

DimDate and DimAirport are role playing dimensions as they are referenced many times by the fact table.

-------------------------------------------------------------------------------------------
Question 3:
- Load the dimension and fact tables from the bronze source tables.
- Surrogate keys were generated for the dimensions  and business key joins were used to resolve the corresponding surrogate keys while populating FactTicketSales.
- DimDate was populated using distinct booking, travel, flight date keys in integer YYYYMMDD format.

Results:
|Table | Record count|
|---|---|
|DimPassenger | 1500|
|DimFlight | 2000|
|DimAirport | 24|
|DimAircraft | 10|
|DimDate | 515|
|FactTicketSales |40,000|
|bronze_bookings | 40,000|

Validation:
- Fact count matches the bronze booking count.
- All 8 dimension Fks are populated.
- Every fact record resolves to its corresponding dimension records.

-------------------------------------------------------------------------------------------
Question 4:
- Normalized airport dimension into 3 linked tables.
- DimAirport -> DimCity -> DimCountry
- DimAirport references DimCity through city_key
- DimCity references DimCountry through country_key

- Advantages: Helps structure data, reduces data duplication by seperating airport, city, country into tables like DimAiport, DimCity, DimCountry.
- Trade off: Requires additional joins increasing query complexity and potentially impacting the performance of the query.

Validation:
- All 24 airport records resolve to their corresponding cities and countries through FK relationships.

-------------------------------------------------------------------------------------------
Question 5:
- Create dw.DimPassenger_SCD2 to maintain historical changes in passenger attributes.
- The followings columns were introduced:
1. effective_from
2. effective_to
3. is_current

Implementation:
1. Identified existing passengers whose frequent_flyer_tier or home_airport_code changed.
2. Stored the changed records in a temporary table.
3. Expired the existing versions by setting is_current to 0 and updating the effective_to.
4. Inserted new current versions with new surrogate keys.
5. Inserted brand new passengers as single current records.

- Transactions were used to maintain data consistency during expire and insert process.
- Original passenger surrogate keys were preserved to maintain historical fact table relationships.

Results:
|Description | Record count|
|---|---|
|Original passengers | 1,500|
|Changed passengers  | 200|
|Brand New passengers | 50|
|Historical records  | 200|
|Current records | 1550|
|Total SCD2 records | 1750|

Validation:
1. Changed passengers have two versions.
2. Brand new passengers have one version.
3. Each passenger has exactly one current record.
4. Historical effective_to matches the new version's effective_from.
5. All 40,000 fact tables are preserved.

Assumption:
- Since the staging table does not provide the signup date for the new passengers, the processing date is used as their sign date.

-------------------------------------------------------------------------------------------
Question 6:
- Partitioned FactTicketSales using booking_date_key.
- Created a RANGE RIGHT partition function and a partition scheme with yearly boundaries.
### Partition Structure

| Partition | Booking Date Range |
|---|---|
| Partition 1 | Before 2025 |
| Partition 2 | 2025 to 2025 |
| Partition 3 | 2026 and later |

-Created  a partitioned clustered index on booking_date_key and booking_id to place the fact table on the partition scheme.

### Partition Elimination Results

| Query Filter | Partitions Accessed | Actual Partition Count |
|---|---|---|
| booking_date_key: Year 2025 | Partition 2 | 1 |
| passenger_key: 100 | Partitions 1, 2 and 3 | 3 |

- The first query filters directly on the partition key, allowing SQL server to elimiate the irrelevant partitions and access only partition 2.
- The second query filters on a non-partition column, SQL server cannot determine which date partition contains the matching records and therefore access all three partitions using the selected index.
- An index hint was used to ensure both queries accessed the same partitioned clustered index.
- Actual execution plans.
- Query 1: With Partition Elimiation.
- Query 2: Without Partition Elimination.

-------------------------------------------------------------------------------------------
Question 7:
### Medallion Layer Classification

| Table Name | Medallion Layer | Reason |
|---|---|---|
| dbo.bronze_bookings | BRONZE | Contains raw booking data ingested from the source without any transformations. |
| dbo.bronze_passengers | BRONZE | Contains raw passenger data ingested from the source without any transformations. |
| dbo.bronze_flights | BRONZE | Contains raw flight data ingested from the source without any transformations. |
| dbo.bronze_airports | BRONZE | Contains raw airport data ingested from the source without any transformations. |
| dbo.bronze_aircraft | BRONZE | Contains raw aircraft data ingested from the source without any transformations. |
| dbo.stg_passenger_updates | BRONZE | Contains raw passenger update data without any transformations. It serves as input for the SCD Type 2 process. |
| dw.DimPassenger | GOLD | Contains transformed passenger data with surrogate keys, designed to support analytical queries through the fact table. |
| dw.DimFlight | GOLD | Contains transformed flight data with surrogate keys, designed to support analytical queries through the fact table. |
| dw.DimAirport | GOLD | Contains transformed airport data with surrogate keys, designed to support analytical queries through the fact table. |
| dw.DimAircraft | GOLD | Contains transformed aircraft data with surrogate keys, designed to support analytical queries through the fact table. |
| dw.DimDate | GOLD | Contains booking, travel and flight dates with surrogate keys, designed to support date-based analysis. |
| dw.DimCity | GOLD | Contains transformed city data with surrogate keys, designed to support the geographical hierarchy. |
| dw.DimCountry | GOLD | Contains transformed country data with surrogate keys, designed to support the geographical hierarchy. |
| dw.DimPassenger_SCD2 | GOLD | Contains transformed passenger data with surrogate keys, designed to support historical passenger analysis through the fact table. |
| dw.FactTicketSales | GOLD | Contains business measures and dimension surrogate keys, enabling analytical reporting on ticket sales, revenue and miles earned. |

**Note:** No dedicated Silver layer is implemented in this pipeline. Data quality checks and necessary transformations are performed during the Bronze-to-Gold ETL process without materializing intermediate tables.

--------------------------------------------------------------------------------------------------------------------------------
DATA CONTRACT
--------------------------------------------------------------------------------------------------------------------------------
| Column Name | Data Type | Nullable | Description | Allowed Values |
|---|---|---|---|---|
| booking_id | INT | No | Unique booking identifier | — |
| passenger_id | INT | No | Passenger identifier | — |
| flight_id | INT | No | Flight identifier | — |
| booking_date | DATE | No | Date on which the ticket was booked | — |
| travel_date | DATE | No | Scheduled date of travel | — |
| fare_class | NVARCHAR(50) | No | Travel fare class | Economy, Premium Economy, Business, First |
| fare_amount | DECIMAL(18,10) | No | Base fare in INR | — |
| tax_amount | DECIMAL(18,10) | No | Taxes and fees in INR | — |
| booking_status | NVARCHAR(50) | No | Current status of the booking | Confirmed, Cancelled |
| miles_earned | INT | No | Loyalty miles credited | — |

-----------------------------------------------------------------------------------------------------------------

| SLA Parameter | Requirement |
|---|---|
| Delivery Frequency | Daily |
| Delivery Deadline | 8:00 AM IST |
| Maximum Freshness Interval | 24 hours |
| SLA Violation | The daily delivery deadline is missed or the feed has not been refreshed for more than 24 hours. |


------
OWNER
------
- Business Owner - Booking Operations Team
- Technical Owner - Data Engineering Team

---------------
BREAKING CHANGE
---------------
- Introducing NULL values and duplicates into the booking id - this violates the FACT table's NOT NULL and UNIQUE constraints respectively.

-------------------
NON-BREAKING CHANGE
-------------------
- Introducing a nullable column such as booking_duration (duration between the latest booking and current date)








