SELECT
TIMESTAMP_TRUNC(d.time_created, DAY) as day,
SUM(IF(i.incident_id is NULL, 0, 1)) / COUNT(DISTINCT change_id) as change_fail_rate
FROM four_keys.deployments d, d.changes
LEFT JOIN four_keys.changes c ON changes = c.change_id
LEFT JOIN(SELECT
        incident_id,
        change,
        time_resolved
        FROM four_keys.incidents i,
        i.changes change) i ON i.change = changes
GROUP BY day;
