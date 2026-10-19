-- Grain: one row per AMA event (event_id), enriched with its feedback (when one
-- exists and is valid) and with the workspace attributes.
-- It is the shared base of every AMA mart, so quality is defined in one place only.

with events as (
    select * from {{ ref('stg_lexroom__events_ama') }}
),

valid_feedback as (
    -- Only +1/-1 votes. Each event has at most one feedback today; the unique test
    -- on event_id in this model guards against a future fan-out.
    -- Orphan feedbacks (unknown event_id) drop out here, because we start from events.
    select * from {{ ref('stg_lexroom__feedback_ama') }}
    where is_valid_thumbs
),

users as (
    select * from {{ ref('stg_lexroom__users') }}
),

workspaces as (
    select * from {{ ref('stg_lexroom__workspaces') }}
)

select
    events.event_id,
    events.user_id,
    events.workspace_id,
    events.module_tag,
    events.event_at,
    cast(date_trunc('week', events.event_at) as date)      as event_week,   -- ISO week, starting Monday

    -- Answer
    events.response_latency_ms,                              -- NULL when the measurement is invalid
    events.latency_status,
    events.has_invalid_latency,
    events.response_tokens,
    events.retrieved_chunks,
    events.retrieved_chunks > 0                              as has_sources,
    events.is_cached,

    -- Feedback (NULL = no vote, or an invalid vote)
    valid_feedback.feedback_id is not null                   as has_vote,
    valid_feedback.thumbs,
    valid_feedback.is_thumbs_down,
    valid_feedback.reason_tag,

    -- Workspace (NULL when the workspace is missing from the workspaces table)
    workspaces.workspace_id is null                          as is_unknown_workspace,
    workspaces.country,
    workspaces.plan,
    workspaces.firm_size_bucket,

    -- Time consistency: users.created_at is truncated to midnight,
    -- so we trust the event and only flag the inconsistency
    events.event_at < users.created_at                       as is_before_user_creation
from events
left join valid_feedback on valid_feedback.event_id = events.event_id
left join users          on users.user_id           = events.user_id
left join workspaces     on workspaces.workspace_id = events.workspace_id
