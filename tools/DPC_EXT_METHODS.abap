"====================================================================
" ZTEI_ELD_PM_SRV_DPC_EXT - GetEntitySet redefinitionlari
" Her metod SEGW'de Service Implementation > <EntitySet> > GetEntitySet
" satirina cift tiklayip Redefine ile buraya yapistirilacak.
"====================================================================


"--------------------------------------------------------------------
" 1. ENGINESET_GET_ENTITYSET
" En basit olani: ZTEI_C_ELD_DASHBOARD CDS view'i zaten tum join+aggregation
" isini yapmis durumda (bir satir = bir motor). Sadece duz SELECT yeterli.
"--------------------------------------------------------------------
METHOD engineset_get_entityset.

  DATA: lt_engine TYPE STANDARD TABLE OF zcelddash.

  SELECT * FROM zcelddash
    INTO TABLE @lt_engine.

  " CORRESPONDING #(...) alan isimleri eslesince otomatik kopyalar
  " (ENGINESN, BOMID, vs. - hem CDS'ten hem SEGW importundan ayni isimler geldigi icin calisir)
  et_entityset = CORRESPONDING #( lt_engine ).

ENDMETHOD.


"--------------------------------------------------------------------
" 2. PARTRISKSET_GET_ENTITYSET
" Object Page'de "bu motorun kritik parcalari" listesi icin kullanilacak.
" Fiori tarafi genelde $filter=EngineSn eq '...' ile cagiracak, o yuzden
" IT_FILTER_SELECT_OPTIONS icinden EngineSn degerini elle cikariyoruz.
"--------------------------------------------------------------------
METHOD partriskset_get_entityset.

  DATA: lt_partrisk  TYPE STANDARD TABLE OF zieldprsk,
        lv_engine_sn TYPE ztei_eld_engine-engine_sn.

  " Gelen $filter parametrelerinde EngineSn var mi diye bak
  LOOP AT it_filter_select_options INTO DATA(ls_filter) WHERE property = 'EngineSn'.
    READ TABLE ls_filter-select_options INTO DATA(ls_option) INDEX 1.
    IF sy-subrc = 0.
      lv_engine_sn = ls_option-low.  " filtredeki deger (orn. 'TF6000-001')
    ENDIF.
  ENDLOOP.

  IF lv_engine_sn IS NOT INITIAL.
    " belirli bir motora filtrelenmis istek (Object Page drill-down)
    SELECT * FROM zieldprsk
      WHERE enginesn = @lv_engine_sn
      INTO TABLE @lt_partrisk.
  ELSE.
    " filtre yoksa tum kayitlari don (test/liste ekrani icin)
    SELECT * FROM zieldprsk INTO TABLE @lt_partrisk.
  ENDIF.

  et_entityset = CORRESPONDING #( lt_partrisk ).

ENDMETHOD.


"--------------------------------------------------------------------
" 3. BORESCOPESET_GET_ENTITYSET
" Object Page'de "muayene bulgu gecmisi" listesi icin. PartRisk ile ayni
" filtreleme mantigi - EngineSn geldi mi diye bakip ona gore filtreliyor.
"--------------------------------------------------------------------
METHOD borescopeset_get_entityset.

  DATA: lt_boresco   TYPE STANDARD TABLE OF ztei_eld_boresco,
        lv_engine_sn TYPE ztei_eld_engine-engine_sn.

  LOOP AT it_filter_select_options INTO DATA(ls_filter) WHERE property = 'EngineSn'.
    READ TABLE ls_filter-select_options INTO DATA(ls_option) INDEX 1.
    IF sy-subrc = 0.
      lv_engine_sn = ls_option-low.
    ENDIF.
  ENDLOOP.

  IF lv_engine_sn IS NOT INITIAL.
    SELECT * FROM ztei_eld_boresco
      WHERE engine_sn = @lv_engine_sn
      INTO TABLE @lt_boresco.
  ELSE.
    SELECT * FROM ztei_eld_boresco INTO TABLE @lt_boresco.
  ENDIF.

  et_entityset = CORRESPONDING #( lt_boresco ).

ENDMETHOD.


"--------------------------------------------------------------------
" 4. FORECASTSET_GET_ENTITYSET
" Veritabaninda hazir veri yok - ZCL_TEI_ELD_FORECAST sinifini cagirip
" tahmini hesaplatiyoruz. EngineSn filtresi varsa sinifa oldugu gibi geciyoruz
" (sinif zaten IV_ENGINE_SN bos ise tum motorlari, doluysa sadece o motoru donuyor).
"--------------------------------------------------------------------
METHOD forecastset_get_entityset.

  DATA: lv_engine_sn TYPE ztei_eld_engine-engine_sn,
        lt_forecast  TYPE zcl_tei_eld_forecast=>tt_forecast.

  LOOP AT it_filter_select_options INTO DATA(ls_filter) WHERE property = 'EngineSn'.
    READ TABLE ls_filter-select_options INTO DATA(ls_option) INDEX 1.
    IF sy-subrc = 0.
      lv_engine_sn = ls_option-low.
    ENDIF.
  ENDLOOP.

  " asil is burada: ABAP sinifi cagriliyor, DB SELECT degil hesaplama yapiliyor
  lt_forecast = zcl_tei_eld_forecast=>calculate_forecast( iv_engine_sn = lv_engine_sn ).

  et_entityset = CORRESPONDING #( lt_forecast ).

ENDMETHOD.


"--------------------------------------------------------------------
" 5. EGTTRENDSET_GET_ENTITYSET
" Forecast ile ayni mantik, farkli sinif (ZCL_TEI_ELD_EGT_TREND) cagiriliyor.
"--------------------------------------------------------------------
METHOD egttrendset_get_entityset.

  DATA: lv_engine_sn TYPE ztei_eld_engine-engine_sn,
        lt_trend     TYPE zcl_tei_eld_egt_trend=>tt_trend.

  LOOP AT it_filter_select_options INTO DATA(ls_filter) WHERE property = 'EngineSn'.
    READ TABLE ls_filter-select_options INTO DATA(ls_option) INDEX 1.
    IF sy-subrc = 0.
      lv_engine_sn = ls_option-low.
    ENDIF.
  ENDLOOP.

  lt_trend = zcl_tei_eld_egt_trend=>calculate_trend( iv_engine_sn = lv_engine_sn ).

  et_entityset = CORRESPONDING #( lt_trend ).

ENDMETHOD.
