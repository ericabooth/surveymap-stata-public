# Stata traps every builder must respect (learned on mergemap, all verified)

1. Compound quotes: never expand a macro holding a lone quote char inside
   `"..."'; a stray `" or "' nests/closes and dies "too few quotes" r(132).
   Compare characters with substr(...) == char(96)+char(34) at expression
   level.  Scanner-style placeholder swaps must placeholder backtick, dollar
   AND the apostrophe.
2. -args cond label- splits parenthesized expressions at spaces: callers pass
   `=(expr)' pre-evaluated.
3. `frame F: local x `"`=var[i]'"'` expands =var[i] in the CURRENT frame and
   yields empty; use  frame F: local x = var[i]
4. frget silently skips a DESTINATION name starting with "_" (rc 0, nothing
   created).  Link frames by a generated row id, plain names (sm_row).
5. You cannot -frame drop- the frame you are inside (r(119)); set a flag,
   leave the block, then drop and exit.
6. Mata string literals have NO escapes: "\\" is two backslashes; use
   char(92).  No backticks or dollars inside mata blocks in ados.
7. import delimited varnames(1) silently renames a reserved-word header
   (using -> v9).  No reserved words as journal columns; read by name.
8. Journal fixtures in do-files: write backtick/quote chars with
   file write fh "save " _char(96) "hold" _char(39) _n   (a `=char(96)'
   inside a quoted string is re-scanned by the macro expander and collapses).
9. export excel: first sheet may take -replace-, later sheets need
   -sheetreplace- and NO -replace-.  putexcel set ..., modify + bold for
   header rows, always behind capture.
10. Absolute paths: leading "/" OR leading backslash (UNC \\server\share,
    root-relative \dir) OR drive letter colon.  Both separators when
    splitting basenames: max(strrpos(s,"/"), strrpos(s,char(92))).
11. In batch mode c(mode)=="batch": no auto-open of HTML.  _sm_open shells
    open/winexec cmd /c start/xdg-open on c(os); path travels in a global so
    the SMCL {stata} directive holds no quote, space or colon.
12. syntax [if] validates the expression against the data in memory -- do
    not declare [if] for expressions meant for a journal; parse by hand if
    ever needed.
13. mergemap run's dispatcher bug: never build an option list with a leading
    comma and then append it after another comma.
14. tempfile names are session-reused; a mkdir on a tempfile path needs
    retry suffixes.
15. -datasignature-/-cf- across .dta writes: header timestamps differ at
    minute resolution; never byte-compare .dta files.
16. Test assertions on HTML: <title> hover text keeps full phrases; assert
    drawn text with ">text" (inside a <text> element), not bare substrings.
17. Version-gate everything at version 16; test on BOTH binaries before
    calling anything done.
18. Value labels and variable labels belong to a DATASET, not to a session.
    A gate banded inside frame _smwork has its label only there, so
    `: value label x`, `: label lblname #` and `: variable label x` must all
    run inside the frame or they come back empty (or r(111) for a derived
    column that exists only in the copy).
19. -xtile- creates its own variable and refuses one that already exists;
    do not pre-generate the destination the way -replace- patterns suggest.
20. -confirm number- rejects extended missings (.a to .z).  Accept a
    refusal code with regexm(code, "^\.[a-z]$") OR confirm number, not
    confirm number alone.
21. Mermaid sibling-subgraph order is NOT controllable and NOT portable.
    Whether the layout engine keeps or reverses declaration order depends on
    the graph (a merge target changes it) and on the renderer: mermaid-cli
    11.16.0 and GitHub lay the SAME file out in opposite orders.  Do not
    compensate for one of them; declare lane 1 first, label every lane, and
    say in the docs that the HTML map and the twoway figure are the ones
    whose lane order is guaranteed because we lay them out ourselves.
22. A count is not comparable across respondents that skip logic asked
    different numbers of questions.  Anything respondent-level that counts
    items has to be divided by the items THAT respondent was asked, with
    system-missing (never shown) out of both numerator and denominator.
23. A mermaid subgraph's own `direction` is ignored the moment ANY node in
    it links outside the subgraph.  Every surveymap lane links out twice (up
    to the gate, down to the merge), so the per-lane direction line was dead
    code: the same map with the line present, absent, or set to the opposite
    direction renders byte-identical PNG and SVG on mermaid-cli 11.16.0.
24. Only a mermaid node ID named `end` breaks a flowchart; a quoted LABEL of
    "end" is fine, including immediately before a subgraph's closing `end`.
    The invariant that keeps this safe is that item names reach labels only,
    never IDs (ids are machine-generated n1 / n2v1), and labels are always
    quoted.  Do not relax either half.
25. `n1---o3` with no spaces is lexed as the `---o` circle-edge into a new
    node "3", not as a link to o3.  surveymap emits `-->` with spaces, so it
    is safe; anything that ever emits the bare `---` form must space it.
26. rankSpacing is NOT a free win.  Tightening it from 50 to 35 takes ~12% off
    the printed height, but on a map with lane subgraphs it pulls the fan
    edges down through the lane titles, drawing a line through
    "gate = category - n".  Measure legibility, not just pixel height: the
    probe that recommended it measured height and missed this.
27. Verify a citation before shipping it.  "Groves and Peytcheva (2008) found
    the nonresponse rate explains 11% of the variance in bias" conflated two
    real sources: the 59-study meta-analysis is theirs, but the 11% is
    Groves (2006), across 235 estimates in 30 studies.  Both halves were
    plausible and the sentence was wrong.
28. -graph export- to PNG can return 198 ("failed to export to the specified
    format") and leave a zero-byte file, for a graph that exports to SVG and
    PDF without complaint.  Observed on macOS console-mode (batch) Stata with
    text-heavy immediate-plot graphs (many text() elements over scatteri,
    pci, pcarrowi), at any item count.  The same twoway command rebuilt at
    the top level of a fresh session usually exports fine, and a graph save'd
    copy of the refused graph stays refused after graph use in a new session,
    so the refusal travels with the serialized graph rather than with the
    session.  The renderer works around it (0.4.5): vector first, trap the
    PNG, rebuild it from PDF via sips on a Mac.  While fixing it: GUI Stata
    reports c(os) = "MacOSX" but the console build reports "Unix"; a Mac test
    that must hold in batch mode has to read c(machine_type) instead.
29. -import delimited- GUESSES the encoding when none is named, and a
    mostly-ASCII journal with a few UTF-8 labels can read back as latin1,
    exploding every curly quote into mojibake.  Every journal read carries
    encoding("utf-8") explicitly; caught by the TVP vendor labels.
30. substr()/strlen() count BYTES.  Truncating label text with them can split
    a multibyte character and leave an invalid byte in the page.  Label cuts
    go through usubstr()/ustrlen()/ustrrpos(); cuts at ASCII delimiters found
    by strpos() are safe because the delimiter is single-byte.
31. No apostrophe in a journal flags string.  The text passes through macro
    quoting in every reader, and a lone quote aborts the run there -- the
    battery itself crash-truncated at the first flags string carrying
    "item's", silently reporting only the checks before the crash.  Check the
    completion banner, not just the FAIL count.
