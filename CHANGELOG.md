# Changelog

All notable changes to surveymap. Dates are the day the work landed locally.

## 0.4.0 - 2026-08-24

### Added

- `layout(vertical)` draws the map top to bottom in both HTML and mermaid,
  with one swimlane `subgraph` per lane. A report page scrolls down, so a long
  instrument fits it better on its side. Both layouts read the same journal.
- `branch()` bands a continuous item on the fly: `cut(25 35 45 65)` for breaks
  you name, `q(4)` for quantiles. Neither drops anybody, unlike
  `egen cut, at()`, so the lanes still add up to the sample. There is no
  default cut, because where to divide age is a decision about the population
  being described.
- `profile()` splits the map by what a respondent did rather than by what they
  answered: `declined`, `refused`, `dontknow`, `asked`, `answered` and
  `breakoff`. The first three are shares of the items each respondent was
  actually asked, since skip logic asks different people different numbers of
  questions and a raw count is not comparable between them. `refusedcode()`
  and `dkcode()` name the survey's own codes rather than guessing them.
- The default share split is at zero and nowhere else, giving `none` and
  `at least one`. Any other threshold is a decision about what counts as a
  lot, and the journal records when a default rather than the analyst chose
  the bands.
- A derived gate is drawn with its own node shape and labelled
  `derived, not asked`, so a reader cannot take it for a question somebody
  was asked. Its caveat travels in the journal, including the warning that a
  weighted figure inside a behaviour-defined lane describes the weighted
  sample rather than a population subgroup.
- `profile(exaggerator)` and `profile(careless)` are refused with the reason
  and the citations. Nothing in a set of answers separates someone who
  over-reports a socially desirable answer from someone who reports it
  honestly, and a flag built from responses alone would reproduce the
  demographics of the behaviour instead.

### Fixed

- Lane order in every mermaid map. Sibling subgraph order depends on whether
  the lanes rejoin the spine: with a merge the declaration order is kept,
  without one mermaid reverses it. A banded gate could therefore read right to
  left. The renderer now compensates only in the case that needs it, and the
  battery pins both.
- A value label read outside the frame it was defined in came back empty, so a
  banded gate's lanes were labelled with their band numbers.

### Testing

- 236 checks, passing on Stata 16.1 and 19.5.

## 0.3.0 — 2026-08-24

### Added

- **`export(png)` and `export(svg)`**, drawing the same figure through Stata's
  own graph engine for a paper or a slide. Both come from one `twoway` call, so
  asking for either writes both. A figure is readable up to a point: past
  `maxnodes()` drawn columns (default 14) it stops and names the HTML page,
  which scrolls and keeps the full record on hover. A fan counts as one column
  however many items sit inside it, so the limit is on what the eye has to
  follow and not on the item count.
- **A gallery.** `gallery/runall.do` rebuilds every example artifact from one
  fake survey: three journals, three HTML maps, a fragment, mermaid text, a
  PNG and an SVG, the Excel tracker, a `verify()` run against a deliberately
  wrong declared table, and an index page. It counts its own failures and
  prints a verdict, because a Stata do-file can abort and still leave the
  runner reporting success.
- **The fragment-scoping check now ships with the package**, at
  `tests/embedcheck/check_embed_scoping.py`. It refuses a fragment carrying an
  unscoped selector, a script, an un-namespaced id, or a page wrapper, and its
  exit status can gate a build.

### Fixed

- The figure's caption used `char(183)` for a middle dot, which is a lone
  `0xB7` byte and invalid UTF-8, so `graph export` refused the file with
  "failed to export to the specified format" after drawing it successfully.
  `uchar(183)` is the Unicode form.
- A `{bf:}` directive in the help file spanned a line break, which SMCL does
  not allow, so it rendered literally in the plain-text help.

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
