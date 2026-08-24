*! version 0.1.0  23aug2026  Eric Booth
*! _sm_rendertext -- emit a mermaid flowchart LR from a surveymap journal
*! (TSV, 20 columns).
*!
*! syntax: _sm_rendertext using journal.tsv, saving(stub) [name(string) replace]
*!
*! files written:
*!   stub.mmd   the bare mermaid source
*!   stub.md    the same wrapped in a ```mermaid fence with a title line
*!
*! conventions (JOURNAL_SCHEMA.md): items are nodes in position order,
*! n<pos>[qname<br/>n (pct%)]; a gate fans out one edge per lane (kept
*! categories + other + noanswer, from the journal as given), labeled with
*! the category label and its n; lane cells are nodes n<pos>v<lane>; a cell
*! the lane was routed around is a dashed "ghost" node (classDef); lanes
*! merge back into the next spine item.  Severity travels as the "!!" text
*! marker, never colour alone; the one accent, #4a6d8c, strokes flagged
*! nodes.  No "click ... href" anywhere; nothing newer than mermaid 10.0.2.

program define _sm_rendertext
    version 16
    syntax using/, SAVing(string) [NAME(string) replace]

    * forgive a pasted extension on the stub
    foreach e in .mmd .md {
        local le = strlen("`e'")
        if strlower(substr(`"`saving'"', -`le', .)) == "`e'" {
            local saving = substr(`"`saving'"', 1, strlen(`"`saving'"') - `le')
        }
    }

    * ---- load the journal into a frame (read columns BY NAME) ----
    tempname J
    frame create `J'
    frame `J' {
        quietly import delimited using "`using'", delimiter(tab) ///
            varnames(1) stringcols(_all) clear
        capture confirm variable class
        local badc = _rc
        capture confirm variable gatevar
        if `badc' | _rc {
            display as error "`using' is not a surveymap journal (no " ///
                "class/gatevar column; see JOURNAL_SCHEMA.md)"
            exit 459
        }
        foreach v in seq class var position vallabel value gatevar n_asked ///
            n_answered n_nonresp n_sysmiss pct_answered rate status gate  ///
            gated_by pooled type severity flags {
            capture confirm variable `v'
            if _rc quietly generate str1 `v' = "."
            quietly replace `v' = "." if `v' == ""
        }
        * neutralize before any value passes through a macro (TRAPS 1):
        * backtick and double quote become apostrophes (mermaid labels must
        * not carry double quotes), dollar becomes a placeholder swapped back
        * at write time, "<" would read as an html tag and gets mermaid's own
        * entity form
        foreach v in class var vallabel value gatevar status gate gated_by ///
            pooled type severity flags {
            quietly replace `v' = subinstr(`v', char(96), char(39), .)
            quietly replace `v' = subinstr(`v', char(34), char(39), .)
            quietly replace `v' = subinstr(`v', char(36), char(2),  .)
            quietly replace `v' = subinstr(`v', "<", "#60;", .)
        }
    }
    frame `J': local NR = _N

    * ---- survey + item index (positions 1..K) ----
    local NN "."
    local K = 0
    forvalues i = 1/`NR' {
        frame `J': local cls = class[`i']
        if "`cls'" == "survey" {
            frame `J': local NN = n_asked[`i']
        }
        if "`cls'" != "item" continue
        frame `J': local p = real(position[`i'])
        if `p' >= . continue
        local K = max(`K', `p')
        frame `J': local v_`p'  = var[`i']
        frame `J': local na_`p' = n_asked[`i']
        frame `J': local nn_`p' = n_answered[`i']
        frame `J': local nr_`p' = n_nonresp[`i']
        frame `J': local pa_`p' = pct_answered[`i']
        frame `J': local g_`p'  = gate[`i']
    }
    if `K' == 0 {
        frame drop `J'
        display as error "`using' has no item rows; nothing to draw"
        exit 459
    }
    local G = 0
    forvalues p = 1/`K' {
        if `"`v_`p''"' == "" {
            frame drop `J'
            display as error "journal item positions are not contiguous (position `p' missing)"
            exit 459
        }
        if "`g_`p''" == "1" local ++G
        local L_`p' = 0
    }

    * ---- lanes per gate: cat rows in order, other and noanswer last ----
    forvalues i = 1/`NR' {
        frame `J': local cls = class[`i']
        if "`cls'" != "cat" continue
        frame `J': local gv = gatevar[`i']
        local gp = 0
        forvalues p = 1/`K' {
            if `"`v_`p''"' == `"`gv'"' local gp = `p'
        }
        if `gp' == 0 continue
        frame `J': local vv = value[`i']
        frame `J': local ll = vallabel[`i']
        frame `J': local ln = n_asked[`i']
        if `"`vv'"' == "noanswer" {
            local hasna_`gp' = 1
            local nal_`gp' `"`ll'"'
            local nan_`gp' `"`ln'"'
        }
        else if `"`vv'"' == "other" {
            local hasot_`gp' = 1
            local otl_`gp' `"`ll'"'
            local otn_`gp' `"`ln'"'
        }
        else {
            local k = `L_`gp'' + 1
            local L_`gp' = `k'
            local lv_`gp'_`k' `"`vv'"'
            local ll_`gp'_`k' `"`ll'"'
            local ln_`gp'_`k' `"`ln'"'
        }
    }
    forvalues p = 1/`K' {
        if "`hasot_`p''" == "1" {
            local k = `L_`p'' + 1
            local L_`p' = `k'
            local lv_`p'_`k' "other"
            local ll_`p'_`k' `"`otl_`p''"'
            local ln_`p'_`k' `"`otn_`p''"'
        }
        if "`hasna_`p''" == "1" {
            local k = `L_`p'' + 1
            local L_`p' = `k'
            local lv_`p'_`k' "noanswer"
            local ll_`p'_`k' `"`nal_`p''"'
            local ln_`p'_`k' `"`nan_`p''"'
        }
    }

    * ---- cells + segment map (nearer gate wins on a conflict) ----
    forvalues i = 1/`NR' {
        frame `J': local cls = class[`i']
        if "`cls'" != "cell" continue
        frame `J': local gv = gatevar[`i']
        frame `J': local w  = var[`i']
        local gp = 0
        local wp = 0
        forvalues p = 1/`K' {
            if `"`v_`p''"' == `"`gv'"' local gp = `p'
            if `"`v_`p''"' == `"`w'"'  local wp = `p'
        }
        if `gp' == 0 | `wp' == 0 continue
        if `gp' >= `wp' continue
        if "`seg_`wp''" == "" local seg_`wp' = `gp'
        else if `gp' > `seg_`wp'' local seg_`wp' = `gp'
        frame `J': local vv = value[`i']
        local kk = 0
        forvalues k = 1/`L_`gp'' {
            if `"`lv_`gp'_`k''"' == `"`vv'"' local kk = `k'
        }
        if `kk' == 0 continue
        frame `J': local cN_`gp'_`kk'_`wp' = n_answered[`i']
        frame `J': local cR_`gp'_`kk'_`wp' = rate[`i']
        frame `J': local cS_`gp'_`kk'_`wp' = status[`i']
    }
    * A gate's segment is the run of items it owns.  That run does not have
    * to start in the column after the gate: a party question asked early can
    * own the primary-turnout items much later, and the lanes belong where
    * those items are.  fanat_ maps the column a fan opens in to its gate.
    forvalues q = 1/`K' {
        local fanat_`q' ""
    }
    forvalues p = 1/`K' {
        local segstart_`p' = 0
        local segend_`p' = `p'
        if "`g_`p''" != "1" continue
        local ps = 0
        local pe = `p'
        forvalues q = `=`p'+1'/`K' {
            if "`seg_`q''" == "`p'" {
                if `ps' == 0 local ps = `q'
                local pe = `q'
            }
            else if `ps' > 0 continue, break
        }
        local segstart_`p' = `ps'
        local segend_`p' = `pe'
        if `ps' > 0 & `L_`p'' > 0 local fanat_`ps' = `p'
    }

    * ---- build node, edge and class stacks ----
    local nnd = 0
    local ned = 0
    local ghosts ""
    local warns  ""
    local prev ""
    local p = 1
    while `p' <= `K' {
        * a gate's lanes open here?  Then this column and the rest of the
        * segment are drawn as lanes, and the spine picks up after the merge.
        if "`fanat_`p''" != "" {
            local gp = `fanat_`p''
            local pe = `segend_`gp''
            local mtgt ""
            if `pe' + 1 <= `K' local mtgt "n`=`pe'+1'"
            local src `"`prev'"'
            forvalues k = 1/`L_`gp'' {
                local q1 = 0
                local qL = 0
                forvalues q = `p'/`pe' {
                    if `"`cS_`gp'_`k'_`q''"' == "" continue
                    if `q1' == 0 local q1 = `q'
                    local qL = `q'
                }
                _srt_n `"`ln_`gp'_`k''"'
                local flab `"`v_`gp'' = `ll_`gp'_`k'' - `s(o)'"'
                if `q1' == 0 {
                    if "`mtgt'" != "" & "`src'" != "" {
                        local ++ned
                        local ed`ned' `"  `src' -- "`flab'" --> `mtgt'"'
                    }
                    continue
                }
                if "`src'" != "" {
                    local ++ned
                    local ed`ned' `"  `src' -- "`flab'" --> n`q1'v`k'"'
                }
                local pc ""
                forvalues q = `q1'/`qL' {
                    if `"`cS_`gp'_`k'_`q''"' == "" continue
                    local st `"`cS_`gp'_`k'_`q''"'
                    local id "n`q'v`k'"
                    if `"`st'"' == "skipped" {
                        local clab `"`v_`q''<br/>skipped"'
                        local ghosts = "`ghosts'" + cond("`ghosts'" == "", "", ",") + "`id'"
                    }
                    else {
                        _srt_n `"`cN_`gp'_`k'_`q''"'
                        local cnf `"`s(o)'"'
                        if "`cnf'" == "" local cnf "."
                        local clab `"`v_`q''<br/>`cnf' (`cR_`gp'_`k'_`q''%)"'
                        if `"`st'"' == "partial" {
                            local clab `"`clab'<br/>!! partial"'
                            local warns = "`warns'" + cond("`warns'" == "", "", ",") + "`id'"
                        }
                    }
                    local ++nnd
                    local nd`nnd' `"  `id'["`clab'"]"'
                    if "`pc'" != "" {
                        local ++ned
                        local ed`ned' `"  `pc' --> `id'"'
                    }
                    local pc "`id'"
                }
                if "`mtgt'" != "" & "`pc'" != "" {
                    local ++ned
                    local ed`ned' `"  `pc' --> `mtgt'"'
                }
            }
            local prev ""
            local p = `pe' + 1
            continue
        }
        * spine node for item p
        _srt_n `"`nn_`p''"'
        local nnf `"`s(o)'"'
        if "`nnf'" == "" local nnf "."
        local lab `"`v_`p''<br/>`nnf' (`pa_`p''%)"'
        local isw = 0
        local rr = real(`"`nr_`p''"')
        local aa = real(`"`na_`p''"')
        if `rr' < . & `aa' < . & `aa' > 0 {
            if `rr' > 0.05 * `aa' {
                _srt_n `"`nr_`p''"'
                local lab `"`lab'<br/>!! nonresp `s(o)'"'
                local isw = 1
            }
        }
        local ++nnd
        local nd`nnd' `"  n`p'["`lab'"]"'
        if `isw' local warns = "`warns'" + cond("`warns'" == "", "", ",") + "n`p'"
        if "`prev'" != "" {
            local ++ned
            local ed`ned' `"  `prev' --> n`p'"'
        }
        local prev "n`p'"
        local ++p
    }
    frame drop `J'

    * ---- provenance: journal name, timestamp, Stata version ----
    local jname = substr("`using'", ///
        cond(max(strrpos("`using'", "/"), strrpos("`using'", char(92))) > 0, ///
        max(strrpos("`using'", "/"), strrpos("`using'", char(92))) + 1, 1), .)
    if `"`name'"' != "" local jname `"`name'"'
    local flav = cond(c(MP) == 1, "MP", cond(c(SE) == 1, "SE", c(flavor)))
    local prov "surveymap _sm_rendertext 0.1.0 - journal `jname'"
    local prov "`prov' - rendered `c(current_date)' `c(current_time)'"
    local prov "`prov' - Stata `c(stata_version)' `flav'"

    _srt_n `"`NN'"'
    local nnf `"`s(o)'"'
    if "`nnf'" == "" local nnf "?"
    local acct "surveymap flow of `jname'"
    local gw = cond(`G' == 1, "gate", "gates")
    local iw = cond(`K' == 1, "item", "items")
    local accd "`nnf' respondents, `K' `iw', `G' `gw'. Items run left to"
    local accd "`accd' right in questionnaire order; a gate fans the sample"
    local accd "`accd' into lanes that rejoin the spine at the end of its"
    local accd "`accd' segment. A dashed node is a cell the lane was routed"
    local accd "`accd' around. Two exclamation marks flag a warning."

    * ---- emit stub.mmd, then the same fenced as stub.md ----
    * one layout, so the file is named for the stub the caller gave: a
    * survey runs left to right and there is no second direction to pick
    local written ""
    foreach ext in mmd md {
        local out "`saving'.`ext'"
        if "`replace'" == "" confirm new file "`out'"
        tempname fh
        file open `fh' using "`out'", write text replace
        if "`ext'" == "md" {
            file write `fh' ("# surveymap: `jname' - mermaid flow, LR") _n _n
            file write `fh' ("Items run left to right in questionnaire ") ///
                ("order; a gate fans the sample into lanes that rejoin ") ///
                ("the spine at the end of its segment. A dashed node is ") ///
                ("a cell the lane was routed around. ") ///
                (char(96) + "!!" + char(96)) ///
                (" marks a warning.") _n _n
            file write `fh' ("*`prov'*") _n _n
            * fence backticks are written with char(96): a backtick held in
            * a macro is re-scanned by the macro expander (TRAPS 8)
            file write `fh' (char(96) + char(96) + char(96) + "mermaid") _n
        }
        * theme "base" plus explicit theme variables, so the diagram looks
        * the same on GitHub, in mermaid.live, in Quarto and in VS Code
        local tv "'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'14px'"
        local tv "`tv','primaryColor':'#ffffff','primaryTextColor':'#202020'"
        local tv "`tv','primaryBorderColor':'#606060','lineColor':'#606060'"
        local tv "`tv','secondaryColor':'#f4f4f4','tertiaryColor':'#fafafa'"
        local tv "`tv','edgeLabelBackground':'#ffffff','titleColor':'#202020'"
        file write `fh' ("%%{init: {'theme':'base','themeVariables':{`tv'}}}%%") _n
        file write `fh' ("%% `prov'") _n
        file write `fh' ("flowchart LR") _n
        file write `fh' ("  accTitle: `acct'") _n
        file write `fh' ("  accDescr {") _n
        file write `fh' ("    `accd'") _n
        file write `fh' ("  }") _n
        file write `fh' ("  classDef default fill:#ffffff,stroke:#606060,") ///
            ("color:#202020;") _n
        file write `fh' ("  classDef smghost fill:#ffffff,stroke:#909090,") ///
            ("stroke-dasharray: 5 4,color:#707070;") _n
        file write `fh' ("  classDef smwarn fill:#ffffff,stroke:#4a6d8c,") ///
            ("stroke-width:2.5px,color:#202020;") _n
        forvalues i = 1/`nnd' {
            file write `fh' (subinstr(`"`nd`i''"', char(2), char(36), .)) _n
        }
        forvalues i = 1/`ned' {
            file write `fh' (subinstr(`"`ed`i''"', char(2), char(36), .)) _n
        }
        if "`ghosts'" != "" file write `fh' ("  class `ghosts' smghost;") _n
        if "`warns'"  != "" file write `fh' ("  class `warns' smwarn;") _n
        if "`ext'" == "md" {
            file write `fh' (char(96) + char(96) + char(96)) _n
        }
        file close `fh'
        local written "`written' `out'"
    }

    display as text "_sm_rendertext: `jname' -> " as result trim("`written'")
end

* comma-format a count string ("." or "" -> empty) -> s(o)
program define _srt_n, sclass
    args s
    if `"`s'"' == "." | `"`s'"' == "" sreturn local o ""
    else sreturn local o = trim(string(real(`"`s'"'), "%20.0fc"))
end
