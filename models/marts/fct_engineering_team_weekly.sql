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
        team_weeks.team,
        team_weeks.week_start,
        count(prs.pr_id)                                            as prs_open_at_week_end,
        median(date_diff('minute', prs.created_at, team_weeks.week_end) / 60.0)
                                                                    as median_open_pr_age_hours
    from team_weeks
    left join prs
        on  prs.team = team_weeks.team
        and prs.created_at < team_weeks.week_end
        and (prs.merged_at is null or prs.merged_at >= team_weeks.week_end)
    group by 1, 2
),

final as (
    select
        team_weeks.team,
        team_weeks.week_start,
        coalesce(merged.prs_merged, 0)                              as prs_merged,
        merged.median_merge_lead_time_hours,
        merged.p90_merge_lead_time_hours,
        merged.median_pr_size_lines,
        open_at_week_end.prs_open_at_week_end,
        open_at_week_end.median_open_pr_age_hours
    from team_weeks
    left join merged           using (team, week_start)
    left join open_at_week_end using (team, week_start)
)

select * from final
