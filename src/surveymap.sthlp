{smcl}
{* *! version 0.6.0  27aug2026  Eric Booth}{...}
{vieweralsosee "datadictionary" "help datadictionary"}{...}
{vieweralsosee "mergemap" "help mergemap"}{...}
{vieweralsosee "tabulate" "help tabulate"}{...}
{vieweralsosee "misstable" "help misstable"}{...}
{viewerjumpto "Quick start" "surveymap##quickstart"}{...}
{viewerjumpto "Installation" "surveymap##install"}{...}
{viewerjumpto "Syntax" "surveymap##syntax"}{...}
{viewerjumpto "Description" "surveymap##description"}{...}
{viewerjumpto "Reading the receipt" "surveymap##receipt"}{...}
{viewerjumpto "Branching" "surveymap##branch"}{...}
{viewerjumpto "How routing is found" "surveymap##detect"}{...}
{viewerjumpto "Pruning noisy branches" "surveymap##prune"}{...}
{viewerjumpto "Drawing the map" "surveymap##draw"}{...}
{viewerjumpto "The Excel tracker" "surveymap##export"}{...}
{viewerjumpto "Working with datadictionary" "surveymap##dd"}{...}
{viewerjumpto "Options" "surveymap##options"}{...}
{viewerjumpto "Examples" "surveymap##examples"}{...}
{viewerjumpto "Limitations" "surveymap##limits"}{...}
{viewerjumpto "Stored results" "surveymap##results"}{...}
{viewerjumpto "Related commands" "surveymap##related"}{...}
{viewerjumpto "Author" "surveymap##author"}{...}

{title:Title}

{phang}
{bf:surveymap} {hline 2} Map how respondents moved through a survey


{marker quickstart}{...}
{title:Quick start}

{pstd}
See it work on a survey you do not have to find first:{p_end}

{phang2}{stata "surveymap demo":. surveymap demo}{p_end}

{pstd}
Then, on your own data, one row per respondent and columns in the order the
questions were asked:{p_end}

{phang2}{cmd:. surveymap}{p_end}
{phang2}{cmd:. surveymap draw}{p_end}

{pstd}
Split the flow by the question that decides the rest of the interview:{p_end}

{phang2}{cmd:. surveymap, branch(party)}{p_end}
{phang2}{cmd:. surveymap draw}{p_end}

{pstd}
And keep the numbers as a workbook:{p_end}

{phang2}{cmd:. surveymap export, saving(flow.xlsx) replace}{p_end}


{marker install}{...}
{title:Installation}

{phang2}{cmd:. net install surveymap, from("https://raw.githubusercontent.com/ericabooth/surveymap-stata-public/main/") replace force}{p_end}

{pstd}
{cmd:surveymap} needs Stata 16 or later and installs nothing else. The HTML map
opens in any browser with no internet connection.{p_end}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:surveymap} [{cmd:scan}] [{varlist}] {ifin} {weight} [{cmd:,}
{opt br:anch(spec)} {opt prof:ile(spec)} {opt ref:usedcode(value)}
{opt dk:code(value)} {opt out(filename)} {opt non:response(numlist)}
{opt ex:clude(varlist)} {opt nostrings} {opt ver:ify(filename)}
{opt prune(#)} {opt minn(#)} {opt maxc:ats(#)} {opt resp:onses(#)}
{opt det:ect(# #)} {opt noautodetect} {opt noreceipt} {opt noprune} {opt replace}]

{pstd}
{cmd:pweight}s are allowed; see {help surveymap##weights:Weights}.{p_end}

{p 8 17 2}
{cmd:surveymap paths} {varlist} {ifin} {weight} [{cmd:,} {opt top(#)}
{opt out(filename)} {opt sav:ing(filename)} {opt titl:e(text)}
{opt nodr:aw} {opt noop:en} {opt replace}]

{p 8 17 2}
{cmd:surveymap draw} [{it:journalfile}] [{cmd:,} {opt exp:ort(html|mermaid|png|svg)}
{opt lay:out(horizontal|vertical)} {opt sav:ing(filename)} {opt prune(#)}
{opt minn(#)} {opt maxc:ats(#)} {opt noprune} {opt name(text)} {opt embed}
{opt maxn:odes(#)} {opt noopen} {opt replace}]

{p 8 17 2}
{cmd:surveymap band} [{it:journalfile}] [{cmd:,} {opt sav:ing(filename)}
{opt ti:tle(text)} {opt sub:title(text)} {opt not:e(text)} {opt names(spec)}
{opt area} {opt bar} {opt xsi:ze(#)} {opt ysi:ze(#)} {opt sc:ale(#)}
{opt nolegend} {opt replace}]

{p 8 17 2}
{cmd:surveymap export} [{it:journalfile}] [{cmd:,} {opt sav:ing(filename)}
{opt f:ormat(xlsx|dta|csv)} {opt dict:ionary(filename)} {opt prune(#)}
{opt minn(#)} {opt maxc:ats(#)} {opt noprune} {opt replace}]

{p 8 17 2}
{cmd:surveymap receipt} {it:journalfile}

{p 8 17 2}
{cmd:surveymap demo} [{it:foldername}] [{cmd:,} {opt fold:er(path)} {opt replace}]

{p 8 17 2}
{cmd:surveymap clear}

{synoptset 26 tabbed}{...}
{synopthdr:subcommand}
{synoptline}
{synopt :{opt demo}}write a small survey, scan it, and show the output{p_end}
{synopt :{opt scan}}read the data and write the journal {it:(the default)}{p_end}
{synopt :{opt draw}}draw the flow map: a browser page, or mermaid text{p_end}
{synopt :{opt band}}the band chart: one column per item, for a long instrument{p_end}
{synopt :{opt export}}the tracker: {cmd:.xlsx}, {cmd:.dta}, or {cmd:.csv}{p_end}
{synopt :{opt receipt}}reprint the receipt from a saved journal{p_end}
{synopt :{opt clear}}empty {cmd:$SM_LASTJ} so the next {cmd:draw} needs a filename; no file on disk is touched{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
Point {cmd:surveymap} at a survey in memory: one row per respondent, one column
per item, columns in the order the questions were asked. For every item you get
counts of who was in scope, who gave a real answer, who declined, and who was
never shown it, together with the earlier answers that routed people past the
later questions. Your data are read and not written to.{p_end}

{pstd}
A blank means three different things in a survey file, and you get a separate
count for each, because one "percent missing" figure hides the difference
between them:{p_end}

{synoptset 26 tabbed}{...}
{synopt :{bf:answered}}a real answer{p_end}
{synopt :{bf:declined}}an extended missing ({cmd:.a} to {cmd:.z}: don't know, refused) or a code you name in {opt nonresponse()}{p_end}
{synopt :{bf:not shown}}system missing ({cmd:.}), which is where skip logic lands{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
Which column the blanks fall in tells you what to do about them. Blanks under
{bf:declined} mean people saw the question and would not answer it, so look at
the wording. Blanks under {bf:not shown} mean the instrument never put the
question in front of them, so there is nothing to fix and no reason to report a
low response rate on that item.{p_end}

{pstd}
The scan writes one intermediate file, a tab-separated journal with a line per
event. Everything else you get, the receipt, the map, the mermaid text and the
Excel tracker, comes from that journal, so you can re-cut a drawing without
touching the data again.{p_end}


{marker start}{...}
{title:Where to start a map}

{pstd}
A survey with little skip logic draws as a single line of boxes, which answers
who was asked what and nothing else. The starting points below turn that line
into paths a reader can follow, and they combine freely.{p_end}

{pstd}
{bf:The response braid.} {cmd:surveymap paths} follows the answers instead of
the routing: every item in the list becomes a column, each of its {opt top(#)}
most common answers a block, and a ribbon between two blocks carries the
respondents who gave both answers on consecutive items, so the survey reads
left to right as a braid that splits and merges at every item. The remaining
answers pool into {bf:other answers}, and {bf:no answer recorded} holds
everyone with nothing on the item, including anyone the routing never showed
it. Every respondent in scope sits in exactly one block of every column, so
each column adds back to the sample. Under the figure, a table of the ten
most common complete paths, end to end. See
{help surveymap##paths:The paths subcommand}.{p_end}

{phang2}{cmd:. surveymap paths d3a q1 q2 q3, top(3) out(flows.tsv) saving(flows.html)}{p_end}

{pstd}
{bf:The spine with its splits.} {opt responses(#)} adds each item's {it:#}
most common answers to its box on the routing map, drawn as share bars, with
the rest pooled into {bf:other answers} and the declined share on its own
row. The denominator is the people the item was put to (answered plus
declined), so the rows inside a box account for everyone who saw the
question. Items with more than 30 distinct values (age in years) are skipped
with a note: band them with {cmd:branch(age = cut(...))} instead. String
items are skipped.{p_end}

{phang2}{cmd:. surveymap, responses(3)}{p_end}

{pstd}
{bf:One subgroup's path.} An {cmd:if} or {cmd:in} restriction traces the
respondents it selects through the questionnaire, on the paths view or the
scan, and the page says so: the journal records the expression, and the map
opens with {bf:scope: only respondents where ...} so nobody mistakes whose
path it shows.{p_end}

{phang2}{cmd:. surveymap paths q1 q2 q3 if inlist(party, 2, 3) & age > 40}{p_end}

{pstd}
{bf:The outlier paths.} {opt profile()} splits the routing map by what
respondents did rather than what they answered: the share of asked items they
declined, refused, or answered don't know, and where they stopped. See
{help surveymap##profile:Splitting by what the respondent did}.{p_end}

{phang2}{cmd:. surveymap, profile(declined)}{p_end}

{pstd}
Response rows are drawn on the spine and in the mermaid nodes; inside a gate's
lanes the cells stay compact and keep their answer rates only. Every HTML page
also carries {bf:How to read this map, step by step}, written with the
survey's own item and gate names.{p_end}


{marker paths}{...}
{title:The paths subcommand}

{pstd}
{cmd:surveymap paths} {varlist} {ifin} [{cmd:[pweight=}{it:w}{cmd:]}]
[{cmd:,} {opt top(#)} {opt out(filename)} {opt sav:ing(filename)}
{opt titl:e(text)} {opt nodr:aw} {opt noop:en} {opt replace}]{p_end}

{pstd}
Give two to twelve numeric items in the order the questionnaire asks them.
Each item is cut into {opt top(#)} named answers (ranked by count, default 3,
at most 6), a pooled {bf:other answers} block, and {bf:no answer recorded}.
The command writes a journal ({opt out()}, default
{cmd:surveymap_paths.tsv}) and draws the HTML page ({opt saving()}, default
{cmd:surveymap_paths.html}) in one step; {opt nodraw} writes the journal
only, and {cmd:surveymap draw} redraws a paths journal later without
rescanning. A paths journal draws as HTML only.{p_end}

{pstd}
An item with more than 30 distinct answers is refused with a message: band
it first ({cmd:egen} {it:newvar} {cmd:= cut(}{it:var}{cmd:), at(...)}) and
map the banded variable. String items are refused: {cmd:encode} them first.
With a {cmd:pweight}, weighted counts are journaled alongside; the drawing
reports unweighted counts, because a route through a questionnaire is a
property of the fieldwork rather than of the population.{p_end}

{pstd}
Stored results: {cmd:r(N)} respondents in scope, {cmd:r(K_items)} items,
{cmd:r(n_sequences)} distinct complete answer sequences, {cmd:r(journal)}
and {cmd:r(output)} the files written.{p_end}


{marker receipt}{...}
{title:Reading the receipt}

{pstd}
The receipt prints after a scan, one line per item in questionnaire order:{p_end}

{phang2}{cmd}{...}
{space 3}#{space 2}item{space 9}answered{space 6}declined{space 4}not shown{space 3}routed around by{break}
{space 3}7{space 2}q5_voted{space 8}1,133 (94.4%){space 6}28{space 6}39{space 2}q1_consent==0{break}
{space 3}8{space 2}q6_whovote{space 9}578 (48.2%){space 6}22{space 5}600{space 2}q5_voted==0{break}
{space 3}9{space 2}q7_whynot{space 10}507 (42.2%){space 6}26{space 5}667{space 2}q5_voted==1{break}
{space 2}15{space 2}q13_income{space 8}941 (78.4%){space 5}220{space 6}39{space 2}q1_consent==0{p_end}
{txt}{...}

{pstd}
{cmd:q6_whovote} and {cmd:q13_income} both look poorly answered, for opposite
reasons. Six hundred people never saw {cmd:q6_whovote}, because it asks who you
voted for and they had just said they did not vote: the instrument was working.
Almost everyone saw {cmd:q13_income}, and 220 of them refused: that one is a
wording problem. Read the last column to tell the two apart, since it gives the
answer that routed people away.{p_end}

{pstd}
{bf:Every percentage here is out of the whole sample.}
The receipt and the journal's {cmd:pct_answered} both divide by the respondents
in scope, so {cmd:q6_whovote} shows 48.2 percent of all 1,200. Of the 600 people
it was put in front of, 578 answered, which is 96.3 percent. Both numbers are true and they answer
different questions, so say which one you mean. When you want the second,
compute it from the journal, which has no column for it:{p_end}

{phang2}{cmd:. // answered as a share of those the item was shown to}{p_end}
{phang2}{cmd:. generate double shown = n_asked - n_sysmiss}{p_end}
{phang2}{cmd:. generate double pct_of_shown = 100 * n_answered / shown}{p_end}

{pstd}
Reporting the first figure as though it were the second is the standard way a
filtered item gets written up as a response-rate problem. NCES Statistical
Standard 1-3-5 and the AAPOR {it:Standard Definitions} (10th ed., 2023) both
put the item base at respondents minus valid skips, which is
{cmd:pct_of_shown}.{p_end}


{pstd}
{bf:You do not have to take the arithmetic on trust.} Every respondent in scope
falls into exactly one of answered, declined or not shown at every item, so
those three counts must add to the sample on every row. {cmd:surveymap} checks
that at scan time and prints the verdict at the foot of the receipt, because a
map whose arithmetic is wrong looks exactly like one whose arithmetic is right.
Read the count of failures from {cmd:r(N_unbalanced)}, and assert it in a
do-file rather than reading it by eye:{p_end}

{phang2}{cmd:. surveymap, out(journal.tsv) replace}{p_end}
{phang2}{cmd:. assert r(N_unbalanced) == 0}{p_end}

{pstd}
You will also find the verdict in the journal, so somebody who opens the file
months later can see that the check ran. Anything other than zero means the map
is not a partition of the sample and nothing built on it holds; report it as a
bug.{p_end}


{marker realfile}{...}
{title:Pointing it at a real survey file}

{pstd}
A delivered survey file is wider than the questionnaire. Alongside the answers it
contains record identifiers, sample-frame columns from a voter or panel list,
interviewer administration, vendor recodes, and verbatim text. Map all of it and
you get a picture with more columns than structure; worse, a column that was
never a question can look like branching to the routing detector. Cut it down to
the instrument in one of these ways.{p_end}

{synoptset 26 tabbed}{...}
{synopt :{opt ex:clude(varlist)}}drop columns that are not questions{p_end}
{synopt :{opt nostrings}}drop every string column; on a delivered file these are the verbatims{p_end}
{synopt :{it:varlist}}or name the items you want, positively{p_end}
{synoptline}
{p2colreset}{...}

{phang2}{cmd:. surveymap, exclude(respid weight_final interviewer) nostrings}{p_end}

{pstd}
{bf:Watch for blanks that are not skip logic.} An item can be blank for three
different reasons, and only one of them is routing.{p_end}

{phang2}
{bf:Skip logic.} The respondent was not asked, because of an earlier answer. This
is what the map is for.{p_end}

{phang2}
{bf:A frame property.} A sample-frame column is blank for any respondent the
frame never matched. In one real file every voter-file column came back blank
for all 363 panel respondents, because nobody matches a panel case to the voter
file. No skip routed those people anywhere and the columns do not apply to them,
so put the whole block in {opt exclude()}. Leave it in and the detector reads the
frame as a filter.{p_end}

{phang2}
{bf:A split ballot.} Some items are asked of a random half of the sample by
design. That is missing completely at random by construction, and the two
versions are two different questions, not one question with gaps.{p_end}

{pstd}
The detector works from the responses, so a frame column or a split ballot can
satisfy its test without being a filter. Treat a detected gate as a claim to
check rather than as a finding; see
{help surveymap##detect:How routing is found} for what the test is and
{help surveymap##verify:Checking the map against a questionnaire} for how to
check it.{p_end}


{marker weights}{...}
{title:Weights}

{pstd}
{cmd:pweight}s are allowed. Give one whenever the numbers you are going to
publish are weighted:{p_end}

{phang2}{cmd:. surveymap [pweight=wtfinal], exclude(respid) nostrings}{p_end}

{pstd}
You get both counts, because they answer different questions. Use the unweighted
count when you are describing the fieldwork and who was asked what, since it
describes the people somebody actually interviewed. Use the weighted count when
you are describing an estimate, since that is what a published percentage rests
on. A weighted scan adds {cmd:w_asked}, {cmd:w_answered} and
{cmd:pct_answered_w} to the journal and a {cmd:wtd%} column to the receipt, and
leaves every unweighted column meaning what it meant before.{p_end}

{pstd}
Expect two consequences. A respondent whose weight is zero drops out of scope,
exactly as they drop out of a weighted estimate, so the respondent count on the
receipt is the positive-weight base rather than the number of interviews: check
it against the count you expect before reading anything else. And since a weight
belongs to a respondent rather than to an answer, {cmd:surveymap} leaves the
weight variable out of the item list, so you do not need to name it in
{opt exclude()}.{p_end}

{pstd}
{bf:What you see in the drawing.} A weighted map follows the convention survey
results are usually reported in: an unweighted count, because it describes the
people interviewed, beside a weighted percentage, because that describes the
estimate. The caption states which is which, so nobody downstream has to guess
whether a map was weighted.{p_end}

{pstd}
With no weight given, the three weighted columns contain {cmd:.} rather than
zero, so a reader can tell "not weighted" from "weighted to zero".{p_end}


{marker verify}{...}
{title:Checking the map against a questionnaire}

{pstd}
Most survey projects already keep a table of the skip logic, one row per gated
question with the number of people who should have answered it. That table and
this map are two independent accounts of the same routing, so ask whether they
agree:{p_end}

{phang2}{cmd:. surveymap, verify(skiplogic.csv)}{p_end}

{pstd}
Give it a CSV whose header names at least {cmd:varname} and {cmd:expected_n}.
{cmd:study}, {cmd:gate_expr} and {cmd:note} are read when present and skipped
when absent, so a table somebody wrote for another purpose will often work
unchanged. {cmd:surveymap} compares each declared item against what the answers
show and returns the number of disagreements in {cmd:r(N_mismatch)}, which you
can use to stop a run:{p_end}

{phang2}{cmd:. surveymap, verify(skiplogic.csv) out(journal.tsv) replace}{p_end}
{phang2}{cmd:. assert r(N_mismatch) == 0}{p_end}

{pstd}
A disagreement can run either way, and the two directions call for different
work. When the map routes an item the table does not mention, you are looking at
either an undocumented filter or a small-cell correlation that happened to
satisfy the test; open the questionnaire and decide which, then either add the
row or write down why it is spurious.{p_end}

{pstd}
{bf:Chase the reverse case first.} A gate the questionnaire declares but the
answer counts do not produce means the instrument and the file disagree about
who was asked, so you cannot trust the denominator of any estimate on that item
until you have found out which of the two is wrong.{p_end}

{pstd}
{bf:You will see the disagreement in the drawing, not only in the receipt.} A
number in a receipt is something the reader has to go looking for, so
{opt verify()} adds its verdict to the journal as {cmd:note} rows and every
renderer puts a {cmd:!?} on the item, on the spine and in each lane that draws
it, with the declared and observed counts on hover. Hand the map to somebody who
will not read a receipt and they still see the problem. Because the marks live
in the journal rather than in the renderer, a map you draw months later from a
stored journal still carries the audit that ran at scan time. Take the item
names from {cmd:r(mismatched)} and {cmd:r(notmapped)} when you want to act on
them in code.{p_end}

{pstd}
The two marks answer different questions. {cmd:!?} means the questionnaire and
the file disagree about who was asked. {cmd:!!} means the declines on an item come
to more than 5 percent of the respondents in scope. A journal written without {opt verify()}
carries no {cmd:!?} at all and draws exactly as it did before.{p_end}

{pstd}
Run it the other way round on a new delivery, where you have the file before
anybody has written the skip-logic table. Scan first, take the {cmd:gated_by}
column as your draft of that table, then check the draft against the
questionnaire. You are starting from what respondents actually saw rather than
from what the instrument was supposed to do.{p_end}


{marker branch}{...}
{title:Branching}

{pstd}
{opt branch()} names the questions whose answers you want the flow split by: the
party question on a political survey, the screener on a panel, the treatment arm
on a trial. Each category becomes a lane, and every later item the gate routes is
drawn once per lane with that lane's own numbers.{p_end}

{synoptset 34 tabbed}{...}
{synopt :{cmd:branch(party)}}every category of {cmd:party} is a lane{p_end}
{synopt :{cmd:branch(party = 1 3 4)}}only these; the rest pool into {bf:other}{p_end}
{synopt :{cmd:branch(party = 1/3 5)}}{help numlist:numlists} expand{p_end}
{synopt :{cmd:branch(party = 1 3, voted = 1)}}two gates, comma separated{p_end}
{synopt :{cmd:branch(party, voted)}}two gates, every category of each{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
Several gates go in one {opt branch()} separated by commas, because
{helpb syntax} cannot repeat an option.{p_end}

{pstd}
The lanes always partition the sample: the categories you kept, one {bf:other}
lane for the rest, and one {bf:no answer} lane for the people who left the gate
blank. Add the lane counts and you get the number of respondents in scope, so
you can check that nobody was lost and nobody was counted twice. The battery
asserts it on every gate.{p_end}

{pstd}
Give a numeric variable. A string would produce one lane per distinct answer,
which is a listing rather than a branch, so {cmd:surveymap} names the offending
gate, skips it, and carries on with the others rather than stopping the
scan.{p_end}

{pstd}
Give no {opt branch()} at all and you get the two questions that route the most
respondents, with the receipt naming them so you know what you are looking at.
Use {opt noautodetect} when you want only the gates you asked for, which matters
when you are producing a figure for publication and do not want the drawn gates
changing as the data change.{p_end}


{pstd}
{bf:Gating on a continuous item.} Age in years has too many values to work as a
gate, so name the cut yourself and {cmd:surveymap} bands the item for the
drawing. It bands a copy inside a frame, so your data are untouched and the
variable keeps its original values afterwards.{p_end}

{synoptset 30 tabbed}{...}
{synopt :{cmd:branch(age = cut(25 35 45 65))}}bands at the breaks you name{p_end}
{synopt :{cmd:branch(hhinc = q(4))}}quartile bands{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
There is deliberately no default cut. Where to divide age is a decision about
the population you are describing, and once it is drawn it becomes a stated fact
in a figure somebody else will reuse, so you make that decision rather than the
software. You will find the breaks you chose written into the journal, which is
what lets a later reader see whose judgement they were.{p_end}

{pstd}
Nobody falls outside the bands. Everyone below the first break goes into the
first lane and everyone at or above the last break into the top one, which is
where this differs from {helpb egen} {cmd:cut, at()}: that command returns both
tails as missing, and lanes that dropped the tails would stop adding up to the
sample. Expect labels taken from the breaks themselves, so {cmd:cut(25 35 45 65)}
gives you {bf:under 25}, {bf:25 to 34}, {bf:35 to 44}, {bf:45 to 64} and
{bf:65 and over}, and a {cmd:q()} band is labelled with the range it
covers.{p_end}


{marker profile}{...}
{title:Splitting by what the respondent did}

{pstd}
{opt branch()} splits the map by an answer, so you read one lane for Republicans
and another for Democrats. {opt profile()} splits it by something the respondent
did while answering, so you read one lane for the people who left items blank
and another for the people who did not. Reach for it when you want to know
whether item nonresponse concentrates in one kind of respondent rather than
spreading evenly across the sample, and, more usefully, {it:where} along the
instrument that happens.{p_end}

{synoptset 30 tabbed}{...}
{synopt :{cmd:profile(declined)}}% of asked items left unanswered{p_end}
{synopt :{cmd:profile(refused)}}% of asked items refused; needs {opt refusedcode()}{p_end}
{synopt :{cmd:profile(dontknow)}}% of asked items answered don't know; needs {opt dkcode()}{p_end}
{synopt :{cmd:profile(asked)}}how many items the routing carried them to{p_end}
{synopt :{cmd:profile(answered)}}how many items they answered{p_end}
{synopt :{cmd:profile(breakoff)}}the position of the last item they answered{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
Band any of them with the same grammar as a continuous gate, in the units of the
condition itself: {cmd:profile(declined = cut(10 25))} reads its breaks as
percentages, and {cmd:profile(asked = q(4))} cuts a count into quartiles.{p_end}

{pstd}
{cmd:refused} and {cmd:dontknow} will not run until you name the codes this
survey uses, because no two survey houses agree on them and a guess would be a
fabrication. Look at what the file contains, then pass it:{p_end}

{phang2}{cmd:. codebook q13_income, tabulate(0)}{p_end}
{phang2}{cmd:. surveymap, profile(refused) refusedcode(.b)}{p_end}
{phang2}{cmd:. surveymap, profile(dontknow) dkcode(99)}{p_end}

{pstd}
Where the survey writes numeric codes such as 98 and 99 rather than extended
missings, pass them to {opt nonresponse()} on the same scan as well, or every
other part of the map counts those answers as real values.{p_end}

{pstd}
{bf:Why the first three are shares and not counts.} Skip logic asks different
respondents different numbers of questions, so a parent who answered three
child-related items and a non-parent who was routed past all three have
different denominators. Compare raw counts of declines between them and you are
comparing two different things; compare shares and you are not. So these three
divide by the items that respondent was actually asked, and an item a skip
routed past counts in neither the numerator nor the denominator. Count it and a
well-behaved respondent on a long branch looks like a bad one. NCES Statistical
Standard 1-3-5 and the AAPOR {it:Standard Definitions} (10th ed., 2023) both
define the item base this way.{p_end}

{pstd}
{bf:Where the default splits, and when to override it.} With no banding, a share
cuts at zero and nowhere else, giving you {bf:none} and {bf:at least one}. Zero
is the only boundary on this measure that is not a judgement call: a threshold
like "declined more than 20 percent" decides what counts as a lot, and AAPOR is
explicit that such a boundary belongs to the researcher and has to be declared
in advance, so {cmd:surveymap} will not supply one. On a long instrument, where
almost everybody declines something, that default puts nearly the whole sample
in one lane and tells you little, so look at the distribution and set your own
breaks:{p_end}

{phang2}{cmd:. surveymap, profile(declined = cut(2 10))}{p_end}

{pstd}
You will find a note in the journal whenever the bands were the default rather
than yours, which is how a later reader separates your judgement from the
software's. For {cmd:breakoff} the default splits at reaching the last item,
which needs no judgement either.{p_end}

{pstd}
{bf:What you may and may not write up from this.} A lane built this way is
descriptive: it shows you where answers were not obtained. Whether that distorts
an estimate depends on whether the people who declined differ on the thing being
measured, and response data cannot settle that. Groves and Peytcheva's (2008)
meta-analysis of 59 nonresponse bias studies found the nonresponse rate is by
itself a poor predictor of nonresponse bias, and Groves (2006) put the variance
in bias it explains at about 11 percent. So "this item lost 220 of the people it
was asked, and they sit in the high-decline lane" is a finding you can publish;
"this item is biased" is not. One more caution when you read the picture: the
{it:amount} of declining inside a lane you defined by declining is true by
construction, so read the location rather than the size.{p_end}

{pstd}
{bf:With a weight, report these lanes unweighted.} A weight is built to make a
sample represent a population, and "respondents who declined a lot of items" is
not a group that exists in the population, so a weighted percentage inside one
of these lanes describes the weighted sample and nothing beyond it. You will
find that warning written into the journal on any weighted scan that uses
{opt profile()}, so it travels with the file. If a weighted figure has to appear
in a table, carry the sentence with it.{p_end}

{pstd}
{bf:Why you cannot give anyone an "exaggerator" flag.}
Ask for {cmd:profile(exaggerator)} and you get a refusal that prints
its reasoning, so you can forward the message rather than reconstruct the
argument. People who over-report a socially desirable answer resemble people who
report it honestly on everything a survey can observe: Ansolabehere and Hersh's (2012)
fifty-state vote validation found over-reporters look like voters on
demographics and attitudes alike. Build a flag from the answers alone and you
reproduce the profile of the behaviour rather than of the misreporting, which
means labelling older, better-educated, more engaged respondents as liars. To
measure it you need an external record to validate against, or an instrument
designed for it: a list experiment, randomised response, or the planted foils of
the over-claiming technique.{p_end}

{pstd}
{cmd:profile(straightlining)} is refused for a different reason. You can measure
non-differentiation, but only inside a battery you name, and only where
answering the same way down that battery would be implausible. Where it is
plausible, Schonlau and Toepoel (2015) found 15 to 40 percent of respondents produce a
straight line, against under 2 percent where it is implausible, and no index
separates those two cases. Non-differentiation also runs higher among
respondents with less schooling (Krosnick and Alwin 1988), so a lane built on it
is partly a lane built on education. A survey file does not say which items
share a response scale, so this package will not guess at the battery for
you.{p_end}

{pstd}
Run {cmd:profile(refused)} against {cmd:profile(dontknow)} instead, which is a
question the data can answer. Shoemaker, Eichholz and Skewes (2002) found don't-know
associated with the cognitive effort a question demands, and refusal associated
with effort {it:and} with how sensitive the question is. So refusals stacking on
an income block point you at sensitivity, and don't-knows spread across an
attitude battery point you at burden. Those call for different fixes, rewording
one question versus shortening a battery, which is why {cmd:surveymap} keeps the
two counts apart instead of adding them into one "missing".{p_end}


{marker detect}{...}
{title:How routing is found}

{pstd}
{cmd:surveymap} reads the routing out of the answers, because a delivered file
contains no other trace of the instrument. It treats category {it:v} of gate
{it:g} as routing people around item {it:i} when almost nobody in that lane
answered {it:i} while the other lanes did:{p_end}

{phang2}
answer rate of {it:i} within {it:g}{cmd:==}{it:v} at most {bf:2%}, and{p_end}
{phang2}
answer rate of {it:i} among {it:g}'s other answered categories at least {bf:50%}{p_end}

{pstd}
{opt detect(# #)} moves the two thresholds. Raise the first when a routed item
still collected a handful of stray answers, which happens with back-coded or
interviewer-entered values. Lower the second when the people who were asked
answered patchily, which happens on a long or sensitive item where the answer
rate never reaches 50 percent even among those who saw it.{p_end}

{pstd}
What you get here is evidence, not a questionnaire spec. Where everyone in a
category happened not to answer an item, you cannot tell that apart from an item
they were never shown, and no amount of data will separate the two. The receipt
prints one line saying so. Read a detected gate as a claim to check rather than
as a fact, and where you know the instrument, name the gates yourself with
{opt branch()} instead.{p_end}


{marker prune}{...}
{title:Pruning noisy branches}

{pstd}
A gate with a long tail of small categories produces a map nobody can read, so
{cmd:surveymap} folds the small categories into one {bf:other} lane. Three rules
decide which ones, and a category folds when it fails any of them:{p_end}

{synoptset 26 tabbed}{...}
{synopt :{opt prune(#)}}fold a category under {it:#} percent of the sample {it:(default 5)}{p_end}
{synopt :{opt minn(#)}}fold a category under {it:#} respondents {it:(default 30)}{p_end}
{synopt :{opt maxc:ats(#)}}keep at most the {it:#} largest {it:(default 6)}{p_end}
{synopt :{opt noprune}}keep every category{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
Whatever the rules say, the journal keeps every category; the folding happens
when you build a map or a tracker. So you can change the rules at draw time and
see the result without reading the data again:{p_end}

{phang2}{cmd:. surveymap, branch(party)}{p_end}
{phang2}{cmd:. surveymap draw, prune(10)}{p_end}
{phang2}{cmd:. surveymap draw, noprune}{p_end}

{pstd}
Set them on the scan instead and every later drawing inherits them as its
default. Categories you left out of an explicit {cmd:branch(}{it:var}
{cmd:= ...)} list work differently: naming a list states what you want the lanes
to be, the journal keeps that statement, and only {opt noprune} brings the rest
back.{p_end}


{marker draw}{...}
{title:Drawing the map}

{pstd}
{cmd:surveymap draw} turns a journal into a picture. Name a journal file, or
give none and you get whatever the last scan wrote. {cmd:surveymap} keeps that
path in the global {cmd:$SM_LASTJ}, so it lasts as long as the Stata session
does and no longer: name the file yourself in a do-file somebody else will run,
or after you {helpb clear all}.{p_end}

{synoptset 22 tabbed}{...}
{synopt :{opt export(html)}}a self-contained page: no internet, no JavaScript {it:(the default)}{p_end}
{synopt :{opt export(mermaid)}}text that GitHub, Quarto and VS Code render{p_end}
{synopt :{opt export(png)}}a figure through Stata's own graph engine{p_end}
{synopt :{opt export(svg)}}the same figure, scalable{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
{opt png} and {opt svg} come from one {helpb twoway} call, so ask for either and
you get both; keep whichever the document needs. A figure stays readable only up
to a point, so past {opt maxnodes(#)} drawn columns (default 14) {cmd:surveymap}
stops and points you at the HTML page, which scrolls and keeps the full record
on hover. A fan counts as one column however many items it contains, so the
limit is on what your eye has to follow rather than on the item count. When you
hit it, narrow the map with a {varlist} or {opt exclude()}, or draw the whole
instrument with {help surveymap##band:{cmd:surveymap band}} instead.{p_end}

{pstd}
{bf:How to read it.} Follow the spine left to right: that is questionnaire
order. Each box gives you the item name, its label, and the count and percent
who answered, with {cmd:!!} on any item where the people who declined come to
more than 5 percent of the respondents in scope. Where a gate splits the sample the spine fans into lanes, headed
{bf:split by} the gate's name, each lane labelled with its category and size.
Inside a lane, read a plain box as an item the respondents in that lane were
asked, and a {bf:dashed grey box} as one the gate routed them around. The lanes rejoin at a dot and the
spine continues. Hover any box to get the full record behind it.{p_end}

{pstd}
Expect the lanes to open where the gate's items are rather than immediately
after the gate. A party question asked early can decide primary-turnout
questions much later, and the fan belongs where those questions fall in the
questionnaire, not where the gate does.{p_end}

{pstd}
{bf:Which way it runs.} {opt layout(vertical)} turns the map on its side: items
run down the page and a gate spreads its lanes across it, one column per lane.
Choose vertical for a report or a README, because a page scrolls downward and a
long instrument is taller than any screen is wide. Choose the horizontal default
for a slide or a wide monitor. A vertical mermaid map puts each lane in a
labelled {cmd:subgraph}, so a reader sees the grouping drawn rather than
inferring it from where the boxes sit. Both layouts read the same journal, so
write one of each without rescanning:{p_end}

{phang2}{cmd:. surveymap draw, layout(vertical) saving(flow_tall.html) replace}{p_end}
{phang2}{cmd:. surveymap draw, export(mermaid) layout(vertical) saving(flow_tall) replace}{p_end}

{pstd}
{bf:Do not rely on lane order in a mermaid file.} {cmd:surveymap} declares lane
1 first, but the renderer controls the order they come out in, and renderers
disagree: mermaid-cli and GitHub lay the same file out in opposite orders. Every
lane is labelled with the answer that opened it, so you lose nothing by it. When you do need the order guaranteed, as you do for a
banded gate whose lanes run low to high, use the HTML map or the
{opt export(png)} figure, which {cmd:surveymap} lays out itself.{p_end}

{pstd}
{bf:The same numbers, as text.} Under the figure you get a {cmd:<details>} block
containing the whole map as a table: one row per item, with answered, declined,
not shown, and what routed it. A diagram is not readable by everyone, and the
honest fallback for a figure built from a table is that table rather than a
sentence describing it. Use it for an accessibility review, or hand it to a
reader who wants the numbers rather than the picture, instead of building a
second table yourself. {cmd:surveymap} marks the figure {cmd:role="img"}, points
it at its own title and description, and keeps it out of the keyboard tab order,
so a forty-node map does not turn into forty tab stops.{p_end}

{pstd}
The page has no height cap and the diagram scrolls sideways, because a survey is
wider than it is tall. Use {opt embed} to get a fragment for a report page
rather than a whole document: scoped styles, no element selectors, and a bounded
box, so dropping it into your page cannot restyle the page. The repository
includes the check that proves it,
{cmd:tests/embedcheck/check_embed_scoping.py}, which fails any fragment
carrying an unscoped selector, a script, or a page wrapper.{p_end}


{marker band}{...}
{title:The band chart, for a long instrument}

{pstd}
The flow map has a node budget. Past {opt maxnodes()} drawn columns it stops
and points you at the HTML page, and on a 230-item instrument there is no
arrangement of boxes and lanes that fits a page at all. {cmd:surveymap band}
has no budget: one thin column per item, in questionnaire order, each split
into answered, declined and not shown, stacking to the whole sample.{p_end}

{phang2}{cmd:. surveymap band}{p_end}
{phang2}{cmd:. surveymap band journal.tsv, saving(leaks.png) replace}{p_end}

{pstd}
Use it to answer a different question from the map, which is why both exist.
Go to the map when you want to know who was asked what. Go to the band chart
when you want to know where along the instrument the answers stop coming, on one
page, for a questionnaire of any length. Reading it: a wide block of
{bf:not shown} is a filter doing its job, and a swelling band of {bf:declined}
is people being asked and not answering. A percent-missing table makes those two
look identical.{p_end}

{pstd}
Give no journal and, as with {cmd:draw}, you get the one the last scan wrote.
The shape is the state-distribution plot of Gabadinho et al.'s TraMineR (2011),
drawn with {helpb twoway}: you
get one bar per item on a short survey, and a filled area once there are more
items than separate bars can show, switching over automatically at 60 items.
Above about 60 items you also get a few landmark positions named on the top
axis, picked where the not-shown share jumps, which is where the gates
are.{p_end}

{pstd}
{bf:Every column comes from the three counts, never from a hard-coded 100.} So a
journal whose counts do not add to the sample gives you a short column rather
than a full one that quietly lies about it. Read the largest shortfall, in
respondents, from {cmd:r(devmax)}, and assert it the way you assert
{cmd:r(N_unbalanced)} after a scan. Expect zero on any journal
{cmd:surveymap} wrote, since the scan checks the same arithmetic; the check is
here for a journal somebody has edited by hand.{p_end}


{marker export}{...}
{title:The Excel tracker}

{pstd}
{cmd:surveymap export, saving(flow.xlsx)} writes three sheets:{p_end}

{synoptset 18 tabbed}{...}
{synopt :{bf:sm_items}}one row per item: asked, answered, declined, not shown, percent, and what routed it. The first column is named {cmd:variable}{p_end}
{synopt :{bf:sm_branches}}one row per gate category: label, count, share, and whether it pooled{p_end}
{synopt :{bf:sm_flow}}one row per lane and item: lane size, answered, rate, and status{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
Counts arrive as numbers rather than text, so Excel sorts and filters them
correctly without you cleaning the sheet first. You can also let the map hide the
small lanes while the workbook keeps every one of them: pass {opt noprune} to the
export and you get a complete tracker whatever the drawing shows.{p_end}

{pstd}
Ask for {opt format(dta)} or {opt format(csv)} when you want the whole journal
as data to merge against something else you track, such as a question bank or a
fieldwork log.{p_end}


{marker dd}{...}
{title:Working with datadictionary}

{pstd}
Use {helpb datadictionary} to document what a survey's variables {it:are}: types, labels, value labels, summary statistics, and how labels changed across
waves. Use {cmd:surveymap} to document how respondents {it:moved} through them.
You can put both in one codebook, and neither needs the other
installed.{p_end}

{pstd}
{bf:Flow columns in the codebook.} {cmd:datadictionary}'s {opt flow()} option
reads a surveymap journal and adds {cmd:pct_answered_sm} and {cmd:skipped_by_sm}
to its Variables sheet and its saved dataset, matched on variable name:{p_end}

{phang2}{cmd:. surveymap, branch(party) out(flow.tsv) replace}{p_end}
{phang2}{cmd:. datadictionary, excel(codebook.xlsx) flow(flow.tsv) replace}{p_end}

{pstd}
{bf:Flow sheets in the workbook.} Going the other way, {opt dictionary()} adds
the three surveymap sheets to a codebook workbook that already exists, leaving
every sheet {cmd:datadictionary} wrote untouched:{p_end}

{phang2}{cmd:. datadictionary, excel(codebook.xlsx) replace}{p_end}
{phang2}{cmd:. surveymap export, dictionary(codebook.xlsx)}{p_end}

{pstd}
You end up with one workbook containing the item definitions, the response
distributions, the label history, and the flow. Both sides key on the variable
name, so a lookup across sheets takes one formula.{p_end}


{marker options}{...}
{title:Options}

{dlgtab:Scan}

{synoptset 26 tabbed}{...}
{synopt :{opt br:anch(spec)}}the gates to split the flow by; see {help surveymap##branch:Branching}{p_end}
{synopt :{opt prof:ile(spec)}}split by what the respondent did rather than by what they answered; see {help surveymap##profile:Splitting by what the respondent did}{p_end}
{synopt :{opt ref:usedcode(value)}}which value means refused, such as {cmd:.b} or {cmd:99}; required by {cmd:profile(refused)} and used by nothing else{p_end}
{synopt :{opt dk:code(value)}}which value means don't know; required by {cmd:profile(dontknow)} and used by nothing else{p_end}
{synopt :{opt out(filename)}}write the journal here; default {cmd:survey_journal.tsv}{p_end}
{synopt :{opt non:response(numlist)}}coded values to count as declined rather than answered, such as {cmd:98 99}; extended missings always count as declined{p_end}
{synopt :{opt ex:clude(varlist)}}columns to leave out: ids, sample frame, admin{p_end}
{synopt :{opt nostrings}}leave the string columns out, which are usually verbatims{p_end}
{synopt :{opt ver:ify(filename)}}check the routing found against a declared skip-logic table{p_end}
{synopt :{opt resp:onses(#)}}show each item's {it:#} most common answers inside its box; see {help surveymap##start:Where to start a map}{p_end}
{synopt :{opt det:ect(# #)}}the two routing thresholds; default {cmd:2 50}{p_end}
{synopt :{opt noautodetect}}do not look for gates; draw only the ones named in {opt branch()}{p_end}
{synopt :{opt noreceipt}}skip the receipt table{p_end}
{synopt :{opt replace}}overwrite an existing journal{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
Use a {varlist} to choose which items to map. It does not reorder anything,
because {cmd:surveymap} always reads dataset order. {cmd:if} and {cmd:in}
restrict who is in scope, and every count and percent you get is computed within
that scope.{p_end}

{pstd}
{opt nonresponse()} and {opt refusedcode()} do different jobs, so set both when
your survey codes its refusals numerically. {opt nonresponse()} moves coded
values out of answered and into declined everywhere in the map.
{opt refusedcode()} tells {cmd:profile(refused)} which one of those codes is a
refusal as opposed to a don't know, and changes nothing else.{p_end}

{dlgtab:Pruning (scan, draw and export)}

{synoptset 26 tabbed}{...}
{synopt :{opt prune(#)}}fold a category under {it:#} percent; default {cmd:5}{p_end}
{synopt :{opt minn(#)}}fold a category under {it:#} respondents; default {cmd:30}{p_end}
{synopt :{opt maxc:ats(#)}}keep at most the {it:#} largest; default {cmd:6}{p_end}
{synopt :{opt noprune}}keep every category{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
A category folds when it fails {it:any} of the three, so at the defaults a
category with 4 percent of the sample folds even when that is 200 people.
Raise {opt prune()} and {opt minn()} together, or give {opt noprune}, when you
want the small categories back.{p_end}

{dlgtab:Draw}

{synoptset 26 tabbed}{...}
{synopt :{opt exp:ort(html|mermaid|png|svg)}}the medium; default {cmd:html}{p_end}
{synopt :{opt lay:out(horizontal|vertical)}}which way the questionnaire runs; default {cmd:horizontal}{p_end}
{synopt :{opt sav:ing(filename)}}where to write it{p_end}
{synopt :{opt name(text)}}what to call the survey on the page{p_end}
{synopt :{opt embed}}a fragment for someone else's page, not a whole document{p_end}
{synopt :{opt maxn:odes(#)}}how many columns a {cmd:png}/{cmd:svg} figure will attempt; default {cmd:14}. Past it {cmd:surveymap} writes the HTML page instead and prints its path{p_end}
{synopt :{opt noopen}}write the page but do not open a browser{p_end}
{synopt :{opt replace}}overwrite existing output{p_end}
{synoptline}
{p2colreset}{...}

{dlgtab:Export}

{synoptset 26 tabbed}{...}
{synopt :{opt sav:ing(filename)}}where to write it; the extension picks the format{p_end}
{synopt :{opt f:ormat(xlsx|dta|csv)}}the format, when {opt saving()} does not say{p_end}
{synopt :{opt dict:ionary(filename)}}add the sheets to an existing {helpb datadictionary} workbook{p_end}
{synopt :{opt replace}}overwrite an existing tracker{p_end}
{synoptline}
{p2colreset}{...}

{dlgtab:Band}

{synoptset 26 tabbed}{...}
{synopt :{opt sav:ing(filename)}}export the figure here; the extension picks the format{p_end}
{synopt :{opt ti:tle(text)}}title above the figure{p_end}
{synopt :{opt sub:title(text)}}subtitle under the title{p_end}
{synopt :{opt not:e(text)}}note under the figure; the default states the denominator{p_end}
{synopt :{opt names(spec)}}which items to name on the top axis: {cmd:auto}, {cmd:none}, or a list of variable names or positions{p_end}
{synopt :{opt nn:ames(#)}}how many items {cmd:auto} names; default {cmd:6}{p_end}
{synopt :{opt bar}}one discrete bar per item, whatever the item count{p_end}
{synopt :{opt area}}one filled area, whatever the item count{p_end}
{synopt :{opt areamin(#)}}switch from bars to area above this many items; default {cmd:60}{p_end}
{synopt :{opt xsi:ze(#)} {opt ysi:ze(#)} {opt sc:ale(#)}}figure inches and text scaling{p_end}
{synopt :{opt nolegend}}leave the legend off{p_end}
{synopt :{opt name(text)}}the Stata graph name{p_end}
{synopt :{opt replace}}overwrite existing output{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
{opt bar} and {opt area} override the automatic switch at {opt areamin()}.
Force {opt bar} above 60 items when you need columns a reader can count and can
accept the seams; force {opt area} below it when the figure is going next to
another area chart. For a figure the width of a report page rather than a
landscape slide, {cmd:xsize(6.5) ysize(2.5) scale(1.3)} works; below
{cmd:ysize(2)} the axis labels start colliding.{p_end}
{title:Examples}

{pstd}{bf:See it work, with no setup}{p_end}
{phang2}{stata "surveymap demo":. surveymap demo}{p_end}
{pstd}
Writes a 600-person survey and its journal into {cmd:./surveymap_demo}, prints
the receipt, and offers the drawing commands as clickable links. Name a folder
as {it:foldername} or in {opt folder()} to put it somewhere else, and add
{opt replace} to reuse a folder you have already written to. It leaves the data
in memory alone.{p_end}

{pstd}{bf:Map the survey in memory}{p_end}
{phang2}{cmd:. surveymap}{p_end}

{pstd}{bf:Map the questions, leaving the identifiers and paradata out}{p_end}
{phang2}{cmd:. surveymap q1-q42}{p_end}
{phang2}{cmd:. surveymap, exclude(respid wtfinal interviewer) nostrings}{p_end}

{pstd}{bf:A weighted survey: both counts, side by side}{p_end}
{phang2}{cmd:. surveymap [pweight=wtfinal], exclude(respid) nostrings}{p_end}

{pstd}{bf:Does the file agree with the questionnaire about who was asked?}{p_end}
{phang2}{cmd:. surveymap, verify(skiplogic.csv)}{p_end}
{pstd}
You get a table of declared against observed, one row per declared gate, and a
count in {cmd:r(N_mismatch)}. A zero there means every declared gate reproduced.
Anything else, read the names out of {cmd:r(mismatched)} and open the map: those
items are marked {cmd:!?}, with the two counts on hover.{p_end}

{pstd}{bf:Completed interviews only}{p_end}
{phang2}{cmd:. surveymap if status == 1}{p_end}

{pstd}{bf:Split the flow by party, and by whether they voted}{p_end}
{phang2}{cmd:. surveymap, branch(party, voted)}{p_end}

{pstd}{bf:Only the three main parties; everything else pools into one lane}{p_end}
{phang2}{cmd:. surveymap, branch(party = 1 2 3)}{p_end}

{pstd}{bf:This survey writes refusals into the answer, as 98 and 99}{p_end}
{phang2}{cmd:. surveymap, nonresponse(98 99)}{p_end}

{pstd}{bf:A routed item collected a few stray answers, so loosen the test}{p_end}
{phang2}{cmd:. surveymap, detect(5 40)}{p_end}
{pstd}
Compare the {cmd:routed around by} column against the run before it: the gate
you expected should now appear there. Loosening also invites false positives, so
check any new gate against the questionnaire before you keep the setting.{p_end}

{pstd}{bf:You know the instrument, so stop it guessing at gates}{p_end}
{phang2}{cmd:. surveymap, branch(screener) noautodetect}{p_end}

{pstd}{bf:Split the lanes by age, banded where you say}{p_end}
{phang2}{cmd:. surveymap, branch(age = cut(30 45 65))}{p_end}
{phang2}{cmd:. surveymap, branch(hhinc = q(4))}{p_end}

{pstd}{bf:Do the people who leave items blank take a different route?}{p_end}
{phang2}{cmd:. surveymap, profile(declined)}{p_end}
{phang2}{cmd:. surveymap, profile(declined = cut(2 10))}{p_end}
{pstd}
The default splits at zero, which on a long instrument puts almost everyone in
one lane; the second line is what you run once you have looked at the spread.
Report these lanes unweighted, because a lane defined by behaviour is not a
population subgroup.{p_end}

{pstd}{bf:Where the refusals are, as against where the don't-knows are}{p_end}
{phang2}{cmd:. surveymap, profile(refused) refusedcode(.b)}{p_end}
{phang2}{cmd:. surveymap, profile(dontknow) dkcode(.a)}{p_end}

{pstd}{bf:Draw what was just scanned}{p_end}
{phang2}{cmd:. surveymap draw}{p_end}

{pstd}{bf:The same map with the small lanes kept, then with fewer}{p_end}
{phang2}{cmd:. surveymap draw, noprune}{p_end}
{phang2}{cmd:. surveymap draw, prune(10) maxcats(4)}{p_end}

{pstd}{bf:A fragment for a report page, and text for a README}{p_end}
{phang2}{cmd:. surveymap draw, saving(flow_frag.html) embed replace}{p_end}
{phang2}{cmd:. surveymap draw, export(mermaid) saving(flow) replace}{p_end}

{pstd}{bf:A figure for a paper or a slide}{p_end}
{phang2}{cmd:. surveymap draw, export(png) saving(figures/flow) replace}{p_end}

{pstd}{bf:The same map down a page, for a report or a README}{p_end}
{phang2}{cmd:. surveymap draw, layout(vertical) saving(flow_tall.html) replace}{p_end}
{phang2}{cmd:. surveymap draw, export(mermaid) layout(vertical) saving(flow_tall) replace}{p_end}

{pstd}{bf:A 230-item instrument, which is too wide for any flow map}{p_end}
{phang2}{cmd:. surveymap band, saving(leaks.png) replace}{p_end}
{pstd}
One column per item, so the whole instrument fits one page. Look for a wide dark
block, which is a filter doing its job, and a swelling grey band, which is
people being asked and not answering.{p_end}

{pstd}{bf:The tracker, with every lane whatever the map shows}{p_end}
{phang2}{cmd:. surveymap export, saving(flow.xlsx) noprune replace}{p_end}

{pstd}{bf:One workbook with the codebook and the flow in it}{p_end}
{phang2}{cmd:. datadictionary, excel(codebook.xlsx) flow(survey_journal.tsv) replace}{p_end}
{phang2}{cmd:. surveymap export, dictionary(codebook.xlsx)}{p_end}

{pstd}{bf:Reprint a receipt from a journal saved last month}{p_end}
{phang2}{cmd:. surveymap receipt audit/wave3.tsv}{p_end}


{marker limits}{...}
{title:Limitations}

{pstd}
Routing is inferred from the answers. An item that everyone in a category
happened not to answer is indistinguishable from an item they were never shown,
and a category that routes around an item only sometimes is not reported at all.
Name the gates with {opt branch()} when you know the instrument.{p_end}

{pstd}
Lanes do not nest. Each item belongs to at most one gate's segment; where two
gates both route it, the item goes to whichever gate comes latest in
questionnaire order before it, so a map shows one level of branching at a
time. Scanning twice with different {opt branch()} gates shows the other
level.{p_end}

{pstd}
A blank string cannot say whether it was never shown or was left empty, so blank
strings are counted as not shown. Code the item numerically if the difference
matters.{p_end}

{pstd}
Columns are read in dataset order, which is taken to be the order the questions
were asked. A file whose columns have been reordered maps in that order, not in
the order the instrument ran.{p_end}

{pstd}
{cmd:surveymap} takes a {cmd:pweight} and nothing more of a survey design. It
does not read {helpb svyset} information, so strata, PSUs and finite population
corrections play no part and no standard error is available anywhere in the
output. Every figure it gives you is a count or a share of a count.{p_end}


{marker results}{...}
{title:Stored results}

{pstd}{cmd:surveymap} stores the following in {cmd:r()}:{p_end}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}respondents in scope{p_end}
{synopt:{cmd:r(K_items)}}items mapped{p_end}
{synopt:{cmd:r(N_gates)}}gates drawn{p_end}
{synopt:{cmd:r(N_unbalanced)}}items whose three counts do not add to the sample; assert this is 0{p_end}
{synopt:{cmd:r(N_mismatch)}}after {opt verify()}: declared gates the answer counts contradict{p_end}
{synopt:{cmd:r(nitems)}}after {cmd:band}: columns drawn{p_end}
{synopt:{cmd:r(devmax)}}after {cmd:band}: largest shortfall in respondents on any column; assert this is 0{p_end}
{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(journal)}}path to the journal file{p_end}
{synopt:{cmd:r(gates)}}the gate variables drawn{p_end}
{synopt:{cmd:r(mismatched)}}after {opt verify()}: the items whose counts disagree{p_end}
{synopt:{cmd:r(notmapped)}}after {opt verify()}: declared items that are not in the map{p_end}
{synopt:{cmd:r(output)}}after {cmd:draw}: the file it wrote{p_end}
{synopt:{cmd:r(file)}}after {cmd:export}: the tracker it wrote{p_end}
{p2colreset}{...}

{pstd}
Read the journal yourself with {cmd:import delimited, delimiter(tab)}. Its
columns, in order:
{cmd:seq class var position vallabel value gatevar n_asked n_answered}
{cmd:n_nonresp n_sysmiss pct_answered rate status gate gated_by pooled type}
{cmd:severity flags w_asked w_answered pct_answered_w}. The three weighted
columns contain {cmd:.} unless you supplied a weight.{p_end}

{pstd}
The ones whose names do not give them away:{p_end}

{synoptset 18 tabbed}{...}
{synopt :{cmd:class}}which kind of row: {cmd:survey} once for the scan's own settings, {cmd:item} one per item, {cmd:cat} one per gate category, {cmd:cell} one per lane crossed with one item, {cmd:note} for warnings and for what {opt verify()} found{p_end}
{synopt :{cmd:n_asked}}the respondents in scope, which is the same on every item row{p_end}
{synopt :{cmd:pct_answered}}answered as a share of scope, not of the people the item reached{p_end}
{synopt :{cmd:rate}}answered as a share of the lane, on {cmd:cell} rows only; {cmd:.} on item rows{p_end}
{synopt :{cmd:status}}on an item row {cmd:open} or {cmd:gated}; on a cell row {cmd:answered}, {cmd:partial} or {cmd:skipped}{p_end}
{synopt :{cmd:gated_by}}the answers that routed people around this item, semicolon separated{p_end}
{synopt :{cmd:pooled}}{cmd:1} on a category the prune rules folded into {bf:other}{p_end}
{synopt :{cmd:severity}}{cmd:note} or {cmd:warn}; {cmd:warn} is what puts {cmd:!!} or {cmd:!?} on the drawing{p_end}
{synopt :{cmd:flags}}the text of the warning, or the scan's settings on the {cmd:survey} row{p_end}
{synoptline}
{p2colreset}{...}


{marker related}{...}
{title:Related commands}

{pstd}
{cmd:surveymap} draws boxes and lanes because a survey node has to show more
than a width: the item name, its label, how many were asked, how many answered,
and how many declined. The commands below draw flows in other shapes, and are
the better tool when that is the shape you want.{p_end}

{phang2}
{bf:For a ribbon whose width is the count.} {cmd:sankey} and {cmd:alluvial}
(Naqvi) draw flow widths from {cmd:from}/{cmd:to}/{cmd:value} data, and mermaid's
own {cmd:sankey-beta} does the same from three CSV columns. Reach for one of
them when two or three transitions are the whole story. {cmd:surveymap} does not
encode counts as widths, for two reasons worth knowing before you go looking for
the option. Readers expect the widths at a node in a ribbon diagram to add up,
and on a questionnaire they do not: the people who declined an item show up as a
gap, and a reader takes that gap for attrition the diagram has already accounted
for, which it has not. Second, on a 15 to 40 item instrument the smallest flows
fall below a pixel, so a path nobody took vanishes altogether. On a QC map that
empty path is usually the thing you were checking for.{p_end}

{phang2}
{bf:For a study-disposition figure in a paper.} {cmd:flowchart} (Dodd) generates
LaTeX PGF/TikZ for CONSORT and PRISMA diagrams. It needs LaTeX, and the counts
are ones you supply yourself.{p_end}

{phang2}
{bf:For systematic-review flow diagrams.} {cmd:direct_flow} (Pacheco,
Martimbianco and Riera) draws study-selection flowcharts, again from counts you
give it.{p_end}

{phang2}
{bf:For a flowchart in a spreadsheet that refreshes.} {cmd:statflow} takes an
Excel sheet of logic, variable, statistic and value, and rewrites the value
column. The shape is fixed by you; the numbers come from the data.{p_end}

{phang2}
{bf:For what the variables are.} {helpb datadictionary} (Booth) builds the
codebook: types, labels, value labels, statistics, and label changes across
waves. It reads a surveymap journal through its {opt flow()} option, and
{cmd:surveymap export, dictionary()} writes into its workbook. See
{help surveymap##dd:Working with datadictionary}.{p_end}

{phang2}
{bf:For how a dataset was built.} {helpb mergemap} (Booth) maps the merges,
appends and joins across a set of do-files. {cmd:surveymap} maps movement through
one dataset's columns; {cmd:mergemap} maps how the datasets themselves were
assembled.{p_end}

{phang2}
{bf:In official Stata.} {helpb misstable} summarises missingness patterns, and
{helpb tabulate} with {cmd:missing} shows one crosstab at a time. Neither
separates a refusal from a skip, and neither follows the flow across the whole
instrument.{p_end}


{title:Also see}

{psee}
Help: {helpb datadictionary}, {helpb mergemap}, {helpb misstable}, {helpb tabulate}
{p_end}


{marker author}{...}
{title:Author}

{pstd}
Eric A. Booth{break}
Sr Researcher, Texas 2036{break}
{browse "mailto:eric.a.booth@gmail.com":eric.a.booth@gmail.com}{break}
{browse "https://github.com/ericabooth":github.com/ericabooth}{p_end}

{pstd}
Issues and suggestions:
{browse "https://github.com/ericabooth/surveymap-stata-public/issues":github.com/ericabooth/surveymap-stata-public/issues}{p_end}
