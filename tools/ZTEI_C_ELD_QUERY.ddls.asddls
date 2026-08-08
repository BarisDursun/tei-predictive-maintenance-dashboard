@AbapCatalog.sqlViewName: 'ZCELDQRY'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ELD Predictive Maintenance Query'
// ANALYTICS KATMANI 2/2: QUERY
// Cube'un ustundeki tuketim katmani. Iki kritik annotasyon:
//
//   @Analytics.query: true  -> bu view'i bir analitik SORGU yapar. Toplama
//        (aggregation) artik SAP'nin Analytic Manager'i tarafindan runtime'da
//        yapilir; biz $apply veya sap:aggregation-role kodu yazmayiz.
//
//   @OData.publish: true    -> OData servisini OTOMATIK uretir.
//        Uretilen servis adi: ZTEI_C_ELD_QUERY_CDS
//        Aktive ettikten sonra /IWFND/MAINT_SERVICE'te kaydedilmesi gerekiyor.
//
// Olculerin nasil toplanacagi (SUM/AVG/MIN) cube katmaninda tanimlandi,
// burada tekrar belirtmeye gerek yok - devralinir.
@Analytics.query: true
@OData.publish: true
define view ZTEI_C_ELD_QUERY
  as select from ZTEI_I_ELD_CUBE as Cube
{
      // ---- boyutlar ----
      Cube.EngineSn              as EngineSn,
      Cube.BomId                 as BomId,
      Cube.EngineFamilyType      as EngineFamilyType,
      Cube.BaseCode              as BaseCode,
      Cube.BaseName              as BaseName,
      Cube.Status                as Status,

      // ---- olculer (aggregation davranisi cube'dan devralinir) ----
      Cube.TotalFlightHours      as TotalFlightHours,
      Cube.TotalCycles           as TotalCycles,
      Cube.CurrentEgtMargin      as CurrentEgtMargin,
      Cube.WorstPartRiskRank     as WorstPartRiskRank,
      Cube.RedPartCount          as RedPartCount,
      Cube.YellowPartCount       as YellowPartCount
}
