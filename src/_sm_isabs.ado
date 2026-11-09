*! version 0.8.4  09nov2026  Eric Booth
*! _sm_isabs -- is this path absolute?  Returns the answer in r(abs), 1 or 0.
*!
*! Absolute on any platform surveymap supports:
*!   /project/data.dta          unix and macOS
*!   C:\project\data.dta        Windows, drive letter in position 2
*!   \\server\share\data.dta    Windows UNC share
*!   \project\data.dta          Windows, root of the current drive
*!   ~/project/data.dta         the home folder; r(path) holds it expanded
*!
*! r(path) is the path with a leading ~ expanded (unchanged otherwise).
*!
*! The UNC and root-relative forms were the ones that got missed: a path
*! starting with a backslash looks relative to a test that only checks for a
*! leading slash and a drive letter, so it was sent back through c(pwd) and
*! came out as a path that opens nothing.

program define _sm_isabs, rclass
    version 16
    gettoken p 0 : 0
    local p = strtrim(`"`p'"')
    local a = 0
    * A leading ~ is the home folder.  Stata's file commands expand it, but
    * a path that is pasted after c(pwd) or handed to the shell inside
    * quotes is not, so expand it here and return the result in r(path).
    if `"`p'"' == "~" | substr(`"`p'"', 1, 2) == "~/" |                   ///
        substr(`"`p'"', 1, 2) == "~" + char(92) {
        local h : env HOME
        if "`c(os)'" == "Windows" {
            local h : env USERPROFILE
            if `"`h'"' == "" {
                local hd : env HOMEDRIVE
                local hp : env HOMEPATH
                local h `"`hd'`hp'"'
            }
            if `"`h'"' == "" local h : env HOME
        }
        if `"`h'"' != "" {
            local p `"`h'`=substr(`"`p'"', 2, .)'"'
            local a = 1
        }
    }
    if substr(`"`p'"', 1, 1) == "/"       local a = 1
    if substr(`"`p'"', 1, 1) == char(92)  local a = 1
    if substr(`"`p'"', 2, 1) == ":"       local a = 1
    return scalar abs = `a'
    return local path `"`p'"'
end
