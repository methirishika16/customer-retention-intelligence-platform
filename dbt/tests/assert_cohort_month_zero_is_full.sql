-- Sanity check for the cohort grid: every customer bought in their acquisition month,
-- so month 0 must be 100% and later months can never exceed 100%.

select *
from {{ ref('cohort_retention') }}
where (months_since_acquisition = 0 and retention_rate <> 1)
   or retention_rate > 1
   or retention_rate < 0
