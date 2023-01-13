SELECT
    source,
    event_type,
    IF(
        event_type = "push",
        id,
        JSON_EXTRACT_SCALAR(metadata, '$.pull_request.merge_commit_sha')
    ) change_id,
    IF(
        event_type = "push",
        time_created,
        TIMESTAMP_TRUNC(
            TIMESTAMP(
                JSON_EXTRACT_SCALAR(metadata, '$.pull_request.merged_at')
            ),
            second
        )
    ) as time_created,
    JSON_EXTRACT_SCALAR(metadata, '$.repository.name') as repository_name,
    JSON_EXTRACT_SCALAR(metadata, '$.repository.id') as repository_id,
    JSON_EXTRACT_SCALAR(metadata, '$.jira.id') as jira_id
FROM
    four_keys.events_raw
WHERE
    event_type = "push"
    OR event_type = "pull_request"
GROUP BY
    1,
    2,
    3,
    4