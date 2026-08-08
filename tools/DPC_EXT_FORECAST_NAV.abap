"====================================================================
" KALICI DUZELTME v3 - Madde 2a: Forecast/EgtTrend facetleri
"
" TESHIS ZINCIRI (ozet):
"   1) IT_KEY_TAB okuma DOGRUYDU (name='Enginesn', value='TS1400-DUR1').
"   2) CALCULATE_FORECAST/CALCULATE_TREND DOGRU calisiyordu.
"   3) CORRESPONDING #( lt_forecast ) YANLISTI - ty_forecast/ty_trend ALT
"      CIZGILI (engine_sn, node_id...), OData ALT CIZGISIZ (EngineSn,
"      NodeId...) - hicbir alan eslesmiyordu, satirlar BOS donuyordu.
"      -> Alan alan ACIK esleme ile duzeltildi.
"   4) EstimatedDate (dats) dogrudan Edm.DateTime alanina (TIMESTAMP)
"      ataninca "Value 742330 is not a valid date..." hatasi (HTTP 500)
"      -> CONVERT DATE...INTO TIME STAMP ile duzeltildi. EgtTrend'de
"      calisti (60 marj, 1641 gun, "Feb 4 2031" dogru geldi) AMA
"      Forecast'te AYNI HATA (742330) DEVAM ETTI.
"   5) BULUNAN GERCEK SEBEP: ZCL_TEI_ELD_FORECAST bazi parcalar icin
"      estimated_days_left'i **9999** (sentinel - "kullanim yok, pratikte
"      hic ulasmaz") veya BUYUK NEGATIF (N214 gibi zaten asilmis parcalar,
"      -1152 gun) uretiyor. `sy-datum + 9999` gibi asiri buyuk/kucuk
"      sapmalar ABAP'in dats aritmetiginde gecerli tarih araligini
"      (0001-9999) zorlayip bozuk deger uretebiliyor - "742330" bunun
"      belirtisi. EgtTrend'de bu sorun cikmadi cunku ordaki gun sayilari
"      (1641 gibi) makul araliktaydi.
"
" COZUM: Tarih hesaplamasina girmeden ONCE gun sayisini +/-3650 (10 yil)
" ile SINIRLIYORUZ. "10+ yil sonra" ya da "10+ yil once asildi" bilgisi
" zaten gun hassasiyeti gerektirmiyor - kirpma bilgi kaybina yol acmiyor.
" EstimatedDaysLeft alaninda HAM (kirpilmamis) deger kaliyor - kullanici
" gercek sayiyi (orn. "-1152 gun" veya "9999 gun") gorur, sadece
" EstimatedDate alani (tarih) guvenli araliga cekiliyor.
"
" YAPILACAK: SE24'te iki metodun govdesini TAMAMEN bununla degistir,
" aktive et.
"====================================================================


"--------------------------------------------------------------------
" 1. FORECASTSET_GET_ENTITYSET
"--------------------------------------------------------------------
METHOD forecastset_get_entityset.

  DATA: lv_engine_sn  TYPE ztei_eld_engine-engine_sn,
        lt_forecast   TYPE zcl_tei_eld_forecast=>tt_forecast,
        lv_ts         TYPE timestamp,
        lv_days_safe  TYPE i,
        lv_date_safe  TYPE dats.

  " (a) duz liste + $filter ile geldiyse
  LOOP AT it_filter_select_options INTO DATA(ls_filter) WHERE property = 'EngineSn'.
    READ TABLE ls_filter-select_options INTO DATA(ls_option) INDEX 1.
    IF sy-subrc = 0.
      lv_engine_sn = ls_option-low.
    ENDIF.
  ENDLOOP.

  " (b) navigation ile geldiyse (dogrulandi: IT_KEY_TAB'da name='Enginesn')
  IF lv_engine_sn IS INITIAL.
    READ TABLE it_key_tab INTO DATA(ls_key) WITH KEY name = 'Enginesn'.
    IF sy-subrc = 0.
      lv_engine_sn = ls_key-value.
    ENDIF.
  ENDIF.

  lt_forecast = zcl_tei_eld_forecast=>calculate_forecast( iv_engine_sn = lv_engine_sn ).

  " Alan alan ACIK esleme (CORRESPONDING DEGIL) + guvenli tarih hesabi.
  LOOP AT lt_forecast INTO DATA(ls_fc).
    APPEND INITIAL LINE TO et_entityset ASSIGNING FIELD-SYMBOL(<ls_row>).

    " Gun sayisini +/-3650 (10 yil) ile sinirla - sentinel (9999) veya
    " asiri negatif (cok eskiden asilmis) degerler dats araligini tasirdi.
    lv_days_safe = ls_fc-estimated_days_left.
    IF lv_days_safe > 3650.
      lv_days_safe = 3650.
    ELSEIF lv_days_safe < -3650.
      lv_days_safe = -3650.
    ENDIF.
    lv_date_safe = sy-datum + lv_days_safe.

    CLEAR lv_ts.
    CONVERT DATE lv_date_safe TIME '000000'
      INTO TIME STAMP lv_ts TIME ZONE sy-zonlo.

    <ls_row>-EngineSn          = ls_fc-engine_sn.
    <ls_row>-NodeId            = ls_fc-node_id.
    <ls_row>-CycleLimit        = ls_fc-cycle_limit.
    <ls_row>-CyclesAccumulated = ls_fc-cycles_accumulated.
    <ls_row>-UsagePct          = ls_fc-usage_pct.
    <ls_row>-UsageRatePerDay   = ls_fc-usage_rate_per_day.
    <ls_row>-RemainingCycles   = ls_fc-remaining_cycles.
    <ls_row>-EstimatedDaysLeft = ls_fc-estimated_days_left.
    <ls_row>-EstimatedDate     = lv_ts.
    <ls_row>-RiskCategory      = ls_fc-risk_category.
  ENDLOOP.

ENDMETHOD.


"--------------------------------------------------------------------
" 2. EGTTRENDSET_GET_ENTITYSET
" Zaten calisiyordu ama AYNI sinir (9999 sentinel ihtimaline karsi)
" tutarlilik icin buraya da eklendi - decline_per_day sifira yakinsa
" burada da ayni tasma riski var, henuz karsimiza cikmadi ama onceden
" onlemek daha guvenli.
"--------------------------------------------------------------------
METHOD egttrendset_get_entityset.

  DATA: lv_engine_sn  TYPE ztei_eld_engine-engine_sn,
        lt_trend      TYPE zcl_tei_eld_egt_trend=>tt_trend,
        lv_ts         TYPE timestamp,
        lv_days_safe  TYPE i,
        lv_date_safe  TYPE dats.

  LOOP AT it_filter_select_options INTO DATA(ls_filter) WHERE property = 'EngineSn'.
    READ TABLE ls_filter-select_options INTO DATA(ls_option) INDEX 1.
    IF sy-subrc = 0.
      lv_engine_sn = ls_option-low.
    ENDIF.
  ENDLOOP.

  IF lv_engine_sn IS INITIAL.
    READ TABLE it_key_tab INTO DATA(ls_key) WITH KEY name = 'Enginesn'.
    IF sy-subrc = 0.
      lv_engine_sn = ls_key-value.
    ENDIF.
  ENDIF.

  lt_trend = zcl_tei_eld_egt_trend=>calculate_trend( iv_engine_sn = lv_engine_sn ).

  LOOP AT lt_trend INTO DATA(ls_tr).
    APPEND INITIAL LINE TO et_entityset ASSIGNING FIELD-SYMBOL(<ls_row>).

    lv_days_safe = ls_tr-estimated_days_left.
    IF lv_days_safe > 3650.
      lv_days_safe = 3650.
    ELSEIF lv_days_safe < -3650.
      lv_days_safe = -3650.
    ENDIF.
    lv_date_safe = sy-datum + lv_days_safe.

    CLEAR lv_ts.
    CONVERT DATE lv_date_safe TIME '000000'
      INTO TIME STAMP lv_ts TIME ZONE sy-zonlo.

    <ls_row>-EngineSn          = ls_tr-engine_sn.
    <ls_row>-CurrentEgtMargin  = ls_tr-current_egt_margin.
    <ls_row>-DeclinePerDay     = ls_tr-decline_per_day.
    <ls_row>-ThresholdUsed     = ls_tr-threshold_used.
    <ls_row>-EstimatedDaysLeft = ls_tr-estimated_days_left.
    <ls_row>-EstimatedDate     = lv_ts.
  ENDLOOP.

ENDMETHOD.
