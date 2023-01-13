SELECT
    source,
    JSON_EXTRACT_SCALAR(metadata, '$.issue.number') AS incident_id,
    TIMESTAMP(
        JSON_EXTRACT_SCALAR(metadata, '$.issue.created_at')
    ) AS time_created,
    TIMESTAMP(
        JSON_EXTRACT_SCALAR(metadata, '$.issue.closed_at')
    ) AS time_resolved,
    REGEXP_CONTAINS(
        JSON_EXTRACT(metadata, '$.issue.labels'),
        '"name":"bug"'
    ) AS bug
FROM
    four_keys.events_raw
WHERE
    event_type LIKE "issue%"