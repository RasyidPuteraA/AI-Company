# Stale Task Recovery Plan

- generated_at: 2026-06-14T05:24:52+07:00
- mode: report-only
- threshold_hours: 24
- report_path: company/reports/stale-task-recovery/20260614T052452+0700-stale-task-recovery-plan.md

## Safety

- This runner does not mutate task status.
- Client tasks are owner-review only.
- Stale tasks are not marked DONE automatically.
- Tasks are not deleted.

## IN_PROGRESS Tasks

        task_key        |                       title                       |     agent      |   status    |         updated_at         | age_hours | task_category | has_active_runtime | has_active_lock |  recommended_action   
------------------------+---------------------------------------------------+----------------+-------------+----------------------------+-----------+---------------+--------------------+-----------------+-----------------------
 INTERNAL-038           | Add Minimal Chat Command Bar UI                   | engineer_agent | IN_PROGRESS | 2026-06-11 18:08:03.628654 |        52 | internal      | f                  | f               | release_claim_if_safe
 INTERNAL-044           | Clean Pixel Office and Add AI Usage Widget        | engineer_agent | IN_PROGRESS | 2026-06-11 20:28:04.632588 |        49 | internal      | f                  | f               | release_claim_if_safe
 INTERNAL-045           | Add Tilemap Office Renderer v1                    | engineer_agent | IN_PROGRESS | 2026-06-11 20:40:36.786241 |        49 | internal      | f                  | f               | release_claim_if_safe
 INTERNAL-048           | Clean Pixel Office CSS and Sprite Frame Selection | engineer_agent | IN_PROGRESS | 2026-06-12 03:36:22.191435 |        42 | internal      | f                  | f               | release_claim_if_safe
 INTERNAL-049           | Render LimeZu Modern Office Map v1                | engineer_agent | IN_PROGRESS | 2026-06-12 04:10:46.385297 |        42 | internal      | f                  | f               | release_claim_if_safe
 AUTO-20260613193656-01 | Review and resolve TODO/FIXME findings            | engineer_agent | IN_PROGRESS | 2026-06-13 12:37:06.838415 |         9 | auto          | f                  | f               | keep_if_recent
(6 rows)


## Counts

 task_category |  recommended_action   | task_count 
---------------+-----------------------+------------
 auto          | keep_if_recent        |          1
 internal      | release_claim_if_safe |          5
(2 rows)

