'use strict';
/*
 * ZTEI_ELD_PM_SRV mock data generator.
 * Reads the already-generated dataset (generate-eld-data.js output) and
 * reshapes it into the exact OData property casing from metadata.xml,
 * writing directly into webapp/localService/mockdata/*.json.
 *
 * Forecast/EgtTrend have no DB table behind them (ABAP class output) so
 * their values are computed here with the SAME logic as
 * ZCL_TEI_ELD_FORECAST / ZCL_TEI_ELD_EGT_TREND, to keep mock and real
 * backend consistent.
 */

const fs = require('fs');
const path = require('path');

const SRC_DIR = path.join(__dirname, 'output');
// NOT: yol ui5-mock.yaml'daki mockdataPath ile birebir eslesmeli
const OUT_DIR = path.join(__dirname, '..', 'webapp', 'localService', 'mainService', 'data');
fs.mkdirSync(OUT_DIR, { recursive: true });

const TODAY = new Date('2026-08-04');

const engines = JSON.parse(fs.readFileSync(path.join(SRC_DIR, 'ZTEI_ELD_ENGINE.json')));
const partLife = JSON.parse(fs.readFileSync(path.join(SRC_DIR, 'ZTEI_ELD_PART_LIFE.json')));
const usageLog = JSON.parse(fs.readFileSync(path.join(SRC_DIR, 'ZTEI_ELD_USAGE_LOG.json')));
const borescope = JSON.parse(fs.readFileSync(path.join(SRC_DIR, 'ZTEI_ELD_BORESCOPE.json')));

const parseYyyymmdd = (s) => new Date(`${s.slice(0, 4)}-${s.slice(4, 6)}-${s.slice(6, 8)}`);
const odataDate = (d) => `/Date(${d.getTime()})/`;
const daysBetween = (a, b) => Math.round((b - a) / 86400000);

const engineBySn = new Map(engines.map((e) => [e.ENGINE_SN, e]));

// ---- usage aggregation per engine (mirrors the ABAP GROUP BY in ZCL_TEI_ELD_FORECAST) ----
const usageAgg = new Map(); // engineSn -> { totCycles, firstDate, lastDate }
for (const u of usageLog) {
  const d = parseYyyymmdd(u.FLIGHT_DATE);
  const agg = usageAgg.get(u.ENGINE_SN) || { totCycles: 0, firstDate: d, lastDate: d };
  agg.totCycles += Number(u.CYCLES);
  if (d < agg.firstDate) agg.firstDate = d;
  if (d > agg.lastDate) agg.lastDate = d;
  usageAgg.set(u.ENGINE_SN, agg);
}

// ---- first/last EGT reading per engine (mirrors ZCL_TEI_ELD_EGT_TREND) ----
const egtReadings = new Map(); // engineSn -> [{date, value}] sorted
for (const u of usageLog) {
  if (!u.EGT_MARGIN_READING) continue;
  const list = egtReadings.get(u.ENGINE_SN) || [];
  list.push({ date: parseYyyymmdd(u.FLIGHT_DATE), value: Number(u.EGT_MARGIN_READING) });
  egtReadings.set(u.ENGINE_SN, list);
}
for (const list of egtReadings.values()) list.sort((a, b) => a.date - b.date);

function writeJson(filename, data) {
  fs.writeFileSync(path.join(OUT_DIR, filename), JSON.stringify(data, null, 2));
  console.log(`${filename}: ${data.length} kayit`);
}

// Status kodunun okunur metni - ZTEI_I_ELD_FLEET_HEALTH'teki CDS CASE'in
// birebir JS karsiligi (A/M/D disinda hicbir deger uretilmiyor ama
// tutarlilik icin "Bilinmiyor" da eklendi).
const STATUS_TEXT = { A: 'Aktif', M: 'Bakımda', D: 'Devre Dışı' };

// ---- EngineSet ----
const engineSet = engines.map((e) => ({
  Enginesn: e.ENGINE_SN,
  Bomid: e.BOM_ID,
  Enginefamilytype: e.ENGINE_FAMILY_TYPE,
  Basecode: e.BASE_CODE,
  Basename: e.BASE_NAME,
  Status: e.STATUS,
  Statustext: STATUS_TEXT[e.STATUS] || 'Bilinmiyor',
  Totalflighthours: e.TOTAL_FLIGHT_HOURS,
  Totalcycles: e.TOTAL_CYCLES,
  Currentegtmargin: e.CURRENT_EGT_MARGIN,
  // Ekranda sayinin yerine bu metin gosteriliyor (Common.Text + TextArrangement=TextOnly).
  // DPC_EXT'teki FORMAT_EGT_TEXT metodunun birebir JS karsiligi - mock ile gercek
  // backend'in ayni davranmasi icin ikisi de ayni kurali uygulamak zorunda.
  // Pistonlu (P) motorda EGT marjini kavrami gecersiz -> "N/A".
  Currentegtmargintxt: e.ENGINE_FAMILY_TYPE === 'P'
    ? 'N/A'
    : `${Number(e.CURRENT_EGT_MARGIN).toFixed(1)} C`,
  // "Sonraki Bakim Tahmini" - ForecastSet hesaplandiktan SONRA, asagidaki
  // ikinci gecişte doldurulacak (Redpartcount/Worstpartriskrank ile ayni
  // "once yer ac, sonra geri doldur" deseni).
  Nearestforecasttxt: 'Veri Yok',
  Worstpartriskrank: 3, // varsayilan: risk verisi yok/hepsi yesil (SAP Criticality: 3=Positive)
  Redpartcount: 0,
  Yellowpartcount: 0,
}));

// ---- PartRiskSet (also fills in Engine's Worst/Red/Yellow counts, mirrors ZTEI_C_ELD_DASHBOARD) ----
const partRiskSet = partLife.map((p) => {
  const limit = Number(p.CYCLE_LIMIT);
  const acc = Number(p.CYCLES_ACCUMULATED);
  const usagePct = limit === 0 ? 0 : Math.round((acc * 100 / limit) * 10) / 10;
  const riskCategory = limit > 0 && acc * 100 >= limit * 90 ? 'R'
    : limit > 0 && acc * 100 >= limit * 70 ? 'Y' : 'G';

  // WorstPartRiskRank SAP UI.Criticality enum'uyla hizali: 1=Negative(Kirmizi), 2=Critical(Sari), 3=Positive(Yesil)
  const eng = engineBySn.get(p.ENGINE_SN);
  const engineRow = engineSet.find((e) => e.Enginesn === p.ENGINE_SN);
  if (engineRow) {
    if (riskCategory === 'R') { engineRow.Redpartcount++; engineRow.Worstpartriskrank = 1; }
    else if (riskCategory === 'Y') { engineRow.Yellowpartcount++; if (engineRow.Worstpartriskrank > 2) engineRow.Worstpartriskrank = 2; }
  }

  // RiskCategory'nin okunur metni + SAP Criticality'ye hizali sirali hali -
  // ZTEI_I_ELD_PART_RISK'teki CDS CASE'lerin birebir JS karsiligi.
  const riskCategoryText = riskCategory === 'R' ? 'Kırmızı' : riskCategory === 'Y' ? 'Sarı' : 'Yeşil';
  const riskRank = riskCategory === 'R' ? 1 : riskCategory === 'Y' ? 2 : 3;

  return {
    Enginesn: p.ENGINE_SN,
    Nodeid: p.NODE_ID,
    Cyclelimit: p.CYCLE_LIMIT,
    Cyclesaccumulated: p.CYCLES_ACCUMULATED,
    Lastinspectiondate: odataDate(parseYyyymmdd(p.LAST_INSPECTION_DATE)),
    Usagepct: usagePct.toFixed(1),
    Riskcategory: riskCategory,
    Riskcategorytext: riskCategoryText,
    Riskrank: riskRank,
    Bomid: eng.BOM_ID,
    Basecode: eng.BASE_CODE,
    Enginefamilytype: eng.ENGINE_FAMILY_TYPE,
  };
});

// ---- BorescopeSet ----
const borescopeSet = borescope.map((b) => ({
  FindingId: b.FINDING_ID,
  EngineSn: b.ENGINE_SN,
  InspectionDate: odataDate(parseYyyymmdd(b.INSPECTION_DATE)),
  Severity: b.SEVERITY,
  Subsystem: b.SUBSYSTEM,
  FindingText: b.FINDING_TEXT,
}));

// ---- ForecastSet (mirrors ZCL_TEI_ELD_FORECAST=>calculate_forecast) ----
const forecastSet = partLife.map((p) => {
  const limit = Number(p.CYCLE_LIMIT);
  const acc = Number(p.CYCLES_ACCUMULATED);
  const usagePct = limit === 0 ? 0 : Math.round((acc * 100 / limit) * 10) / 10;
  const agg = usageAgg.get(p.ENGINE_SN);
  let daysSpan = agg ? daysBetween(agg.firstDate, agg.lastDate) : 0;
  if (daysSpan <= 0) daysSpan = 1;
  const usageRate = agg ? agg.totCycles / daysSpan : 0;
  const remaining = limit - acc;
  const estDays = usageRate > 0 ? Math.round(remaining / usageRate) : 9999;
  const estDate = new Date(TODAY.getTime() + estDays * 86400000);
  const riskCategory = limit > 0 && acc * 100 >= limit * 90 ? 'R'
    : limit > 0 && acc * 100 >= limit * 70 ? 'Y' : 'G';

  return {
    EngineSn: p.ENGINE_SN,
    NodeId: p.NODE_ID,
    CycleLimit: p.CYCLE_LIMIT,
    CyclesAccumulated: p.CYCLES_ACCUMULATED,
    UsagePct: usagePct.toFixed(1),
    UsageRatePerDay: usageRate.toFixed(3),
    RemainingCycles: String(remaining),
    EstimatedDaysLeft: estDays,
    EstimatedDate: odataDate(estDate),
    RiskCategory: riskCategory,
  };
});

// ---- EgtTrendSet (mirrors ZCL_TEI_ELD_EGT_TREND=>calculate_trend, T-family only) ----
const THRESHOLD = 15.0;
const egtTrendSet = engines
  .filter((e) => e.ENGINE_FAMILY_TYPE === 'T')
  .map((e) => {
    const readings = egtReadings.get(e.ENGINE_SN) || [];
    let decline = 0;
    if (readings.length >= 2) {
      const first = readings[0];
      const last = readings[readings.length - 1];
      const days = daysBetween(first.date, last.date);
      if (days > 0) decline = (first.value - last.value) / days;
    }
    const current = Number(e.CURRENT_EGT_MARGIN);
    const estDays = decline > 0 ? Math.round((current - THRESHOLD) / decline) : 9999;
    const estDate = new Date(TODAY.getTime() + estDays * 86400000);

    return {
      EngineSn: e.ENGINE_SN,
      CurrentEgtMargin: e.CURRENT_EGT_MARGIN,
      DeclinePerDay: decline.toFixed(4),
      ThresholdUsed: THRESHOLD.toFixed(1),
      EstimatedDaysLeft: estDays,
      EstimatedDate: odataDate(estDate),
    };
  });

// ---- EngineSet'i geri doldur: her motorun TUM parcalari arasindaki EN
// YAKIN (en kucuk EstimatedDaysLeft) tahmini bul. DPC_EXT'teki
// ENGINESET_GET_ENTITYSET'teki lt_nearest mantiginin birebir JS karsiligi. ----
const nearestByEngine = new Map(); // engineSn -> en kucuk EstimatedDaysLeft
for (const fc of forecastSet) {
  const cur = nearestByEngine.get(fc.EngineSn);
  if (cur === undefined || fc.EstimatedDaysLeft < cur) {
    nearestByEngine.set(fc.EngineSn, fc.EstimatedDaysLeft);
  }
}
for (const eng of engineSet) {
  const days = nearestByEngine.get(eng.Enginesn);
  // Esik `=== 9999` (tam esitlik) - genc filo icin GERCEK ama COK BUYUK
  // gun sayilari da olabilir (orn. 18000+ gun), bunlar "veri yok" degil.
  // DPC_EXT'teki ayni duzeltmenin JS karsiligi (bkz. DPC_EXT_NEAREST_FORECAST.abap).
  if (days === undefined || days === 9999) {
    eng.Nearestforecasttxt = 'Veri Yok';
  } else if (days < 0) {
    eng.Nearestforecasttxt = 'ASILDI';
  } else if (days > 3650) {
    eng.Nearestforecasttxt = '10+ yıl';
  } else {
    eng.Nearestforecasttxt = `${days} gün`;
  }
}

writeJson('EngineSet.json', engineSet);
writeJson('PartRiskSet.json', partRiskSet);
writeJson('BorescopeSet.json', borescopeSet);
writeJson('ForecastSet.json', forecastSet);
writeJson('EgtTrendSet.json', egtTrendSet);
