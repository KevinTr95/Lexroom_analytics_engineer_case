-- No answer may be lost or duplicated between the event model and the marts.
-- Protects against fan-out in joins and against mistakes in the date spine.
with counts as (
    select
        (select count(*)     from {{ ref('int_ama_events_enriched') }}) as events,
        (select sum(answers) from {{ ref('fct_ama_module_weekly') }})   as module_answers,
        (select sum(answers) from {{ ref('fct_ama_quality_weekly') }})  as weekly_answers
)
select *
from counts
where module_answers <> events
   or weekly_answers <> events
