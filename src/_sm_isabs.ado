*! version 0.4.0  24aug2026  Eric Booth
*! _sm_isabs -- is this path absolute?  Returns the answer in r(abs), 1 or 0.
*!
*! Absolute on any platform surveymap supports:
*!   /project/data.dta          unix and macOS
*!   C:\project\data.dta        Windows, drive letter in position 2
*!   \\server\share\data.dta    Windows UNC share
*!   \project\data.dta          Windows, root of the current drive
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
    if substr(`"`p'"', 1, 1) == "/"       local a = 1
    if substr(`"`p'"', 1, 1) == char(92)  local a = 1
    if substr(`"`p'"', 2, 1) == ":"       local a = 1
    return scalar abs = `a'
end
