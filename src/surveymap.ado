*! version 0.1.0  23aug2026  Eric Booth
*! surveymap: map how respondents moved through a survey
*!
*! The data in memory are a survey: one row per respondent, one column per
*! item, columns in questionnaire order.  surveymap reads them (it never
*! changes them), works out who was asked each item, who answered, who was
*! routed around it by skip logic, and who declined, and writes a journal.
*! Everything else -- the receipt, the HTML map, the mermaid text, the Excel
*! tracker -- is built from that journal.
*!
*! Routing is read from the responses, not from a questionnaire spec: a
*! category whose respondents almost all have a system missing on a later
*! item, while the other categories answered it, was routed around that item.
*! The receipt says so once, because an item that a category happened not to
*! answer looks the same in the data.
*!
*! Subcommands: (bare) = scan, draw, export, receipt, demo, clear.
*! See proto/JOURNAL_SCHEMA.md for the 20-column journal contract.

program define surveymap, rclass
    version 16

    * ---- which subcommand ------------------------------------------------
    gettoken sub rest : 0, parse(" ,")
    local sub = strtrim(`"`sub'"')
    if `"`sub'"' == "scan" local 0 `"`rest'"'
    else if inlist(`"`sub'"', "draw", "export", "receipt", "demo", "clear") {
        * pass the rest of the line through untouched: never rebuild an
        * option list with a leading comma and then append it after another
        if `"`sub'"' == "draw" {
            capture which _sm_draw
            if _rc {
                di as err "surveymap draw needs _sm_draw.ado, which is not installed."
                di as err "    Reinstall the package to get the drawings."
                exit 601
            }
            _sm_draw `rest'
            return add
            exit
        }
        if `"`sub'"' == "export" {
            capture which _sm_export
            if _rc {
                di as err "surveymap export needs _sm_export.ado, which is not installed."
                di as err "    Reinstall the package to get the tracker."
                exit 601
            }
            _sm_export `rest'
            return add
            exit
        }
        if `"`sub'"' == "receipt" {
            local 0 `"`rest'"'
            syntax anything(name=jfile id="journal file")
            gettoken jfile : jfile
            confirm file `"`jfile'"'
            _sm_receipt using `"`jfile'"'
            global SM_LASTJ `"`jfile'"'
            return local journal `"`jfile'"'
            exit
        }
        if `"`sub'"' == "demo" {
            _sm_demo `rest'
            if `"`demojournal'"' != "" {
                return local journal `"`demojournal'"'
            }
            exit
        }
        * clear
        global SM_LASTJ ""
        global SM_LASTOUT ""
        di as txt "surveymap: the remembered journal is forgotten; no file was touched"
        exit
    }

    * ---- scan (the default) ----------------------------------------------
    syntax [varlist(default=none)] [if] [in] [,                            ///
        BRanch(string asis) out(string) NONresponse(string)                ///
        PRUNE(real 5) MINN(integer 30) MAXCats(integer 6)                  ///
        DETect(numlist min=2 max=2) NOAUTOdetect NORECeipt NOPRUNE replace]

    if _N == 0 {
        di as err "surveymap: no data in memory"
        di as err "    load a survey (one row per respondent) and try again,"
        di as err "    or run {stata surveymap demo} to see it work"
        exit 2000
    }
    if `prune' < 0 | `prune' > 100 {
        di as err "prune() is a percentage between 0 and 100"
        exit 198
    }
    if `minn' < 0 {
        di as err "minn() must be 0 or more"
        exit 198
    }
    if `maxcats' < 1 {
        di as err "maxcats() must be 1 or more"
        exit 198
    }
    local dlow  = 2
    local dhigh = 50
    if `"`detect'"' != "" {
        local dlow  : word 1 of `detect'
        local dhigh : word 2 of `detect'
        if `dlow' < 0 | `dlow' > 100 | `dhigh' < 0 | `dhigh' > 100 {
            di as err "detect() takes two percentages between 0 and 100"
            exit 198
        }
        if `dlow' >= `dhigh' {
            di as err "detect(): the first threshold must be below the second"
            di as err "    detect(2 50) reads: routed when a lane answers at most 2%"
            di as err "    while the other lanes answer at least 50%"
            exit 198
        }
    }
    if "`noprune'" != "" {
        * recorded as the default a later draw or export inherits; the
        * journal always holds every category either way
        local prune = 0
        local minn = 0
        local maxcats = 9999
    }
    if `"`out'"' == "" local out "survey_journal.tsv"
    if strlower(substr(`"`out'"', -4, .)) != ".tsv" local out `"`out'.tsv"'
    capture confirm file `"`out'"'
    if !_rc & "`replace'" == "" {
        di as err `"file `out' already exists; specify replace"'
        exit 602
    }

    * ---- the items, in dataset column order ------------------------------
    * a varlist selects WHICH items to map, not what order the questionnaire
    * ran in: the model is that columns run left to right
    if `"`varlist'"' == "" unab vlist : _all
    else {
        unab allv : _all
        local vlist ""
        foreach v of local allv {
            local hit : list v in varlist
            if `hit' local vlist `"`vlist' `v'"'
        }
        local vlist = strtrim(`"`vlist'"')
    }
    local K : word count `vlist'
    if `K' == 0 {
        di as err "surveymap: no items to map"
        exit 198
    }

    marksample touse, novarlist
    quietly count if `touse'
    local N = r(N)
    if `N' == 0 {
        di as err "surveymap: no observations in scope"
        exit 2000
    }

    * ---- nonresponse codes -----------------------------------------------
    * extended missings (.a to .z) always count as nonresponse; nonresponse()
    * adds coded values a survey writes in the answer itself, like 98 and 99
    local nrcodes ""
    if `"`nonresponse'"' != "" {
        capture numlist `"`nonresponse'"'
        if _rc {
            di as err `"nonresponse(): could not read "`nonresponse'""'
            di as err "    give the coded values, for example nonresponse(98 99)"
            exit 198
        }
        local nrcodes `"`r(numlist)'"'
    }

    * ---- gates -----------------------------------------------------------
    local ngdecl = 0
    local declared ""
    local skipgates ""
    if `"`branch'"' != "" {
        * plain quotes, not compound: a compound-quoted value inside an
        * -asis- option nests and dies "too few quotes" r(132).  A branch
        * spec never contains a quote character, and _sm_branch strips the
        * pair it receives.
        _sm_branch , spec("`branch'")
        local ngdecl = `s(n)'
        local declared `"`s(gates)'"'
        local skipgates `"`s(skipped)'"'
        forvalues i = 1/`ngdecl' {
            local gv`i' `"`s(gate`i')'"'
            local gk`i' `"`s(vals`i')'"'
        }
        * a declared gate that is not among the mapped items cannot be drawn
        forvalues i = 1/`ngdecl' {
            local hit : list gv`i' in vlist
            if !`hit' {
                di as err "branch(`gv`i''): that variable is not among the items being mapped"
                di as err "    add it to the varlist, or drop it from branch()"
                exit 198
            }
        }
    }

    * ---- work in a frame copy: the user's data are never touched ---------
    tempvar tflag
    quietly gen byte `tflag' = `touse'
    capture frame drop _smwork
    frame put `vlist' `tflag', into(_smwork)
    frame _smwork {
        quietly keep if `tflag'
        quietly drop `tflag'
    }

    * ---- per item: answered / nonresponse / system missing ---------------
    local pos = 0
    foreach v of local vlist {
        local ++pos
        local p_`v' = `pos'
        local item`pos' `"`v'"'
        frame _smwork {
            local isstr = 0
            capture confirm numeric variable `v'
            if _rc local isstr = 1
            local ty : type `v'
            if `isstr' {
                * a blank string cannot say whether it was never shown or was
                * left empty; it is counted as not shown, and the help says so
                quietly count if trim(`v') != ""
                local ans = r(N)
                local nr  = 0
                local sys = `N' - `ans'
            }
            else {
                local nrexp "0"
                foreach c of local nrcodes {
                    local nrexp `"`nrexp' | `v' == `c'"'
                }
                quietly count if !missing(`v') & !(`nrexp')
                local ans = r(N)
                quietly count if (missing(`v') & `v' != .) | (!missing(`v') & (`nrexp'))
                local nr = r(N)
                quietly count if `v' == .
                local sys = r(N)
            }
        }
        local a_`v' = `ans'
        local r_`v' = `nr'
        local s_`v' = `sys'
        local t_`v' `"`ty'"'
        local str_`v' = `isstr'
        local lab_`v' : variable label `v'
        if `"`lab_`v''"' == "" local lab_`v' `"`v'"'
    }

    * ---- gate candidates for detection ------------------------------------
    * numeric, more than one and not too many distinct answers, and a
    * position before the item it might route around
    local cands ""
    if "`noautodetect'" == "" {
        local cap3 = `maxcats' * 3
        foreach v of local vlist {
            if `str_`v'' continue
            frame _smwork {
                quietly levelsof `v' if !missing(`v'), local(lv)
            }
            local nlv : word count `lv'
            if `nlv' >= 2 & `nlv' <= `cap3' local cands `"`cands' `v'"'
        }
        local cands = strtrim(`"`cands'"')
    }
    * declared gates are always candidates for the gated_by column, so the
    * receipt can say who was routed around an item even when the gate was
    * named rather than found
    foreach g of local declared {
        local hit : list g in cands
        if !`hit' & !`str_`g'' local cands `"`cands' `g'"'
    }
    local cands = strtrim(`"`cands'"')

    * ---- detect routing ---------------------------------------------------
    * category v of gate g routes around item i when the lane answers at most
    * dlow% while the rest of g's answered categories answer at least dhigh%
    foreach v of local vlist {
        local gb_`v' ""
        local reach_`v' ""
    }
    foreach g of local cands {
        local routed_`g' = 0
        frame _smwork {
            quietly levelsof `g' if !missing(`g'), local(gvals_`g')
        }
        foreach v of local vlist {
            if `p_`v'' <= `p_`g'' continue
            if "`v'" == "`g'" continue
            local hits ""
            foreach c of local gvals_`g' {
                frame _smwork {
                    quietly count if `g' == `c'
                    local nlane = r(N)
                    if `nlane' == 0 continue
                    if `str_`v'' quietly count if `g' == `c' & trim(`v') != ""
                    else quietly count if `g' == `c' & !missing(`v')
                    local ain = r(N)
                    quietly count if `g' != `c' & !missing(`g')
                    local nout = r(N)
                    if `str_`v'' quietly count if `g' != `c' & !missing(`g') & trim(`v') != ""
                    else quietly count if `g' != `c' & !missing(`g') & !missing(`v')
                    local aout = r(N)
                }
                if `nlane' == 0 | `nout' == 0 continue
                local rin  = 100 * `ain'  / `nlane'
                local rout = 100 * `aout' / `nout'
                if `rin' <= `dlow' & `rout' >= `dhigh' {
                    local hits `"`hits' `c'"'
                    local routed_`g' = `routed_`g'' + `nlane'
                }
            }
            if `"`hits'"' != "" {
                local hits = strtrim(`"`hits'"')
                local one `"`g'==`hits'"'
                local gb_`v' `"`gb_`v''`=cond(`"`gb_`v''"' == "", "", "; ")'`one'"'
                local reach_`g' = `p_`v''
            }
        }
    }

    * ---- which gates get drawn --------------------------------------------
    local drawn ""
    local autonote ""
    if `ngdecl' > 0 {
        forvalues i = 1/`ngdecl' {
            local drawn `"`drawn' `gv`i''"'
        }
        local drawn = strtrim(`"`drawn'"')
    }
    else if "`noautodetect'" == "" {
        * the two gates that route around the most respondents
        local best1 ""
        local best2 ""
        local n1 = 0
        local n2 = 0
        foreach g of local cands {
            if `routed_`g'' > `n1' {
                local best2 `"`best1'"'
                local n2 = `n1'
                local best1 `"`g'"'
                local n1 = `routed_`g''
            }
            else if `routed_`g'' > `n2' {
                local best2 `"`g'"'
                local n2 = `routed_`g''
            }
        }
        * keep them in questionnaire order
        foreach v of local vlist {
            if "`v'" == "`best1'" | "`v'" == "`best2'" {
                if `routed_`v'' > 0 local drawn `"`drawn' `v'"'
            }
        }
        local drawn = strtrim(`"`drawn'"')
        if `"`drawn'"' != "" {
            local autonote `"gates found in the data: `drawn'; name your own with branch()"'
        }
    }
    local NG : word count `drawn'

    * ---- segments ----------------------------------------------------------
    * A gate's lanes cover the items it routes around, so declaring a gate
    * shows you what that gate decides wherever those items sit.  An item
    * routed by two gates belongs to the nearer one, which keeps lanes from
    * nesting: every item is in at most one gate's segment.  A gate that
    * routes nothing (party on a survey with no party filter) still earns
    * lanes: it takes the run of unclaimed items up to the next gate, which
    * is how you read answer rates by party across the rest of the survey.
    * drawn is put in questionnaire order first, so "the next gate" means
    * the next one to the right.
    local ordered ""
    foreach v of local vlist {
        local hit : list v in drawn
        if `hit' local ordered `"`ordered' `v'"'
    }
    local drawn = strtrim(`"`ordered'"')

    foreach v of local vlist {
        local owner_`v' ""
        local opos_`v' = 0
    }
    foreach v of local vlist {
        if `"`gb_`v''"' == "" continue
        local rest `"`gb_`v''"'
        while `"`rest'"' != "" {
            local q = strpos(`"`rest'"', "; ")
            if `q' {
                local one = substr(`"`rest'"', 1, `q' - 1)
                local rest = substr(`"`rest'"', `q' + 2, .)
            }
            else {
                local one `"`rest'"'
                local rest ""
            }
            local e = strpos(`"`one'"', "==")
            if !`e' continue
            local gname = strtrim(substr(`"`one'"', 1, `e' - 1))
            local hit : list gname in drawn
            if `hit' & `p_`gname'' > `opos_`v'' {
                local owner_`v' `"`gname'"'
                local opos_`v' = `p_`gname''
            }
        }
    }
    local gi = 0
    foreach g of local drawn {
        local ++gi
        local gname`gi' `"`g'"'
        local seg`gi' ""
        foreach v of local vlist {
            if `"`owner_`v''"' == "`g'" local seg`gi' `"`seg`gi'' `v'"'
        }
        local seg`gi' = strtrim(`"`seg`gi''"')
    }
    * a gate that routes nothing takes the unclaimed run up to the next gate
    local gi = 0
    foreach g of local drawn {
        local ++gi
        if `"`seg`gi''"' != "" continue
        local nxt = `K'
        local seen = 0
        foreach h of local drawn {
            if `p_`h'' > `p_`g'' & !`seen' {
                local nxt = `p_`h'' - 1
                local seen = 1
            }
        }
        forvalues p = `=`p_`g'' + 1'/`nxt' {
            local it `"`item`p''"'
            if `"`it'"' == "" continue
            if "`it'" == "`g'" continue
            if `"`owner_`it''"' != "" continue
            local seg`gi' `"`seg`gi'' `it'"'
        }
        local seg`gi' = strtrim(`"`seg`gi''"')
    }

    * ---- write the journal -------------------------------------------------
    tempname JH
    quietly file open `JH' using `"`out'"', write text replace
    file write `JH' "seq" _tab "class" _tab "var" _tab "position" _tab      ///
        "vallabel" _tab "value" _tab "gatevar" _tab "n_asked" _tab          ///
        "n_answered" _tab "n_nonresp" _tab "n_sysmiss" _tab                 ///
        "pct_answered" _tab "rate" _tab "status" _tab "gate" _tab           ///
        "gated_by" _tab "pooled" _tab "type" _tab "severity" _tab "flags" _n

    local seq = 0
    * survey row: the scan's settings travel with the journal, so a later
    * draw can say what the defaults were
    local ++seq
    local nrtxt = cond(`"`nrcodes'"' == "", "none", `"`nrcodes'"')
    local sflags "prune=`prune' minn=`minn' maxcats=`maxcats' dlow=`dlow' dhigh=`dhigh' nonresp=`nrtxt'"
    if `"`autonote'"' != "" local sflags `"`sflags'; `autonote'"'
    if `"`skipgates'"' != "" local sflags `"`sflags'; skipped `skipgates'"'
    _sm_wrow `JH' `seq' survey "." `K' "." "." "." `N' "." "." "." "." "." ///
        "." "." "." "." "." note `"`sflags'"'

    * item rows
    foreach v of local vlist {
        local ++seq
        local pct = string(100 * `a_`v'' / `N', "%9.1f")
        local isg = 0
        local hit : list v in drawn
        if `hit' local isg = 1
        local st = cond(`"`gb_`v''"' == "", "open", "gated")
        local sev "note"
        local fl "."
        if `a_`v'' == 0 {
            local sev "warn"
            local fl "!! nobody answered this item"
        }
        else if `s_`v'' == `N' {
            local sev "warn"
            local fl "!! nobody was shown this item"
        }
        local gbv = cond(`"`gb_`v''"' == "", ".", `"`gb_`v''"')
        _sm_wrow `JH' `seq' item `"`v'"' `p_`v'' `"`lab_`v''"' "." "."     ///
            `N' `a_`v'' `r_`v'' `s_`v'' `"`pct'"' "." `"`st'"' `isg'      ///
            `"`gbv'"' "." `"`t_`v''"' `"`sev'"' `"`fl'"'
    }

    * category and cell rows, gate by gate
    foreach g of local drawn {
        * which categories are lanes: the declared keep list, or all of them
        local keep ""
        forvalues i = 1/`ngdecl' {
            if "`gv`i''" == "`g'" local keep `"`gk`i''"'
        }
        local cats `"`gvals_`g''"'
        * a hard cap so a mis-declared gate cannot write thousands of rows
        local ncats : word count `cats'
        local capped = 0
        if `ncats' > 30 {
            local capped = 1
            local cats2 ""
            local kk = 0
            foreach c of local cats {
                local ++kk
                if `kk' <= 30 local cats2 `"`cats2' `c'"'
            }
            local cats = strtrim(`"`cats2'"')
        }
        local lanevals ""
        foreach c of local cats {
            if `"`keep'"' != "" {
                local hit : list c in keep
                if !`hit' continue
            }
            local lanevals `"`lanevals' `c'"'
        }
        local lanevals = strtrim(`"`lanevals'"')
        * categories the user did not keep still get a row, marked so a
        * reader can fold them; the journal keeps every category
        local allrows `"`cats'"'

        local vlbl : value label `g'
        foreach c of local allrows {
            frame _smwork {
                quietly count if `g' == `c'
                local nc = r(N)
            }
            local ctext "`c'"
            if `"`vlbl'"' != "" {
                local dec : label `vlbl' `c', strict
                if `"`dec'"' != "" & `"`dec'"' != "`c'" local ctext `"`dec'"'
            }
            local ++seq
            local pooled "."
            local hit : list c in lanevals
            if !`hit' local pooled "1"
            local pct = string(100 * `nc' / `N', "%9.1f")
            _sm_wrow `JH' `seq' cat `"`g'"' `p_`g'' `"`ctext'"' `"`c'"'    ///
                `"`g'"' `nc' "." "." "." `"`pct'"' "." "." "." "."         ///
                `"`pooled'"' "." note "."
        }
        * one row for the respondents who left the gate blank
        frame _smwork {
            quietly count if missing(`g')
            local nblank = r(N)
        }
        if `nblank' > 0 {
            local ++seq
            local pct = string(100 * `nblank' / `N', "%9.1f")
            _sm_wrow `JH' `seq' cat `"`g'"' `p_`g'' "no answer" "noanswer" ///
                `"`g'"' `nblank' "." "." "." `"`pct'"' "." "." "." "."     ///
                "." "." note "."
        }
        if `capped' {
            local ++seq
            _sm_wrow `JH' `seq' note `"`g'"' `p_`g'' "." "." `"`g'"' "."  ///
                "." "." "." "." "." "." "." "." "." "." warn               ///
                `"!! `g' has `ncats' categories; the 30 first are mapped"'
        }

        * cell rows: each lane against each item in the gate's segment
        * cells for EVERY category, not only the lanes this scan kept: the
        * journal holds the whole picture and the reader folds it, so a draw
        * can change prune() or ask for noprune without a rescan
        local segl `"`allrows'"'
        if `nblank' > 0 local segl `"`segl' noanswer"'
        local gidx = 0
        local gj = 0
        foreach h of local drawn {
            local ++gj
            if "`h'" == "`g'" local gidx = `gj'
        }
        foreach it of local seg`gidx' {
            local p = `p_`it''
            foreach c of local segl {
                frame _smwork {
                    if "`c'" == "noanswer" local cond "missing(`g')"
                    else local cond "`g' == `c'"
                    quietly count if `cond'
                    local nlane = r(N)
                    if `nlane' == 0 continue
                    local nrexp "0"
                    if !`str_`it'' {
                        foreach z of local nrcodes {
                            local nrexp `"`nrexp' | `it' == `z'"'
                        }
                    }
                    if `str_`it'' {
                        quietly count if `cond' & trim(`it') != ""
                        local ain = r(N)
                        local nrin = 0
                        local sysin = `nlane' - `ain'
                    }
                    else {
                        quietly count if `cond' & !missing(`it') & !(`nrexp')
                        local ain = r(N)
                        quietly count if `cond' & ((missing(`it') & `it' != .) | (!missing(`it') & (`nrexp')))
                        local nrin = r(N)
                        quietly count if `cond' & `it' == .
                        local sysin = r(N)
                    }
                }
                if `nlane' == 0 continue
                local rt = 100 * `ain' / `nlane'
                local stt = cond(`rt' <= 5, "skipped", cond(`rt' >= 80, "answered", "partial"))
                local ++seq
                _sm_wrow `JH' `seq' cell `"`it'"' `p' "." `"`c'"' `"`g'"' ///
                    `nlane' `ain' `nrin' `sysin' "."                       ///
                    `"`=string(`rt', "%9.1f")'"' `"`stt'"' "." "." "." "." ///
                    note "."
            }
        }
    }
    file close `JH'
    frame drop _smwork

    global SM_LASTJ `"`out'"'
    di as txt "surveymap: " as res "`K'" as txt " items, " as res "`N'"    ///
        as txt " respondents, journal " as res `"`out'"'
    if `"`skipgates'"' != "" {
        di as txt "surveymap: gates skipped -- `skipgates'"
    }

    if "`noreceipt'" == "" {
        _sm_receipt using `"`out'"'
    }

    return local journal `"`out'"'
    return local gates   `"`drawn'"'
    return scalar N        = `N'
    return scalar K_items  = `K'
    return scalar N_gates  = `NG'
end


* ---------------------------------------------------------------- one row
* Writes one journal line.  Every field is sanitized: a tab or a newline
* inside a variable label would otherwise split the row and every reader
* would see a different number of columns.
program define _sm_wrow
    args JH seq class var position vallabel value gatevar n_asked         ///
        n_answered n_nonresp n_sysmiss pct_answered rate status gate      ///
        gated_by pooled type severity flags
    foreach f in class var vallabel value gatevar status gated_by pooled  ///
        type severity flags {
        local `f' = subinstr(`"``f''"', char(9), " ", .)
        local `f' = subinstr(`"``f''"', char(10), " ", .)
        local `f' = subinstr(`"``f''"', char(13), " ", .)
        local `f' = strtrim(`"``f''"')
        if `"``f''"' == "" local `f' "."
    }
    foreach f in seq position n_asked n_answered n_nonresp n_sysmiss      ///
        pct_answered rate gate {
        local `f' = strtrim(`"``f''"')
        if `"``f''"' == "" local `f' "."
    }
    file write `JH' `"`seq'"' _tab `"`class'"' _tab `"`var'"' _tab        ///
        `"`position'"' _tab `"`vallabel'"' _tab `"`value'"' _tab           ///
        `"`gatevar'"' _tab `"`n_asked'"' _tab `"`n_answered'"' _tab        ///
        `"`n_nonresp'"' _tab `"`n_sysmiss'"' _tab `"`pct_answered'"' _tab  ///
        `"`rate'"' _tab `"`status'"' _tab `"`gate'"' _tab `"`gated_by'"'   ///
        _tab `"`pooled'"' _tab `"`type'"' _tab `"`severity'"' _tab         ///
        `"`flags'"' _n
end


* ---------------------------------------------------------------- receipt
* One aligned table: a row per item, in questionnaire order, with what each
* item cost in answers and who was routed around it.
program define _sm_receipt
    version 16
    syntax using/
    capture frame drop _smrc
    frame create _smrc
    local notv2 = 0
    frame _smrc {
        quietly import delimited using `"`using'"', delimiter(tab)        ///
            varnames(1) stringcols(_all) bindquote(nobind) clear
        capture confirm variable gated_by
        if _rc local notv2 = 1
    }
    if `notv2' {
        frame drop _smrc
        di as err `"surveymap: `using' is not a surveymap journal"'
        di as err `"          rebuild it with: surveymap, out(`using')"'
        exit 459
    }

    local jname = substr(`"`using'"', ///
        max(strrpos(`"`using'"', "/"), strrpos(`"`using'"', char(92))) + 1, .)

    frame _smrc {
        quietly levelsof n_asked if class == "survey", local(NN) clean
        quietly levelsof flags   if class == "survey", local(sf) clean
        quietly count if class == "item"
        local K = r(N)
        quietly count if class == "cat"
        local NC = r(N)
        quietly levelsof gatevar if class == "cat", local(gl) clean
        local NG : word count `gl'
        quietly count if class == "item" & gated_by != "."
        local NR = r(N)
        quietly count if class == "item" & severity == "warn"
        local NW = r(N)
    }

    * one short of the line width: a rule exactly as wide as the line wraps
    local ls = c(linesize) - 1
    if `ls' < 79 local ls 79
    if `ls' > 119 local ls 119
    local wlab = `ls' - 62
    if `wlab' < 16 local wlab 16

    di as txt ""
    di as txt "{hline `ls'}"
    di as txt "surveymap receipt: " as res "`jname'" as txt "   (`K' items, " ///
        as res "`NN'" as txt " respondents, `NG' gate" ///
        cond(`NG' == 1, "", "s") ")"
    di as txt "{hline `ls'}"
    di as txt "   #  item" _col(20) "answered" _col(34) "declined" _col(46) "not shown" ///
        _col(58) "routed around by"
    di as txt "{hline `ls'}"

    frame _smrc {
        forvalues i = 1/`=_N' {
            if class[`i'] != "item" continue
            local vn  = var[`i']
            local pos = position[`i']
            local a   = n_answered[`i']
            local r   = n_nonresp[`i']
            local s   = n_sysmiss[`i']
            local p   = pct_answered[`i']
            local gb  = gated_by[`i']
            local sv  = severity[`i']
            if "`gb'" == "." local gb ""
            local af = trim(string(real("`a'"), "%20.0fc"))
            local rf = trim(string(real("`r'"), "%20.0fc"))
            local sf2 = trim(string(real("`s'"), "%20.0fc"))
            if strlen("`vn'") > 15 local vn = substr("`vn'", 1, 14) + "~"
            local gbs "`gb'"
            if strlen("`gbs'") > `wlab' local gbs = substr("`gbs'", 1, `wlab' - 1) + "~"
            di as txt %4s "`pos'" "  " as res %-15s "`vn'" as txt ///
                _col(20) %8s "`af'" as txt " (" %4s "`p'" "%)" ///
                _col(34) %8s "`rf'" _col(46) %8s "`sf2'" "  " ///
                as res %-1s "`gbs'"
            if "`sv'" == "warn" {
                local fl = flags[`i']
                if "`fl'" != "." di as err "        `fl'"
            }
        }
    }
    di as txt "{hline `ls'}"
    di as txt "answered = a real answer.  declined = don't know, refused, or a " ///
        "nonresponse code."
    di as txt "not shown = system missing, which is where skip logic lands."
    if `NR' > 0 {
        di as txt "Routing is read from the responses, not from a questionnaire " ///
            "spec: an item that"
        di as txt "everyone in a category happened to skip looks the same in the data."
    }
    if `NG' > 0 {
        di as txt "`NG' gate" cond(`NG' == 1, "", "s") " drawn with `NC' categories.  " ///
            `"{stata surveymap draw:Draw the map} to see the lanes."'
    }
    else {
        di as txt `"No branching drawn.  Name a gate with branch(), for example "' ///
            "branch(party)."
    }
    frame drop _smrc
end


* ------------------------------------------------------------------- demo
* Writes a small survey, scans it, and shows the whole loop.  A folder the
* demo wrote before is refreshed in place; a folder holding anything else is
* left alone unless replace.
program define _sm_demo
    version 16
    syntax [anything(name=dname)] [, FOLDer(string asis) replace]
    local d `"`folder'"'
    if `"`d'"' == "" local d `"`dname'"'
    if `"`d'"' == "" local d "surveymap_demo"

    local exists = 0
    capture confirm file `"`d'/demo_survey.dta"'
    if !_rc local exists = 1
    mata: st_local("dirthere", strofreal(direxists("`d'")))
    if "`dirthere'" == "1" & !`exists' & "`replace'" == "" {
        di as err `"surveymap demo: the folder `d' exists and holds files the demo did not write"'
        di as err "    name another folder, or specify replace"
        exit 602
    }
    capture mkdir `"`d'"'

    preserve
    quietly {
        clear
        set seed 20260823
        set obs 600
        capture label drop smd_yn
        capture label drop smd_party
        capture label drop smd_why
        label define smd_yn 1 "Yes" 0 "No" .a "Don't know" .b "Refused"
        label define smd_party 1 "Democrat" 2 "Republican" 3 "Independent" ///
            .a "Don't know" .b "Refused"
        label define smd_why 1 "Too busy" 2 "Not registered" 3 "Other reason" ///
            .a "Don't know"
        gen long resp_id = _n
        label variable resp_id "Respondent id"
        tempvar u
        gen double `u' = runiform()
        gen byte consent = `u' >= .04
        label variable consent "Consented to be interviewed"
        label values consent smd_yn
        replace `u' = runiform()
        gen byte party = .
        replace party = 1 if consent == 1 & `u' < .40
        replace party = 2 if consent == 1 & `u' >= .40 & `u' < .75
        replace party = 3 if consent == 1 & `u' >= .75
        replace `u' = runiform()
        replace party = .a if consent == 1 & `u' < .05
        label variable party "Party identification"
        label values party smd_party
        replace `u' = runiform()
        gen byte voted = .
        replace voted = `u' < .64 if consent == 1
        label variable voted "Voted in the last election"
        label values voted smd_yn
        replace `u' = runiform()
        gen byte whyskip = .
        replace whyskip = 1 + floor(`u' * 3) if voted == 0
        label variable whyskip "Main reason for not voting"
        label values whyskip smd_why
        replace `u' = runiform()
        gen byte approve = .
        replace approve = 1 + floor(`u' * 4) if consent == 1
        replace `u' = runiform()
        replace approve = .a if consent == 1 & `u' < .07
        label variable approve "Approval of the governor"
        replace `u' = runiform()
        gen byte income = .
        replace income = 1 + floor(`u' * 6) if consent == 1
        replace `u' = runiform()
        replace income = .b if consent == 1 & `u' < .20
        label variable income "Household income bracket"
        drop `u'
        compress
        label data "surveymap demo survey"
        save `"`d'/demo_survey.dta"', replace
    }

    di as txt ""
    di as txt "{hline 78}"
    di as txt "surveymap demo: a 600-person survey in " as res `"`d'"'
    di as txt "{hline 78}"
    di as txt "The survey has a consent question, a party question, and a voting"
    di as txt "question that routes non-voters around the reason-for-not-voting item."
    di as txt ""
    di as txt "This is what was run:"
    di as txt `"    use "`d'/demo_survey.dta", clear"'
    di as txt `"    surveymap, branch(party) out("`d'/demo_journal.tsv") replace"'
    di as txt ""

    surveymap, branch(party) out(`"`d'/demo_journal.tsv"') replace
    restore

    di as txt ""
    di as txt "Next:"
    di as txt `"    {stata surveymap draw:surveymap draw}"' ///
        as txt "                     the flow map, in your browser"
    di as txt `"    {stata surveymap draw, export(mermaid) saving(demo_map) replace:surveymap draw, export(mermaid) ...}"' ///
        as txt "  text for a README"
    di as txt `"    {stata surveymap export, saving(`d'/demo_tracker.xlsx) replace:surveymap export, saving(...xlsx)}"' ///
        as txt "   the Excel tracker"
    di as txt ""
    c_local demojournal `"`d'/demo_journal.tsv"'
end
