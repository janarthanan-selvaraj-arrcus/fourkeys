SELECT
    source,
    id as deploy_id,
    time_created,
    JSON_EXTRACT_SCALAR(metadata, '$.deployment.sha') as main_commit,
    JSON_EXTRACT_SCALAR(metadata, '$.deployment_status.repository_name') as repository_name,
    JSON_EXTRACT_SCALAR(metadata, '$.deployment_status.repository_id') as repository_id,
    JSON_EXTRACT_SCALAR(metadata, '$.deployment_status.image_tag') as image_tag
FROM
    four_keys.events_raw
WHERE
    source LIKE "github%"
    AND event_type = "deployment_status"
    AND JSON_EXTRACT_SCALAR(metadata, '$.deployment_status.state') = "success"