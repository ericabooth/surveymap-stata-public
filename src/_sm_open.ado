*! version 0.4.0  24aug2026  Eric Booth
*! _sm_open -- open a file surveymap just wrote, using the operating system's
*! own handler.  Called from the click-to-run link that -surveymap draw- prints
*! after writing an HTML page.
*!
*! Why a shell command rather than SMCL's {browse}: {browse} hands its target
*! to the platform's URL machinery, and on macOS a file:// URL passed that way
*! throws an uncaught exception inside NSURLComponents and takes Stata down
*! with it (verified on StataNow 19.5, macOS 26.5).  {stata ...} links run a
*! Stata command instead, which never reaches that code path.

program define _sm_open
    version 16
    gettoken f 0 : 0, parse(",")
    local f = subinstr(`"`f'"', `"""', "", .)
    local f = strtrim(`"`f'"')
    if `"`f'"' == "" local f `"$SM_LASTOUT"'
    if `"`f'"' == "" {
        di as err "surveymap: nothing to open yet"
        exit 198
    }
    capture confirm file `"`f'"'
    if _rc {
        di as err `"surveymap: `f' not found"'
        exit 601
    }
    * absolute path, so the handler resolves it whatever the working directory.
    _sm_isabs `"`f'"'
    if !r(abs) local f `"`c(pwd)'/`f'"'
    local q = char(34)
    if "`c(os)'" == "MacOSX" {
        shell open `q'`f'`q'
    }
    else if "`c(os)'" == "Windows" {
        winexec cmd /c start "" `q'`f'`q'
    }
    else {
        shell xdg-open `q'`f'`q' &
    }
end
