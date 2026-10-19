{#- Column descriptions shared by several models: defined once, reused with doc(). -#}

{% docs col_event_id %}
Identifier of an AMA event: one question asked to AMA and its answer.
{% enddocs %}

{% docs col_user_id %}
Identifier of the user (a lawyer or legal professional). Pseudonymous.
{% enddocs %}

{% docs col_workspace_id %}
Identifier of the workspace: the customer account, a law firm or an in-house legal team.
{% enddocs %}

{% docs col_module_tag %}
Legal module the question belongs to: civile, penale, tributario, lavoro, amministrativo,
societario. Spelling variants in the raw data are standardised.
{% enddocs %}

{% docs col_country %}
Country of the workspace: IT, DE, ES, or 'unknown' when missing in the source.
{% enddocs %}

{% docs col_plan %}
Commercial plan of the workspace: free, pro or enterprise.
{% enddocs %}

{% docs col_firm_size_bucket %}
Size of the firm: 1-5, 6-20, 21-100 or 100+ people.
{% enddocs %}

{% docs col_latency_status %}
Whether the measured latency can be trusted: 'valid'; 'negative' (impossible duration);
'sentinel' (exactly 900,000 ms, a placeholder value); 'implausible_cache' (45,000 ms on a
cached answer).
{% enddocs %}

{% docs col_response_latency_ms %}
Time to answer, in milliseconds. Empty when the measurement is not valid (see `latency_status`).
{% enddocs %}

{% docs col_reason_tag %}
Reason given with a thumbs down: wrong_answer, incomplete, hallucination, slow, other.
Empty = no reason given. Indicative only: it often disagrees with the written comment.
{% enddocs %}

{% docs col_week_start %}
Monday of the week (ISO week, UTC).
{% enddocs %}

{% docs col_answers %}
Number of AMA answers (one per question asked).
{% enddocs %}

{% docs col_votes %}
Number of valid votes (thumbs up or thumbs down) on those answers. About a quarter of the
answers get a vote.
{% enddocs %}

{% docs col_thumbs_up %}
Number of thumbs up.
{% enddocs %}

{% docs col_thumbs_down %}
Number of thumbs down.
{% enddocs %}

{% docs col_answers_with_sources %}
Number of answers that cite at least one source retrieved by the RAG.
{% enddocs %}

{% docs col_median_latency_ms %}
Median time to answer, in milliseconds, over the answers with a valid latency.
{% enddocs %}

{% docs col_response_rate %}
Valid votes / answers: the share of answers that got a vote. If it shifts a lot,
satisfaction becomes less comparable over time.
{% enddocs %}

{% docs col_satisfaction_rate %}
Thumbs up / valid votes, from 0 to 1. Only reflects the people who vote.
{% enddocs %}

{% docs col_grounded_rate %}
Answers citing at least one source / answers, from 0 to 1.
{% enddocs %}

{% docs col_is_low_sample_week %}
True when the row has fewer than 50 votes: the rates are unstable and should be read with care.
{% enddocs %}
