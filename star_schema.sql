-- setup
CREATE SCHEMA IF NOT EXISTS cosmofone;
SET search_path TO cosmofone;

-- drop tables if they exist
DROP TABLE IF EXISTS fact_support CASCADE;
DROP TABLE IF EXISTS fact_billing CASCADE;
DROP TABLE IF EXISTS fact_usage CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;
DROP TABLE IF EXISTS dim_customer CASCADE;

-- create dimension tables
-- one row per customer use stg_customers
CREATE TABLE dim_customer AS
SELECT DISTINCT
  TRIM(customer_id)::text        AS customer_id,
  NULLIF(TRIM(name), '')::text   AS name,
  NULLIF(TRIM(region), '')::text AS region,
  CASE WHEN TRIM(age::text) ~ '^\d+$' THEN TRIM(age::text)::int ELSE NULL END AS age,
  NULLIF(TRIM(plan_type), '')::text AS plan_type,
  NULLIF(TRIM(signup_date), '')::date AS signup_date
FROM stg_customers;

ALTER TABLE dim_customer
  ADD CONSTRAINT pk_dim_customer PRIMARY KEY (customer_id);

-- one row per date use stg_billing and stg_support and stg_usage
CREATE TABLE dim_date AS
WITH bounds AS (
  SELECT MIN(d)::date AS min_d, MAX(d)::date AS max_d
  FROM (
    SELECT NULLIF(TRIM(usage_month), '')::date AS d FROM stg_usage
    UNION ALL
    SELECT NULLIF(TRIM(invoice_date), '')::date AS d FROM stg_billing
    UNION ALL
    SELECT NULLIF(TRIM(ticket_date), '')::date  AS d FROM stg_support_tickets
  ) x
)
SELECT
  d::date AS date_key,
  EXTRACT(YEAR FROM d)::int  AS year,
  EXTRACT(MONTH FROM d)::int AS month,
  EXTRACT(DAY FROM d)::int   AS day,
  TO_CHAR(d, 'Mon')          AS month_name,
  (EXTRACT(YEAR FROM d)::int * 100 + EXTRACT(MONTH FROM d)::int) AS yyyymm
FROM (
  SELECT generate_series(min_d, max_d, interval '1 day') AS d
  FROM bounds
) s;

ALTER TABLE dim_date
  ADD CONSTRAINT pk_dim_date PRIMARY KEY (date_key);



-- create fact tables
-- fact usage

CREATE TABLE fact_usage AS
SELECT
  TRIM(u.customer_id)::text             AS customer_id,
  NULLIF(TRIM(u.usage_month), '')::date AS date_key,
  NULLIF(TRIM(u.call_minutes::text), '')::numeric(12,2) AS call_minutes,
  NULLIF(TRIM(u.data_usage_gb::text), '')::numeric(12,2) AS data_usage_gb,
  NULLIF(TRIM(u.num_sms::text), '')::numeric(12,2)       AS num_sms
FROM stg_usage u
WHERE TRIM(u.customer_id) <> ''
  AND u.customer_id IN (SELECT customer_id FROM dim_customer);

ALTER TABLE fact_usage ADD COLUMN usage_id bigserial PRIMARY KEY;

ALTER TABLE fact_usage
  ADD CONSTRAINT fk_usage_customer FOREIGN KEY (customer_id) REFERENCES dim_customer(customer_id),
  ADD CONSTRAINT fk_usage_date FOREIGN KEY (date_key) REFERENCES dim_date(date_key);


--fact billing
CREATE TABLE fact_billing AS
SELECT
  TRIM(b.customer_id)::text AS customer_id,
  NULLIF(TRIM(b.invoice_date), '')::date AS date_key,
  NULLIF(TRIM(b.amount::text), '')::numeric(12,2) AS amount,
  CASE
    WHEN LOWER(TRIM(b.payment_status)) IN ('paid','y','yes','true','t','1') THEN TRUE
    WHEN LOWER(TRIM(b.payment_status)) IN ('unpaid','n','no','false','f','0') THEN FALSE
    ELSE NULL
  END AS paid
FROM stg_billing b
WHERE TRIM(b.customer_id) <> ''
  AND b.customer_id IN (SELECT customer_id FROM dim_customer);

ALTER TABLE fact_billing ADD COLUMN billing_id bigserial PRIMARY KEY;

ALTER TABLE fact_billing
  ADD CONSTRAINT fk_billing_customer FOREIGN KEY (customer_id) REFERENCES dim_customer(customer_id),
  ADD CONSTRAINT fk_billing_date FOREIGN KEY (date_key) REFERENCES dim_date(date_key);



-- fact support
CREATE TABLE fact_support AS
SELECT
  TRIM(s.customer_id)::text AS customer_id,
  NULLIF(TRIM(s.ticket_date), '')::date AS date_key,
  NULLIF(TRIM(s.issue_type), '')::text  AS issue_type,
  NULLIF(TRIM(s.resolution_time_hrs::text), '')::numeric(12,2) AS resolution_time_hrs
FROM stg_support_tickets s
WHERE TRIM(s.customer_id) <> ''
  AND s.customer_id IN (SELECT customer_id FROM dim_customer);

ALTER TABLE fact_support ADD COLUMN ticket_id bigserial PRIMARY KEY;

ALTER TABLE fact_support
  ADD CONSTRAINT fk_support_customer FOREIGN KEY (customer_id) REFERENCES dim_customer(customer_id),
  ADD CONSTRAINT fk_support_date FOREIGN KEY (date_key) REFERENCES dim_date(date_key);
