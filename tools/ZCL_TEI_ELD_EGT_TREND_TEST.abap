"====================================================================
" ABAP Unit test - ZCL_TEI_ELD_EGT_TREND
"
" Ayni gerekce ZCL_TEI_ELD_FORECAST_TEST.abap'ta anlatildi - bu testler
" bugunku hata ayiklamada bulunan sentinel/tasma derslerini regresyona
" karsi kilitliyor. Gercek sistem verisine dayanir (mock/test-double yok).
"
" YAPILACAK: SE24 > ZCL_TEI_ELD_EGT_TREND > Goto > Test Classes > bu kodu
" yapistir > Aktive et > Ctrl+Shift+F10 ile calistir.
"====================================================================

CLASS ltcl_egt_trend DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS:
      piston_motor_bos_doner FOR TESTING,
      turbin_motor_tek_satir_doner FOR TESTING,
      sentinel_dusus_yoksa FOR TESTING,
      esik_parametre_ile_degisir FOR TESTING.

ENDCLASS.

CLASS ltcl_egt_trend IMPLEMENTATION.

  " PD170 pistonlu bir motor - EGT marjini kavrami gecersiz, sinif bunu
  " WHERE engine_family_type = 'T' ile filtreliyor. Piston motor icin BOS
  " tablo donmeli - Object Page'de "There are no entries yet" olarak
  " gorulen davranisin (tasarim geregi, hata degil) ta kendisi.
  METHOD piston_motor_bos_doner.
    DATA(lt_result) = zcl_tei_eld_egt_trend=>calculate_trend( iv_engine_sn = 'PD170-001' ).

    cl_abap_unit_assert=>assert_initial(
      act = lt_result
      msg = 'Piston (P tipi) motor icin EGT trend sonucu bos olmali' ).
  ENDMETHOD.

  " Turbin motor icin TAM OLARAK 1 satir donmeli (motor bazinda tek
  " sonuc, parca bazinda degil - EgtTrend'in Forecast/PartRisk'ten
  " temel yapisal farki, Object Page facet tasariminin dayandigi kural).
  METHOD turbin_motor_tek_satir_doner.
    DATA(lt_result) = zcl_tei_eld_egt_trend=>calculate_trend( iv_engine_sn = 'TS1400-DUR1' ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_result )
      exp = 1
      msg = 'Turbin motoru icin tam olarak 1 EGT trend satiri beklenir' ).
  ENDMETHOD.

  " KRITIK REGRESYON TESTI: decline_per_day <= 0 oldugunda
  " estimated_days_left TAM OLARAK 9999 olmali - Forecast sinifindaki
  " ayni sentinel deseni, DPC_EXT'teki ayni "= 9999" duzeltmesiyle
  " tutarli olmak zorunda (ikisi de ayni ENGINESET_GET_ENTITYSET
  " mantigindan besleniyor).
  METHOD sentinel_dusus_yoksa.
    DATA(lt_result) = zcl_tei_eld_egt_trend=>calculate_trend( ).

    LOOP AT lt_result INTO DATA(ls_row) WHERE estimated_days_left = 9999.
      cl_abap_unit_assert=>assert_true(
        act = xsdbool( ls_row-decline_per_day <= 0 )
        msg = |{ ls_row-engine_sn }: sentinel (9999) sadece dusus <=0 iken cikmali, |
           && |ama decline_per_day={ ls_row-decline_per_day }| ).
    ENDLOOP.
  ENDMETHOD.

  " IV_THRESHOLD parametresi degistiginde threshold_used alanina AYNEN
  " yansimali - varsayilan (15.0) degeri sessizce gormezden gelip
  " gecmemeli.
  METHOD esik_parametre_ile_degisir.
    DATA(lt_result) = zcl_tei_eld_egt_trend=>calculate_trend(
      iv_engine_sn = 'TS1400-DUR1'
      iv_threshold = '20.0' ).

    cl_abap_unit_assert=>assert_not_initial( act = lt_result ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_result[ 1 ]-threshold_used
      exp = CONV zcl_tei_eld_egt_trend=>ty_margin( '20.0' )
      msg = 'threshold_used, verilen iv_threshold parametresini yansitmali' ).
  ENDMETHOD.

ENDCLASS.
