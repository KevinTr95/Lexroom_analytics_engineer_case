-- Grain: one row per user (user_id).
with source as (
    select * from {{ ref('raw_users') }}
)

select
    user_id,
    workspace_id,
    lower(trim(role))                                           as role,
    -- Every created_at is at midnight: a truncated date, less reliable than
    -- event timestamps (see README, known data issues).
    created_at at time zone 'UTC'                               as created_at,
    is_deleted
from source
