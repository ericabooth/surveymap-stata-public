*! version 0.4.3  24aug2026  Eric Booth
*! _sm_jprune -- apply the prune rules to a surveymap journal before a
*! reader (receipt, HTML map, mermaid, Excel) sees it.
*!
*! The journal keeps EVERY category of every gate (proto/JOURNAL_SCHEMA.md);
*! pruning is a read-time decision, so prune()/minn()/maxcats() can change at
*! draw or export time without a rescan -- the same architecture as
*! mergemap's draw-time cuts.  Rules, applied per gate:
*!   keep a category when pct >= prune AND n >= minn;
*!   keep at most maxcats categories (largest n first; ties by value order);
*!   fold the rest into one "other" row (cat and cell rows aggregated,
*!   pct and rate recomputed);
*!   the "noanswer" category (gate left blank) is never folded into other --
*!   it is kept when it clears minn alone, else folded.
*! Lane rows still partition the scope: kept + other + noanswer.
*!
*! syntax:  _sm_jprune using journal.tsv [, prune(real) minn(integer)
*!              maxcats(integer) NOPRUNE Quietly]
*! Defaults come from the survey row's recorded settings when an option is
*! not given, falling back to prune(5) minn(30) maxcats(6).
*! returns: s(jfile)  the journal to read (the input when nothing was folded)
*!          s(note)   one line on what was folded, "" when nothing
*!          s(n_folded)  categories folded across all gates

program define _sm_jprune, sclass
    version 16
    syntax using/ [, PRUNE(real -1) MINN(integer -1) MAXCats(integer -1) ///
        NOPRUNE Quietly]
    sreturn clear
    sreturn local jfile `"`using'"'
    sreturn local note ""
    sreturn local n_folded = 0
    if "`noprune'" != "" exit

    capture frame drop _smpr
    frame create _smpr
    frame _smpr {
        quietly import delimited `"`using'"', delimiter(tab) varnames(1) ///
            stringcols(_all) clear
        capture confirm variable class
        if _rc {
            di as err `"surveymap: `using' is not a surveymap journal"'
            exit 459
        }
    }
    * the frame cannot be dropped from inside its own block: compute inside,
    * decide outside
    local bad = 0
    frame _smpr {
        capture confirm variable gatevar
        if _rc local bad = 1
    }
    if `bad' {
        frame drop _smpr
        di as err `"surveymap: `using' is not a surveymap journal (no gatevar column)"'
        exit 459
    }

    * ---- defaults: the survey row recorded the scan's settings ----------
    frame _smpr {
        quietly levelsof flags if class == "survey", local(sflags) clean
    }
    if `prune' < 0 {
        local prune = 5
        local p = strpos(`"`sflags'"', "prune=")
        if `p' local prune = real(substr(`"`sflags'"', `p' + 6, ///
            cond(strpos(substr(`"`sflags'"', `p' + 6, .), " "), ///
                 strpos(substr(`"`sflags'"', `p' + 6, .), " ") - 1, .)))
        if `prune' >= . local prune = 5
    }
    if `minn' < 0 {
        local minn = 30
        local p = strpos(`"`sflags'"', "minn=")
        if `p' local minn = real(substr(`"`sflags'"', `p' + 5, ///
            cond(strpos(substr(`"`sflags'"', `p' + 5, .), " "), ///
                 strpos(substr(`"`sflags'"', `p' + 5, .), " ") - 1, .)))
        if `minn' >= . local minn = 30
    }
    if `maxcats' < 0 {
        local maxcats = 6
        local p = strpos(`"`sflags'"', "maxcats=")
        if `p' local maxcats = real(substr(`"`sflags'"', `p' + 8, ///
            cond(strpos(substr(`"`sflags'"', `p' + 8, .), " "), ///
                 strpos(substr(`"`sflags'"', `p' + 8, .), " ") - 1, .)))
        if `maxcats' >= . local maxcats = 6
    }

    local nfold = 0
    frame _smpr {
        quietly gen long sm_row = _n
        quietly gen double sm_n   = real(n_asked)
        quietly gen double sm_pct = real(pct_answered)
        * ---- decide, per gate, which categories fold --------------------
        quietly gen byte sm_fold = 0
        * the scan may already have marked a category to fold: branch(g = 1 3)
        * means the categories left out of the list are not lanes.  That is a
        * scan-time decision and it is honoured here alongside the read-time
        * rules; noprune skips this program and shows everything.
        quietly replace sm_fold = 1 if class == "cat" & pooled == "1"
        quietly levelsof gatevar if class == "cat", local(gates) clean
        foreach g of local gates {
            * rank real categories by n (noanswer handled after)
            quietly count if class == "cat" & gatevar == "`g'" & value != "noanswer"
            local nc = r(N)
            quietly replace sm_fold = 1 if class == "cat" & gatevar == "`g'" ///
                & value != "noanswer" ///
                & (sm_pct < `prune' | sm_n < `minn')
            if `nc' > `maxcats' {
                * keep the maxcats largest of the survivors
                tempvar rk
                quietly gsort -sm_n sm_row
                quietly gen long `rk' = sum(class == "cat" & gatevar == "`g'" ///
                    & value != "noanswer" & !sm_fold)
                quietly replace sm_fold = 1 if class == "cat" & gatevar == "`g'" ///
                    & value != "noanswer" & !sm_fold & `rk' > `maxcats'
                drop `rk'
                sort sm_row
            }
            * a blank-gate lane below minn folds too
            quietly replace sm_fold = 1 if class == "cat" & gatevar == "`g'" ///
                & value == "noanswer" & sm_n < `minn'
            * never fold everything: if no real category survives, keep the
            * largest so the gate still draws
            quietly count if class == "cat" & gatevar == "`g'" ///
                & value != "noanswer" & !sm_fold
            if r(N) == 0 {
                tempvar rk2
                quietly gsort -sm_n sm_row
                quietly gen long `rk2' = sum(class == "cat" & gatevar == "`g'" ///
                    & value != "noanswer")
                quietly replace sm_fold = 0 if class == "cat" & gatevar == "`g'" ///
                    & value != "noanswer" & `rk2' == 1
                drop `rk2'
                sort sm_row
            }
        }
        * mark the pooled column for the record
        quietly replace pooled = "1" if sm_fold & class == "cat"
        quietly count if sm_fold & class == "cat"
        local nfold = r(N)
    }
    if `nfold' == 0 {
        frame drop _smpr
        if "`quietly'" == "" exit
        exit
    }

    * ---- fold: aggregate cat and cell rows of folded categories ---------
    frame _smpr {
        * which (gate, value) pairs fold
        quietly gen byte sm_isfold = 0
        quietly levelsof gatevar if sm_fold, local(fg) clean
        foreach g of local fg {
            quietly levelsof value if sm_fold & gatevar == "`g'", local(fv)
            foreach v of local fv {
                * value is a string column; the token must be quoted or a
                * numeric-looking level dies on a type mismatch (r109)
                quietly replace sm_isfold = 1 if gatevar == "`g'" ///
                    & value == `"`v'"' & inlist(class, "cat", "cell")
            }
        }
        * numeric working copies for the sums
        foreach c in n_asked n_answered n_nonresp n_sysmiss {
            capture confirm variable `c'
            if !_rc quietly gen double sm_`c' = real(`c')
        }
        * aggregate folded rows into one "other" row per gate (cat) and per
        * gate x item (cell)
        tempfile keeprows
        preserve
        quietly keep if sm_isfold
        quietly count
        if r(N) > 0 {
            collapse (sum) sm_n_asked sm_n_answered sm_n_nonresp sm_n_sysmiss ///
                (first) sm_row position, by(class gatevar var)
            quietly gen value = "other"
            quietly gen vallabel = "other (pooled)"
            quietly gen pooled = "."
            quietly gen str12 status = ""
            quietly gen str12 severity = "."
            quietly gen str12 gate = "."
            quietly gen str1 gated_by = "."
            quietly gen str1 type = "."
            quietly gen str1 flags = "."
            quietly save `"`keeprows'"'
        }
        else quietly save `"`keeprows'"', emptyok
        restore
        quietly drop if sm_isfold
        quietly append using `"`keeprows'"'
        sort sm_row
        * recompute the folded rows' text columns
        capture confirm variable seq
        quietly replace seq = string(_n) if seq == "" | seq == "."
        foreach c in n_asked n_answered n_nonresp n_sysmiss {
            capture confirm variable sm_`c'
            if !_rc {
                quietly replace `c' = string(sm_`c', "%20.0f") if value == "other" & sm_`c' < .
            }
        }
        * pct (cat rows: share of scope) and rate (cell rows: share of lane)
        quietly levelsof n_asked if class == "survey", local(NN) clean
        local NN = real(`"`NN'"')
        quietly replace pct_answered = string(100 * sm_n_asked / `NN', "%9.1f") ///
            if value == "other" & class == "cat" & `NN' < . & `NN' > 0
        quietly replace rate = string(100 * sm_n_answered / sm_n_asked, "%9.1f") ///
            if value == "other" & class == "cell" & sm_n_asked > 0 & sm_n_asked < .
        quietly replace rate = "." if value == "other" & class == "cell" & rate == ""
        quietly replace status = cond(real(rate) <= 5, "skipped", ///
            cond(real(rate) >= 80, "answered", "partial")) ///
            if value == "other" & class == "cell" & real(rate) < .
        quietly drop sm_row sm_n sm_pct sm_fold sm_isfold
        capture drop sm_n_asked sm_n_answered sm_n_nonresp sm_n_sysmiss
        tempfile jp
        local jp `"`jp'.tsv"'
        quietly export delimited using `"`jp'"', delimiter(tab) replace datafmt
    }
    frame drop _smpr
    local note "folded `nfold' small categories into other (prune `prune'%, minn `minn', maxcats `maxcats')"
    if "`quietly'" == "" di as txt "surveymap: `note'"
    sreturn local jfile `"`jp'"'
    sreturn local note  `"`note'"'
    sreturn local n_folded = `nfold'
end
