*! version 0.6.0  27aug2026  Eric Booth
*! _sm_paths -- the response-flow view behind -surveymap paths-.
*!
*! The flow map (surveymap scan + draw) follows the ROUTING: who was shown
*! what.  On an instrument with little skip logic that map is a straight
*! line, because the routing IS a straight line.  This view follows the
*! ANSWERS instead: every item in the list becomes a column, each of its
*! most common answers a block, and a ribbon between two blocks counts the
*! people who gave both answers on consecutive items.  The survey reads
*! left to right as a braid of paths, splitting and merging at every item.
*!
*!     surveymap paths d3a q1 q2 q3, top(3) out(flows.tsv) saving(flows.html)
*!
*! States per item: the top(k) answers by count, then -other answers-
*! pooling the rest, then -no answer- for anyone with nothing recorded
*! (declined, never shown, or lost; item data cannot tell these apart, and
*! the page says so).  Every respondent in scope lands in exactly one block
*! of every column, so each column adds back to the scope count.  That
*! invariant is asserted here, not assumed.
*!
*! The journal gains three classes (JOURNAL_SCHEMA.md):
*!     pnode  one block: var, position, value (or ~o / ~m), vallabel,
*!            gate = slot 1..k+2, n_asked = n, pct_answered = share of scope
*!     pflow  one ribbon: var/value/vallabel = from, gatevar/gated_by = to,
*!            gate = from slot, rate = to slot, n_asked = n
*!     ppath  one full sequence: value = slot codes "2>1>4", gate = rank,
*!            n_asked = n; the ten most common full paths, for the table
*!
*! Weighted runs journal weighted counts alongside (w_asked); the drawing
*! reports unweighted counts, because a route through a questionnaire is a
*! property of the fieldwork rather than of the population.

program define _sm_paths, rclass
    version 16

    syntax varlist(min=1) [if] [in] [pweight] [,   ///
        TOP(integer 3) OUT(string) SAVing(string)  ///
        TITLe(string) NOOPen NODRaw replace]

    * ---- the list must be short enough to read ---------------------------
    local K : word count `varlist'
    if `K' < 2 {
        di as err "surveymap paths: needs at least two items"
        di as err "    a path runs between items; one column has nothing to flow to"
        exit 198
    }
    if `K' > 12 {
        di as err "surveymap paths: `K' items is more than a reader can follow"
        di as err "    give at most 12; map the rest in a second call, or use"
        di as err "    surveymap band for the whole-instrument view"
        exit 198
    }
    foreach v of local varlist {
        capture confirm numeric variable `v'
        if _rc {
            di as err "surveymap paths: `v' is a string variable"
            di as err "    encode it first, so its answers have counts and labels"
            exit 198
        }
        * this program generates _smS1.. and _smf in its frame copy; a
        * mapped variable under one of those names would collide there
        if ustrregexm("`v'", "^_smS[0-9]+$") | "`v'" == "_smf" {
            di as err "surveymap paths: `v' collides with an internal name"
            di as err "    rename it (clonevar) and map the copy"
            exit 198
        }
    }
    if `top' < 1 | `top' > 6 {
        di as err "top(): give a whole number from 1 to 6"
        di as err "    top(3) keeps each item like this: three named answers,"
        di as err "    other answers, no answer"
        exit 198
    }

    * ---- scope -----------------------------------------------------------
    marksample touse, novarlist
    local scopetxt = strtrim(`"`if' `in'"')
    if substr(`"`scopetxt'"', 1, 3) == "if " {
        local scopetxt = strtrim(substr(`"`scopetxt'"', 4, .))
    }

    local wvar ""
    if `"`weight'"' != "" {
        local wvar = strtrim(subinstr(`"`exp'"', "=", "", .))
        capture confirm numeric variable `wvar'
        if _rc {
            di as err "surveymap paths: the weight must be one numeric variable"
            exit 198
        }
        if ustrregexm("`wvar'", "^_smS[0-9]+$") | "`wvar'" == "_smf" {
            di as err "surveymap paths: `wvar' collides with an internal name"
            di as err "    rename it (clonevar) and weight by the copy"
            exit 198
        }
    }

    * ---- work in a frame copy: the data in memory are never touched ------
    tempvar tflag
    quietly gen byte `tflag' = `touse'
    capture frame drop _smpwork
    frame put `varlist' `tflag' `wvar', into(_smpwork)
    frame _smpwork {
        quietly keep if `tflag'
        quietly drop `tflag'
    }
    frame _smpwork: local N = _N
    if `N' == 0 {
        frame drop _smpwork
        di as err "surveymap paths: no respondents in scope"
        exit 2000
    }
    local WTOT "."
    if "`wvar'" != "" {
        frame _smpwork {
            _smp_wsum "`wvar'" "1"
            local WTOT "`s(o)'"
        }
    }
    local KO = `top' + 1
    local KM = `top' + 2

    * ---- states, item by item --------------------------------------------
    * Slot 1..top are the item's most common answers in rank order, slot
    * top+1 pools the remaining answers, slot top+2 is no answer.  The slot
    * variables drive both the counts and the sequence table, so every
    * number on the page comes from one assignment.
    local t = 0
    foreach v of local varlist {
        local ++t
        local wording : variable label `v'
        if `"`wording'"' == "" local wording "`v'"
        local lab_`t' `"`wording'"'
        local v_`t' "`v'"

        tempname RF RR
        capture frame _smpwork: tab `v' if !missing(`v'), matcell(`RF') matrow(`RR')
        if _rc {
            frame drop _smpwork
            di as err "surveymap paths: could not tabulate `v'"
            exit _rc
        }
        local nr = r(r)
        if `nr' > 30 {
            frame drop _smpwork
            di as err "surveymap paths: `v' has `nr' distinct answers"
            di as err "    a flow map needs a handful per item.  Band it first,"
            di as err "    for example  egen `v'_b = cut(`v'), at(...)  and map"
            di as err "    the banded variable, or drop `v' from the list"
            exit 198
        }
        if `nr' == 0 {
            frame drop _smpwork
            di as err "surveymap paths: nobody in scope answered `v'"
            di as err "    a column with one all-grey block says nothing; drop it"
            exit 2000
        }
        forvalues i = 1/`nr' {
            local rn`i' = `RF'[`i', 1]
        }
        * rank by count, ties broken by value order, same rule as responses()
        forvalues i = 1/`nr' {
            local rk`i' = 1
            forvalues j = 1/`nr' {
                if `rn`j'' > `rn`i'' | (`rn`j'' == `rn`i'' & `j' < `i') {
                    local rk`i' = `rk`i'' + 1
                }
            }
        }
        frame _smpwork {
            quietly gen byte _smS`t' = `KO' if !missing(`v')
            quietly replace  _smS`t' = `KM' if missing(`v')
        }
        local rvl ""
        frame _smpwork: local rvl : value label `v'
        forvalues s = 1/`top' {
            local key_`t'_`s' ""
            local dec_`t'_`s' ""
        }
        forvalues i = 1/`nr' {
            if `rk`i'' > `top' continue
            * compare against the matrix element, never a macro copy of it:
            * a macro keeps 16 digits and a float code like .1 needs 17 to
            * round-trip, so the macro copy matches nobody (TRAPS 34)
            frame _smpwork: quietly replace _smS`t' = `rk`i'' if `v' == `RR'[`i', 1]
            local vtxt = strofreal(`RR'[`i', 1], "%12.0g")
            local key_`t'_`rk`i'' "`vtxt'"
            local dec ""
            if `"`rvl'"' != "" & `RR'[`i', 1] == int(`RR'[`i', 1]) ///
                & abs(`RR'[`i', 1]) < 2147483620 {
                local iv = int(`RR'[`i', 1])
                frame _smpwork: capture local dec : label `rvl' `iv', strict
            }
            if `"`dec'"' == "" local dec "`vtxt'"
            local dec_`t'_`rk`i'' `"`dec'"'
        }
        local key_`t'_`KO' "~o"
        local dec_`t'_`KO' "other answers"
        local key_`t'_`KM' "~m"
        * not plain "no answer": for an item the routing skipped, most of
        * this block was never asked, and the label must not claim otherwise
        local dec_`t'_`KM' "no answer recorded"

        * node counts, and the invariant: the slots partition the scope
        local tot = 0
        forvalues s = 1/`KM' {
            frame _smpwork: quietly count if _smS`t' == `s'
            local n_`t'_`s' = r(N)
            local tot = `tot' + r(N)
            local wn_`t'_`s' "."
            if "`wvar'" != "" {
                frame _smpwork {
                    _smp_wsum "`wvar'" "_smS`t' == `s'"
                    local wn_`t'_`s' "`s(o)'"
                }
            }
        }
        if `tot' != `N' {
            frame drop _smpwork
            di as err "surveymap paths: internal error at `v': states hold `tot' of `N'"
            di as err "    this is a bug in surveymap; please report it"
            exit 459
        }
    }

    * ---- flows between consecutive items ---------------------------------
    forvalues t = 1/`=`K'-1' {
        local u = `t' + 1
        forvalues a = 1/`KM' {
            forvalues b = 1/`KM' {
                frame _smpwork: quietly count if _smS`t' == `a' & _smS`u' == `b'
                local f_`t'_`a'_`b' = r(N)
                local wf_`t'_`a'_`b' "."
                if "`wvar'" != "" & r(N) > 0 {
                    frame _smpwork {
                        _smp_wsum "`wvar'" "_smS`t' == `a' & _smS`u' == `b'"
                        local wf_`t'_`a'_`b' "`s(o)'"
                    }
                }
            }
        }
    }

    * ---- the most common full sequences ----------------------------------
    * The ribbons count adjacent pairs; this counts whole rows, so the table
    * under the figure can name the paths people actually took end to end.
    local slist ""
    forvalues t = 1/`K' {
        local slist "`slist' _smS`t'"
    }
    frame _smpwork {
        tempvar seqs
        quietly gen str1 `seqs' = ""
        forvalues t = 1/`K' {
            if `t' == 1 quietly replace `seqs' = string(_smS`t')
            else        quietly replace `seqs' = `seqs' + ">" + string(_smS`t')
        }
        quietly contract `seqs', freq(_smf)
        quietly gsort -_smf `seqs'
        local npaths = min(_N, 10)
        forvalues i = 1/`npaths' {
            local path`i' = `seqs'[`i']
            local pn`i'   = _smf[`i']
        }
        quietly count
        local ndistinct = r(N)
    }
    frame drop _smpwork

    * ---- journal ---------------------------------------------------------
    if `"`out'"' == "" local out "surveymap_paths.tsv"
    capture confirm file `"`out'"'
    if !_rc & "`replace'" == "" {
        di as err `"surveymap paths: `out' exists; add replace to overwrite"'
        exit 602
    }
    tempname JH
    quietly file open `JH' using `"`out'"', write text replace
    file write `JH' "seq" _tab "class" _tab "var" _tab "position" _tab      ///
        "vallabel" _tab "value" _tab "gatevar" _tab "n_asked" _tab          ///
        "n_answered" _tab "n_nonresp" _tab "n_sysmiss" _tab                 ///
        "pct_answered" _tab "rate" _tab "status" _tab "gate" _tab           ///
        "gated_by" _tab "pooled" _tab "type" _tab "severity" _tab "flags"   ///
        _tab "w_asked" _tab "w_answered" _tab "pct_answered_w" _n

    local seq = 1
    * no apostrophe in a flags string: the journal text passes through
    * macro quoting in every reader, and a lone quote breaks it there
    local sflags "paths: top=`top'; each column partitions the scope into named answers, other answers, no answer; denominator = respondents in scope; `ndistinct' distinct full sequences"
    if `"`scopetxt'"' != "" local sflags `"`sflags'; scope: `scopetxt'"'
    _smp_wrow `JH' `seq' survey "." `K' "." "." "." `N' "." "." "." "." "." ///
        "." "." "." "." "." note `"`sflags'"' `"`WTOT'"' "." "."

    forvalues t = 1/`K' {
        local ++seq
        local answered = `N' - `n_`t'_`KM''
        local pct = string(100 * `answered' / `N', "%9.1f")
        _smp_wrow `JH' `seq' item `"`v_`t''"' `t' `"`lab_`t''"' "." "."      ///
            `N' `answered' `n_`t'_`KM'' 0 `"`pct'"' "." open 0 "." "."      ///
            "." note "." `"`WTOT'"' "." "."
    }
    forvalues t = 1/`K' {
        forvalues s = 1/`KM' {
            if `s' <= `top' & `"`key_`t'_`s''"' == "" continue
            if `n_`t'_`s'' == 0 & `s' > `top' continue
            local ++seq
            local pct = string(100 * `n_`t'_`s'' / `N', "%9.1f")
            local pooled = cond(`s' == `KO', "1", ".")
            _smp_wrow `JH' `seq' pnode `"`v_`t''"' `t' `"`dec_`t'_`s''"'     ///
                `"`key_`t'_`s''"' `"`v_`t''"' `n_`t'_`s'' "." "." "."       ///
                `"`pct'"' "." "." `s' "." `"`pooled'"' "." note "."          ///
                `"`wn_`t'_`s''"' "." "."
        }
    }
    forvalues t = 1/`=`K'-1' {
        local u = `t' + 1
        forvalues a = 1/`KM' {
            forvalues b = 1/`KM' {
                if `f_`t'_`a'_`b'' == 0 continue
                local ++seq
                local pct = string(100 * `f_`t'_`a'_`b'' / `N', "%9.1f")
                _smp_wrow `JH' `seq' pflow `"`v_`t''"' `t'                   ///
                    `"`dec_`t'_`a''"' `"`key_`t'_`a''"' `"`v_`u''"'          ///
                    `f_`t'_`a'_`b'' "." "." "." `"`pct'"' `b' "." `a'        ///
                    `"`dec_`u'_`b''"' "." "." note "."                       ///
                    `"`wf_`t'_`a'_`b''"' "." "."
            }
        }
    }
    forvalues i = 1/`npaths' {
        local ++seq
        local pct = string(100 * `pn`i'' / `N', "%9.1f")
        _smp_wrow `JH' `seq' ppath "." "." "." `"`path`i''"' "." `pn`i''      ///
            "." "." "." `"`pct'"' "." "." `i' "." "." "." note "." "." "." "."
    }
    file close `JH'
    global SM_LASTJ `"`out'"'

    return scalar N = `N'
    return scalar K_items = `K'
    return scalar n_sequences = `ndistinct'
    return local journal `"`out'"'

    di as txt "surveymap paths: " as res `K' as txt " items, "              ///
        as res `N' as txt " respondents in scope, "                          ///
        as res `ndistinct' as txt " distinct full sequences"
    di as txt "    journal: " as res `"`out'"'

    * ---- draw ------------------------------------------------------------
    if "`nodraw'" != "" exit
    local hf `"`saving'"'
    if `"`hf'"' == "" local hf "surveymap_paths.html"
    _sm_renderflow using `"`out'"', saving(`"`hf'"') title(`"`title'"') `replace'
    return local output `"`s(out)'"'
    local abs `"`s(out)'"'
    _sm_isabs `"`abs'"'
    if !r(abs) local abs `"`c(pwd)'/`s(out)'"'
    global SM_LASTOUT `"`abs'"'
    di as txt `"    {stata _sm_open:Open the map in your browser}"'
    di as txt `"    `abs'"'
    if "`noopen'" == "" & "`c(mode)'" != "batch" & "`c(console)'" == "" {
        capture _sm_open
    }
end

* ---- helpers: own copies of the scan's journal writers -------------------
* (subprograms of surveymap.ado are not callable from another ado file)

program define _smp_wsum, sclass
    args wvar cond
    sreturn clear
    sreturn local o "."
    if `"`wvar'"' == "" exit
    quietly summarize `wvar' if `cond', meanonly
    if r(N) == 0 {
        sreturn local o "0"
        exit
    }
    sreturn local o = string(r(sum), "%20.4f")
end

* Writes one journal line.  Every field is sanitized: a tab or a newline
* inside a variable label would otherwise split the row and every reader
* would see a different number of columns.
program define _smp_wrow
    args JH seq class var position vallabel value gatevar n_asked         ///
        n_answered n_nonresp n_sysmiss pct_answered rate status gate      ///
        gated_by pooled type severity flags w_asked w_answered pct_answered_w
    foreach f in class var vallabel value gatevar status gated_by pooled  ///
        type severity flags {
        local `f' = subinstr(`"``f''"', char(9), " ", .)
        local `f' = subinstr(`"``f''"', char(10), " ", .)
        local `f' = subinstr(`"``f''"', char(13), " ", .)
        local `f' = strtrim(`"``f''"')
        if `"``f''"' == "" local `f' "."
    }
    foreach f in seq position n_asked n_answered n_nonresp n_sysmiss      ///
        pct_answered rate gate w_asked w_answered pct_answered_w {
        local `f' = strtrim(`"``f''"')
        if `"``f''"' == "" local `f' "."
    }
    file write `JH' `"`seq'"' _tab `"`class'"' _tab `"`var'"' _tab        ///
        `"`position'"' _tab `"`vallabel'"' _tab `"`value'"' _tab           ///
        `"`gatevar'"' _tab `"`n_asked'"' _tab `"`n_answered'"' _tab        ///
        `"`n_nonresp'"' _tab `"`n_sysmiss'"' _tab `"`pct_answered'"' _tab  ///
        `"`rate'"' _tab `"`status'"' _tab `"`gate'"' _tab `"`gated_by'"'   ///
        _tab `"`pooled'"' _tab `"`type'"' _tab `"`severity'"' _tab         ///
        `"`flags'"' _tab `"`w_asked'"' _tab `"`w_answered'"' _tab           ///
        `"`pct_answered_w'"' _n
end
