-- Grain: one row per user (user_id).

with source as (
    select * from {{ source('lexroom', 'raw_users') }}
),

final as (
    select
        user_id,
        workspace_id,
        lower(trim(role))                                       as role,
        -- Every created_at is at midnight: a truncated date, less reliable than
        -- event timestamps (see README, known data issues).
        cast(created_at as timestamptz) at time zone 'UTC'      as created_at,
        cast(is_deleted as boolean)                             as is_deleted
    from source
)

select * from final
