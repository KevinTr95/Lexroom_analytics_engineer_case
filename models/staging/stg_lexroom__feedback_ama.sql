-- Grain: one row per feedback (feedback_id).
-- free_text is NOT carried beyond staging: it is free text written by lawyers and
-- in production it may contain personal or confidential data. Only a flag is kept.

with source as (
    select * from {{ source('lexroom', 'raw_feedback_ama') }}
),

typed as (
    select
        feedback_id,
        event_id,
        user_id,
        cast(thumbs as integer)                                 as thumbs,
        reason_tag,
        free_text,
        cast(created_at as timestamptz)                         as created_at
    from source
),

deduplicated as (
    -- 15 feedback_ids appear twice with identical rows: keep one
    select *
    from typed
    qualify row_number() over (partition by feedback_id order by created_at) = 1
),

final as (
    select
        feedback_id,
        event_id,
        user_id,
        thumbs,
        -- The schema allows only +1 / -1. 16 feedbacks have -2, 0 or +2: they stay here,
        -- but are excluded from metrics (0.5% of votes, meaning undocumented).
        thumbs in (1, -1)                                       as is_valid_thumbs,
        thumbs = -1                                             as is_thumbs_down,
        reason_tag,                                             -- NULL = no reason given
        free_text is not null                                   as has_free_text,
        created_at at time zone 'UTC'                           as feedback_at
    from deduplicated
)

select * from final
