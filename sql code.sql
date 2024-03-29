--Inspect Data
SELECT*FROM [dbo].[sales_data_sample]

--Checking unique Values
SELECT DISTINCT status FROM [dbo].[sales_data_sample] --* plot*
SELECT DISTINCT year_id FROM [dbo].[sales_data_sample]
SELECT DISTINCT PRODUCTLINE FROM [dbo].[sales_data_sample]--*plot*
SELECT DISTINCT COUNTRY FROM [dbo].[sales_data_sample]  --*plot*
SELECT DISTINCT DEALSIZE FROM [dbo].[sales_data_sample] --*plot* 
SELECT DISTINCT TERRITORY FROM [dbo].[sales_data_sample]--*plot*

---ANALYSIS 
---GROUPING SALES BY PRODUCTLINE
SELECT PRODUCTLINE, SUM(sales) Revenue
FROM [dbo].[sales_data_sample]
GROUP BY PRODUCTLINE
ORDER BY 2 DESC


--Who is our best customer (this could be best answered with RFM)

DROP TABLE IF EXISTS #rfm
;WITH rfm AS
(
	SELECT 
		CUSTOMERNAME,
		SUM(sales) MonetaryValue,
		AVG(sales) AvgMonetaryValue,
		COUNT(ORDERNUMBER) Frequency,
		MAX(ORDERDATE) last_order_date,
		(SELECT MAX(ORDERDATE) FROM [dbo].[sales_data_sample]) max_order_date,
		DATEDIFF(DD, MAX(ORDERDATE), (SELECT MAX(ORDERDATE) FROM [dbo].[sales_data_sample])) Recency
	FROM [PortfolioDB].[dbo].[sales_data_sample]
	GROUP BY CUSTOMERNAME
),
rfm_calc as
(
SELECT	r.*,
	NTILE(4) OVER (order by Recency desc) rfm_recency,
	NTILE(4) OVER (order by Frequency) rfm_frequency,
	NTILE(4) OVER (order by MonetaryValue) rfm_monetary
from rfm r
)
SELECT 
	c.*, rfm_recency + rfm_frequency + rfm_monetary AS rfm_cell,
	CAST(rfm_recency AS VARCHAR) + CAST(rfm_frequency AS VARCHAR) + CAST(rfm_monetary AS VARCHAR)rfm_cell_string
INTO #rfm
FROM rfm_calc c

SELECT CUSTOMERNAME , rfm_recency, rfm_frequency, rfm_monetary,
	CASE 
		when rfm_cell_string in (111, 112 , 121, 122, 123, 132, 211, 212, 114, 141) then 'lost_customers'  --lost customers
		when rfm_cell_string in (133, 134, 143, 244, 334, 343, 344, 144) then 'slipping away, cannot lose' -- (Large spenders who haven’t purchased lately) slipping away
		when rfm_cell_string in (311, 411, 331) then 'new customers'
		when rfm_cell_string in (222, 223, 233, 322) then 'potential churners'
		when rfm_cell_string in (323, 333,321, 422, 332, 432) then 'active' --(Customers who buy often & recently, but at low price points)
		when rfm_cell_string in (433, 434, 443, 444) then 'loyal'
	END rfm_segment
FROM #rfm

--Which Products are frequently sold together and bought at the sametime
--SELECT * FROM [dbo].[sales_data_sample] WHERE ORDERNUMBER = 10411

SELECT DISTINCT OrderNumber, STUFF(

	(SELECT ',' + PRODUCTCODE
	FROM [dbo].[sales_data_sample] p
	WHERE ORDERNUMBER IN 
		(

			SELECT ORDERNUMBER
			FROM (
				SELECT ORDERNUMBER, COUNT(*) rn
				FROM [PortfolioDB].[dbo].[sales_data_sample]
				WHERE Status = 'Shipped'
				GROUP BY ORDERNUMBER
			)m
			WHERE rn = 3
		)
		AND p.ORDERNUMBER = s.ORDERNUMBER 
		FOR XML PATH (''))

		, 1, 1, '') ProductCodes

FROM [dbo].[sales_data_sample] s
ORDER BY 2 desc
