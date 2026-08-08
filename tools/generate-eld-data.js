'use strict';
/*
 * ZTEI_ELD_PM - Predictive Maintenance test data generator / simulator.
 * Deterministic (seeded RNG) so numbers are stable and reviewable before
 * transferring to ABAP/SE16 or the SAPUI5 mock server.
 *
 * Grounding (see memory zteieldpm-project.md for full source list):
 * - LLP cycle limits: disk 15000-20000, blade 10000-12000 (FAA AC 33.70-1 / CFM56-7B reference)
 * - EGT margin: new engine ~70-90 C, red/HSI threshold ~15-20 C, decay fast-then-slow
 * - Oil debris: normal <5ppm, caution 5-15ppm, critical >15ppm
 * - Borescope severity 1-5
 * - PD170 is a compression-ignition piston engine (family 'P'): no EGT/borescope, oil+hours only
 */

const fs = require('fs');
const path = require('path');

const OUT_DIR = path.join(__dirname, 'output');
fs.mkdirSync(OUT_DIR, { recursive: true });

const TODAY = new Date('2026-08-03');

// ---- seeded RNG (mulberry32) ----
function mulberry32(seed) {
  return function () {
    seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rnd = mulberry32(20260803);
const rndBetween = (min, max) => min + rnd() * (max - min);
const rndInt = (min, max) => Math.floor(rndBetween(min, max + 1));
const pick = (arr) => arr[Math.floor(rnd() * arr.length)];

const daysBetween = (a, b) => Math.round((b - a) / 86400000);
const addDays = (d, n) => new Date(d.getTime() + n * 86400000);
const fmtDate = (d) => d.toISOString().slice(0, 10).replace(/-/g, '');

// ---- Bases (BASE_CODE must match ZTEI_ELD_BASECD_DO fixed values: BTM/MLT/VAN/ESK) ----
// Turkce karakterler (2026-08-08): CSV artik UTF-8 yaziliyor (asagidaki
// writeCsv 'latin1' -> 'utf8'), ABAP tarafinda GUI_UPLOAD'a codepage='4110'
// eklendi (bkz. ZTEI_ELD_LOAD_DATA.abap). Ikisi BIRLIKTE degismek zorunda -
// sadece burayi degistirip ABAP tarafini unutursak veri bozulur.
const BASES = {
  BTM: '14. İnsansız Uçak Sistemleri Üs Komutanlığı, Batman',
  MLT: '7. Ana Jet Üssü, Malatya',
  VAN: 'Van (Akıncı SİHA)',
  ESK: 'TEİ Ana Tesis, Eskişehir (Ar-Ge/Test)',
};

// ---- Real critical (LLP) nodes per BOM, from zteibomrisk BomNodeSet.json ----
const LLP_NODES = {
  BOM0001: [ // TF6000
    { nodeId: 'N012', tier: 'disk' },
    { nodeId: 'N014', tier: 'blade' },
    { nodeId: 'N015', tier: 'disk' },
    { nodeId: 'N021', tier: 'blade' },
    { nodeId: 'N022', tier: 'disk' },
  ],
  BOM0003: [ // TS1400
    { nodeId: 'N210', tier: 'disk' },
    { nodeId: 'N214', tier: 'blade' },
    { nodeId: 'N215', tier: 'disk' },
    { nodeId: 'N216', tier: 'blade' },
    { nodeId: 'N217', tier: 'disk' },
  ],
  BOM0004: [ // TF10000 (shares TF6000 core numbering)
    { nodeId: 'N012', tier: 'disk' },
    { nodeId: 'N014', tier: 'blade' },
    { nodeId: 'N015', tier: 'disk' },
    { nodeId: 'N021', tier: 'blade' },
    { nodeId: 'N022', tier: 'disk' },
  ],
  BOM0005: [ // TJ90
    { nodeId: 'N310', tier: 'disk' },
    { nodeId: 'N312', tier: 'disk' },
  ],
  BOM0006: [ // TP38
    { nodeId: 'N410', tier: 'disk' },
  ],
};
const CYCLE_LIMIT_RANGE = { disk: [15000, 20000], blade: [10000, 12000] };

// ---- Engine model config ----
const ENGINE_TYPES = [
  {
    bomId: 'BOM0001', snPrefix: 'TF6000', family: 'T', count: 3,
    bases: ['ESK'], inServiceYearsAgo: [0.7, 2.1],
    hoursPerYear: [40, 110], hoursPerFlight: [0.5, 1.8], flightsPerWeek: [1, 3],
    egtNew: [78, 88], egtRedThreshold: [16, 20], wearRate: [0.7, 1.1],
  },
  {
    bomId: 'BOM0002', snPrefix: 'PD170', family: 'P', count: 6,
    bases: ['BTM', 'VAN'], inServiceYearsAgo: [1.5, 6.5],
    hoursPerYear: [180, 320], hoursPerFlight: [3, 8], flightsPerWeek: [3, 6],
  },
  {
    bomId: 'BOM0003', snPrefix: 'TS1400', family: 'T', count: 4,
    bases: ['BTM', 'VAN'], inServiceYearsAgo: [1.8, 4.5],
    hoursPerYear: [200, 380], hoursPerFlight: [2, 5], flightsPerWeek: [3, 5],
    egtNew: [70, 82], egtRedThreshold: [15, 18], wearRate: [0.8, 1.3],
  },
  {
    bomId: 'BOM0004', snPrefix: 'TF10000', family: 'T', count: 2,
    bases: ['ESK'], inServiceYearsAgo: [0.4, 1.3],
    hoursPerYear: [25, 70], hoursPerFlight: [0.4, 1.5], flightsPerWeek: [1, 2],
    egtNew: [75, 85], egtRedThreshold: [16, 20], wearRate: [0.7, 1.1],
  },
  {
    bomId: 'BOM0005', snPrefix: 'TJ90', family: 'T', count: 3,
    bases: ['MLT', 'BTM'], inServiceYearsAgo: [1.8, 4.8],
    hoursPerYear: [60, 140], hoursPerFlight: [0.2, 0.9], flightsPerWeek: [2, 4],
    egtNew: [55, 70], egtRedThreshold: [12, 15], wearRate: [0.9, 1.4],
  },
  {
    bomId: 'BOM0006', snPrefix: 'TP38', family: 'T', count: 2,
    bases: ['ESK', 'MLT'], inServiceYearsAgo: [0.9, 2.8],
    hoursPerYear: [80, 180], hoursPerFlight: [1, 3], flightsPerWeek: [1, 3],
    egtNew: [60, 72], egtRedThreshold: [13, 16], wearRate: [0.8, 1.2],
  },
  {
    // Dedicated ground endurance/qualification test article (TEI Eskisehir test cell) -
    // real practice: OEMs deliberately run a test engine to/beyond LLP limits to validate
    // them before certification. This is the only engine expected to show yellow/red parts;
    // the fielded fleet is genuinely too young (all in-service <6.5y) to be near any LLP limit.
    bomId: 'BOM0003', snPrefix: 'TS1400-END', family: 'T', count: 1, fixedSn: 'TS1400-DUR1',
    bases: ['ESK'], inServiceYearsAgo: [1.3, 1.7],
    hoursPerYear: [2200, 2800], hoursPerFlight: [0.2, 0.3], flightsPerWeek: [20, 28],
    egtNew: [70, 82], egtRedThreshold: [15, 18], wearRate: [1.3, 1.6],
  },
];

const engines = [];
const partLife = [];
const usageLog = [];
const borescope = [];
let logIdSeq = 1;
let findingIdSeq = 1;

// Digital monitoring system window: only last DIGITAL_WINDOW_YEARS are logged flight-by-flight
const DIGITAL_WINDOW_YEARS = 2;

for (const type of ENGINE_TYPES) {
  for (let i = 1; i <= type.count; i++) {
    const engineSn = type.fixedSn || `${type.snPrefix}-${String(i).padStart(3, '0')}`;
    const inServiceYearsAgo = rndBetween(...type.inServiceYearsAgo);
    const inServiceDate = addDays(TODAY, -Math.round(inServiceYearsAgo * 365));
    const ageYears = inServiceYearsAgo;
    const hoursPerYear = rndBetween(...type.hoursPerYear);
    const totalFlightHours = Math.round(hoursPerYear * ageYears * rndBetween(0.85, 1.15) * 10) / 10;
    const avgFlightHours = rndBetween(...type.hoursPerFlight);
    const totalCycles = Math.round(totalFlightHours / avgFlightHours);
    const base = pick(type.bases);

    let currentEgtMargin = 0;
    let wearRate = 1;
    if (type.family === 'T') {
      const egtNew = rndBetween(...type.egtNew);
      const egtRed = rndBetween(...type.egtRedThreshold);
      wearRate = rndBetween(...type.wearRate);
      // fast-early-then-slow decay approaching (egtNew-egtRed) asymptotically over ~12 "wear-years"
      const decayFrac = 1 - Math.exp(-wearRate * ageYears / 4.5);
      currentEgtMargin = Math.round((egtNew - decayFrac * (egtNew - egtRed) * rndBetween(0.5, 0.95)) * 10) / 10;
      type._egtNewPicked = egtNew; type._egtRedPicked = egtRed; type._wearPicked = wearRate;
    }

    const status = ageYears < 0.15 ? 'A' : (rnd() < 0.08 ? 'M' : (rnd() < 0.03 ? 'D' : 'A'));

    engines.push({
      ENGINE_SN: engineSn,
      BOM_ID: type.bomId,
      ENGINE_FAMILY_TYPE: type.family,
      BASE_CODE: base,
      BASE_NAME: BASES[base],
      IN_SERVICE_DATE: fmtDate(inServiceDate),
      TOTAL_FLIGHT_HOURS: totalFlightHours.toFixed(1),
      TOTAL_CYCLES: String(totalCycles),
      CURRENT_EGT_MARGIN: type.family === 'T' ? currentEgtMargin.toFixed(1) : '0.0',
      STATUS: status,
    });

    // ---- PART_LIFE (T family only) ----
    const nodes = LLP_NODES[type.bomId] || [];
    for (const node of nodes) {
      const [lo, hi] = CYCLE_LIMIT_RANGE[node.tier];
      const cycleLimit = rndInt(lo, hi);
      const replaced = rnd() < 0.15 && ageYears > 2; // ~15% of parts on older engines were swapped
      const cyclesAccumulated = replaced
        ? Math.round(totalCycles * rndBetween(0.05, 0.35))
        : Math.round(totalCycles * rndBetween(0.9, 1.0));
      const lastInspDaysAgo = rndInt(20, 400);
      partLife.push({
        ENGINE_SN: engineSn,
        NODE_ID: node.nodeId,
        CYCLE_LIMIT: String(cycleLimit),
        CYCLES_ACCUMULATED: String(Math.min(cyclesAccumulated, cycleLimit - 1 >= 0 ? cyclesAccumulated : cyclesAccumulated)),
        LAST_INSPECTION_DATE: fmtDate(addDays(TODAY, -lastInspDaysAgo)),
      });
    }

    // ---- USAGE_LOG: digitized window only ----
    const windowYears = Math.min(ageYears, DIGITAL_WINDOW_YEARS);
    const windowStart = addDays(TODAY, -Math.round(windowYears * 365));
    const flightsPerWeek = rndBetween(...type.flightsPerWeek);
    const totalDaysInWindow = daysBetween(windowStart, TODAY);
    const numFlights = Math.round((totalDaysInWindow / 7) * flightsPerWeek);

    let cursorDate = new Date(windowStart);
    for (let f = 0; f < numFlights; f++) {
      cursorDate = addDays(cursorDate, rndInt(1, Math.max(1, Math.round(7 / flightsPerWeek) * 2)));
      if (cursorDate > TODAY) break;
      const flightHours = Math.round(rndBetween(avgFlightHours * 0.6, avgFlightHours * 1.4) * 10) / 10;
      const cycles = rnd() < 0.85 ? 1 : 2;

      let egtReading = '';
      if (type.family === 'T') {
        const ageAtFlight = daysBetween(inServiceDate, cursorDate) / 365;
        const decayFrac = 1 - Math.exp(-wearRate * ageAtFlight / 4.5);
        const val = type._egtNewPicked - decayFrac * (type._egtNewPicked - type._egtRedPicked) * rndBetween(0.5, 0.95)
          + rndBetween(-2.5, 2.5);
        egtReading = val.toFixed(1);
      }

      // borescope finding: small chance per flight, severity weighted toward low
      // (realistic: most findings cosmetic/minor, critical ones rare)
      let findingSeverity = null;
      if (type.family === 'T' && rnd() < 0.016) {
        const w = rnd();
        findingSeverity = w < 0.40 ? 1 : w < 0.70 ? 2 : w < 0.88 ? 3 : w < 0.97 ? 4 : 5;
      }

      const ageAtFlight = daysBetween(inServiceDate, cursorDate) / 365;
      let oilPpm = 1.5 + ageAtFlight * rndBetween(0.6, 1.4) + rndBetween(-0.5, 0.5);
      // oil debris spikes alongside a severe (4-5) borescope finding - consistent story
      if (findingSeverity >= 4) oilPpm += rndBetween(8, 16);
      oilPpm = Math.max(0.2, oilPpm);

      usageLog.push({
        LOG_ID: String(logIdSeq++).padStart(10, '0'),
        ENGINE_SN: engineSn,
        FLIGHT_DATE: fmtDate(cursorDate),
        FLIGHT_HOURS: flightHours.toFixed(1),
        CYCLES: String(cycles),
        EGT_MARGIN_READING: egtReading,
        OIL_DEBRIS_PPM: oilPpm.toFixed(2),
      });

      if (findingSeverity) {
        const subsystems = type.bomId === 'BOM0001' || type.bomId === 'BOM0004'
          ? ['Fan', 'Kompresör', 'Türbin']
          : type.bomId === 'BOM0003' ? ['Kompresör', 'Gaz Üretici Türbini', 'Güç Türbini']
          : ['Kompresör', 'Türbin'];
        const subsystem = pick(subsystems);
        const findingTextBySeverity = {
          1: 'Kozmetik iz, limit dahilinde',
          2: 'Hafif erozyon, izlemede',
          3: 'Eşiğe yaklaşan aşınma, yakın takip',
          4: 'Limit aşıldı, sonraki uçuş öncesi tamir gerekli',
          5: 'Kritik hasar, motor söküm gerekli',
        };
        borescope.push({
          FINDING_ID: String(findingIdSeq++).padStart(10, '0'),
          ENGINE_SN: engineSn,
          INSPECTION_DATE: fmtDate(cursorDate),
          SEVERITY: String(findingSeverity),
          SUBSYSTEM: subsystem,
          FINDING_TEXT: findingTextBySeverity[findingSeverity],
        });
      }
    }
  }
}

fs.writeFileSync(path.join(OUT_DIR, 'ZTEI_ELD_ENGINE.json'), JSON.stringify(engines, null, 2));
fs.writeFileSync(path.join(OUT_DIR, 'ZTEI_ELD_PART_LIFE.json'), JSON.stringify(partLife, null, 2));
fs.writeFileSync(path.join(OUT_DIR, 'ZTEI_ELD_USAGE_LOG.json'), JSON.stringify(usageLog, null, 2));
fs.writeFileSync(path.join(OUT_DIR, 'ZTEI_ELD_BORESCOPE.json'), JSON.stringify(borescope, null, 2));

// ---- CSV output for ABAP GUI_UPLOAD (semicolon-delimited - BASE_NAME contains commas) ----
// DIKKAT: 'latin1' -> 'utf8' (2026-08-08). Latin-1'de Turkce'ye ozgu
// karakterler (i, I, s, S, g, G) YOKTUR - o kodlamayla yazilan bir 's'
// sessizce bozulurdu. ABAP tarafinda GUI_UPLOAD cagrisina karsilik gelen
// codepage='4110' (UTF-8) parametresi eklendi (bkz. ZTEI_ELD_LOAD_DATA.abap) -
// ikisi BIRLIKTE degismek zorunda, biri unutulursa veri bozulur.
function writeCsv(filename, rows, columns) {
  const lines = [columns.join(';')];
  for (const r of rows) lines.push(columns.map(c => r[c] ?? '').join(';'));
  fs.writeFileSync(path.join(OUT_DIR, filename), lines.join('\r\n'), 'utf8');
}
writeCsv('ZTEI_ELD_ENGINE.csv', engines,
  ['ENGINE_SN', 'BOM_ID', 'ENGINE_FAMILY_TYPE', 'BASE_CODE', 'BASE_NAME', 'IN_SERVICE_DATE', 'TOTAL_FLIGHT_HOURS', 'TOTAL_CYCLES', 'CURRENT_EGT_MARGIN', 'STATUS']);
writeCsv('ZTEI_ELD_PART_LIFE.csv', partLife,
  ['ENGINE_SN', 'NODE_ID', 'CYCLE_LIMIT', 'CYCLES_ACCUMULATED', 'LAST_INSPECTION_DATE']);
writeCsv('ZTEI_ELD_USAGE_LOG.csv', usageLog,
  ['LOG_ID', 'ENGINE_SN', 'FLIGHT_DATE', 'FLIGHT_HOURS', 'CYCLES', 'EGT_MARGIN_READING', 'OIL_DEBRIS_PPM']);
writeCsv('ZTEI_ELD_BORESCOPE.csv', borescope,
  ['FINDING_ID', 'ENGINE_SN', 'INSPECTION_DATE', 'SEVERITY', 'SUBSYSTEM', 'FINDING_TEXT']);

// ---- summary ----
console.log('=== ZTEI_ELD_ENGINE ===', engines.length, 'kayit');
for (const e of engines) {
  console.log(`  ${e.ENGINE_SN.padEnd(12)} ${e.BOM_ID} fam=${e.ENGINE_FAMILY_TYPE} base=${e.BASE_CODE} inService=${e.IN_SERVICE_DATE} hrs=${e.TOTAL_FLIGHT_HOURS} cyc=${e.TOTAL_CYCLES} egt=${e.CURRENT_EGT_MARGIN} status=${e.STATUS}`);
}
console.log('\n=== ZTEI_ELD_PART_LIFE ===', partLife.length, 'kayit (ornek ilk 8)');
partLife.slice(0, 8).forEach(p => console.log(' ', p));
console.log('\n=== ZTEI_ELD_USAGE_LOG ===', usageLog.length, 'kayit (ornek ilk 3)');
usageLog.slice(0, 3).forEach(u => console.log(' ', u));
console.log('\n=== ZTEI_ELD_BORESCOPE ===', borescope.length, 'kayit (ornek ilk 5)');
borescope.slice(0, 5).forEach(b => console.log(' ', b));

const bySeverity = borescope.reduce((acc, b) => { acc[b.SEVERITY] = (acc[b.SEVERITY] || 0) + 1; return acc; }, {});
console.log('\nBorescope severity dagilimi:', bySeverity);
console.log('\nToplam: ENGINE=%d PART_LIFE=%d USAGE_LOG=%d BORESCOPE=%d', engines.length, partLife.length, usageLog.length, borescope.length);
