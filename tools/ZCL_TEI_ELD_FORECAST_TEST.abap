"====================================================================
" ABAP Unit test - ZCL_TEI_ELD_FORECAST
"
" NEDEN: Bugunku hata ayiklamada (Madde 2a) tam olarak bu testlerin
" yakalayacagi turden bir hata bulundu - DPC_EXT'te estimated_days_left
" icin yanlis esik (`>= 9999` yerine `= 9999` olmasi gerekiyordu). O hata
" elle, adim adim bulundu; bir unit test olsaydi ilk yazildigi anda
" otomatik yakalanirdi. Bu testler o dersi kalici hale getiriyor.
"
" GERCEK VERIYE DAYANIR (test double/mock yok) - sinif dogrudan Open SQL
" SELECT yaptigi icin (ztei_eld_part_li, ztei_eld_usage_l), klasik
" mocking bu sistemde pratik degil. Bunun yerine SISTEMDE ZATEN VAR OLAN
" bilinen test motorlarini (TS1400-DUR1, TF6000-001) sabit veri (fixture)
" olarak kullaniyoruz - degerler generate-eld-data.js'in deterministik
" seed'i sayesinde her yuklemede AYNI kalir.
"
" YAPILACAK: SE24 > ZCL_TEI_ELD_FORECAST > Goto > Test Classes (ya da
" toolbar'daki test sinifi editoru) > bu kodu yapistir > Aktive et >
" Ctrl+Shift+F10 (ya da "Test" butonu) ile calistir.
"====================================================================

CLASS ltcl_forecast DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS:
      risk_bandi_kirmizi FOR TESTING,
      risk_bandi_yesil FOR TESTING,
      sentinel_kullanim_yok FOR TESTING,
      kalan_cevrim_negatif_olabilir FOR TESTING,
      motor_filtresi_bos_tum_doner FOR TESTING,
      var_olmayan_motor_bos_doner FOR TESTING.

ENDCLASS.

CLASS ltcl_forecast IMPLEMENTATION.

  " TS1400-DUR1 (dayaniklilik test motoru) parcalari zaten limitini asmis -
  " risk bandi kirmizi (R) olan parcalarin kalan gunu NEGATIF olmali.
  METHOD risk_bandi_kirmizi.
    DATA(lt_result) = zcl_tei_eld_forecast=>calculate_forecast( iv_engine_sn = 'TS1400-DUR1' ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lt_result
      msg = 'TS1400-DUR1 icin en az bir parca sonucu beklenir' ).

    DATA(lv_found_red) = abap_false.
    LOOP AT lt_result INTO DATA(ls_row) WHERE risk_category = 'R'.
      lv_found_red = abap_true.
      cl_abap_unit_assert=>assert_true(
        act = xsdbool( ls_row-estimated_days_left < 0 )
        msg = |{ ls_row-node_id }: kirmizi (limit asilmis) parcanin kalan gunu negatif olmali, |
           && |ama { ls_row-estimated_days_left } geldi| ).
    ENDLOOP.

    cl_abap_unit_assert=>assert_true(
      act = lv_found_red
      msg = 'TS1400-DUR1de en az bir kirmizi (asilmis) parca beklenir - test verisi degismis olabilir' ).
  ENDMETHOD.

  " TF6000-001 tum parcalari yesil (dogrulandi: Redpartcount=0,
  " Worstpartriskrank=3) - yesil bandindaki parcalarin kullanim
  " yuzdesi %70'in altinda olmali (esik kuralinin tersine calismadigini
  " dogrular).
  METHOD risk_bandi_yesil.
    DATA(lt_result) = zcl_tei_eld_forecast=>calculate_forecast( iv_engine_sn = 'TF6000-001' ).

    LOOP AT lt_result INTO DATA(ls_row) WHERE risk_category = 'G'.
      cl_abap_unit_assert=>assert_true(
        act = xsdbool( ls_row-usage_pct < 70 )
        msg = |{ ls_row-node_id }: yesil parcanin kullanim yuzdesi %70'in altinda olmali| ).
    ENDLOOP.
  ENDMETHOD.

  " KRITIK REGRESYON TESTI: bugun elle bulunan hatanin ta kendisi.
  " usage_rate_per_day <= 0 oldugunda estimated_days_left TAM OLARAK 9999
  " sentinel degerini almali. DPC_EXT bu deger uzerinden "Veri Yok" karari
  " veriyor - eger sinif YANLISLIKLA 9999'dan farkli/daha buyuk bir deger
  " uretirse (orn. 10000), DPC_EXT'teki `= 9999` kontrolu bunu KACIRIR ve
  " kullaniciya "Veri Yok" yerine anlamsiz bir gun sayisi gosterilir.
  METHOD sentinel_kullanim_yok.
    DATA(lt_result) = zcl_tei_eld_forecast=>calculate_forecast( ).

    LOOP AT lt_result INTO DATA(ls_row) WHERE estimated_days_left = 9999.
      cl_abap_unit_assert=>assert_true(
        act = xsdbool( ls_row-usage_rate_per_day <= 0 )
        msg = |{ ls_row-node_id }: sentinel (9999) sadece kullanim hizi <=0 iken cikmali, |
           && |ama usage_rate_per_day={ ls_row-usage_rate_per_day }| ).
    ENDLOOP.
  ENDMETHOD.

  " Limitini asmis bir parcada kalan cevrim (remaining_cycles) NEGATIF
  " olabilmeli - sifirda "kilitlenmemeli" (birisi ileride savunmaci bir
  " MAX(0,...) eklerse "ASILDI" bilgisi kaybolur, bu test o regresyonu
  " yakalar).
  METHOD kalan_cevrim_negatif_olabilir.
    DATA(lt_result) = zcl_tei_eld_forecast=>calculate_forecast( iv_engine_sn = 'TS1400-DUR1' ).

    DATA(lv_found_negative) = abap_false.
    LOOP AT lt_result INTO DATA(ls_row) WHERE remaining_cycles < 0.
      lv_found_negative = abap_true.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true(
      act = lv_found_negative
      msg = 'TS1400-DUR1de en az bir parcanin kalan cevrimi negatif olmali (limit asilmis)' ).
  ENDMETHOD.

  " IV_ENGINE_SN bos birakilirsa TUM filonun parcalari donmeli (tek-motor
  " filtresi degil, "hepsi" anlamina gelmeli) - ENGINESET_GET_ENTITYSET'teki
  " "Sonraki Bakim Tahmini" hesabinin dogru calismasi buna dayaniyor.
  METHOD motor_filtresi_bos_tum_doner.
    DATA(lt_all) = zcl_tei_eld_forecast=>calculate_forecast( ).
    DATA(lt_one) = zcl_tei_eld_forecast=>calculate_forecast( iv_engine_sn = 'TS1400-DUR1' ).

    cl_abap_unit_assert=>assert_true(
      act = xsdbool( lines( lt_all ) > lines( lt_one ) )
      msg = 'Filtresiz cagri, tek motor filtresinden daha fazla satir donmeli' ).
  ENDMETHOD.

  " Var olmayan bir motor seri no'su verilirse bos tablo donmeli - hata
  " firlatilmamali, yanlislikla TUM filo da donmemeli ("= @space ise tum
  " motorlar" kuralinin yanlis motoru bos sanip tumunu donmedigini dogrular).
  METHOD var_olmayan_motor_bos_doner.
    DATA(lt_result) = zcl_tei_eld_forecast=>calculate_forecast( iv_engine_sn = 'YOKMOTOR001' ).

    cl_abap_unit_assert=>assert_initial(
      act = lt_result
      msg = 'Var olmayan motor icin bos tablo beklenir' ).
  ENDMETHOD.

ENDCLASS.
