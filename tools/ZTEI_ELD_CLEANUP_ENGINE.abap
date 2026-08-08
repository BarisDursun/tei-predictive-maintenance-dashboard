REPORT ztei_eld_cleanup_engine.

" BASE_NAME CHAR40->CHAR50 genisletildikten sonra, eski (kesilmis metinli)
" 21 motor kaydini temizliyoruz. PART_LIFE/USAGE_LOG/BORESCOPE'a dokunmuyoruz -
" onlar ENGINE_SN uzerinden referans veriyor, o degerler degismedi.
DELETE FROM ztei_eld_engine.
COMMIT WORK.

WRITE: / 'ZTEI_ELD_ENGINE tablosu temizlendi, tekrar yuklemeye hazir.'.
