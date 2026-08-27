# surveymap journal schema, v2

One tab-separated line per event, **23 columns**, header row present. Missing
value is a single period `.`. The journal is the package's one intermediate
artifact: the scan writes it, and the receipt, the HTML map, the mermaid text
and the Excel tracker are all read from it. **Read columns by name** from the
header row and tolerate unknown trailing columns.

| # | name | meaning |
|---|---|---|
| 1 | seq | event number, 1..N |
| 2 | class | `survey` `item` `cat` `cell` `resp` `note` |
| 3 | var | the item (or gate) variable name |
| 4 | position | 1-based order of the item among the mapped items |
| 5 | vallabel | item rows: the variable label; cat rows: the value's label text |
| 6 | value | cat/cell rows: the gate category value; sentinel `other` = pooled, `noanswer` = gate not answered |
| 7 | gatevar | cat/cell rows: the gate variable this category belongs to |
| 8 | n_asked | item rows: respondents in scope; cell rows: respondents in the lane |
| 9 | n_answered | nonmissing, and not a nonresponse code |
| 10 | n_nonresp | extended missings `.a`-`.z` plus any `nonresponse()` values |
| 11 | n_sysmiss | system missing `.` (where skip logic lands by default) |
| 12 | pct_answered | 100 * n_answered / n_asked, one decimal |
| 13 | rate | cell rows: 100 * n_answered / n_asked within the lane, one decimal |
| 14 | status | cell rows: `answered` `partial` `skipped`; item rows: `open` `gated` |
| 15 | gate | 1 on item rows that branch the flow (declared or detected) |
| 16 | gated_by | item rows: `voted==0` style summary of who is routed around this item; `;`-separated when more than one |
| 17 | pooled | 1 on cat rows folded into `other` by the prune rules |
| 18 | type | storage type (`byte` `int` `float` `long` `double` `str#`) |
| 19 | severity | `note` `warn` |
| 20 | flags | human-readable diagnostics; `!!` marks a warning; `; `-separated |
| 21 | w_asked | weighted respondents in scope (item rows) or in the lane/category; `.` when no weight was given |
| 22 | w_answered | weighted count of `n_answered`; `.` when no weight was given |
| 23 | pct_answered_w | 100 * w_answered / w_asked, one decimal; `.` when no weight was given |

**Columns 21 to 23 arrived in v2 and are appended, not inserted**, so a reader
written against v1 keeps working: the rule has always been to read by name and
tolerate unknown trailing columns. A journal written without a weight carries `.`
in all three, and every reader must treat that as "unweighted only" rather than
as zero.

## Row classes

- `survey` (exactly one, seq 1): `n_asked` = respondents in scope, `position` =
  number of mapped items, `flags` records the scan settings (prune, minn,
  maxcats, detect thresholds, nonresponse codes) so a later draw can say what
  the defaults were.
- `item` (one per mapped variable, in questionnaire order = dataset column
  order): the tracker row. `status` is `gated` when gated_by is nonempty.
- `cat` (one per response category of each gate, plus one `noanswer` row when
  any respondent left the gate blank): `n`/`pct` live in n_asked/pct_answered
  (the category's share of the scope). ALL categories are journaled; `pooled`
  marks the ones the current prune rules would fold into `other`. There is no
  pre-aggregated `other` row: the reader folds pooled rows itself, so prune
  settings can change at draw time without a rescan.
- `cell` (one per gate-category x item within the gate's segment): the lane
  cell. `status`: `skipped` when rate <= the skip threshold, `answered` when
  rate >= 80, else `partial`.
- `resp` (v0.5.0, only when the scan ran with `responses(k)`): one row per
  distinct answer of each numeric item, up to a hard cap of 30 distinct
  values (past the cap the item gets a `note` advising banding instead).
  `n`/`pct` live in n_asked/pct_answered; the percentage's denominator is
  the people the item was put to (answered plus declined), so an item's
  response shares, its pooled remainder and its declined share add to 100.
  ALL values are journaled and `pooled` marks the ones ranked below the
  scan's `responses(k)`, mirroring the `cat` convention: the reader folds.
- `note`: anything worth keeping that is not a row above (auto-detection
  summary, pooling notice past the hard cap, string gates declined).

## Semantics every reader shares

- Items run LEFT TO RIGHT in dataset column order; the flow is linear except
  inside a gate's segment.
- A gate's segment starts at the item after the gate. A DECLARED gate's
  segment runs to the item before the next declared gate, or the last item.
  A DETECTED gate's segment runs to the last item whose gated_by names it.
  Segments do not nest in v1: lanes split at the gate, run the segment, and
  merge before the next gate.
- Lanes partition the scope: kept categories + `other` (pooled) + `noanswer`.
  Lane counts must sum to the survey `n_asked`.
- Skip detection: category v of gate g "routes around" item i when the answer
  rate of i within g==v is <= dlow (default 2%) while the rate within the
  rest of g's answered categories is >= dhigh (default 50%). Detection is
  evidence from the data, not the questionnaire spec, and the receipt says so.
- The single accent colour is `#4a6d8c`. `!!` warnings are text, never colour
  alone. Ghost (dashed, grey) boxes mark cells `skipped` by routing.

## Reserved-word rule

No journal column may be named a Stata reserved word (`using` burned mergemap:
`import delimited` silently renames it and readers die). None above is.
