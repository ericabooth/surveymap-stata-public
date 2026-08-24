*! version 0.2.0  23aug2026  Eric Booth
*! _sm_branch -- parse the branch() spec of -surveymap- into gates.
*!
*! Accepted forms, comma separated inside one branch():
*!     party                 every category of party becomes a lane
*!     party = 1 3 4         only these categories; the rest pool into other
*!     party = 1/3 5         numlists expand
*!     party = 1 3, voted = 1    two gates in one option
*!
*! A gate must be a numeric variable that exists in the data: survey gates
*! are coded, and a string gate would make one lane per distinct answer.
*! A string gate is declined with a warning and the scan carries on, because
*! a bad gate is not a reason to lose the rest of the map.
*!
*! syntax:  _sm_branch , spec(string asis)
*! returns: s(n)       number of gates parsed
*!          s(gate`i') the i-th gate variable name
*!          s(vals`i') its kept values, space separated ("" = every category)
*!          s(gates)   all gate names, space separated, in the order given
*!          s(skipped) gates declined, with the reason, "; " separated

program define _sm_branch, sclass
    version 16
    syntax , SPEC(string asis)
    sreturn clear
    sreturn local n = 0
    sreturn local gates ""
    sreturn local skipped ""

    local spec = strtrim(`"`spec'"')
    * asis keeps whatever quoting the caller used; a spec wrapped in quotes
    * would otherwise reach -confirm variable- with the quotes attached.
    * Stripped inline: a helper program's -sreturn clear- would wipe the
    * gate results this program accumulates in s() across the loop.
    if substr(`"`spec'"', 1, 1) == char(34) & substr(`"`spec'"', -1, 1) == char(34) {
        local spec = substr(`"`spec'"', 2, strlen(`"`spec'"') - 2)
    }
    if `"`spec'"' == "" exit

    local ng = 0
    local names ""
    local skip ""
    local rest `"`spec'"'
    while `"`rest'"' != "" {
        * one spec runs to the next top-level comma
        local p = strpos(`"`rest'"', ",")
        if `p' {
            local one = substr(`"`rest'"', 1, `p' - 1)
            local rest = substr(`"`rest'"', `p' + 1, .)
        }
        else {
            local one `"`rest'"'
            local rest ""
        }
        local one = strtrim(`"`one'"')
        if `"`one'"' == "" continue

        * split on the first =; anything after is the kept-value list
        local q = strpos(`"`one'"', "=")
        if `q' {
            local gv  = strtrim(substr(`"`one'"', 1, `q' - 1))
            local vl  = strtrim(substr(`"`one'"', `q' + 1, .))
        }
        else {
            local gv `"`one'"'
            local vl ""
        }

        * a second = is a typo, not a numlist
        if strpos(`"`vl'"', "=") {
            di as err `"branch(): could not read "`one'""'
            di as err "    the form is  branch(var)  or  branch(var = 1 3 4),"
            di as err "    with a comma between gates"
            exit 198
        }
        if `"`gv'"' == "" {
            di as err `"branch(): a gate variable name is missing in "`one'""'
            exit 198
        }
        * one token only on the left of the =
        local nw : word count `gv'
        if `nw' > 1 {
            di as err `"branch(): "`gv'" is not one variable name"'
            di as err "    separate gates with a comma: branch(a = 1, b = 2)"
            exit 198
        }

        if substr(`"`gv'"', 1, 1) == char(34) & substr(`"`gv'"', -1, 1) == char(34) {
            local gv = substr(`"`gv'"', 2, strlen(`"`gv'"') - 2)
        }
        capture confirm variable `gv'
        if _rc {
            di as err `"branch(): variable `gv' not found"'
            exit 111
        }
        capture confirm numeric variable `gv'
        if _rc {
            * a string gate would make one lane per distinct answer, which is
            * not a branch; say so and carry on with the other gates
            di as txt "surveymap: branch(`gv') skipped, a string variable is " ///
                "not a survey gate;"
            di as txt "           recode it, or gate on the coded item"
            local skip `"`skip'`=cond(`"`skip'"' == "", "", "; ")'`gv' (string)"'
            continue
        }

        * expand the kept-value list
        local keep ""
        if `"`vl'"' != "" {
            capture numlist `"`vl'"', integer
            if _rc {
                di as err `"branch(`gv'): could not read the value list "`vl'""'
                di as err "    values are integers or ranges: 1 3 4, or 1/3 5"
                exit 198
            }
            local keep `"`r(numlist)'"'
        }

        * a gate named twice keeps the first spec
        local dup = 0
        foreach nm of local names {
            if "`nm'" == "`gv'" local dup = 1
        }
        if `dup' {
            di as txt "surveymap: branch(`gv') named more than once; the first spec is used"
            continue
        }

        local ++ng
        local names `"`names' `gv'"'
        sreturn local gate`ng' `"`gv'"'
        sreturn local vals`ng' `"`keep'"'
    }

    sreturn local n = `ng'
    sreturn local gates `"`=strtrim(`"`names'"')'"'
    sreturn local skipped `"`skip'"'
end
