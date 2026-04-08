SELECT TOP (1000) [event_id]
      ,[user_id]
      ,[event_type]
      ,[event_date]
      ,[product_id]
      ,[amount]
      ,[traffic_source]
      ,[F8]
      ,[F9]
  FROM [E_Commerce_data].[dbo].[user_events]

  --define sales funnel and the different stages 
  ;WITH funnel_stages AS (
    SELECT 
        COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS stage_1_views,
        COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN user_id END) AS stage_2_cart,
        COUNT(DISTINCT CASE WHEN event_type = 'checkout_start' THEN user_id END) AS stage_3_checkout,
        COUNT(DISTINCT CASE WHEN event_type = 'payment_info' THEN user_id END) AS stage_4_payment,
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS stage_5_purchase
    FROM E_Commerce_data.dbo.user_events
       WHERE event_date >= DATEADD(
        DAY, 
        -30, 
        --“Take the latest date in the dataset, go back 30 days from there, and return all records from that period.”
        (SELECT MAX(event_date) FROM E_Commerce_data.dbo.user_events))
)

--calculating the conversion rate 
SELECT 

stage_1_views,
stage_2_cart,
ROUND(stage_2_cart * 100 / stage_1_views,1) AS view_to_cart_rate,

stage_3_checkout,
ROUND(stage_3_checkout * 100 / stage_2_cart,1) AS cart_to_checkout_rate,

stage_4_payment,
ROUND(stage_4_payment * 100 /stage_3_checkout,2) AS checkout_to_payment_rate,

stage_5_purchase,
ROUND(stage_5_purchase * 100 /stage_4_payment,2) AS payment_to_purchase_rate,

ROUND(stage_5_purchase * 100 /stage_1_views,1) AS overall_conversion_rate

from funnel_stages

--funnel by source
;WITH source_funnel AS (
SELECT 
[traffic_source],
   COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN [user_id] END) AS views,
   COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN [user_id] END) AS cart,
   COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN [user_id] END) AS purchases
    FROM E_Commerce_data.dbo.user_events
     
 WHERE event_date >= DATEADD( DAY,-30, 
        (SELECT MAX(event_date) FROM E_Commerce_data.dbo.user_events))
        GROUP BY [traffic_source]
)
SELECT

traffic_source,
views,
cart,
purchases,
ROUND(cart * 100 / views,1) AS cart_conversion_rate,
ROUND(purchases * 100 / cart,1) AS cart_to_purchase_conversion_rate,
ROUND(purchases * 100 / views,1) AS purchase_conversion_rate

FROM source_funnel
ORDER BY purchases desc

--Time to conversion analysis
;WITH user_journey AS(
SELECT 
user_id,
   MIN(CASE WHEN event_type = 'page_view' THEN event_date END) AS view_time,
   MIN(CASE WHEN event_type = 'add_to_cart' THEN event_date END) AS cart_time,
   MIN(CASE WHEN event_type = 'purchase' THEN event_date END) AS purchase_time
FROM  E_Commerce_data.dbo.user_events
 WHERE event_date >= DATEADD( DAY, -30, 
        (SELECT MIN(event_date) FROM E_Commerce_data.dbo.user_events))
        GROUP BY [user_id]
        HAVING MIN(CASE WHEN event_type = 'purchase' THEN event_date END) IS NOT NULL
        )

 SELECT 
   COUNT(*) AS converted_users,
   ROUND(AVG(DATEDIFF(MINUTE,view_time,cart_time)),2) AS avg_view_to_cart_minutes,
   ROUND(AVG(DATEDIFF(MINUTE,cart_time,purchase_time)),2) AS avg_cart_to_purcgase_minutes,
   ROUND(AVG(DATEDIFF(MINUTE,view_time,purchase_time)),2) AS avg_total_journey_minutes
 FROM user_journey

 --Revenue funnel analysis
; WITH funnel_revenue AS(
 SELECT
    COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN [user_id] END) AS total_visitors,
   SUM(CASE WHEN event_type = 'purchase' THEN amount END) AS total_revenue,
   COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN [user_id] END) AS total_buyers,
   COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN 1 END) AS total_orders

FROM  E_Commerce_data.dbo.user_events
 WHERE event_date >= DATEADD( DAY, -30, 
        (SELECT MIN(event_date) FROM E_Commerce_data.dbo.user_events))

        )
 SELECT 
   total_visitors,
   total_orders,
   total_revenue
   total_buyers,
   total_revenue/total_orders AS avg_order_value,
  total_revenue/total_buyers AS revenue_per_buyer,
  total_revenue/total_visitors AS revenue_per_visitor
FROM funnel_revenue
