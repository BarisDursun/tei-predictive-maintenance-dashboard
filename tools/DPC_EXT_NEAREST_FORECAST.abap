"====================================================================
" Madde 2b + Madde 3 (DPC_EXT kismi): "Sonraki Bakim Tahmini" kolonu
"
" NEDEN GEREKLI: Engine listesindeki "Kritik Parca" kolonu SADECE "su an
" kac parca sorunlu" bilgisini veriyor (durum). Forecast'i sadece Object
" Page'e gomduk (Madde 2a) ama ana listede hala bir ongoru sinyali yok.
" Bu kolon, o motorun TUM parcalari arasinda EN YAKIN tahmini sorun
" tarihini metin olarak gosterir: "47 gun", "ASILDI", "10+ yil", "Veri Yok".
"
" DUZELTME (ilk canli testte bulundu): esik `>= 9999` idi, ama genc filo
" (limitine cok uzak motorlar) icin calculate_forecast GERCEK ama COK BUYUK
" bir gun sayisi hesapliyor (orn. 18000+ gun = ~50 yil) - bu "veri yok"
" DEGIL, "cok uzak bir tarih". Sinifin GERCEK "veri yok" sinyali TAM OLARAK
" 9999 (sabit sentinel deger, calculate_forecast icinde `ELSE
" estimated_days_left = 9999` satirinda literal olarak atanıyor). `>= 9999`
" kullanmak butun genc filoyu yanlislikla "Veri Yok" gosteriyordu. Simdi
" `= 9999` (tam esitlik) ile gercek sentinel ayirt ediliyor, buyuk ama
" GERCEK degerler icin de "10+ yil" (okunabilir) gosteriliyor - tarih
" alanindaki +/-3650 gun kirpma mantigiyla ayni felsefe.
"
" NOT: StatusText icin DPC_EXT'te HICBIR SEY YAPILMIYOR - o saf CDS CASE
" ile zaten hesaplaniyor (ZTEI_I_ELD_FLEET_HEALTH), duz SELECT * ile
" otomatik geliyor. Sadece NearestForecastTxt (ABAP sinifindan geldigi
" icin) burada dolduruluyor.
"
" YAPILACAK: SE24 > ZCL_ZTEI_ELD_PM_SRV_DPC_EXT > Degistir > Methods >
" Redefinitions > ENGINESET_GET_ENTITYSET VE ENGINESET_GET_ENTITY - ikisinin
" de govdesini TAMAMEN bununla degistir > Aktive et.
"====================================================================


"--------------------------------------------------------------------
" 1. ENGINESET_GET_ENTITYSET
" Madde 1'deki filtre+siralama+sayfalama+EGT-metni AYNEN korunuyor,
" sadece sona "Sonraki Bakim Tahmini" hesaplamasi eklendi.
"--------------------------------------------------------------------
METHOD engineset_get_entityset.

  DATA: lv_bomid  TYPE ztei_eld_engine-bom_id,
        lv_basecd TYPE ztei_eld_engine-base_code,
        lv_status TYPE ztei_eld_engine-status,
        lt_engine TYPE STANDARD TABLE OF zcelddash,
        lv_order  TYPE string,
        lv_col    TYPE string,
        lv_from   TYPE i.

  " 1) Filtreler
  LOOP AT it_filter_select_options INTO DATA(ls_filter).
    READ TABLE ls_filter-select_options INTO DATA(ls_opt) INDEX 1.
    CHECK sy-subrc = 0.
    CASE ls_filter-property.
      WHEN 'Bomid'.    lv_bomid  = ls_opt-low.
      WHEN 'Basecode'. lv_basecd = ls_opt-low.
      WHEN 'Status'.   lv_status = ls_opt-low.
    ENDCASE.
  ENDLOOP.

  " 2) Siralama (beyaz liste ile dinamik ORDER BY)
  LOOP AT it_order INTO DATA(ls_order).
    CLEAR lv_col.
    CASE ls_order-property.
      WHEN 'Enginesn'.            lv_col = 'ENGINESN'.
      WHEN 'Bomid'.               lv_col = 'BOMID'.
      WHEN 'Enginefamilytype'.    lv_col = 'ENGINEFAMILYTYPE'.
      WHEN 'Basecode'.            lv_col = 'BASECODE'.
      WHEN 'Basename'.            lv_col = 'BASENAME'.
      WHEN 'Status'.              lv_col = 'STATUS'.
      WHEN 'Totalflighthours'.    lv_col = 'TOTALFLIGHTHOURS'.
      WHEN 'Totalcycles'.         lv_col = 'TOTALCYCLES'.
      WHEN 'Currentegtmargin'.    lv_col = 'CURRENTEGTMARGIN'.
      WHEN 'Worstpartriskrank'.   lv_col = 'WORSTPARTRISKRANK'.
      WHEN 'Redpartcount'.        lv_col = 'REDPARTCOUNT'.
      WHEN 'Yellowpartcount'.     lv_col = 'YELLOWPARTCOUNT'.
    ENDCASE.
    CHECK lv_col IS NOT INITIAL.

    IF lv_order IS NOT INITIAL.
      lv_order = |{ lv_order }, |.
    ENDIF.

    IF ls_order-order = 'desc'.
      lv_order = |{ lv_order }{ lv_col } DESCENDING|.
    ELSE.
      lv_order = |{ lv_order }{ lv_col } ASCENDING|.
    ENDIF.
  ENDLOOP.

  IF lv_order IS INITIAL.
    lv_order = 'WORSTPARTRISKRANK ASCENDING, ENGINESN ASCENDING'.
  ENDIF.

  " 3) Veriyi cek
  SELECT * FROM zcelddash
    WHERE ( bomid    = @lv_bomid  OR @lv_bomid  = @space )
      AND ( basecode  = @lv_basecd OR @lv_basecd = @space )
      AND ( status    = @lv_status OR @lv_status = @space )
    ORDER BY (lv_order)
    INTO TABLE @lt_engine.

  " 4) Toplam sayi
  es_response_context-inlinecount = lines( lt_engine ).

  " 5) Sayfalama
  IF is_paging-skip > 0.
    DELETE lt_engine TO is_paging-skip.
  ENDIF.
  IF is_paging-top > 0.
    lv_from = is_paging-top + 1.
    DELETE lt_engine FROM lv_from.
  ENDIF.

  et_entityset = CORRESPONDING #( lt_engine ).

  " 6) YENI - Filodaki TUM parcalarin tahminini TEK cagrida al, motor
  " bazinda EN YAKIN (en kucuk EstimatedDaysLeft) degeri bul. N+1 sorgu
  " yerine tek hesap - performans icin kritik (58 parca, 21 motor).
  DATA(lt_forecast) = zcl_tei_eld_forecast=>calculate_forecast( ).
  TYPES: BEGIN OF ty_nearest,
           engine_sn TYPE ztei_eld_engine-engine_sn,
           days_left TYPE i,
         END OF ty_nearest.
  DATA: lt_nearest TYPE HASHED TABLE OF ty_nearest WITH UNIQUE KEY engine_sn.

  LOOP AT lt_forecast INTO DATA(ls_fc).
    READ TABLE lt_nearest INTO DATA(ls_exist) WITH TABLE KEY engine_sn = ls_fc-engine_sn.
    IF sy-subrc <> 0.
      INSERT VALUE ty_nearest( engine_sn = ls_fc-engine_sn
                                days_left = ls_fc-estimated_days_left ) INTO TABLE lt_nearest.
    ELSEIF ls_fc-estimated_days_left < ls_exist-days_left.
      ls_exist-days_left = ls_fc-estimated_days_left.
      MODIFY TABLE lt_nearest FROM ls_exist.
    ENDIF.
  ENDLOOP.

  " 7) EGT metni + Sonraki Bakim Tahmini metni - her satir icin
  LOOP AT et_entityset ASSIGNING FIELD-SYMBOL(<ls_engine>).

    IF <ls_engine>-enginefamilytype = 'P'.
      <ls_engine>-currentegtmargintxt = 'N/A'.
    ELSE.
      <ls_engine>-currentegtmargintxt = |{ <ls_engine>-currentegtmargin DECIMALS = 1 } C|.
    ENDIF.

    READ TABLE lt_nearest INTO DATA(ls_near) WITH TABLE KEY engine_sn = <ls_engine>-enginesn.
    IF sy-subrc <> 0 OR ls_near-days_left = 9999.
      <ls_engine>-nearestforecasttxt = 'Veri Yok'.
    ELSEIF ls_near-days_left < 0.
      <ls_engine>-nearestforecasttxt = 'ASILDI'.
    ELSEIF ls_near-days_left > 3650.
      <ls_engine>-nearestforecasttxt = '10+ yil'.
    ELSE.
      <ls_engine>-nearestforecasttxt = |{ ls_near-days_left } gun|.
    ENDIF.

  ENDLOOP.

ENDMETHOD.


"--------------------------------------------------------------------
" 2. ENGINESET_GET_ENTITY
" Object Page basligi - listeyle AYNI mantik kullanilmali (EGT metninde
" ogrenilen ders: liste "N/A" gosterip detay "0.0" gosterirse tutarsiz
" gorunur). Tek motor icin calculate_forecast( iv_engine_sn = ... ) daha
" ucuz - filo genelini cekmeye gerek yok.
"--------------------------------------------------------------------
METHOD engineset_get_entity.

  DATA: lv_engine_sn TYPE ztei_eld_engine-engine_sn.

  READ TABLE it_key_tab INTO DATA(ls_key) WITH KEY name = 'Enginesn'.
  IF sy-subrc = 0.
    lv_engine_sn = ls_key-value.
  ENDIF.

  SELECT SINGLE * FROM zcelddash
    WHERE enginesn = @lv_engine_sn
    INTO CORRESPONDING FIELDS OF @er_entity.

  IF er_entity-enginefamilytype = 'P'.
    er_entity-currentegtmargintxt = 'N/A'.
  ELSE.
    er_entity-currentegtmargintxt = |{ er_entity-currentegtmargin DECIMALS = 1 } C|.
  ENDIF.

  DATA(lt_forecast) = zcl_tei_eld_forecast=>calculate_forecast( iv_engine_sn = lv_engine_sn ).
  DATA(lv_min) = 99999.
  LOOP AT lt_forecast INTO DATA(ls_fc).
    IF ls_fc-estimated_days_left < lv_min.
      lv_min = ls_fc-estimated_days_left.
    ENDIF.
  ENDLOOP.

  IF lt_forecast IS INITIAL OR lv_min = 9999.
    er_entity-nearestforecasttxt = 'Veri Yok'.
  ELSEIF lv_min < 0.
    er_entity-nearestforecasttxt = 'ASILDI'.
  ELSEIF lv_min > 3650.
    er_entity-nearestforecasttxt = '10+ yil'.
  ELSE.
    er_entity-nearestforecasttxt = |{ lv_min } gun|.
  ENDIF.

ENDMETHOD.
