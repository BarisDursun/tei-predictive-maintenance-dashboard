@AbapCatalog.sqlViewName: 'ZIELDPRSK'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ELD Part Risk'
// COMPOSITE katman: basic view'daki hazir UsagePct'i risk bandina cevirir.
// Kosulda aritmetik YOK - sadece sabit karsilastirma (bkz. ZTEI_I_ELD_PART_USAGE notu).
define view ZTEI_I_ELD_PART_RISK
  as select from ZTEI_I_ELD_PART_USAGE as Part
{
      key Part.EngineSn                  as EngineSn,
      key Part.NodeId                    as NodeId,
          Part.CycleLimit                 as CycleLimit,
          Part.CyclesAccumulated          as CyclesAccumulated,
          Part.LastInspectionDate         as LastInspectionDate,
          Part.UsagePct                   as UsagePct,

          // risk bandi: arastirmadaki esikler (%70 sari, %90 kirmizi)
          case
            when Part.UsagePct >= 90 then 'R'
            when Part.UsagePct >= 70 then 'Y'
            else 'G'
          end                              as RiskCategory,

          // RiskCategory'nin okunur metin hali - Engine listesindeki
          // Kirmizi/Sari/Yesil Parca kolon etiketleriyle ayni kelimeler,
          // gorsel dil tutarli kalsin diye.
          case
            when Part.UsagePct >= 90 then 'Kırmızı'
            when Part.UsagePct >= 70 then 'Sarı'
            else 'Yeşil'
          end                              as RiskCategoryText,

          // RiskCategory'nin SAP UI.Criticality enum'una hizali sirali hali
          // (1=Kirmizi/Negative, 2=Sari/Critical, 3=Yesil/Positive) - Object
          // Page'deki Risk kolonunda renkli gosterge icin (Engine listesindeki
          // Worstpartriskrank ile ayni desen).
          case
            when Part.UsagePct >= 90 then 1
            when Part.UsagePct >= 70 then 2
            else 3
          end                              as RiskRank,

          Part.BomId                       as BomId,
          Part.BaseCode                    as BaseCode,
          Part.EngineFamilyType            as EngineFamilyType
}
