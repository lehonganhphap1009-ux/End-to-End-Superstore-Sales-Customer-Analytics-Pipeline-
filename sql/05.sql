SELECT 
    region,
    segment,
    SUM(sales) AS sales,
    SUM(profit) AS profit
INTO agg_region_segment
FROM vw_sales
GROUP BY region, segment;