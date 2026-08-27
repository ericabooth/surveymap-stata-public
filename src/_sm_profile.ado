*! version 0.5.0  27aug2026  Eric Booth
*! Read a profile() spec: a respondent-level condition to split the map by.
*!
*! A branch() gate splits the map by an ANSWER, so the lanes say what
*! Republicans did and what Democrats did.  A profile() gate splits it by
*! something the respondent DID while answering, so the lanes say what the
*! people who left a lot of items blank did.  The second kind of gate is
*! derived, was never a question anybody was asked, and every renderer says so
*! on the node itself.
*!
*! Accepted forms:
*!     profile(declined)               share of asked items left unanswered
*!     profile(declined = cut(10 25))  the same, banded at 10% and 25%
*!     profile(declined = q(4))        the same, quartile bands
*!     profile(asked = q(4))           how many items the respondent reached
*!
*! Two rules count coded answers and so need the survey's own codes named:
*!     profile(refused), refusedcode(.b)
*!     profile(dontknow), dkcode(.a)
*!
*! WHY A SHARE AND NOT A COUNT.  Skip logic asks different respondents
*! different numbers of questions, so a Democrat and a Republican on a
*! split-ballot instrument have different denominators.  A count of declines
*! is therefore not comparable between them and a share is, which is why the
*! share rules divide by the items each respondent was actually asked.  The
*! same rule is why an item a skip routed around is in neither the numerator
*! nor the denominator: counting a routed-around item as a decline would make
*! a well-behaved respondent on a long branch look like a bad one.  See NCES
*! Statistical Standard 1-3-5 and AAPOR Standard Definitions (10th ed., 2023),
*! which both define the item base as respondents minus valid skips.
*!
*! Returns (sclass):
*!     s(rule)   the condition name, already validated
*!     s(kind)   "share", "count" or "position"
*!     s(band)   "cut" or "q"
*!     s(parm)   the breaks for cut(), or the number of bands for q()
*!     s(vname)  the variable name the scan should build in its frame copy
*!     s(vlab)   the variable label that names the condition in the map
*!     s(deflt)  "1" when the banding is this program's default, not the
*!               user's, so the scan can say so in the journal
*!     s(caveat) the sentence that has to travel with this condition

program define _sm_profile, sclass
    version 16
    syntax , SPEC(string)

    sreturn clear
    local spec = strtrim(`"`spec'"')
    if `"`spec'"' == "" {
        di as err "profile(): needs a condition"
        _sm_prules
        exit 198
    }

    * split the rule from the banding, on the first = only
    local eq = strpos(`"`spec'"', "=")
    if `eq' {
        local rule = strtrim(substr(`"`spec'"', 1, `eq' - 1))
        local bspec = strtrim(substr(`"`spec'"', `eq' + 1, .))
    }
    else {
        local rule = strtrim(`"`spec'"')
        local bspec ""
    }
    local rule = strlower(`"`rule'"')

    * ---- conditions this refuses to build, and why -----------------------
    * Somebody will ask for these, so the refusal explains itself rather than
    * printing "unknown option".  Over-reporting is the clearest case: vote
    * validation studies (Ansolabehere and Hersh 2012, Political Analysis
    * 20:437-459) find that people who claim a vote they did not cast look
    * like voters on everything a survey observes, so a classifier built from
    * answers alone reproduces the demographics of voting and labels older,
    * better-educated, more engaged respondents as liars.  Separating the two
    * groups takes an external record or a design that plants the trap
    * (a list experiment, randomised response, or the over-claiming technique
    * of Paulhus et al. 2003), not a pattern in the responses.
    if inlist("`rule'", "exaggerator", "exaggerators", "faker", "fakers") | ///
       inlist("`rule'", "liar", "liars", "dishonest", "lying", "overreport") | ///
       inlist("`rule'", "overreporter", "overreporting", "socialdesirability") {
        di as err "profile(`rule'): this cannot be built from responses alone"
        di as err "    People who over-report a socially desirable answer resemble"
        di as err "    people who report it honestly on everything a survey records,"
        di as err "    so any flag built from the answers reproduces the profile of"
        di as err "    the behaviour rather than of the misreporting, and labels"
        di as err "    older, better-educated, more engaged respondents as liars."
        di as err "    Measuring it takes an external record to validate against, or"
        di as err "    an instrument designed for it: a list experiment, randomised"
        di as err "    response, or planted foils.  See Ansolabehere and Hersh (2012)"
        di as err "    and Tourangeau and Yan (2007)."
        di as err "    What this can show instead: profile(refused) and"
        di as err "    profile(dontknow), which say where answers were withheld."
        exit 198
    }
    if inlist("`rule'", "careless", "carelessness", "quality", "badrespondent") | ///
       inlist("`rule'", "straightlining", "straightliner", "ier", "cheater") {
        di as err "profile(`rule'): this is a verdict, not something the data shows"
        di as err "    Non-differentiation is measurable, but only inside a battery"
        di as err "    the analyst names, and only where answering the same way down"
        di as err "    the battery would be implausible: where it is plausible, 15 to"
        di as err "    40 percent of respondents produce one, against under 2 percent"
        di as err "    where it is implausible, and no index separates the two"
        di as err "    (Schonlau and Toepoel 2015).  It is also more common among"
        di as err "    respondents with less schooling, so a lane built on it is partly"
        di as err "    a lane built on education (Krosnick and Alwin 1988; Berinsky,"
        di as err "    Margolis and Sances 2014)."
        di as err "    This package does not ship it, because a survey file does not"
        di as err "    say which items share a scale."
        exit 198
    }

    * ---- the conditions it will build ------------------------------------
    if "`rule'" == "declined" {
        local kind "share"
        local vlab "% of asked items left unanswered"
        local caveat "a share of the items each respondent was asked; a high share is not by itself evidence of bias"
    }
    else if "`rule'" == "refused" {
        local kind "share"
        local vlab "% of asked items refused"
        local caveat "a share of the items each respondent was asked; refusal concentrates on sensitive questions, which is a different signal from don't know"
    }
    else if "`rule'" == "dontknow" {
        local kind "share"
        local vlab "% of asked items answered don't know"
        local caveat "a share of the items each respondent was asked; whether don't know was offered explicitly drives this rate more than respondents do"
    }
    else if "`rule'" == "asked" {
        local kind "count"
        local vlab "items the respondent reached"
        local caveat "a count of items reached, which is how far the routing carried each respondent"
    }
    else if "`rule'" == "answered" {
        local kind "count"
        local vlab "items the respondent answered"
        local caveat "a count, so it is not comparable across respondents the routing asked different numbers of questions"
    }
    else if "`rule'" == "breakoff" {
        local kind "position"
        local vlab "position of the last item answered"
        local caveat "consistent with abandonment at that point, which item data cannot separate from reaching the end and declining the last few items"
    }
    else {
        di as err `"profile(): "`rule'" is not a condition this can build"'
        _sm_prules
        exit 198
    }
    local vname "sm_`rule'"

    * ---- the banding -----------------------------------------------------
    * A condition needs bands, because one lane per distinct value is a map
    * nobody can read.  The default differs by kind, and in both cases the
    * journal records that the default, not the analyst, chose it.
    *
    * For a share the default splits at zero and nowhere else.  Zero is the
    * only boundary on this measure that is not a judgement call: a threshold
    * like "declined more than 20%" is a decision about what counts as a lot,
    * and AAPOR is explicit that such a boundary belongs to the researcher and
    * has to be declared, not supplied by software.
    local deflt = 0
    if `"`bspec'"' == "" {
        local deflt = 1
        if "`kind'" == "share" {
            local band "cut"
            local parm "0.00001"
        }
        else {
            local band "q"
            local parm "4"
        }
    }
    else {
        local bl = strlower(`"`bspec'"')
        if !regexm(`"`bl'"', "^(cut|q)[ ]*\(") {
            di as err `"profile(`rule'): could not read "`bspec'""'
            di as err "    band the condition with cut() or q(), for example"
            if "`kind'" == "share" di as err "        profile(`rule' = cut(10 25))   breaks in percentage points"
            else                   di as err "        profile(`rule' = cut(5 10))"
            di as err "        profile(`rule' = q(4))"
            exit 198
        }
        local band = regexs(1)
        local o1 = strpos(`"`bspec'"', "(")
        local o2 = strrpos(`"`bspec'"', ")")
        if !`o2' | `o2' < `o1' {
            di as err "profile(`rule'): `band'() is missing its closing bracket"
            exit 198
        }
        local inside = strtrim(substr(`"`bspec'"', `o1' + 1, `o2' - `o1' - 1))
        if `"`inside'"' == "" {
            di as err "profile(`rule'): `band'() needs a value"
            exit 198
        }
        if "`band'" == "cut" {
            * a count or a position is a whole number; a share is not
            if "`kind'" == "share" capture numlist `"`inside'"', sort range(>=0 <=100)
            else                   capture numlist `"`inside'"', sort integer
            if _rc {
                if "`kind'" == "share" {
                    di as err `"profile(`rule'): the breaks must be percentages between 0 and 100, not "`inside'""'
                    di as err "    cut(10 25) means none to under 10%, 10 to under 25%, 25% and over"
                }
                else {
                    di as err `"profile(`rule'): the breaks must be whole numbers, not "`inside'""'
                }
                exit 198
            }
            local parm `"`r(numlist)'"'
        }
        else {
            capture confirm integer number `inside'
            if _rc | `inside' < 2 | `inside' > 20 {
                di as err "profile(`rule'): q() takes a whole number of bands, 2 to 20"
                exit 198
            }
            local parm `inside'
        }
    }

    sreturn local rule   `"`rule'"'
    sreturn local kind   `"`kind'"'
    sreturn local band   `"`band'"'
    sreturn local parm   `"`parm'"'
    sreturn local vname  `"`vname'"'
    sreturn local vlab   `"`vlab'"'
    sreturn local deflt  `"`deflt'"'
    sreturn local caveat `"`caveat'"'
end

program define _sm_prules
    di as err "    the conditions are:"
    di as err "        declined   % of asked items the respondent left unanswered"
    di as err "        refused    % of asked items answered with a refusal code"
    di as err "        dontknow   % of asked items answered don't know"
    di as err "        asked      how many items the respondent reached"
    di as err "        answered   how many items the respondent answered"
    di as err "        breakoff   position of the last item answered"
    di as err "    refused and dontknow need the survey's codes named:"
    di as err "        profile(refused), refusedcode(.b)"
    di as err "        profile(dontknow), dkcode(99)"
end
