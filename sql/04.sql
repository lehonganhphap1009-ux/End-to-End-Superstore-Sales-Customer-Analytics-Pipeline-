-- ========================================================================
-- FILE: 04_analytical_queries.sql
-- MÔ TẢ: Tất cả các truy vấn phân tích cho dự án Superstore
-- CSDL: SuperstoreDB
-- Tác giả: [Your Name]
-- Ngày: 2026-09-02
-- ========================================================================

USE SuperstoreDB;
GO

-- ========================================================================
-- PHẦN 1: TỔNG QUAN
-- ========================================================================

-- 1.1 Tổng doanh số, lợi nhuận, số đơn hàng, số khách hàng, biên lợi nhuận trung bình
SELECT 
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS total_customers,
    SUM(sales) AS total_sales,
    SUM(profit) AS total_profit,
    AVG(profit_margin) AS avg_margin
FROM vw_sales;
GO

-- 1.2 Kiểm tra nhanh số lượng giao dịch theo năm
SELECT order_year, COUNT(*) AS transactions
FROM vw_sales
GROUP BY order_year
ORDER BY order_year;
GO

-- ========================================================================
-- PHẦN 2: PHÂN TÍCH THEO THỜI GIAN
-- ========================================================================

-- 2.1 Doanh số và lợi nhuận theo năm
SELECT 
    order_year,
    SUM(sales) AS sales,
    SUM(profit) AS profit,
    AVG(profit_margin) AS margin
FROM vw_sales
GROUP BY order_year
ORDER BY order_year;
GO

-- 2.2 Doanh số theo quý (trong từng năm)
SELECT 
    order_year,
    order_quarter,
    SUM(sales) AS sales
FROM vw_sales
GROUP BY order_year, order_quarter
ORDER BY order_year, order_quarter;
GO

-- 2.3 Doanh số theo tháng (để vẽ biểu đồ xu hướng)
SELECT 
    order_year,
    order_month,
    SUM(sales) AS monthly_sales
FROM vw_sales
GROUP BY order_year, order_month
ORDER BY order_year, order_month;
GO

-- 2.4 So sánh doanh số cùng kỳ năm trước (YoY)
WITH monthly_sales AS (
    SELECT 
        order_year,
        order_month,
        SUM(sales) AS sales
    FROM vw_sales
    GROUP BY order_year, order_month
)
SELECT 
    order_year,
    order_month,
    sales,
    LAG(sales, 12) OVER (ORDER BY order_year, order_month) AS sales_prev_year
FROM monthly_sales
ORDER BY order_year, order_month;
GO

-- ========================================================================
-- PHẦN 3: PHÂN TÍCH THEO ĐỊA LÝ (REGION)
-- ========================================================================

-- 3.1 Doanh số, lợi nhuận, biên lợi nhuận, số khách hàng theo vùng
SELECT 
    region,
    SUM(sales) AS sales,
    SUM(profit) AS profit,
    AVG(profit_margin) AS margin,
    COUNT(DISTINCT customer_id) AS customers
FROM vw_sales
GROUP BY region
ORDER BY sales DESC;
GO

-- 3.2 Doanh số và lợi nhuận theo bang (State) – top 10
SELECT TOP 10
    state,
    SUM(sales) AS sales,
    SUM(profit) AS profit
FROM vw_sales
GROUP BY state
ORDER BY sales DESC;
GO

-- ========================================================================
-- PHẦN 4: PHÂN TÍCH SẢN PHẨM
-- ========================================================================

-- 4.1 Doanh số, lợi nhuận theo danh mục (Category)
SELECT 
    category,
    SUM(sales) AS sales,
    SUM(profit) AS profit,
    AVG(profit_margin) AS margin
FROM vw_sales
GROUP BY category
ORDER BY sales DESC;
GO

-- 4.2 Top 10 Sub-Category có lợi nhuận cao nhất
SELECT TOP 10
    sub_category,
    SUM(profit) AS profit
FROM vw_sales
GROUP BY sub_category
ORDER BY profit DESC;
GO

-- 4.3 Top 5 Sub-Category thua lỗ nhiều nhất
SELECT TOP 5
    sub_category,
    SUM(profit) AS profit
FROM vw_sales
GROUP BY sub_category
ORDER BY profit ASC;
GO

-- 4.4 Top 10 sản phẩm (product_name) theo doanh số
SELECT TOP 10
    product_name,
    SUM(sales) AS sales
FROM vw_sales
GROUP BY product_name
ORDER BY sales DESC;
GO

-- 4.5 Phân tích ma trận BCG (Star, Cash Cow, Question Mark, Dog)
WITH product_stats AS (
    SELECT 
        sub_category,
        SUM(sales) AS total_sales,
        SUM(profit) AS total_profit
    FROM vw_sales
    GROUP BY sub_category
),
percentiles AS (
    SELECT 
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_sales) OVER () AS median_sales,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_profit) OVER () AS median_profit
    FROM product_stats
)
SELECT DISTINCT
    p.sub_category,
    p.total_sales,
    p.total_profit,
    CASE 
        WHEN p.total_sales > (SELECT TOP 1 median_sales FROM percentiles) 
             AND p.total_profit > (SELECT TOP 1 median_profit FROM percentiles) THEN 'Star'
        WHEN p.total_sales > (SELECT TOP 1 median_sales FROM percentiles) 
             AND p.total_profit <= (SELECT TOP 1 median_profit FROM percentiles) THEN 'Cash Cow'
        WHEN p.total_sales <= (SELECT TOP 1 median_sales FROM percentiles) 
             AND p.total_profit > (SELECT TOP 1 median_profit FROM percentiles) THEN 'Question Mark'
        ELSE 'Dog'
    END AS performance_group
FROM product_stats p
ORDER BY total_sales DESC;
GO

-- 4.6 Phân tích Pareto: 80% doanh số đến từ nhóm Sub-Category nào?
WITH product_rank AS (
    SELECT 
        sub_category,
        SUM(sales) AS sales,
        SUM(SUM(sales)) OVER (ORDER BY SUM(sales) DESC) AS running_total,
        SUM(SUM(sales)) OVER () AS total_sales
    FROM vw_sales
    GROUP BY sub_category
)
SELECT 
    sub_category,
    sales,
    (running_total * 1.0 / total_sales) * 100 AS cumulative_percent
FROM product_rank
WHERE (running_total * 1.0 / total_sales) <= 0.8
ORDER BY sales DESC;
GO

-- ========================================================================
-- PHẦN 5: PHÂN TÍCH KHÁCH HÀNG
-- ========================================================================

-- 5.1 Doanh số, lợi nhuận theo phân khúc (Segment)
SELECT 
    segment,
    SUM(sales) AS sales,
    SUM(profit) AS profit,
    COUNT(DISTINCT customer_id) AS customers,
    AVG(sales) AS avg_order_value
FROM vw_sales
GROUP BY segment;
GO

-- 5.2 Phân tích RFM (Recency, Frequency, Monetary) – 20 khách hàng tốt nhất
WITH rfm_base AS (
    SELECT 
        customer_id,
        MAX(order_date) AS last_order_date,
        COUNT(DISTINCT order_id) AS frequency,
        SUM(sales) AS monetary
    FROM vw_sales
    GROUP BY customer_id
),
rfm_score AS (
    SELECT 
        customer_id,
        NTILE(5) OVER (ORDER BY last_order_date DESC) AS recency_score,
        NTILE(5) OVER (ORDER BY frequency DESC) AS frequency_score,
        NTILE(5) OVER (ORDER BY monetary DESC) AS monetary_score
    FROM rfm_base
)
SELECT TOP 20
    customer_id,
    recency_score,
    frequency_score,
    monetary_score,
    (recency_score + frequency_score + monetary_score) AS rfm_total
FROM rfm_score
ORDER BY rfm_total DESC;
GO

-- 5.3 Top 10 khách hàng theo doanh số
SELECT TOP 10
    customer_name,
    SUM(sales) AS sales
FROM vw_sales
GROUP BY customer_name
ORDER BY sales DESC;
GO

-- ========================================================================
-- PHẦN 6: PHÂN TÍCH CHIẾT KHẤU
-- ========================================================================

-- 6.1 Tác động của chiết khấu đến lợi nhuận trung bình
SELECT 
    discount,
    COUNT(*) AS transactions,
    AVG(profit) AS avg_profit,
    AVG(sales) AS avg_sales,
    AVG(profit_margin) AS avg_margin
FROM vw_sales
GROUP BY discount
ORDER BY discount;
GO

-- 6.2 Phân nhóm chiết khấu (0%, 0-20%, 20-50%, >50%) và so sánh
WITH discount_groups AS (
    SELECT 
        CASE 
            WHEN discount = 0 THEN '0%'
            WHEN discount <= 0.2 THEN '0-20%'
            WHEN discount <= 0.5 THEN '20-50%'
            ELSE '>50%'
        END AS discount_range,
        profit,
        sales
    FROM vw_sales
)
SELECT 
    discount_range,
    COUNT(*) AS transactions,
    AVG(profit) AS avg_profit,
    AVG(profit/sales) AS avg_margin
FROM discount_groups
GROUP BY discount_range
ORDER BY discount_range;
GO

-- ========================================================================
-- PHẦN 7: PHÂN TÍCH KẾT HỢP (CROSS-SECTION)
-- ========================================================================

-- 7.1 Doanh số và lợi nhuận theo vùng và phân khúc
SELECT 
    region,
    segment,
    SUM(sales) AS sales,
    SUM(profit) AS profit
FROM vw_sales
GROUP BY region, segment
ORDER BY region, segment;
GO

-- 7.2 Doanh số và lợi nhuận theo danh mục và vùng
SELECT 
    category,
    region,
    SUM(sales) AS sales,
    SUM(profit) AS profit
FROM vw_sales
GROUP BY category, region
ORDER BY category, region;
GO

-- ========================================================================
-- PHẦN 8: TRUY VẤN XUẤT DỮ LIỆU CHO PYTHON / POWER BI
-- (Tạo các bảng tổng hợp)
-- ========================================================================

-- 8.1 Tạo bảng tổng hợp theo vùng, phân khúc, năm
SELECT 
    region,
    segment,
    order_year,
    SUM(sales) AS sales,
    SUM(profit) AS profit,
    COUNT(DISTINCT order_id) AS orders
INTO agg_region_segment_year
FROM vw_sales
GROUP BY region, segment, order_year;

-- 8.2 Tạo bảng tổng hợp theo tháng
SELECT 
    order_year,
    order_month,
    SUM(sales) AS monthly_sales
INTO agg_monthly_sales
FROM vw_sales
GROUP BY order_year, order_month
ORDER BY order_year, order_month;

-- 8.3 Tạo bảng tổng hợp sản phẩm (Sub-Category) với chỉ số hiệu quả
SELECT 
    sub_category,
    SUM(sales) AS total_sales,
    SUM(profit) AS total_profit,
    AVG(profit_margin) AS avg_margin,
    COUNT(DISTINCT order_id) AS order_count
INTO agg_product_performance
FROM vw_sales
GROUP BY sub_category;

-- 8.4 Tạo bảng RFM chi tiết cho tất cả khách hàng
WITH rfm_base AS (
    SELECT 
        customer_id,
        MAX(order_date) AS last_order_date,
        COUNT(DISTINCT order_id) AS frequency,
        SUM(sales) AS monetary
    FROM vw_sales
    GROUP BY customer_id
)
SELECT 
    customer_id,
    DATEDIFF(day, last_order_date, GETDATE()) AS recency_days,
    frequency,
    monetary,
    NTILE(5) OVER (ORDER BY DATEDIFF(day, last_order_date, GETDATE()) DESC) AS recency_score,
    NTILE(5) OVER (ORDER BY frequency DESC) AS frequency_score,
    NTILE(5) OVER (ORDER BY monetary DESC) AS monetary_score
INTO rfm_customers
FROM rfm_base;

-- ========================================================================
-- KẾT THÚC FILE
-- ========================================================================