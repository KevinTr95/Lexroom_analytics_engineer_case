-- No merged PR may be lost or duplicated between staging and the weekly team mart.
-- Protects against a week spine that does not cover the data (a PR merged outside it
-- would silently disappear) and against fan-out in the joins.
{% set window_end = "cast(cast('" ~ var('analysis_end_week') ~ "' as date) + interval 7 day as timestamp)" %}

with counts as (
    select
        (select count(*)
         from {{ ref('stg_lexroom__engineering_prs') }}
         where is_merged and merged_at < {{ window_end }})                  as prs_merged_in_window,
        (select sum(prs_merged) from {{ ref('fct_engineering_team_weekly') }}) as mart_prs_merged
)

select *
from counts
where prs_merged_in_window <> mart_prs_merged
