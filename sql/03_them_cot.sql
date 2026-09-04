CREATE VIEW vw_sales AS
SELECT 
    *,
    YEAR(order_date) AS order_year,
    MONTH(order_date) AS order_month,
    DATEPART(QUARTER, order_date) AS order_quarter,
    CASE WHEN sales <> 0 THEN profit / sales ELSE NULL END AS profit_margin
FROM superstore;