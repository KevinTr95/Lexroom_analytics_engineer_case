-- Q1: where should the Product team focus?
-- For each module: quality in the last 4 weeks against the 4 before, and how many
-- unsatisfying answers it produces (volume x dissatisfaction).
-- Rates are recomputed from counts, not averaged across weeks.
with periods as (
    select
        module_tag,
        case when week_start > cast('{{ var("analysis_end_week") }}' as date) - interval 28 day
             then 'recent' else 'previous' end                           as period,
        sum(answers) as answers, sum(votes) as votes,
        sum(thumbs_up) as thumbs_up, sum(thumbs_down) as thumbs_down,
        sum(reason_wrong_answer + reason_hallucination + reason_incomplete) as content_issues
    from {{ ref('fct_ama_module_weekly') }}
    where week_start > cast('{{ var("analysis_end_week") }}' as date) - interval 56 day
    group by 1, 2
)

select
    module_tag,
    round(max(thumbs_up / votes) filter (where period = 'previous'), 3)   as satisfaction_previous_4w,
    round(max(thumbs_up / votes) filter (where period = 'recent'), 3)     as satisfaction_recent_4w,
    round(max(thumbs_up / votes) filter (where period = 'recent')
        - max(thumbs_up / votes) filter (where period = 'previous'), 3)   as change_pts,
    max(votes)          filter (where period = 'recent')                  as votes_recent_4w,
    max(thumbs_down)    filter (where period = 'recent')                  as thumbs_down_recent_4w,
    max(content_issues) filter (where period = 'recent')                  as content_issues_recent_4w,
    max(votes) filter (where period = 'recent') < 50                      as is_low_sample
from periods
group by 1
order by change_pts
