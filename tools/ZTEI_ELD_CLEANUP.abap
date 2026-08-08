REPORT ztei_eld_cleanup.

" CHAR12'ye sigmayan eski hatali seri no (TS1400-END-001 -> kesilerek TS1400-END-0 olmustu)
" tum tablolardan temizleniyor, dogru isimle (TS1400-DUR1) tekrar yuklenecek.
DELETE FROM ztei_eld_engine WHERE engine_sn = 'TS1400-END-0'.
DELETE FROM ztei_eld_part_li WHERE engine_sn = 'TS1400-END-0'.
DELETE FROM ztei_eld_usage_l WHERE engine_sn = 'TS1400-END-0'.
DELETE FROM ztei_eld_boresco WHERE engine_sn = 'TS1400-END-0'.
COMMIT WORK.

WRITE: / 'TS1400-END-0 kayitlari tum tablolardan silindi.'.
