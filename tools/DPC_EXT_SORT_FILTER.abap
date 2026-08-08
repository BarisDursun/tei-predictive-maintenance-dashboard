"====================================================================
" ENGINESET_GET_ENTITYSET - filtre + siralama + SAYFALAMA
"
" Bu metot uc ayri hatanin duzeltilmis halini icerir. Hepsi ayni kok
" sebepten geliyor: SEGW'de GET_ENTITYSET'i redefine ettiginde OData'nin
" sana GONDERDIGI her seyi (filtre, siralama, sayfalama) ELLE islemen
" gerekir - framework bunu senin yerine yapmaz.
"
" ---- HATA 1: filtreler yok sayiliyordu ----
" Metot duz "SELECT * FROM zcelddash" yapiyordu, IT_FILTER_SELECT_OPTIONS'a
" hic bakmiyordu. Sonuc: filtre barindan secim yapmak hicbir sey degistirmiyordu.
"
" ---- HATA 2: siralama yok sayiliyordu ----
" IT_ORDER okunmuyordu. SEGW'de tum alanlarda "Sortable" kutusunu isaretledik,
" yani kullanici artik kolon basligina tiklayip siralayabiliyor - ama backend
" bunu gormezse hicbir sey olmaz. Simdi IT_ORDER dinamik ORDER BY'a ceviriliyor.
"
" ---- HATA 3 (en sinsisi): SAYFALAMA yok sayiliyordu ----
" GridTable veriyi parca parca ister ($skip=20&$top=20 gibi) ve toplam kayit
" sayisini $inlinecount ile sorar. Biz her istekte eslesen TUM satirlari
" donuyorduk ve toplam sayiyi hic bildirmiyorduk. Filtresizken 21 satir tek
" sayfaya sigdigi icin sorun GORUNMUYORDU; ama kullanici filtre uygulayinca
" sonuc kumesi degisiyor, sayfa sinirlari kayiyor ve UI5 modeli bozuluyor:
"     "No data loaded for select property: Bomid of entry: EngineSet('TS1400-DUR1')"
" Ekranda tum hucreler bosaliyor, grafikte [object Object] yaziyordu. Dikkat:
" o hata mesajindaki TS1400-DUR1 BOM0003'tu, yani BOM0002 filtresinin sonucunda
" olmamasi gereken bir satir - model filtre oncesi ve sonrasi satirlari
" birbirine karistirmisti. Klasik "sayfalamayi elle uygulamayi unutma" tuzagi.
"
" NOT: Bu hatalarin UCU DE mock server'da GORUNMEZ - @sap-ux/ui5-middleware-fe-mockserver
" $filter/$orderby/$skip/$top/$inlinecount'un hepsini kendisi isler. Sadece
" gercek backend'de ortaya cikarlar.
"
" YAPILACAK: SE24 > ZCL_ZTEI_ELD_PM_SRV_DPC_EXT > Degistir > Methods >
" Redefinitions > ENGINESET_GET_ENTITYSET > METHOD ile ENDMETHOD arasindaki
" HER SEYI bununla degistir > Aktive et (Ctrl+F3).
"====================================================================

  DATA: lv_bomid  TYPE ztei_eld_engine-bom_id,
        lv_basecd TYPE ztei_eld_engine-base_code,
        lv_status TYPE ztei_eld_engine-status,
        lt_engine TYPE STANDARD TABLE OF zcelddash,
        lv_order  TYPE string,
        lv_col    TYPE string,
        lv_from   TYPE i.

  "-------------------------------------------------------------
  " 1) FILTRELER - UI.SelectionFields'daki 3 alan (Bomid/Basecode/Status)
  " Basitlestirme: her alan icin sadece ILK secilen deger alinir
  " (coklu secim OR'lanmiyor) - PARTRISKSET_GET_ENTITYSET'te de ayni kabul var.
  "-------------------------------------------------------------
  LOOP AT it_filter_select_options INTO DATA(ls_filter).
    READ TABLE ls_filter-select_options INTO DATA(ls_opt) INDEX 1.
    CHECK sy-subrc = 0.
    CASE ls_filter-property.
      WHEN 'Bomid'.    lv_bomid  = ls_opt-low.
      WHEN 'Basecode'. lv_basecd = ls_opt-low.
      WHEN 'Status'.   lv_status = ls_opt-low.
    ENDCASE.
  ENDLOOP.

  "-------------------------------------------------------------
  " 2) SIRALAMA - kullanici kolon basligina tikladiysa IT_ORDER dolu gelir
  "
  " Dinamik ORDER BY kullaniyoruz ama gelen alan adini DOGRUDAN sorguya
  " koymuyoruz: bilinmeyen bir isim gelirse ABAP calisma zamaninda DUMP eder.
  " Bu yuzden asagida beyaz liste (whitelist) var - sadece tanidigimiz
  " alanlar kabul ediliyor, gerisi sessizce yok sayiliyor.
  "-------------------------------------------------------------
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

  " Kullanici bir siralama secmediyse varsayilan: en kotu risk en ustte.
  " (1=Kirmizi, 3=Yesil oldugu icin ARTAN siralama en kotuyu basa getirir.)
  IF lv_order IS INITIAL.
    lv_order = 'WORSTPARTRISKRANK ASCENDING, ENGINESN ASCENDING'.
  ENDIF.

  "-------------------------------------------------------------
  " 3) VERIYI CEK - "= @deger OR @deger = @space" kalibi: deger bossa
  " o alanda filtre uygulanmamis gibi davranir (Open SQL'de IS INITIAL yok).
  "-------------------------------------------------------------
  SELECT * FROM zcelddash
    WHERE ( bomid    = @lv_bomid  OR @lv_bomid  = @space )
      AND ( basecode  = @lv_basecd OR @lv_basecd = @space )
      AND ( status    = @lv_status OR @lv_status = @space )
    ORDER BY (lv_order)
    INTO TABLE @lt_engine.

  "-------------------------------------------------------------
  " 4) TOPLAM SAYI ($inlinecount) - SAYFALAMADAN ONCE hesaplanmali!
  " Istemciye "filtreye uyan toplam su kadar kayit var" demek zorundayiz,
  " yoksa tablo kaydirma cubugunu ve sayfa sinirlarini hesaplayamaz.
  "-------------------------------------------------------------
  es_response_context-inlinecount = lines( lt_engine ).

  "-------------------------------------------------------------
  " 5) SAYFALAMA ($skip / $top) - istemcinin istedigi dilimi kes.
  " Once bastan SKIP kadar sil, sonra kalanin TOP'tan sonrasini sil.
  " Sirasi onemli: once skip, sonra top.
  "-------------------------------------------------------------
  IF is_paging-skip > 0.
    DELETE lt_engine TO is_paging-skip.
  ENDIF.

  IF is_paging-top > 0.
    lv_from = is_paging-top + 1.
    DELETE lt_engine FROM lv_from.
  ENDIF.

  et_entityset = CORRESPONDING #( lt_engine ).

  "-------------------------------------------------------------
  " 6) EGT metni - turbin "71.8 C", piston "N/A"
  " Bu blok ZORUNLU: Currentegtmargin alaninda Common.Text +
  " TextArrangement=TextOnly kullaniliyor, yani ekranda SAYININ YERINE
  " bu metin gosteriliyor. Blok atlanirsa EGT kolonu tamamen BOSALIR.
  "-------------------------------------------------------------
  LOOP AT et_entityset ASSIGNING FIELD-SYMBOL(<ls_engine>).
    IF <ls_engine>-enginefamilytype = 'P'.
      <ls_engine>-currentegtmargintxt = 'N/A'.
    ELSE.
      <ls_engine>-currentegtmargintxt = |{ <ls_engine>-currentegtmargin DECIMALS = 1 } C|.
    ENDIF.
  ENDLOOP.
