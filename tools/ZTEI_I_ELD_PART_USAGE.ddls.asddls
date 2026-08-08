@AbapCatalog.sqlViewName: 'ZIELDPUSG'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ELD Part Usage - Basic View'
// BASIC katman: her kritik parca icin kullanim yuzdesini hesaplar.
// Risk kategorisi UST katmanda (ZTEI_I_ELD_PART_RISK) hesaplaniyor, cunku
// bu sistemin CDS surumu CASE WHEN KOSULU icinde aritmetik islem kabul etmiyor
// (sonuc ifadesinde kabul ediyor) - bu yuzden yuzde burada hazirlanip
// ust katmanda sadece sabitle karsilastiriliyor.
define view ZTEI_I_ELD_PART_USAGE
  as select from ztei_eld_part_li as Part

  association [0..1] to ztei_eld_engine as _Engine
    on _Engine.engine_sn = Part.engine_sn

{
      key Part.engine_sn                 as EngineSn,
      key Part.node_id                   as NodeId,
          Part.cycle_limit                as CycleLimit,
          Part.cycles_accumulated         as CyclesAccumulated,
          Part.last_inspection_date       as LastInspectionDate,

          // kullanim yuzdesi = kullanilan cevrim / limit * 100 (limitin ustune de cikabilir - kasitli).
          // Ham "/" sadece float tipler arasi calisiyor (DEC/packed arasi degil) - bu yuzden
          // CDS'in decimal bolme icin ozel fonksiyonu division(pay, payda, ondalik_basamak) kullaniliyor.
          cast(
            case
              when Part.cycle_limit = 0 then 0
              else division( Part.cycles_accumulated * 100, Part.cycle_limit, 1 )
            end as abap.dec( 5, 1 )
          )                                as UsagePct,

          _Engine.bom_id                   as BomId,
          _Engine.base_code                as BaseCode,
          _Engine.engine_family_type        as EngineFamilyType,

          _Engine
}
