# TEI ELD Predictive Maintenance Dashboard

*Türkçe için [README.tr.md](README.tr.md)'ye bakın.*

An SAP Fiori Elements **Analytical List Page + Object Page** dashboard for predictive maintenance of an aircraft engine fleet — built on classic **CDS views**, **ABAP forecast/trend classes with ABAP Unit tests**, and a **classic SEGW OData V2** service.

Third in a series of SAP Fiori/ABAP portfolio projects, following [tei-part-traceability-portal](https://github.com/BarisDursun/tei-part-traceability-portal) and [tei-bom-embargo-risk-simulator](https://github.com/BarisDursun/tei-bom-embargo-risk-simulator). This one deliberately reuses the fleet (TF6000, PD170, TS1400, TF10000, TJ90, TP38) and BOM data from project 2, modeling physical serial-numbered engine instances against those existing part models — an attempt at an integrated mini-ERP narrative across the three projects rather than three disconnected demos.

## Screenshots

| | |
|---|---|
| ![ALP overview](docs/images/01-alp-overview.png) | ![Critical parts](docs/images/02-object-page-critical-parts.png) |
| Analytical List Page — chart + table, sorted worst-risk-first | Object Page — critical (LLP) parts, color-coded risk |
| ![Borescope findings](docs/images/03-object-page-borescope.png) | ![Life forecast](docs/images/04-object-page-forecast.png) |
| Borescope inspection history | Life forecast per part — the "predictive" payoff |
| ![EGT trend](docs/images/05-object-page-egt-trend.png) | ![Filter bar](docs/images/06-filter-bar.png) |
| EGT margin decline trend | Filter bar in use |
| ![Backend data](docs/images/07-se11-tables.png) | ![Unit tests](docs/images/08-abap-unit-tests.png) |
| Real seeded data in the Z-tables | ABAP Unit test run — 10/10 green |

## Why this project

Projects 1 and 2 proved out classic CRUD and hierarchical/recursive OData patterns. This one deliberately targets a different SAP skill: **analytical CDS views feeding a Fiori Elements Analytical List Page**, plus genuinely *predictive* (not just descriptive) business logic — a class that projects when a life-limited part will hit its cycle limit, and another that projects when an engine's EGT margin will cross its Hot Section Inspection threshold.

## Architecture

```
ztei_eld_engine / ztei_eld_part_li / ztei_eld_usage_l / ztei_eld_boresco   (Z-tables)
        │
        ▼
ZTEI_I_ELD_FLEET_HEALTH  ─┐
ZTEI_I_ELD_PART_USAGE     │  CDS: basic → composite → dashboard layering
ZTEI_I_ELD_PART_RISK      │  (see "CDS syntax constraints" below for why
ZTEI_C_ELD_DASHBOARD     ─┘   it's layered this way, not flattened)
        │
        ▼
ZCL_TEI_ELD_FORECAST / ZCL_TEI_ELD_EGT_TREND   (ABAP calculation classes,
        │                                        unit-tested, no DB writes)
        ▼
ZTEI_ELD_PM_SRV  (classic SEGW OData V2, DPC_EXT redefinitions)
        │
        ▼
Fiori Elements Analytical List Page + Object Page  (webapp/, annotation.xml)
```

## Key features

- **Analytical List Page**: bar chart (flight hours by base) + donut chart (fleet risk by model), switchable via *View By*, backed by a `GridTable` with server-side filter, sort, and paging.
- **Object Page with four facets** per engine:
  - **Critical Parts** — every life-limited part (LLP), cycle limit vs. accumulated cycles, color-coded risk (red/yellow/green, aligned to SAP's `UI.Criticality` enum).
  - **Borescope Findings** — inspection history with a 1–5 severity scale.
  - **Life Forecast** — for each critical part, a projected number of days until its cycle limit is reached (or already exceeded).
  - **EGT Trend Forecast** — projected days until the engine's exhaust-gas-temperature margin crosses its Hot Section Inspection threshold.
- **A headline "Next Maintenance Estimate" column** on the main list — the *nearest* forecast across all of an engine's parts, so the predictive signal isn't buried three clicks deep.
- **Decoded, localized display everywhere**: raw status/risk codes (`A`/`M`/`D`, `G`/`Y`/`R`) are never shown to the user — always their Turkish text equivalent, via `Common.Text` + `TextArrangement=TextOnly`.
- **Full Turkish localization**: UI labels, base names, borescope findings — including the CSV → SAP upload encoding pipeline (see below).
- **ABAP Unit test coverage** for both prediction classes (10 tests), written specifically to lock in two real bugs found during manual testing (see "Engineering deep dive").

## Domain model — grounded, not invented

- **LLP (Life-Limited Part)** cycle tracking: rotating parts (turbine disks, blades) accumulate fatigue damage per flight cycle, not per flight hour, and are retired at a hard cycle limit.
- **EGT margin**: the gap between an engine's current exhaust gas temperature and its certified redline — it decays over an engine's life (fast-then-slow), and crossing a threshold triggers a Hot Section Inspection (HSI).
- **Borescope inspection**: periodic internal visual inspection of hot-section components, findings classified on a 1–5 severity scale.

Numerical ranges (cycle limits, EGT decay curves, HSI thresholds) are **industry-typical, illustrative values grounded in public references** (FAA AC 33.70-1, published TEI engine specs, general MRO literature) — **not real, published TEI figures**, which aren't public. This mirrors the same honesty principle used in project 2.

PD170 is modeled as a compression-ignition piston engine (unlike the rest of the fleet, which are turbines) — it genuinely has no LLP/EGT/borescope concept, and the dashboard reflects that honestly (`N/A` for EGT, empty "Critical Parts"/"Borescope" sections) rather than faking data for it.

## What we tried — and stepped back from

The original plan called for *true* server-side analytical aggregation: a CDS `@Analytics.dataCategory: #CUBE` + `@Analytics.query: true` query view, auto-published via `@OData.publish: true`, consumed by a Fiori Elements `AnalyticalTable`. Two genuine attempts were made:

1. **CDS Cube + Query view**, activated cleanly, but the auto-generated OData service's `$metadata` consistently came back with an empty `<EntityContainer>` (zero entity types) — even after clearing the Gateway cache and manually re-registering the service via `/IWFND/MAINT_SERVICE`.
2. **SEGW's "Redefine → ODP Extraction"** wizard, an alternative path to expose a BW-style InfoProvider as OData — got stuck in the "Select ODP" search dialog, which only offered hierarchical component-category browsing, not name search, on this trial landscape.

Both point to the same underlying limitation: this NPL trial system's native OData-V2-over-embedded-analytics path isn't fully exposed end-to-end. Rather than burn further time chasing a platform limitation, we made a deliberate call to fall back to a plain `GridTable` bound to a classic SQL-based CDS view, with client-side chart aggregation — a fully working, honest solution. The unused cube/query CDS views are still in the repo (`tools/ZTEI_I_ELD_CUBE.ddls.asddls`, `tools/ZTEI_C_ELD_QUERY.ddls.asddls`) as a record of the attempt.

That decision had a real technical consequence, described next.

## Engineering deep dive — real bugs, found and fixed

A few of the more interesting ones, in the order they were found:

**1. The ALP chart crash that only appeared after the first filter.** Once a `GridTable` (not `AnalyticalTable`) is bound to a non-analytical service, `sap.chart.Chart.getDrillStack()` returns `undefined` instead of an array — SAP's own `_setParamMap()` controller code then calls `.forEach()` on that `undefined` and throws, but only on **every rebind after the first** (the chart isn't fully initialized on the very first render, so the crash is invisible until you touch a filter or sort). Root-caused by reading the minified UI5 framework source directly in the browser (`fetch(sap.ui.require.toUrl(...))`), then fixed with a five-line guard in `Component.js` that wraps `sap.chart.Chart.prototype.getDrillStack` and substitutes an empty array when the framework returns `undefined` — a minimal patch for a genuine gap in SAP's own null-check, not a workaround for our own bug.

**2. `GetEntitySet` silently ignoring filter, sort, and paging.** The classic SEGW `DPC_EXT` pattern requires you to manually read `IT_FILTER_SELECT_OPTIONS`, `IT_ORDER`, and `IS_PAGING` — none of it is handled by the framework. The mock server (`@sap-ux/ui5-middleware-fe-mockserver`) *does* implement all of this automatically, so the gap was completely invisible until testing against the real backend: filters had no effect, the intended "worst risk first" sort order silently didn't apply, and — most subtly — applying any filter corrupted the entire UI5 table model (`No data loaded for select property: Bomid of entry: EngineSet(...)`, all cells blank, `[object Object]` in the chart), because the server never honored `$skip`/`$top`/`$inlinecount`, so the client's paging assumptions and the server's actual result set silently diverged.

**3. A predictive-maintenance entity that always came back empty — for three unrelated reasons.** Wiring the `Forecast`/`EgtTrend` OData entities up to the Object Page (they'd been built and unit-tested weeks earlier, but never actually connected to any UI) surfaced a layered bug, each one masking the next:
   - `IT_KEY_TAB` navigation-key extraction was actually correct from the start — confirmed by a throwaway diagnostic method that returned the key's name/value as fake OData rows, since there's no debugger-attach workflow readily available against this Gateway stack.
   - `CORRESPONDING #( lt_forecast )` was silently producing all-blank rows: the ABAP calculation class uses idiomatic `snake_case` field names (`engine_sn`, `node_id`), while the OData-generated structure uses `PascalCase` (`EngineSn`, `NodeId`) — `CORRESPONDING` matches by exact component name, so *nothing* mapped, and the Gateway silently dropped the resulting empty-keyed rows rather than erroring. Fixed with explicit field-by-field assignment.
   - Even after that, `EstimatedDate` (an ABAP `dats`) assigned directly into an `Edm.DateTime`-backed field produced `HTTP 500 — "Value 742330 is not a valid date..."` — needed an explicit `CONVERT DATE ... INTO TIME STAMP`.
   - And *that* uncovered a genuine logic bug: the forecast class emits a `9999` sentinel for "no measurable usage trend," but the days-left-based date arithmetic can also legitimately produce very large day counts for a young fleet far from any limit — the original `>= 9999` check conflated the two, showing "no data" for engines that actually had a valid (if distant) forecast. Fixed to check `= 9999` exactly, with a readable "10+ years" label for genuinely large-but-real projections.

**4. An inverted risk aggregation.** The dashboard's worst-part-risk column used `MAX()` over a scale where **1 = worst (red)** and **3 = best (green)** — meaning it was reporting the *best* risk in a group, not the worst, and understating risk on every multi-part engine. Caught by comparing the dashboard's color against the engine's actual known-red part count. Fixed to `MIN()`, with the reasoning documented inline in the CDS source so it doesn't get "corrected" back by mistake later.

## Testing

`ZCL_TEI_ELD_FORECAST` and `ZCL_TEI_ELD_EGT_TREND` each carry an ABAP Unit test class (`tools/*_TEST.abap`) run against the live seeded dataset rather than mocks, since the classes issue direct Open SQL against the Z-tables. Two of the ten tests exist specifically to regression-lock bug #3's `9999`-sentinel fix — they assert that the sentinel value only ever appears when the underlying usage/decline rate is non-positive, which is exactly the invariant that was silently violated before the fix.

## Data & honesty note

All fleet, part-life, usage-log, and borescope data is synthetically generated (`tools/generate-eld-data.js`, deterministic seeded RNG) — grounded in publicly researched ranges, not real TEI operational data. One engine (`TS1400-DUR1`) is modeled as a dedicated ground endurance/qualification test article, deliberately run to accelerated cycle accumulation — mirroring the real-world practice of validating LLP limits on a test article before certification, and the only realistic way to demonstrate red/yellow risk states given how young the rest of the (realistically-aged) fielded fleet is.

## Tech stack

| Layer | Technology |
|---|---|
| Data model | SAP ABAP Dictionary (Z-tables, Domains, Data Elements) |
| Analytics | ABAP CDS views (layered basic → composite → dashboard) |
| Business logic | ABAP OO classes + ABAP Unit |
| Service | Classic SAP Gateway (SEGW), OData V2, DPC_EXT/MPC_EXT |
| Frontend | SAP Fiori Elements — Analytical List Page + Object Page |
| Tooling | SAP Fiori tools (VS Code), `@sap-ux/ui5-middleware-fe-mockserver` |
| Data generation | Node.js (deterministic seeded generator, JSON + CSV output) |

## Project structure

```
webapp/                    Fiori Elements app (manifest.json, annotation.xml, Component.js)
tools/
  generate-eld-data.js      Seeded synthetic data generator (CSV for GUI_UPLOAD + JSON for mock)
  generate-mock-data.js     Reshapes generator output into OData-shaped mock JSON
  *.ddls.asddls             CDS view sources (as activated in the SAP system)
  ZCL_TEI_ELD_*.abap         Forecast/EGT-trend classes + their ABAP Unit test classes
  DPC_EXT_*.abap             DPC_EXT method redefinitions (SEGW service implementation)
  ZTEI_ELD_LOAD_DATA.abap    GUI_UPLOAD-based CSV loader
docs/images/                Screenshots referenced above
```

> Backend ABAP objects (tables, CDS, classes, the SEGW service) live in the connected SAP system, not as deployable source in this repo — the `tools/` files are the *reference source*, kept here for review and reproducibility.

## Getting started

```bash
npm install
npm run start-mock   # runs against generated mock data, no SAP backend needed
npm start            # runs against the real SAP backend (requires VPN/network access)
```

## Related projects

- [tei-part-traceability-portal](https://github.com/BarisDursun/tei-part-traceability-portal) — project 1: List Report + Object Page, OOP tolerance validation
- [tei-bom-embargo-risk-simulator](https://github.com/BarisDursun/tei-bom-embargo-risk-simulator) — project 2: recursive BOM rollup, embargo risk, what-if simulation

## Author

Barış Dursun — [barisdursun.com.tr](https://barisdursun.com.tr)
