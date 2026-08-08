@AbapCatalog.sqlViewName: 'ZIELDCUBE'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ELD Engine Cube'
// ANALYTICS KATMANI 1/2: CUBE
// Analitik yiginin "gercek veri" katmani. Ustune yazilacak query view
// (@Analytics.query) bu cube'u tuketecek ve SAP'nin Analytic Manager'i
// toplama (aggregation) islerini OTOMATIK yapacak - bizim $apply veya
// sap:aggregation-role kodu yazmamiza gerek kalmiyor.
//
// TANE (grain) = BIR MOTOR. Ucus saati/cevrim motor seviyesinde gercek olcu.
// Parca riski zaten alt katmanda (ZTEI_C_ELD_DASHBOARD) motor seviyesine
// indirgenmis durumda. Cube'u parca tanesinde kursaydik ucus saati parca
// sayisiyla carpilirdi - klasik tane (grain) tuzagi.
@Analytics.dataCategory: #CUBE
define view ZTEI_I_ELD_CUBE
  as select from ZTEI_C_ELD_DASHBOARD as Engine

  // Object Page navigation'lari: uretilen OData servisinde otomatik
  // navigation property olacaklar (SEGW'de elle association kurmaya gerek yok)
  association [0..*] to ZTEI_I_ELD_PART_RISK as _PartRisk
    on _PartRisk.EngineSn = Engine.EngineSn

  association [0..*] to ZTEI_I_ELD_BORESCOPE as _Borescope
    on _Borescope.EngineSn = Engine.EngineSn

{
      // ---- BOYUTLAR (characteristics) - @DefaultAggregation YOK ----
      key Engine.EngineSn             as EngineSn,
          Engine.BomId                 as BomId,
          Engine.EngineFamilyType      as EngineFamilyType,
          Engine.BaseCode              as BaseCode,
          Engine.BaseName              as BaseName,
          Engine.Status                as Status,

      // ---- OLCULER (measures) - @DefaultAggregation ZORUNLU ----
      @DefaultAggregation: #SUM
      Engine.TotalFlightHours          as TotalFlightHours,

      @DefaultAggregation: #SUM
      Engine.TotalCycles               as TotalCycles,

      // NOT: burada #AVG DENENDI ama Analytics motoru hata verdi ("Error while
      // processing select entry ... [Analytics]"). Sebep: klasik SAP OLAP
      // mimarisinde AVG native bir aggregation davranisi DEGILDIR - "ortalamalarin
      // ortalamasi" matematiksel olarak yanlis sonuc verir (SUM/MIN/MAX gibi
      // distributive degildir). Gercek ortalama icin SUM+COUNT tutup orani
      // sunum katmaninda hesaplamak gerekir - bu asamada SUM ile birakiyoruz.
      @DefaultAggregation: #SUM
      Engine.CurrentEgtMargin          as CurrentEgtMargin,

      // DIKKAT: burada #MIN kullaniliyor, #MAX degil. Cunku SAP Criticality
      // enum'unda 1=Kirmizi(en kotu), 3=Yesil(en iyi) - yani sayi kucukse
      // durum daha kotu. Bir grup motorun "en kotu" riskini bulmak icin
      // MINIMUM almak gerekiyor.
      @DefaultAggregation: #MIN
      Engine.WorstPartRiskRank         as WorstPartRiskRank,

      @DefaultAggregation: #SUM
      Engine.RedPartCount              as RedPartCount,

      @DefaultAggregation: #SUM
      Engine.YellowPartCount           as YellowPartCount,

      // association'lari expose et ki query view ve OData devralsin
      _PartRisk,
      _Borescope
}
