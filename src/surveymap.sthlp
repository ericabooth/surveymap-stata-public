{smcl}
{* *! version 0.2.0  23aug2026  Eric Booth}{...}
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
{opt br:anch(spec)} {opt out(filename)} {opt non:response(numlist)}
{opt ex:clude(varlist)} {opt nostrings} {opt ver:ify(filename)}
{opt prune(#)} {opt minn(#)} {opt maxc:ats(#)} {opt det:ect(# #)}
{opt noautodetect} {opt noreceipt} {opt noprune} {opt replace}]

{pstd}
{cmd:pweight}s are allowed; see {help surveymap##weights:Weights}.{p_end}

{p 8 17 2}
{cmd:surveymap draw} [{it:journalfile}] [{cmd:,} {opt exp:ort(html|mermaid)}
{opt sav:ing(filename)} {opt prune(#)} {opt minn(#)} {opt maxc:ats(#)}
{opt noprune} {opt name(text)} {opt embed} {opt noopen} {opt replace}]

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
{synopt :{opt export}}the tracker: {cmd:.xlsx}, {cmd:.dta}, or {cmd:.csv}{p_end}
{synopt :{opt receipt}}reprint the receipt from a saved journal{p_end}
{synopt :{opt clear}}forget the remembered journal; no file is touched{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:surveymap} treats the data in memory as a survey: one row per respondent,
one column per item, columns in the order the questions were asked. It reads
them and never changes them. For each item it counts who was asked, who gave a
real answer, who declined, and who was never shown the item at all, and it
works out which earlier answers routed people around which later questions.{p_end}

{pstd}
Three kinds of blank are counted apart, because they mean different things and
a single "percent missing" hides the difference:{p_end}

{synoptset 26 tabbed}{...}
{synopt :{bf:answered}}a real answer{p_end}
{synopt :{bf:declined}}an extended missing ({cmd:.a} to {cmd:.z}: don't know, refused) or a code you name in {opt nonresponse()}{p_end}
{synopt :{bf:not shown}}system missing ({cmd:.}), which is where skip logic lands{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
An item that half the sample left blank is a different problem depending on
which column the blanks are in. Blanks under {bf:declined} are a question people
would not answer, and the fix is question wording. Blanks under {bf:not shown}
are people the instrument never asked, and there is nothing to fix.{p_end}

{pstd}
The scan writes a journal: one tab-separated line per event, which is the only
intermediate file. The receipt, the map, the mermaid text and the Excel tracker
are all built from it, so a drawing can be re-cut without re-reading the
data.{p_end}


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
{cmd:q6_whovote} and {cmd:q13_income} both look poorly answered, and the reason
is different. {cmd:q6_whovote} was never shown to 600 people, because it asks
who you voted for and they said they did not vote. {cmd:q13_income} was shown to
almost everyone and 220 of them refused. The last column names the answers that
routed people away, so the two cases read apart at a glance.{p_end}


{marker realfile}{...}
{title:Pointing it at a real survey file}

{pstd}
A delivered survey file is wider than the questionnaire. Alongside the answers it
holds record identifiers, sample-frame columns from a voter or panel list,
interviewer administration, vendor recodes, and verbatim text. Mapping all of it
produces a picture with more columns than structure, and worse, the columns that
were never questions can look like branching to the routing detector. Three
options keep the map to the instrument.{p_end}

{synoptset 26 tabbed}{...}
{synopt :{opt ex:clude(varlist)}}drop columns that are not questions{p_end}
{synopt :{opt nostrings}}drop the string columns, which are usually verbatims{p_end}
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
{bf:A frame property.} Sample-frame columns are blank for respondents who were
never matched to that frame. In one real file every voter-file column was blank
for all of the panel respondents, because panel cases are not matched to the
voter file. Nobody was routed anywhere; the columns simply do not apply. Exclude
them.{p_end}

{phang2}
{bf:A split ballot.} Some items are asked of a random half of the sample by
design. That is missing completely at random, not routing, and the two versions
are two different questions, not one question with gaps.{p_end}

{pstd}
The routing detector reports what the data shows, so a frame column or a split
ballot can satisfy its test. Read a detected gate as a claim to check, and use
{opt verify()} against the questionnaire when you have it.{p_end}


{marker weights}{...}
{title:Weights}

{pstd}
{cmd:pweight}s are allowed, and a weighted survey usually wants them:{p_end}

{phang2}{cmd:. surveymap [pweight=wtfinal], exclude(respid) nostrings}{p_end}

{pstd}
Both counts are kept, because they answer different questions. The unweighted
count describes the people who were interviewed, which is the honest denominator
for a statement about fieldwork and about who was asked what. The weighted count
describes the estimate, which is what a published percentage rests on. The
journal gains {cmd:w_asked}, {cmd:w_answered} and {cmd:pct_answered_w}, the
receipt gains a {cmd:wtd%} column, and every unweighted column keeps its
meaning.{p_end}

{pstd}
Two consequences worth knowing. A respondent whose weight is zero leaves the
scope, exactly as they leave a weighted estimate, so the respondent count in the
receipt is the positive-weight base and not the interview count. And a weight is
a property of a respondent and not an answer, so the weight variable is
never mapped as an item.{p_end}

{pstd}
{bf:What the drawing shows.} A weighted journal is drawn the way survey results
are normally reported: the count is unweighted, because it describes the people
interviewed, and the percentage is weighted, because it describes the estimate.
The page says so in its caption, so a weighted map cannot be mistaken for an
unweighted one, and an unweighted map never claims otherwise.{p_end}

{pstd}
Without a weight the three columns hold {cmd:.} and every reader treats that as
"unweighted only" instead of as zero.{p_end}


{marker verify}{...}
{title:Checking the map against a questionnaire}

{pstd}
Survey projects usually keep their own table of the skip logic, one row per
gated question with the number of people who should have answered it. That table
and this map are two independent accounts of the same thing, so it is worth
asking whether they agree:{p_end}

{phang2}{cmd:. surveymap, verify(skiplogic.csv)}{p_end}

{pstd}
The file is a CSV whose header names at least {cmd:varname} and
{cmd:expected_n}; {cmd:study}, {cmd:gate_expr} and {cmd:note} are used when
present and ignored when absent, so a table written for another purpose usually
works as it is. Each declared item is compared against what the answers show,
and the count of disagreements comes back in {cmd:r(N_mismatch)}.{p_end}

{pstd}
The two outcomes mean different things. An item the map routes but the table does
not mention is usually an undocumented filter, or a small-cell correlation that
happens to satisfy the test. {bf:A declared gate the data does not show is the one
to chase}, because it means the questionnaire and the file disagree about who was
asked, and every estimate on that item inherits the disagreement.{p_end}

{pstd}
It also works the other way round. On a new delivery, run the scan first and use
its {cmd:gated_by} output as the draft of the skip-logic table, then check the
draft against the questionnaire. The draft is derived from what respondents
actually saw.{p_end}


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
Lanes always partition the sample: the categories you kept, one {bf:other} lane
for the rest, and one {bf:no answer} lane for people who left the gate blank.
Their counts sum to the number of respondents in scope, so nobody is lost and
nobody is counted twice.{p_end}

{pstd}
A gate must be numeric. A string variable would make one lane per distinct
answer, which is not a branch; {cmd:surveymap} says so and continues with the
other gates.{p_end}

{pstd}
With no {opt branch()}, the two questions that route the most respondents are
drawn, and the receipt names them. {opt noautodetect} turns that off.{p_end}


{marker detect}{...}
{title:How routing is found}

{pstd}
{cmd:surveymap} reads routing out of the answers, because that is the only
record of the instrument in the data. Category {it:v} of gate {it:g} is
recorded as routing people around item {it:i} when almost nobody in that lane
answered {it:i} while the other lanes did:{p_end}

{phang2}
answer rate of {it:i} within {it:g}{cmd:==}{it:v} at most {bf:2%}, and{p_end}
{phang2}
answer rate of {it:i} among {it:g}'s other answered categories at least {bf:50%}{p_end}

{pstd}
{opt detect(# #)} sets the two thresholds. Raise the first if a routed item
still collected a few stray answers; lower the second if the people who were
asked answer it patchily.{p_end}

{pstd}
This is evidence, not a questionnaire spec. An item that everyone in a category
happened not to answer looks exactly like an item they were never shown, and the
receipt says so once. Read a detected gate as a claim to check, not a fact, and
name the gates yourself with {opt branch()} when you know the instrument.{p_end}


{marker prune}{...}
{title:Pruning noisy branches}

{pstd}
A gate with a long tail of small categories draws a map nobody can read. Three
rules fold the small ones into one {bf:other} lane:{p_end}

{synoptset 26 tabbed}{...}
{synopt :{opt prune(#)}}fold a category under {it:#} percent of the sample {it:(default 5)}{p_end}
{synopt :{opt minn(#)}}fold a category under {it:#} respondents {it:(default 30)}{p_end}
{synopt :{opt maxc:ats(#)}}keep at most the {it:#} largest {it:(default 6)}{p_end}
{synopt :{opt noprune}}keep every category{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
The journal keeps every category whatever the rules say, and the folding happens
when a map or a tracker is built. So the rules can change at draw time without
reading the data again:{p_end}

{phang2}{cmd:. surveymap, branch(party)}{p_end}
{phang2}{cmd:. surveymap draw, prune(10)}{p_end}
{phang2}{cmd:. surveymap draw, noprune}{p_end}

{pstd}
Set them on the scan instead and they become the default every later drawing
inherits. Categories you leave out of an explicit {cmd:branch(}{it:var}
{cmd:= ...)} list are a different matter: that is a statement about what the
lanes are, it is recorded in the journal, and only {opt noprune} shows them
again.{p_end}


{marker draw}{...}
{title:Drawing the map}

{pstd}
{cmd:surveymap draw} turns the last journal into a picture. With no argument it
draws whatever the last scan wrote, in this session or a later one.{p_end}

{synoptset 22 tabbed}{...}
{synopt :{opt export(html)}}a self-contained page: no internet, no JavaScript {it:(the default)}{p_end}
{synopt :{opt export(mermaid)}}text that GitHub, Quarto and VS Code render{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
{bf:Reading it.} Items run left to right in questionnaire order along a spine.
Each box shows the item name, its label, and the count and percent who
answered; {cmd:!!} marks an item a lot of people declined. Where a gate splits
the sample the spine fans into lanes, headed {bf:split by} the gate's name and
labelled with each category and its size. Inside a lane, a normal box is an item
that lane answered and a {bf:dashed grey box} is one it was routed around. The
lanes rejoin at a dot and the spine continues. Hover any box for the full
record.{p_end}

{pstd}
The lanes open where the gate's items are, which is not always the next column:
a party question asked early can decide primary-turnout questions much later, and
the lanes belong where those questions sit.{p_end}

{pstd}
The page has no height cap and the diagram scrolls sideways, because a survey is
wider than it is tall. {opt embed} writes a fragment for a report page instead of
a whole document: scoped styles, no element selectors, and a bounded box, so it
cannot restyle the page it is dropped into.{p_end}


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
Counts arrive as numbers, so Excel sorts and filters them as numbers. The map can
hide the small lanes while the workbook keeps all of them: pass {opt noprune} to
the export and the tracker is complete whatever the drawing shows.{p_end}

{pstd}
{opt format(dta)} and {opt format(csv)} write the whole journal as data, which is
the form to merge with anything else you track.{p_end}


{marker dd}{...}
{title:Working with datadictionary}

{pstd}
{helpb datadictionary} documents what a survey's variables {it:are}:  types,
labels, value labels, summary statistics, and how labels changed across waves.
{cmd:surveymap} documents how respondents {it:moved} through them. The two fit
together in one codebook, and neither needs the other installed.{p_end}

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
One workbook then holds the item definitions, the response distributions, the
label history, and the flow. The join key on both sides is the variable name,
so a lookup across sheets is one formula.{p_end}


{marker options}{...}
{title:Options}

{dlgtab:Scan}

{synoptset 26 tabbed}{...}
{synopt :{opt br:anch(spec)}}the gates to split the flow by; see {help surveymap##branch:Branching}{p_end}
{synopt :{opt out(filename)}}write the journal here; default {cmd:survey_journal.tsv}{p_end}
{synopt :{opt non:response(numlist)}}coded values that mean a refusal, such as {cmd:98 99}. Extended missings always count as declined{p_end}
{synopt :{opt ex:clude(varlist)}}columns to leave out: ids, sample frame, admin{p_end}
{synopt :{opt nostrings}}leave the string columns out, which are usually verbatims{p_end}
{synopt :{opt ver:ify(filename)}}check the routing found against a declared skip-logic table{p_end}
{synopt :{opt det:ect(# #)}}the two routing thresholds; default {cmd:2 50}{p_end}
{synopt :{opt noautodetect}}do not look for gates; draw only the ones named in {opt branch()}{p_end}
{synopt :{opt noreceipt}}skip the receipt table{p_end}
{synopt :{opt replace}}overwrite an existing journal{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
A {varlist} chooses which items to map, not what order they were asked in: the
columns keep their dataset order either way. {cmd:if} and {cmd:in} restrict the
respondents in scope, and every count and percent is computed within it.{p_end}

{dlgtab:Pruning (scan, draw and export)}

{synoptset 26 tabbed}{...}
{synopt :{opt prune(#)}}fold a category under {it:#} percent; default {cmd:5}{p_end}
{synopt :{opt minn(#)}}fold a category under {it:#} respondents; default {cmd:30}{p_end}
{synopt :{opt maxc:ats(#)}}keep at most the {it:#} largest; default {cmd:6}{p_end}
{synopt :{opt noprune}}keep every category{p_end}
{synoptline}
{p2colreset}{...}

{dlgtab:Draw}

{synoptset 26 tabbed}{...}
{synopt :{opt exp:ort(html|mermaid)}}the medium; default {cmd:html}{p_end}
{synopt :{opt sav:ing(filename)}}where to write it{p_end}
{synopt :{opt name(text)}}what to call the survey on the page{p_end}
{synopt :{opt embed}}a fragment for someone else's page, not a whole document{p_end}
{synopt :{opt noopen}}write the page but do not open a browser{p_end}
{synopt :{opt replace}}overwrite existing output{p_end}
{synoptline}
{p2colreset}{...}

{dlgtab:Export}

{synoptset 26 tabbed}{...}
{synopt :{opt sav:ing(filename)}}where to write it; the extension picks the format{p_end}
{synopt :{opt f:ormat(xlsx|dta|csv)}}the format, when {opt saving()} does not say{p_end}
{synopt :{opt dict:ionary(filename)}}add the sheets to an existing {helpb datadictionary} workbook{p_end}
{synoptline}
{p2colreset}{...}


{marker examples}{...}
{title:Examples}

{pstd}{bf:See it work, with no setup}{p_end}
{phang2}{stata "surveymap demo":. surveymap demo}{p_end}

{pstd}{bf:Map the survey in memory}{p_end}
{phang2}{cmd:. surveymap}{p_end}

{pstd}{bf:Map the questions, leaving the identifiers and paradata out}{p_end}
{phang2}{cmd:. surveymap q1-q42}{p_end}
{phang2}{cmd:. surveymap, exclude(respid wtfinal interviewer) nostrings}{p_end}

{pstd}{bf:A weighted survey: both counts, side by side}{p_end}
{phang2}{cmd:. surveymap [pweight=wtfinal], exclude(respid) nostrings}{p_end}

{pstd}{bf:Does the file agree with the questionnaire about who was asked?}{p_end}
{phang2}{cmd:. surveymap, verify(skiplogic.csv)}{p_end}

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

{pstd}{bf:I know the instrument; do not guess at gates}{p_end}
{phang2}{cmd:. surveymap, branch(screener) noautodetect}{p_end}

{pstd}{bf:Draw what was just scanned}{p_end}
{phang2}{cmd:. surveymap draw}{p_end}

{pstd}{bf:The same map with the small lanes kept, then with fewer}{p_end}
{phang2}{cmd:. surveymap draw, noprune}{p_end}
{phang2}{cmd:. surveymap draw, prune(10) maxcats(4)}{p_end}

{pstd}{bf:A fragment for a report page, and text for a README}{p_end}
{phang2}{cmd:. surveymap draw, saving(flow_frag.html) embed replace}{p_end}
{phang2}{cmd:. surveymap draw, export(mermaid) saving(flow) replace}{p_end}

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
Lanes do not nest. Each item belongs to at most one gate's segment, the nearer
one when two gates both route it, so a map shows one level of branching at a
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
Counts and percentages are unweighted. For weighted estimates, read the journal
as data and apply your own weights.{p_end}


{marker results}{...}
{title:Stored results}

{pstd}{cmd:surveymap} stores the following in {cmd:r()}:{p_end}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}respondents in scope{p_end}
{synopt:{cmd:r(K_items)}}items mapped{p_end}
{synopt:{cmd:r(N_gates)}}gates drawn{p_end}
{synopt:{cmd:r(N_mismatch)}}after {opt verify()}: declared gates the data does not agree with{p_end}
{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(journal)}}path to the journal file{p_end}
{synopt:{cmd:r(gates)}}the gate variables drawn{p_end}
{synopt:{cmd:r(output)}}after {cmd:draw}: the file it wrote{p_end}
{synopt:{cmd:r(file)}}after {cmd:export}: the tracker it wrote{p_end}
{p2colreset}{...}

{pstd}
The journal's columns, for reading the file yourself:
{cmd:seq class var position vallabel value gatevar n_asked n_answered}
{cmd:n_nonresp n_sysmiss pct_answered rate status gate gated_by pooled type}
{cmd:severity flags w_asked w_answered pct_answered_w}. The last three are `.` unless a
weight was given. {cmd:class} is one of {cmd:survey item cat cell note}:
{cmd:item} rows are the tracker, {cmd:cat} rows are a gate's categories, and
{cmd:cell} rows are one lane against one item.{p_end}


{marker related}{...}
{title:Related commands}

{pstd}
{cmd:surveymap} draws boxes and lanes because a survey node has to show more
than a width: the item name, its label, how many were asked, how many answered,
and how many declined. The commands below draw flows in other shapes, and are
the better tool when that is the shape you want.{p_end}

{phang2}
{bf:For a ribbon whose width is the count.} {cmd:sankey} and {cmd:alluvial}
(Naqvi) draw flow widths from {cmd:from}/{cmd:to}/{cmd:value} data. Beautiful for
two or three transitions; a survey has too many columns and too much per node for
a ribbon to show.{p_end}

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
