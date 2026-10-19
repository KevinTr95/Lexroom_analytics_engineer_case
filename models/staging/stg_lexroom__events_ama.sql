-- Grain: one row per AMA event (event_id).
-- Cleaning: types set, exact duplicates removed, module_tag standardised,
-- invalid latencies set to NULL and flagged (the event itself is kept).

with source as (
    select * from {{ source('lexroom', 'raw_events_ama') }}
),

typed as (
    -- The raw files arrive as text: types are set here, once
    select
        event_id,
        user_id,
        workspace_id,
        module_tag,
        cast(response_latency_ms as bigint)                     as response_latency_ms,
        cast(response_tokens as bigint)                         as response_tokens,
        cast(retrieved_chunks as bigint)                        as retrieved_chunks,
        cast(is_cached as boolean)                              as is_cached,
        cast(created_at as timestamptz)                         as created_at
    from source
),

deduplicated as (
    -- 5 event_ids appear twice with identical rows (likely a duplicate delivery):
    -- keep one. With identical rows, which one we keep makes no difference.
    select *
    from typed
    qualify row_number() over (partition by event_id order by created_at) = 1
),

cleaned as (
    select
        event_id,
        user_id,
        workspace_id,

        -- 247 events use different casing or 'civil' instead of 'civile'
        case lower(trim(module_tag))
            when 'civil' then 'civile'
            else lower(trim(module_tag))
        end                                                     as module_tag,

        -- Latency classification:
        --   negative          -> impossible duration, measurement error
        --   sentinel          -> exactly 900,000 ms (15 min). Not read as a timeout: 4 of the 28
        --                        are cached answers (cached p99 ~230 ms) and 6 received a vote,
        --                        so the answer did reach the user. A placeholder value, not a duration.
        --   implausible_cache -> exactly 45,000 ms on a cached answer (cached median is ~120 ms)
        case
            when response_latency_ms < 0                          then 'negative'
            when response_latency_ms = 900000                     then 'sentinel'
            when response_latency_ms = 45000 and is_cached        then 'implausible_cache'
            else 'valid'
        end                                                     as latency_status,

        case
            when response_latency_ms >= 0
             and response_latency_ms <> 900000
             and not (response_latency_ms = 45000 and is_cached)
            then response_latency_ms
        end                                                     as response_latency_ms,

        response_tokens,
        retrieved_chunks,
        is_cached,
        created_at at time zone 'UTC'                           as event_at
    from deduplicated
),

final as (
    select
        *,
        latency_status <> 'valid'                               as has_invalid_latency
    from cleaned
)

select * from final
