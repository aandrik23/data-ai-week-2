SET search_path TO cosmofone;

-- Average resolution time per region/plan/month + number of tickets
CREATE OR REPLACE VIEW support_metrics AS
SELECT
  c.region,
  c.plan_type,
  d.yyyymm,
  AVG(s.resolution_time_hrs)::numeric(12,2) AS avg_resolution_hrs,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY s.resolution_time_hrs) AS median_resolution_hrs,
  COUNT(*) AS ticket_count
FROM fact_support s
JOIN dim_customer c   ON c.customer_id = s.customer_id
LEFT JOIN dim_date d  ON d.date_key = s.date_key
GROUP BY c.region, c.plan_type, d.yyyymm
ORDER BY d.yyyymm, c.region, c.plan_type;