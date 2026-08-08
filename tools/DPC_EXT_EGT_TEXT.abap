"====================================================================
" EGT Marjini metin gosterimi - DPC_EXT guncellemesi
"
" SORUN: PD170 pistonlu (sikistirma-atesilemeli) bir motor. Pistonlu motorda
" "EGT marjini" (turbin cikis sicakligi rezervi) diye bir kavram YOKTUR -
" olcum yapilan bir turbin kademesi yok. Ama SAP'de transparent tablodaki
" packed/DEC alan gercek anlamda NULL olamaz; bos birakilsa da 0 olarak durur.
" Sonucta dashboard'da PD170 satirlarinda "0.0" goruluyor ve buna bakan biri
" "EGT marjini sifir = motor en kritik durumda" diye okuyor. Tam tersi:
" o motor icin bu olcunun kendisi gecersiz.
"
" COZUM: sayisal alani (Currentegtmargin) OLDUGU GIBI birakiyoruz - grafik,
" siralama ve filtreleme onun uzerinden calismaya devam etsin. Yanina sadece
" GOSTERIM icin bir metin alani (Currentegtmargintxt) ekliyoruz:
"     turbin (T) -> "71.8 C"
"     piston (P) -> "N/A"
" Frontend'de Common.Text + UI.TextArrangement=TextOnly ile tabloda sayinin
" YERINE bu metin gosteriliyor (bkz. annotation.xml).
"
" NEDEN CDS'te DEGIL DE BURADA: bu sistemin CDS surumu sayisal->karakter
" cast'ini kabul etmiyor (daha once division() ve CASE WHEN'de de benzer
" sinirlara takildik). ABAP tarafinda string sablonu (|{ ... }|) ile
" formatlamak hem calisiyor hem de sunum-katmani formatlamasi zaten
" DPC_EXT'in dogal isi.
"
" ONKOSULLAR (2026-08-07 itibariyle HEPSI TAMAMLANDI):
"   1) ZTEI_I_ELD_FLEET_HEALTH'e CurrentEgtMarginTxt yer tutucu kolonu
"      eklendi - cast( '' as abap.char( 12 ) ), CDS'te bos duruyor.
"      Gerekli cunku SEGW'de Engine entity'si ZCELDDASH yapisina bagli;
"      orada karsiligi olmayan property "ABAP field name '' is not part
"      of the ABAP structure 'ZCELDDASH'" hatasi veriyor.
"   2) ZTEI_C_ELD_DASHBOARD kolonu geciriyor (GROUP BY listesinde de var).
"   3) SEGW > Engine > Properties'e Currentegtmargintxt eklendi
"      (Edm.String, MaxLength 12, ABAP Field Name = CURRENTEGTMARGINTXT),
"      Generate Runtime Objects calistirildi.
"
" NOT - ayni 6 satir bilerek iki metotta tekrarlaniyor: ortak bir yardimci
" metoda cikarmak SE24'te yeni metot + CHANGING parametresi + MPC tip adi
" (zcl_..._mpc=>ts_engine) tanimlamayi gerektiriyor; bu kadar kisa bir mantik
" icin o ek karmasikligi tercih etmedik. Ilerde mantik buyurse ayrilmali.
"
" YAPILACAK: SE24 > ZCL_ZTEI_ELD_PM_SRV_DPC_EXT > Degistir (kalem ikonu) >
" Methods > Redefinitions altindaki iki metoda cift tiklayip govdelerini
" asagidakilerle degistir > Aktive et (Ctrl+F3).
"====================================================================


"--------------------------------------------------------------------
" 1. ENGINESET_GET_ENTITYSET  (MEVCUDUNU BUNUNLA DEGISTIR)
" ALP listesi/tablosu buradan besleniyor.
"--------------------------------------------------------------------
METHOD engineset_get_entityset.

  DATA: lt_engine TYPE STANDARD TABLE OF zcelddash.

  SELECT * FROM zcelddash
    INTO TABLE @lt_engine.

  et_entityset = CORRESPONDING #( lt_engine ).

  " Sunum formatlamasi: her satir icin EGT metnini uret.
  " ASSIGNING kullaniyoruz cunku tabloyu YERINDE degistiriyoruz -
  " INTO ile kopya alsaydik degisiklik tabloya geri yazilmazdi.
  LOOP AT et_entityset ASSIGNING FIELD-SYMBOL(<ls_engine>).
    IF <ls_engine>-enginefamilytype = 'P'.
      " Pistonlu motor: olcu gecersiz. Sayisal alana DOKUNMUYORUZ (zaten 0);
      " sadece kullaniciya gosterilen metni "N/A" yapiyoruz.
      <ls_engine>-currentegtmargintxt = 'N/A'.
    ELSE.
      " Turbin: sayiyi tek ondalikli, birimiyle birlikte goster ("71.8 C")
      <ls_engine>-currentegtmargintxt = |{ <ls_engine>-currentegtmargin DECIMALS = 1 } C|.
    ENDIF.
  ENDLOOP.

ENDMETHOD.


"--------------------------------------------------------------------
" 2. ENGINESET_GET_ENTITY  (MEVCUDUNU BUNUNLA DEGISTIR)
" Object Page basligi buradan besleniyor - ayni formatlamayi burada da
" yapmak zorundayiz, yoksa listede "N/A" gorup detaya girince "0.0"
" goren tutarsiz bir ekran olusur.
"--------------------------------------------------------------------
METHOD engineset_get_entity.

  DATA: lv_engine_sn TYPE ztei_eld_engine-engine_sn.

  " URL'deki anahtar ( EngineSet('PD170-003') ) IT_KEY_TAB icinde gelir
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

ENDMETHOD.
