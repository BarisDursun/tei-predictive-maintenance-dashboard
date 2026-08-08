"====================================================================
" MPC_EXT - DEFINE metodu redefinition.
" Amac: Engine entity'sinin alanlarini Dimension/Measure olarak isaretleyip
" Analytical Table'in sunucu-tarafi toplama (aggregation) yapabilmesini saglamak.
"
" NOT: asagidaki metod isimleri (SET_ANNOTATION vb.) genel/dokumante edilen
" kaliba gore yazildi ama tam surum farkli olabilir. "lo_entity->" veya
" "lo_property->" yazip Ctrl+Space (otomatik tamamlama) ile mevcut metod
" listesine bak - "annotation", "aggregation", "semantics" gecen isimleri ara.
"====================================================================
METHOD define.

  DATA: lo_entity_type TYPE REF TO /iwbep/if_mgw_odata_entity_typ,
        lo_property    TYPE REF TO /iwbep/if_mgw_odata_property.

  super->define( ).

  lo_entity_type = model->get_entity_type( iv_entity_name = 'Engine' ).

  " entity'nin kendisini "aggregate" (analitik) olarak isaretle
  lo_entity_type->set_annotation(
    iv_key       = 'semantics'
    iv_namespace = 'sap'
    iv_value     = 'aggregate' ).

  " ---- BOYUTLAR (dimension) ----
  LOOP AT VALUE string_table( ( `Bomid` ) ( `Enginefamilytype` ) ( `Basecode` ) ( `Status` ) )
       INTO DATA(lv_dim_name).
    lo_property = lo_entity_type->get_property( iv_property_name = lv_dim_name ).
    lo_property->set_annotation(
      iv_key       = 'aggregation-role'
      iv_namespace = 'sap'
      iv_value     = 'dimension' ).
  ENDLOOP.

  " ---- OLCULER (measure) ----
  LOOP AT VALUE string_table(
      ( `Totalflighthours` ) ( `Totalcycles` ) ( `Currentegtmargin` )
      ( `Worstpartriskrank` ) ( `Redpartcount` ) ( `Yellowpartcount` ) )
       INTO DATA(lv_measure_name).
    lo_property = lo_entity_type->get_property( iv_property_name = lv_measure_name ).
    lo_property->set_annotation(
      iv_key       = 'aggregation-role'
      iv_namespace = 'sap'
      iv_value     = 'measure' ).
  ENDLOOP.

ENDMETHOD.
