-- Q1: where should the Product team focus?
-- For each module: quality in the last 4 weeks against the 4 before, and how many
-- answers fall short in absolute terms (answers x (1 - quality)).
-- Quality is the same formula as the North Star (satisfaction x grounded share),
-- recomputed from the counts of each period, not averaged across weeks.

with periods as (
    select
        module_tag,
        case when week_start > cast('{{ var("analysis_end_week") }}' as date) - interval 28 day
             then 'recent' else 'previous' end                              as period,
        sum(answers)                                                        as answers,
        sum(votes)                                                          as votes,
        sum(thumbs_up)                                                      as thumbs_up,
        sum(thumbs_down)                                                    as thumbs_down,
        sum(answers_with_sources)                                           as answers_with_sources,
        sum(reason_wrong_answer + reason_hallucination + reason_incomplete) as content_issues
    from {{ ref('fct_ama_module_weekly') }}
    where week_start > cast('{{ var("analysis_end_week") }}' as date) - interval 56 day
    group by 1, 2
),

quality as (
    select
        *,
        thumbs_up / nullif(votes, 0) * (answers_with_sources / nullif(answers, 0)) as quality_score
    from periods
),

final as (
    select
        module_tag,
        round(max(quality_score) filter (where period = 'previous'), 3)    as quality_previous_4w,
        round(max(quality_score) filter (where period = 'recent'), 3)      as quality_recent_4w,
        round(max(quality_score) filter (where period = 'recent')
            - max(quality_score) filter (where period = 'previous'), 3)    as quality_change,
        max(answers)        filter (where period = 'recent')               as answers_recent_4w,
        round(max(answers * (1 - quality_score)) filter (where period = 'recent'))
                                                                           as answers_falling_short_recent_4w,
        max(votes)          filter (where period = 'recent')               as votes_recent_4w,
        max(thumbs_down)    filter (where period = 'recent')               as thumbs_down_recent_4w,
        max(content_issues) filter (where period = 'recent')               as content_issues_recent_4w,
        max(votes) filter (where period = 'recent') < 50                   as is_low_sample
    from quality
    group by 1
)

select * from final
order by quality_change
