*! version 0.6.0  27aug2026  Eric Booth
*! _sm_draw -- dispatcher behind -surveymap draw-.  Resolves which journal to
*! draw, picks the renderer from export(), applies the read-time prune rules,
*! and handles the open-in-browser courtesy for HTML output.
*!
*! Journal resolution, in order: an explicit file on the command line (a
*! leading -using- token is accepted and ignored), then the journal the last
*! surveymap scan wrote in this session (a global, so it survives
*! -clear all-), then survey_journal.tsv in the working directory.
*!
*! Pruning happens here, on the journal, before any renderer sees it
*! (_sm_jprune): the journal keeps every category, so prune()/minn()/
*! maxcats()/noprune can change at draw time without a rescan.  name() is
*! forwarded so a pruned tempfile copy still shows the real journal name.

program define _sm_draw, rclass
    version 16
    syntax [anything(name=jspec)] [, EXPort(string) SAVing(string)          ///
        LAYout(string) PRUNE(real -1) MINN(integer -1) MAXCats(integer -1)  ///
        NOPRUNE NAME(string) NOOPen EMBed MAXnodes(integer -1) replace]

    * ---- which journal --------------------------------------------------
    gettoken w1 rest : jspec
    if `"`w1'"' == "using" local jspec `"`rest'"'
    gettoken jfile rest : jspec
    if strtrim(`"`rest'"') != "" {
        di as err `"surveymap draw: did not understand `rest'"'
        di as err "    syntax is: surveymap draw [journal] [, options]"
        exit 198
    }
    if `"`jfile'"' == "" local jfile `"$SM_LASTJ"'
    if `"`jfile'"' == "" {
        capture confirm file "survey_journal.tsv"
        if !_rc local jfile "survey_journal.tsv"
    }
    if `"`jfile'"' == "" {
        di as err "surveymap draw: no journal to draw."
        di as err "    Scan something first (surveymap [varlist]), or name a"
        di as err "    journal file: surveymap draw myjournal.tsv"
        exit 601
    }
    capture confirm file `"`jfile'"'
    if _rc {
        di as err `"surveymap draw: journal `jfile' not found"'
        exit 601
    }

    * ---- which renderer -------------------------------------------------
    if `"`export'"' == "" local export "html"
    local export = strlower(`"`export'"')
    if !inlist("`export'", "html", "mermaid", "png", "svg") {
        di as err "surveymap draw: export() must be html, mermaid, png or svg"
        exit 198
    }

    * ---- layout ---------------------------------------------------------
    * A questionnaire is a sequence, so it reads either way.  Left to right
    * suits a slide and a wide screen; top to bottom suits a report page, a
    * phone, and a long instrument, because a page scrolls down and a survey
    * of forty items is taller than any screen is wide.
    if `"`layout'"' == "" local layout "horizontal"
    local layout = strlower(`"`layout'"')
    if inlist("`layout'", "h", "horiz", "lr") local layout "horizontal"
    if inlist("`layout'", "v", "vert", "tb", "td") local layout "vertical"
    if !inlist("`layout'", "horizontal", "vertical") {
        di as err "surveymap draw: layout() must be horizontal or vertical"
        exit 198
    }

    * ---- a paths journal draws with the flow renderer -------------------
    * pnode rows mark a journal -surveymap paths- wrote; its map is the
    * response braid, which only the html renderer draws
    local ispaths = 0
    tempname PJ
    frame create `PJ'
    frame `PJ' {
        capture quietly import delimited using `"`jfile'"', delimiter(tab) ///
            varnames(1) stringcols(_all) encoding("utf-8") clear
        capture confirm variable class
        if !_rc {
            quietly count if class == "pnode"
            if r(N) > 0 local ispaths = 1
        }
    }
    frame drop `PJ'
    if `ispaths' {
        if "`export'" != "html" {
            di as err "surveymap draw: a paths journal draws as html only"
            di as err "    surveymap draw `jfile', export(html) saving(...)"
            exit 198
        }
        local hf `"`saving'"'
        if `"`hf'"' == "" local hf "surveymap_paths.html"
        if strlower(substr(`"`hf'"', -5, .)) != ".html" local hf `"`hf'.html"'
        local no ""
        if `"`name'"' != "" local no `"name(`name')"'
        _sm_renderflow using `"`jfile'"', saving(`"`hf'"') `no' `embed' `replace'
        return local journal `"`jfile'"'
        return local output `"`s(out)'"'
        local abs `"`hf'"'
        _sm_isabs `"`abs'"'
        if !r(abs) local abs `"`c(pwd)'/`hf'"'
        global SM_LASTOUT `"`abs'"'
        di as txt `"    {stata _sm_open:Open the map in your browser}"'
        di as txt `"    `abs'"'
        if "`noopen'" == "" & "`c(mode)'" != "batch" & "`c(console)'" == "" {
            capture _sm_open
        }
        exit
    }

    * ---- prune the journal before any renderer sees it ------------------
    local po ""
    if `prune'   >= 0 local po `"`po' prune(`prune')"'
    if `minn'    >= 0 local po `"`po' minn(`minn')"'
    if `maxcats' >= 0 local po `"`po' maxcats(`maxcats')"'
    local jorig `"`jfile'"'
    _sm_jprune using `"`jfile'"', `po' `noprune'
    local jfile  `"`s(jfile)'"'
    local nfold  = `s(n_folded)'
    return local journal `"`jfile'"'
    return scalar folded = `nfold'
    * the page and the mermaid header name the journal; when a pruned copy
    * is drawn they should still name the journal you gave
    local jname `"`jorig'"'
    local p = max(strrpos(`"`jname'"', "/"), strrpos(`"`jname'"', char(92)))
    if `p' local jname = substr(`"`jname'"', `p' + 1, .)
    if `"`name'"' != "" local jname `"`name'"'

    * ---- html -----------------------------------------------------------
    if "`export'" == "html" {
        local hf `"`saving'"'
        if `"`hf'"' == "" local hf "surveymap_map.html"
        _sm_draw_html `"`jfile'"' `"`hf'"' `"`jname'"' "`embed'" "`replace'" "`noopen'" "`layout'"
        return local output `"`s(out)'"'
        exit
    }

    * ---- png / svg: one figure, through Stata's own graph engine -------
    * png and svg come from the same twoway call, so asking for either
    * writes both and the caller keeps whichever it needs
    if inlist("`export'", "png", "svg") {
        local stub `"`saving'"'
        if `"`stub'"' == "" local stub "surveymap_map"
        local o `"`replace'"'
        if `"`nameopt'"' != "" local o `"`o' `nameopt'"'
        if `maxnodes' >= 0 local o `"`o' maxnodes(`maxnodes')"'
        _sm_rendertw using `"`jfile'"', saving(`"`stub'"') `o'
        return local output `"`stub'.`export'"'
        exit
    }

    * ---- mermaid --------------------------------------------------------
    local stub `"`saving'"'
    if `"`stub'"' == "" local stub "surveymap_map"
    _sm_rendertext using `"`jfile'"', saving(`"`stub'"') name(`jname') ///
        layout(`layout') `replace'
    return local output `"`stub'.mmd"'
end

* ---------------------------------------------------------------- html leg
* Writes the page (or fragment), prints a clickable link, and opens the
* system browser in GUI sessions unless noopen.  An embed fragment is not a
* standalone page, so it gets the path only, never an auto-open.
program define _sm_draw_html, sclass
    args jfile hf jname embed replace noopen layout
    if strlower(substr(`"`hf'"', -5, .)) != ".html" local hf `"`hf'.html"'
    _sm_renderhtml using `"`jfile'"', saving(`"`hf'"') name(`jname') ///
        layout(`layout') `embed' `replace'
    sreturn local out `"`hf'"'
    if "`embed'" != "" {
        di as txt `"surveymap draw: fragment written; drop it into your page's body"'
        exit
    }
    * absolute path, so the link still resolves after the user changes
    * directory.  Note the missing-file case also gets an absolute path:
    * only absolutising when the file existed left a relative path in the
    * link on the one occasion it mattered.
    local abs `"`hf'"'
    _sm_isabs `"`abs'"'
    if !r(abs) local abs `"`c(pwd)'/`hf'"'
    global SM_LASTOUT `"`abs'"'
    * A {stata ...} link runs a Stata command.  Do NOT go back to
    * {browse "file://..."}: SMCL hands that to the platform URL parser, and
    * on macOS it throws inside NSURLComponents and aborts Stata outright.
    di as txt `"    {stata _sm_open:Open the map in your browser}"'
    di as txt `"    `abs'"'
    * auto-open where a handler can exist: GUI, not batch or console
    if "`noopen'" == "" & "`c(mode)'" != "batch" & "`c(console)'" == "" {
        capture _sm_open
    }
end
