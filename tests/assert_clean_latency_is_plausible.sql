-- Protects the cleaning logic: after staging, a valid latency must be
-- non-negative, never equal to the 900,000 ms sentinel value, and never the
-- implausible 45,000 ms on a cached answer.
select event_id, response_latency_ms, is_cached
from {{ ref('stg_lexroom__events_ama') }}
where response_latency_ms < 0
   or response_latency_ms = 900000
   or (response_latency_ms = 45000 and is_cached)
