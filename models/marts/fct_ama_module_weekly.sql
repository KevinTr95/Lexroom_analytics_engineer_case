-- Grain: one row per legal module and week (Monday), for every week in the data,
-- including weeks without events. Answers Q1 (quality trend per module).
-- Quality uses the same formula as the North Star (fct_ama_quality_weekly).

with events as (
    select * from {{ ref('int_ama_events_enriched') }}
),

weeks as (
    {{ dbt_utils.date_spine(
        datepart="week",
        start_date="cast('" ~ var('data_start_week') ~ "' as date)",
        end_date="cast(cast('" ~ var('analysis_end_week') ~ "' as date) + interval 7 day as date)"
    ) }}
),

modules as (
    select distinct module_tag from events
),

module_weeks as (
    -- Every module with every week: a week without activity stays visible
    select modules.module_tag, cast(weeks.date_week as date) as week_start
    from modules
    cross join weeks
),

weekly as (
    select
        module_tag,
        event_week                                                      as week_start,
        count(*)                                                        as answers,
        count(*) filter (where has_vote)                                as votes,
        count(*) filter (where thumbs = 1)                              as thumbs_up,
        count(*) filter (where is_thumbs_down)                          as thumbs_down,
        count(*) filter (where has_sources)                             as answers_with_sources,
        median(response_latency_ms)                                     as median_latency_ms,
        -- Thumbs-down reasons (indicative only: reason_tag and free_text often disagree)
        count(*) filter (where reason_tag = 'wrong_answer')             as reason_wrong_answer,
        count(*) filter (where reason_tag = 'incomplete')               as reason_incomplete,
        count(*) filter (where reason_tag = 'hallucination')            as reason_hallucination,
        count(*) filter (where reason_tag = 'slow')                     as reason_slow,
        count(*) filter (where reason_tag = 'other')                    as reason_other,
        count(*) filter (where is_thumbs_down and reason_tag is null)   as reason_not_given
    from events
    group by 1, 2
),

final as (
    select
        mw.module_tag,
        mw.week_start,
        coalesce(w.answers, 0)                                          as answers,
        coalesce(w.votes, 0)                                            as votes,
        coalesce(w.thumbs_up, 0)                                        as thumbs_up,
        coalesce(w.thumbs_down, 0)                                      as thumbs_down,
        coalesce(w.answers_with_sources, 0)                             as answers_with_sources,
        w.median_latency_ms,

        -- Quality components (NULL when the denominator is zero)
        w.votes       / nullif(w.answers, 0)                            as response_rate,
        w.thumbs_up   / nullif(w.votes, 0)                              as satisfaction_rate,
        w.answers_with_sources / nullif(w.answers, 0)                   as grounded_rate,

        coalesce(w.votes, 0) < {{ var('min_votes_per_week') }}          as is_low_sample,

        coalesce(w.reason_wrong_answer, 0)                              as reason_wrong_answer,
        coalesce(w.reason_incomplete, 0)                                as reason_incomplete,
        coalesce(w.reason_hallucination, 0)                             as reason_hallucination,
        coalesce(w.reason_slow, 0)                                      as reason_slow,
        coalesce(w.reason_other, 0)                                     as reason_other,
        coalesce(w.reason_not_given, 0)                                 as reason_not_given
    from module_weeks as mw
    left join weekly as w
        on  w.module_tag = mw.module_tag
        and w.week_start = mw.week_start
)

select
    *,
    -- Quality score: estimated share of answers that are grounded and liked
    satisfaction_rate * grounded_rate                                   as quality_score
from final
