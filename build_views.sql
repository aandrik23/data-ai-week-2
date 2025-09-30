SET search_path TO cosmofone;

-- CUSTOMER SUMMARY
CREATE OR REPLACE VIEW customer_summary AS
SELECT
  c.customer_id,
  c.name,
  c.region,
  c.age,
  c.plan_type,
  c.signup_date,
  COALESCE(SUM(u.call_minutes),0)  AS total_call_minutes,
  COALESCE(SUM(u.data_usage_gb),0) AS total_data_gb,
  COALESCE(SUM(u.num_sms),0)       AS total_sms,
  COALESCE(SUM(b.amount),0)        AS total_revenue,
  COUNT(DISTINCT s.ticket_id)      AS support_tickets
FROM dim_customer c
LEFT JOIN fact_usage   u ON u.customer_id = c.customer_id
LEFT JOIN fact_billing b ON b.customer_id = c.customer_id
LEFT JOIN fact_support s ON s.customer_id = c.customer_id
GROUP BY c.customer_id, c.name, c.region, c.age, c.plan_type, c.signup_date;

-- MONTHLY KPIS
CREATE OR REPLACE VIEW monthly_kpis AS
SELECT
  d.yyyymm,
  SUM(u.call_minutes)  AS total_call_minutes,
  SUM(u.data_usage_gb) AS total_data_gb,
  SUM(u.num_sms)       AS total_sms,
  SUM(b.amount)        AS total_revenue,
  COUNT(DISTINCT u.customer_id) AS active_customers
FROM dim_date d
LEFT JOIN fact_usage   u ON u.date_key = d.date_key
LEFT JOIN fact_billing b ON b.date_key = d.date_key
GROUP BY d.yyyymm
ORDER BY d.yyyymm;

-- CHURN RISK INDICATORS
CREATE OR REPLACE VIEW churn_risk_indicators AS
SELECT
  c.customer_id,
  c.name,
  c.region,
  c.plan_type,
  COALESCE(SUM(CASE WHEN b.paid = FALSE THEN 1 ELSE 0 END),0) AS unpaid_invoices,
  COALESCE(COUNT(s.ticket_id),0) AS total_tickets,
  CASE 
    WHEN COALESCE(SUM(CASE WHEN b.paid = FALSE THEN 1 ELSE 0 END),0) > 0 
         OR COALESCE(COUNT(s.ticket_id),0) >= 3
    THEN TRUE ELSE FALSE END AS is_churn_risk
FROM dim_customer c
LEFT JOIN fact_billing b ON b.customer_id = c.customer_id
LEFT JOIN fact_support s ON s.customer_id = c.customer_id
GROUP BY c.customer_id, c.name, c.region, c.plan_type;