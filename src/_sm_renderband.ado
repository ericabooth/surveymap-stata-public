*! version 0.5.0  27aug2026  Eric Booth
*! _sm_renderband -- the status band chart (chronogram) of a surveymap journal.
*!
*! One thin column per item, in questionnaire order, each split into answered
*! / declined / not shown and stacking to 100% of the scope.  It is TraMineR's
*! state-distribution plot (seqdplot) drawn in base Stata, and it exists
*! because the flow map has a node budget and this has none: a 230-item
*! instrument gets no readable flow map, and still gets this.
*!
*! The map answers "who was asked what".  This answers "where does the
*! instrument leak", which is the question a long questionnaire actually
*! raises and the one the map cannot fit on a page.
*!
*! syntax: _sm_renderband using journal.tsv [, saving() title() ... ]
*!
*! Every column is drawn from the three counts the journal carries, never
*! from a hard-coded 100, so a journal whose counts do not partition the
*! scope draws a short column instead of quietly lying about it.  r(devmax)
*! reports the largest such gap and the program prints it.


program define _sm_renderband, rclass
    version 16

    syntax using/ [,                                                        ///
        SAVing(string)  TItle(string)  SUBtitle(string)                     ///
        NOTe(string) NAMEs(string) NNames(integer 6)                        ///
        XSIze(real 0) YSIze(real 0) EVery(integer 0) NAMEMax(integer 16)    ///
        BARwidth(real 0) AREA BAR AREAMin(integer 60) SCale(real 0)         ///
        WIDthpx(integer 2400) NOLEGend NAme(string) REPLACE ]

    * every other surveymap subcommand takes replace, so this one does
    * too.  graph export overwrites either way; without the option the
    * command simply rejected a word the rest of the package accepts.

    confirm file `"`using'"'

    tempname F
    capture frame drop `F'
    frame create `F'

    frame `F' {

    quietly import delimited using `"`using'"', delimiter(tab) ///
        varnames(1) stringcols(_all) encoding("utf-8") clear

    foreach v in class var position n_asked n_answered n_nonresp n_sysmiss {
        capture confirm variable `v'
        if _rc {
            di as err "smband: `using' is not a surveymap journal (no `v' column)"
            exit 459
        }
    }

    * ---- scope N from the survey row ------------------------------------
    quietly count if class == "survey"
    if r(N) != 1 {
        di as err "smband: expected exactly one survey row, found " r(N)
        exit 459
    }
    quietly levelsof n_asked if class == "survey", local(Nscope) clean
    local Nscope = real("`Nscope'")
    if missing(`Nscope') | `Nscope' <= 0 {
        di as err "smband: the survey row of `using' has no usable n_asked"
        exit 459
    }

    * ---- item rows only --------------------------------------------------
    quietly keep if class == "item"
    quietly count
    local nit = r(N)
    if `nit' == 0 {
        di as err "smband: no item rows in `using'"
        exit 459
    }

    foreach v in position n_asked n_answered n_nonresp n_sysmiss {
        quietly destring `v', replace force
    }
    sort position
    quietly replace position = _n if missing(position)

    * =====================================================================
    * ARITHMETIC CHECK: the three statuses must partition the scope N
    * =====================================================================
    quietly gen double _tot = n_answered + n_nonresp + n_sysmiss
    quietly gen double _dev = _tot - `Nscope'
    quietly summarize _dev, meanonly
    local devmax = max(abs(r(min)), abs(r(max)))
    quietly count if abs(_dev) > 1e-6
    local nbad = r(N)

    * denominator: the scope N when it checks out, else each item's own total
    if `nbad' == 0 {
        quietly gen double _den = `Nscope'
        local denword "the N = `: display %9.0fc `Nscope'' respondents in scope"
        local denword = stritrim("`denword'")
    }
    else {
        quietly gen double _den = _tot
        local denword "each item's own answered + declined + not-shown total"
        di as err "smband: WARNING -- " `nbad' " of `nit' items do not sum to the scope N"
        di as err "        (max deviation " `devmax' " respondents); bands are drawn"
        di as err "        over each item's own total instead."
    }
    quietly count if _den <= 0
    if r(N) {
        di as err "smband: `r(N)' item(s) have a zero denominator; cannot draw"
        exit 459
    }

    quietly gen double pa = 100 * n_answered / _den
    quietly gen double pd = 100 * n_nonresp  / _den
    quietly gen double pn = 100 * n_sysmiss  / _den
    quietly gen double c0 = 0
    quietly gen double c1 = pa
    quietly gen double c2 = pa + pd
    quietly gen double c3 = pa + pd + pn

    quietly gen double _top = c3 - 100
    quietly summarize _top, meanonly
    local topmax = max(abs(r(min)), abs(r(max)))

    di as txt "{hline 62}"
    di as txt "smband stacking check: " as res "`nit'" as txt " items, scope N = " as res "`Nscope'"
    di as txt "  max |answered+declined+notshown - N| = " as res %12.0g `devmax' as txt " respondents"
    di as txt "  items off by more than 1e-6          = " as res `nbad'
    di as txt "  max |top of stack - 100%|            = " as res %12.0g `topmax' as txt " pp"
    di as txt "{hline 62}"

    return scalar nitems  = `nit'
    return scalar N       = `Nscope'
    return scalar devmax  = `devmax'
    return scalar nbad    = `nbad'
    return scalar topmax  = `topmax'

    * =====================================================================
    * x axis: numeric ticks
    * =====================================================================
    if `every' <= 0 {
        local every 1
        foreach k in 1 2 5 10 20 25 50 100 200 {
            if `nit'/`k' >= 8 local every `k'
        }
    }
    local xl ""
    if `nit' <= `namemax' & `"`names'"' == "" {
        * short survey: name every item on the main axis, and skip the top one
        forvalues i = 1/`nit' {
            local vn = var[`i']
            local pp = position[`i']
            local xl `"`xl' `pp' "`vn'""'
        }
        local xlopt `"xlabel(`xl', angle(90) labsize(*.75) tlength(*.5))"'
        local names "none"
    }
    else {
        local j = `every'
        local xl "1"
        while `j' <= `nit' {
            local xl "`xl' `j'"
            local j = `j' + `every'
        }
        local xlopt `"xlabel(`xl', labsize(*.8) tlength(*.5))"'
    }

    * =====================================================================
    * a few named items on a second (top) x axis
    * =====================================================================
    local x2opt ""
    local ax2 ""
    if `"`names'"' == "" & `nit' > `namemax' local names "auto"
    if `"`names'"' == "none" local names ""

    if `"`names'"' != "" {
        quietly gen byte _pick = 0
        * two rotated labels closer together than this would collide
        local gapmin = max(1, ceil(`nit'/25))

        if `"`names'"' == "auto" {
            * landmarks: the first item, and the items where the not-shown
            * share jumps -- that is exactly where the routing changes
            quietly gen double _jump = abs(pn - pn[_n-1])
            quietly replace _jump = 100 in 1
            local m = min(`nnames', `nit')
            forvalues i = 1/`m' {
                quietly summarize _jump, meanonly
                if r(max) <= 2 continue, break
                gsort -_jump position
                local bp = position[1]
                quietly replace _pick = 1 if position == `bp'
                * knock out this pick and its neighbours so labels do not
                * pile up on one another
                quietly replace _jump = -1 if abs(position - `bp') < `gapmin'
                sort position
            }
        }
        else {
            foreach t of local names {
                capture confirm number `t'
                if !_rc quietly replace _pick = 1 if position == `t'
                else    quietly replace _pick = 1 if var == "`t'"
            }
        }

        local x2 ""
        quietly count if _pick == 1
        local npick = r(N)
        if `npick' > 0 {
            sort position
            forvalues i = 1/`nit' {
                if _pick[`i'] == 1 {
                    local vn = var[`i']
                    local pp = position[`i']
                    local x2 `"`x2' `pp' "`vn'""'
                }
            }
            local ax2 "xaxis(1 2)"
            local x2opt `"xlabel(`x2', axis(2) angle(90) labsize(*.7) tlength(*1.4)) xtitle("", axis(2))"'
        }
    }

    * =====================================================================
    * sizes
    * =====================================================================
    if `xsize' <= 0 {
        if      `nit' <= 12 local xsize 6.5
        else if `nit' <= 40 local xsize 8.0
        else                local xsize 9.0
    }
    if `ysize' <= 0 local ysize 4.0

    * Stata sizes graph text relative to the graph's HEIGHT, so a short strip
    * silently shrinks every label.  scale() can push the text back up, but
    * only so far: past about scale(1.6) the labels eat the plot region.  The
    * default leaves Stata's own sizing alone and warns instead.
    if `scale' <= 0 local scale = 1
    if `ysize' < 3 & `scale' == 1 {
        di as txt "smband: note -- at ysize(`ysize') Stata's default axis text" ///
                  " is under 5pt at print size;"
        di as txt "        raise ysize() or try scale(1.2)-scale(1.5)."
    }

    * ---- discrete columns, or the same step function as a solid band ----
    if "`area'" != "" & "`bar'" != "" {
        di as err "smband: area and bar cannot both be specified"
        exit 198
    }
    if "`area'" == "" & "`bar'" == "" & `nit' > `areamin' local area "area"

    if `barwidth' <= 0 {
        if "`area'" != ""            local barwidth = 1
        else if `nit' <= `namemax'   local barwidth = .88
        else                         local barwidth = 1
    }
    if "`area'" != "" & `barwidth' != 1 {
        di as txt "smband: area mode forces barwidth(1) so the polygon is a" ///
                  " true step function"
        local barwidth = 1
    }

    if `"`title'"'    == "" local title "Item status by questionnaire position"
    if `"`subtitle'"' == "" local subtitle ""
    if `"`note'"' == "" {
        if "`area'" == "" local unit "Each column is one item."
        else              local unit "One column of the band per item, in questionnaire order."
        local note "`unit' Bands are shares of `denword'; every column sums to 100%. Source: `using'."
    }

    local leg `"legend(order(1 "Answered" 2 "Declined" 3 "Not shown") rows(1) pos(6) region(lwidth(none)) size(*.85) symxsize(*.5) symysize(*.5))"'
    if "`legend'" == "nolegend" local leg "legend(off)"

    local gname ""
    if `"`name'"' != "" local gname `"name(`name', replace)"'

    quietly summarize position, meanonly
    local xmin = r(min) - 0.5
    local xmax = r(max) + 0.5
    local xsc `"xscale(range(`xmin' `xmax'))"'
    if "`ax2'" != "" ///
        local xsc `"`xsc' xscale(axis(2) range(`xmin' `xmax') lstyle(none))"'

    * ---- the three stacked layers ---------------------------------------
    * rbar  = one discrete column per item (the default)
    * rarea = the same step function drawn as a solid polygon, which
    *         avoids the hairline seams rbar leaves between columns when
    *         there are more columns than the raster has pixels
    if "`area'" == "" {
        local L1 `"(rbar c0 c1 position, barwidth(`barwidth') bcolor(gs14) blwidth(none) fintensity(100) `ax2')"'
        local L2 `"(rbar c1 c2 position, barwidth(`barwidth') bcolor(gs9)  blwidth(none) fintensity(100))"'
        local L3 `"(rbar c2 c3 position, barwidth(`barwidth') bcolor(gs3)  blwidth(none) fintensity(100))"'
    }
    else {
        * two x points per item, at the column's left and right edge
        local hw = `barwidth'/2
        quietly expand 2
        sort position
        quietly by position: gen double _x = position - `hw' + 2*`hw'*(_n-1)
        sort _x
        local L1 `"(rarea c0 c1 _x, fcolor(gs14) lwidth(none) fintensity(100) `ax2')"'
        local L2 `"(rarea c1 c2 _x, fcolor(gs9)  lwidth(none) fintensity(100))"'
        local L3 `"(rarea c2 c3 _x, fcolor(gs3)  lwidth(none) fintensity(100))"'
    }

    twoway `L1' `L2' `L3'                                                 ///
      , `xlopt' `x2opt'                                                   ///
        `xsc'                                                             ///
        ylabel(0(25)100, angle(0) labsize(*.85) format(%3.0f))            ///
        yscale(range(0 100))                                              ///
        ytitle("Share of respondents (%)", size(*.9))                     ///
        xtitle("Item position in questionnaire order", size(*.9))         ///
        title("`title'", size(*.95) span pos(11) margin(b=3))             ///
        subtitle("`subtitle'", size(*.75) span pos(11))                   ///
        note("`note'", size(*.6) span)                                    ///
        `leg'                                                             ///
        graphregion(color(white) margin(l=2 r=4))                         ///
        plotregion(margin(zero) lcolor(gs8) lwidth(thin))                 ///
        xsize(`xsize') ysize(`ysize') scale(`scale') `gname'

    if `"`saving'"' != "" {
        local dot = strrpos(`"`saving'"', ".")
        local sfx = ""
        if `dot' > 0 local sfx = lower(substr(`"`saving'"', `dot'+1, .))
        local wopt ""
        if inlist("`sfx'", "png", "tif", "tiff", "gif", "jpg", "jpeg") ///
            local wopt "width(`widthpx')"
        graph export `"`saving'"', replace `wopt'
        di as txt "smband: wrote " as res `"`saving'"' as txt               ///
            " at xsize(`xsize') ysize(`ysize') in, scale(`scale') `wopt'"
    }
    return local xsize "`xsize'"
    return local ysize "`ysize'"
    return local scale "`scale'"

    }
    frame drop `F'
end

* ---------------------------------------------------------------------------
* Example: build a journal, then draw it
*
*   surveymap demo d, replace
*   use d/demo_survey.dta, clear
*   surveymap, out(j.tsv) replace noreceipt
*   do smband.do
*   smband using "j.tsv", saving("fig.png") title("Demo survey")
* ---------------------------------------------------------------------------