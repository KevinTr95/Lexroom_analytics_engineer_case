-- Grain: one row per week (Monday). Holds the AMA North Star (Q3).
--
-- North Star = estimated share of good answers
--            = voter satisfaction x grounded share
--
-- Rates are computed from the week's counts (ratio of sums), not as an average of
-- the module rates: every answer weighs the same.

with events as (
    select * from {{ ref('int_ama_events_enriched') }}
),

weekly as (
    select
        event_week                                          as week_start,
        count(*)                                            as answers,
        count(*) filter (where has_vote)                    as votes,
        count(*) filter (where thumbs = 1)                  as thumbs_up,
        count(*) filter (where is_thumbs_down)              as thumbs_down,
        count(*) filter (where has_sources)                 as answers_with_sources,
        median(response_latency_ms)                         as median_latency_ms,
        -- Usage guardrails: the North Star measures quality, not volume
        count(distinct workspace_id)                        as active_workspaces,
        count(distinct user_id)                             as active_users
    from events
    group by 1
),

components as (
    select
        *,
        votes       / nullif(answers, 0)                    as response_rate,
        thumbs_up   / nullif(votes, 0)                      as satisfaction_rate,
        answers_with_sources / nullif(answers, 0)           as grounded_rate
    from weekly
),

final as (
    select
        week_start,
        satisfaction_rate * grounded_rate                       as north_star_quality,
        satisfaction_rate,
        grounded_rate,
        response_rate,
        votes < {{ var('min_votes_per_week') }}                 as is_low_sample,
        answers,
        votes,
        thumbs_up,
        thumbs_down,
        answers_with_sources,
        median_latency_ms,
        active_workspaces,
        active_users
    from components
)

select * from final
