# Changelog

All notable changes to surveymap. Dates are the day the work landed locally.

## 0.1.0 — 2026-08-23

First release.

### The command

- `surveymap` scans the survey in memory and writes a journal: for every item,
  who was in scope, who gave a real answer, who declined (extended missings and
  any `nonresponse()` codes), and who was never shown it. The three are counted
  apart, because a refusal and a skip look identical in a percent-missing
  summary and call for opposite responses.
- Routing is read out of the answers: a category is recorded as routing people
  around a later item when that lane answered it at most 2% of the time while
  the other lanes answered at least 50%. `detect(# #)` moves both thresholds,
  `noautodetect` turns inference off. The receipt says once that this is
  evidence and not a questionnaire spec.
- `branch()` names the gates to split the flow by, as `branch(party)`,
  `branch(party = 1 3 4)`, `branch(party = 1/3 5)`, or several gates comma
  separated in one option. Lanes partition the sample: kept categories, one
  pooled `other`, and one `no answer` for people who left the gate blank.
- A gate's lanes cover the items it routes, wherever those sit, so a party
  question asked early still owns the primary-turnout questions much later. An
  item routed by two gates belongs to the nearer one, which keeps lanes from
  nesting.
- `prune()`, `minn()` and `maxcats()` fold small categories into `other`. The
  journal keeps every category and the reader folds, so a drawing can be re-cut
  at a different setting without reading the data again.

### The outputs

- A Results-window receipt, one line per item, with what each item cost in
  answers and who was routed around it.
- `surveymap draw`: a self-contained HTML flow map, no internet and no
  JavaScript, items left to right with lanes at each gate and dashed grey boxes
  for cells a lane was routed around. `embed` writes a scoped fragment for a
  report page. `export(mermaid)` writes text GitHub and Quarto render.
- `surveymap export`: an Excel tracker of three sheets, `sm_items`,
  `sm_branches` and `sm_flow`, with counts as numbers; also `.dta` and `.csv`.
- `surveymap demo` writes a small survey, scans it, and shows the whole loop.

### Working with datadictionary

- `datadictionary` gains `flow()`, which reads a surveymap journal and adds
  `pct_answered_sm` and `skipped_by_sm` to its Variables sheet and its saved
  dataset, matched on variable name. A file that is not a surveymap journal
  gives a clear `r(459)`.
- `surveymap export, dictionary()` adds the three `sm_` sheets to an existing
  datadictionary workbook and leaves every sheet it wrote untouched.
- Neither package requires the other to be installed; the join is a plain TSV
  read on one side and a sheet write on the other.

### Testing

- 113 checks across 16 blocks, on Stata 16.1 and 19.5, over a 1,200-respondent
  fake survey whose routing, refusal and screener patterns are known in advance
  (`tests/FAKE_SURVEY_SPEC.md`).
