@AbapCatalog.sqlViewName: 'ZCELDDASH'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ELD Dashboard - Engine + Worst Part Risk'
// Bir satir = bir motor. FLEET_HEALTH'teki motor olculerini, PART_RISK'teki
// parcalarin OZETIYLE (en kotu risk, kirmizi/sari parca sayisi) birlestiriyor.
// PD170 (family P) motorlarin hic parca-risk kaydi yok (LEFT OUTER JOIN + CASE ELSE 1
// ile "risk verisi yok = yesil" olarak ele aliniyor - turbine olmadigi icin zaten anlamli degil).
// NOT: Burada gercek bir GROUP BY var, bu yuzden GROUP BY'da olmayan her sutun
// GERCEK bir SQL aggregate fonksiyonuna (max()/sum()) sarilmali - @DefaultAggregation
// annotasyonu sadece @Analytics.query ile calisan runtime aggregation icin, burada islevi yok.
define view ZTEI_C_ELD_DASHBOARD
  as select from ZTEI_I_ELD_FLEET_HEALTH as Engine

  left outer join ZTEI_I_ELD_PART_RISK   as Part
    on Part.EngineSn = Engine.EngineSn

{
      key Engine.EngineSn                 as EngineSn,
          Engine.BomId                     as BomId,
          Engine.EngineFamilyType          as EngineFamilyType,
          Engine.BaseCode                  as BaseCode,
          Engine.BaseName                  as BaseName,
          Engine.Status                    as Status,

          // Status'un okunur metin hali - alt katmandan (FLEET_HEALTH) geciyor,
          // gercek CASE ile orada hesaplaniyor (yer tutucu DEGIL, DPC_EXT'e
          // gerek yok - CurrentEgtMarginTxt'ten farki bu).
          Engine.StatusText                as StatusText,

          Engine.TotalFlightHours          as TotalFlightHours,
          Engine.TotalCycles               as TotalCycles,
          Engine.CurrentEgtMargin          as CurrentEgtMargin,

          // Alt katmandan geciyor - CDS'te bos, DPC_EXT dolduruyor.
          // GROUP BY listesine de eklendi (asagida), cunku aggregate degil.
          Engine.CurrentEgtMarginTxt       as CurrentEgtMarginTxt,

          // "Sonraki Bakim Tahmini" - CurrentEgtMarginTxt ile ayni desen,
          // ABAP sinifindan (ZCL_TEI_ELD_FORECAST) DPC_EXT'te doldurulacak.
          Engine.NearestForecastTxt        as NearestForecastTxt,

          // en kotu parca riski - SAP UI.Criticality enum'uyla hizali: 1=Negative(Kirmizi),
          // 2=Critical(Sari), 3=Positive(Yesil)/veri-yok. Boylece frontend'de ayrica
          // deger-cevirme annotasyonu yazmaya gerek kalmiyor, direkt Criticality'ye baglanabiliyor.
          //
          // DIKKAT - burada MIN kullaniliyor, MAX DEGIL. Sezgiye ters gelebilir ama
          // olcekte KUCUK sayi DAHA KOTU durumu ifade ediyor (1=Kirmizi, 3=Yesil),
          // yani bir motorun "en kotu" parcasini bulmak MINIMUM almak demek.
          // Bu satir onceden max() idi ve riski oldugundan HAFIF gosteriyordu:
          //   [1,1,2,2,2] (2 kirmizi + 3 sari parca) -> max=2 "sari", dogrusu min=1 "kirmizi"
          //   [3,3,2,3,3] (1 sari parca)             -> max=3 "yesil", sari tamamen gizleniyordu
          // Parcasi olmayan motorlarda (PD170, pistonlu) LEFT OUTER JOIN null verir,
          // case ELSE 3 devreye girer, min de 3 = yesil olur - dogru davranis.
          min(
            case Part.RiskCategory
              when 'R' then 1
              when 'Y' then 2
              else 3
            end
          )                                as WorstPartRiskRank,

          sum( case when Part.RiskCategory = 'R' then 1 else 0 end ) as RedPartCount,

          sum( case when Part.RiskCategory = 'Y' then 1 else 0 end ) as YellowPartCount
}
group by
  Engine.EngineSn,
  Engine.BomId,
  Engine.EngineFamilyType,
  Engine.BaseCode,
  Engine.BaseName,
  Engine.Status,
  Engine.StatusText,
  Engine.TotalFlightHours,
  Engine.TotalCycles,
  Engine.CurrentEgtMargin,
  Engine.CurrentEgtMarginTxt,
  Engine.NearestForecastTxt
