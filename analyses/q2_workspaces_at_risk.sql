-- Q2: which workspaces show signs of a deteriorating experience?
-- Scored workspaces at high or medium risk, sorted by score and, on ties, by volume
-- (the most active customers first). Dormant workspaces (active before, silent for the
-- whole 8 weeks) are listed at the end: they are past the warning stage, most likely lost.
select
    workspace_id,
    country,
    plan,
    firm_size_bucket,
    risk_score,
    risk_band,
    risk_signals,
    answers_prev_4w,
    answers_recent_4w,
    round(usage_change_vs_platform_pts)     as usage_vs_platform_pts,
    is_low_sample
from {{ ref('fct_workspace_health') }}
where risk_band in ('high', 'medium', 'dormant')
order by risk_score desc nulls last, answers_prev_4w desc
