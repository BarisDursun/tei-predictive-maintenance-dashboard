CLASS zcl_tei_eld_forecast DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Tek bir parca-tahmin satirinin yapisi (dashboard/OData'da da bu tip kullanilacak)
    TYPES: BEGIN OF ty_forecast,
             engine_sn              TYPE ztei_eld_engine-engine_sn,
             node_id                TYPE ztei_eld_part_li-node_id,
             cycle_limit            TYPE ztei_eld_part_li-cycle_limit,
             cycles_accumulated     TYPE ztei_eld_part_li-cycles_accumulated,
             usage_pct              TYPE p LENGTH 5 DECIMALS 1,   " limitin yuzde kaci kullanilmis
             usage_rate_per_day     TYPE p LENGTH 9 DECIMALS 3,   " gunluk ortalama cevrim hizi
             remaining_cycles       TYPE p LENGTH 9 DECIMALS 0,   " limite kalan cevrim
             estimated_days_left    TYPE i,                        " tahmini kalan gun (negatifse limit asilmis)
             estimated_date         TYPE dats,                     " tahmini limit tarihi
             risk_category          TYPE char1,                    " G=yesil Y=sari R=kirmizi
           END OF ty_forecast,
           tt_forecast TYPE STANDARD TABLE OF ty_forecast WITH EMPTY KEY.

    " Ana hesaplama metodu. IV_ENGINE_SN bos birakilirsa TUM motorlar/parcalar donuyor.
    CLASS-METHODS calculate_forecast
      IMPORTING
        iv_engine_sn       TYPE ztei_eld_engine-engine_sn OPTIONAL
      RETURNING
        VALUE(rt_forecast) TYPE tt_forecast.

ENDCLASS.

CLASS zcl_tei_eld_forecast IMPLEMENTATION.

  METHOD calculate_forecast.

    " Her motorun gunluk kullanim istatistigi (toplam cevrim, ilk/son log tarihi)
    TYPES: BEGIN OF ty_usage_agg,
             engine_sn  TYPE ztei_eld_usage_l-engine_sn,
             tot_cycles TYPE ztei_eld_usage_l-cycles,
             first_date TYPE ztei_eld_usage_l-flight_date,
             last_date  TYPE ztei_eld_usage_l-flight_date,
           END OF ty_usage_agg.

    DATA: lt_usage_agg TYPE HASHED TABLE OF ty_usage_agg WITH UNIQUE KEY engine_sn,
          ls_forecast  TYPE ty_forecast.

    " ONEMLI: kullanim hizini her parca icin ayri ayri sorgulamak yerine
    " (N+1 sorgu hatasi), TUM motorlarin ozetini TEK bir GROUP BY sorgusuyla
    " cekip HASHED TABLE'a aliyoruz - performans icin kritik.
    SELECT engine_sn, SUM( cycles ) AS tot_cycles,
           MIN( flight_date ) AS first_date, MAX( flight_date ) AS last_date
      FROM ztei_eld_usage_l
      GROUP BY engine_sn
      INTO CORRESPONDING FIELDS OF TABLE @lt_usage_agg.

    " Open SQL'de "IS INITIAL" desteklenmiyor - bos deger karsilastirmasi @space ile yapiliyor.
    " Inline @DATA() kullanildiginda INTO cumlesi WHERE'den SONRA, en sonda olmali (strict Open SQL kurali).
    SELECT * FROM ztei_eld_part_li
      WHERE engine_sn = @iv_engine_sn OR @iv_engine_sn = @space
      INTO TABLE @DATA(lt_parts).

    LOOP AT lt_parts INTO DATA(ls_part).
      CLEAR ls_forecast.

      ls_forecast-engine_sn          = ls_part-engine_sn.
      ls_forecast-node_id            = ls_part-node_id.
      ls_forecast-cycle_limit        = ls_part-cycle_limit.
      ls_forecast-cycles_accumulated = ls_part-cycles_accumulated.

      " kullanim yuzdesi = kullanilan cevrim / limit
      IF ls_part-cycle_limit > 0.
        ls_forecast-usage_pct = ls_part-cycles_accumulated / ls_part-cycle_limit * 100.
      ENDIF.

      " onceden hesaplanmis ozet tablodan bu motorun kullanim hizini bul (DB'ye tekrar gitmeden)
      READ TABLE lt_usage_agg INTO DATA(ls_agg) WITH TABLE KEY engine_sn = ls_part-engine_sn.
      IF sy-subrc = 0.
        DATA(lv_days) = ls_agg-last_date - ls_agg-first_date.
        IF lv_days <= 0.
          lv_days = 1.  " sifira bolme koruma (tek gunluk veri varsa)
        ENDIF.
        ls_forecast-usage_rate_per_day = ls_agg-tot_cycles / lv_days.
      ENDIF.

      ls_forecast-remaining_cycles = ls_part-cycle_limit - ls_part-cycles_accumulated.

      " kalan cevrim / gunluk hiz = kac gun sonra limite ulasir
      IF ls_forecast-usage_rate_per_day > 0.
        ls_forecast-estimated_days_left = ls_forecast-remaining_cycles / ls_forecast-usage_rate_per_day.
      ELSE.
        ls_forecast-estimated_days_left = 9999.  " kullanim yoksa "pratikte hic ulasmaz" sentinel degeri
      ENDIF.

      ls_forecast-estimated_date = sy-datum + ls_forecast-estimated_days_left.

      " risk bandi: proje arastirmasindaki esikler (bkz. README)
      IF ls_forecast-usage_pct >= 90.
        ls_forecast-risk_category = 'R'.
      ELSEIF ls_forecast-usage_pct >= 70.
        ls_forecast-risk_category = 'Y'.
      ELSE.
        ls_forecast-risk_category = 'G'.
      ENDIF.

      APPEND ls_forecast TO rt_forecast.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
