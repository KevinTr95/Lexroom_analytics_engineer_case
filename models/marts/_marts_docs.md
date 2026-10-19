{% docs __overview__ %}
# Lexroom: AMA analytics

This project turns events from **AMA** (the legal question-answering assistant) into tables
that answer three business questions:

| Question | Table |
|---|---|
| Q1, Product: how is AMA quality trending for each legal module? | `fct_ama_module_weekly` |
| Q2, Customer Success: which customers have a deteriorating experience? | `fct_workspace_health` |
| Q3, Leadership: one number for AMA quality | `fct_ama_quality_weekly` |
| Bonus, Engineering: how fast do code changes get merged? | `fct_engineering_team_weekly` |

Data flows from the **sources** (the raw tables) through three layers: **staging** (typing
and cleaning each source table), **intermediate** (one event enriched with its vote and
customer) and **marts** (the tables above). Every table states in its description what one
row represents, and every column is described.

Weeks start on Monday (UTC). The "last 8 weeks" run from 23 February to 13 April 2026:
they end with the last week in the data, not with today's date.
{% enddocs %}

{% docs int_ama_events_enriched %}
One row per **AMA answer** (event), with the vote it received and the customer's attributes.

It is the shared base of every AMA table, so quality is always computed the same way.

- An event has at most one vote. Only +1 (thumbs up) and -1 (thumbs down) votes count.
- Feedback pointing to a non-existent answer does not appear.
- If the customer is missing from the workspaces table, its attributes are empty and
  `is_unknown_workspace` is true.
{% enddocs %}

{% docs quality_score %}
**Estimated share of good answers**: the probability that an AMA answer cites at least
one source and is liked.

`voter satisfaction x grounded share`

- **Voter satisfaction** = thumbs up / valid votes. People who do not vote are not judged.
- **Grounded share** = answers with at least one retrieved source / answers.

Today the grounded share is close to 100%, so the value mostly follows satisfaction;
it acts as a safeguard in case answers stop citing sources.
Read it together with the number of votes: below 50 votes a week the value is unstable.
{% enddocs %}

{% docs fct_ama_module_weekly %}
One row per **legal module and week**, for every week in the data, including weeks with
no activity.

Use it to compare module quality over time (Q1). For each module and week: answers, votes,
the estimated share of good answers and its components, median latency, and the reasons
behind thumbs down.

- Quality uses the same formula as the North Star (`quality_score`).
- Thumbs-down reasons are indicative: they often disagree with the written comment.
- Less-used modules get only a few dozen votes a week: check `is_low_sample`.
{% enddocs %}

{% docs fct_ama_quality_weekly %}
One row per **week**. Holds the **AMA North Star**, `north_star_quality`.

It is the estimated share of good answers across the whole platform, computed from the
week's counts: every answer weighs the same, whatever its module.

Next to it are the components, the number of votes and two usage measures (active customers
and users): the North Star measures quality, not how much AMA is used, and the two trends
should be read together.
{% enddocs %}

{% docs fct_workspace_health %}
One row per **customer** (workspace), assessed at the end of the data.

Use it to see which customers have a deteriorating experience (Q2). Each customer is compared
with itself: the last 4 weeks against the 4 before.

- `risk_score` runs from 0 to 100 and is explained by `risk_signals`.
- Over the period, usage of the whole platform drops by about two thirds, so many customers
  come out at risk. `usage_change_vs_platform_pts` shows, as context, whether a customer is
  doing better or worse than average.
- With few votes the quality signal is unreliable: check `is_low_sample`.
- Customers with fewer than 10 answers in the previous 4 weeks get no score (`risk_score`
  is empty): `risk_band` says why.
{% enddocs %}

{% docs risk_band %}
For scored customers, the level of risk:

| Value | Meaning |
|---|---|
| high | score 50 or more |
| medium | score 25 to 49 |
| low | score below 25 |

For customers without a score, the reason:

| Value | Meaning |
|---|---|
| low_volume | fewer than 10 answers in the previous 4 weeks: too little to measure a trend |
| new | first ever answer in the last 4 weeks |
| returning | used AMA before, nothing in the previous 4 weeks, back in the last 4 |
| dormant | used AMA before, nothing at all in the last 8 weeks: most likely already lost |
| never_active | never used AMA |
{% enddocs %}

{% docs risk_score %}
Risk score from 0 to 100, a sum of simple rules:

| Signal | Rule | Points |
|---|---|---|
| Usage drop | answers down by more than 50% | 35 |
| Quality getting worse | (smoothed) thumbs-down share up by more than 10 points | 25 |
| Slower answers | median latency up by more than 30% | 15 |
| Fewer people | active users down by more than 30% | 15 |
| Answers without sources | more than 10% of recent answers have no source | 10 |

The thumbs-down share is **smoothed**: each customer gets 10 extra "average" votes, so that a
customer with 2 votes does not look disastrous because of a single thumbs down.

Empty for customers with fewer than 10 answers in the previous 4 weeks: on such small
volumes, going from 2 answers to 0 would look like a 100% drop. See `risk_band`.
{% enddocs %}

{% docs fct_engineering_team_weekly %}
One row per **engineering team and week** (bonus, a DORA-style metric).

- **Merge lead time**: hours between opening a change (pull request) and merging it into the
  main code, median of the PRs merged in the week. There is no release data, so we stop at
  the merge.
- **PRs open at week end** and their median age: the lead time only counts PRs that made it
  through, so on its own it is optimistic. Stuck PRs show up here.
{% enddocs %}
