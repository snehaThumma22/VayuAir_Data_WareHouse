1. Project Overview:
Building an airline ticketing sales data warehouse in SQL Server.

-------------------------------------------------
Vayu Air - Data Modelling & Warehouse Engineering.
--------------------------------------------------
Project Over view:
The project implements an airline ticket sales data warehouse using Microsoft SQL Server as a part of Data Engineering learning assignment.
The project demonstrates dimensional modelling, star and snowflake schemas, ETL loading, Slowly changing dimension Type 2 and fact table partitioning.

Tools & Technologies:
Microsoft SQL Server
SQL Server Management Studio(SSMS)
T-SQl
GitHub

Prerequisites:
1. Create the VayuAir Database.
2. Import the bronze source tables and stg_passenger_updates using the provided the assigment dataset.
3. Ensure the dw schema  does not already exist before the initial execution.

Execution Order:
Execute the .sql scripts in the following order:
Q2_Star_Schema.sql
Q3_ETL_DimDate.sql
Q4_Snowflake_Geography.sql
Q5_SCD_Type2.sql
Q6_Partition.sql

The scripts are designed for an initial warehouse build in a fresh DB containing the source tables.

-------------------------------------------------------------------------------------------

Question 1:
Grain: One row in sales fact table represents one "booking" asssociated with a flight.

Dimension Keys:
Source business key:                        Dimension Key(Surrogate key)
aircraft_code                               aircraft_code_key
origin_airport_code                         origin_airport_code_key
dest_airport_code                           dest_airport_code_key
passenger_id                                passenger_key
flight_id                                   flight_key
flight_date                                 flight_date_key
booking_date                                booking_date_key
travel_date                                 travel_date_key


Degenerate Dimension: Retained in the Fact table without seperate dimension table.
booking id 

Descriptive Dimension Attributes:
fare_class
booking_status
flight_number

Additive Measures:
fare_amount
tax_amount
miles_earned

Additive measures: fare_amount, tax_amount, miles_earned
Non-additive measures: fare_amount per miles_earned ( a calculated ratio) - Can not be further aggregated into a meaningful value.

-------------------------------------------------------------------------------------------
Question 2: 
Created the dw schema to organise the data warehouse tables.
The star schema contains one central fact table and five dimension tables.
Dimension table                     Primary key
DimAircraft                         aircraft_key
DimAirport                          airport_key
DimFlight                           flight_key
DimPassenger                        passenger_key
DimDate                             date_key

Fact Table: dw.FactTicketSales 
- Surrogate keys are used to identify the dimension records.
- Business keys are retained in dimension tables.
- 8 FK relationships connect Fact table to the 5 Dimension tables.
- booking_id is retained in Fact table as a degenerate dimension.
- Only additive measures are stored in the Facts table.

DimDate and DimAirport are role playing dimensions as they are referenced many times by the fact table.

-------------------------------------------------------------------------------------------
Question 3:
Load the dimension and fact tables from the bronze source tables.
Surrogate keys were generated for the dimensions  and business key joins were used to resolve the corresponding surrogate keys while populating FactTicketSales.
DimDate was populated using distinct booking, travel, flight date keys in integer YYYYMMDD format.

Results:
Table                                               Record count
DimPassenger                                        1500
DimFlight                                           2000
DimAirport                                          24
DimAircraft                                         10
DimDate                                             515
FactTicketSales                                     40,000
bronze_bookings                                     40,000

Validation:
Fact count matches the bronze booking count.
All 8 dimension Fks are populated.
Every fact record resolves to its corresponding dimension records.

-------------------------------------------------------------------------------------------
Question 4:
Normalized airport dimension into 3 linked tables.
DimAirport -> DimCity -> DimCountry
DimAirport references DimCity through city_key
DimCity references DimCountry through country_key

Advantages: Helps structure data, reduces data duplication by seperating airport, city, country into tables like DimAiport, DimCity, DimCountry.
Trade off: Requires additional joins increasing query complexity and potentially impacting the performance of the query.

Validation:
All 24 airport records resolve to their corresponding cities and countries through FK relationships.

-------------------------------------------------------------------------------------------
Question 5:
Create dw.DimPassenger_SCD2 to maintain historical changes in passenger attributes.
The followings columns were introduced:
effective_from
effective_to
is_current

Implementation:
1. Identified existing passengers whose frequent_flyer_tier or home_airport_code changed.
2. Stored the changed records in a temporary table.
3. Expired the existing versions by setting is_current to 0 and updating the effective_to.
4. Inserted new current versions with new surrogate keys.
5. Inserted brand new passengers as single current records.

Transactions were used to maintain data consistency during expire and insert process.
Original passenger surrogate keys were preserved to maintain historical fact table relationships.

Results:
Description                                     Record count
Original passengers                             1,500
Changed passengers                              200
Brand New passengers                            50
Historical records                              200
Current records                                 1550
Total SCD2 records                              1750

Validation:
1. Changed passengers have two versions.
2. Brand new passengers have one version.
3. Each passenger has exactly one current record.
4. Historical effective_to matches the new version's effective_from.
5. All 40,000 fact tables are preserved.

Assumption:
Since the staging table does not provide the signup date for the new passengers, the processing date is used as their sign date.

-------------------------------------------------------------------------------------------
Question 6:
Partitioned FactTicketSales using booking_date_key.
Created a RANGE RIGHT partition function and a partition scheme with yearly boundaries.
Parition Structure
Parition                        Booking date range
Partition 1                     Before 2025
Partition 2                     2025 to 2026
Partition 3                     2026 and later

Created  a partitioned clustered index on booking_date_key and booking_id to place the fact table on the partition scheme.

Parition elimiation results
Query filter                    Partitions accessed                 Actual partition count
booking_date_key: Year 2025     Partition 2                         1
passengeer_key: 100             Partitions 1, 2 & 3                 3

The first query filters directly on the partition key, allowing SQL server to elimiate the irrelevant partitions and access only partition 2.
The second query filters on a non-partition column, SQL server cannot determine which date partition contains the matching records and therefore access all three partitions using the selected index.
An index hint was used to ensure both queries accessed the same partitioned clustered index.
Actual execution plans.
Query 1: With Partition Elimiation.
Query 2: Without Partition Elimination.

-------------------------------------------------------------------------------------------
Question 7:
Table Name                  Medallion Layer            Reason
dbo.bronze_booking          BRONZE                     Contains raw booking data ingested
                                                       from the source without any transformations.
dbo.bronze_passengers       BRONZE                     Contains raw booking data ingested
                                                       from the source without any transformations.
dbo.bronze_flights          BRONZE                     Contains raw booking data ingested
                                                       from the source without any transformations.
dbo.bronze_airports         BRONZE                     Contains raw booking data ingested
                                                       from the source without any transformations.
dbo.bronze_aircraft         BRONZE                     Contains raw booking data ingested
                                                       from the source without any transformations.
dbo.stg_passenger_updates   BRONZE                     It contains raw passenger data, no cleaning or
                                                       transformations are performed within the table.
                                                       It serves as input for SCD Type 2 process.
dw.DimPassenger             GOLD                       Transformed passenger data with surrogate keys,
                                                       designed to support analytical queries through fact table.
dw.DimFlight                GOLD                       Transformed flight data with surrogate keys,
                                                       designed to support analytical queries through fact table.
dw.DimAirport               GOLD                       Transformed airport data with surrogate keys,
                                                       designed to support analytical queries through fact table.
dw.DimAircraft              GOLD                       Transformed aircraft data with surrogate keys,
                                                       designed to support analytical queries through fact table.
dw.DimDate                  GOLD                       Transformed booking, travel, flight dates data with surrogate keys,
                                                       designed to support date analysis through fact table.
dw.DimCity                  GOLD                       Transformed city data with surrogate keys,
                                                       designed to support geographical hierachy.
dw.DimCountry               GOLD                       Transformed country data with surrogate keys,
                                                       designed to support geographical hierachy.
dw.DimPassenger_SCD2        GOLD                       Transformed passenger data with surrogate keys,
                                                       designed to support historical analysis of the passengers
                                                       through fact table.   
dw.FactTicketSales          GOLD                       Contains business measures and dimensions surrogate keys, 
                                                       making analytical reporting on ticket sales, revenue and miles earned.

NOTE: No dedicated Silver layer is implemented in this pipeline. Data quality checks and necessary transformations are performed during the Bronze-to-Gold ETL process without materializing intermediate tables.

--------------------------------------------------------------------------------------------------------------------------------
DATA CONTRACT
--------------------------------------------------------------------------------------------------------------------------------
Column name             Data type        Nullable     Description                      Allowed Values    
booking_id              INT              No           Unique booking identifier
passenger_id            INT              No           Passenger identifier
flight_id               INT              No           Flight identifier
booking_date            DATE             No           When the ticket was booked
travel_date             DATE             No           The flight date travelled
fare_class              NVARCHAR(50)     No                                             Economy/Premium Economy/Business/First
fare_amount             DECIMAL(18,10)   No           Base Fare in INR
tax_amount              DECIMAL(18,10)   No           Taxes & Fees in INR
booking_status          NVARCHAR(50)     No                                             Confirmed/Cancelled
miles_earned            INT              No           Loyalty miled credited

-------------------------------------------------------
SLA Parameters                              Requirement
-------------------------------------------------------
Delivery frequency                          Daily
Delivery deadline                           8.00 AM IST
Maximum freshness interval                  24 hours
SLA violation                               Daily delivery deadline is missed or the feed has not been refreshed
                                            for more than 24 hours.
------
OWNER
------
Business Owner - Booking Operations Team
Technical Owner - Data Engineering Team

---------------
BREAKING CHANGE
---------------
Introducing NULL values and duplicates into the booking id - this violates the FACT table's NOT NULL and UNIQUE constraints respectively.

-------------------
NON-BREAKING CHANGE
-------------------
Introducing a nullable column such as booking_duration (duration between the latest booking and current date)








