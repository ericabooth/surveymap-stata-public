*! version 0.3.0  24aug2026  Eric Booth
*! _sm_export -- the journal as a dataset or an Excel tracker.  Count and
*! percentage columns arrive numeric; text columns stay text.  The xlsx form
*! is the point: a three-sheet tracker (items, branch lanes, lane-by-item
*! cells) that field staff can sort and filter, and that can sit inside a
*! datadictionary workbook next to the codebook sheets.
*!
*! Formats: xlsx (default -- the tracker), dta, csv.  The format follows the
*! extension on saving() when format() is not given.  The xlsx sheets:
*!   sm_items     one row per mapped item: variable position varlabel
*!                n_asked n_answered pct_answered n_nonresp n_sysmiss gate
*!                gated_by flags.  The first column is named "variable" to
*!                match datadictionary's Variables-sheet key, so an
*!                Excel-side join is one VLOOKUP.
*!   sm_branches  one row per gate category: gatevar value label n pct pooled
*!   sm_flow      one row per lane x item cell: gatevar value item n_lane
*!                n_answered rate status
*! dta/csv write the whole (pruned) journal, typed.
*!
*! dictionary(dd.xlsx) writes the three sm_ sheets INTO an existing
*! datadictionary workbook via sheetreplace, leaving every other sheet alone;
*! it may not be combined with saving().  Pruning (prune/minn/maxcats/
*! noprune) is applied at read time by _sm_jprune, so the tracker can be cut
*! differently from the scan without a rescan.
*!
*! r(): r(file) r(journal) r(N_items) r(N_branches) r(N_cells) r(format)

program define _sm_export, rclass
    version 16
    syntax [anything(name=jspec)] [, Format(string) SAVing(string) replace ///
        DICTionary(string) PRUNE(real -1) MINN(integer -1)                 ///
        MAXCats(integer -1) NOPRUNE]

    if `"`saving'"' != "" & `"`dictionary'"' != "" {
        di as err "surveymap export: saving() and dictionary() may not be combined;"
        di as err "    dictionary() names the workbook the sheets are written into"
        exit 198
    }

    * ---- format: explicit, else the saving() extension, else xlsx --------
    local format = strlower("`format'")
    if inlist("`format'", "excel", "xls") local format "xlsx"
    if "`format'" == "" {
        local lo = strlower(`"`saving'"')
        if substr(`"`lo'"', -4, .) == ".dta"       local format "dta"
        else if substr(`"`lo'"', -4, .) == ".csv"  local format "csv"
        else if substr(`"`lo'"', -5, .) == ".xlsx" local format "xlsx"
        else if substr(`"`lo'"', -4, .) == ".xls"  local format "xlsx"
        else local format "xlsx"
    }
    if !inlist("`format'", "dta", "csv", "xlsx") {
        di as err "surveymap export: format() must be dta, csv, or xlsx"
        exit 198
    }
    if `"`dictionary'"' != "" & "`format'" != "xlsx" {
        di as err "surveymap export: dictionary() writes xlsx sheets; format(`format') may not be combined with it"
        exit 198
    }

    * ---- which journal: explicit, else the last scan's, else the default -
    gettoken w1 rest : jspec
    if `"`w1'"' == "using" local jspec `"`rest'"'
    gettoken jfile : jspec
    if `"`jfile'"' == "" local jfile `"$SM_LASTJ"'
    if `"`jfile'"' == "" {
        capture confirm file "survey_journal.tsv"
        if !_rc local jfile "survey_journal.tsv"
    }
    if `"`jfile'"' == "" {
        di as err "surveymap: no journal to export."
        di as err "    Scan something first (surveymap [varlist]), or name a"
        di as err "    journal file on the command line."
        exit 601
    }
    capture confirm file `"`jfile'"'
    if _rc {
        di as err `"surveymap: journal `jfile' not found"'
        exit 601
    }

    * ---- output file ------------------------------------------------------
    if `"`dictionary'"' != "" {
        if strlower(substr(`"`dictionary'"', -5, .)) != ".xlsx" ///
            & strlower(substr(`"`dictionary'"', -4, .)) != ".xls" {
            local dictionary `"`dictionary'.xlsx"'
        }
        capture confirm file `"`dictionary'"'
        if _rc {
            di as err `"surveymap export: dictionary(`dictionary') not found;"'
            di as err "    run datadictionary, excel(...) first, or export without dictionary()"
            exit 601
        }
        local outfile `"`dictionary'"'
    }
    else {
        if `"`saving'"' == "" {
            local saving = cond("`format'" == "xlsx", ///
                "surveymap_tracker.xlsx", "surveymap_journal.`format'")
        }
        if "`format'" == "xlsx" ///
            & strlower(substr(`"`saving'"', -5, .)) != ".xlsx" ///
            & strlower(substr(`"`saving'"', -4, .)) != ".xls" {
            local saving `"`saving'.xlsx"'
        }
        local outfile `"`saving'"'
    }

    * ---- read-time prune, then load; the journal itself is never edited ---
    _sm_jprune using `"`jfile'"', prune(`prune') minn(`minn') ///
        maxcats(`maxcats') `noprune'
    local src `"`s(jfile)'"'

    capture frame drop _smexp
    frame create _smexp
    local bad = 0
    frame _smexp {
        quietly import delimited `"`src'"', delimiter(tab) varnames(1) ///
            stringcols(_all) clear
        capture confirm variable class
        if _rc local bad = 1
        capture confirm variable gatevar
        if _rc local bad = 1
    }
    if `bad' {
        frame drop _smexp
        di as err `"surveymap: `jfile' is not a surveymap journal"'
        exit 459
    }

    frame _smexp {
        quietly count if class == "item"
        local nitems = r(N)
        quietly count if class == "cat"
        local nbranch = r(N)
        quietly count if class == "cell"
        local ncell = r(N)
        quietly count
        local N = r(N)

        if "`format'" != "xlsx" {
            * numbers as numbers; "." was the journal's missing all along
            foreach v in seq position n_asked n_answered n_nonresp ///
                n_sysmiss pct_answered rate gate pooled {
                capture confirm variable `v'
                if !_rc quietly destring `v', replace force
            }
            if "`format'" == "dta" quietly save `"`outfile'"', `replace'
            else quietly export delimited using `"`outfile'"', `replace'
        }
    }

    if "`format'" == "xlsx" {
        * first sheet may take -replace-; later sheets need -sheetreplace-
        * and no -replace-.  Into a datadictionary workbook every sheet is
        * -sheetreplace-, so its own sheets survive.
        local sh1opt `"`replace'"'
        if `"`dictionary'"' != "" local sh1opt "sheetreplace"

        * ---- sm_items: the tracker rows, keyed "variable" -----------------
        capture frame drop _smexpi
        frame copy _smexp _smexpi
        frame _smexpi {
            quietly keep if class == "item"
            rename var variable
            rename vallabel varlabel
            foreach v in position n_asked n_answered pct_answered ///
                n_nonresp n_sysmiss gate {
                quietly destring `v', replace force
            }
            foreach v in varlabel gated_by flags {
                quietly replace `v' = "" if `v' == "."
            }
            quietly keep variable position varlabel n_asked n_answered ///
                pct_answered n_nonresp n_sysmiss gate gated_by flags
            order variable position varlabel n_asked n_answered ///
                pct_answered n_nonresp n_sysmiss gate gated_by flags
            quietly export excel using `"`outfile'"', sheet("sm_items") ///
                firstrow(variables) `sh1opt'
        }
        frame drop _smexpi

        * ---- sm_branches: one row per gate category ------------------------
        capture frame drop _smexpb
        frame copy _smexp _smexpb
        frame _smexpb {
            quietly keep if class == "cat"
            rename vallabel label
            rename n_asked n
            rename pct_answered pct
            foreach v in n pct pooled {
                quietly destring `v', replace force
            }
            quietly replace label = "" if label == "."
            quietly keep gatevar value label n pct pooled
            order gatevar value label n pct pooled
            if _N > 0 {
                quietly export excel using `"`outfile'"', ///
                    sheet("sm_branches") firstrow(variables) sheetreplace
            }
            else {
                * no gates journaled: a header-only sheet keeps the
                * three-sheet contract (putexcel creates a missing sheet)
                capture putexcel set `"`outfile'"', sheet("sm_branches") modify open
                capture putexcel A1 = "gatevar" B1 = "value" C1 = "label" ///
                    D1 = "n" E1 = "pct" F1 = "pooled"
                capture putexcel save
            }
        }
        frame drop _smexpb

        * ---- sm_flow: one row per lane x item cell -------------------------
        capture frame drop _smexpf
        frame copy _smexp _smexpf
        frame _smexpf {
            quietly keep if class == "cell"
            rename var item
            rename n_asked n_lane
            foreach v in n_lane n_answered rate {
                quietly destring `v', replace force
            }
            quietly replace status = "" if status == "."
            quietly keep gatevar value item n_lane n_answered rate status
            order gatevar value item n_lane n_answered rate status
            if _N > 0 {
                quietly export excel using `"`outfile'"', sheet("sm_flow") ///
                    firstrow(variables) sheetreplace
            }
            else {
                capture putexcel set `"`outfile'"', sheet("sm_flow") modify open
                capture putexcel A1 = "gatevar" B1 = "value" C1 = "item" ///
                    D1 = "n_lane" E1 = "n_answered" F1 = "rate" G1 = "status"
                capture putexcel save
            }
        }
        frame drop _smexpf

        * a bold header row on each sheet, so it reads as a table; no harm
        * done if this Stata cannot style cells
        foreach sh in sm_items sm_branches sm_flow {
            capture putexcel set `"`outfile'"', sheet("`sh'") modify
            if !_rc {
                capture putexcel A1:K1, bold
                capture putexcel clear
            }
        }
    }
    frame drop _smexp

    di as txt "surveymap export: `nitems' items from " as res `"`jfile'"'
    di as txt "               to " as res `"`outfile'"'
    if "`format'" == "xlsx" {
        di as txt "               sheets: sm_items (`nitems'), sm_branches (`nbranch'), sm_flow (`ncell')"
        if `"`dictionary'"' != "" ///
            di as txt "               inside the datadictionary workbook; its own sheets untouched"
    }
    else di as txt "               `N' journal rows, typed"

    return local file    `"`outfile'"'
    return local journal `"`jfile'"'
    return local format  "`format'"
    return scalar N_items    = `nitems'
    return scalar N_branches = `nbranch'
    return scalar N_cells    = `ncell'
end
