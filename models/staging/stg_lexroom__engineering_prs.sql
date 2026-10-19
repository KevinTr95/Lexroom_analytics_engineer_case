-- Grain: one row per pull request (pr_id).

with source as (
    select * from {{ source('lexroom', 'raw_engineering_prs') }}
),

final as (
    select
        pr_id,
        author_id,
        team,
        cast(created_at as timestamptz) at time zone 'UTC'      as created_at,
        cast(merged_at as timestamptz) at time zone 'UTC'       as merged_at,   -- NULL = not merged (yet)
        merged_at is not null                                   as is_merged,
        cast(lines_added as bigint)                             as lines_added,
        cast(lines_deleted as bigint)                           as lines_deleted,
        cast(review_comments_count as bigint)                   as review_comments_count
    from source
)

select * from final
