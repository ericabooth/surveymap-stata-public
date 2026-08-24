# Fake survey fixture: pol2026 (n = 1,200, seed 20260823)

One row per respondent, columns in questionnaire order.  Every item has a
variable label; every categorical item has value labels, including labels on
.a "Don't know" and .b "Refused".  Written by tests/make_fake_survey.do
(program sm_makefake, callable with n() and saving()) and, in compact form,
by surveymap demo.

| var | label | values | routing / missingness |
|---|---|---|---|
| resp_id | Respondent id | 1..N | never mapped (id) |
| st | State (string) | "TX" "CA" ... | string item: answered-only stats |
| q1_consent | Consented to interview | 1 yes, 0 no | ~3% no; 0 routes around EVERYTHING after (hard gate) |
| q2_age | Age in years | 18-90 | continuous; ~2% .b |
| q3_party | Party identification | 1 Dem 2 Rep 3 Ind 4 Other | ~4% .a, ~3% .b; KEY GATE |
| q4_reg | Registered to vote | 1 yes 0 no | asked of all consenters |
| q5_voted | Voted in 2024 | 1 yes 0 no | ~2% .a; GATE |
| q6_whovote | 2024 vote choice | 1..4 | ONLY q5_voted==1; else sysmiss |
| q7_whynot | Main reason did not vote | 1..5 | ONLY q5_voted==0; else sysmiss |
| q8_approve | Approves of the governor | 1..4 | all consenters; ~6% .a, ~2% .b; correlated with party |
| q9_econ | Economy rating | 1..5 | all; ~5% .a |
| q10_dem_prim | Will vote in the Dem primary | 1 0 | ONLY q3_party==1 or 3; else sysmiss |
| q11_rep_prim | Will vote in the Rep primary | 1 0 | ONLY q3_party==2 or 3; else sysmiss |
| q12_ideol | Ideology | 1..7 | all; ~7% .a+.b |
| q13_income | Household income bracket | 1..9 | all; ~18% .b (REFUSAL, not routing) |
| q14_zip | ZIP (string) | 5-digit strings | ~10% "" |

Truths the battery asserts:
- q6 gated_by contains q5_voted==0 (and q1_consent==0); q7 by q5_voted==1.
- q10 gated_by q3_party==2 4 (Reps and Other routed around it); q11 by 1 4.
- q13_income shows LOW pct_answered but NO gated_by (refusal is nonresponse,
  not routing).
- branch(q3_party = 1 2 3) pools 4 into other; noanswer lane = .a+.b on q3.
- Lane counts sum to the survey n on every gate.
