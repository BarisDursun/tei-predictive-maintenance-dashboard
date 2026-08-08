sap.ui.define(
    ["sap/suite/ui/generic/template/lib/AppComponent", "sap/chart/Chart", "sap/base/Log"],
    function (Component, Chart, Log) {
        "use strict";

        // =====================================================================
        // SAP Fiori Elements ALP + analitik OLMAYAN OData servisi uyumsuzlugu
        // icin minimal koruma (guard).
        //
        // SORUN: Analytical List Page sablonunun grafik denetleyicisi, altta
        // toplama (aggregation) yapan bir analitik OData servisi VARSAYIYOR.
        // Bizim servisimiz klasik SEGW OData V2 - analitik degil (bkz. README:
        // native analytics denemeleri bu NPL sisteminde sonuc vermedi, bilincli
        // olarak GridTable'a gecildi).
        //
        // ZINCIR (UI5 kaynagi okunarak tespit edildi):
        //   1. SmartChartController._onSmartChartInit:
        //          this._chartInfo.drillStack = this.oChart.getDrillStack();
        //      Servis drill-down desteklemedigi icin getDrillStack() UNDEFINED
        //      doner (konsolda "Data source does not support drillDown/drillUp"
        //      uyarisi cikar) - yani drillStack undefined olarak saklanir.
        //   2. ControllerImplementation.onBeforeRebindTable her yeniden
        //      baglamada detailController._applyCriticalityInfo(...) cagirir.
        //   3. O da "grafik var mi" kosuluyla _setParamMap(chart) cagirir.
        //   4. _setParamMap icinde: drillFiltersFromChart.forEach(...)
        //      -> undefined uzerinde forEach -> TypeError.
        //
        // SONUC: rebind yarida kesilir, tablo hicbir alan isteyemez; ekranda
        // tum hucreler BOSALIR ve grafik [object Object] cizer. Kullanici
        // acisindan "filtre uygulayinca uygulama bozuluyor" seklinde gorunur.
        //
        // NEDEN BURADA VE BOYLE COZULDU:
        // - Deterministik bir hata: grafik bir kez hazir olduktan sonra HER
        //   filtre/siralama isleminde tekrarlanir (ilk acilista calismasinin
        //   sebebi oChart'in henuz asenkron olarak set edilmemis olmasi).
        // - UI.LineItem'daki Criticality annotasyonunu kaldirmak COZMEZ; cokme
        //   criticality kontrolunden ONCE, sadece grafigin varligina bagli
        //   blokta olusur.
        // - Prototip seviyesinde duzeltiyoruz cunku _chartInfo.drillStack
        //   grafik init'inde BIR KEZ okunuyor; controller extension ile
        //   sonradan mudahale etmek zamanlama yarisina girerdi. Burada, hicbir
        //   grafik olusturulmadan once, kaynaktan duzeltmis oluyoruz.
        // - Davranis degisikligi minimum: SADECE undefined -> bos dizi. Servis
        //   drill-down destekliyorsa orijinal deger aynen gecer.
        // =====================================================================
        var fnOriginalGetDrillStack = Chart.prototype.getDrillStack;
        Chart.prototype.getDrillStack = function () {
            var vResult = fnOriginalGetDrillStack.apply(this, arguments);
            if (vResult === undefined || vResult === null) {
                Log.info(
                    "getDrillStack() undefined dondu (analitik olmayan servis) - " +
                    "bos dizi ile degistirildi, ALP rebind cokmesi engelleniyor.",
                    null,
                    "com.tei.zteieldpm.Component"
                );
                return [];
            }
            return vResult;
        };

        return Component.extend("com.tei.zteieldpm.Component", {
            metadata: {
                manifest: "json"
            }
        });
    }
);
