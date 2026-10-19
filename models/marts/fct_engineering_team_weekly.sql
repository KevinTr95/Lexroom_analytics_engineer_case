-- Grain: one row per engineering team and week (Monday). Bonus, a DORA-style metric.
--
-- Main metric: merge lead time = hours between opening and merging a PR, median of the
-- PRs merged in the week (a proxy for DORA "lead time for changes": there is no deploy
-- data, so we stop at the merge).
-- Alongside it: PRs still open at week end and their age, because a lead time computed
-- on merged PRs only is optimistic (stuck PRs never enter it).
--
-- Window: from prs_start_week to the end of the week of analysis_end_week (Sunday 19 April).
-- A PR merged after the window (1 today, merged on 20 April) is counted as still open at
-- the end of the last week, not as merged: the mart describes the state at the window end.

{% set window_end = "cast(cast('" ~ var('analysis_end_week') ~ "' as date) + interval 7 day as timestamp)" %}

with prs as (
    select * from {{ ref('stg_lexroom__engineering_prs') }}
),

weeks as (
    {{ dbt_utils.date_spine(
        datepart="week",
        start_date="cast('" ~ var('prs_start_week') ~ "' as date)",
        end_date="cast(cast('" ~ var('analysis_end_week') ~ "' as date) + interval 7 day as date)"
    ) }}
),

team_weeks as (
    select
        teams.team,
        cast(weeks.date_week as date)                               as week_start,
        cast(weeks.date_week as timestamp) + interval 7 day         as week_end
    from (select distinct team from prs) as teams
    cross join weeks
),

merged as (
    select
        team,
        cast(date_trunc('week', merged_at) as date)                 as week_start,
        count(*)                                                    as prs_merged,
        median(date_diff('minute', created_at, merged_at) / 60.0)   as median_merge_lead_time_hours,
        quantile_cont(date_diff('minute', created_at, merged_at) / 60.0, 0.9)
                                                                    as p90_merge_lead_time_hours,
        median(lines_added + lines_deleted)                         as median_pr_size_lines
    from prs
    where is_merged
      and merged_at < {{ window_end }}
    group by 1, 2
),

open_at_week_end as (
    -- PRs opened before the end of the week and not yet merged at that point
    select
        tw.team,
        tw.week_start,
        count(p.pr_id)                                              as prs_open_at_week_end,
        median(date_diff('minute', p.created_at, tw.week_end) / 60.0)
                                                                    as median_open_pr_age_hours
    from team_weeks as tw
    left join prs as p
        on  p.team = tw.team
        and p.created_at < tw.week_end
        and (p.merged_at is null or p.merged_at >= tw.week_end)
    group by 1, 2
)

select
    tw.team,
    tw.week_start,
    coalesce(m.prs_merged, 0)                                       as prs_merged,
    m.median_merge_lead_time_hours,
    m.p90_merge_lead_time_hours,
    m.median_pr_size_lines,
    o.prs_open_at_week_end,
    o.median_open_pr_age_hours
from team_weeks as tw
left join merged           as m using (team, week_start)
left join open_at_week_end as o using (team, week_start)
