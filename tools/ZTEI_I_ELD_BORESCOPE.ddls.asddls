@AbapCatalog.sqlViewName: 'ZIELDBORE'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ELD Borescope Findings'
// Muayene bulgulari icin basit interface view.
// Neden gerekli: cube'dan Object Page'e navigation kurabilmek icin
// association HEDEFI bir CDS view olmali (ham tablo degil) - boylece
// uretilen OData servisinde alan adlari duzgun CamelCase gorunuyor.
define view ZTEI_I_ELD_BORESCOPE
  as select from ztei_eld_boresco as Finding
{
      key Finding.finding_id        as FindingId,
          Finding.engine_sn          as EngineSn,
          Finding.inspection_date    as InspectionDate,
          Finding.severity           as Severity,
          Finding.subsystem          as Subsystem,
          Finding.finding_text       as FindingText
}
