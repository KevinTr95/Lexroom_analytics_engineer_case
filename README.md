# Lexroom — AMA analytics (Analytics Engineer case)

A small dbt project (dbt-core + DuckDB) that turns the AMA case data into marts answering
three business questions, plus the optional engineering bonus.

- **5 sources** (the raw CSVs, read in place) and **10 models**: 5 staging, 1 intermediate, 4 marts
- **59 tests**: 51 generic (keys, grain, relationships, accepted values) and 8 singular tests on business rules
- **every source, model and column documented**, with docs blocks written for a non-technical
  reader, and **exposures** linking each mart to its question
- **separate dev and prod** targets, so development never overwrites the tables people read
- **answer queries** in [`/analyses`](analyses)

---

## Results at a glance

All windows are anchored to the **last complete week in the data** (week of 13 April 2026),
not to today's date. "Last 8 weeks" = weeks starting 23 Feb → 13 Apr 2026.

### Q3 — North Star: AMA quality is falling, and so is usage

| Week | North Star | Votes | Active workspaces |
|---|---|---|---|
| 23 Feb | 70.8% | 448 | 65 |
| 02 Mar | 76.3% | 394 | 64 |
| 09 Mar | 76.4% | 317 | 58 |
| 16 Mar | 73.9% | 278 | 54 |
| 23 Mar | 66.1% | 229 | 58 |
| 30 Mar | 63.4% | 142 | 46 |
| 06 Apr | 65.3% | 84 | 42 |
| 13 Apr | 50.0% ⚠️ | 20 | 33 |

The estimated share of good answers drops from ~76% in early March to ~65% in April.
The last week (50%) rests on 20 votes (±22 pts) and is flagged as a small sample.
**At the same time usage collapses**: answers per week go from 1,875 (mid-February peak) to 102,
active workspaces from 67 to 33. The North Star measures quality, not usage, so the two
trends must be read together: quality and usage are declining at the same time.

### Q1 — Every module is getting worse; focus on *societario* and *civile*

Quality score (the North Star formula, per module), last 4 weeks vs the 4 before:

| Module | Before | After | Change | Answers falling short (last 4w) | Votes (last 4w) |
|---|---|---|---|---|---|
| amministrativo | 67.8% | 50.0% | −18 pts | 38 | 18 ⚠️ small sample |
| societario | 73.9% | 59.5% | −14 pts | 113 | 74 |
| tributario | 72.6% | 61.7% | −11 pts | 73 | 50 |
| civile | 75.8% | 65.8% | −10 pts | 270 | 203 |
| lavoro | 71.9% | 64.9% | −7 pts | 112 | 74 |
| penale | 77.0% | 73.2% | −4 pts | 44 | 56 |

"Answers falling short" = answers × (1 − quality): how many answers are estimated not to be
both sourced and liked.

Where Product should look first:
- **societario**: the clearest drop on a meaningful volume.
- **civile**: a smaller drop, but it is by far the biggest module, so it produces the most
  answers falling short in absolute terms (~270 in 4 weeks).
- **amministrativo**: the largest drop, but on 18 votes it is not yet evidence — watch it.
- Thumbs-down reasons point at **content, not speed**: `wrong_answer`, `incomplete` and
  `hallucination` far outnumber `slow`.

### Q2 — Risk is platform-wide; the score surfaces it, CS prioritises

47 workspaces have enough history to be scored (at least 10 answers in the earlier 4 weeks):

| Risk band | Workspaces |
|---|---|
| high (≥ 50) | 19 |
| medium (25–49) | 26 |
| low (< 25) | 2 |

The other 33 get no score, and `risk_band` says why:

| Status | Workspaces |
|---|---|
| low_volume (1–9 answers in the earlier 4 weeks) | 26 |
| dormant (active before, silent for all 8 weeks: likely lost) | 4 |
| returning (back after a pause, nothing to compare against) | 2 |
| never_active | 1 |

Platform usage fell **66%** between the two 4-week windows, so 45 of the 47 scored workspaces
trigger the usage signal. This is deliberate (see *Design decisions*): the score reports what
is happening to each customer; deciding who to call first is a CS decision. To support it,
each row carries the triggered signals in words, the volumes, a small-sample flag and the
workspace's usage change **relative to the platform**.

Examples among workspaces with enough votes:

| Workspace | Plan | Score | Signals |
|---|---|---|---|
| ws_0077 | pro, 100+ | 75 | usage −71%, thumbs down +34 pts, active users −38% |
| ws_0041 | enterprise, 100+ | 60 | usage −66%, thumbs down +46 pts |
| ws_0051 | enterprise, 1–5 | 60 | usage −67%, thumbs down +24 pts |

24 of the 45 high/medium workspaces have fewer than 20 votes in 8 weeks: their quality signal is weak.

### Bonus — engineering merge lead time

Typical merge lead time over the last 8 weeks ranges from ~7 h (`product_integrations`,
`platform_data`) to ~14 h (`platform_infra`, which also has a week with a 176 h p90).
`platform_data` has the most PRs still open at the end of the period (19, including one
merged on 20 April, just after the window).

---

## Setup

Requirements: Python 3.10–3.12 and Git. On macOS the system `python3` is 3.9, which is too
old: use `uv` or a Homebrew `python3.12`. All commands run from the repository root (the
sources read `data/*.csv` with a path relative to it).

```bash
uv venv .venv --python 3.12           # or: python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt       # dbt-core 1.12, dbt-duckdb 1.11 (with uv: uv pip install ...)
dbt deps                              # installs dbt_utils (pinned, from GitHub)
dbt build                             # dev target: builds models, runs tests
dbt docs generate && dbt docs serve   # documentation and lineage in the browser
```

`profiles.yml` is in the repository root (dbt looks there first) and writes a local DuckDB
file, `lexroom.duckdb`. No credentials are needed. Two targets:

| Target | Command | Schemas |
|---|---|---|
| `dev` (default) | `dbt build` | `dev_staging`, `dev_intermediate`, `dev_marts` |
| `prod` | `dbt build --target prod` | `staging`, `intermediate`, `marts` |

To run an answer query: `dbt show --select q3_north_star_trend` (add `--limit 50` for more
than 5 rows), or execute the compiled SQL from `target/compiled/lexroom_analytics/analyses/`
in any SQL client.

Expected result of `dbt build`: all tests pass, with **4 warnings** — they are the known
data issues listed below, tested as `warn` on purpose.

---

## Project structure

```
data/             raw CSVs, as delivered (declared as dbt sources)
models/
  _shared_docs.md column descriptions used by several models
  staging/        sources + one model per source: type, dedup, standardise, flag  (views)
  intermediate/   int_ama_events_enriched: one event + its vote + its workspace  (view)
  marts/          the four tables below  (tables), their docs and the exposures
analyses/         answer queries for Q1, Q2, Q3 and the bonus
macros/           environment-aware schema names (dev / prod)
tests/            singular tests on business rules
```

Every model follows the dbt Labs layout: import CTEs at the top, one CTE per logical step,
and a closing `select * from final`.

| Mart | Grain (one row per…) | Answers |
|---|---|---|
| `fct_ama_module_weekly` | legal module and week, every week in the data | Q1 |
| `fct_ama_quality_weekly` | week | Q3 |
| `fct_workspace_health` | workspace, assessed at the end of the data | Q2 |
| `fct_engineering_team_weekly` | engineering team and week | Bonus |

`int_ama_events_enriched` (one row per AMA event) is the single place where an answer is
joined to its vote and customer, so every mart computes quality in the same way.

---

## Design decisions and trade-offs

**Sources, not seeds.** dbt recommends seeds for small, static lookup data, not for raw
data. The CSVs are therefore declared as **sources** and read in place by dbt-duckdb
(`read_csv` with `external_location`), so staging uses `source()` exactly as it would on the
BigQuery tables fed by Pub/Sub. Every column is read as text and **typed in staging**, the
first layer that owns the data, so loading never depends on type inference. In production
the sources would add a `freshness` check (e.g. warn after 6 hours without new events).

**Separate dev and prod.** `generate_schema_name` prefixes schemas with the target schema
on every target except `prod` (`dev_marts` vs `marts`): a development run can never
overwrite the tables that CS or Product read. On BigQuery the same macro maps to datasets,
and each developer would get their own prefix.

**Intermediate as a view, not ephemeral.** An ephemeral model would also be testable (dbt
injects it as a CTE into the test query), but it exists only inside the compiled SQL of its
consumers: as a view it can be queried directly when a number needs explaining, and its
three joins are defined once instead of being pasted into the 3 marts and 4 tests that use
it. The one join that could silently multiply rows (event → feedback) lives here, and its
grain is protected by a `unique` test.

**Windows anchored to the data, Monday weeks, UTC.** "Last 8 weeks" is computed from
`analysis_end_week` (a project variable), not `current_date`: on this dataset, today's
date would return nothing. All 11 weeks in the data are complete (Monday 2 Feb → Sunday 19 Apr).
Weeks start on Monday (ISO); on BigQuery `DATE_TRUNC(x, WEEK)` starts on **Sunday**, so the
port needs `WEEK(MONDAY)` or `ISOWEEK`.

**Non-voters are not judged.** Only ~26% of answers receive a vote. I checked whether
non-voted answers look technically like up- or down-voted ones: latency, cache share, number
of sources and tokens are **identical** across the three groups, so there is no observable
basis to infer how non-voters felt. Satisfaction is therefore measured **among voters only**,
always reported with the number of votes and the response rate. Inferring satisfaction for
non-voters would need behavioural signals this dataset lacks (re-asking the same question,
copying the answer, returning the next week).

**North Star: a multiplicative composite, no arbitrary weights.**

```
north_star_quality = voter satisfaction × grounded share
                   = (thumbs up / valid votes) × (answers with ≥1 source / answers)
```

| | |
|---|---|
| Grain | week (the same formula per module in Q1) |
| Window | ISO weeks, last 8 complete weeks |
| Direction | higher is better |
| Reads as | "estimated share of AMA answers that cite at least one source and are liked" |

Alternatives considered:
- *Weighted sum* (e.g. 0.8 × satisfaction + 0.2 × grounded): the weights are arbitrary, and a
  component near 99% adds ~20 fixed points that flatten the trend.
- *A "delivered share" (1 − timeouts / answers)*: I first read the 900,000 ms latencies as
  timeouts, but the data contradicts it (see *Known data issues* #5). With no reliable signal
  of an answer not arriving, a delivery component would measure nothing.
- *Per-event "good answer" rule*: counts non-voted answers as good, i.e. judges non-voters.
- *Satisfaction alone*: simplest, but not composite, and blind to outages.

Trade-offs: the product assumes the components are independent, and today the grounded share
sits at ~99–100%, so the metric moves almost entirely with satisfaction. It is kept as a
**guardrail**: a wave of ungrounded answers would show up immediately. A delivery guardrail
would need a real error or timeout event from the backend.
Latency is *not* in the formula: valid latencies are all under 10 s and do not differ
between liked and disliked answers, while thumbs-down reasons point at content.

**Rates from counts (ratio of sums).** Weekly and per-module rates are computed from summed
counts, never by averaging lower-level rates, so every answer weighs the same.

**Small samples.** A rate on a handful of votes is mostly noise: the standard error of a
proportion is about √(p(1−p)/n), roughly ±18 pts at n = 5 and ±3 pts at n = 200.
- Q1/Q3 rows with fewer than 50 votes are flagged `is_low_sample` rather than hidden.
- In Q2 the thumbs-down share is **smoothed** (empirical-Bayes shrinkage):
  `(thumbs_down + k × global_rate) / (votes + k)`, with `k = 10`, close to the median number
  of votes of a scored workspace in the earlier 4-week window (12): a typical account weighs
  half its own rate and half the average. Across all workspaces the median is much lower
  (3.5), which is exactly why the smoothing is needed. A workspace with 2 votes is pulled towards the average; one with
  200 votes keeps essentially its own rate. Without it, a single thumbs-down could make a
  tiny workspace look like the worst account. Workspaces with fewer than 20 votes over the
  8 weeks are flagged `is_low_sample`; below 10 answers in the earlier 4 weeks they get no
  score at all (see the next point), but they stay in the table with the reason.

**Q2 risk score: rule-based, each workspace against itself.** Last 4 complete weeks vs the 4 before,
only for workspaces with **at least 10 answers in the earlier 4 weeks** (`min_answers_for_risk`):

| Signal | Rule | Points | Why |
|---|---|---|---|
| Usage drop | answers down > 50% | 35 | earliest sign of churn |
| Quality drop | smoothed thumbs-down share up > 10 pts | 25 | the experience itself is worse |
| Slower answers | median latency up > 30% | 15 | degraded experience even without votes |
| Fewer people | active users down > 30% | 15 | usage concentrates on fewer people, the account gets fragile |
| Ungrounded answers | > 10% of recent answers without sources | 10 | for legal RAG, an unsourced answer is a quality risk |

Rules rather than a model: they are transparent, easy to challenge with CS, and there is no
labelled churn history to train or validate a model. Plan and firm size are *not* in the
score; they are columns CS can use to prioritise.

The volume threshold exists because, on tiny accounts, the rules measure noise: going from
1 answer to 0 reads as "usage −100%" and "active users −100%", 50 points, *high* risk. Before
the threshold, 16 of the 35 high-risk workspaces had fewer than 10 answers in the earlier
4 weeks. Unscored workspaces are not hidden: `risk_band` gives the reason (`low_volume`,
`new`, `returning`, `dormant`, `never_active`) and the volumes stay visible. `dormant`
accounts (active earlier, silent for the whole 8 weeks) are past the warning stage and are
listed at the end of the Q2 query.

The thresholds are **absolute**. Because the whole platform lost 66% of its usage, most
workspaces trigger the usage signal. I considered a relative signal (usage drop worse than
the platform's), which would flag 28 of the 47 scored workspaces instead of 45, but kept the
absolute one: the job of this mart is to surface the problem faithfully, and the
prioritisation belongs to CS.
The relative view is still provided as an informational column, `usage_change_vs_platform_pts`.

**Privacy.** `free_text` is dropped in staging (only a `has_free_text` flag is kept). In this
dataset it contains only 10 generic sentences, but in production it is free text written by
lawyers and could contain client names or case details. IDs are pseudonymous; 19 workspaces
have a single user account (21 counting only accounts that are not deleted), which would
matter if names were ever joined in. The 26 deleted users have no events, consistent with
deletion-on-request; 2 of them still have a feedback, both pointing to non-existent events
(issue #7).

---

## Known data issues

| # | Issue | Rows | Decision |
|---|---|---|---|
| 1 | Exact duplicate events / feedbacks | 5 / 15 | Deduplicated in staging (identical rows, no information lost) |
| 2 | `module_tag` casing variants and `civil` instead of `civile` | 247 events | `lower(trim())`, `civil` → `civile` |
| 3 | `thumbs` outside ±1 (values −2, 0, +2) | 16 feedbacks | Kept with `is_valid_thumbs = false`, excluded from metrics. They come from 16 different users who otherwise vote ±1, spread over time, never with a reason: more likely recording errors than a 5-point scale (0.5% of votes; either reading changes nothing) |
| 4 | Negative latency | 33 events | Latency set to NULL (`latency_status = 'negative'`); the event is kept |
| 5 | Latency exactly 900,000 ms (15 min) | 28 events | **Not** a timeout: 4 are cached answers (cached p99 ~230 ms) and 6 received a vote, so the answer reached the user. Read as a placeholder value: latency NULL (`latency_status = 'sentinel'`), the event is kept and counts as a normal answer. The meaning is undocumented — to confirm with Engineering |
| 6 | Latency exactly 45,000 ms on cached answers | 5 events | Not credible for a cache hit (median ~120 ms): latency NULL, event kept |
| 7 | Feedback pointing to non-existent events (`_orphan` suffix, all at 00:00:00) | 50 | Kept in staging, dropped from module/workspace metrics (their module is unknown). `relationships` test as warn |
| 8 | Events / users on non-existent workspaces (`ws_9000`–`ws_9002`) | 8 / 3 | Kept, flagged `is_unknown_workspace`; not in Q2 (no account to act on). Test as warn |
| 9 | Events before the user's `created_at` | 817 events, 71 users | All `users.created_at` values are at midnight, i.e. truncated: the event timestamp is trusted, the mismatch is flagged |
| 10 | Events before the workspace `signup_date` | 3 workspaces | Same as #9 |
| 11 | Missing `country` | 3 workspaces | `'unknown'` |
| 12 | Thumbs-down without `reason_tag` | 173 (175 before deduplication) | Kept NULL = "no reason given". Note: `reason_tag` and `free_text` often disagree (e.g. "too slow" is tagged `slow` only once in 12), so reasons are indicative |
| 13 | Unmerged PRs | 65 of 520 | `merged_at` NULL; lead time on merged PRs only, reported next to open PRs and their age to offset the optimistic bias |
| 14 | PR merged after the end of the data window | 1 (20 April) | Counted as open at the end of the last week, not as merged: the mart describes the state at the window end |

---

## Tests and what they protect

| Test | Protects against |
|---|---|
| `not_null` on every source key | a broken export or event without an identifier |
| `unique` + `not_null` on every staging key | duplicates re-entering from the event stream |
| `unique` on `int_ama_events_enriched.event_id` | an event getting two feedbacks and multiplying every metric (fan-out) |
| `unique_combination_of_columns` on module × week, team × week | grain violations in the weekly marts |
| `accepted_values` on `module_tag` (error) | a new spelling creating a phantom module in Q1 |
| `accepted_values` on `thumbs` (warn) | new off-schema vote values; current ones are known |
| `relationships` on events/users/feedback (warn where issues are known) | orphan keys; `warn` because the current orphans are understood and handled |
| `assert_marts_reconcile_with_events` | answers lost or duplicated between the event model and the marts |
| `assert_quality_metrics_are_rates` | a formula or denominator error pushing a rate outside [0, 1] |
| `assert_clean_latency_is_plausible` | the latency cleaning logic regressing (negative, 900,000 ms, 45,000 ms on cache) |
| `assert_event_workspace_matches_user_workspace` | activity attributed to the wrong customer |
| `assert_feedback_not_before_event` | broken event/feedback timestamps |
| `assert_feedback_thumbs_up_has_no_reason` (warn) | a feedback UI recording reasons on positive votes |
| `assert_risk_score_in_range` | errors in the scoring rules; a score on a workspace that should not be scored, or a missing one |
| `assert_engineering_mart_reconciles_with_prs` | merged PRs lost by a week spine that does not cover the data, or duplicated by a join |

No blanket `not_null`: nullable columns with meaning (`reason_tag`, `merged_at`, latency after
cleaning) are left alone, because a test that fails for legitimate data trains people to ignore tests.

---

## Answer queries

| Question | Query |
|---|---|
| Q1 trend | [`analyses/q1_module_quality_trend.sql`](analyses/q1_module_quality_trend.sql) |
| Q1 focus | [`analyses/q1_module_focus.sql`](analyses/q1_module_focus.sql) |
| Q2 | [`analyses/q2_workspaces_at_risk.sql`](analyses/q2_workspaces_at_risk.sql) |
| Q3 | [`analyses/q3_north_star_trend.sql`](analyses/q3_north_star_trend.sql) |
| Bonus | [`analyses/bonus_engineering_lead_time.sql`](analyses/bonus_engineering_lead_time.sql) |

---

## Porting to BigQuery

The logic is portable; the main changes would be:
- `date_trunc('week', x)` → `DATE_TRUNC(x, WEEK(MONDAY))` (BigQuery weeks start on Sunday)
- `median()` / `quantile_cont()` → `APPROX_QUANTILES()` or `PERCENTILE_CONT()`
- `count(*) filter (where …)` → `COUNTIF(…)`
- `x at time zone 'UTC'` → `TIMESTAMP` columns are already UTC in BigQuery
- sources: `external_location` → the Pub/Sub tables, with `freshness`; incremental models on
  the event tables to limit scanned bytes (cost)

---

## What I would do next

- **Confirm the open assumptions with the data owners**: what 900,000 ms and 45,000 ms mean
  (and whether a real timeout/error event exists, to bring back a delivery guardrail),
  what `thumbs` −2/0/+2 are, why `users.created_at` is truncated, where the `_orphan`
  feedbacks come from.
- **Investigate the usage collapse** (−95% in 8 weeks) before anything else: is it real, a
  tracking change, or a data pipeline problem? It changes how every other number is read.
- **Behavioural quality signals** to cover non-voters: repeated questions within minutes,
  answer copied/exported, return the following week.
- **Validate the risk score** against actual churn or downgrades once the history exists,
  and tune thresholds and weights with CS.
- **Confidence intervals** (e.g. Wilson) instead of a binary small-sample flag.
- **Production hardening**: source freshness, incremental event models, CI running
  `dbt build` on pull requests, and a semantic layer so the North Star is defined once for
  every tool.
- **dbt unit tests** (dbt ≥ 1.8) on the deterministic logic: the risk-score rules and the
  latency classification, tested on hand-made inputs rather than on today's data only.
- **dbt Labs folder layout**: `staging/lexroom/` with `_lexroom__sources.yml` and
  `_lexroom__models.yml`, and marts grouped by business area (`product/`,
  `customer_success/`, `engineering/`). Not worth the churn at 10 models, useful past ~20.
- **Model contracts** on the marts (`contract: enforced`), once a BI tool or another team
  depends on their columns.
- **Bonus**: real DORA metrics need deploy and incident data; merge lead time is a proxy.

---

## How AI was used

I used Claude (Anthropic) throughout the case, in three phases.

**1. Exploring the data.** At the start I used it to profile the five files quickly:
row counts, duplicates, null and out-of-range values, orphan keys, timestamp ranges and
distributions. Most of the *Known data issues* above surfaced in this phase; I then checked
each one myself before deciding how to handle it.

**2. Deciding the structure, then writing the code.** We worked out together how to
structure the project: the three layers, the grain of each mart, the North Star formula and
the risk-score rules. With those decisions taken, I wrote the first version of the code
myself.

**3. Reviewing it for standards, consistency and documentation.** I then had the AI review
the whole project, step by step, to bring it in line with the dbt Labs conventions and to
document it, and to verify every result against the data, so that each number in this README
can be traced back to a query:
- checking that each model keeps its grain (no fan-out, marts reconciling with the events);
- checking that the same definition of quality is used everywhere (North Star, Q1, Q2);
- aligning the project with the brief and the dbt Labs conventions: sources instead of seeds,
  separate dev and prod targets, the same CTE layout in every model, and a description on
  every source, model and column;
- challenging some of the design choices against the data, which led to the 900,000 ms
  values being treated as placeholders rather than timeouts and to a minimum volume before
  a workspace gets a risk score.
