CLASS zcl_tei_eld_egt_trend DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Esik/marjin degerleri icin adlandirilmis tip - metod parametresinde inline "TYPE p LENGTH n
    " DECIMALS m" yazmak parser hatasi veriyor, bu yuzden once adlandirilmis tip tanimlaniyor.
    TYPES ty_margin TYPE p LENGTH 5 DECIMALS 1.

    " Tek bir motorun EGT marjin trend sonucu
    TYPES: BEGIN OF ty_trend,
             engine_sn              TYPE ztei_eld_engine-engine_sn,
             current_egt_margin     TYPE ztei_eld_engine-current_egt_margin,
             decline_per_day        TYPE p LENGTH 7 DECIMALS 4,   " gunluk EGT marjin dususu (derece)
             threshold_used         TYPE ty_margin,                " HSI/kirmizi tetikleyici esik
             estimated_days_left    TYPE i,                        " esige kac gun kaldi
             estimated_date         TYPE dats,
           END OF ty_trend,
           tt_trend TYPE STANDARD TABLE OF ty_trend WITH EMPTY KEY.

    " IV_ENGINE_SN bos = tum turbin motorlari (piston/P tipi motorlarda EGT anlamsiz, otomatik disarida)
    " IV_THRESHOLD = kirmizi alarm esigi, varsayilan 15 derece (arastirmadaki tipik HSI esigi)
    CLASS-METHODS calculate_trend
      IMPORTING
        iv_engine_sn    TYPE ztei_eld_engine-engine_sn OPTIONAL
        iv_threshold    TYPE ty_margin DEFAULT '15.0'
      RETURNING
        VALUE(rt_trend) TYPE tt_trend.

ENDCLASS.

CLASS zcl_tei_eld_egt_trend IMPLEMENTATION.

  METHOD calculate_trend.

    DATA: ls_trend TYPE ty_trend.

    " sadece turbin motorlari (family = T) - piston motorda (PD170) EGT kavrami yok
    " Open SQL'de "IS INITIAL" desteklenmiyor - bos deger karsilastirmasi @space ile yapiliyor.
    " Inline @DATA() kullanildiginda INTO cumlesi WHERE'den SONRA, en sonda olmali (strict Open SQL kurali).
    SELECT * FROM ztei_eld_engine
      WHERE engine_family_type = 'T'
        AND ( engine_sn = @iv_engine_sn OR @iv_engine_sn = @space )
      INTO TABLE @DATA(lt_engines).

    LOOP AT lt_engines INTO DATA(ls_engine).
      CLEAR ls_trend.

      " digitize edilmis log penceresindeki EN ESKI EGT okumasi
      SELECT flight_date, egt_margin_reading
        FROM ztei_eld_usage_l
        WHERE engine_sn = @ls_engine-engine_sn
          AND egt_margin_reading <> 0
        ORDER BY flight_date ASCENDING
        INTO TABLE @DATA(lt_first)
        UP TO 1 ROWS.

      " EN YENI EGT okumasi
      SELECT flight_date, egt_margin_reading
        FROM ztei_eld_usage_l
        WHERE engine_sn = @ls_engine-engine_sn
          AND egt_margin_reading <> 0
        ORDER BY flight_date DESCENDING
        INTO TABLE @DATA(lt_last)
        UP TO 1 ROWS.

      ls_trend-engine_sn          = ls_engine-engine_sn.
      ls_trend-current_egt_margin = ls_engine-current_egt_margin.
      ls_trend-threshold_used     = iv_threshold.

      " basit egim hesabi: (ilk deger - son deger) / gecen gun = gunluk dusus hizi
      IF lines( lt_first ) = 1 AND lines( lt_last ) = 1.
        DATA(lv_days) = lt_last[ 1 ]-flight_date - lt_first[ 1 ]-flight_date.
        IF lv_days > 0.
          ls_trend-decline_per_day =
            ( lt_first[ 1 ]-egt_margin_reading - lt_last[ 1 ]-egt_margin_reading ) / lv_days.
        ENDIF.
      ENDIF.

      " (mevcut marj - esik) / gunluk dusus = esige kac gun kaldi
      IF ls_trend-decline_per_day > 0.
        ls_trend-estimated_days_left =
          ( ls_trend-current_egt_margin - iv_threshold ) / ls_trend-decline_per_day.
      ELSE.
        ls_trend-estimated_days_left = 9999.  " dusus yoksa/negatifse "pratikte esige ulasmaz" sentinel
      ENDIF.

      ls_trend-estimated_date = sy-datum + ls_trend-estimated_days_left.

      APPEND ls_trend TO rt_trend.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
