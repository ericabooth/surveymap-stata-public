*! runall.do -- regenerate every artifact in gallery/ from scratch.
*! Author: Eric Booth
*
* Run headless from this directory:
*     cd gallery
*     /Applications/StataNow/StataMP.app/Contents/MacOS/stata-mp -b do runall.do
* then check the log:  grep '^r([0-9]' runall.log   (should print nothing)
*
* Exit status is not a check. A Stata do-file can abort and still leave the
* runner reporting success, so the log is the record: this script counts its
* own failures and prints a verdict at the end.
*
* What it builds, all from one fake survey and one journal per scan:
*   1. the fixture             fake_survey.dta
*   2. plain scan              g_plain.tsv          + receipt
*   3. weighted scan           g_weighted.tsv       + receipt with wtd%
*   4. branched scan           g_branched.tsv       (party and voting gates)
*   5. HTML maps               g_map.html, g_map_weighted.html, g_frag.html
*   6. mermaid text            g_map.mmd / .md
*   7. PNG and SVG figures     g_fig.png / g_fig.svg
*   8. the Excel tracker       g_tracker.xlsx
*   9. a verify run            g_verify.log against a declared skip table
*  10. gallery.html            an index of everything above
*
* Every path here is relative to gallery/, and nothing outside it is written.

version 16
clear all
set more off
set graphics off

capture log close gallery
log using runall.log, replace text name(gallery) nomsg

global GFAIL = 0
capture program drop gok
program define gok
    args cond label
    if `cond' {
        display as text "  ok    " as result "`label'"
    }
    else {
        display as error "  FAIL  `label'"
        global GFAIL = $GFAIL + 1
    }
end

* the package under test is the working tree, not whatever is installed
adopath ++ "../src"
capture which surveymap
gok `=(_rc == 0)' "surveymap resolves from ../src"

display as text _n "{hline 70}"
display as text "1. the fixture"
display as text "{hline 70}"
do ../tests/make_fake_survey.do
sm_makefake, n(1200) saving(fake_survey.dta)
gok `=(_N == 1200)' "1,200 respondents built"
* a weight with a visible effect, so the weighted artifacts differ from the rest
quietly gen double wt = cond(inlist(q3_party, 1, 3), 1.30, 0.78)
quietly replace wt = 0 if q1_consent == 0
quietly save fake_survey.dta, replace

display as text _n "{hline 70}"
display as text "2. a plain scan, with the columns that are not questions left out"
display as text "{hline 70}"
use fake_survey.dta, clear
capture noisily surveymap, nostrings exclude(resp_id wt) out(g_plain.tsv) replace
gok `=(_rc == 0)' "plain scan"
local KPLAIN = r(K_items)

display as text _n "{hline 70}"
display as text "3. the same survey, weighted"
display as text "{hline 70}"
use fake_survey.dta, clear
capture noisily surveymap [pweight=wt], nostrings exclude(resp_id) ///
    out(g_weighted.tsv) replace
gok `=(_rc == 0)' "weighted scan"
gok `=(r(N) < 1200)' "the zero-weight respondents left the scope"

display as text _n "{hline 70}"
display as text "4. branching on party and on whether they voted"
display as text "{hline 70}"
use fake_survey.dta, clear
capture noisily surveymap q1_consent q3_party q4_reg q5_voted q6_whovote  ///
    q7_whynot q8_approve q9_econ q10_dem_prim q11_rep_prim q12_ideol      ///
    q13_income [pweight=wt], branch(q3_party = 1 2 3, q5_voted)           ///
    out(g_branched.tsv) replace
gok `=(_rc == 0)' "branched scan"
gok `=(r(N_gates) == 2)' "two gates drawn"

display as text _n "{hline 70}"
display as text "5. HTML maps"
display as text "{hline 70}"
capture noisily surveymap draw g_branched.tsv, export(html) saving(g_map.html) ///
    replace noopen
gok `=(_rc == 0)' "the branched map"
capture noisily surveymap draw g_weighted.tsv, export(html)      ///
    saving(g_map_weighted.html) replace noopen
gok `=(_rc == 0)' "the weighted map"
capture noisily surveymap draw g_branched.tsv, export(html) saving(g_frag.html) ///
    replace embed
gok `=(_rc == 0)' "an embed fragment for a report page"

* a questionnaire is long and a report page scrolls down, so the same map
* reads better on the page turned on its side
capture noisily surveymap draw g_branched.tsv, export(html) layout(vertical) ///
    saving(g_map_vertical.html) replace noopen
gok `=(_rc == 0)' "the same map, top to bottom"

display as text _n "{hline 70}"
display as text "6. mermaid text"
display as text "{hline 70}"
capture noisily surveymap draw g_branched.tsv, export(mermaid) saving(g_map) replace
gok `=(_rc == 0)' "mermaid"
capture noisily surveymap draw g_branched.tsv, export(mermaid) layout(vertical) ///
    saving(g_map_vertical) replace
gok `=(_rc == 0)' "mermaid, top to bottom with a swimlane per lane"

display as text _n "{hline 70}"
display as text "7. PNG and SVG, through Stata's own graph engine"
display as text "{hline 70}"
* a figure is only readable up to a point, so this one is a short survey
use fake_survey.dta, clear
capture noisily surveymap q1_consent q3_party q5_voted q6_whovote q7_whynot ///
    q8_approve q13_income, out(g_fig.tsv) replace noreceipt
gok `=(_rc == 0)' "the figure's own scan"
capture noisily surveymap draw g_fig.tsv, export(png) saving(g_fig) replace
gok `=(_rc == 0)' "png and svg"

display as text _n "{hline 70}"
display as text "7b. splitting the map by what the respondent did"
display as text "{hline 70}"
* not "what did Republicans answer" but "what does the route look like for
* the people who left items blank".  The lanes are derived, and every
* renderer says so on the node itself.
use fake_survey.dta, clear
capture noisily surveymap q1_consent q3_party q4_reg q5_voted q6_whovote  ///
    q7_whynot q8_approve q9_econ q10_dem_prim q11_rep_prim q12_ideol      ///
    q13_income, profile(declined) out(g_profile.tsv) replace noreceipt
gok `=(_rc == 0)' "a derived-condition scan"
capture noisily surveymap draw g_profile.tsv, export(html) layout(vertical) ///
    saving(g_profile.html) replace noopen
gok `=(_rc == 0)' "the derived-condition map"
capture noisily surveymap draw g_profile.tsv, export(mermaid) layout(vertical) ///
    saving(g_profile) replace
gok `=(_rc == 0)' "the same, as mermaid"

display as text _n "{hline 70}"
display as text "7c. the band chart, which has no node budget"
display as text "{hline 70}"
* the flow map refuses past maxnodes(); this is what a long instrument gets
capture noisily surveymap band g_branched.tsv, saving(g_band.png) replace ///
    title("Where the instrument leaks")
gok `=(_rc == 0)' "the band chart"
gok `=(r(devmax) == 0)' "every column accounts for the whole scope"

display as text _n "{hline 70}"
display as text "8. the Excel tracker"
display as text "{hline 70}"
capture noisily surveymap export g_branched.tsv, saving(g_tracker.xlsx) ///
    noprune replace
gok `=(_rc == 0)' "tracker, with every lane kept"

display as text _n "{hline 70}"
display as text "9. checking the map against a declared skip table"
display as text "{hline 70}"
* the table a survey project would keep by hand; the last row is deliberately
* wrong, so the gallery shows what a disagreement looks like
capture erase g_declared.csv
tempname dh
file open `dh' using g_declared.csv, write text replace
file write `dh' "study,varname,gate_expr,expected_n,note" _n
file write `dh' "1,q6_whovote,q5_voted==1,578,vote choice asked of voters" _n
file write `dh' "1,q7_whynot,q5_voted==0,507,reason asked of non-voters" _n
file write `dh' "1,q10_dem_prim,inlist(q3_party 1 3),591,dem primary" _n
file write `dh' "1,q11_rep_prim,inlist(q3_party 2 3),999,deliberately wrong" _n
file close `dh'
use fake_survey.dta, clear
capture noisily surveymap q1_consent q3_party q5_voted q6_whovote q7_whynot ///
    q10_dem_prim q11_rep_prim, out(g_verify.tsv) replace noreceipt          ///
    verify(g_declared.csv)
gok `=(_rc == 0)' "verify runs"
gok `=(r(N_mismatch) == 1)' "it finds the one row that disagrees"

display as text _n "{hline 70}"
display as text "10. the index page"
display as text "{hline 70}"
capture erase gallery.html
tempname gh
file open `gh' using gallery.html, write text replace
file write `gh' "<!DOCTYPE html>" _n
file write `gh' `"<html lang="en"><head><meta charset="utf-8" />"' _n
file write `gh' "<title>surveymap gallery</title>" _n
file write `gh' "<style>" _n
file write `gh' "body { font-family: -apple-system, Segoe UI, Helvetica, Arial, sans-serif;" _n
file write `gh' "  color: #222; background: #fff; margin: 32px; max-width: 1100px; }" _n
file write `gh' "h1 { font-size: 20px; margin: 0 0 4px 0; }" _n
file write `gh' "h2 { font-size: 15px; margin: 26px 0 6px 0; }" _n
file write `gh' "p, li { font-size: 14px; line-height: 1.5; color: #333; }" _n
file write `gh' ".sub { color: #666; font-size: 13px; margin: 0 0 18px 0; }" _n
file write `gh' "code { font-family: SF Mono, Menlo, Consolas, monospace; font-size: 13px; }" _n
file write `gh' "img { max-width: 100%; border: 1px solid #e4e4e4; border-radius: 4px; }" _n
file write `gh' "</style></head><body>" _n
file write `gh' "<h1>surveymap gallery</h1>" _n
file write `gh' `"<p class="sub">Every file here is regenerated by <code>gallery/runall.do</code> from one fake survey. Nothing is hand-edited.</p>"' _n

file write `gh' "<h2>The flow map</h2>" _n
file write `gh' "<p>A twelve-item poll, weighted, branched on party and on whether the respondent voted. Dashed grey boxes are questions that lane was never shown.</p>" _n
file write `gh' `"<p><a href="g_map.html">g_map.html</a> &#183; <a href="g_map_weighted.html">g_map_weighted.html</a> (no branching) &#183; <a href="g_frag.html">g_frag.html</a> (a fragment for a report page)</p>"' _n

file write `gh' "<h2>The same map as a figure</h2>" _n
file write `gh' "<p>Through Stata's own graph engine, for a paper or a slide.</p>" _n
file write `gh' `"<p><img src="g_fig.png" alt="surveymap figure" /></p>"' _n
file write `gh' `"<p><a href="g_fig.png">g_fig.png</a> &#183; <a href="g_fig.svg">g_fig.svg</a></p>"' _n

file write `gh' "<h2>As text</h2>" _n
file write `gh' "<p>Mermaid, which GitHub and Quarto draw themselves.</p>" _n
file write `gh' `"<p><a href="g_map.mmd">g_map.mmd</a> &#183; <a href="g_map.md">g_map.md</a></p>"' _n

file write `gh' "<h2>The journals</h2>" _n
file write `gh' "<p>One tab-separated line per event. Every picture above is built from one of these, so a drawing can be re-cut without reading the data again.</p>" _n
file write `gh' `"<p><a href="g_plain.tsv">g_plain.tsv</a> &#183; <a href="g_weighted.tsv">g_weighted.tsv</a> &#183; <a href="g_branched.tsv">g_branched.tsv</a></p>"' _n

file write `gh' "<h2>The tracker</h2>" _n
file write `gh' "<p>Three sheets: one row per item, one per gate category, one per lane and item.</p>" _n
file write `gh' `"<p><a href="g_tracker.xlsx">g_tracker.xlsx</a></p>"' _n

file write `gh' "<h2>Checking the map against a questionnaire</h2>" _n
file write `gh' "<p>The declared table here has one deliberately wrong row, so the run shows what a disagreement looks like.</p>" _n
file write `gh' `"<p><a href="g_declared.csv">g_declared.csv</a> &#183; <a href="runall.log">runall.log</a></p>"' _n

file write `gh' "<h2>How to rebuild it</h2>" _n
file write `gh' `"<p><code>cd gallery</code> then <code>stata-mp -b do runall.do</code>, and read <code>runall.log</code>. The log ends with a pass or fail count; the exit status is not the check.</p>"' _n
file write `gh' "</body></html>" _n
file close `gh'
gok `=(1)' "gallery.html written"

display as text _n "{hline 70}"
display as text "gallery: " as result "$GFAIL failed"
display as text "{hline 70}"
if $GFAIL == 0 display as result "ALL GALLERY STEPS PASSED"
else display as error "SOME GALLERY STEPS FAILED"

capture program drop gok
log close gallery
