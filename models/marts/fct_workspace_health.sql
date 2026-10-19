-- Grain: one row per workspace in the workspaces table, assessed at the end of the data.
-- Answers Q2: which workspaces show signs of a deteriorating experience?
--
-- Each workspace is compared with itself: the last 4 complete weeks against the 4 before.
-- The score is rule-based (0-100), transparent, and explained by risk_signals.
-- Weights and thresholds are reasoned choices, documented in the README.
--
-- Only workspaces with enough history get a score (at least min_answers_for_risk answers
-- in the previous 4 weeks): below that, going from 2 answers to 0 would read as a -100%
-- usage drop. The others get a status in risk_band that says why they are not scored.

{% set end_week = "cast('" ~ var('analysis_end_week') ~ "' as date)" %}

with history as (
    -- Full activity history, to tell a new account from a returning or a lost one
    select
        workspace_id,
        min(event_week)                                 as first_active_week
    from {{ ref('int_ama_events_enriched') }}
    where event_week <= {{ end_week }}
    group by 1
),

events as (
    select * from {{ ref('int_ama_events_enriched') }}
    where event_week between {{ end_week }} - interval 49 day and {{ end_week }}
),

workspaces as (
    select * from {{ ref('stg_lexroom__workspaces') }}
),

windowed as (
    select
        *,
        case
            when event_week >= {{ end_week }} - interval 21 day then 'recent'   -- last 4 weeks
            else 'previous'                                                     -- the 4 weeks before
        end as time_window
    from events
),

global_rate as (
    -- Global thumbs-down rate over the 8 weeks: the "average" that the rates of
    -- workspaces with few votes are smoothed towards
    select avg(case when is_thumbs_down then 1.0 else 0.0 end) as thumbs_down_rate
    from windowed
    where has_vote
),

platform as (
    -- Usage trend of the whole platform, as context only: it is not part of the score
    select
        count(*) filter (where time_window = 'recent')
            / nullif(count(*) filter (where time_window = 'previous'), 0) - 1  as platform_usage_change
    from windowed
),

per_window as (
    select
        workspace_id,
        time_window,
        count(*)                                        as answers,
        count(distinct user_id)                         as active_users,
        count(*) filter (where has_vote)                as votes,
        count(*) filter (where is_thumbs_down)          as thumbs_down,
        count(*) filter (where not has_sources)         as answers_without_sources,
        median(response_latency_ms)                     as median_latency_ms
    from windowed
    group by 1, 2
),

pivoted as (
    select
        w.workspace_id,
        sum(answers)            filter (where time_window = 'previous')   as answers_prev,
        sum(answers)            filter (where time_window = 'recent')     as answers_recent,
        sum(active_users)       filter (where time_window = 'previous')   as users_prev,
        sum(active_users)       filter (where time_window = 'recent')     as users_recent,
        sum(votes)              filter (where time_window = 'previous')   as votes_prev,
        sum(votes)              filter (where time_window = 'recent')     as votes_recent,
        sum(thumbs_down)        filter (where time_window = 'previous')   as thumbs_down_prev,
        sum(thumbs_down)        filter (where time_window = 'recent')     as thumbs_down_recent,
        sum(answers_without_sources) filter (where time_window = 'recent') as no_source_recent,
        max(median_latency_ms)  filter (where time_window = 'previous')   as latency_prev,
        max(median_latency_ms)  filter (where time_window = 'recent')     as latency_recent
    from workspaces as w
    left join per_window as p using (workspace_id)
    group by 1
),

measures as (
    select
        p.*,
        coalesce(answers_prev, 0)   as a_prev,
        coalesce(answers_recent, 0) as a_recent,

        -- Usage change: last 4 weeks / previous 4 weeks - 1
        coalesce(answers_recent, 0) / nullif(answers_prev, 0) - 1               as usage_change,
        coalesce(users_recent, 0)   / nullif(users_prev, 0) - 1                 as active_users_change,
        latency_recent / nullif(latency_prev, 0) - 1                            as latency_change,

        -- Smoothed thumbs-down rate: (thumbs down + k * global rate) / (votes + k)
        (coalesce(thumbs_down_prev, 0)   + {{ var('smoothing_k') }} * g.thumbs_down_rate)
            / (coalesce(votes_prev, 0)   + {{ var('smoothing_k') }})            as thumbs_down_rate_prev,
        (coalesce(thumbs_down_recent, 0) + {{ var('smoothing_k') }} * g.thumbs_down_rate)
            / (coalesce(votes_recent, 0) + {{ var('smoothing_k') }})            as thumbs_down_rate_recent,

        no_source_recent / nullif(answers_recent, 0)                            as no_source_share_recent,

        coalesce(answers_prev, 0) >= {{ var('min_answers_for_risk') }}          as is_scored
    from pivoted as p
    cross join global_rate as g
),

signals as (
    select
        *,
        -- Percentage points: 12.0 = the thumbs-down share went up by 12 points
        (thumbs_down_rate_recent - thumbs_down_rate_prev) * 100                 as thumbs_down_change_pts,

        -- Signals fire only on workspaces with enough history to be scored
        coalesce(is_scored and usage_change < -0.50, false)                     as sig_usage_drop,
        coalesce(is_scored and thumbs_down_rate_recent - thumbs_down_rate_prev > 0.10, false)
                                                                                as sig_quality_drop,
        coalesce(is_scored and latency_change > 0.30, false)                    as sig_slower,
        coalesce(is_scored and active_users_change < -0.30, false)              as sig_fewer_users,
        coalesce(is_scored and no_source_share_recent > 0.10, false)            as sig_no_sources
    from measures
),

scored as (
    select
        *,
        case when is_scored then
              case when sig_usage_drop   then 35 else 0 end
            + case when sig_quality_drop then 25 else 0 end
            + case when sig_slower       then 15 else 0 end
            + case when sig_fewer_users  then 15 else 0 end
            + case when sig_no_sources   then 10 else 0 end
        end                                                                     as risk_score   -- NULL = not scored
    from signals
)

select
    s.workspace_id,
    w.country,
    w.plan,
    w.firm_size_bucket,

    s.risk_score,
    case
        -- Not scored: the status says why
        when h.first_active_week is null     then 'never_active'  -- no AMA activity at all
        when s.a_prev = 0 and s.a_recent = 0 then 'dormant'       -- active before the 8 weeks, silent since: likely lost
        when s.a_prev = 0
         and h.first_active_week >= {{ end_week }} - interval 21 day
                                             then 'new'           -- first activity in the last 4 weeks
        when s.a_prev = 0                    then 'returning'     -- back after a pause: nothing to compare against
        when not s.is_scored                 then 'low_volume'    -- too few answers for a reliable trend
        -- Scored
        when s.risk_score >= 50              then 'high'
        when s.risk_score >= 25              then 'medium'
        else 'low'
    end                                                                         as risk_band,
    h.first_active_week,
    concat_ws(', ',
        case when s.sig_usage_drop   then 'usage ' || cast(round(s.usage_change * 100) as integer) || '%' end,
        case when s.sig_quality_drop then 'thumbs down +' || cast(round(s.thumbs_down_change_pts) as integer) || ' pts' end,
        case when s.sig_slower       then 'latency +' || cast(round(s.latency_change * 100) as integer) || '%' end,
        case when s.sig_fewer_users  then 'active users ' || cast(round(s.active_users_change * 100) as integer) || '%' end,
        case when s.sig_no_sources   then cast(round(s.no_source_share_recent * 100) as integer) || '% answers without sources' end
    )                                                                           as risk_signals,

    -- Volumes, to judge how much to trust the score
    s.a_prev                                                                    as answers_prev_4w,
    s.a_recent                                                                  as answers_recent_4w,
    coalesce(s.votes_prev, 0)                                                   as votes_prev_4w,
    coalesce(s.votes_recent, 0)                                                 as votes_recent_4w,
    coalesce(s.votes_prev, 0) + coalesce(s.votes_recent, 0) < 20                as is_low_sample,

    -- Underlying measures
    s.usage_change,
    pl.platform_usage_change,
    (s.usage_change - pl.platform_usage_change) * 100                           as usage_change_vs_platform_pts,
    s.active_users_change,
    s.thumbs_down_rate_prev,
    s.thumbs_down_rate_recent,
    s.thumbs_down_change_pts,
    s.latency_prev                                                              as median_latency_prev_ms,
    s.latency_recent                                                            as median_latency_recent_ms,
    s.latency_change,
    s.no_source_share_recent,
    s.sig_usage_drop,
    s.sig_quality_drop,
    s.sig_slower,
    s.sig_fewer_users,
    s.sig_no_sources
from scored as s
inner join workspaces as w using (workspace_id)
left join history as h using (workspace_id)
cross join platform as pl
