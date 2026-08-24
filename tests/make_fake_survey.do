*! version 0.1.0  23aug2026  Eric Booth
*! make_fake_survey.do -- defines sm_makefake, which builds the pol2026
*! fixture described in tests/FAKE_SURVEY_SPEC.md.
*!
*! The fixture is a political survey with the missingness patterns a real
*! instrument produces, kept apart so a test can tell them from each other:
*!   system missing (.)  a respondent was never shown the item (skip logic)
*!   .a "Don't know"     shown, declined
*!   .b "Refused"        shown, declined
*! q13_income carries a heavy refusal rate and NO routing, which is the case
*! that separates "few answers" from "few people asked".
*!
*!     do make_fake_survey.do
*!     sm_makefake                          // 1,200 respondents in memory
*!     sm_makefake, n(600) saving(s.dta)    // smaller, and saved
*!
*! Deterministic: the same seed gives the same data on every machine and
*! both supported Stata versions.

capture program drop sm_makefake
program define sm_makefake
    version 16
    syntax [, N(integer 1200) SAVing(string) SEED(integer 20260823)]
    if `n' < 20 {
        di as err "n() must be at least 20 for the routing patterns to show"
        exit 198
    }

    clear
    set seed `seed'
    quietly set obs `n'

    * ---- value labels, including labels on the extended missings --------
    capture label drop sm_yn
    capture label drop sm_party
    capture label drop sm_vote
    capture label drop sm_why
    capture label drop sm_appr
    capture label drop sm_econ
    capture label drop sm_ideol
    capture label drop sm_inc
    label define sm_yn    1 "Yes" 0 "No" .a "Don't know" .b "Refused"
    label define sm_party 1 "Democrat" 2 "Republican" 3 "Independent"      ///
                          4 "Something else" .a "Don't know" .b "Refused"
    label define sm_vote  1 "Democratic candidate" 2 "Republican candidate" ///
                          3 "Third party" 4 "Left it blank"                 ///
                          .a "Don't know" .b "Refused"
    label define sm_why   1 "Too busy" 2 "Not registered" 3 "Did not like the choices" ///
                          4 "Illness or emergency" 5 "Other reason"         ///
                          .a "Don't know" .b "Refused"
    label define sm_appr  1 "Strongly approve" 2 "Somewhat approve"        ///
                          3 "Somewhat disapprove" 4 "Strongly disapprove"  ///
                          .a "Don't know" .b "Refused"
    label define sm_econ  1 "Excellent" 2 "Good" 3 "Only fair" 4 "Poor"    ///
                          5 "Very poor" .a "Don't know" .b "Refused"
    label define sm_ideol 1 "Very liberal" 2 "Liberal" 3 "Slightly liberal" ///
                          4 "Moderate" 5 "Slightly conservative"           ///
                          6 "Conservative" 7 "Very conservative"           ///
                          .a "Don't know" .b "Refused"
    label define sm_inc   1 "Under $15,000" 2 "$15,000 to $24,999"         ///
                          3 "$25,000 to $34,999" 4 "$35,000 to $49,999"    ///
                          5 "$50,000 to $74,999" 6 "$75,000 to $99,999"    ///
                          7 "$100,000 to $149,999" 8 "$150,000 to $199,999" ///
                          9 "$200,000 or more" .a "Don't know" .b "Refused"

    * ---- identifiers and frame ------------------------------------------
    quietly gen long resp_id = _n
    label variable resp_id "Respondent id"

    quietly gen str2 st = ""
    quietly replace st = "TX" if runiform() < .30
    quietly replace st = "CA" if st == "" & runiform() < .30
    quietly replace st = "FL" if st == "" & runiform() < .35
    quietly replace st = "NY" if st == "" & runiform() < .40
    quietly replace st = "OH" if st == ""
    label variable st "State of residence"

    * ---- q1 consent: the hard gate --------------------------------------
    quietly gen byte q1_consent = runiform() >= .03
    label variable q1_consent "Consented to be interviewed"
    label values q1_consent sm_yn
    quietly count if q1_consent == 1
    local ncons = r(N)

    * everything below is asked of consenters only; a refusal at q1 leaves
    * the rest system missing, which is what routing looks like in data
    tempvar u
    quietly gen double `u' = .

    * ---- q2 age ----------------------------------------------------------
    quietly gen int q2_age = .
    quietly replace `u' = runiform()
    quietly replace q2_age = 18 + floor(runiform() * 73) if q1_consent == 1
    quietly replace q2_age = .b if q1_consent == 1 & `u' < .02
    label variable q2_age "Age in years"

    * ---- q3 party: the key gate -----------------------------------------
    quietly gen byte q3_party = .
    quietly replace `u' = runiform()
    quietly replace q3_party = 1 if q1_consent == 1 & `u' < .36
    quietly replace q3_party = 2 if q1_consent == 1 & `u' >= .36 & `u' < .69
    quietly replace q3_party = 3 if q1_consent == 1 & `u' >= .69 & `u' < .90
    quietly replace q3_party = 4 if q1_consent == 1 & `u' >= .90
    quietly replace `u' = runiform()
    quietly replace q3_party = .a if q1_consent == 1 & `u' < .04
    quietly replace q3_party = .b if q1_consent == 1 & `u' >= .04 & `u' < .07
    label variable q3_party "Party identification"
    label values q3_party sm_party

    * ---- q4 registered ---------------------------------------------------
    quietly gen byte q4_reg = .
    quietly replace `u' = runiform()
    quietly replace q4_reg = `u' < .82 if q1_consent == 1
    label variable q4_reg "Registered to vote at this address"
    label values q4_reg sm_yn

    * ---- q5 voted: the second gate --------------------------------------
    quietly gen byte q5_voted = .
    quietly replace `u' = runiform()
    quietly replace q5_voted = `u' < .66 if q1_consent == 1
    quietly replace q5_voted = 0 if q1_consent == 1 & q4_reg == 0 & `u' < .90
    quietly replace `u' = runiform()
    quietly replace q5_voted = .a if q1_consent == 1 & `u' < .02
    label variable q5_voted "Voted in the 2024 general election"
    label values q5_voted sm_yn

    * ---- q6 / q7: routed by q5 ------------------------------------------
    quietly gen byte q6_whovote = .
    quietly replace `u' = runiform()
    quietly replace q6_whovote = 1 if q5_voted == 1 & `u' < .47
    quietly replace q6_whovote = 2 if q5_voted == 1 & `u' >= .47 & `u' < .92
    quietly replace q6_whovote = 3 if q5_voted == 1 & `u' >= .92 & `u' < .97
    quietly replace q6_whovote = 4 if q5_voted == 1 & `u' >= .97
    quietly replace `u' = runiform()
    quietly replace q6_whovote = .b if q5_voted == 1 & `u' < .04
    label variable q6_whovote "Vote choice for president in 2024"
    label values q6_whovote sm_vote

    quietly gen byte q7_whynot = .
    quietly replace `u' = runiform()
    quietly replace q7_whynot = 1 + floor(`u' * 5) if q5_voted == 0
    quietly replace `u' = runiform()
    quietly replace q7_whynot = .a if q5_voted == 0 & `u' < .05
    label variable q7_whynot "Main reason for not voting"
    label values q7_whynot sm_why

    * ---- q8 / q9: asked of all consenters, correlated with party --------
    quietly gen byte q8_approve = .
    quietly replace `u' = runiform()
    quietly replace q8_approve = 1 + floor(`u' * 4) if q1_consent == 1
    quietly replace q8_approve = 1 + floor(`u' * 2) if q1_consent == 1 & q3_party == 2
    quietly replace q8_approve = 3 + floor(`u' * 2) if q1_consent == 1 & q3_party == 1
    quietly replace `u' = runiform()
    quietly replace q8_approve = .a if q1_consent == 1 & `u' < .06
    quietly replace q8_approve = .b if q1_consent == 1 & `u' >= .06 & `u' < .08
    label variable q8_approve "Approval of the governor"
    label values q8_approve sm_appr

    quietly gen byte q9_econ = .
    quietly replace `u' = runiform()
    quietly replace q9_econ = 1 + floor(`u' * 5) if q1_consent == 1
    quietly replace `u' = runiform()
    quietly replace q9_econ = .a if q1_consent == 1 & `u' < .05
    label variable q9_econ "Rating of economic conditions today"
    label values q9_econ sm_econ

    * ---- q10 / q11: routed by q3_party ----------------------------------
    * asked of Democrats and Independents; Republicans and Something else
    * are routed around it
    quietly gen byte q10_dem_prim = .
    quietly replace `u' = runiform()
    quietly replace q10_dem_prim = `u' < .58 if inlist(q3_party, 1, 3)
    quietly replace `u' = runiform()
    quietly replace q10_dem_prim = .a if inlist(q3_party, 1, 3) & `u' < .03
    label variable q10_dem_prim "Plans to vote in the Democratic primary"
    label values q10_dem_prim sm_yn

    * asked of Republicans and Independents
    quietly gen byte q11_rep_prim = .
    quietly replace `u' = runiform()
    quietly replace q11_rep_prim = `u' < .61 if inlist(q3_party, 2, 3)
    quietly replace `u' = runiform()
    quietly replace q11_rep_prim = .a if inlist(q3_party, 2, 3) & `u' < .03
    label variable q11_rep_prim "Plans to vote in the Republican primary"
    label values q11_rep_prim sm_yn

    * ---- q12 ideology ----------------------------------------------------
    quietly gen byte q12_ideol = .
    quietly replace `u' = runiform()
    quietly replace q12_ideol = 1 + floor(`u' * 7) if q1_consent == 1
    quietly replace q12_ideol = 4 + floor(`u' * 4) if q1_consent == 1 & q3_party == 2
    quietly replace q12_ideol = 1 + floor(`u' * 4) if q1_consent == 1 & q3_party == 1
    quietly replace `u' = runiform()
    quietly replace q12_ideol = .a if q1_consent == 1 & `u' < .04
    quietly replace q12_ideol = .b if q1_consent == 1 & `u' >= .04 & `u' < .07
    label variable q12_ideol "Ideological self-placement"
    label values q12_ideol sm_ideol

    * ---- q13 income: heavy refusal, NO routing --------------------------
    * the case that separates a low answer rate from a routed-around item
    quietly gen byte q13_income = .
    quietly replace `u' = runiform()
    quietly replace q13_income = 1 + floor(`u' * 9) if q1_consent == 1
    quietly replace `u' = runiform()
    quietly replace q13_income = .b if q1_consent == 1 & `u' < .18
    label variable q13_income "Total household income last year"
    label values q13_income sm_inc

    * ---- q14 zip: a string item with blanks -----------------------------
    quietly gen str5 q14_zip = ""
    quietly replace `u' = runiform()
    quietly replace q14_zip = string(75000 + floor(runiform() * 4000), "%05.0f") ///
        if q1_consent == 1 & `u' >= .10
    label variable q14_zip "ZIP code of residence"

    quietly drop `u'
    quietly compress
    label data "pol2026 fake survey fixture (surveymap)"

    if `"`saving'"' != "" {
        * a fixture generator overwrites its own output: re-running it is the
        * normal case, and refusing would make a test suite order-dependent
        quietly save `"`saving'"', replace
    }
    di as txt "sm_makefake: " as res "`n'" as txt " respondents, " ///
        as res "`ncons'" as txt " consented, 16 columns"
end
