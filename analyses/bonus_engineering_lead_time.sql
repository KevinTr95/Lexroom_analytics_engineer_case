-- Bonus: merge lead time per team over the last 8 weeks, with the PRs left open.
-- The team figure is a median of weekly medians: indicative, not exact.
select
    team,
    sum(prs_merged)                                         as prs_merged_8w,
    round(median(median_merge_lead_time_hours), 1)          as typical_lead_time_hours,
    round(max(p90_merge_lead_time_hours), 1)                as worst_week_p90_hours,
    max(prs_open_at_week_end) filter (
        where week_start = cast('{{ var("analysis_end_week") }}' as date))  as prs_open_at_end
from {{ ref('fct_engineering_team_weekly') }}
where week_start > cast('{{ var("analysis_end_week") }}' as date) - interval 56 day
group by 1
order by typical_lead_time_hours desc
