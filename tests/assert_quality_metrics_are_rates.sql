-- The North Star and its components are shares: they must lie between 0 and 1.
-- A value outside that range would reveal a wrong formula or denominator.
select week_start, north_star_quality, satisfaction_rate, grounded_rate
from {{ ref('fct_ama_quality_weekly') }}
where north_star_quality not between 0 and 1
   or satisfaction_rate  not between 0 and 1
   or grounded_rate      not between 0 and 1
