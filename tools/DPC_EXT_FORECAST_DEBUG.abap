"====================================================================
" TANI KODU - 2. adim. IT_KEY_TAB dogru geldigi kanitlandi
" (EngineSn='Enginesn', NodeId='TS1400-DUR1'). Simdi CALCULATE_FORECAST'i
" bu degerle DOGRUDAN cagirip kac satir dondugunu goruyoruz.
"====================================================================

METHOD forecastset_get_entityset.

  DATA(lv_test_sn) = CONV ztei_eld_engine-engine_sn( it_key_tab[ 1 ]-value ).
  DATA(lt_test) = zcl_tei_eld_forecast=>calculate_forecast( iv_engine_sn = lv_test_sn ).

  APPEND INITIAL LINE TO et_entityset ASSIGNING FIELD-SYMBOL(<ls_dbg>).

  " calculate_forecast kac satir dondu?
  ASSIGN COMPONENT 'ESTIMATEDDAYSLEFT' OF STRUCTURE <ls_dbg> TO FIELD-SYMBOL(<fs_count>).
  IF sy-subrc = 0.
    <fs_count> = lines( lt_test ).
  ENDIF.

  " sinifa GECIRILEN deger tam olarak neydi? (bosluk/kesme sorunu var mi kontrol)
  ASSIGN COMPONENT 'NODEID' OF STRUCTURE <ls_dbg> TO FIELD-SYMBOL(<fs_val>).
  IF sy-subrc = 0.
    <fs_val> = lv_test_sn.
  ENDIF.

  " gecirilen degerin uzunlugu
  ASSIGN COMPONENT 'REMAININGCYCLES' OF STRUCTURE <ls_dbg> TO FIELD-SYMBOL(<fs_len>).
  IF sy-subrc = 0.
    <fs_len> = strlen( lv_test_sn ).
  ENDIF.

ENDMETHOD.
