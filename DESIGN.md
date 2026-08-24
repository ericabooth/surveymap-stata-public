# surveymap design (v0.1.0)

Author: Eric Booth.  Sibling of mergemap: journal-first architecture, the same
output media, documentation and testing conventions.

## What it does

The data in memory are a survey: one row per respondent, one column per item,
columns in questionnaire order.  `surveymap` reads the data (never modifies
them), computes how respondents moved through the instrument, and writes a
journal (TSV).  From the journal: a Results-window receipt, a self-contained
HTML flow map (no internet, no JavaScript), a mermaid text export, and an
Excel tracker that can sit inside a datadictionary workbook.

"Movement" = who was asked, who answered, who was routed around an item by
skip logic (visible in data as system missings concentrated in a gate
category), and who declined (extended missings / refused / don't know).

## Syntax

    surveymap [varlist] [if] [in] [, branch(spec) out(journal.tsv)
        nonresponse(list) prune(#) minn(#) maxcats(#) detect(# #)
        noautodetect noreceipt replace]
    surveymap draw    [journal] [, export(html|mermaid) saving() layout()
        prune(#) minn(#) maxcats(#) noprune name() noopen replace embed]
    surveymap export  [journal] [, saving(x.xlsx|.dta|.csv) dictionary(dd.xlsx)
        format() prune(#) minn(#) maxcats(#) noprune replace]
    surveymap receipt journal
    surveymap demo    [, folder() replace]
    surveymap clear

Default subcommand = scan of the data in memory (mirror of mergemap: the
bare command produces the journal + receipt, executes nothing else, changes
nothing).  $SM_LASTJ remembers the last journal for draw/export/receipt.

## branch()

    branch(party)                 every category of party is a lane
    branch(party = 1 3 4)         only these; the rest pool into "other"
    branch(party = 1/3 5)         numlists work
    branch(party = 1 3, voted = 1)   two gates in one option
    branch(party, voted)             two gates, every category of each

-syntax- cannot repeat an option, so several gates go in ONE branch(),
separated by commas.

A declared gate's lanes run to the next declared gate or the end.  Without
branch(), the two detected gates that route around the most respondents are
drawn (a note row and the receipt say which, and how to override).  String
gates are declined with a warning (survey gates are coded numeric).

## Pruning (defaults, all changeable at scan OR draw/export time)

prune() at scan time records the rule the readers inherit; the reader is
what folds, so one journal can be drawn at several prune settings without a
rescan.  Categories left out of an explicit branch(var = ...) keep list are
marked in the journal, because that is a statement about what the lanes are
and not a noise filter.

prune(5) = hide categories under 5% of scope; minn(30) = or under 30
respondents; maxcats(6) = keep the largest 6, pool the rest.  Pruned
categories fold into one "other" lane; respondents who left the gate blank
form a "no answer" lane.  Lanes always partition the sample.  noprune shows
everything.  The journal keeps ALL categories, so draw-time prune() needs no
rescan (same architecture as mergemap's draw-time cuts).

## Skip detection

Cell rate = % of the lane answering the item.  Category v routes around item
i when rate(i | g==v) <= dlow (2) and rate among g's other answered
categories >= dhigh (50).  detect(# #) sets the two thresholds;
noautodetect turns inference off (declared gates still draw lanes).
This is evidence from the data, not the questionnaire spec: an item everyone
in a category happened to skip is indistinguishable from routing, and the
receipt says so once.

## datadictionary connections (explicit, tested, no hard dependency)

1. surveymap export writes sheets sm_items / sm_branches / sm_flow.  With
   dictionary(file.xlsx) they are added to an EXISTING datadictionary
   workbook via sheetreplace; datadictionary's own sheets are untouched.
   The sm_items key column is `variable`, matching datadictionary's
   Variables sheet key, so Excel-side joins are one VLOOKUP.
2. datadictionary gains a flow(smjournal.tsv) option: it imports the
   surveymap journal's item rows (plain import delimited, no code
   dependency) and adds pct_answered / skipped_by columns to its Variables
   sheet and saving() dataset, matched on variable name.  A file that is
   not a surveymap journal is a clear r(459), not a crash.

## Related work (for the help file)

flowchart (Dodd; LaTeX/TikZ subject-disposition figures), direct_flow
(Pacheco/Martimbianco/Riera; systematic-review flowcharts), statflow
(Excel-refreshed flowcharts), sankey / alluvial (Naqvi; flow widths from
from/to/value data -- surveymap can export edges in that shape one day).
None reads routing out of the responses; that is surveymap's job, and the
box/lane form holds more per node than a ribbon can.

## Considered and not built

Decisions worth keeping, so they are not relitigated from scratch.

### Ribbon widths proportional to the count

Not built. Two reasons, both structural rather than aesthetic. A ribbon
diagram invites the reader to expect the widths at a node to add up, and on a
questionnaire they do not: the people who declined an item are a gap the eye
reads as attrition already accounted for. And on a 15 to 40 item instrument
the smallest flows fall below a pixel, so a path taken by nobody disappears,
which on a QC map is usually the finding you most wanted. `sankey` and
`alluvial` (Naqvi) and mermaid's `sankey-beta` are the right tools when two or
three transitions are the whole story.

### A dropout curve over item position

Not built, after prototyping it. The naive version -- respondents answering,
plotted against item position -- measures routing and attrition added
together, because a system missing in this package means "never shown", so a
filtered item looks exactly like a cliff. The fix is to plot what the
respondent was shown, which is `n_asked - n_sysmiss`, and that series is
non-monotone by construction on any instrument whose branches rejoin, so it
is not a survival curve and should not be drawn as one.

The series a reader actually wants, how many are still in the interview at
each position, is **not identified from the journal alone**: aggregate counts
per item cannot separate a respondent who was routed past an item from one who
had already stopped. An honest figure would draw it as a band with the range
printed in the risk row, and a band whose whole point is that the data cannot
say is a lot of figure for very little claim.

`surveymap band` covers the useful part: it shows not-shown and declined by
position, so a filter and a cliff are visibly different things rather than one
line going down. For the respondent-level question, `profile(breakoff)` lanes
the sample by where each respondent stopped, which is identified because it is
computed per respondent rather than reconstructed from margins.

If this is ever revisited: read `gated_by`, never plot `n_asked` (it is the
scope, and constant), and print the risk set under the axis the way Galesic
(2006, JOS 22(2):313-328) does, or the right-hand tail will be over-read.

### rankSpacing on the mermaid output

Tested, not adopted. Tightening it from 50 to 35 takes about 12% off the
printed height, and pulls the fan edges down through the lane titles, so a
lane heading gets a line drawn through it. Height is worth less than a legible
label. `curve: linear` WAS adopted: straight edges, because a path-following
diagram is read by tracing an edge and uniform curvature measurably hurts that
(Xu et al. 2012, IEEE TVCG 18(12):2449-2456).

## House rules (binding)

- Stata 16 floor, both test binaries:
  /Applications/Stata/StataMP.app/Contents/MacOS/stata-mp        (16.1)
  /Applications/StataNow/StataMP.app/Contents/MacOS/stata-mp     (19.5)
- Never touch the user's data: work in frames, tempfiles, preserve.
- No c(sortseed)/c(sortrngstate) (absent on 16.1); set seed only in demo
  fixtures.
- HTML: self-contained page, inline SVG, zero <script>, scoped CSS in embed
  fragments (.sm- prefix), accent #4a6d8c, !! never colour alone, tooltips
  keep the full record, one line per fact, click-to-open via
  {stata _sm_open:...} + $SM_LASTOUT, NEVER {browse "file://...} (aborts
  Stata on macOS).
- No AI attribution anywhere: files, headers, commits, metadata.
