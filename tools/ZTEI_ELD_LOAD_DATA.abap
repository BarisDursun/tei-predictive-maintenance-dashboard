REPORT ztei_eld_load_data.

PARAMETERS:
  p_eng RADIOBUTTON GROUP tbl DEFAULT 'X',
  p_prt RADIOBUTTON GROUP tbl,
  p_log RADIOBUTTON GROUP tbl,
  p_bor RADIOBUTTON GROUP tbl,
  p_file TYPE string LOWER CASE OBLIGATORY.

DATA: lt_raw TYPE STANDARD TABLE OF string.

START-OF-SELECTION.

  " codepage = '4110' (UTF-8) - 2026-08-08 eklendi. CSV artik UTF-8 yaziliyor
  " (generate-eld-data.js'te 'latin1' -> 'utf8'), bu parametre olmadan
  " Turkce karakterler (i, s, g, u, o, c harfleri) sessizce bozulur -
  " ikisi BIRLIKTE degismek zorunda.
  CALL METHOD cl_gui_frontend_services=>gui_upload
    EXPORTING
      filename = p_file
      filetype = 'ASC'
      codepage = '4110'
    CHANGING
      data_tab = lt_raw
    EXCEPTIONS
      OTHERS   = 99.

  IF sy-subrc <> 0.
    WRITE: / 'Dosya okunamadi, subrc =', sy-subrc.
    RETURN.
  ENDIF.

  DELETE lt_raw INDEX 1. " header satirini at

  IF p_eng = 'X'.
    PERFORM load_engine.
  ELSEIF p_prt = 'X'.
    PERFORM load_part_life.
  ELSEIF p_log = 'X'.
    PERFORM load_usage_log.
  ELSEIF p_bor = 'X'.
    PERFORM load_borescope.
  ENDIF.

FORM load_engine.
  DATA: lt_tab  TYPE STANDARD TABLE OF ztei_eld_engine,
        ls_tab  TYPE ztei_eld_engine,
        lv_line TYPE string,
        lv_sn TYPE string, lv_bom TYPE string, lv_fam TYPE string,
        lv_base TYPE string, lv_basenm TYPE string, lv_isd TYPE string,
        lv_hrs TYPE string, lv_cyc TYPE string, lv_egt TYPE string, lv_stat TYPE string.

  LOOP AT lt_raw INTO lv_line.
    CLEAR ls_tab.
    SPLIT lv_line AT ';' INTO lv_sn lv_bom lv_fam lv_base lv_basenm lv_isd lv_hrs lv_cyc lv_egt lv_stat.
    ls_tab-engine_sn           = lv_sn.
    ls_tab-bom_id               = lv_bom.
    ls_tab-engine_family_type   = lv_fam.
    ls_tab-base_code            = lv_base.
    ls_tab-base_name            = lv_basenm.
    ls_tab-in_service_date      = lv_isd.
    ls_tab-total_flight_hours   = lv_hrs.
    ls_tab-total_cycles         = lv_cyc.
    ls_tab-current_egt_margin   = lv_egt.
    ls_tab-status                = lv_stat.
    APPEND ls_tab TO lt_tab.
  ENDLOOP.

  INSERT ztei_eld_engine FROM TABLE lt_tab ACCEPTING DUPLICATE KEYS.
  WRITE: / lines( lt_tab ), 'kayit ZTEI_ELD_ENGINE tablosuna yuklendi.'.
ENDFORM.

FORM load_part_life.
  DATA: lt_tab  TYPE STANDARD TABLE OF ztei_eld_part_li,
        ls_tab  TYPE ztei_eld_part_li,
        lv_line TYPE string,
        lv_sn TYPE string, lv_node TYPE string, lv_lim TYPE string,
        lv_acc TYPE string, lv_insp TYPE string.

  LOOP AT lt_raw INTO lv_line.
    CLEAR ls_tab.
    SPLIT lv_line AT ';' INTO lv_sn lv_node lv_lim lv_acc lv_insp.
    ls_tab-engine_sn             = lv_sn.
    ls_tab-node_id                = lv_node.
    ls_tab-cycle_limit            = lv_lim.
    ls_tab-cycles_accumulated     = lv_acc.
    ls_tab-last_inspection_date   = lv_insp.
    APPEND ls_tab TO lt_tab.
  ENDLOOP.

  INSERT ztei_eld_part_li FROM TABLE lt_tab ACCEPTING DUPLICATE KEYS.
  WRITE: / lines( lt_tab ), 'kayit ZTEI_ELD_PART_LI tablosuna yuklendi.'.
ENDFORM.

FORM load_usage_log.
  DATA: lt_tab  TYPE STANDARD TABLE OF ztei_eld_usage_l,
        ls_tab  TYPE ztei_eld_usage_l,
        lv_line TYPE string,
        lv_id TYPE string, lv_sn TYPE string, lv_date TYPE string,
        lv_hrs TYPE string, lv_cyc TYPE string, lv_egt TYPE string, lv_ppm TYPE string.

  LOOP AT lt_raw INTO lv_line.
    CLEAR ls_tab.
    SPLIT lv_line AT ';' INTO lv_id lv_sn lv_date lv_hrs lv_cyc lv_egt lv_ppm.
    ls_tab-log_id       = lv_id.
    ls_tab-engine_sn    = lv_sn.
    ls_tab-flight_date  = lv_date.
    ls_tab-flight_hours = lv_hrs.
    ls_tab-cycles       = lv_cyc.
    IF lv_egt IS NOT INITIAL.
      ls_tab-egt_margin_reading = lv_egt.
    ENDIF.
    ls_tab-oil_debris_ppm = lv_ppm.
    APPEND ls_tab TO lt_tab.
  ENDLOOP.

  INSERT ztei_eld_usage_l FROM TABLE lt_tab ACCEPTING DUPLICATE KEYS.
  WRITE: / lines( lt_tab ), 'kayit ZTEI_ELD_USAGE_L tablosuna yuklendi.'.
ENDFORM.

FORM load_borescope.
  DATA: lt_tab  TYPE STANDARD TABLE OF ztei_eld_boresco,
        ls_tab  TYPE ztei_eld_boresco,
        lv_line TYPE string,
        lv_id TYPE string, lv_sn TYPE string, lv_date TYPE string,
        lv_sev TYPE string, lv_sub TYPE string, lv_txt TYPE string.

  LOOP AT lt_raw INTO lv_line.
    CLEAR ls_tab.
    SPLIT lv_line AT ';' INTO lv_id lv_sn lv_date lv_sev lv_sub lv_txt.
    ls_tab-finding_id      = lv_id.
    ls_tab-engine_sn        = lv_sn.
    ls_tab-inspection_date  = lv_date.
    ls_tab-severity          = lv_sev.
    ls_tab-subsystem         = lv_sub.
    ls_tab-finding_text      = lv_txt.
    APPEND ls_tab TO lt_tab.
  ENDLOOP.

  INSERT ztei_eld_boresco FROM TABLE lt_tab ACCEPTING DUPLICATE KEYS.
  WRITE: / lines( lt_tab ), 'kayit ZTEI_ELD_BORESCO tablosuna yuklendi.'.
ENDFORM.
