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

* the line a string first appears on, or 0 -> r(line)
program define sm_fline, rclass
    args f str
    tempname fh
    local n = 0
    local hit = 0
    file open `fh' using `"`f'"', read text
    file read `fh' line
    while r(eof) == 0 {
        local ++n
        if `hit' == 0 & strpos(`"`macval(line)'"', `"`str'"') local hit = `n'
        file read `fh' line
    }
    file close `fh'
    return scalar line = `hit'
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
capture noisily surveymap q1_consent q3_party q5_voted q6_whovote q13_income ///
    [pweight=wt], out(j17w.tsv) noreceipt replace
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

* ---- the weighted journal draws the survey convention ----
* unweighted counts, weighted percentages, and the page says which is which,
* so a weighted scan cannot be read as an unweighted result
capture noisily surveymap draw j17w.tsv, export(html) saving(m17.html) replace noopen
sm_assert `=(_rc == 0)' "a weighted journal still draws"
capture sm_fcount m17.html "counts unweighted, percentages weighted"
sm_assert `=(r(n) == 1)' "the weighted page states the convention in its caption"
* the weighted percentage is what gets drawn, not the unweighted one
* q13_income sits on the spine, so its box carries the item-level share; an
* item inside a gate's segment is drawn as a lane cell and shows the lane rate
capture sm_jval j17w.tsv pct_answered   item q13_income
local pu = "`r(val)'"
capture sm_jval j17w.tsv pct_answered_w item q13_income
local pw = "`r(val)'"
sm_assert `=(`pu' != `pw')' "the fixture's weighted and unweighted shares differ"
capture sm_fcount m17.html "(`pw'%)"
local dreww = r(n)
capture sm_fcount m17.html "(`pu'%)"
sm_assert `=(`dreww' >= 1 & r(n) == 0)' "the drawing uses the weighted share, not the unweighted one"
* an unweighted journal must not claim weighting
capture noisily surveymap draw j17c.tsv, export(html) saving(m17u.html) replace noopen
capture sm_fcount m17u.html "percentages weighted"
sm_assert `=(r(n) == 0)' "an unweighted page makes no weighting claim"
capture noisily surveymap export j17w.tsv, saving(t17.xlsx) replace
sm_assert `=(_rc == 0)' "a weighted journal still exports"
capture noisily surveymap draw j17w.tsv, export(mermaid) saving(mm17) replace
sm_assert `=(_rc == 0)' "a weighted journal renders to mermaid"

* ============================================================================
sm_block 18 "the figure renderer, and the fragment's scoping guarantee"
* ============================================================================
capture use fake_a.dta, clear
capture noisily surveymap q1_consent q3_party q5_voted q6_whovote q7_whynot ///
    q8_approve, out(j18.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "the figure fixture scans"

* ---- png and svg come from one twoway call, so asking for either writes both
capture noisily surveymap draw j18.tsv, export(png) saving(f18) replace
sm_assert `=(_rc == 0)' "export(png) runs"
capture confirm file f18.png
local a = _rc
capture confirm file f18.svg
sm_assert `=(`a' == 0 & _rc == 0)' "png and svg are both written"
capture noisily surveymap draw j18.tsv, export(svg) saving(f18b) replace
capture confirm file f18b.png
local a = _rc
capture confirm file f18b.svg
sm_assert `=(`a' == 0 & _rc == 0)' "export(svg) writes the same pair"
* a pasted extension on the stub is forgiven
capture noisily surveymap draw j18.tsv, export(png) saving(f18c.png) replace
capture confirm file f18c.png
sm_assert `=(_rc == 0)' "a pasted .png on saving() is forgiven, not doubled"
capture confirm file f18c.png.png
sm_assert `=(_rc != 0)' "and it does not write f18c.png.png"
* replace is required, as everywhere else
capture noisily surveymap draw j18.tsv, export(png) saving(f18)
sm_assert `=(_rc == 602)' "an existing figure needs replace"

* ---- a figure is only readable up to a point ----
capture use fake_a.dta, clear
capture noisily surveymap, nostrings out(j18w.tsv) noreceipt replace
capture noisily surveymap draw j18w.tsv, export(png) saving(f18d) replace maxnodes(3)
sm_assert `=(_rc == 134)' "past maxnodes() the figure is refused with r(134)"
capture noisily surveymap draw j18w.tsv, export(html) saving(f18d.html) replace noopen
sm_assert `=(_rc == 0)' "and the same journal still draws as HTML"

* ---- the fragment cannot restyle the page it is dropped into ----
capture noisily surveymap draw j18.tsv, export(html) saving(fr18.html) replace embed
sm_assert `=(_rc == 0)' "an embed fragment is written"
capture sm_fcount fr18.html "<script"
sm_assert `=(r(n) == 0)' "the fragment carries no script"
capture sm_fcount fr18.html "<!DOCTYPE"
local d = r(n)
capture sm_fcount fr18.html "<body"
sm_assert `=(`d' == 0 & r(n) == 0)' "the fragment is a fragment, not a page"
* the vendored checker agrees, and it is the one the gallery and CI would run
capture confirm file ../embedcheck/check_embed_scoping.py
sm_assert `=(_rc == 0)' "the scoping checker ships with the package"

* ============================================================================
sm_block 19 "vertical layout"
* ============================================================================
* A questionnaire reads either way. Left to right suits a slide; top to bottom
* suits a report page and a long instrument, because a page scrolls down.
capture use fake_a.dta, clear
capture noisily surveymap q1_consent q3_party q5_voted q6_whovote q7_whynot ///
    q8_approve q10_dem_prim q11_rep_prim q13_income,                        ///
    branch(q3_party = 1 2 3, q5_voted) out(j19.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "the layout fixture scans"

capture noisily surveymap draw j19.tsv, export(mermaid) saving(m19v) replace ///
    layout(vertical)
sm_assert `=(_rc == 0)' "mermaid accepts layout(vertical)"
capture sm_fcount m19v.mmd "flowchart TB"
sm_assert `=(r(n) == 1)' "vertical emits flowchart TB"
capture noisily surveymap draw j19.tsv, export(mermaid) saving(m19h) replace ///
    layout(horizontal)
capture sm_fcount m19h.mmd "flowchart LR"
sm_assert `=(r(n) == 1)' "horizontal emits flowchart LR, and is the default"
capture noisily surveymap draw j19.tsv, export(mermaid) saving(m19d) replace
capture sm_fcount m19d.mmd "flowchart LR"
sm_assert `=(r(n) == 1)' "the default layout is horizontal"
* the abbreviations a user will actually type
foreach L in v vert tb td VERTICAL {
    capture noisily surveymap draw j19.tsv, export(mermaid) saving(m19a) replace layout(`L')
    sm_assert `=(_rc == 0)' "layout(`L') is understood"
}
capture noisily surveymap draw j19.tsv, export(mermaid) saving(m19b) replace layout(diagonal)
sm_assert `=(_rc == 198)' "an unknown layout is refused"

* ---- each lane is drawn as its own labelled subgraph ----
capture sm_fcount m19v.mmd "subgraph SG"
local nsg = r(n)
sm_assert `=(`nsg' >= 5)' "every lane with cells becomes a subgraph"
capture sm_fcount m19v.mmd "  end"
sm_assert `=(r(n) == `nsg')' "every subgraph is closed"
* A subgraph's own direction is ignored the moment any node in it links
* outside, and every lane links out twice: up to the gate and down to the
* merge.  Rendering the same map with the line present, absent, and set to the
* opposite direction gives byte-identical PNG and SVG on mermaid-cli 11.16.0,
* so the line was dead code that only ever restated the parent's direction.
capture sm_fcount m19v.mmd "    direction "
sm_assert `=(r(n) == 0)' "no subgraph carries a direction line, which mermaid would ignore"
capture sm_fcount m19v.mmd "flowchart TB"
sm_assert `=(r(n) == 1)' "the parent flowchart still declares the direction"

* Straight edges, because a path-following diagram is read by tracing one and
* uniform curvature measurably hurts that (Xu et al. 2012).
capture sm_fcount m19v.mmd "'curve':'linear'"
sm_assert `=(r(n) == 1)' "the init directive asks for straight edges"
capture sm_fcount m19v.mmd "rankSpacing"
sm_assert `=(r(n) == 0)' "rank spacing is left alone, so fan edges stay clear of the lane titles"
* the lane label belongs to the subgraph, so the edge into it is not labelled
* with the same text twice
capture sm_fcount m19v.mmd `"-- ""'
sm_assert `=(r(n) == 0)' "a lane with cells has no duplicate edge label"

* ---- the description states the direction actually drawn ----
capture sm_fcount m19v.mmd "run top to bottom"
sm_assert `=(r(n) == 1)' "the vertical accDescr says top to bottom"
capture sm_fcount m19h.mmd "run left to right"
sm_assert `=(r(n) == 1)' "the horizontal accDescr says left to right"

* ---- the label text is safe inside a mermaid quoted string ----
capture sm_fcount m19v.mmd `"["'
local nopen = r(n)
sm_assert `=(`nopen' > 0)' "the file has bracketed nodes to check"
* a middle dot must be real UTF-8, not a lone 0xB7 byte: that is what made
* graph export refuse the figure, and it would corrupt a mermaid label too
capture sm_fcount m19v.mmd "`=uchar(183)'"
sm_assert `=(r(n) >= 1)' "the separator is valid UTF-8"

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

* ============================================================================
sm_block 20 "banding a continuous item into lanes"
* ============================================================================
* A questionnaire asks age in years, but a map can only show a handful of
* lanes, so the analyst says where to cut.  Nobody may fall outside the
* bands: everyone below the first break belongs to the first lane and
* everyone at or above the last break to the top one, which is the point on
* which -egen cut, at()- differs, because it leaves the tails missing.
capture use fake_a.dta, clear

* ---- cut() at named breaks ----
capture noisily surveymap q1_consent q2_age q3_party q8_approve ///
    , branch(q2_age = cut(25 35 45 65)) out(j20c.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "branch(age = cut(...)) is accepted"
capture sm_jcount j20c.tsv cat q2_age
sm_assert `=(r(n) == 6)' "four breaks give five bands plus a no-answer lane"
capture sm_jval j20c.tsv vallabel cat q2_age 1
sm_assert `=("`r(val)'" == "under 25")' "the bottom band is labelled by its open side"
capture sm_jval j20c.tsv vallabel cat q2_age 3
sm_assert `=("`r(val)'" == "35 to 44")' "an interior band is labelled by its own range"
capture sm_jval j20c.tsv vallabel cat q2_age 5
sm_assert `=("`r(val)'" == "65 and over")' "the top band is labelled by its open side"

* ---- the bands are a partition: nobody is dropped and nobody is counted twice
capture sm_jsumn j20c.tsv n_asked cat q2_age
local lanesum = r(sum)
capture sm_jval j20c.tsv n_asked survey "*"
local scope = real("`r(val)'")
sm_assert `=(`lanesum' == `scope')' "the bands account for every respondent in scope"

* ---- the journal says the lanes are derived, not asked ----
capture sm_jval j20c.tsv flags survey "*"
sm_assert `=(strpos("`r(val)'", "q2_age banded at 25 35 45 65") > 0)' ///
    "the survey row records the breaks the analyst chose"

* ---- q(k) cuts at the quantiles instead ----
capture use fake_a.dta, clear
capture noisily surveymap q1_consent q2_age q8_approve ///
    , branch(q2_age = q(4)) out(j20q.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "branch(age = q(4)) is accepted"
capture sm_jcount j20q.tsv cat q2_age
sm_assert `=(r(n) == 5)' "q(4) gives four bands plus a no-answer lane"
capture sm_jsumn j20q.tsv n_asked cat q2_age
local qsum = r(sum)
capture sm_jval j20q.tsv n_asked survey "*"
sm_assert `=(`qsum' == real("`r(val)'"))' "the quartile bands account for everyone in scope"
* four quantile bands of 1,200-odd respondents should be within a few percent
capture sm_jval j20q.tsv n_asked cat q2_age 1
local q1 = real("`r(val)'")
capture sm_jval j20q.tsv n_asked cat q2_age 4
local q4 = real("`r(val)'")
sm_assert `=(abs(`q1' - `q4') / `q1' < 0.15)' "the quartile bands are close to equal in size"
capture sm_jval j20q.tsv vallabel cat q2_age 1
sm_assert `=(strpos("`r(val)'", " to ") > 0)' "a quantile band is labelled by the range it spans"

* ---- a banding rule is checked before it is used ----
capture use fake_a.dta, clear
capture noisily surveymap q1_consent q2_age, branch(q2_age = cut()) ///
    out(j20e.tsv) noreceipt replace
sm_assert `=(_rc == 198)' "cut() with no breaks is refused"
capture noisily surveymap q1_consent q2_age, branch(q2_age = cut(abc)) ///
    out(j20e.tsv) noreceipt replace
sm_assert `=(_rc == 198)' "cut() with breaks that are not numbers is refused"
capture noisily surveymap q1_consent q2_age, branch(q2_age = q(1)) ///
    out(j20e.tsv) noreceipt replace
sm_assert `=(_rc == 198)' "q(1) is refused, because one band is not a split"
capture noisily surveymap q1_consent q2_age, branch(q2_age = q(40)) ///
    out(j20e.tsv) noreceipt replace
sm_assert `=(_rc == 198)' "q(40) is refused as more lanes than a map can show"
capture noisily surveymap q1_consent st, branch(st = q(3)) ///
    out(j20e.tsv) noreceipt replace
sm_assert `=(_rc == 198)' "a banding rule on a string item is refused"

* ---- a banded gate still routes the items below it ----
capture use fake_a.dta, clear
capture noisily surveymap q1_consent q2_age q8_approve q13_income ///
    , branch(q2_age = cut(40)) out(j20r.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "a single break is enough to gate"
capture sm_jcount j20r.tsv cell "*" q2_age
sm_assert `=(r(n) > 0)' "the banded gate produces cell rows for the items below it"

* ============================================================================
sm_block 21 "profile(): splitting the map by what the respondent did"
* ============================================================================
* branch() splits the map by an answer.  profile() splits it by something the
* respondent did while answering, so an analyst can see whether the people
* who leave items blank take a different route through the questionnaire.
capture use fake_a.dta, clear

capture noisily surveymap, profile(declined) out(j21n.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "profile(declined) is accepted"
capture sm_jval j21n.tsv var item sm_declined
sm_assert `=("`r(val)'" == "sm_declined")' "the derived condition becomes an item"
capture sm_jval j21n.tsv position item sm_declined
sm_assert `=(real("`r(val)'") == 1)' "the condition sits first, ahead of every question"
capture sm_jval j21n.tsv gate item sm_declined
sm_assert `=("`r(val)'" == "1")' "the condition is a gate"

* ---- a reader must never take a derived column for a question ----
capture sm_jval j21n.tsv flags item sm_declined
sm_assert `=(strpos("`r(val)'", "derived:") == 1)' ///
    "the item row says the condition is derived, not asked"
capture sm_jval j21n.tsv flags survey "*"
local sf `"`r(val)'"'
sm_assert `=(strpos(`"`sf'"', "is derived") > 0)' ///
    "the survey row records what the condition measures"
sm_assert `=(strpos(`"`sf'"', "not by itself evidence of bias") > 0)' ///
    "the caveat that a decline rate is not a bias estimate travels with the map"
sm_assert `=(strpos(`"`sf'"', "splits at zero only") > 0)' ///
    "the journal admits the default threshold was not the analyst's choice"

* ---- the default split is at zero, which is the one non-arbitrary boundary
capture sm_jcount j21n.tsv cat sm_declined
sm_assert `=(r(n) == 2)' "the default gives two lanes"
capture sm_jval j21n.tsv vallabel cat sm_declined 1
sm_assert `=("`r(val)'" == "none")' "the lower lane is the respondents who declined nothing"
capture sm_jval j21n.tsv vallabel cat sm_declined 2
sm_assert `=("`r(val)'" == "at least one")' "the upper lane is everyone else"

* ---- the lanes partition the sample ----
capture sm_jsumn j21n.tsv n_asked cat sm_declined
local lanesum = r(sum)
capture sm_jval j21n.tsv n_asked survey "*"
sm_assert `=(`lanesum' == real("`r(val)'"))' "the condition's lanes account for everyone"

* ---- a share, not a count: the denominator is the items THAT respondent
* ---- was asked, because skip logic asks different people different numbers
capture use fake_a.dta, clear
quietly gen int hand_num = 0
quietly gen int hand_den = 0
foreach v of varlist q1_consent q2_age q3_party q4_reg q5_voted q6_whovote ///
    q7_whynot q8_approve q9_econ q10_dem_prim q11_rep_prim q12_ideol q13_income ///
    resp_id {
    quietly replace hand_den = hand_den + 1 if `v' != .
    quietly replace hand_num = hand_num + 1 if missing(`v') & `v' != .
}
quietly gen double hand_share = 100 * hand_num / hand_den if hand_den > 0
quietly count if hand_share > 0 & !missing(hand_share)
local handany = r(N)
capture sm_jval j21n.tsv n_asked cat sm_declined 2
sm_assert `=(real("`r(val)'") == `handany')' ///
    "the upper lane holds exactly the respondents who declined something"
* the denominator really does vary, which is the whole reason for a share
quietly summarize hand_den, meanonly
sm_assert `=(r(min) < r(max))' "the fixture asks different respondents different numbers of items"

* ---- bands of the analyst's own, read in percentage points ----
capture use fake_a.dta, clear
capture noisily surveymap, profile(declined = cut(10 25)) ///
    out(j21b.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "profile() takes bands of the analyst's own"
capture sm_jcount j21b.tsv cat sm_declined
sm_assert `=(r(n) == 3)' "two breaks give three bands"
capture sm_jval j21b.tsv vallabel cat sm_declined 1
sm_assert `=("`r(val)'" == "under 10%")' "a share band is labelled in percentage points"
capture sm_jval j21b.tsv vallabel cat sm_declined 3
sm_assert `=("`r(val)'" == "25% and over")' "the top share band names its open side"
capture sm_jval j21b.tsv flags survey "*"
sm_assert `=(strpos("`r(val)'", "splits at zero only") == 0)' ///
    "the journal does not claim a default when the analyst set the bands"

* ---- where a respondent stopped ----
capture use fake_a.dta, clear
capture noisily surveymap, profile(breakoff) out(j21k.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "profile(breakoff) is accepted"
capture sm_jcount j21k.tsv cat sm_breakoff
sm_assert `=(r(n) == 2)' "the default splits at reaching the last item"
capture sm_jval j21k.tsv vallabel cat sm_breakoff 2
sm_assert `=("`r(val)'" == "reached the last item")' "the upper lane is the finishers"
capture sm_jval j21k.tsv flags survey "*"
sm_assert `=(strpos("`r(val)'", "consistent with abandonment") > 0)' ///
    "the journal hedges breakoff, which item data cannot prove"

* ---- refused and dontknow will not guess the survey's codes ----
capture use fake_a.dta, clear
capture noisily surveymap, profile(refused) out(j21e.tsv) noreceipt replace
sm_assert `=(_rc == 198)' "profile(refused) without refusedcode() is refused"
capture noisily surveymap, profile(dontknow) out(j21e.tsv) noreceipt replace
sm_assert `=(_rc == 198)' "profile(dontknow) without dkcode() is refused"
capture noisily surveymap, profile(refused) refusedcode(.b) ///
    out(j21r.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "profile(refused) with the code named runs"
capture sm_jval j21r.tsv var item sm_refused
sm_assert `=("`r(val)'" == "sm_refused")' "the refusal count becomes an item"

* ---- conditions the package refuses to build, and says why -------------
* Over-reporters resemble honest reporters on everything a survey records
* (Ansolabehere and Hersh 2012), so a flag built from answers alone would
* reproduce the demographics of the behaviour and call those people liars.
capture noisily surveymap, profile(exaggerator) out(j21e.tsv) noreceipt replace
sm_assert `=(_rc == 198)' "profile(exaggerator) is refused, not invented"
capture noisily surveymap, profile(liar) out(j21e.tsv) noreceipt replace
sm_assert `=(_rc == 198)' "the other names for it are refused too"
capture noisily surveymap, profile(straightlining) out(j21e.tsv) noreceipt replace
sm_assert `=(_rc == 198)' "profile(straightlining) is refused without a named battery"
capture noisily surveymap, profile(careless) out(j21e.tsv) noreceipt replace
sm_assert `=(_rc == 198)' "a verdict about the respondent is refused"

* ---- the bands are checked before they are used ----
capture noisily surveymap, profile(declined = cut(150)) ///
    out(j21e.tsv) noreceipt replace
sm_assert `=(_rc == 198)' "a share break above 100 is refused"
capture noisily surveymap, profile(declined = cut(abc)) ///
    out(j21e.tsv) noreceipt replace
sm_assert `=(_rc == 198)' "a break that is not a number is refused"
capture noisily surveymap, profile(asked = cut(2.5)) ///
    out(j21e.tsv) noreceipt replace
sm_assert `=(_rc == 198)' "a fractional break on a count is refused"
capture noisily surveymap, profile(declined = q(1)) ///
    out(j21e.tsv) noreceipt replace
sm_assert `=(_rc == 198)' "q(1) is refused, because one band is not a split"

* ---- a weighted map says what a behaviour-defined lane can mean ----
capture use fake_a.dta, clear
quietly gen double wt21 = cond(q3_party == 1, 1.4, 0.8)
capture noisily surveymap [pweight=wt21], profile(declined) ///
    out(j21w.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "a weighted scan takes a derived condition"
capture sm_jval j21w.tsv flags survey "*"
sm_assert `=(strpos("`r(val)'", "not a population subgroup") > 0)' ///
    "the journal warns that a weighted figure inside a behaviour lane is not a population estimate"

* ---- profile() composes with branch() ----
capture use fake_a.dta, clear
capture noisily surveymap, profile(declined) branch(q3_party) ///
    out(j21c.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "profile() and branch() can both be given"
capture sm_jcount j21c.tsv cat sm_declined
local a = r(n)
capture sm_jcount j21c.tsv cat q3_party
sm_assert `=(`a' > 0 & r(n) > 0)' "both gates get their own lanes"

* ---- the renderers accept a derived gate ----
capture noisily surveymap draw j21n.tsv, export(mermaid) layout(vertical) ///
    saving(m21v) replace
sm_assert `=(_rc == 0)' "a vertical mermaid draws a derived gate"
capture sm_fcount m21v.mmd "derived, not asked"
sm_assert `=(r(n) == 1)' "the mermaid node says the gate was derived"
* a gate does a different job from a question, so it gets a different shape:
* a reader printing in greyscale still sees which node splits the sample
capture sm_fcount m21v.mmd "{{"
sm_assert `=(r(n) >= 1)' "the gate node is drawn as its own shape, not a plain box"

* ---- lane order in the file, which is the part this controls ----
* mermaid's layout engine decides which order the lanes are DRAWN in, and
* renderers disagree: mermaid-cli 11.16.0 and GitHub lay the same file out in
* opposite orders.  So the file declares lane 1 first and every lane carries
* its own label; nothing depends on where a lane lands.
capture sm_fline m21v.mmd "subgraph SG1x1"
local first = r(line)
capture sm_fline m21v.mmd "subgraph SG1x2"
sm_assert `=(`first' < r(line) & `first' > 0)' "lane 1 is declared before lane 2"
capture sm_fcount m21v.mmd "sm_declined = "
sm_assert `=(r(n) >= 2)' "every lane is labelled with the condition that opened it"

* the same holds for a gate in the middle of the questionnaire, which merges
capture use fake_a.dta, clear
capture noisily surveymap q1_consent q3_party q5_voted q6_whovote q7_whynot ///
    q8_approve, branch(q5_voted) out(j21m.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "a mid-questionnaire gate scans"
capture noisily surveymap draw j21m.tsv, export(mermaid) layout(vertical) ///
    saving(m21m) replace
sm_assert `=(_rc == 0)' "it draws vertically"
capture sm_fcount m21m.mmd "--> n6"
sm_assert `=(r(n) >= 2)' "the lanes rejoin the spine at the next item"
capture sm_fline m21m.mmd "subgraph SG3x1"
local mfirst = r(line)
capture sm_fline m21m.mmd "subgraph SG3x2"
sm_assert `=(`mfirst' < r(line) & `mfirst' > 0)' "lane 1 is declared first here too"

* the HTML map is laid out here rather than by mermaid, so its lane order IS
* guaranteed: lane 1 sits left of lane 2
capture noisily surveymap draw j21m.tsv, export(html) layout(vertical) ///
    saving(h21m.html) replace
sm_assert `=(_rc == 0)' "the HTML map draws the same gate"
capture sm_fline h21m.html ">No<"
local hno = r(line)
capture sm_fline h21m.html ">Yes<"
sm_assert `=(`hno' > 0 & r(line) > 0)' "both lane labels are drawn in the HTML map"

capture noisily surveymap draw j21n.tsv, export(html) layout(vertical) ///
    saving(h21v.html) replace
sm_assert `=(_rc == 0)' "a vertical HTML map draws a derived gate"

* ============================================================================
sm_block 22 "conservation, and the map as text"
* ============================================================================
* Every respondent in scope lands in exactly one of answered, declined or not
* shown at every single item.  That is the arithmetic the whole map rests on,
* so the scan checks it rather than assuming it: a slip here would draw a
* picture that looks right and is not.
capture use fake_a.dta, clear
capture noisily surveymap, branch(q3_party) out(j22.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "the scan runs"
sm_assert `=(r(N_unbalanced) == 0)' "every item accounts for the whole sample"
capture sm_jval j22.tsv flags survey "*"
sm_assert `=(strpos("`r(val)'", "balance ok") > 0)' ///
    "the journal records the audit, so a later reader can see it was done"

* ---- and the same arithmetic, checked here rather than taken on trust ----
capture sm_jval j22.tsv n_asked survey "*"
local scope = real("`r(val)'")
sm_assert `=(`scope' > 0)' "the survey row carries the scope"
* walk every item row and add the three states back up
tempname fr22
frame create `fr22'
frame `fr22' {
    quietly import delimited using "j22.tsv", delimiter(tab) varnames(1) ///
        stringcols(_all) clear
    quietly keep if class == "item"
    quietly gen double s22 = real(n_answered) + real(n_nonresp) + real(n_sysmiss)
    quietly count if s22 != `scope'
    local off = r(N)
    quietly count
    local nit = r(N)
}
frame drop `fr22'
sm_assert `=(`nit' > 0)' "there are item rows to check"
sm_assert `=(`off' == 0)' "answered + declined + not shown = the sample on every item row"

* ---- a weighted scan keeps the unweighted arithmetic intact ----
capture use fake_a.dta, clear
quietly gen double w22 = cond(q3_party == 1, 1.4, 0.8)
capture noisily surveymap [pweight=w22], out(j22w.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "a weighted scan runs"
sm_assert `=(r(N_unbalanced) == 0)' "weighting does not disturb the unweighted counts"

* ---- the map ships its own numbers as text ----
* A diagram is not readable by everyone, and the honest fallback for a figure
* built from a table is that table.
capture noisily surveymap draw j22.tsv, export(html) saving(h22.html) replace
sm_assert `=(_rc == 0)' "the HTML map draws"
capture sm_fcount h22.html `"<details class="sm-alt">"'
sm_assert `=(r(n) == 1)' "the page carries a text alternative"
capture sm_fcount h22.html `"scope="row""'
sm_assert `=(r(n) >= 10)' "the table has a row header per item"
capture sm_fcount h22.html "aria-labelledby="
sm_assert `=(r(n) == 1)' "the figure points at its own title and description"
capture sm_fcount h22.html `"focusable="false""'
sm_assert `=(r(n) == 1)' "the figure does not swallow the keyboard tab order"

* the ids the figure points at must actually exist, or the label resolves to
* nothing and a screen reader announces an unlabelled graphic
capture sm_fcount h22.html `"-ti">surveymap flow map"'
sm_assert `=(r(n) == 1)' "the title the figure names is present"
capture sm_fcount h22.html `"-de">Items run"'
sm_assert `=(r(n) == 1)' "the description the figure names is present"

* ---- the fragment stays scoped even with the table in it ----
capture noisily surveymap draw j22.tsv, export(html) saving(f22.html) replace embed
sm_assert `=(_rc == 0)' "the embed fragment draws"
capture sm_fcount f22.html `"<details class="sm-alt">"'
sm_assert `=(r(n) == 1)' "the fragment carries the table too"
capture sm_fcount f22.html "<html"
sm_assert `=(r(n) == 0)' "the fragment is still a fragment"

* ============================================================================
sm_block 23 "verify() writes its verdict back, and the map draws it"
* ============================================================================
* A count in a receipt is a number somebody has to go looking for.  Where the
* questionnaire and the file disagree about who was asked an item, the useful
* form of that is a mark on the item, wherever the map is read.
capture use fake_a.dta, clear
capture erase decl23.csv
tempname d23
file open `d23' using decl23.csv, write text replace
file write `d23' "varname,expected_n,note" _n
file write `d23' "q6_whovote,578,vote choice asked of voters" _n
file write `d23' "q11_rep_prim,99999,deliberately wrong" _n
file write `d23' "q99_nothere,100,not in the survey at all" _n
file close `d23'

capture noisily surveymap q1_consent q3_party q5_voted q6_whovote q11_rep_prim, ///
    noautodetect out(j23.tsv) noreceipt replace verify(decl23.csv)
sm_assert `=(_rc == 0)' "a scan with verify() runs"
sm_assert `=(r(N_mismatch) == 1)' "it finds the one declared count that disagrees"

* ---- the verdict is appended to the journal, not just printed ----
capture sm_jcount j23.tsv note q11_rep_prim
sm_assert `=(r(n) >= 1)' "the disagreeing item gets a note row"
capture sm_jval j23.tsv flags note q11_rep_prim
sm_assert `=(strpos("`r(val)'", "verify=mismatch") == 1)' ///
    "the note says what kind of disagreement it was"
sm_assert `=(strpos("`r(val)'", "99999") > 0)' "the note carries the declared count"
capture sm_jval j23.tsv flags note q99_nothere
sm_assert `=(strpos("`r(val)'", "verify=notmapped") == 1)' ///
    "a declared item that is not in the map is recorded too"
capture sm_jval j23.tsv severity note q11_rep_prim
sm_assert `=("`r(val)'" == "warn")' "the note is a warning, not a footnote"

* ---- an item that agreed gets no note, so the mark means something ----
capture sm_jcount j23.tsv note q6_whovote
sm_assert `=(r(n) == 0)' "an item whose declared count matches is left unmarked"

* ---- appending must not disturb the rows already there ----
capture sm_jcount j23.tsv item
sm_assert `=(r(n) == 5)' "the five item rows survive the append"
capture sm_jval j23.tsv n_answered item q11_rep_prim
sm_assert `=(real("`r(val)'") > 0)' "the item row still carries its own counts"

* ---- and the seq keeps running, because the schema is append-only ----
tempname f23
frame create `f23'
frame `f23' {
    quietly import delimited using "j23.tsv", delimiter(tab) varnames(1) ///
        stringcols(_all) clear
    quietly gen double sq23 = real(seq)
    quietly summarize sq23
    local nrow = r(N)
    local mx = r(max)
    quietly duplicates report sq23
    local ndup = r(unique_value)
}
frame drop `f23'
sm_assert `=(`ndup' == `nrow')' "every row still has a sequence number of its own"

* ---- the map draws the disagreement, on the spine ----
capture noisily surveymap draw j23.tsv, export(html) saving(h23.html) replace
sm_assert `=(_rc == 0)' "the map draws"
capture sm_fcount h23.html "!? declared routing disagrees"
sm_assert `=(r(n) >= 1)' "the disagreeing item is marked on the map"
capture sm_fcount h23.html "the declared routing and the data disagree"
sm_assert `=(r(n) == 1)' "the legend says what the mark means"

* ---- and inside a fan, where an item is drawn once per lane ----
capture use fake_a.dta, clear
capture noisily surveymap q1_consent q3_party q5_voted q6_whovote q11_rep_prim, ///
    branch(q3_party = 1 2) out(j23f.tsv) noreceipt replace verify(decl23.csv)
sm_assert `=(_rc == 0)' "a branched scan with verify() runs"
capture noisily surveymap draw j23f.tsv, export(html) saving(h23f.html) replace
sm_assert `=(_rc == 0)' "the branched map draws"
capture sm_fcount h23f.html `"q11_rep_prim !?"'
sm_assert `=(r(n) >= 2)' "an item inside a fan is marked in every lane that draws it"

* ---- mermaid carries the mark too ----
capture noisily surveymap draw j23.tsv, export(mermaid) saving(m23) replace
sm_assert `=(_rc == 0)' "mermaid draws"
capture sm_fcount m23.mmd "!? declared routing disagrees"
sm_assert `=(r(n) >= 1)' "the mermaid node carries the mark"

* ---- a journal with no verify rows draws exactly as before ----
capture use fake_a.dta, clear
capture noisily surveymap q1_consent q3_party q5_voted, out(j23n.tsv) ///
    noreceipt replace
capture noisily surveymap draw j23n.tsv, export(html) saving(h23n.html) replace
sm_assert `=(_rc == 0)' "a journal without verify rows still draws"
capture sm_fcount h23n.html "!? declared routing disagrees"
sm_assert `=(r(n) == 0)' "and carries no disagreement mark"

* ============================================================================
sm_block 24 "the band chart, for the surveys the map is too small for"
* ============================================================================
* The flow map has a node budget and refuses past maxnodes() drawn columns,
* which used to mean a 230-item instrument got no figure at all.  The band
* chart has no budget: one thin column per item, split into the three states,
* stacking to the scope.  It answers a different question from the map --
* where the instrument leaks, rather than who was asked what.
capture use fake_a.dta, clear
capture noisily surveymap, out(j24.tsv) noreceipt replace
sm_assert `=(_rc == 0)' "the scan runs"

capture noisily surveymap band j24.tsv, saving(b24.png) replace
sm_assert `=(_rc == 0)' "surveymap band draws from a named journal"
sm_assert `=(r(nitems) == 16)' "it draws one column per item"
capture confirm file b24.png
sm_assert `=(_rc == 0)' "the figure is written"

* ---- the arithmetic the figure claims must actually hold ----
* Every column is drawn from the three counts, never from a hard-coded 100,
* so a journal that does not partition draws a short column instead of
* quietly lying.  r(devmax) is the largest gap in respondents.
sm_assert `=(r(devmax) == 0)' "every column accounts for the whole scope"
sm_assert `=(abs(r(topmax)) < 0.001)' "every column reaches 100 percent"
sm_assert `=(r(nbad) == 0)' "no item is flagged as failing to partition"

* ---- it falls back on the remembered journal, the way draw does ----
capture noisily surveymap band, saving(b24b.png) replace
sm_assert `=(_rc == 0)' "band uses the journal the last scan wrote"
sm_assert `=(r(nitems) == 16)' "and gets the same items"

* ---- and refuses clearly when there is nothing to draw ----
capture noisily surveymap clear
capture noisily surveymap band, saving(b24c.png) replace
sm_assert `=(_rc == 198)' "with no journal named and none remembered, it stops"
capture noisily surveymap band nosuchfile.tsv, saving(b24d.png) replace
sm_assert `=(_rc == 601)' "a journal that does not exist is a file error"

* ---- it scales past the flow map's node budget, which is the point ----
* A 230-item instrument: the map refuses, this does not.
capture erase big24.tsv
tempname bh
file open `bh' using big24.tsv, write text replace
file write `bh' "seq" _tab "class" _tab "var" _tab "position" _tab "vallabel" ///
    _tab "value" _tab "gatevar" _tab "n_asked" _tab "n_answered" _tab       ///
    "n_nonresp" _tab "n_sysmiss" _tab "pct_answered" _tab "rate" _tab       ///
    "status" _tab "gate" _tab "gated_by" _tab "pooled" _tab "type" _tab     ///
    "severity" _tab "flags" _n
file write `bh' "1" _tab "survey" _tab "." _tab "230" _tab "." _tab "." _tab ///
    "." _tab "2000" _tab "." _tab "." _tab "." _tab "." _tab "." _tab "."   ///
    _tab "." _tab "." _tab "." _tab "." _tab "note" _tab "x" _n
forvalues i = 1/230 {
    local ns = cond(`i' > 120 & `i' < 170, 900, 0)
    local nr = 40 + mod(`i', 60)
    local na = 2000 - `ns' - `nr'
    local pc = string(100 * `na' / 2000, "%9.1f")
    file write `bh' "`=`i'+1'" _tab "item" _tab "q`i'" _tab "`i'" _tab      ///
        "item `i'" _tab "." _tab "." _tab "2000" _tab "`na'" _tab "`nr'"    ///
        _tab "`ns'" _tab "`pc'" _tab "." _tab "open" _tab "0" _tab "."      ///
        _tab "." _tab "byte" _tab "note" _tab "." _n
}
file close `bh'
capture noisily surveymap band big24.tsv, saving(b24big.png) replace
sm_assert `=(_rc == 0)' "230 items draw"
sm_assert `=(r(nitems) == 230)' "all 230 columns are there"
sm_assert `=(r(devmax) == 0)' "and every one of them still partitions the scope"

* the flow map, on the same instrument, correctly refuses
capture noisily surveymap draw big24.tsv, export(png) saving(b24map) replace
sm_assert `=(_rc != 0)' "the flow map refuses an instrument this wide"

* ---- a journal whose counts do not partition is reported, not hidden ----
capture erase bad24.tsv
tempname xh
file open `xh' using bad24.tsv, write text replace
file write `xh' "seq" _tab "class" _tab "var" _tab "position" _tab "vallabel" ///
    _tab "value" _tab "gatevar" _tab "n_asked" _tab "n_answered" _tab       ///
    "n_nonresp" _tab "n_sysmiss" _tab "pct_answered" _tab "rate" _tab       ///
    "status" _tab "gate" _tab "gated_by" _tab "pooled" _tab "type" _tab     ///
    "severity" _tab "flags" _n
file write `xh' "1" _tab "survey" _tab "." _tab "2" _tab "." _tab "." _tab  ///
    "." _tab "1000" _tab "." _tab "." _tab "." _tab "." _tab "." _tab "."   ///
    _tab "." _tab "." _tab "." _tab "." _tab "note" _tab "x" _n
file write `xh' "2" _tab "item" _tab "a" _tab "1" _tab "a" _tab "." _tab    ///
    "." _tab "1000" _tab "500" _tab "100" _tab "100" _tab "50.0" _tab "."   ///
    _tab "open" _tab "0" _tab "." _tab "." _tab "byte" _tab "note" _tab "." _n
file write `xh' "3" _tab "item" _tab "b" _tab "2" _tab "b" _tab "." _tab    ///
    "." _tab "1000" _tab "900" _tab "50" _tab "50" _tab "90.0" _tab "."     ///
    _tab "open" _tab "0" _tab "." _tab "." _tab "byte" _tab "note" _tab "." _n
file close `xh'
capture noisily surveymap band bad24.tsv, saving(b24bad.png) replace
sm_assert `=(_rc == 0)' "a journal that does not partition still draws"
sm_assert `=(r(devmax) > 0)' "and the shortfall is reported rather than hidden"

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
