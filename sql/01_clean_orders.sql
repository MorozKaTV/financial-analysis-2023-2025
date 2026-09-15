/* =============================================================================
   The Daily Grind — Financial Analysis 2023-2025
   File:     01_clean_orders.sql
   Purpose:  Combine three yearly order extracts into one clean, analysis-ready
             table and hand it to Power BI.
   Dialect:  PostgreSQL 18.6
   Requires: the five tables defined in 00_schema.sql, loaded from the source CSVs.
   ---------------------------------------------------------------------------
   WHAT IS IN THIS FILE

   Most of this file is commented out. Those greyed-out blocks are the checks
   used to audit the raw data, kept on purpose as a record of what was inspected
   and what turned up. Each one is followed by the finding it produced.

   Only two statements actually run:
       Step 3  — builds "orders_combined", a combined view of all three years.
       Step 10 — produces the final cleaned result, 4432 rows.

   ============================================================================= */


    -- Step 1: Check for duplicate IDs in the customers and products tables
/*
    SELECT
        COUNT(CustomerID) AS TotalCustomerIDs,
        COUNT(DISTINCT CustomerID) AS UniqueCustomerIDs
    FROM customers;

    SELECT
        COUNT(ProductID) AS TotalProductIDs,
        COUNT(DISTINCT ProductID) AS UniqueProductIDs
    FROM products;
*/
    -- There are no duplicate IDs in the customers table (200) or the products table (50)


    -- Step 2: Check that customers.Region and products.ProductCategory contain
    -- only valid category names
/*
    SELECT
        DISTINCT Region
    FROM customers;

    SELECT
        DISTINCT ProductCategory
    FROM products;
*/
    -- Region returns exactly 4 expected values: East, North, South, West
    -- ProductCategory returns exactly 5 expected values: Accessories, Consumables,
    -- Grinders & Brewers, Merchandise, Subscriptions
    -- There are no misspelt or unexpected category names in either column


    -- Step 3: Combine the orders from 2023, 2024 and 2025 into a single table
    --
    -- This is a view rather than a CTE so that the audit checks in Steps 4-8 can
    -- be run on their own, without pasting the union in front of each one.

CREATE OR REPLACE VIEW orders_combined AS
    SELECT
        OrderID,
        CustomerID,
        ProductID,
        OrderDate,
        Quantity,
        Revenue,
        COGS,
        SourceFile
    FROM orders_2023

    UNION ALL

    SELECT
        OrderID,
        CustomerID,
        ProductID,
        OrderDate,
        Quantity,
        Revenue,
        COGS,
        SourceFile
    FROM orders_2024

    UNION ALL

    SELECT
        OrderID,
        CustomerID,
        ProductID,
        TO_DATE(OrderDate, 'FMMM/FMDD/YYYY') AS OrderDate,
        Quantity,
        Revenue,
        COGS,
        SourceFile
    FROM orders_2025;
    -- There are 4456 rows overall (1603 + 1570 + 1283)
    -- Schema drift: 2023 and 2024 ship OrderDate as ISO YYYY-MM-DD, but 2025 ships
    -- it as M/D/YYYY (e.g. 1/13/2025), so that column is landed as text and
    -- parsed here. FM makes the zero-padding optional, so both 1/1/2025
    -- and 1/13/2025 parse. This depends on orders_2025.OrderDate being text — if it
    -- is already a date column, TO_DATE fails with
    -- "function to_date(date, unknown) does not exist"
    -- and the cast should simply be dropped.


    -- Step 4: Check for duplicate OrderIDs in the combined orders table
/*
    SELECT
        COUNT(*) AS TotalOrders,
        COUNT(DISTINCT OrderID) AS UniqueOrders
    FROM orders_combined;
*/
    -- Both counts return 4456, so there are no duplicate OrderIDs


    -- Step 5: Identify how many rows have null values in any of the columns in the
    -- combined orders table
/*
    SELECT
        COUNT(*) AS TotalRowsWithNulls
    FROM orders_combined
    WHERE OrderID IS NULL
        OR CustomerID IS NULL
        OR ProductID IS NULL
        OR OrderDate IS NULL
        OR Quantity IS NULL
        OR Revenue IS NULL
        OR COGS IS NULL;

        -- There are 65 rows with null values in total
        -- Next, identify which columns those nulls are in, and how many per column.

    SELECT
        SUM(CASE WHEN OrderID    IS NULL THEN 1 ELSE 0 END) AS NullOrderID,
        SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS NullCustomerID,
        SUM(CASE WHEN ProductID  IS NULL THEN 1 ELSE 0 END) AS NullProductID,
        SUM(CASE WHEN OrderDate  IS NULL THEN 1 ELSE 0 END) AS NullOrderDate,
        SUM(CASE WHEN Quantity   IS NULL THEN 1 ELSE 0 END) AS NullQuantity,
        SUM(CASE WHEN Revenue    IS NULL THEN 1 ELSE 0 END) AS NullRevenue,
        SUM(CASE WHEN COGS       IS NULL THEN 1 ELSE 0 END) AS NullCOGS
    FROM orders_combined;
*/
    -- The nulls sit in exactly two columns: CustomerID has 24 and Revenue has 41.
    -- Every other column is complete. 
    -- I will use INNER JOIN to remove the rows with a null CustomerID, so the row
    -- count should drop from 4456 to 4432. An order that cannot be attributed to a
    -- customer is useless for the regional analysis the brief asks for.
    -- I will recalculate the 41 null Revenues using the COALESCE function with the
    -- Price and Quantity columns.


    -- Step 6: Find quartiles and then outliers based on the Quantity column using
    -- the IQR method
/*
    WITH quartiles AS (
        SELECT
            PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Quantity) AS Q1,
            PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Quantity) AS Q3
        FROM orders_combined
    ),
    outliers AS (
        SELECT
            o.*,
            q.Q1,
            q.Q3,
            (q.Q3 - q.Q1) AS IQR
        FROM orders_combined AS o
            CROSS JOIN quartiles AS q
    )
    SELECT
        *
    FROM outliers
    WHERE Quantity < (Q1 - 1.5 * IQR)
        OR Quantity > (Q3 + 1.5 * IQR);

    SELECT
        MIN(Quantity) AS MinQuantity,
        MAX(Quantity) AS MaxQuantity,
        AVG(Quantity) AS AvgQuantity,
        STDDEV(Quantity) AS StdDevQuantity
    FROM orders_combined;
*/
    -- Q1 = 2 and Q3 = 3, so the IQR fences fall at 0.5 and 4.5 and the query
    -- returns no rows: there are no outliers in the Quantity column.
    -- In this dataset MIN = 1, MAX = 4, AVG = 2.49 and STDDEV = 1.11.



    -- Step 7: Check for negative or zero values in the Revenue and COGS columns
/*
    SELECT
        COUNT(*) AS NegativeOrZeroRows
    FROM orders_combined
    WHERE Revenue <= 0
        OR COGS <= 0;

        -- Note: Revenue is still null on 41 rows at this point, and NULL <= 0
        -- evaluates to NULL, so those rows are not counted here. They are already
        -- accounted for in Step 5 and are imputed in Step 10.

        -- A second, related check: gross margin should never be zero or negative,
        -- even where the individual columns are positive.
    SELECT
        COUNT(*) AS NonPositiveMarginRows
    FROM orders_combined
    WHERE Revenue - COGS <= 0;
*/
    -- There are 0 rows with negative or zero values in the Revenue and COGS columns
    -- (the minimums are 15.23 and 5.39 respectively).
    -- There are also 0 rows with a zero or negative gross margin.


    -- Step 8: Check for correct date ranges in the OrderDate column in the combined
    -- orders table
/*
    SELECT
        MIN(OrderDate) AS FirstOrderDate,
        MAX(OrderDate) AS LastOrderDate
    FROM orders_combined;
*/
    -- The OrderDate range in the combined orders table is correct: 2023-01-02 to
    -- 2025-11-30. 


    -- Step 9: Count the number of rows after INNER JOINing the combined orders table
    -- with the customers and products tables, to remove rows with a null CustomerID
/*
    SELECT
        COUNT(*) AS TotalRowsAfterJoin
    FROM orders_combined AS o
        INNER JOIN customers AS c ON o.CustomerID = c.CustomerID
        INNER JOIN products AS p ON o.ProductID = p.ProductID;
*/
    -- The count of rows is 4432, which is the expected 4456 - 24


    -- Step 10: INNER JOIN orders_combined with the customers and products tables,
    -- and recalculate Revenue where it is null.
    -- Assumption behind the COALESCE: for the 41 rows with a missing Revenue, list
    -- price multiplied by quantity is an acceptable estimate. This holds only
    -- because the dataset records no discounts, returns or currency differences.
    -- This is the query that is loaded into Power BI.
    SELECT
        o.OrderID,
        c.Region,
        o.ProductID,
        o.OrderDate,
        DATE_TRUNC('week', o.OrderDate)::date AS WeekDate,
        c.CustomerJoinDate,
        o.Quantity,
        COALESCE(o.Revenue, p.Price * o.Quantity) AS Revenue,
        o.COGS,
        p.ProductName,
        p.ProductCategory,
        p.Price,
        p.Base_Cost AS BaseCost
    FROM orders_combined AS o
        INNER JOIN customers AS c ON o.CustomerID = c.CustomerID
        INNER JOIN products AS p ON o.ProductID = p.ProductID;

