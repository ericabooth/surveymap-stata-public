# Changelog

All notable changes to surveymap. Dates are the day the work landed locally.

## 0.2.0 — 2026-08-23

Everything here came from running 0.1.0 against a real poll (a 1,105-respondent
statewide survey, 229 columns) and finding out where it was awkward.

### Added

- **`pweight`s.** A weighted survey usually wants them, and both counts are now
  kept, because they answer different questions: the unweighted count describes
  the people interviewed, the weighted count describes the estimate. The journal
  gains `w_asked`, `w_answered` and `pct_answered_w` (appended, so a reader
  written against v1 is unaffected), and the receipt gains a `wtd%` column. A
  respondent whose weight is zero leaves the scope, exactly as they leave a
  weighted estimate, and the weight itself is never mapped as an item.
- **`exclude(varlist)` and `nostrings`.** A delivered survey file is wider than
  the questionnaire: record ids, sample-frame columns, interviewer admin, and
  verbatim text. Mapping all of it gives a picture with more columns than
  structure, and columns that were never questions can satisfy the routing test.
- **`verify(filename)`.** A survey project usually keeps its own table of the
  skip logic. That table and the map are two independent accounts of the same
  thing, so `verify()` compares them item by item and returns the count that
  disagreed in `r(N_mismatch)`. Run against a real project's file it matched 12
  of 14 declared gates exactly, the other two being verbatim items that
  `nostrings` had excluded. It also runs in reverse: on a new delivery, scan
  first and use the `gated_by` output as the draft of the skip-logic table.

### Changed

- The journal is schema v2, 23 columns. The three weighted columns are appended
  after `flags`, never inserted, so the rule that readers read by name and
  tolerate unknown trailing columns keeps a v1 reader working.
- The receipt lays its columns out at fixed positions, so a long routing
  expression cannot run into the column beside it.
- **A weighted journal is drawn the way survey results are reported**: unweighted
  counts, weighted percentages, and a caption that says which is which. Before
  this, a weighted scan produced a map of unweighted numbers with nothing on the
  page to say so, which is a result somebody could have published as weighted.

### Documentation

- The help file and README gain three sections written from the applied example:
  pointing the command at a real survey file, weights, and checking the map
  against a questionnaire. The main lesson is that an item can be blank for
  three different reasons and only one of them is skip logic; the other two are
  a sample frame that does not apply to a respondent, and a split ballot.

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
