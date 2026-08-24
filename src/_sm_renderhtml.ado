*! version 0.3.0  24aug2026  Eric Booth
*! _sm_renderhtml -- render a surveymap journal (TSV, 20 columns) as HTML
*! with one inline SVG flow map.
*!
*! syntax: _sm_renderhtml using journal.tsv, saving(x.html)
*!         [name(string) embed noheader replace accent(hex)]
*!
*! Layout is horizontal, left to right: items are columns in position order.
*! An ungated stretch is one row of item boxes on the spine.  At a gate the
*! flow fans out into one lane per cat row of the (already pruned) journal --
*! kept categories + other + noanswer -- each lane crossing the gate's
*! segment cell by cell, and the lanes merge at a join point before the next
*! stretch.  A cell the lane was routed around draws as a dashed grey ghost
*! box.  Width grows with items; the page scrolls sideways (.sm-wrap is
*! overflow-x auto), and lane rows stack vertically, so total height follows
*! the widest gate.
*!
*! Two output shapes:
*!   page  (default) a self-contained document; the map runs full height
*!   embed (option)  a FRAGMENT for pasting into a host report: one scoped
*!                   <style>, one <div class="sm-embed ...">, one <svg> with
*!                   a viewBox and no width/height.  Every class is prefixed
*!                   sm-, every id is namespaced per diagram, and the
*!                   stylesheet contains NO element selectors, so the host
*!                   page is untouched.  The map sits in a bounded resizable
*!                   box; the print query lifts the cap.
*! No external assets, no JavaScript: opens offline at file://.
*! Accent #4a6d8c appears only on "!!" text and arrowheads, never alone.
*!
*! Marker control chars used internally (mapped to XML entities on write):
*!   char(1)=ellipsis char(3)=middot char(6)=backtick char(7)=dollar
*!   char(16)=amp char(17)=lt char(18)=gt char(19)=doublequote

program define _sm_renderhtml
    version 16
    syntax using/, SAVing(string) [NAME(string) EMBed NOHEADer REPLACE ///
        ACCent(string) LAYout(string)]

    * A questionnaire is a sequence, so it reads either way.  Left to right
    * suits a slide and a wide screen; top to bottom suits a report page,
    * because a page scrolls down and a long instrument is taller than any
    * screen is wide.
    if `"`layout'"' == "" local layout "horizontal"
    local layout = strlower(`"`layout'"')
    if inlist("`layout'", "h", "horiz", "lr") local layout "horizontal"
    if inlist("`layout'", "v", "vert", "tb", "td") local layout "vertical"
    if !inlist("`layout'", "horizontal", "vertical") {
        display as error "layout() must be horizontal or vertical"
        exit 198
    }
    local vert = ("`layout'" == "vertical")

    * ------------------------------------------------ options
    if "`accent'" == "" local accent "#4a6d8c"
    if substr("`accent'",1,1) != "#" local accent "#`accent'"
    if !ustrregexm(lower("`accent'"), "^#[0-9a-f]{6}$") {
        display as error "accent() must be a 6-digit hex color, e.g. accent(4a6d8c)"
        exit 198
    }
    local out "`saving'"
    if !strmatch(lower("`out'"), "*.html") & !strmatch(lower("`out'"), "*.htm") {
        local out "`out'.html"
    }
    capture confirm file "`out'"
    if !_rc & "`replace'" == "" {
        display as error "file `out' already exists; specify replace"
        exit 602
    }

    * ------------------------------------------------ per-diagram id namespace
    * ids and the CSS scope class both live under this prefix, so two diagrams
    * on one page never share an arrowhead marker or a style rule
    local stem = substr("`out'", strrpos(subinstr("`out'","\","/",.), "/") + 1, .)
    local stem = subinstr("`stem'", ".html", "", .)
    local stem = subinstr("`stem'", ".htm",  "", .)
    _srh_slug `"sm-`stem'"'
    local pfx `"`s(o)'"'

    * ------------------------------------------------ load journal into a frame
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
        * required core, read BY NAME; tolerate absent columns and unknown
        * trailing columns (JOURNAL_SCHEMA.md)
        foreach v in seq class var position vallabel value gatevar n_asked ///
            n_answered n_nonresp n_sysmiss pct_answered rate status gate  ///
            gated_by pooled type severity flags {
            capture confirm variable `v'
            if _rc quietly generate str1 `v' = "."
            quietly replace `v' = "." if `v' == ""
        }
        * neutralize macro-hostile and XML-special chars IN THE DATA before
        * any value passes through a macro (TRAPS 1): backtick contents are
        * re-expanded on macro dereference; & < > break XML; a double quote
        * can close a compound quote early
        foreach v in class var vallabel value gatevar status gate gated_by ///
            pooled type severity flags {
            quietly replace `v' = subinstr(`v', "&",      char(16), .)
            quietly replace `v' = subinstr(`v', "<",      char(17), .)
            quietly replace `v' = subinstr(`v', ">",      char(18), .)
            quietly replace `v' = subinstr(`v', char(96), char(6),  .)
            quietly replace `v' = subinstr(`v', char(36), char(7),  .)
            quietly replace `v' = subinstr(`v', char(34), char(19), .)
        }
    }
    frame `J': local NR = _N

    * does this journal carry weighted counts?
    local haswt = 0
    frame `J' {
        capture confirm variable pct_answered_w
        if !_rc {
            quietly count if class == "item" & pct_answered_w != "." & ///
                pct_answered_w != ""
            local haswt = (r(N) > 0)
        }
    }

    * ------------------------------------------------ survey + item index
    * items are indexed by position (1..K, contiguous by schema)
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
        frame `J': local lb_`p' = vallabel[`i']
        frame `J': local na_`p' = n_asked[`i']
        frame `J': local nn_`p' = n_answered[`i']
        frame `J': local nr_`p' = n_nonresp[`i']
        frame `J': local ns_`p' = n_sysmiss[`i']
        frame `J': local pa_`p' = pct_answered[`i']
        * A weighted journal is drawn the way survey results are normally
        * reported: the count is unweighted, because it describes the people
        * interviewed, and the percentage is weighted, because it describes the
        * estimate.  The caption says so, so nobody has to guess which is which.
        if `haswt' {
            frame `J': local pw = pct_answered_w[`i']
            if "`pw'" != "." & "`pw'" != "" local pa_`p' "`pw'"
        }
        frame `J': local g_`p'  = gate[`i']
        frame `J': local gb_`p' = gated_by[`i']
        frame `J': local ty_`p' = type[`i']
        frame `J': local fl_`p' = flags[`i']
    }
    if `K' == 0 {
        frame drop `J'
        display as error "`using' has no item rows; nothing to draw"
        exit 459
    }
    forvalues p = 1/`K' {
        if `"`v_`p''"' == "" {
            frame drop `J'
            display as error "journal item positions are not contiguous (position `p' missing)"
            exit 459
        }
    }
    local G = 0
    forvalues p = 1/`K' {
        if "`g_`p''" == "1" local ++G
        local L_`p' = 0
    }

    * ------------------------------------------------ lanes per gate
    * cat rows in journal order; other and noanswer forced to the last lanes
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
        frame `J': local lp = pct_answered[`i']
        if `"`vv'"' == "noanswer" {
            local hasna_`gp' = 1
            local nal_`gp' `"`ll'"'
            local nan_`gp' `"`ln'"'
            local nap_`gp' `"`lp'"'
        }
        else if `"`vv'"' == "other" {
            local hasot_`gp' = 1
            local otl_`gp' `"`ll'"'
            local otn_`gp' `"`ln'"'
            local otp_`gp' `"`lp'"'
        }
        else {
            local k = `L_`gp'' + 1
            local L_`gp' = `k'
            local lv_`gp'_`k' `"`vv'"'
            local ll_`gp'_`k' `"`ll'"'
            local ln_`gp'_`k' `"`ln'"'
            local lp_`gp'_`k' `"`lp'"'
        }
    }
    forvalues p = 1/`K' {
        if "`hasot_`p''" == "1" {
            local k = `L_`p'' + 1
            local L_`p' = `k'
            local lv_`p'_`k' "other"
            local ll_`p'_`k' `"`otl_`p''"'
            local ln_`p'_`k' `"`otn_`p''"'
            local lp_`p'_`k' `"`otp_`p''"'
        }
        if "`hasna_`p''" == "1" {
            local k = `L_`p'' + 1
            local L_`p' = `k'
            local lv_`p'_`k' "noanswer"
            local ll_`p'_`k' `"`nal_`p''"'
            local ln_`p'_`k' `"`nan_`p''"'
            local lp_`p'_`k' `"`nap_`p''"'
        }
    }

    * ------------------------------------------------ cells + segment map
    * an item belongs to the segment of the gate its cell rows name; when two
    * gates claim one item (out-of-contract journal) the nearer gate wins
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
        frame `J': local cA_`gp'_`kk'_`wp' = n_asked[`i']
        frame `J': local cN_`gp'_`kk'_`wp' = n_answered[`i']
        frame `J': local cR_`gp'_`kk'_`wp' = rate[`i']
        * a weighted journal draws the weighted rate here too, so every
        * percentage on the page is on the same footing
        if `haswt' {
            frame `J': local rw = pct_answered_w[`i']
            if "`rw'" != "." & "`rw'" != "" local cR_`gp'_`kk'_`wp' "`rw'"
        }
        frame `J': local cS_`gp'_`kk'_`wp' = status[`i']
    }

    * ------------------------------------------------ geometry
    local XM   12
    local BW   176
    local GAP  56
    local LH   14
    local CH   54
    local LGAP 22
    local LBUD 25
    local HBUD 23
    forvalues p = 1/`K' {
        local colx_`p' = `XM' + (`p' - 1) * (`BW' + `GAP')
    }
    local svgw = `XM' + `K' * (`BW' + `GAP') - `GAP' + `XM'
    * uniform spine-box height: varname + wrapped label (1-2) + count + flag
    local maxnl = 3
    forvalues p = 1/`K' {
        _srh_wrapn `LBUD' 2 `"`lb_`p''"'
        local nlab_`p' = max(`s(n)', 1)
        forvalues j = 1/`nlab_`p'' {
            local lbl_`p'_`j' `"`s(l`j')'"'
        }
        if `nlab_`p'' == 0 {
            local nlab_`p' = 1
            local lbl_`p'_1 ""
        }
        local flag_`p' = 0
        local rr = real(`"`nr_`p''"')
        local aa = real(`"`na_`p''"')
        if `rr' < . & `aa' < . & `aa' > 0 {
            if `rr' > 0.05 * `aa' local flag_`p' = 1
        }
        local maxnl = max(`maxnl', 2 + `nlab_`p'' + `flag_`p'')
    }
    local SH = 14 * `maxnl' + 12
    * tallest lane block across gates that own a segment
    * A gate's segment is the run of items it owns, and that run does not
    * have to start in the column after the gate: a party question asked
    * early can own the primary-turnout items much later, and the lanes
    * belong where those items are.  fanat_ maps a column to the gate whose
    * lanes open there.
    local maxblk = 0
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
        if `ps' > 0 & `L_`p'' > 0 {
            local fanat_`ps' = `p'
            local maxblk = max(`maxblk', `L_`p'' * (`CH' + `LGAP') - `LGAP')
        }
    }
    * room above the top lane for its label and the block heading
    local half = max(`SH' / 2, `maxblk' / 2 + 34)
    local Y0 = 8 + `half'
    local svgh = `Y0' + `half' + 12

    * ---- vertical geometry: items down the page, lanes across it --------
    if `vert' {
        local GAPV = 82
        forvalues p = 1/`K' {
            local coly_`p' = 52 + (`p' - 1) * (`SH' + `GAPV')
        }
        local maxlan = 1
        forvalues p = 1/`K' {
            if "`fanat_`p''" != "" {
                local gp = `fanat_`p''
                local maxlan = max(`maxlan', `L_`gp'')
            }
        }
        local blkwmax = `maxlan' * (`BW' + `LGAP') - `LGAP'
        local svgw = max(`blkwmax', `BW') + 2 * `XM' + 24
        local XC = `svgw' / 2 - `BW' / 2
        local svgh = 52 + `K' * (`SH' + `GAPV') - `GAPV' + 46
    }

    * globals the writers read (dropped at the end)
    global SRH_ACC "`accent'"
    global SRH_PFX "`pfx'"

    * ------------------------------------------------ SVG body to a tempfile
    * (written first because the <svg> tag needs the finished extent)
    tempfile bodyf
    tempname B
    file open `B' using "`bodyf'", write text replace

    if `vert' {
    * ================================================ vertical body
    * The same drawing with the axes exchanged: items run down the page and a
    * gate spreads its lanes across it, so a lane is a column and the block is
    * as wide as the gate has lanes.
    local prevy = .
    local p = 1
    while `p' <= `K' {
        if "`fanat_`p''" != "" {
            local gp = `fanat_`p''
            local pe = `segend_`gp''
            local srcy = `prevy'
            if `srcy' == . local srcy = `coly_`p'' - `GAPV'
            local L = `L_`gp''
            local blkw = `L' * (`BW' + `LGAP') - `LGAP'
            local bleft = `XC' + `BW' / 2 - `blkw' / 2
            local y1 = `coly_`p''
            local cxs = `XC' + `BW' / 2
            file write `B' `"<g class="sm-node">"' _n
            file write `B' `"<title>"'
            _srh_wtip `B' lanes split by `v_`gp''
            _srh_wtip `B' `lb_`gp''
            file write `B' `"</title>"' _n
            _srh_wtext `B' `bleft' `=`y1'-66' lh `"split by `v_`gp''"'
            file write `B' `"</g>"' _n
            * one bus line for the whole fan, so no connector crosses a label
            local busy = `y1' - 20
            _srh_line `B' `cxs' `srcy' `cxs' `busy'
            local bl = `bleft' + `BW' / 2
            local br = `bleft' + (`L' - 1) * (`BW' + `LGAP') + `BW' / 2
            if `L' > 1 _srh_line `B' `bl' `busy' `br' `busy'
            local jy = `coly_`pe'' + `SH' + `GAPV' - 34
            forvalues k = 1/`L' {
                local lleft = `bleft' + (`k' - 1) * (`BW' + `LGAP')
                local lcx = `lleft' + `BW' / 2
                _srh_line `B' `lcx' `=`y1'-20' `lcx' `=`y1'-2'
                _srh_n `"`ln_`gp'_`k''"'
                local lnf `"`s(o)'"'
                * a lane label has one column's width to live in, so the
                * answer goes on one line and its size on the next
                _srh_mell 21 `"`ll_`gp'_`k''"'
                local lab1 `"`s(o)'"'
                local lab2 `"`lnf' (`lp_`gp'_`k''%)"'
                file write `B' `"<g class="sm-node">"' _n
                file write `B' `"<title>"'
                _srh_wtip `B' lane: `v_`gp'' == `lv_`gp'_`k''
                _srh_wtip `B' `ll_`gp'_`k''
                _srh_wtip `B' `lnf' respondents (`lp_`gp'_`k''% of scope)
                file write `B' `"</title>"' _n
                _srh_wtext `B' `lleft' `=`y1'-50' ll `"`lab1'"'
                _srh_wtext `B' `lleft' `=`y1'-36' ll `"`lab2'"'
                file write `B' `"</g>"' _n
                local pcy = .
                forvalues q = `p'/`pe' {
                    if `"`cS_`gp'_`k'_`q''"' == "" continue
                    local cy = `coly_`q''
                    if `pcy' != . _srh_line `B' `lcx' `pcy' `lcx' `=`cy'-2'
                    local st `"`cS_`gp'_`k'_`q''"'
                    _srh_n `"`cA_`gp'_`k'_`q''"'
                    local caf `"`s(o)'"'
                    _srh_n `"`cN_`gp'_`k'_`q''"'
                    local cnf `"`s(o)'"'
                    local crt `"`cR_`gp'_`k'_`q''"'
                    file write `B' `"<g class="sm-node">"' _n
                    file write `B' `"<title>"'
                    _srh_wtip `B' `v_`q'' `=char(3)' lane `v_`gp'' == `lv_`gp'_`k''
                    _srh_wtip `B' `lb_`q''
                    _srh_wtip `B' in lane `caf' `=char(3)' answered `cnf' (`crt'%)
                    _srh_wtip `B' status: `st'
                    if `"`st'"' == "skipped" _srh_wtip `B' routed around by skip logic
                    file write `B' `"</title>"' _n
                    _srh_mell `HBUD' `"`v_`q''"'
                    local wname `"`s(o)'"'
                    if `"`st'"' == "skipped" {
                        _srh_rect `B' `lleft' `cy' `BW' `CH' gx
                        _srh_wtext `B' `=`lleft'+8' `=`cy'+17' gt `"`wname'"'
                        _srh_wtext `B' `=`lleft'+8' `=`cy'+31' gt `"skipped `=char(3)' routed around"'
                    }
                    else if `"`st'"' == "partial" {
                        _srh_rect `B' `lleft' `cy' `BW' `CH' cx
                        _srh_wtext `B' `=`lleft'+8' `=`cy'+17' bh `"`wname'"'
                        _srh_wtext `B' `=`lleft'+8' `=`cy'+31' bn `"`cnf' answered"'
                        _srh_wtext `B' `=`lleft'+8' `=`cy'+45' bf `"!! partial `crt'%"'
                    }
                    else {
                        _srh_rect `B' `lleft' `cy' `BW' `CH' cx
                        _srh_wtext `B' `=`lleft'+8' `=`cy'+17' bh `"`wname'"'
                        _srh_wtext `B' `=`lleft'+8' `=`cy'+31' bn `"`cnf' (`crt'%)"'
                    }
                    file write `B' `"</g>"' _n
                    local pcy = `cy' + `CH'
                }
                if `pcy' == . local pcy = `busy'
                _srh_line `B' `lcx' `pcy' `lcx' `=`jy'-14'
                if `lcx' != `cxs' _srh_line `B' `lcx' `=`jy'-14' `cxs' `=`jy'-14'
            }
            _srh_line `B' `cxs' `=`jy'-14' `cxs' `=`jy'-1'
            file write `B' `"<circle cx="`cxs'" cy="`jy'" r="3.5" class="sm-jp" fill="#444444" />"' _n
            local prevy = `jy' + 4
            local p = `pe' + 1
            continue
        }
        local y = `coly_`p''
        local xl = `XC'
        local cxs = `XC' + `BW' / 2
        if `prevy' != . _srh_line `B' `cxs' `prevy' `cxs' `=`y'-2'
        file write `B' `"<g class="sm-node">"' _n
        file write `B' `"<title>"'
        _srh_wtip `B' `v_`p'' `=char(3)' item `p' of `K'
        _srh_wtip `B' `lb_`p''
        _srh_n `"`na_`p''"'
        local naf `"`s(o)'"'
        _srh_n `"`nn_`p''"'
        local nnf `"`s(o)'"'
        _srh_wtip `B' asked `naf' `=char(3)' answered `nnf' (`pa_`p''%)
        _srh_n `"`nr_`p''"'
        local a `"`s(o)'"'
        _srh_n `"`ns_`p''"'
        local b `"`s(o)'"'
        if "`a'" == "" local a "0"
        if "`b'" == "" local b "0"
        _srh_wtip `B' nonresponse `a' `=char(3)' system missing `b'
        if `"`ty_`p''"' != "." _srh_wtip `B' type `ty_`p''
        if "`g_`p''" == "1" _srh_wtip `B' gate: lanes split here
        if `"`gb_`p''"' != "." _srh_wtip `B' routed around for: `gb_`p''
        if `"`fl_`p''"' != "." & `"`fl_`p''"' != "" {
            local rest `"`fl_`p''"'
            while `"`rest'"' != "" {
                local q = strpos(`"`rest'"', "; ")
                if `q' {
                    local one = substr(`"`rest'"', 1, `q'-1)
                    local rest = substr(`"`rest'"', `q'+2, .)
                }
                else {
                    local one `"`rest'"'
                    local rest ""
                }
                _srh_wtip `B' `one'
            }
        }
        file write `B' `"</title>"' _n
        _srh_rect `B' `xl' `y' `BW' `SH' bx
        local ty = `y' + 3
        _srh_mell `HBUD' `"`v_`p''"'
        local ty = `ty' + `LH'
        _srh_wtext `B' `=`xl'+8' `ty' bh `"`s(o)'"'
        forvalues j = 1/`nlab_`p'' {
            local ty = `ty' + `LH'
            _srh_wtext `B' `=`xl'+8' `ty' bl `"`lbl_`p'_`j''"'
        }
        local ty = `ty' + `LH'
        _srh_wtext `B' `=`xl'+8' `ty' bn `"`nnf' (`pa_`p''%)"'
        if `flag_`p'' {
            _srh_n `"`nr_`p''"'
            local ty = `ty' + `LH'
            _srh_wtext `B' `=`xl'+8' `ty' bf `"!! nonresp `s(o)'"'
        }
        file write `B' `"</g>"' _n
        local prevy = `y' + `SH'
        local ++p
    }
    }
    else {
    local prevx = .
    local p = 1
    while `p' <= `K' {
        * ---- a gate's lanes open here: fan out, lanes, merge ----
        if "`fanat_`p''" != "" {
            local gp = `fanat_`p''
            local pe = `segend_`gp''
            local srcx = `prevx'
            if `srcx' == . local srcx = `colx_`p'' - `GAP'
            local L = `L_`gp''
            local blkh = `L' * (`CH' + `LGAP') - `LGAP'
            local btop = `Y0' - `blkh' / 2
            local x1 = `colx_`p''
            * head the block with the question that split it: the gate box
            * can be many columns back, and a reader should not have to work
            * out which question these lanes came from
            file write `B' `"<g class="sm-node">"' _n
            file write `B' `"<title>"'
            _srh_wtip `B' lanes split by `v_`gp''
            _srh_wtip `B' `lb_`gp''
            file write `B' `"</title>"' _n
            _srh_wtext `B' `x1' `=`btop'-20' lh `"split by `v_`gp''"'
            file write `B' `"</g>"' _n
            local jx = `colx_`pe'' + `BW' + `GAP' - 22
            forvalues k = 1/`L' {
                local ltop = `btop' + (`k' - 1) * (`CH' + `LGAP')
                local lcy = `ltop' + `CH' / 2
                * the lanes open where the segment starts, so the connector
                * leaves the spine that runs into it, not the gate box
                local xa = `srcx'
                local xb = `x1' - 2
                _srh_line `B' `xa' `Y0' `xb' `lcy'
                * lane label on the connector, above the lane's first column
                _srh_n `"`ln_`gp'_`k''"'
                local lnf `"`s(o)'"'
                _srh_mell 18 `"`ll_`gp'_`k''"'
                local lab `"`s(o)' `=char(3)' `lnf' (`lp_`gp'_`k''%)"'
                file write `B' `"<g class="sm-node">"' _n
                file write `B' `"<title>"'
                _srh_wtip `B' lane: `v_`gp'' == `lv_`gp'_`k''
                _srh_wtip `B' `ll_`gp'_`k''
                _srh_wtip `B' `lnf' respondents (`lp_`gp'_`k''% of scope)
                file write `B' `"</title>"' _n
                _srh_wtext `B' `x1' `=`ltop'-5' ll `"`lab'"'
                file write `B' `"</g>"' _n
                * cells across the segment
                local pcx = .
                forvalues q = `p'/`pe' {
                    if `"`cS_`gp'_`k'_`q''"' == "" continue
                    local cx = `colx_`q''
                    if `pcx' != . {
                        local xb = `cx' - 2
                        _srh_line `B' `pcx' `lcy' `xb' `lcy'
                    }
                    local st `"`cS_`gp'_`k'_`q''"'
                    _srh_n `"`cA_`gp'_`k'_`q''"'
                    local caf `"`s(o)'"'
                    _srh_n `"`cN_`gp'_`k'_`q''"'
                    local cnf `"`s(o)'"'
                    local crt `"`cR_`gp'_`k'_`q''"'
                    file write `B' `"<g class="sm-node">"' _n
                    file write `B' `"<title>"'
                    _srh_wtip `B' `v_`q'' `=char(3)' lane `v_`gp'' == `lv_`gp'_`k''
                    _srh_wtip `B' `lb_`q''
                    _srh_wtip `B' in lane `caf' `=char(3)' answered `cnf' (`crt'%)
                    _srh_wtip `B' status: `st'
                    if `"`st'"' == "skipped" _srh_wtip `B' routed around by skip logic
                    file write `B' `"</title>"' _n
                    _srh_mell `HBUD' `"`v_`q''"'
                    local wname `"`s(o)'"'
                    if `"`st'"' == "skipped" {
                        _srh_rect `B' `cx' `ltop' `BW' `CH' gx
                        _srh_wtext `B' `=`cx'+8' `=`ltop'+17' gt `"`wname'"'
                        _srh_wtext `B' `=`cx'+8' `=`ltop'+31' gt `"skipped `=char(3)' routed around"'
                    }
                    else if `"`st'"' == "partial" {
                        _srh_rect `B' `cx' `ltop' `BW' `CH' cx
                        _srh_wtext `B' `=`cx'+8' `=`ltop'+17' bh `"`wname'"'
                        _srh_wtext `B' `=`cx'+8' `=`ltop'+31' bn `"`cnf' answered"'
                        _srh_wtext `B' `=`cx'+8' `=`ltop'+45' bf `"!! partial `crt'%"'
                    }
                    else {
                        _srh_rect `B' `cx' `ltop' `BW' `CH' cx
                        _srh_wtext `B' `=`cx'+8' `=`ltop'+17' bh `"`wname'"'
                        _srh_wtext `B' `=`cx'+8' `=`ltop'+31' bn `"`cnf' (`crt'%)"'
                    }
                    file write `B' `"</g>"' _n
                    local pcx = `cx' + `BW'
                }
                * merge connector into the join point
                if `pcx' == . local pcx = `srcx'
                local xb = `jx' - 4
                _srh_line `B' `pcx' `lcy' `xb' `Y0'
            }
            file write `B' `"<circle cx="`jx'" cy="`Y0'" r="3.5" class="sm-jp" fill="#444444" />"' _n
            file write `B' `"<circle cx="`jx'" cy="`Y0'" r="3.5" class="sm-jp" fill="#444444" />"' _n
            local prevx = `jx' + 4
            local p = `pe' + 1
            continue
        }
        local x = `colx_`p''
        local t = `Y0' - `SH' / 2
        if `prevx' != . {
            local x2 = `x' - 2
            _srh_line `B' `prevx' `Y0' `x2' `Y0'
        }
        * ---- spine item box ----
        file write `B' `"<g class="sm-node">"' _n
        file write `B' `"<title>"'
        _srh_wtip `B' `v_`p'' `=char(3)' item `p' of `K'
        _srh_wtip `B' `lb_`p''
        _srh_n `"`na_`p''"'
        local naf `"`s(o)'"'
        _srh_n `"`nn_`p''"'
        local nnf `"`s(o)'"'
        _srh_wtip `B' asked `naf' `=char(3)' answered `nnf' (`pa_`p''%)
        _srh_n `"`nr_`p''"'
        local a `"`s(o)'"'
        _srh_n `"`ns_`p''"'
        local b `"`s(o)'"'
        if "`a'" == "" local a "0"
        if "`b'" == "" local b "0"
        _srh_wtip `B' nonresponse `a' `=char(3)' system missing `b'
        if `"`ty_`p''"' != "." _srh_wtip `B' type `ty_`p''
        if "`g_`p''" == "1" _srh_wtip `B' gate: lanes split here
        if `"`gb_`p''"' != "." _srh_wtip `B' routed around for: `gb_`p''
        if `"`fl_`p''"' != "." & `"`fl_`p''"' != "" {
            local rest `"`fl_`p''"'
            while `"`rest'"' != "" {
                local q = strpos(`"`rest'"', "; ")
                if `q' {
                    local one = substr(`"`rest'"', 1, `q'-1)
                    local rest = substr(`"`rest'"', `q'+2, .)
                }
                else {
                    local one `"`rest'"'
                    local rest ""
                }
                _srh_wtip `B' `one'
            }
        }
        file write `B' `"</title>"' _n
        _srh_rect `B' `x' `t' `BW' `SH' bx
        local ty = `t' + 3
        _srh_mell `HBUD' `"`v_`p''"'
        local ty = `ty' + `LH'
        _srh_wtext `B' `=`x'+8' `ty' bh `"`s(o)'"'
        forvalues j = 1/`nlab_`p'' {
            local ty = `ty' + `LH'
            _srh_wtext `B' `=`x'+8' `ty' bl `"`lbl_`p'_`j''"'
        }
        local ty = `ty' + `LH'
        if "`naf'" == "" local naf "."
        _srh_wtext `B' `=`x'+8' `ty' bn `"`nnf' (`pa_`p''%)"'
        if `flag_`p'' {
            _srh_n `"`nr_`p''"'
            local ty = `ty' + `LH'
            _srh_wtext `B' `=`x'+8' `ty' bf `"!! nonresp `s(o)'"'
        }
        file write `B' `"</g>"' _n

        local prevx = `x' + `BW'
        local ++p
    }
    }
    file close `B'

    * ------------------------------------------------ assemble
    local jname = substr("`using'", strrpos(subinstr("`using'","\","/",.), "/") + 1, .)
    * the caller may be drawing a pruned tempfile copy of the journal; name()
    * is what the page should call it
    if `"`name'"' != "" local jname `"`name'"'

    tempname H
    file open `H' using "`out'", write text replace

    if "`embed'" == "" {
        file write `H' `"<!DOCTYPE html>"' _n
        file write `H' `"<html xmlns="http://www.w3.org/1999/xhtml" lang="en">"' _n
        file write `H' `"<head>"' _n
        file write `H' `"<meta charset="utf-8" />"' _n
        file write `H' `"<title>surveymap &#183; `jname'</title>"' _n
        file write `H' `"<style type="text/css">"' _n
        * page chrome: element selectors are safe here, never in embed mode
        file write `H' `"body { font-family: -apple-system, Segoe UI, Helvetica, Arial, sans-serif; color: #222; background: #fff; margin: 24px; }"' _n
        file write `H' `"h1 { font-size: 19px; margin: 0 0 2px 0; font-weight: 600; }"' _n
        _srh_css `H' "`pfx'" "`accent'" `svgw' ""
        file write `H' `"</style>"' _n
        file write `H' `"</head>"' _n
        file write `H' `"<body>"' _n
        file write `H' `"<h1>surveymap &#183; `jname'</h1>"' _n
    }
    else {
        file write `H' `"<!-- surveymap embed fragment: `jname'. Scoped to .`pfx'; no element selectors; ids namespaced `pfx'-*. -->"' _n
        file write `H' `"<style type="text/css">"' _n
        _srh_css `H' "`pfx'" "`accent'" `svgw' "embed"
        file write `H' `"</style>"' _n
    }

    file write `H' `"<div class="sm-embed `pfx'">"' _n

    if "`noheader'" == "" {
        _srh_n `"`NN'"'
        local nnf `"`s(o)'"'
        if "`nnf'" == "" local nnf "?"
        local gw = cond(`G' == 1, "gate", "gates")
        local iw = cond(`K' == 1, "item", "items")
        local wnote = cond(`haswt', ///
            " &#183; counts unweighted, percentages weighted", "")
        file write `H' `"<div class="sm-cap">survey: `jname' &#183; `nnf' respondents &#183; `K' `iw' &#183; `G' `gw'`wnote'</div>"' _n
        file write `H' `"<div class="sm-leg"><span class="sm-legk">!!</span> = warning (never colour alone) &#183; dashed box = skipped, routed around by the gate &#183; lanes partition the sample &#183; hover a node for detail</div>"' _n
    }

    file write `H' `"<div class="sm-wrap">"' _n
    if "`embed'" == "" {
        file write `H' `"<svg xmlns="http://www.w3.org/2000/svg" class="sm-svg" role="img" viewBox="0 0 `svgw' `svgh'" width="`svgw'" height="`svgh'">"' _n
    }
    else {
        * embed: viewBox only, no width/height; natural width comes from a
        * scoped CSS rule inside .sm-wrap
        file write `H' `"<svg xmlns="http://www.w3.org/2000/svg" class="sm-svg" role="img" viewBox="0 0 `svgw' `svgh'">"' _n
    }
    file write `H' `"<title>surveymap flow map for `jname'</title>"' _n
    file write `H' `"<desc>Items run left to right in questionnaire order; a gate fans the sample into lanes that rejoin the spine at the end of its segment.</desc>"' _n
    file write `H' `"<defs>"' _n
    file write `H' `"<marker id="`pfx'-aa" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="`accent'" /></marker>"' _n
    file write `H' `"</defs>"' _n
    * copy the body (data was neutralized, so no backticks, dollars or quotes)
    tempname R
    file open `R' using "`bodyf'", read text
    file read `R' bline
    while r(eof) == 0 {
        file write `H' `"`macval(bline)'"' _n
        file read `R' bline
    }
    file close `R'
    file write `H' `"</svg>"' _n
    file write `H' `"</div>"' _n

    * provenance footer
    local flav = cond(c(MP) == 1, "MP", cond(c(SE) == 1, "SE", c(flavor)))
    file write `H' `"<div class="sm-foot">surveymap &#183; journal `jname' &#183; generated `c(current_date)' `c(current_time)' &#183; Stata `c(stata_version)' `flav'</div>"' _n

    file write `H' `"</div>"' _n
    if "`embed'" == "" {
        file write `H' `"</body>"' _n
        file write `H' `"</html>"' _n
    }
    file close `H'

    frame drop `J'
    capture macro drop SRH_ACC SRH_PFX

    local tag = cond("`embed'" != "", ", embed fragment", "")
    display as text "_sm_renderhtml: wrote " as result "`out'" ///
        as text " (`K' items, `G' gates`tag')"
end


* ============================================================ stylesheet
* Every rule is scoped under the per-diagram class and every selector is a
* class selector.  No element selectors: those would restyle the host page
* an embed fragment is pasted into.
program define _srh_css
    args H pfx accent svgw embed

    local P ".`pfx'"
    local MONO "SF Mono, Menlo, Consolas, DejaVu Sans Mono, monospace"
    local SANS "-apple-system, Segoe UI, Helvetica, Arial, sans-serif"

    file write `H' `"`P' { margin: 1rem 0; }"' _n
    * The fragment gets a bounded, resizable viewport, because it sits inside
    * someone else's page.  A standalone page is the page: no max-height cap,
    * the browser scrolls it.  The print query lifts the cap either way.
    if "`embed'" != "" {
        file write `H' `"`P' .sm-wrap { max-height: 32rem; overflow: auto; resize: vertical; border: 1px solid #e4e4e4; border-radius: 4px; padding: 6px; background: #fff; }"' _n
    }
    else {
        file write `H' `"`P' .sm-wrap { overflow-x: auto; border: 1px solid #e4e4e4; border-radius: 4px; padding: 6px; background: #fff; }"' _n
    }
    * width grows with items: keep native width, scroll sideways
    file write `H' `"`P' .sm-svg { width: `svgw'px; max-width: none; height: auto; display: block; }"' _n
    file write `H' `"`P' .sm-cap { font-family: `SANS'; font-size: 12px; color: #666; margin: 0 0 3px 0; }"' _n
    file write `H' `"`P' .sm-leg { font-family: `SANS'; font-size: 11px; color: #888; margin: 0 0 8px 0; }"' _n
    file write `H' `"`P' .sm-legk { color: `accent'; font-weight: 700; }"' _n
    file write `H' `"`P' .sm-foot { font-family: `SANS'; font-size: 10px; color: #999; margin: 10px 0 0 0; line-height: 1.5; }"' _n
    file write `H' `"`P' .sm-node { cursor: help; }"' _n
    * svg text roles
    file write `H' `"`P' .sm-t { font-family: `MONO'; }"' _n
    file write `H' `"`P' .sm-bh { font-size: 12px; font-weight: 700; fill: #111; }"' _n
    file write `H' `"`P' .sm-bl { font-size: 11px; fill: #333; }"' _n
    file write `H' `"`P' .sm-bn { font-size: 11px; fill: #666; }"' _n
    file write `H' `"`P' .sm-bf { font-size: 11px; font-weight: 700; fill: `accent'; }"' _n
    file write `H' `"`P' .sm-gt { font-size: 11px; fill: #8a8a8a; }"' _n
    file write `H' `"`P' .sm-ll { font-size: 11px; fill: #333; }"' _n
    file write `H' `"`P' .sm-lh { font-size: 11px; font-weight: 700; fill: #222222; }"' _n
    * svg shape roles
    file write `H' `"`P' .sm-bx { fill: #f7f7f7; stroke: #333; stroke-width: 1.1; }"' _n
    file write `H' `"`P' .sm-cx { fill: #fcfcfc; stroke: #666; stroke-width: 1; }"' _n
    file write `H' `"`P' .sm-gx { fill: #fff; stroke: #999; stroke-width: 1; stroke-dasharray: 5 3; }"' _n
    file write `H' `"`P' .sm-sp { stroke: #444; stroke-width: 1.2; fill: none; }"' _n
    file write `H' `"`P' .sm-jp { fill: #444; }"' _n
    file write `H' `"@media print { `P' .sm-wrap { max-height: none; overflow: visible; resize: none; border: 0; padding: 0; } }"' _n
end


* ============================================================ svg writers
* Shapes carry presentation attributes as well as classes, so a fragment
* whose stylesheet is stripped still renders as legible boxes.

program define _srh_rect
    args B x y w h cls
    local fill "#f7f7f7"
    local strk "#333"
    local sw   "1.1"
    local dash ""
    if "`cls'" == "cx" {
        local fill "#fcfcfc"
        local strk "#666"
        local sw   "1"
    }
    if "`cls'" == "gx" {
        local fill "#ffffff"
        local strk "#999"
        local sw   "1"
        local dash `" stroke-dasharray="5 3""'
    }
    file write `B' `"<rect x="`x'" y="`y'" width="`w'" height="`h'" class="sm-`cls'" fill="`fill'" stroke="`strk'" stroke-width="`sw'"`dash' />"' _n
end

* connector; every arrowhead uses the accent marker (the one place besides
* "!!" the accent colour appears)
program define _srh_line
    args B x1 y1 x2 y2
    file write `B' `"<line x1="`x1'" y1="`y1'" x2="`x2'" y2="`y2'" class="sm-sp" stroke="#444444" stroke-width="1.2" fill="none" marker-end="url(#${SRH_PFX}-aa)" />"' _n
end

* write an svg <text>; maps marker chars to XML entities and mirrors the CSS
* into presentation attributes
program define _srh_wtext
    gettoken h   0 : 0
    gettoken x   0 : 0
    gettoken y   0 : 0
    gettoken cls 0 : 0
    if "`cls'" == "" local cls "bl"
    * the text arrives as ONE compound-quoted token; gettoken binds and
    * strips the quotes (args would keep them, and they would draw)
    gettoken txt : 0
    _srh_map `"`txt'"'
    local t = trim(`"`s(o)'"')
    local size 11
    local wt   "normal"
    local fill "#333"
    if "`cls'" == "bh" {
        local size 12
        local wt "bold"
        local fill "#111"
    }
    if "`cls'" == "bn" local fill "#666"
    if "`cls'" == "bf" {
        local wt "bold"
        local fill "$SRH_ACC"
    }
    if "`cls'" == "gt" local fill "#8a8a8a"
    file write `h' `"<text x="`x'" y="`y'" class="sm-t sm-`cls'" font-family="SF Mono, Menlo, Consolas, DejaVu Sans Mono, monospace" font-size="`size'" font-weight="`wt'" fill="`fill'">`t'</text>"' _n
end

* one tooltip line (a real newline: browsers honour it inside svg <title>)
program define _srh_wtip
    gettoken h 0 : 0
    _srh_map `"`0'"'
    local t = trim(`"`s(o)'"')
    file write `h' `"`t'"' _n
end

* map internal marker chars to XML entities -> s(o)
program define _srh_map, sclass
    args t
    local t = subinstr(`"`t'"', char(16), "&amp;",   .)
    local t = subinstr(`"`t'"', char(17), "&lt;",    .)
    local t = subinstr(`"`t'"', char(18), "&gt;",    .)
    local t = subinstr(`"`t'"', char(19), "&quot;",  .)
    local t = subinstr(`"`t'"', char(6),  "&#96;",   .)
    local t = subinstr(`"`t'"', char(7),  "&#36;",   .)
    local t = subinstr(`"`t'"', char(1),  "&#8230;", .)
    local t = subinstr(`"`t'"', char(3),  "&#183;",  .)
    sreturn local o `"`t'"'
end

* comma-format a count string ("." or "" -> empty) -> s(o)
program define _srh_n, sclass
    args s
    if `"`s'"' == "." | `"`s'"' == "" sreturn local o ""
    else sreturn local o = trim(string(real(`"`s'"'), "%20.0fc"))
end

* middle-ellipsis to maxlen -> s(o); only when the label genuinely overflows
program define _srh_mell, sclass
    args maxlen t
    if strlen(`"`t'"') <= `maxlen' {
        sreturn local o `"`t'"'
        exit
    }
    local h1 = floor((`maxlen'-1)/2)
    local h2 = `maxlen' - 1 - `h1'
    sreturn local o = substr(`"`t'"', 1, `h1') + char(1) + substr(`"`t'"', -`h2', .)
end

* word-wrap to at most maxlines lines -> s(n), s(l1..); overflow past the
* last line merges in with a middle-ellipsis
program define _srh_wrapn, sclass
    args maxlen maxlines t
    local rest = trim(`"`t'"')
    local n 0
    while `"`rest'"' != "" & `n' < `maxlines' {
        if strlen(`"`rest'"') <= `maxlen' {
            local ++n
            local l`n' `"`rest'"'
            local rest ""
        }
        else {
            local head = substr(`"`rest'"', 1, `maxlen')
            local p = strrpos(`"`head'"', " ")
            if `p' < 8 local p = `maxlen'
            local ++n
            local l`n' = trim(substr(`"`rest'"', 1, `p'))
            local rest = trim(substr(`"`rest'"', `p'+1, .))
        }
    }
    if `"`rest'"' != "" & `n' > 0 {
        local merged `"`l`n'' `rest'"'
        _srh_mell `maxlen' `"`merged'"'
        local l`n' `"`s(o)'"'
    }
    sreturn clear
    sreturn local n = `n'
    forvalues k = 1/`n' {
        sreturn local l`k' `"`l`k''"'
    }
end

* sanitize an id/class prefix -> s(o)
program define _srh_slug, sclass
    args t
    local out ""
    local L = strlen(`"`t'"')
    if `L' > 40 local L 40
    forvalues i = 1/`L' {
        local ch = substr(`"`t'"', `i', 1)
        if !ustrregexm("`ch'", "^[A-Za-z0-9-]$") local ch "-"
        local out "`out'`ch'"
    }
    while substr("`out'", -1, 1) == "-" {
        local out = substr("`out'", 1, strlen("`out'")-1)
    }
    if substr("`out'", 1, 3) != "sm-" local out "sm-`out'"
    if "`out'" == "sm-" local out "sm-1"
    sreturn clear
    sreturn local o "`out'"
end
