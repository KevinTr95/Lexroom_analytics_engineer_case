-- An event must belong to the workspace of the user who generated it:
-- otherwise workspace metrics would credit activity to the wrong customer.
select e.event_id, e.workspace_id as event_workspace, u.workspace_id as user_workspace
from {{ ref('stg_lexroom__events_ama') }} as e
join {{ ref('stg_lexroom__users') }}      as u using (user_id)
where e.workspace_id <> u.workspace_id
