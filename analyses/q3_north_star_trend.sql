-- Q3: AMA North Star trend over the last 8 weeks, with the context needed to read it.
select
    week_start,
    round(north_star_quality, 3)    as north_star_quality,
    round(satisfaction_rate, 3)     as satisfaction_rate,
    round(grounded_rate, 4)         as grounded_rate,
    votes,
    round(response_rate, 3)         as response_rate,
    is_low_sample,
    answers,
    active_workspaces
from {{ ref('fct_ama_quality_weekly') }}
where week_start > cast('{{ var("analysis_end_week") }}' as date) - interval 56 day
order by week_start
