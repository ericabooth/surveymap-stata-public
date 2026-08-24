*! version 0.4.1  24aug2026  Eric Booth
*! _sm_rendertw : draw a surveymap journal (schema v2) as a native twoway
*!            boxes-and-arrows figure, for a paper or a slide
*!
*! syntax:  _sm_rendertw using <journal.tsv>, saving(stub)
*!              [maxnodes(#) name(text) noprovenance]
*!
*! Writes <stub>.png (width 2000) and <stub>.svg from one twoway call: boxes
*! from pci segments, arrows from pcarrowi, labels from text().  Items run
*! left to right; a gate fans the sample into lanes that rejoin the spine,
*! and a cell the lane was routed around is drawn dashed and grey.
*!
*! Monochrome, with one accent colour (#4a6d8c, written as the RGB triplet
*! 74 109 140 so it is valid at the Stata 16 floor) used only for "!!" flag
*! text.  Severity is never colour alone.
*!
*! A figure is only readable up to a point.  Past maxnodes() drawn columns
*! this refuses and names the HTML page instead, which scrolls and carries
*! the full record on hover.  Reads the journal BY COLUMN NAME and tolerates
*! unknown trailing columns.

program define _sm_rendertw
    version 16
    syntax using/, SAVing(string) [MAXnodes(integer 14) NAME(string) ///
        noPROVenance replace]

    * forgive a pasted extension on the stub
    foreach e in .png .svg {
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

    * does this journal carry weighted counts?  If it does, the drawing
    * reports the survey convention: unweighted counts, weighted percentages.
    local haswt = 0
    frame `J' {
        capture confirm variable pct_answered_w
        if !_rc {
            quietly count if class == "item" & pct_answered_w != "." & ///
                pct_answered_w != ""
            local haswt = (r(N) > 0)
        }
    }

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
        if `haswt' {
            frame `J': local pw = pct_answered_w[`i']
            if "`pw'" != "." & "`pw'" != "" local pa_`p' "`pw'"
        }
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
        if `haswt' {
            frame `J': local rw = pct_answered_w[`i']
            if "`rw'" != "." & "`rw'" != "" local cR_`gp'_`kk'_`wp' "`rw'"
        }
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


    frame drop `J'

    * ---- how many columns will be drawn? ------------------------------
    * a fan collapses its whole segment into one column of lanes, so the
    * drawn width is not the item count
    local ncol = 0
    local p = 1
    while `p' <= `K' {
        local ++ncol
        if "`fanat_`p''" != "" {
            local gp = `fanat_`p''
            local p = `segend_`gp'' + 1
        }
        else local ++p
    }
    if `ncol' > `maxnodes' {
        display as error "_sm_rendertw: `ncol' drawn columns is past maxnodes(`maxnodes')"
        display as error "    A figure this wide is not readable. Draw fewer items with a"
        display as error "    varlist or exclude(), or use export(html), which scrolls and"
        display as error "    carries the full record on hover."
        exit 134
    }

    * ---- geometry -----------------------------------------------------
    local BW  9        // box width
    local BH  3.2      // box height
    local GAP 3.6      // gap between columns
    local LGAP 1.4     // gap between lanes
    local ACC "74 109 140"

    * the tallest fan decides the figure height
    local maxL = 1
    forvalues p = 1/`K' {
        if "`fanat_`p''" != "" {
            local gp = `fanat_`p''
            local maxL = max(`maxL', `L_`gp'')
        }
    }
    local blkh = `maxL' * (`BH' + `LGAP') - `LGAP'
    local half = max(`BH' / 2 + 2.2, `blkh' / 2 + 3.4)
    local Y0 = 0

    local boxsegs ""
    local dashsegs ""
    local arrs ""
    local txts ""
    local x = 2

    * ---- walk the columns ---------------------------------------------
    local prevx = .
    local p = 1
    while `p' <= `K' {
        if "`fanat_`p''" != "" {
            * ---- a gate's lanes open here ----
            local gp = `fanat_`p''
            local pe = `segend_`gp''
            local L = `L_`gp''
            local btop = `Y0' + `blkh' / 2
            local srcx = cond(`prevx' == ., `x' - `GAP', `prevx')
            * name the split above the block
            local yh = `btop' + 2.2
            local txts `"`txts' text(`yh' `x' "{bf:split by `v_`gp''}", size(@SZH@) color(gs4) placement(e))"'
            forvalues k = 1/`L' {
                local lt = `btop' - (`k' - 1) * (`BH' + `LGAP')
                local lb = `lt' - `BH'
                local lcy = (`lt' + `lb') / 2
                * fan connector from the spine into the lane
                local arrs `"`arrs' `Y0' `srcx' `lcy' `= `x' - 0.4'"'
                * lane label above its first box
                _srw_n `"`ln_`gp'_`k''"'
                local lnf `"`s(o)'"'
                _srw_ell 22 `"`ll_`gp'_`k''"'
                local txts `"`txts' text(`= `lt' + 0.9' `x' `"`s(o)' `=uchar(183)' `lnf'"', size(@SZL@) color(gs5) placement(e))"'
                * the lane's cells
                local cx = `x'
                local pcx = .
                forvalues q = `p'/`pe' {
                    if `"`cS_`gp'_`k'_`q''"' == "" continue
                    local st `"`cS_`gp'_`k'_`q''"'
                    local xr = `cx' + `BW'
                    if `pcx' != . local arrs `"`arrs' `lcy' `pcx' `lcy' `= `cx' - 0.4'"'
                    if `"`st'"' == "skipped" {
                        local dashsegs `"`dashsegs' `lt' `cx' `lt' `xr' `lb' `cx' `lb' `xr' `lt' `cx' `lb' `cx' `lt' `xr' `lb' `xr'"'
                        _srw_ell 15 `"`v_`q''"'
                        local txts `"`txts' text(`= `lt' - 1.0' `= `cx' + 0.5' `"`s(o)'"', size(@SZ@) color(gs8) placement(e))"'
                        local txts `"`txts' text(`= `lt' - 2.2' `= `cx' + 0.5' "skipped `=uchar(183)' routed around", size(@SZS@) color(gs8) placement(e))"'
                    }
                    else {
                        local boxsegs `"`boxsegs' `lt' `cx' `lt' `xr' `lb' `cx' `lb' `xr' `lt' `cx' `lb' `cx' `lt' `xr' `lb' `xr'"'
                        _srw_ell 15 `"`v_`q''"'
                        local txts `"`txts' text(`= `lt' - 1.0' `= `cx' + 0.5' `"{bf:`s(o)'}"', size(@SZ@) color(black) placement(e))"'
                        _srw_n `"`cN_`gp'_`k'_`q''"'
                        local txts `"`txts' text(`= `lt' - 2.2' `= `cx' + 0.5' "`s(o)' (`cR_`gp'_`k'_`q''%)", size(@SZS@) color(gs4) placement(e))"'
                    }
                    local pcx = `xr'
                    local cx = `xr' + `GAP'
                }
                * merge back to the spine
                local jx = `x' + (`pe' - `p' + 1) * (`BW' + `GAP') - `GAP' + 1.6
                if `pcx' == . local pcx = `x'
                local arrs `"`arrs' `lcy' `pcx' `Y0' `= `jx' - 0.3'"'
            }
            local x = `x' + (`pe' - `p' + 1) * (`BW' + `GAP') + 1.6
            local prevx = `x' - `GAP' + 0.6
            local p = `pe' + 1
            continue
        }

        * ---- a plain spine box ----
        local bt = `Y0' + `BH' / 2
        local bb = `Y0' - `BH' / 2
        local xr = `x' + `BW'
        if `prevx' != . local arrs `"`arrs' `Y0' `prevx' `Y0' `= `x' - 0.4'"'
        local boxsegs `"`boxsegs' `bt' `x' `bt' `xr' `bb' `x' `bb' `xr' `bt' `x' `bb' `x' `bt' `xr' `bb' `xr'"'
        _srw_ell 15 `"`v_`p''"'
        local txts `"`txts' text(`= `bt' - 1.0' `= `x' + 0.5' `"{bf:`s(o)'}"', size(@SZ@) color(black) placement(e))"'
        _srw_n `"`nn_`p''"'
        local txts `"`txts' text(`= `bt' - 2.2' `= `x' + 0.5' "`s(o)' (`pa_`p''%)", size(@SZS@) color(gs4) placement(e))"'
        * a lot of declined answers is worth a flag, in text and never colour alone
        local rr = real(`"`nr_`p''"')
        local aa = real(`"`nn_`p''"')
        if `rr' < . & `aa' < . & `aa' > 0 {
            if `rr' > 0.05 * `aa' {
                _srw_n `"`nr_`p''"'
                local txts `"`txts' text(`= `bb' + 0.6' `= `x' + 0.5' "{bf:!! nonresp `s(o)'}", size(@SZS@) color("`ACC'") placement(e))"'
            }
        }
        local prevx = `xr'
        local x = `xr' + `GAP'
        local ++p
    }

    * ---- caption and provenance ---------------------------------------
    local jname = substr("`using'", ///
        cond(max(strrpos("`using'", "/"), strrpos("`using'", char(92))) > 0, ///
        max(strrpos("`using'", "/"), strrpos("`using'", char(92))) + 1, 1), .)
    if `"`name'"' != "" local jname `"`name'"'
    _srw_n `"`NN'"'
    local nnf `"`s(o)'"'
    local iw = cond(`K' == 1, "item", "items")
    local gw = cond(`G' == 1, "gate", "gates")
    local cap "survey: `jname'  `=uchar(183)'  `nnf' respondents  `=uchar(183)'  `K' `iw'  `=uchar(183)'  `G' `gw'"
    if `haswt' local cap "`cap'  `=uchar(183)'  counts unweighted, percentages weighted"
    local ytop = `Y0' + `half'
    local txts `"`txts' text(`= `ytop' - 0.4' 2 "`cap'", size(@SZC@) color(gs6) placement(e))"'

    local ybot = `Y0' - `half'
    if "`provenance'" != "noprovenance" {
        local flav = cond(c(MP) == 1, "MP", cond(c(SE) == 1, "SE", c(flavor)))
        local prov "surveymap `=uchar(183)' `c(current_date)' `=uchar(183)' Stata `c(stata_version)' `flav'"
        local txts `"`txts' text(`= `ybot' + 0.5' 2 "`prov'", size(@SZP@) color(gs10) placement(e))"'
    }

    * ---- one twoway call ----------------------------------------------
    local W = `x'
    local plots `"(scatteri `ybot' 0 `ytop' `W', msymbol(none))"'
    if `"`boxsegs'"' != "" {
        local plots `"`plots' (pci `boxsegs', lcolor(black) lwidth(medthin))"'
    }
    if `"`dashsegs'"' != "" {
        local plots `"`plots' (pci `dashsegs', lcolor(gs9) lwidth(thin) lpattern(dash))"'
    }
    if `"`arrs'"' != "" {
        local plots `"`plots' (pcarrowi `arrs', lcolor(gs4) mcolor(gs4) lwidth(thin) msize(1.1) mlwidth(thin))"'
    }

    * text sizes scale with the figure, so a wide figure keeps its labels legible
    local xsize = min(24, max(7, `W' / 7))
    local ysize = max(3, (`ytop' - `ybot') / 7)
    local sz    = 2.0 * (7 / `xsize') * 1.6
    if `sz' > 3.2 local sz = 3.2
    if `sz' < 1.1 local sz = 1.1
    local txts : subinstr local txts "@SZ@"  "`sz'", all
    local txts : subinstr local txts "@SZS@" "`= `sz' * 0.88'", all
    local txts : subinstr local txts "@SZL@" "`= `sz' * 0.85'", all
    local txts : subinstr local txts "@SZH@" "`= `sz' * 0.95'", all
    local txts : subinstr local txts "@SZC@" "`= `sz' * 0.9'", all
    local txts : subinstr local txts "@SZP@" "`= `sz' * 0.72'", all

    capture confirm file `"`saving'.png"'
    if !_rc & "`replace'" == "" {
        display as error "file `saving'.png already exists; specify replace"
        exit 602
    }

    twoway `plots', `txts'                                    ///
        yscale(off) xscale(off)                               ///
        ylabel(none, nogrid) xlabel(none, nogrid)             ///
        legend(off) graphregion(color(white))                 ///
        plotregion(margin(zero) style(none))                  ///
        scheme(s1color)                                       ///
        xsize(`xsize') ysize(`ysize') name(_srw, replace)

    qui graph export `"`saving'.png"', width(2000) replace
    qui graph export `"`saving'.svg"', replace
    graph drop _srw

    display as text "_sm_rendertw: wrote " as result "`saving'.png" ///
        as text " and " as result "`saving'.svg" as text " (`ncol' columns)"
end


* ---------------------------------------------------------------- helpers

* comma-format a count string ("." or "" -> empty) -> s(o)
program define _srw_n, sclass
    args t
    if "`t'" == "." | "`t'" == "" sreturn local o ""
    else sreturn local o = trim(string(real("`t'"), "%20.0fc"))
end

* trim to maxlen with a middle ellipsis, only when it overflows -> s(o)
program define _srw_ell, sclass
    args maxlen t
    if strlen(`"`t'"') <= `maxlen' {
        sreturn local o `"`t'"'
        exit
    }
    local h1 = floor((`maxlen' - 1) / 2)
    local h2 = `maxlen' - 1 - `h1'
    sreturn local o = substr(`"`t'"', 1, `h1') + "~" + substr(`"`t'"', -`h2', .)
end
