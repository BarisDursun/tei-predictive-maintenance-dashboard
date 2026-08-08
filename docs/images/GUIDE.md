# Ekran Görüntüsü Rehberi

Bu klasöre aşağıdaki dosya adlarıyla PNG/JPG ekran görüntüleri ekle. README.md ve README.tr.md zaten bu isimlere referans veriyor — tam bu adlarla kaydedersen otomatik görünürler.

| Dosya adı | Ne göstermeli |
|---|---|
| `01-alp-overview.png` | Ana ekran (ALP): grafik + tablo bir arada, motorlar risk sırasına göre (en kırmızı en üstte), Türkçe kolon başlıkları görünür olsun |
| `02-object-page-critical-parts.png` | Bir motora tıklayınca açılan Object Page, "Kritik Parçalar" bölümü — Kırmızı/Sarı/Yeşil renkli risk göstergesi görünür olsun (örn. TS1400-DUR1) |
| `03-object-page-borescope.png` | Aynı sayfada "Muayene Bulguları" bölümü |
| `04-object-page-forecast.png` | "Ömür Tahmini (Parça Bazında)" bölümü — projenin "kestirimci" iddiasını gösteren en önemli görsel |
| `05-object-page-egt-trend.png` | "EGT Trend Tahmini" bölümü |
| `06-filter-bar.png` | Filtre barı açık, bir seçim yapılmış (örn. Motor Modeli = BOM0002), Go'ya basılmadan önce ya da sonrası |
| `07-se11-tables.png` | SAP GUI'de SE16/SE11 — dört Z-tablosundan birinin (örn. ZTEI_ELD_ENGINE) gerçek Türkçe verilerle dolu hâli |
| `08-abap-unit-tests.png` | Eclipse ADT'de ABAP Unit test sonucu — yeşil onay işaretleriyle dolu ekran (10/10 testin geçtiği görüntü) |

**Opsiyonel (varsa ekle, yoksa sorun değil):**

| Dosya adı | Ne göstermeli |
|---|---|
| `09-native-analytics-attempt.png` | Terk edilen `ZTEI_I_ELD_CUBE`/`ZTEI_C_ELD_QUERY` CDS view'larının Eclipse'teki hâli — "denedik, öğrendik" hikâyesi için |

Ekran görüntülerini eklerken dosya adlarını **birebir** bu tabloya uydur (büyük/küçük harf dahil) — README'ler bu adlarla `docs/images/...` yolunu referans veriyor.
