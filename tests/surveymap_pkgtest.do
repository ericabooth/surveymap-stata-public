*! surveymap_pkgtest.do -- regression battery for surveymap
*! Eric Booth
*
* Run from this directory:
*     cd tests
*     do surveymap_pkgtest.do
* or headless:
*     /Applications/Stata/StataMP.app/Contents/MacOS/stata-mp -b do surveymap_pkgtest.do
*
* Every block prints PASS or FAIL and the battery ends with a count.  A block
* marked OPEN is a known gap that is not yet implemented; it reports OPEN
* instead of FAIL so the battery stays readable while the gaps are worked off.
* Asserts whose exact wording or count the engine has not yet pinned down carry
* a trailing "* INTEGRATION: verify" comment.

version 16
clear all
set more off
set linesize 100

* ---------------------------------------------------------------- harness ----
global SM_PASS = 0
global SM_FAIL = 0
global SM_OPEN = 0

* call as:  sm_assert `=(<expression>)' "label"
* the expression must be evaluated by the caller: -args- splits on spaces,
* so a bare (a == b) would arrive as three separate arguments.
program define sm_assert
    args cond label
    if `cond' {
        display as text "  PASS  " as result "`label'"
        global SM_PASS = $SM_PASS + 1
    }
    else {
        display as error "  FAIL  `label'"
        global SM_FAIL = $SM_FAIL + 1
    }
end

program define sm_openx
    args label
    display as text "  OPEN  `label'"
    global SM_OPEN = $SM_OPEN + 1
end

program define sm_block
    args n label
    display as text _n "{hline 78}"
    display as text "BLOCK `n': `label'"
    display as text "{hline 78}"
end

* count the data rows of a journal (header line excluded)
program define sm_jrows, rclass
    args jfile
    tempname fh
    local n = 0
    file open `fh' using `"`jfile'"', read text
    file read `fh' line
    while r(eof) == 0 {
        local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar rows = `n' - 1
end

* return the raw header line of a journal in r(hdr)
program define sm_jhdr, rclass
    args jfile
    tempname fh
    file open `fh' using `"`jfile'"', read text
    file read `fh' line
    file close `fh'
    return local hdr `"`macval(line)'"'
end

* does the journal contain a row whose fields include all of the given needles?
program define sm_jhas, rclass
    args jfile n1 n2 n3
    tempname fh
    local hit = 0
    file open `fh' using `"`jfile'"', read text
    file read `fh' line
    while r(eof) == 0 {
        local ok = 1
        if `"`n1'"' != "" & strpos(`"`macval(line)'"', `"`n1'"') == 0 local ok = 0
        if `"`n2'"' != "" & strpos(`"`macval(line)'"', `"`n2'"') == 0 local ok = 0
        if `"`n3'"' != "" & strpos(`"`macval(line)'"', `"`n3'"') == 0 local ok = 0
        if `ok' local hit = 1
        file read `fh' line
    }
    file close `fh'
    return scalar hit = `hit'
end

* read one field of one journal row, selected by named columns rather than by
* seq: whole-line matching (sm_jhas) gives false positives -- "q13_income"
* contains "3" -- so anything numeric must come from a named column of a
* selected row.  Selectors equal to "*" (or empty) match anything.
*   sm_jval <journal> <col> <class> <var> [<value> <gatevar>]  ->  r(val)
program define sm_jval, rclass
    args jfile col cls var value gatevar
    tempname fr
    frame create `fr'
    local val ""
    frame `fr' {
        quietly import delimited using `"`jfile'"', delimiter(tab) ///
            varnames(1) stringcols(_all) clear
        quietly gen byte sm_pick = 1
        if !inlist(`"`cls'"', "", "*")     quietly replace sm_pick = 0 if class   != `"`cls'"'
        if !inlist(`"`var'"', "", "*")     quietly replace sm_pick = 0 if var     != `"`var'"'
        if !inlist(`"`value'"', "", "*")   quietly replace sm_pick = 0 if value   != `"`value'"'
        if !inlist(`"`gatevar'"', "", "*") quietly replace sm_pick = 0 if gatevar != `"`gatevar'"'
        quietly count if sm_pick
        if r(N) > 0 {
            quietly levelsof `col' if sm_pick, local(vv) clean
            local val `"`vv'"'
        }
    }
    frame drop `fr'
    return local val `"`val'"'
end

* count journal rows by class / var / gatevar, optionally only pooled ones
*   sm_jcount <journal> <class> <var> <gatevar> [pooled]  ->  r(n)
program define sm_jcount, rclass
    args jfile cls var gatevar pooled
    tempname fr
    frame create `fr'
    local n = 0
    frame `fr' {
        quietly import delimited using `"`jfile'"', delimiter(tab) ///
            varnames(1) stringcols(_all) clear
        quietly gen byte sm_pick = 1
        if !inlist(`"`cls'"', "", "*")     quietly replace sm_pick = 0 if class   != `"`cls'"'
        if !inlist(`"`var'"', "", "*")     quietly replace sm_pick = 0 if var     != `"`var'"'
        if !inlist(`"`gatevar'"', "", "*") quietly replace sm_pick = 0 if gatevar != `"`gatevar'"'
        if `"`pooled'"' == "pooled"        quietly replace sm_pick = 0 if pooled  != "1"
        quietly count if sm_pick
        local n = r(N)
    }
    frame drop `fr'
    return scalar n = `n'
end

* sum a numeric column over selected rows (for the lane-partition checks)
*   sm_jsumn <journal> <col> <class> <gatevar> [<var>]  ->  r(sum)
program define sm_jsumn, rclass
    args jfile col cls gatevar var
    tempname fr
    frame create `fr'
    local s = .
    frame `fr' {
        quietly import delimited using `"`jfile'"', delimiter(tab) ///
            varnames(1) stringcols(_all) clear
        quietly gen byte sm_pick = 1
        if !inlist(`"`cls'"', "", "*")     quietly replace sm_pick = 0 if class   != `"`cls'"'
        if !inlist(`"`gatevar'"', "", "*") quietly replace sm_pick = 0 if gatevar != `"`gatevar'"'
        if !inlist(`"`var'"', "", "*")     quietly replace sm_pick = 0 if var     != `"`var'"'
        quietly gen double sm_v = real(`col') if sm_pick
        quietly summarize sm_v, meanonly
        local s = cond(r(N) > 0, r(sum), .)
    }
    frame drop `fr'
    return scalar sum = `s'
end

* lines in a file that contain a string -> r(n)
program define sm_fcount, rclass
    args f str
    tempname fh
    local n = 0
    file open `fh' using `"`f'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`str'"') local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

* is there a line containing BOTH needles? (e.g. <title> plus the map's name)
program define sm_flinehas, rclass
    args f n1 n2
    tempname fh
    local hit = 0
    file open `fh' using `"`f'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`n1'"') & ///
           strpos(`"`macval(line)'"', `"`n2'"') local hit = 1
        file read `fh' line
    }
    file close `fh'
    return scalar hit = `hit'
end

* count mermaid fence lines without ever writing a literal backtick in this
* file, and without expanding a backtick-bearing line as a macro (TRAPS 1, 8):
* the file is read as data, so the fence characters never meet the macro
* scanner; a fence line starts with char(96) and names mermaid.
program define sm_fencen, rclass
    args f
    tempname fr
    frame create `fr'
    local n = 0
    frame `fr' {
        quietly import delimited using `"`f'"', delimiter(tab) ///
            varnames(nonames) stringcols(_all) clear
        quietly count if substr(v1, 1, 1) == char(96) & strpos(v1, "mermaid") > 0
        local n = r(N)
    }
    frame drop `fr'
    return scalar n = `n'
end

* ---------------------------------------------------------------- set-up ----
* Use a scratch subdirectory so the battery never disturbs the repo.
capture mkdir pkgtest_tmp
cd pkgtest_tmp

* make the package findable whether or not surveymap is installed
adopath ++ ".."
adopath ++ "../../src"
capture discard

capture which surveymap
if _rc {
    display as error "surveymap.ado not found on the adopath: every scan block below will FAIL"
}

* ============================================================================
sm_block 1 "the fixture builds and is deterministic"
* ============================================================================
capture noisily do ../make_fake_survey.do
sm_assert `=(_rc == 0)' "make_fake_survey.do loads"
capture noisily sm_makefake, n(1200) saving(fake_a.dta)
sm_assert `=(_rc == 0)' "sm_makefake writes the fixture"
capture confirm file fake_a.dta
sm_assert `=(_rc == 0)' "fake_a.dta exists"
capture noisily sm_makefake, n(1200) saving(fake_b.dta)
sm_assert `=(_rc == 0)' "sm_makefake runs a second time"
* never byte-compare .dta files (TRAPS 15): datasignature ignores timestamps
local s1 ""
local s2 "x"
capture {
    quietly use fake_a.dta, clear
    quietly datasignature
    local s1 `"`r(datasignature)'"'
    quietly use fake_b.dta, clear
    quietly datasignature
    local s2 `"`r(datasignature)'"'
}
sm_assert `=("`s1'" == "`s2'" & "`s1'" != "")' "two builds carry the same datasignature"
capture {
    quietly use fake_a.dta, clear
    quietly describe, short
}
sm_assert `=(_N == 1200 & c(k) == 16)' "1,200 respondents, 16 columns"

* ============================================================================
sm_block 2 "bare scan: one journal, exact columns, remembered path"
* ============================================================================
capture use fake_a.dta, clear
capture noisily surveymap, out(j2.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "the bare scan runs"
sm_assert `=(r(N) == 1200)' "r(N) reports the 1,200 respondents in scope"
capture confirm file j2.tsv
sm_assert `=(_rc == 0)' "the journal file exists"
sm_assert `=(strpos(`"$SM_LASTJ"', "j2.tsv") > 0)' "SM_LASTJ remembers the journal"
capture sm_jcount j2.tsv survey
sm_assert `=(r(n) == 1)' "exactly one survey row"
capture sm_jcount j2.tsv item
sm_assert `=(r(n) == 16)' "16 item rows, in questionnaire order"    // * INTEGRATION: verify (15 if resp_id is auto-excluded as an id)
* the 20-column header, exactly as proto/JOURNAL_SCHEMA.md orders it
local T = char(9)
local want "seq`T'class`T'var`T'position`T'vallabel`T'value`T'gatevar`T'n_asked`T'n_answered`T'n_nonresp`T'n_sysmiss`T'pct_answered`T'rate`T'status`T'gate`T'gated_by`T'pooled`T'type`T'severity`T'flags`T'w_asked`T'w_answered`T'pct_answered_w"
capture sm_jhdr j2.tsv
local ok = (`"`r(hdr)'"' == `"`want'"')
sm_assert `=(`ok')' "the header carries the 23 schema columns, by name and in order"
* the three weighted columns are appended, so a v1 reader still finds the first
* twenty where it expects them
local w20 = strpos(`"`r(hdr)'"', `"`T'w_asked`T'w_answered`T'pct_answered_w"')
sm_assert `=(`w20' > 0)' "the weighted columns are appended after flags, not inserted"

* ============================================================================
sm_block 3 "nonresponse accounting: refusal is not routing"
* ============================================================================
* q13_income: ~18% .b refusals, so pct_answered is low -- but nobody was
* routed around it, so gated_by stays empty ("." in the journal).
capture sm_jval j2.tsv n_nonresp item q13_income
sm_assert `=(real("`r(val)'") > 150 & real("`r(val)'") < .)' "q13_income n_nonresp is large (>150 of 1,200)"
capture sm_jval j2.tsv pct_answered item q13_income
sm_assert `=(real("`r(val)'") < 85)' "q13_income pct_answered sits below 85"
capture sm_jval j2.tsv gated_by item q13_income
* the consent screener routes around every later item, q13 included; what
* makes q13 the refusal case is that no OTHER gate explains its gap
sm_assert `=(strpos("`r(val)'", "q3_party") == 0 & strpos("`r(val)'", "q5_voted") == 0)' ///
    "q13_income is not routed by a survey gate: its gap is refusal, not routing"    // * INTEGRATION: verify (q1_consent hard gate must not leak in here)

* ============================================================================
sm_block 4 "skip detection reads the routing out of the data"
* ============================================================================
capture sm_jval j2.tsv gated_by item q6_whovote
local g6 `"`r(val)'"'
sm_assert `=(strpos(`"`g6'"', "q5_voted==0") > 0)' "q6_whovote is gated by q5_voted==0"
* whether the consent screener also clears the detection bar for q6 is a
* threshold question; the routing that matters is the voting filter
sm_assert `=(strpos(`"`g6'"', "q5_voted==0") > 0)' ///
    "q6_whovote names the gate that routes it, whatever else correlates"
capture sm_jval j2.tsv gated_by item q7_whynot
sm_assert `=(strpos(`"`r(val)'"', "q5_voted==1") > 0)' "q7_whynot is gated by q5_voted==1"
capture sm_jval j2.tsv gated_by item q10_dem_prim
local g10 `"`r(val)'"'
sm_assert `=(strpos(`"`g10'"', "q3_party==2 4") > 0)' "q10_dem_prim is gated by q3_party==2 4"    // * INTEGRATION: verify exact multi-value form
capture sm_jval j2.tsv gated_by item q11_rep_prim
local g11 `"`r(val)'"'
sm_assert `=(strpos(`"`g11'"', "q3_party==1 4") > 0)' "q11_rep_prim is gated by q3_party==1 4"    // * INTEGRATION: verify exact multi-value form
capture sm_jval j2.tsv status item q6_whovote
sm_assert `=("`r(val)'" == "gated")' "a gated item has status gated"
capture sm_jval j2.tsv gate item q5_voted
sm_assert `=("`r(val)'" == "1")' "q5_voted carries the gate flag"    // * INTEGRATION: verify (flag on all detected gates vs the drawn two)

* detect() moves the thresholds; noautodetect turns inference off entirely
capture use fake_a.dta, clear
capture noisily surveymap, out(j4a.tsv) noreceipt replace detect(2 50)
sm_assert `=(_rc == 0)' "detect(2 50) is accepted"
capture sm_jval j4a.tsv gated_by item q6_whovote
sm_assert `=(strpos(`"`r(val)'"', "q5_voted==0") > 0)' "the default thresholds spelled out give the same detection"
capture noisily surveymap, out(j4b.tsv) noreceipt replace noautodetect
sm_assert `=(_rc == 0)' "noautodetect is accepted"
capture sm_jval j4b.tsv gated_by item q6_whovote
sm_assert `=("`r(val)'" == ".")' "noautodetect: q6_whovote is no longer marked gated"
capture sm_jval j4b.tsv gate item q5_voted
sm_assert `=("`r(val)'" != "1")' "noautodetect: no detected gate flags remain"

* ============================================================================
sm_block 5 "branch() forms"
* ============================================================================
* bare variable: every category of the gate is a lane
capture use fake_a.dta, clear
capture noisily surveymap, branch(q3_party) out(j5a.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "branch(q3_party) runs"
capture sm_jcount j5a.tsv cat "*" q3_party
sm_assert `=(r(n) == 5)' "4 party categories plus one noanswer cat row (.a/.b on the gate)"
capture sm_jhas j5a.tsv "cat" "q3_party" "noanswer"
sm_assert `=(r(hit) == 1)' "the noanswer lane is journaled"

* = numlist: listed categories are lanes, the rest pool into other
capture use fake_a.dta, clear
capture noisily surveymap, branch(q3_party = 1 3 4) out(j5b.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "branch(q3_party = 1 3 4) runs"
capture sm_jcount j5b.tsv cat "*" q3_party
sm_assert `=(r(n) == 5)' "ALL categories are still journaled (pooling is a mark, not a drop)"
capture sm_jval j5b.tsv pooled cat "*" 2 q3_party
sm_assert `=("`r(val)'" == "1")' "the unlisted category 2 is marked pooled"    // * INTEGRATION: verify
capture sm_jval j5b.tsv pooled cat "*" 1 q3_party
sm_assert `=("`r(val)'" != "1")' "a listed category is not pooled"

* = a/b range form
capture use fake_a.dta, clear
capture noisily surveymap, branch(q3_party = 1/3) out(j5c.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "branch(q3_party = 1/3) runs"
capture sm_jval j5c.tsv pooled cat "*" 4 q3_party
sm_assert `=("`r(val)'" == "1")' "the range form pools category 4"    // * INTEGRATION: verify
capture sm_jval j5c.tsv pooled cat "*" 2 q3_party
sm_assert `=("`r(val)'" != "1")' "the range form keeps category 2"

* two gates in one option, and as repeated options
capture use fake_a.dta, clear
capture noisily surveymap, branch(q3_party = 1 3, q5_voted = 1) out(j5d.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "two gates in one branch() run"
capture sm_jcount j5d.tsv cat "*" q3_party
local n1 = r(n)
capture sm_jcount j5d.tsv cat "*" q5_voted
sm_assert `=(`n1' > 0 & r(n) > 0)' "both gates carry cat rows"
capture use fake_a.dta, clear
* -syntax- cannot repeat an option, so several gates go in one branch()
capture noisily surveymap, branch(q3_party, q5_voted) out(j5e.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "two gates in one branch() run"

* bad specs are refused with r(198)
capture use fake_a.dta, clear
capture noisily surveymap, branch(q3_party = foo) out(j5f.tsv) noreceipt replace
sm_assert `=(_rc == 198)' "a non-numeric category list is refused with r(198)"
capture noisily surveymap, branch(= 1 2) out(j5g.tsv) noreceipt replace
sm_assert `=(_rc == 198)' "a branch() with no variable is refused with r(198)"

* a string gate is declined with a warning, not an error (rc 0)
capture use fake_a.dta, clear
capture noisily surveymap, branch(st) out(j5h.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "branch(st) on a string item returns rc 0"
capture sm_jhas j5h.tsv "note" "string" "st"
sm_assert `=(r(hit) == 1)' "the declined string gate leaves a note row"    // * INTEGRATION: verify wording

* ============================================================================
sm_block 6 "lanes partition the sample"
* ============================================================================
* cat n_asked over every category (kept + pooled + noanswer) sums to the
* survey n for each gate; nobody is dropped and nobody is counted twice.
capture sm_jsumn j5a.tsv n_asked cat q3_party
sm_assert `=(r(sum) == 1200)' "q3_party lanes sum to the survey n"
capture sm_jsumn j5e.tsv n_asked cat q3_party
local s1 = r(sum)
capture sm_jsumn j5e.tsv n_asked cat q5_voted
sm_assert `=(`s1' == 1200 & r(sum) == 1200)' "the lanes of both gates each sum to the survey n"
capture sm_jsumn j2.tsv n_asked cat q5_voted
sm_assert `=(r(sum) == 1200)' "the lanes of a detected gate also partition the sample"    // * INTEGRATION: verify detected-gate cat rows exist in a bare scan

* ============================================================================
sm_block 7 "pruning folds at scan time OR draw time, never in the journal"
* ============================================================================
* q3_party's four categories all clear the default prune(5)/minn(30): the
* default folds nothing.
capture sm_jcount j5a.tsv cat "*" q3_party pooled
sm_assert `=(r(n) == 0)' "default prune rules fold none of q3_party's 4 categories"
* prune(30) folds the small parties (four categories cannot all reach 30%)
capture use fake_a.dta, clear
capture noisily surveymap, branch(q3_party) prune(30) out(j7a.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "prune(30) is accepted at scan time"
* the scan records the rule and the reader applies it, so one journal can be
* drawn at several prune settings without a rescan
capture sm_jval j7a.tsv flags survey "*"
sm_assert `=(strpos(`"`r(val)'"', "prune=30") > 0)' "prune(30) is recorded in the journal for readers"
capture noisily _sm_jprune using j7a.tsv, quietly
sm_assert `=(_rc == 0 & real("`s(n_folded)'") >= 1)' "a reader folds at least one category at prune(30)"
capture sm_jcount j7a.tsv cat "*" q3_party
sm_assert `=(r(n) == 5)' "the journal still keeps every category"
* noprune keeps everything
capture use fake_a.dta, clear
capture noisily surveymap, branch(q3_party) noprune out(j7b.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "noprune is accepted"
capture sm_jcount j7b.tsv cat "*" q3_party pooled
sm_assert `=(r(n) == 0)' "noprune marks nothing pooled"
* draw-time prune needs no rescan: _sm_jprune folds on the journal alone
capture noisily _sm_jprune using j5a.tsv, prune(30) quietly
sm_assert `=(_rc == 0)' "_sm_jprune reruns the prune rules on the journal file"
sm_assert `=(real(s(n_folded)) > 0 & real(s(n_folded)) < .)' "prune(30) at read time folds categories without a rescan"
local jp `"`s(jfile)'"'
sm_assert `=(`"`jp'"' != "j5a.tsv" & `"`jp'"' != "")' "s(jfile) points at a folded copy, not the input"
capture sm_jhas `"`jp'"' "cat" "q3_party" "other"
sm_assert `=(r(hit) == 1)' "the folded copy carries an aggregated other row"
capture sm_jsumn `"`jp'"' n_asked cat q3_party
sm_assert `=(r(sum) == 1200)' "lanes still partition the sample after read-time folding"
capture sm_jhas j5a.tsv "other (pooled)"
sm_assert `=(r(hit) == 0)' "the journal itself holds no pre-aggregated other row"

* ============================================================================
sm_block 8 "if/in scan respects the sample"
* ============================================================================
capture use fake_a.dta, clear
local nc = -1
capture quietly count if q1_consent == 1
if !_rc local nc = r(N)
capture noisily surveymap if q1_consent == 1, out(j8a.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "a scan with if runs"
sm_assert `=(r(N) == `nc')' "r(N) matches the if sample"
capture sm_jval j8a.tsv n_asked survey "*"
sm_assert `=(real("`r(val)'") == `nc')' "the survey row's n_asked matches the if sample"
capture noisily surveymap in 1/600, out(j8b.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "a scan with in runs"
sm_assert `=(r(N) == 600)' "r(N) matches the in range"
capture sm_jval j8b.tsv n_asked survey "*"
sm_assert `=(real("`r(val)'") == 600)' "the survey row's n_asked matches the in range"
quietly count
sm_assert `=(r(N) == 1200)' "the data in memory are untouched by the restricted scan"

* ============================================================================
sm_block 9 "the receipt prints, and reprints from the file"
* ============================================================================
capture use fake_a.dta, clear
capture log close L9
log using l9.smcl, replace smcl name(L9) nomsg
capture noisily surveymap, out(j9.tsv) replace
local rc9 = _rc
log close L9
sm_assert `=(`rc9' == 0)' "a scan with its receipt runs"
capture sm_fcount l9.smcl "surveymap"
sm_assert `=(r(n) >= 1)' "the receipt headline names surveymap"    // * INTEGRATION: verify wording
capture sm_fcount l9.smcl "1,200"
local hitc = r(n)
capture sm_fcount l9.smcl "1200"
sm_assert `=(`hitc' + r(n) >= 1)' "the receipt reports the sample size"    // * INTEGRATION: verify wording
capture noisily surveymap receipt j9.tsv
sm_assert `=(_rc == 0)' "surveymap receipt reprints from the journal file"

* ============================================================================
sm_block 10 "surveymap demo can be run more than once"
* ============================================================================
capture noisily surveymap demo, folder(dm10)
sm_assert `=(_rc == 0)' "demo runs on a fresh folder"
capture noisily surveymap demo, folder(dm10)
sm_assert `=(_rc == 0)' "demo runs again on its own folder"
* a folder surveymap did not write is still protected
capture mkdir dm10_user
capture erase dm10_user/mywork.do
tempname uf
file open `uf' using dm10_user/mywork.do, write text replace
file write `uf' "* the user's own file" _n
file close `uf'
capture noisily surveymap demo, folder(dm10_user)
sm_assert `=(_rc == 602)' "a dirty folder without replace is refused"
capture confirm file dm10_user/mywork.do
sm_assert `=(_rc == 0)' "and the user's file is left alone"

* ============================================================================
sm_block 11 "draw html: self-contained, safe link, no browse"
* ============================================================================
capture use fake_a.dta, clear
capture noisily surveymap, out(j11.tsv) noreceipt replace
capture log close L11
log using l11.smcl, replace smcl name(L11) nomsg
capture noisily surveymap draw j11.tsv, export(html) saving(m11.html) replace noopen
local rc11 = _rc
log close L11
sm_assert `=(`rc11' == 0)' "draw writes HTML (noopen respected in batch)"
capture confirm file m11.html
sm_assert `=(_rc == 0)' "the HTML file exists"
capture sm_fcount m11.html "<script"
sm_assert `=(r(n) == 0)' "zero script tags: the page runs no JavaScript"
capture sm_fcount m11.html "viewBox"
sm_assert `=(r(n) == 1)' "one inline SVG with one viewBox"
capture sm_fcount m11.html "sm-ghost"
local gh = r(n)
capture sm_fcount m11.html "stroke-dasharray"
sm_assert `=(`gh' + r(n) > 0)' "ghost (dashed) boxes mark routed-around cells"    // * INTEGRATION: verify marker class
* the click-to-open link is a {stata _sm_open} command link, never {browse}:
* {browse} hands a file:// URL to the OS parser and aborts Stata on macOS
capture sm_fcount l11.smcl "{stata _sm_open"
sm_assert `=(r(n) >= 1)' "the open link is a {stata _sm_open} command link"
capture sm_fcount l11.smcl "{browse"
local br = r(n)
capture sm_fcount l11.smcl "file://"
sm_assert `=(`br' == 0 & r(n) == 0)' "no {browse} directive and no file:// URL in the draw output"
* name() names the map in the page title
capture noisily surveymap draw j11.tsv, export(html) saving(m11n.html) name(polmap) replace noopen
sm_assert `=(_rc == 0)' "draw accepts name()"
capture sm_flinehas m11n.html "<title>" "polmap"
sm_assert `=(r(hit) == 1)' "name() shows in the page <title>"    // * INTEGRATION: verify
* _sm_open refuses a missing file rather than doing anything drastic
capture noisily _sm_open "no_such_file_here.html"
sm_assert `=(_rc == 601)' "_sm_open refuses a file that is not there"

* ============================================================================
sm_block 12 "draw mermaid"
* ============================================================================
capture noisily surveymap draw j11.tsv, export(mermaid) saving(m12) replace
sm_assert `=(_rc == 0)' "draw writes mermaid"
capture confirm file m12.md
sm_assert `=(_rc == 0)' "the .md file exists"    // * INTEGRATION: verify saving() naming
capture sm_fencen m12.md
sm_assert `=(r(n) >= 1)' "the .md carries a mermaid fence"

* ============================================================================
sm_block 13 "export: xlsx tracker sheets, dta, csv"
* ============================================================================
capture sm_jcount j11.tsv item
local nitem = r(n)
capture sm_jcount j11.tsv cat
local ncat = r(n)
capture sm_jcount j11.tsv cell
local ncell = r(n)
capture sm_jrows j11.tsv
local nall = r(rows)
capture noisily surveymap export j11.tsv, saving(t13.xlsx) replace
sm_assert `=(_rc == 0)' "export writes an xlsx"
capture frame drop _t13
frame create _t13
local rc1 = .
local rc2 = .
local rc3 = .
local rc4 = .
local ni = .
local nb = .
local nf = .
local first ""
local xn13 = .
frame _t13 {
    capture import excel using t13.xlsx, sheet("sm_items") firstrow clear
    local rc1 = _rc
    if !_rc {
        local ni = _N
        quietly ds
        local first : word 1 of `r(varlist)'
        capture confirm numeric variable n_asked
        local rc2 = _rc
        capture {
            tempvar pick
            quietly gen `pick' = variable == "q3_party"
            quietly summarize n_asked if `pick', meanonly
            local xn13 = r(max)
        }
    }
    capture import excel using t13.xlsx, sheet("sm_branches") firstrow clear
    local rc3 = _rc
    if !_rc local nb = _N
    capture import excel using t13.xlsx, sheet("sm_flow") firstrow clear
    local rc4 = _rc
    if !_rc local nf = _N
}
frame drop _t13
sm_assert `=(`rc1' == 0 & `rc3' == 0 & `rc4' == 0)' "the three sm_ sheets are present"
sm_assert `=(`ni' == `nitem')' "sm_items: one row per item"
sm_assert `=(`nb' == `ncat')' "sm_branches: one row per journaled category"    // * INTEGRATION: verify
sm_assert `=(`nf' == `ncell')' "sm_flow: one row per lane cell"    // * INTEGRATION: verify
sm_assert `=("`first'" == "variable")' "sm_items leads with the datadictionary join key: variable"
capture sm_jval j11.tsv n_asked item q3_party
sm_assert `=(`rc2' == 0 & `xn13' == real("`r(val)'"))' "counts round-trip as numbers, equal to the journal"
* dta and csv
capture noisily surveymap export j11.tsv, saving(t13.dta) replace
sm_assert `=(_rc == 0)' "export writes a dta"
local dn = .
local dnum = 0
capture {
    preserve
    quietly use t13.dta, clear
    local dn = _N
    local dnum = (substr("`:type n_asked'", 1, 3) != "str")
    restore
}
sm_assert `=(`dn' == `nall' & `dnum')' "the dta holds every journal row with numeric counts"    // * INTEGRATION: verify row scope
capture noisily surveymap export j11.tsv, saving(t13.csv) replace
sm_assert `=(_rc == 0)' "export writes a csv"
capture confirm file t13.csv
sm_assert `=(_rc == 0)' "the csv exists"

* ============================================================================
sm_block 14 "dictionary(): the tracker rides inside a datadictionary workbook"
* ============================================================================
capture which datadictionary
if _rc {
    sm_openx "datadictionary is installed (skipping the workbook round-trip)"
}
else {
    sysuse auto, clear
    capture noisily datadictionary, excel(dd14.xlsx) replace
    sm_assert `=(_rc == 0)' "datadictionary writes its own workbook"
    capture use fake_a.dta, clear
    capture noisily surveymap, out(j14.tsv) noreceipt replace
    capture noisily surveymap export j14.tsv, dictionary(dd14.xlsx)
    sm_assert `=(_rc == 0)' "export dictionary() adds the sm_ sheets"
    capture frame drop _t14
    frame create _t14
    local rc1 = .
    local rc2 = .
    frame _t14 {
        capture import excel using dd14.xlsx, sheet("Variables") firstrow clear
        local rc1 = _rc
        capture import excel using dd14.xlsx, sheet("sm_items") firstrow clear
        local rc2 = _rc
    }
    frame drop _t14
    sm_assert `=(`rc1' == 0)' "the datadictionary Variables sheet survives sheetreplace"
    sm_assert `=(`rc2' == 0)' "the sm_items sheet sits in the same workbook"
    * a dictionary() target that does not exist is a clear file-not-found
    capture noisily surveymap export j14.tsv, dictionary(no_such_workbook.xlsx)
    sm_assert `=(_rc == 601)' "a missing dictionary() workbook is refused with r(601)"
    * dictionary() and saving() are alternatives, not companions
    capture noisily surveymap export j14.tsv, saving(t14.xlsx) dictionary(dd14.xlsx) replace
    sm_assert `=(_rc == 198)' "saving() with dictionary() is refused with r(198)"
}

* ============================================================================
sm_block 15 "error paths speak clearly"
* ============================================================================
clear
capture noisily surveymap, out(j15.tsv) noreceipt replace
sm_assert `=(_rc != 0)' "a scan with no data in memory does not silently succeed"
capture noisily surveymap draw no_such_journal.tsv, noopen
sm_assert `=(_rc == 601)' "draw on a missing journal is refused with r(601)"
capture noisily surveymap export no_such_journal.tsv, saving(t15.xlsx) replace
sm_assert `=(_rc == 601)' "export on a missing journal is refused with r(601)"
* a file that is not a surveymap journal is a clear r(459), not a crash
tempname nj
file open `nj' using notajournal.tsv, write text replace
file write `nj' "alpha" _tab "beta" _n
file write `nj' "1" _tab "2" _n
file close `nj'
capture noisily _sm_jprune using notajournal.tsv
sm_assert `=(_rc == 459)' "_sm_jprune refuses a non-journal file with r(459)"

* ============================================================================
sm_block 17 "working on a real survey file: exclude, nostrings, weights, verify"
* ============================================================================
* Everything in this block came from running surveymap against a real poll:
* a survey file carries record ids, a sample frame and verbatim text that are
* not questions, its estimates are weighted, and the project keeps its own
* table of the skip logic that the map can be checked against.
capture use fake_a.dta, clear

* ---- exclude() drops columns that are not questions ----
capture noisily surveymap, out(j17a.tsv) noreceipt replace
local kall = r(K_items)
capture noisily surveymap, exclude(resp_id st) out(j17b.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "exclude() is accepted"
sm_assert `=(r(K_items) == `kall' - 2)' "exclude() drops exactly the named columns"
capture sm_jval j17b.tsv var item resp_id
sm_assert `=("`r(val)'" == "")' "an excluded column has no item row"

* ---- nostrings drops the verbatim columns ----
capture noisily surveymap, nostrings out(j17c.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "nostrings is accepted"
capture sm_jval j17c.tsv var item q14_zip
sm_assert `=("`r(val)'" == "")' "nostrings leaves the string item out"
capture sm_jval j17c.tsv var item q3_party
sm_assert `=("`r(val)'" == "q3_party")' "nostrings keeps the numeric items"

* ---- a weight adds the three weighted columns and changes nothing else ----
capture use fake_a.dta, clear
quietly gen double wt = cond(q3_party == 1, 1.4, 0.8)
quietly replace wt = 0 if q1_consent == 0
capture noisily surveymap q1_consent q3_party q5_voted q6_whovote [pweight=wt], ///
    out(j17w.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "a pweight is accepted"
capture sm_jval j17w.tsv w_asked item q3_party
local wa = real("`r(val)'")
capture sm_jval j17w.tsv n_asked item q3_party
local na = real("`r(val)'")
sm_assert `=(`wa' > 0 & `wa' < .)' "w_asked is populated when a weight is given"
sm_assert `=(abs(`wa' - `na') > 0.5)' "the weighted scope differs from the unweighted one"
capture sm_jval j17w.tsv pct_answered_w item q6_whovote
sm_assert `=(real("`r(val)'") > 0 & real("`r(val)'") < 100)' "pct_answered_w is a percentage"
* zero-weight respondents leave the scope, which is what a weighted estimate does
capture sm_jval j17w.tsv n_asked survey "*"
local nw = real("`r(val)'")
capture use fake_a.dta, clear
quietly count if q1_consent == 1
sm_assert `=(`nw' == r(N))' "a zero weight takes a respondent out of scope"

* ---- with no weight, the three columns are all "." ----
capture sm_jval j17c.tsv w_asked item q3_party
sm_assert `=("`r(val)'" == ".")' "without a weight the weighted columns stay missing"

* ---- verify() against a declared skip-logic table ----
capture use fake_a.dta, clear
capture erase decl17.csv
file open fh using decl17.csv, write text replace
file write fh "study,varname,gate_expr,expected_n,note" _n
* the true counts, taken from the scan itself
capture noisily surveymap, out(j17v.tsv) noreceipt replace
capture sm_jval j17v.tsv n_answered item q6_whovote
local n6 = "`r(val)'"
capture sm_jval j17v.tsv n_answered item q7_whynot
local n7 = "`r(val)'"
file write fh "1,q6_whovote,q5_voted==1,`n6'," _n
file write fh "1,q7_whynot,q5_voted==0,`n7'," _n
file write fh "1,q10_dem_prim,inlist(q3_party 1 3),999," _n
file write fh "1,nosuchitem,x==1,50," _n
file close fh
capture noisily surveymap, out(j17v2.tsv) noreceipt replace verify(decl17.csv)
sm_assert `=(_rc == 0)' "verify() runs"
sm_assert `=(r(N_mismatch) == 1)' "verify() finds the one declared count that disagrees"
* a file without the required columns is refused, not crashed
capture erase bad17.csv
file open fh using bad17.csv, write text replace
file write fh "a,b" _n
file write fh "1,2" _n
file close fh
capture noisily surveymap, out(j17v3.tsv) noreceipt replace verify(bad17.csv)
sm_assert `=(_rc == 459)' "a file that is not a skip-logic table gives r(459)"
capture noisily surveymap, out(j17v4.tsv) noreceipt replace verify(nosuch17.csv)
sm_assert `=(_rc == 601)' "a missing verify() file gives r(601)"

* ---- the weighted journal still draws and exports ----
capture noisily surveymap draw j17w.tsv, export(html) saving(m17.html) replace noopen
sm_assert `=(_rc == 0)' "a weighted journal still draws"
capture noisily surveymap export j17w.tsv, saving(t17.xlsx) replace
sm_assert `=(_rc == 0)' "a weighted journal still exports"

* ============================================================================
sm_block 16 "clear forgets the remembered journal"
* ============================================================================
capture use fake_a.dta, clear
capture noisily surveymap, out(j16.tsv) noreceipt replace
capture noisily surveymap clear
sm_assert `=(_rc == 0)' "surveymap clear runs"
sm_assert `=("$SM_LASTJ" == "")' "clear forgets SM_LASTJ"
capture confirm file j16.tsv
sm_assert `=(_rc == 0)' "clear leaves the journal FILE untouched"

* ---------------------------------------------------------------- summary ----
display as text _n "{hline 78}"
display as text "surveymap battery: " as result "$SM_PASS passed" as text ", " ///
    as result "$SM_FAIL failed" as text ", " as result "$SM_OPEN open"
display as text "{hline 78}"
if $SM_FAIL == 0 {
    display as result "ALL IMPLEMENTED CHECKS PASSED"
}
else {
    display as error "SOME CHECKS FAILED"
}
cd ..
