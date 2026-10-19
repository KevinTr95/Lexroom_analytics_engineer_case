-- A feedback cannot precede the answer it refers to.
select f.feedback_id, f.feedback_at, e.event_at
from {{ ref('stg_lexroom__feedback_ama') }} as f
join {{ ref('stg_lexroom__events_ama') }}   as e using (event_id)
where f.feedback_at < e.event_at
