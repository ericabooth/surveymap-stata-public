*! version 0.6.0  27aug2026  Eric Booth
*! _sm_renderflow -- draw a paths journal (pnode/pflow/ppath rows) as a
*! self-contained HTML page: one column per item, one block per common
*! answer, ribbons between consecutive columns sized by the people who gave
*! both answers, and a table of the most common full sequences underneath.
*!
*! Everything drawn is read back from the journal; nothing is recounted.
*! The one derived quantity is geometry: block heights share a single
*! people-to-pixels scale, so a block twice as tall is twice as many
*! people, in every column.
*!
*! Escaping discipline is _sm_renderhtml's (TRAPS 1): journal text is
*! neutralized to marker characters at import, carried through macros
*! inertly, and mapped to XML entities at the moment of writing.

program define _sm_renderflow, sclass
    version 16
    syntax using/, SAVing(string) [TITLe(string) NAME(string) EMBed replace]

    sreturn clear
    local hf `"`saving'"'
    if strlower(substr(`"`hf'"', -5, .)) != ".html" local hf `"`hf'.html"'
    capture confirm file `"`hf'"'
    if !_rc & "`replace'" == "" {
        di as err `"surveymap paths: `hf' exists; add replace to overwrite"'
        exit 602
    }

    * ---- intake ----------------------------------------------------------
    tempname J
    frame create `J'
    frame `J' {
        quietly import delimited using `"`using'"', delimiter(tab) ///
            varnames(1) stringcols(_all) encoding("utf-8") clear
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

    * ---- survey row: N, the settings line, the scope ---------------------
    local NN "."
    local sflags ""
    local K = 0
    forvalues i = 1/`NR' {
        frame `J': local cls = class[`i']
        if "`cls'" == "survey" {
            frame `J': local NN = n_asked[`i']
            frame `J': local sflags = flags[`i']
        }
        if "`cls'" != "item" continue
        frame `J': local p = real(position[`i'])
        if `p' >= . continue
        local K = max(`K', `p')
        frame `J': local v_`p'  = var[`i']
        frame `J': local lb_`p' = vallabel[`i']
    }
    if `K' < 2 {
        frame drop `J'
        di as err "surveymap paths: `using' has no item rows to draw"
        di as err "    write the journal with  surveymap paths varlist, out(...)"
        exit 459
    }
    local scopetxt ""
    local p = strpos(`"`sflags'"', "; scope: ")
    if `p' {
        local scopetxt = strtrim(substr(`"`sflags'"', `p' + 9, .))
    }

    * ---- blocks (pnode), ribbons (pflow), sequences (ppath) --------------
    local KM = 0
    forvalues i = 1/`NR' {
        frame `J': local cls = class[`i']
        if "`cls'" == "pnode" {
            frame `J': local t = real(position[`i'])
            frame `J': local s = real(gate[`i'])
            if `t' >= . | `s' >= . continue
            local KM = max(`KM', `s')
            frame `J': local nk_`t'_`s'  = real(n_asked[`i'])
            if `nk_`t'_`s'' >= . {
                frame drop `J'
                di as err "surveymap paths: a pnode row in `using' has no count"
                di as err "    the journal is damaged; rewrite it with  surveymap paths ..., nodraw"
                exit 459
            }
            frame `J': local pk_`t'_`s'  = pct_answered[`i']
            frame `J': local dk_`t'_`s'  = vallabel[`i']
            frame `J': local vk_`t'_`s'  = value[`i']
        }
        if "`cls'" == "pflow" {
            frame `J': local t = real(position[`i'])
            frame `J': local a = real(gate[`i'])
            frame `J': local b = real(rate[`i'])
            if `t' >= . | `a' >= . | `b' >= . continue
            local FL_`t' "`FL_`t'' `a':`b'"
            frame `J': local fn_`t'_`a'_`b' = real(n_asked[`i'])
            frame `J': local fp_`t'_`a'_`b' = pct_answered[`i']
        }
        if "`cls'" == "ppath" {
            frame `J': local r = real(gate[`i'])
            if `r' >= . continue
            if "`NPATH'" == "" local NPATH = 0
            local NPATH = max(`NPATH', `r')
            frame `J': local sq_`r' = value[`i']
            frame `J': local sn_`r' = n_asked[`i']
            frame `J': local sp_`r' = pct_answered[`i']
        }
    }
    if `KM' == 0 {
        frame drop `J'
        di as err "surveymap paths: `using' has no pnode rows"
        di as err "    it is a scan journal; draw it with  surveymap draw"
        exit 459
    }
    frame drop `J'
    * top comes from the survey row's settings line, not from the occupied
    * slots: on complete data the no-answer slot is never journaled, and
    * inferring from occupancy would shift every colour and the guide text
    local topk = `KM' - 2
    if ustrregexm(`"`sflags'"', "top=([0-9]+)") {
        local topk = real(ustrregexs(1))
        local KM = `topk' + 2
    }
    local N = real(`"`NN'"')
    if `N' >= . | `N' <= 0 {
        di as err "surveymap paths: `using' has no survey row with the scope count"
        di as err "    the journal is damaged; rewrite it with  surveymap paths ..., nodraw"
        exit 459
    }

    * ---- geometry --------------------------------------------------------
    * One vertical scale for every column: pixels per person.  Block heights
    * get a floor so a sliver stays visible; the floor inflates a column by
    * a few pixels at most, and the ribbons anchor inside the drawn blocks,
    * so the braid still partitions each bar edge exactly.
    local PH   = 520
    local TOPM = 96
    local BOTM = 30
    local NW   = 16
    local GAPX = 186
    local LM   = 14
    local RM   = 200
    local SGAP = 5
    local pxper = (`PH' - (`KM' - 1) * `SGAP') / `N'
    local W = `LM' + `K' * `NW' + (`K' - 1) * `GAPX' + `RM'

    * block tops and heights; a slot with no row (n = 0) takes no space
    local Hmax = 0
    forvalues t = 1/`K' {
        local y = `TOPM'
        forvalues s = 1/`KM' {
            if `"`nk_`t'_`s''"' == "" continue
            local h = max(3, round(`nk_`t'_`s'' * `pxper'))
            local gy_`t'_`s' = `y'
            local gh_`t'_`s' = `h'
            local y = `y' + `h' + `SGAP'
        }
        local Hmax = max(`Hmax', `y' - `SGAP')
    }
    local H = `Hmax' + `BOTM'

    * ---- file ------------------------------------------------------------
    local stub `"`hf'"'
    local p = max(strrpos(`"`stub'"', "/"), strrpos(`"`stub'"', char(92)))
    if `p' local stub = substr(`"`stub'"', `p' + 1, .)
    if strlower(substr(`"`stub'"', -5, .)) == ".html" {
        local stub = substr(`"`stub'"', 1, strlen(`"`stub'"') - 5)
    }
    _srf_slug `"`stub'"'
    local PFX "`s(o)'"
    local jname `"`name'"'
    if `"`jname'"' == "" {
        local jname `"`using'"'
        local p = max(strrpos(`"`jname'"', "/"), strrpos(`"`jname'"', char(92)))
        if `p' local jname = substr(`"`jname'"', `p' + 1, .)
    }
    local ttl `"`title'"'
    if `"`ttl'"' == "" local ttl "How the answers flow, item by item"
    * option text and filenames arrive as literals, not marker-encoded
    * journal text, so they get their own XML escaping here
    _srf_lit `"`ttl'"'
    local ttl `"`s(o)'"'
    _srf_lit `"`jname'"'
    local jname `"`s(o)'"'

    tempname h
    quietly file open `h' using `"`hf'"', write text replace
    if "`embed'" == "" {
        file write `h' `"<!DOCTYPE html>"' _n
        file write `h' `"<html xmlns="http://www.w3.org/1999/xhtml" lang="en">"' _n
        file write `h' `"<head>"' _n
        file write `h' `"<meta charset="utf-8" />"' _n
        _srf_map `"`ttl'"'
        file write `h' `"<title>surveymap &#183; `s(o)'</title>"' _n
        file write `h' `"<style type="text/css">"' _n
        file write `h' `"body { font-family: -apple-system, Segoe UI, Helvetica, Arial, sans-serif; color: #222; background: #fff; margin: 24px; }"' _n
        file write `h' `"h1 { font-size: 19px; margin: 0 0 2px 0; font-weight: 600; }"' _n
    }
    file write `h' `"<style type="text/css">"' _n
    file write `h' `".`PFX' { margin: 1rem 0; }"' _n
    file write `h' `".`PFX' .sm-wrap { overflow-x: auto; border: 1px solid #e4e4e4; border-radius: 4px; padding: 6px; background: #fff; }"' _n
    file write `h' `".`PFX' .sm-svg { width: `W'px; max-width: none; height: auto; display: block; }"' _n
    file write `h' `".`PFX' .sm-cap { font-size: 12px; color: #666; margin: 0 0 3px 0; }"' _n
    file write `h' `".`PFX' .sm-leg { font-size: 11px; color: #888; margin: 0 0 8px 0; }"' _n
    file write `h' `".`PFX' .sm-foot { font-size: 10px; color: #999; margin: 10px 0 0 0; line-height: 1.5; }"' _n
    file write `h' `".`PFX' .sm-read { font-size: 12.5px; color: #333; margin: 6px 0 2px 0; }"' _n
    file write `h' `".`PFX' .sm-rdl { margin: 6px 0 4px 18px; padding: 0; max-width: 760px; }"' _n
    file write `h' `".`PFX' .sm-rdl li { margin: 0 0 6px 0; line-height: 1.45; }"' _n
    file write `h' `".`PFX' .sm-ptbl { border-collapse: collapse; margin: 8px 0 0 0; font-size: 12px; }"' _n
    file write `h' `".`PFX' .sm-ptbl th { text-align: left; font-weight: 600; color: #555; padding: 3px 12px 3px 0; border-bottom: 1px solid #ddd; }"' _n
    file write `h' `".`PFX' .sm-ptbl td { padding: 3px 12px 3px 0; border-bottom: 1px solid #f0f0f0; }"' _n
    file write `h' `".`PFX' .sm-ptbl td.n { text-align: right; font-variant-numeric: tabular-nums; }"' _n
    file write `h' `"</style>"' _n
    if "`embed'" == "" {
        file write `h' `"</head>"' _n
        file write `h' `"<body>"' _n
        _srf_map `"`ttl'"'
        file write `h' `"<h1>`s(o)'</h1>"' _n
    }
    file write `h' `"<div class="`PFX'">"' _n

    * caption: what this is, whose numbers, which scope
    _srf_n `"`NN'"'
    local Nfmt "`s(o)'"
    file write `h' `"<p class="sm-cap"><b>`Nfmt' respondents</b>, each counted once in every column &#183; journal: `jname'</p>"' _n
    if `"`scopetxt'"' != "" {
        _srf_map `"`scopetxt'"'
        file write `h' `"<p class="sm-cap"><b>scope:</b> only respondents where `s(o)' &#183; every count and share on this page describes that group</p>"' _n
    }
    file write `h' `"<p class="sm-leg">a column is one item; a block is one answer, sized by how many gave it; a ribbon joins two answers on consecutive items, sized by how many gave both; hover anything for exact counts</p>"' _n

    file write `h' `"<div class="sm-wrap">"' _n
    file write `h' `"<svg class="sm-svg" viewBox="0 0 `W' `H'" width="`W'" height="`H'" xmlns="http://www.w3.org/2000/svg" role="img">"' _n
    file write `h' `"<desc>Response-flow map of `K' survey items for `Nfmt' respondents. Each item is a column of blocks, one per common answer plus other answers and no answer; ribbons between columns carry the respondents who gave both answers.</desc>"' _n

    * ---- ribbons first, so bars and labels overprint them ----------------
    * Each bar edge is partitioned exactly: outgoing ribbons in to-slot
    * order on the right edge, incoming ribbons in from-slot order on the
    * left edge, each taking its share of the drawn block height.
    forvalues t = 1/`=`K'-1' {
        local u = `t' + 1
        local xa = `LM' + (`t' - 1) * (`NW' + `GAPX') + `NW'
        local xb = `LM' + (`u' - 1) * (`NW' + `GAPX')
        local xm = (`xa' + `xb') / 2
        * running offsets down each block edge
        forvalues s = 1/`KM' {
            local oa_`s' = 0
            local ob_`s' = 0
        }
        forvalues a = 1/`KM' {
            forvalues b = 1/`KM' {
                if `"`fn_`t'_`a'_`b''"' == "" continue
                local n = `fn_`t'_`a'_`b''
                local ha = `gh_`t'_`a'' * `n' / `nk_`t'_`a''
                local hb = `gh_`u'_`b'' * `n' / `nk_`u'_`b''
                local ya = `gy_`t'_`a'' + `oa_`a''
                local yb = `gy_`u'_`b'' + `ob_`b''
                local oa_`a' = `oa_`a'' + `ha'
                local ob_`b' = `ob_`b'' + `hb'
                local ya2 = `ya' + `ha'
                local yb2 = `yb' + `hb'
                foreach c in ya yb ya2 yb2 {
                    local `c' = round(``c'', .1)
                }
                _srf_color `a' `topk'
                local col "`s(o)'"
                local op ".40"
                if `a' == `KM' | `b' == `KM' local op ".22"
                file write `h' `"<path class="sm-fp" d="M `xa' `ya' C `xm' `ya' `xm' `yb' `xb' `yb' L `xb' `yb2' C `xm' `yb2' `xm' `ya2' `xa' `ya2' Z" fill="`col'" fill-opacity="`op'" stroke="none">"' _n
                file write `h' `"<title>"'
                _srf_n "`n'"
                local nf "`s(o)'"
                _srf_wtip `h' `"`v_`t'' `dk_`t'_`a'' -> `v_`u'' `dk_`u'_`b''"'
                _srf_wtip `h' `"`nf' of `Nfmt' (`=strtrim("`fp_`t'_`a'_`b''")'% of respondents in scope)"'
                file write `h' `"</title></path>"' _n
            }
        }
    }

    * ---- blocks and their labels -----------------------------------------
    forvalues t = 1/`K' {
        local x = `LM' + (`t' - 1) * (`NW' + `GAPX')
        * column header: item name, wording, in the band above the blocks
        _srf_mell 24 `"`v_`t''"'
        _srf_map `"`s(o)'"'
        file write `h' `"<text x="`x'" y="20" font-family="SF Mono, Menlo, Consolas, DejaVu Sans Mono, monospace" font-size="12.5" font-weight="bold" fill="#111">`s(o)'</text>"' _n
        _srf_wrapn 30 3 `"`lb_`t''"'
        local nl = `s(n)'
        forvalues li = 1/`nl' {
            local yy = 20 + 13 * `li'
            _srf_map `"`s(l`li')'"'
            file write `h' `"<text x="`x'" y="`yy'" font-family="-apple-system, Segoe UI, Helvetica, Arial, sans-serif" font-size="10" fill="#777">`s(o)'</text>"' _n
        }
        forvalues s = 1/`KM' {
            if `"`nk_`t'_`s''"' == "" continue
            local y = `gy_`t'_`s''
            local hh = `gh_`t'_`s''
            _srf_color `s' `topk'
            local col "`s(o)'"
            file write `h' `"<rect x="`x'" y="`y'" width="`NW'" height="`hh'" fill="`col'" rx="2">"' _n
            file write `h' `"<title>"'
            _srf_n "`nk_`t'_`s''"
            local nf "`s(o)'"
            _srf_wtip `h' `"`v_`t'' `dk_`t'_`s''"'
            _srf_wtip `h' `"`nf' of `Nfmt' (`=strtrim("`pk_`t'_`s''")'% of respondents in scope)"'
            file write `h' `"</title></rect>"' _n
            if `hh' >= 12 {
                _srf_mell 22 `"`dk_`t'_`s''"'
                _srf_map `"`s(o)'"'
                local lt "`s(o)'"
                local ly = `y' + `hh' / 2 + 3.5
                local ly = round(`ly', .1)
                local lx = `x' + `NW' + 5
                local pc = strtrim(`"`pk_`t'_`s''"')
                file write `h' `"<text x="`lx'" y="`ly'" font-family="-apple-system, Segoe UI, Helvetica, Arial, sans-serif" font-size="10.5" fill="#222" style="paint-order: stroke; stroke: #ffffff; stroke-width: 3px;"><tspan font-weight="600">`pc'%</tspan> `lt'</text>"' _n
            }
        }
    }
    file write `h' `"</svg>"' _n
    file write `h' `"</div>"' _n

    * ---- the most common full sequences ----------------------------------
    if "`NPATH'" != "" {
        local order ""
        forvalues t = 1/`K' {
            _srf_map `"`v_`t''"'
            if `t' == 1 local order "`s(o)'"
            else        local order "`order' &#8594; `s(o)'"
        }
        file write `h' `"<p class="sm-read"><b>The most common full paths</b>, reading `order':</p>"' _n
        file write `h' `"<table class="sm-ptbl"><tr><th>share</th><th>people</th><th>path</th></tr>"' _n
        forvalues r = 1/`NPATH' {
            if `"`sq_`r''"' == "" continue
            local cells ""
            local rest `"`sq_`r''"'
            local t = 0
            while `"`rest'"' != "" & `t' < `K' {
                local ++t
                local p = strpos(`"`rest'"', char(18))
                if `p' {
                    local tok = substr(`"`rest'"', 1, `p' - 1)
                    local rest = substr(`"`rest'"', `p' + 1, .)
                }
                else {
                    local tok `"`rest'"'
                    local rest ""
                }
                local s = real(`"`tok'"')
                if `s' >= . continue
                local lab `"`dk_`t'_`s''"'
                _srf_mell 22 `"`lab'"'
                _srf_map `"`s(o)'"'
                if `t' == 1 local cells "`s(o)'"
                else        local cells `"`cells' &#8594; `s(o)'"'
            }
            _srf_n `"`sn_`r''"'
            local nf "`s(o)'"
            local pc = strtrim(`"`sp_`r''"')
            file write `h' `"<tr><td class="n">`pc'%</td><td class="n">`nf'</td><td>`cells'</td></tr>"' _n
        }
        file write `h' `"</table>"' _n
    }

    * ---- how to read it, in this map's own names -------------------------
    file write `h' `"<details class="sm-read" open="open"><summary><b>How to read this map, step by step</b></summary><ol class="sm-rdl">"' _n
    _srf_map `"`v_1'"'
    local v1 "`s(o)'"
    _srf_mell 40 `"`dk_1_1'"'
    _srf_map `"`s(o)'"'
    local d11 "`s(o)'"
    local p11 = strtrim(`"`pk_1_1'"')
    * say the grey block exists only where one is drawn: a map of items
    * everybody answered has none, and column one may not have one either
    local greysent ""
    forvalues t = 1/`K' {
        if `"`nk_`t'_`KM''"' != "" {
            local greysent " Light grey blocks collect everyone with no answer recorded on that item."
            continue, break
        }
    }
    file write `h' `"<li>Start at the left. The first column is <b>`v1'</b>. The column stacks all `Nfmt' respondents: each colored block is one answer, its label gives the share who gave it, and the top block here is <b>`d11'</b> at `p11'%.`greysent'</li>"' _n
    file write `h' `"<li>Follow a ribbon to the right. A ribbon connects an answer on one item to an answer on the next, and its thickness is the number of people who gave both. Hovering a ribbon shows the exact count. Where a block fans out into several ribbons, the sample is splitting; where ribbons converge on one block, paths are merging.</li>"' _n
    file write `h' `"<li>Blocks labelled <i>other answers</i> pool everything past the `topk' most common. Nothing is dropped: every respondent sits in exactly one block of every column, so each column adds back to `Nfmt'.</li>"' _n
    if "`NPATH'" != "" {
        file write `h' `"<li>Each line of the table under the figure is one complete path from the first item to the last, with the number and share of respondents who took exactly that path. The ribbons above join two items at a time; the table lines run the whole way across.</li>"' _n
    }
    if `"`scopetxt'"' != "" {
        _srf_map `"`scopetxt'"'
        file write `h' `"<li>This map is scoped: only respondents where `s(o)' are counted, in every column, block and ribbon.</li>"' _n
    }
    file write `h' `"</ol></details>"' _n

    file write `h' `"<p class="sm-foot">Reading rule: counts are unweighted respondents in scope. A ribbon is the number of people who gave that pair of answers on two consecutive items; a table line is the number who took that complete path. <i>no answer recorded</i> includes people the routing never showed the item, which item data cannot separate from a decline. Drawn by surveymap from `jname'; the journal has a weighted count column when the scan was weighted.</p>"' _n
    file write `h' `"</div>"' _n
    if "`embed'" == "" {
        file write `h' `"</body>"' _n
        file write `h' `"</html>"' _n
    }
    file close `h'
    sreturn local out `"`hf'"'
    di as txt "surveymap paths: map written to " as res `"`hf'"'
end

* slot color: ranked answers get the palette, other and no answer grey
program define _srf_color, sclass
    args s topk
    sreturn clear
    if `s' > `topk' + 1 {
        sreturn local o "#e8e8e8"
        exit
    }
    if `s' > `topk' {
        sreturn local o "#bfbfbf"
        exit
    }
    local c1 "#39566e"
    local c2 "#6e8ca8"
    local c3 "#a3b8cc"
    local c4 "#c98f4a"
    local c5 "#7a9b6d"
    local c6 "#9b7a9b"
    sreturn local o "`c`s''"
end

* ---- helpers: local copies of the html renderer's text machinery ---------
* (own copies, so this renderer does not depend on another file's internals)

* escape LITERAL XML-special characters -> s(o).  For option text and
* filenames, which never pass through the journal's marker encoding.
program define _srf_lit, sclass
    args t
    local t = subinstr(`"`t'"', "&", "&amp;",  .)
    local t = subinstr(`"`t'"', "<", "&lt;",   .)
    local t = subinstr(`"`t'"', ">", "&gt;",   .)
    local t = subinstr(`"`t'"', char(34), "&quot;", .)
    sreturn local o `"`t'"'
end

* map internal marker chars to XML entities -> s(o)
program define _srf_map, sclass
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

* one tooltip line (a real newline: browsers honour it inside svg <title>)
program define _srf_wtip
    gettoken h 0 : 0
    * the text arrives as ONE compound-quoted token; gettoken binds and
    * strips the quotes (expanding `0' directly keeps them, and they draw)
    gettoken txt : 0
    _srf_map `"`txt'"'
    local t = trim(`"`s(o)'"')
    file write `h' `"`t'"' _n
end

* comma-format a count string ("." or "" -> empty) -> s(o)
program define _srf_n, sclass
    args s
    if `"`s'"' == "." | `"`s'"' == "" sreturn local o ""
    else sreturn local o = trim(string(real(`"`s'"'), "%20.0fc"))
end

* middle-ellipsis to maxlen -> s(o); only when the label genuinely overflows
program define _srf_mell, sclass
    args maxlen t
    * character counts, not bytes: a byte-based cut can split a curly quote
    * or an accented letter in half and leave an invalid byte on the page
    if ustrlen(`"`t'"') <= `maxlen' {
        sreturn local o `"`t'"'
        exit
    }
    local h1 = floor((`maxlen'-1)/2)
    local h2 = `maxlen' - 1 - `h1'
    local L = ustrlen(`"`t'"')
    sreturn local o = usubstr(`"`t'"', 1, `h1') + char(1) + ///
        usubstr(`"`t'"', `L' - `h2' + 1, .)
end

* word-wrap to at most maxlines lines -> s(n), s(l1..); overflow past the
* last line merges in with a middle-ellipsis
program define _srf_wrapn, sclass
    args maxlen maxlines t
    local rest = trim(`"`t'"')
    local n 0
    while `"`rest'"' != "" & `n' < `maxlines' {
        if ustrlen(`"`rest'"') <= `maxlen' {
            local ++n
            local l`n' `"`rest'"'
            local rest ""
        }
        else {
            local head = usubstr(`"`rest'"', 1, `maxlen')
            local p = ustrrpos(`"`head'"', " ")
            if `p' < 8 local p = `maxlen'
            local ++n
            local l`n' = trim(usubstr(`"`rest'"', 1, `p'))
            local rest = trim(usubstr(`"`rest'"', `p'+1, .))
        }
    }
    if `"`rest'"' != "" & `n' > 0 {
        local merged `"`l`n'' `rest'"'
        _srf_mell `maxlen' `"`merged'"'
        local l`n' `"`s(o)'"'
    }
    sreturn clear
    sreturn local n = `n'
    forvalues k = 1/`n' {
        sreturn local l`k' `"`l`k''"'
    }
end

* sanitize an id/class prefix -> s(o)
program define _srf_slug, sclass
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
