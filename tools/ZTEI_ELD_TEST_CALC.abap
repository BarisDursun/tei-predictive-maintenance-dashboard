REPORT ztei_eld_test_calc.

" Parca omur tahminini calistir ve tabloyu ekrana bas
DATA(lt_forecast) = zcl_tei_eld_forecast=>calculate_forecast( ).
cl_demo_output=>display( lt_forecast ).

" EGT marjin trendini calistir ve tabloyu ekrana bas
DATA(lt_trend) = zcl_tei_eld_egt_trend=>calculate_trend( ).
cl_demo_output=>display( lt_trend ).
