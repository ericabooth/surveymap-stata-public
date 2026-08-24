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
    branch(party) branch(voted)      or repeated options

A declared gate's lanes run to the next declared gate or the end.  Without
branch(), the two detected gates that route around the most respondents are
drawn (a note row and the receipt say which, and how to override).  String
gates are declined with a warning (survey gates are coded numeric).

## Pruning (defaults, all changeable at scan OR draw/export time)

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
