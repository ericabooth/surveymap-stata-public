# surveymap: g_branched.tsv - mermaid flow, LR

Items run left to right in questionnaire order; a gate fans the sample into lanes that rejoin the spine at the end of its segment. A dashed node is a cell the lane was routed around. `!!` marks a warning.

*surveymap _sm_rendertext 0.1.0 - journal g_branched.tsv - rendered 27 Aug 2026 17:09:30 - Stata 19.5 MP*

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'14px','primaryColor':'#ffffff','primaryTextColor':'#202020','primaryBorderColor':'#606060','lineColor':'#606060','secondaryColor':'#f4f4f4','tertiaryColor':'#fafafa','edgeLabelBackground':'#ffffff','titleColor':'#202020'},'flowchart':{'curve':'linear'}}}%%
%% surveymap _sm_rendertext 0.1.0 - journal g_branched.tsv - rendered 27 Aug 2026 17:09:30 - Stata 19.5 MP
flowchart LR
  accTitle: surveymap flow of g_branched.tsv
  accDescr {
    1,161 respondents, 12 items, 2 gates. Items run left to right in questionnaire order; a gate fans the sample into lanes that rejoin the spine at the end of its segment. A dashed node is a cell the lane was routed around. Two exclamation marks flag a warning. Counts are unweighted and percentages are weighted.
  }
  classDef default fill:#ffffff,stroke:#5a5a5a,color:#1a1a1a,stroke-width:1px;
  classDef smghost fill:#fbfbfb,stroke:#b0b0b0,stroke-dasharray: 5 4,color:#8a8a8a,stroke-width:1px;
  classDef smwarn fill:#ffffff,stroke:#4a6d8c,stroke-width:2px,color:#1a1a1a;
  classDef smgate fill:#eef2f6,stroke:#4a6d8c,stroke-width:1.5px,color:#1a1a1a;
  n1["q1_consent<br/>1,161 (100.0%)"]
  n2{{"q3_party<br/>1,074 (94.5%)<br/>!! nonresp 87"}}
  n3["q4_reg<br/>1,161 (100.0%)"]
  n4{{"q5_voted<br/>1,133 (97.7%)"}}
  subgraph SG4x1["q5_voted = No · 533"]
  n5v1["q6_whovote<br/>skipped"]
  n6v1["q7_whynot<br/>507 (95.2%)"]
  end
  subgraph SG4x2["q5_voted = Yes · 600"]
  n5v2["q6_whovote<br/>578 (96.6%)"]
  n6v2["q7_whynot<br/>skipped"]
  end
  subgraph SG4x3["q5_voted = other (pooled) · 28"]
  n5v3["q6_whovote<br/>skipped"]
  n6v3["q7_whynot<br/>skipped"]
  end
  n7["q8_approve<br/>1,053 (90.9%)<br/>!! nonresp 108"]
  n8["q9_econ<br/>1,088 (93.3%)<br/>!! nonresp 73"]
  subgraph SG2x1["q3_party = Democrat · 384"]
  n9v1["q10_dem_prim<br/>375 (97.7%)"]
  n10v1["q11_rep_prim<br/>skipped"]
  end
  subgraph SG2x2["q3_party = Republican · 352"]
  n9v2["q10_dem_prim<br/>skipped"]
  n10v2["q11_rep_prim<br/>342 (97.2%)"]
  end
  subgraph SG2x3["q3_party = Independent · 229"]
  n9v3["q10_dem_prim<br/>216 (94.3%)"]
  n10v3["q11_rep_prim<br/>224 (97.8%)"]
  end
  subgraph SG2x4["q3_party = other (pooled) · 109"]
  n9v4["q10_dem_prim<br/>skipped"]
  n10v4["q11_rep_prim<br/>skipped"]
  end
  subgraph SG2x5["q3_party = no answer · 87"]
  n9v5["q10_dem_prim<br/>skipped"]
  n10v5["q11_rep_prim<br/>skipped"]
  end
  n11["q12_ideol<br/>1,081 (92.7%)<br/>!! nonresp 80"]
  n12["q13_income<br/>941 (80.8%)<br/>!! nonresp 220"]
  n1 --> n2
  n2 --> n3
  n3 --> n4
  n4 --> n5v1
  n5v1 --> n6v1
  n6v1 --> n7
  n4 --> n5v2
  n5v2 --> n6v2
  n6v2 --> n7
  n4 --> n5v3
  n5v3 --> n6v3
  n6v3 --> n7
  n7 --> n8
  n8 --> n9v1
  n9v1 --> n10v1
  n10v1 --> n11
  n8 --> n9v2
  n9v2 --> n10v2
  n10v2 --> n11
  n8 --> n9v3
  n9v3 --> n10v3
  n10v3 --> n11
  n8 --> n9v4
  n9v4 --> n10v4
  n10v4 --> n11
  n8 --> n9v5
  n9v5 --> n10v5
  n10v5 --> n11
  n11 --> n12
  class n4 smgate;
  class n5v1,n6v2,n5v3,n6v3,n10v1,n9v2,n9v4,n10v4,n9v5,n10v5 smghost;
  class n2,n7,n8,n11,n12 smwarn;
```
