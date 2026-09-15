/* =============================================================================
   The Daily Grind — Financial Analysis 2023-2025
   File:     00_schema.sql
   Purpose:  Table definitions for the five source tables.
   Built in: PostgreSQL 18.6, using pgAdmin 4 (v9.17)
   ============================================================================= */


CREATE TABLE customers (
    CustomerID          text PRIMARY KEY,
    Region              text NOT NULL,
    CustomerJoinDate    date NOT NULL
);


CREATE TABLE products (
    ProductID           integer PRIMARY KEY,
    ProductName         text NOT NULL,
    ProductCategory     text NOT NULL,
    Price               numeric(10,2) NOT NULL,
    Base_Cost           numeric(10,2) NOT NULL
);


CREATE TABLE orders_2023 (
    OrderID             text PRIMARY KEY,
    CustomerID          text REFERENCES customers(CustomerID),
    ProductID           integer NOT NULL REFERENCES products(ProductID),
    OrderDate           date NOT NULL,
    Quantity            integer NOT NULL,
    Revenue             numeric(10,2),
    COGS                numeric(10,2) NOT NULL,
    SourceFile          text NOT NULL
);


CREATE TABLE orders_2024 (
    OrderID             text PRIMARY KEY,
    CustomerID          text REFERENCES customers(CustomerID),
    ProductID           integer NOT NULL REFERENCES products(ProductID),
    OrderDate           date NOT NULL,
    Quantity            integer NOT NULL,
    Revenue             numeric(10,2),
    COGS                numeric(10,2) NOT NULL,
    SourceFile          text NOT NULL
);


    -- OrderDate is text, not date: the 2025 extract ships dates as M/D/YYYY,
    -- which are parsed with TO_DATE in Step 3 of 01_clean_orders.sql.
CREATE TABLE orders_2025 (
    OrderID             text PRIMARY KEY,
    CustomerID          text REFERENCES customers(CustomerID),
    ProductID           integer NOT NULL REFERENCES products(ProductID),
    OrderDate           text NOT NULL,
    Quantity            integer NOT NULL,
    Revenue             numeric(10,2),
    COGS                numeric(10,2) NOT NULL,
    SourceFile          text NOT NULL
);
