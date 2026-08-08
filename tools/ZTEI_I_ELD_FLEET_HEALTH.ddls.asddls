@AbapCatalog.sqlViewName: 'ZIELDFLTH'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ELD Fleet Health - Analytical Base'
// Motor bazinda (bir satir = bir motor) aggregate edilebilir olcum degerleri.
// NOT: @Analytics.query: true ilk basta eklenmisti ama bu sistemde gercek bir
// BW-tarzi InfoProvider olusturmaya calisip hata veriyordu ("Error reading
// InfoProvider"). Bize bu gerekmiyor - CDS'e SEGW/DPC_EXT'ten duz SELECT ile
// erisecegiz, gercek runtime analytics sorgusu kullanmiyoruz. @DefaultAggregation
// annotasyonlari (asil gosterdigimiz teknik bilgi) bu satir olmadan da gecerli.
define view ZTEI_I_ELD_FLEET_HEALTH
  as select from ztei_eld_engine as Engine
{
      key Engine.engine_sn              as EngineSn,
          Engine.bom_id                  as BomId,
          Engine.engine_family_type      as EngineFamilyType,
          Engine.base_code               as BaseCode,
          Engine.base_name               as BaseName,
          Engine.in_service_date         as InServiceDate,
          Engine.status                  as Status,

          // Status'un okunur metin hali - karakter->karakter CASE, cast'e
          // gerek yok (ZTEI_I_ELD_PART_RISK'teki RiskCategory ile ayni
          // kanitlanmis desen). Ham kod (A/M/D) yerine ekranda bu metin
          // gosterilecek (annotation.xml'de Common.Text ile baglanacak).
          case Engine.status
            when 'A' then 'Aktif'
            when 'M' then 'Bakımda'
            when 'D' then 'Devre Dışı'
            else 'Bilinmiyor'
          end                              as StatusText,

          // Filo toplam ucus saati - motorlar arasi toplanabilir (SUM)
          @DefaultAggregation: #SUM
          Engine.total_flight_hours      as TotalFlightHours,

          // Filo toplam cevrim - motorlar arasi toplanabilir (SUM)
          @DefaultAggregation: #SUM
          Engine.total_cycles            as TotalCycles,

          // EGT marjini toplanamaz, ortalamasi anlamli (AVG)
          @DefaultAggregation: #AVG
          Engine.current_egt_margin      as CurrentEgtMargin,

          // EGT marjininin EKRANDA gosterilecek metin hali icin YER TUTUCU.
          // Burada bilerek BOS birakiliyor; gercek deger DPC_EXT'teki
          // FORMAT_EGT_TEXT metodunda uretiliyor (turbin -> "71.8 C",
          // piston -> "N/A"). Sebep: bu sistemin CDS surumu sayisal -> karakter
          // donusumunu (cast) kabul etmiyor, yani sayiyi CDS icinde metne
          // ceviremiyoruz. Yine de alanin BURADA tanimli olmasi sart, cunku
          // SEGW'de Engine entity'si ZCELDDASH yapisina bagli ve orada
          // karsiligi olmayan bir property "ABAP field name '' is not part of
          // the ABAP structure 'ZCELDDASH'" hatasi veriyor.
          cast( '' as abap.char( 12 ) )  as CurrentEgtMarginTxt,

          // "Sonraki Bakim Tahmini" kolonu icin yer tutucu - CurrentEgtMarginTxt
          // ile ayni sebep (Kalip A): bu deger ABAP sinifindan
          // (ZCL_TEI_ELD_FORECAST, motorun TUM parcalari arasindaki EN YAKIN
          // tahmini sorun tarihi) geliyor, CDS'te hesaplanmiyor. Ornek
          // degerler: "47 gun", "ASILDI", "Veri Yok".
          cast( '' as abap.char( 20 ) )  as NearestForecastTxt
}
