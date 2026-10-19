-- A reason (reason_tag) only makes sense for a thumbs down.
-- A thumbs up with a reason would point to a bug in feedback collection.
{{ config(severity='warn') }}

select feedback_id, thumbs, reason_tag
from {{ ref('stg_lexroom__feedback_ama') }}
where thumbs = 1
  and reason_tag is not null
