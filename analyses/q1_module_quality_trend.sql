-- Q1: weekly quality trend per module, last 8 weeks.
-- One row per module and week: the series to chart.
select
    module_tag,
    week_start,
    round(quality_score, 3)     as quality_score,
    round(satisfaction_rate, 3) as satisfaction_rate,
    votes,
    answers,
    is_low_sample
from {{ ref('fct_ama_module_weekly') }}
where week_start > cast('{{ var("analysis_end_week") }}' as date) - interval 56 day
order by module_tag, week_start
