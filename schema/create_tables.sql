-- ============================================================
-- Global E-Commerce Database Schema
-- PostgreSQL 14+
-- ============================================================

-- Drop tables in reverse dependency order if they exist
DROP TABLE IF EXISTS risk_management CASCADE;
DROP TABLE IF EXISTS user_behavior CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS marketing CASCADE;
DROP TABLE IF EXISTS shipping CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- ============================================================
-- CUSTOMERS
-- ============================================================
CREATE TABLE customers (
    customer_id             VARCHAR(20)     PRIMARY KEY,
    customer_name           VARCHAR(100),
    email                   VARCHAR(100),
    gender                  VARCHAR(10),
    age                     INTEGER,
    country                 VARCHAR(100),
    city                    VARCHAR(100),
    customer_segment        VARCHAR(30),
    loyalty_score           NUMERIC,
    account_creation_date   DATE
);

-- ============================================================
-- PRODUCTS
-- ============================================================
CREATE TABLE products (
    product_id              VARCHAR(20)     PRIMARY KEY,
    product_name            VARCHAR(255),
    category                VARCHAR(100),
    brand                   VARCHAR(100),
    product_rating_avg      NUMERIC,
    stock_quantity          INTEGER
);

-- ============================================================
-- ORDERS
-- ============================================================
CREATE TABLE orders (
    order_id                VARCHAR(20)     PRIMARY KEY,
    customer_id             VARCHAR(20)     REFERENCES customers(customer_id),
    order_year              INTEGER,
    order_month             INTEGER,
    order_day               INTEGER,
    order_status            VARCHAR(30),
    return_reason           VARCHAR(100)
);

-- ============================================================
-- ORDER ITEMS
-- ============================================================
CREATE TABLE order_items (
    order_id                VARCHAR(20)     REFERENCES orders(order_id),
    product_id              VARCHAR(20)     REFERENCES products(product_id),
    quantity                INTEGER,
    unit_price_usd          NUMERIC,
    discount_percent        NUMERIC,
    discount_amount_usd     NUMERIC,
    total_price_usd         NUMERIC,
    cost_usd                NUMERIC,
    profit_usd              NUMERIC,
    tax_usd                 NUMERIC,
    profit_margin_percent   NUMERIC,
    PRIMARY KEY (order_id, product_id)
);

-- ============================================================
-- PAYMENTS
-- ============================================================
CREATE TABLE payments (
    order_id                VARCHAR(20)     PRIMARY KEY
                                            REFERENCES orders(order_id),
    payment_method          VARCHAR(50),
    payment_status          VARCHAR(30),
    installment             VARCHAR(10),
    currency                VARCHAR(10)
);

-- ============================================================
-- SHIPPING
-- ============================================================
CREATE TABLE shipping (
    order_id                VARCHAR(20)     PRIMARY KEY
                                            REFERENCES orders(order_id),
    shipping_method         VARCHAR(50),
    shipping_cost_usd       NUMERIC,
    delivery_days           INTEGER,
    warehouse               VARCHAR(100),
    shipping_status         VARCHAR(30)
);

-- ============================================================
-- REVIEWS
-- ============================================================
CREATE TABLE reviews (
    order_id                VARCHAR(20)     REFERENCES orders(order_id),
    product_id              VARCHAR(20)     REFERENCES products(product_id),
    rating                  INTEGER,
    sentiment               VARCHAR(20),
    customer_feedback       TEXT,
    PRIMARY KEY (order_id, product_id)
);

-- ============================================================
-- MARKETING
-- ============================================================
CREATE TABLE marketing (
    order_id                VARCHAR(20)     PRIMARY KEY
                                            REFERENCES orders(order_id),
    coupon_used             VARCHAR(5),
    coupon_code             VARCHAR(50),
    campaign_source         VARCHAR(50),
    traffic_source          VARCHAR(50)
);

-- ============================================================
-- USER BEHAVIOR
-- ============================================================
CREATE TABLE user_behavior (
    order_id                    VARCHAR(20)     PRIMARY KEY
                                                REFERENCES orders(order_id),
    device_type                 VARCHAR(20),
    session_duration_minutes    NUMERIC,
    pages_visited               INTEGER,
    abandoned_cart_before       VARCHAR(5)
);

-- ============================================================
-- RISK MANAGEMENT
-- ============================================================
CREATE TABLE risk_management (
    order_id                VARCHAR(20)     PRIMARY KEY
                                            REFERENCES orders(order_id),
    fraud_risk_score        NUMERIC(5,2),
    order_priority          VARCHAR(20),
    support_tickets         INTEGER
);

-- ============================================================
-- INDEXES (for query performance)
-- ============================================================
CREATE INDEX idx_orders_customer_id     ON orders(customer_id);
CREATE INDEX idx_orders_year_month      ON orders(order_year, order_month);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_customers_segment      ON customers(customer_segment);
CREATE INDEX idx_customers_country      ON customers(country);
CREATE INDEX idx_payments_status        ON payments(payment_status);
CREATE INDEX idx_risk_fraud_score       ON risk_management(fraud_risk_score);
