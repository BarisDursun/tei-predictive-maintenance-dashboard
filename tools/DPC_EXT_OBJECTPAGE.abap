"====================================================================
" Object Page icin GEREKEN EK DPC_EXT metotlari.
"
" Neden gerekli: daha once sadece *_GET_ENTITYSET (liste okuma)
" metotlarini redefine etmistik. Object Page ise:
"   1) tek bir motoru okur      -> ENGINESET_GET_ENTITY
"   2) o motorun alt listelerini -> EngineSet('X')/ToPartRisk seklinde
"      NAVIGATION ile ister; bu durumda anahtar IT_FILTER_SELECT_OPTIONS'ta
"      DEGIL, IT_KEY_TAB'da gelir. Bu yuzden asagidaki iki GET_ENTITYSET
"      metodu, onceki hallerinin yerine gececek sekilde guncellendi.
"====================================================================


"--------------------------------------------------------------------
" 1. ENGINESET_GET_ENTITY  (YENI - Redefine et)
" Object Page acilirken "bu tek motoru getir" istegi buraya duser.
"--------------------------------------------------------------------
METHOD engineset_get_entity.

  DATA: lv_engine_sn TYPE ztei_eld_engine-engine_sn.

  " URL'deki anahtar ( EngineSet('TF6000-001') ) IT_KEY_TAB icinde gelir
  READ TABLE it_key_tab INTO DATA(ls_key) WITH KEY name = 'Enginesn'.
  IF sy-subrc = 0.
    lv_engine_sn = ls_key-value.
  ENDIF.

  SELECT SINGLE * FROM zcelddash
    WHERE enginesn = @lv_engine_sn
    INTO CORRESPONDING FIELDS OF @er_entity.

ENDMETHOD.


"--------------------------------------------------------------------
" 2. PARTRISKSET_GET_ENTITYSET  (MEVCUDUNU BUNUNLA DEGISTIR)
" Iki senaryoyu birden karsiliyor:
"   a) duz liste + $filter  -> IT_FILTER_SELECT_OPTIONS
"   b) navigation (Object Page) -> IT_KEY_TAB
"--------------------------------------------------------------------
METHOD partriskset_get_entityset.

  DATA: lt_partrisk  TYPE STANDARD TABLE OF zieldprsk,
        lv_engine_sn TYPE ztei_eld_engine-engine_sn.

  " (a) $filter ile geldiyse
  LOOP AT it_filter_select_options INTO DATA(ls_filter) WHERE property = 'Enginesn'.
    READ TABLE ls_filter-select_options INTO DATA(ls_option) INDEX 1.
    IF sy-subrc = 0.
      lv_engine_sn = ls_option-low.
    ENDIF.
  ENDLOOP.

  " (b) navigation ile geldiyse anahtar IT_KEY_TAB'dadir
  IF lv_engine_sn IS INITIAL.
    READ TABLE it_key_tab INTO DATA(ls_key) WITH KEY name = 'Enginesn'.
    IF sy-subrc = 0.
      lv_engine_sn = ls_key-value.
    ENDIF.
  ENDIF.

  IF lv_engine_sn IS NOT INITIAL.
    SELECT * FROM zieldprsk
      WHERE enginesn = @lv_engine_sn
      INTO TABLE @lt_partrisk.
  ELSE.
    SELECT * FROM zieldprsk INTO TABLE @lt_partrisk.
  ENDIF.

  et_entityset = CORRESPONDING #( lt_partrisk ).

ENDMETHOD.


"--------------------------------------------------------------------
" 3. BORESCOPESET_GET_ENTITYSET  (MEVCUDUNU BUNUNLA DEGISTIR)
" DIKKAT: bu entity'de alan adi EngineSn (buyuk S) - PartRisk'te Enginesn.
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

  " navigation ile gelen anahtar: kaynak entity Engine oldugu icin 'Enginesn'
  IF lv_engine_sn IS INITIAL.
    READ TABLE it_key_tab INTO DATA(ls_key) WITH KEY name = 'Enginesn'.
    IF sy-subrc = 0.
      lv_engine_sn = ls_key-value.
    ENDIF.
  ENDIF.

  IF lv_engine_sn IS NOT INITIAL.
    SELECT * FROM ztei_eld_boresco
      WHERE engine_sn = @lv_engine_sn
      INTO TABLE @lt_boresco.
  ELSE.
    SELECT * FROM ztei_eld_boresco INTO TABLE @lt_boresco.
  ENDIF.

  et_entityset = CORRESPONDING #( lt_boresco ).

ENDMETHOD.
