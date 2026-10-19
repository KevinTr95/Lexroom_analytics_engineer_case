-- The risk score is a sum of rules with a maximum of 100, and it exists exactly for the
-- scored bands (high, medium, low). Catches errors in the scoring rules and a score
-- leaking onto workspaces that are not meant to be scored (or missing on scored ones).
select workspace_id, risk_score, risk_band
from {{ ref('fct_workspace_health') }}
where risk_score not between 0 and 100
   or (risk_band in ('high', 'medium', 'low')) <> (risk_score is not null)
