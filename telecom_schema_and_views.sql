
-- Schema and Table Creation

DROP TABLE IF EXISTS support_tickets, billing, usage, customers CASCADE;

CREATE TABLE customers (
    customer_id VARCHAR PRIMARY KEY,
    name VARCHAR,
    region VARCHAR,
    age INT,
    plan_type VARCHAR,
    signup_date DATE
);

CREATE TABLE usage (
    customer_id VARCHAR REFERENCES customers(customer_id),
    usage_month DATE,
    call_minutes NUMERIC,
    data_usage_gb NUMERIC,
    num_sms INT
);

CREATE TABLE billing (
    customer_id VARCHAR REFERENCES customers(customer_id),
    invoice_date DATE,
    amount NUMERIC,
    payment_status VARCHAR
);

CREATE TABLE support_tickets (
    customer_id VARCHAR REFERENCES customers(customer_id),
    ticket_date DATE,
    issue_type VARCHAR,
    resolution_time_hrs INT
);

-- View: Customer Summary
CREATE OR REPLACE VIEW customer_summary AS
SELECT
    c.customer_id,
    c.name,
    c.region,
    c.plan_type,
    AVG(u.call_minutes) AS avg_call_minutes,
    AVG(u.data_usage_gb) AS avg_data_usage_gb,
    COUNT(b.invoice_date) AS bills_count,
    SUM(b.amount) AS total_billed,
    SUM(CASE WHEN LOWER(b.payment_status) = 'unpaid' THEN 1 ELSE 0 END) AS unpaid_bills,
    COUNT(s.ticket_date) AS support_tickets
FROM customers c
LEFT JOIN usage u ON c.customer_id = u.customer_id
LEFT JOIN billing b ON c.customer_id = b.customer_id
LEFT JOIN support_tickets s ON c.customer_id = s.customer_id
GROUP BY c.customer_id, c.name, c.region, c.plan_type;

-- View: Monthly KPIs
CREATE OR REPLACE VIEW monthly_kpis AS
SELECT
    DATE_TRUNC('month', u.usage_month) AS month,
    COUNT(DISTINCT u.customer_id) AS active_users,
    AVG(u.data_usage_gb) AS avg_data_usage,
    SUM(b.amount) AS total_revenue
FROM usage u
JOIN billing b ON u.customer_id = b.customer_id AND DATE_TRUNC('month', u.usage_month) = DATE_TRUNC('month', b.invoice_date)
GROUP BY month
ORDER BY month;

-- View: Churn Risk Indicators
CREATE OR REPLACE VIEW churn_risk_indicators AS
SELECT
    c.customer_id,
    c.name,
    c.region,
    COUNT(s.ticket_date) AS recent_tickets,
    SUM(CASE WHEN LOWER(b.payment_status) = 'unpaid' THEN 1 ELSE 0 END) AS unpaid_bills
FROM customers c
LEFT JOIN support_tickets s ON c.customer_id = s.customer_id
LEFT JOIN billing b ON c.customer_id = b.customer_id
WHERE s.ticket_date > CURRENT_DATE - INTERVAL '90 days'
GROUP BY c.customer_id, c.name, c.region
HAVING COUNT(s.ticket_date) > 2 OR SUM(CASE WHEN LOWER(b.payment_status) = 'unpaid' THEN 1 ELSE 0 END) > 1;
