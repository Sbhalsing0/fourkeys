SELECT 
CASE WHEN median_time_to_change < 24 * 60 then "One day"
     WHEN median_time_to_change < 168 * 60 then "One week"
     WHEN median_time_to_change < 730 * 60 then "One month"
     WHEN median_time_to_change < 730 * 6 * 60 then "Six months"
     ELSE "One year"
     END as lead_time_to_change,
FROM
  (SElECT
    PERCENTILE_CONT(
    # Ignore automated changes
    IF(time_to_change_minutes > 0,time_to_change_minutes, NULL), 
    0.5) # Median
    OVER () median_time_to_change
      FROM
      (SELECT
       d.deploy_id,
       TIMESTAMP_TRUNC(d.time_created, DAY) as day,
       # Time to Change
       TIMESTAMP_DIFF(d.time_created, c.time_created, MINUTE) time_to_change_minutes
       FROM four_keys.deployments d, d.changes
       LEFT JOIN four_keys.changes c ON changes = c.change_id
       # Limit to 3 months
       WHERE d.time_created > TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH))
       )
      GROUP BY day, time_to_change_minutes
      )
LIMIT 1;
