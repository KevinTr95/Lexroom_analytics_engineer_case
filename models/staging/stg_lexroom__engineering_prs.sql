-- Grain: one row per pull request (pr_id).
with source as (
    select * from {{ ref('raw_engineering_prs') }}
)

select
    pr_id,
    author_id,
    team,
    created_at at time zone 'UTC'                               as created_at,
    merged_at  at time zone 'UTC'                               as merged_at,   -- NULL = not merged (yet)
    merged_at is not null                                       as is_merged,
    lines_added,
    lines_deleted,
    review_comments_count
from source
