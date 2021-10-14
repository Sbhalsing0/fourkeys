SElECT
day,
PERCENTILE_CONT(
  # Ignore automated changes
  IF(time_to_change_minutes > 0,time_to_change_minutes, NULL), 
  0.5) # Median
  OVER (partition by day) median_time_to_change
FROM
(SELECT
 d.deploy_id,
 TIMESTAMP_TRUNC(d.time_created, DAY) as day,
 # Time to Change
 TIMESTAMP_DIFF(d.time_created, c.time_created, MINUTE) time_to_change_minutes
 FROM four_keys.deployments d, d.changes
 LEFT JOIN four_keys.changes c ON changes = c.change_id
 )
GROUP BY day, time_to_change_minutes;
