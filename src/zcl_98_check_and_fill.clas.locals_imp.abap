*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations


CLASS lcl_table DEFINITION.

  PUBLIC SECTION.
    DATA name  TYPE tabname READ-ONLY.

    METHODS constructor
      IMPORTING
        i_name   TYPE tabname
        i_source TYPE tabname
      RAISING
        cx_abap_not_a_table.
    METHODS
      compare
        RETURNING
          VALUE(r_output) TYPE string_table.
    METHODS
      copy
        RAISING
          cx_root .
    METHODS
      copy_with_modevi RETURNING VALUE(r_count) TYPE i
                       RAISING
                                 cx_root .

  PROTECTED SECTION.

  PRIVATE SECTION.


    DATA source TYPE tabname.

    CLASS-METHODS is_table
      IMPORTING
        i_name TYPE tabname
      RAISING
        cx_abap_not_a_table.


ENDCLASS.

CLASS lcl_table IMPLEMENTATION.

  METHOD constructor.

    is_table( i_name ).
    name = i_name.

    is_table( i_source ).
    source = i_source.

  ENDMETHOD.

  METHOD compare.

    DATA(components)   = CAST cl_abap_structdescr(
                              cl_abap_typedescr=>describe_by_name( name )
                         )->components.

    DATA(components_t) = CAST cl_abap_structdescr(
                             cl_abap_typedescr=>describe_by_name( source )
                          )->components.

    DATA(count) = lines( components ).
    DATA(count_t) = lines(  components_t ).

    IF count <> count_t.
      APPEND |Table { name } has { count } fields ( expected: { count_t } ) |
       TO r_output.
    ELSE.

      LOOP AT components_t ASSIGNING FIELD-SYMBOL(<compt>).

        ASSIGN components[ sy-tabix ] TO FIELD-SYMBOL(<comp>).
        IF <comp>-type_kind <> <compt>-type_kind.
          APPEND |Column { sy-tabix WIDTH = 2 ALIGN = RIGHT }: Wrong basic type ( { <comp>-type_kind } instead of { <compt>-type_kind } )|
              TO r_output.

        ELSEIF <comp>-length <> <compt>-length.
          APPEND |Column { sy-tabix WIDTH = 2 ALIGN = RIGHT }: Wrong length ( { <comp>-length } instead of { <compt>-length } )|
              TO r_output.

        ELSEIF <comp>-decimals <> <compt>-decimals.
          APPEND |Column { sy-tabix WIDTH = 2 ALIGN = RIGHT }: Wrong number of decimals!|
             TO r_output.

        ENDIF.

      ENDLOOP.

    ENDIF.
  ENDMETHOD.

  METHOD copy.

    DATA r_source TYPE REF TO data.
    DATA r_target TYPE REF TO data.

    CREATE DATA r_source TYPE TABLE OF (source).
    CREATE DATA r_target TYPE TABLE OF (name).

    ASSIGN  r_source->* TO FIELD-SYMBOL(<source>).
    ASSIGN  r_target->* TO FIELD-SYMBOL(<target>).

    SELECT
      FROM (source)
    FIELDS *
      INTO TABLE @<source>.

    LOOP AT <source> ASSIGNING FIELD-SYMBOL(<source_row>).

      INSERT INITIAL LINE INTO TABLE <target> ASSIGNING FIELD-SYMBOL(<target_row>).

      DO.
        ASSIGN COMPONENT sy-index OF STRUCTURE <source_row> TO FIELD-SYMBOL(<source_field>).
        IF sy-subrc <> 0.
          EXIT.
        ENDIF.

        ASSIGN COMPONENT sy-index OF STRUCTURE <target_row> TO FIELD-SYMBOL(<target_field>).

        <target_field> = <source_field>.

      ENDDO.
    ENDLOOP.

    MODIFY (name) FROM TABLE @<target>.

  ENDMETHOD.

  METHOD copy_with_modevi.
    DATA r_source     TYPE REF TO data.
    DATA r_target     TYPE REF TO data.
    DATA lv_timestamp TYPE timestampl.
    DATA lv_date      TYPE d.
    DATA lv_today     TYPE d. " Variable to hold today's date

    " Get system info once before the loop
    GET TIME STAMP FIELD lv_timestamp.
    lv_today = cl_abap_context_info=>get_system_date( ).

    CREATE DATA r_source TYPE TABLE OF (source).
    CREATE DATA r_target TYPE TABLE OF (name).

    ASSIGN r_source->* TO FIELD-SYMBOL(<source>).
    ASSIGN r_target->* TO FIELD-SYMBOL(<target>).

    " Read only first 200 rows from the source table
    SELECT FROM (source)
      FIELDS *
      ORDER BY PRIMARY KEY
      INTO TABLE @<source>
      UP TO 500 ROWS.

    LOOP AT <source> ASSIGNING FIELD-SYMBOL(<source_row>).
      INSERT INITIAL LINE INTO TABLE <target> ASSIGNING FIELD-SYMBOL(<target_row>).

      " 1. Basic mapping
      MOVE-CORRESPONDING <source_row> TO <target_row>.

      " 2. Key and Salary mapping
      ASSIGN COMPONENT 'EMPLOYEE' OF STRUCTURE <source_row> TO FIELD-SYMBOL(<s_id>).
      ASSIGN COMPONENT 'EMPLOYEE_ID' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<t_id>).
      IF <s_id> IS ASSIGNED AND <t_id> IS ASSIGNED. <t_id> = <s_id>. ENDIF.

      ASSIGN COMPONENT 'SALARY' OF STRUCTURE <source_row> TO FIELD-SYMBOL(<s_sal>).
      ASSIGN COMPONENT 'ANNUAL_SALARY' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<t_sal>).
      IF <s_sal> IS ASSIGNED AND <t_sal> IS ASSIGNED. <t_sal> = <s_sal>. ENDIF.

      ASSIGN COMPONENT 'SALARY_CURRENCY' OF STRUCTURE <source_row> TO FIELD-SYMBOL(<s_cur>).
      ASSIGN COMPONENT 'CURRENCY_CODE' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<t_cur>).
      IF <s_cur> IS ASSIGNED AND <t_cur> IS ASSIGNED. <t_cur> = <s_cur>. ENDIF.

      " 3. Synthetic Date Generation (since source lacks them)

      " Birth Date: Calculate a date based on Employee ID to make it look realistic
      ASSIGN COMPONENT 'BIRTH_DATE' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<t_birth>).
       IF <t_birth> IS ASSIGNED AND <s_id> IS ASSIGNED.
        " Year offset (0-20), month (1-12) and day (1-28) calculated on the fly
                <t_birth> = |{ 1980 + ( <s_id> * 100 ) MOD 25 }{
                 ( <s_id> * 7 ) MOD 12 + 1 WIDTH = 2 ALIGN = RIGHT PAD = '0' }{
                 ( <s_id> * 3 ) MOD 28 + 1 WIDTH = 2 ALIGN = RIGHT PAD = '0' }|.
      ENDIF.

      " Entry Date: Different dates within the last year (365 days)
      ASSIGN COMPONENT 'ENTRY_DATE' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<t_entry>).
      IF <t_entry> IS ASSIGNED AND <s_id> IS ASSIGNED.
        " Logic: Current date minus (ID mod 365) days
        lv_date = lv_today.
        lv_date = lv_date - ( <s_id> MOD 365 ).
        <t_entry> = lv_date.
      ENDIF.

      " 4. Admin Data (z98_s_admin)
      ASSIGN COMPONENT 'CREATED_BY' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<c_by>).
      IF <c_by> IS ASSIGNED. <c_by> = sy-uname. ENDIF.

      ASSIGN COMPONENT 'CREATED_AT' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<c_at>).
      IF <c_at> IS ASSIGNED. <c_at> = lv_timestamp. ENDIF.

      ASSIGN COMPONENT 'LOCAL_LAST_CHANGED_AT' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<l_at>).
      IF <l_at> IS ASSIGNED. <l_at> = lv_timestamp. ENDIF.
    ENDLOOP.

    MODIFY (name) FROM TABLE @<target>.

    r_count = lines( <target> ).

  ENDMETHOD.


  METHOD is_table.

* XCO alternative
    DATA(lo_name_filter) = xco_cp_abap_repository=>object_name->get_filter( xco_cp_abap_sql=>constraint->equal( i_name ) ).

    DATA(lt_objects) = xco_cp_abap_repository=>objects->tabl->database_tables->where( VALUE #(
      ( lo_name_filter )
    ) )->in( xco_cp_abap=>repository )->get( ).

    IF lt_objects IS INITIAL.
      RAISE EXCEPTION NEW cx_abap_not_a_table( value = CONV #( i_name ) ).
    ENDIF.

* RTTI Alternative

*    cl_abap_typedescr=>describe_by_name(
*      EXPORTING
*        p_name         = i_name
*      RECEIVING
*        p_descr_ref    = DATA(type)
*      EXCEPTIONS
*        type_not_found = 1
*    ).
*    IF sy-subrc <> 0.
*      RAISE EXCEPTION NEW cx_abap_not_a_table( value = CONV #( i_name ) ).
*    ENDIF.
*
*    IF type->kind <> type->kind_struct.
*      RAISE EXCEPTION NEW cx_abap_not_a_table( value = CONV #( i_name ) ).
*    ENDIF.
*
*    IF type->is_ddic_type( ) <> cl_abap_typedescr=>true.
*      RAISE EXCEPTION NEW cx_abap_not_a_table( value = CONV #( i_name ) ).
*    ENDIF.

  ENDMETHOD.

ENDCLASS.

CLASS lcl_generator DEFINITION.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ENUM t_version,
        employee_table_only,
        with_relationships,
        with_extensions,
      END OF ENUM t_version.


    METHODS constructor
      IMPORTING
        i_version       TYPE t_version
        i_employ_table  TYPE tabname
        i_depment_table TYPE tabname
        i_out           TYPE REF TO if_oo_adt_classrun_out
      RAISING
        cx_abap_not_a_table.

    METHODS  run.
    METHODS run_custom_fill. " Our new independent method

  PROTECTED SECTION.
  PRIVATE SECTION.

    DATA tables TYPE TABLE OF REF TO lcl_table.

    DATA out TYPE REF TO if_oo_adt_classrun_out.
ENDCLASS.

CLASS lcl_generator IMPLEMENTATION.

  METHOD constructor.

    APPEND NEW lcl_table( i_name = i_employ_table
                          i_source =  SWITCH #( i_version
                                           WHEN employee_table_only    THEN '/DMO/EMPLOYEE_HR' "'/LRN/EMPLOY'
                                           "WHEN with_relationships     THEN '/LRN/EMPLOY_REL'
                                           "WHEN with_extensions        THEN '/LRN/EMPLOY_EXT'
                                           )
                         )
        TO tables.

    IF i_version = with_relationships.
      APPEND NEW lcl_table( i_name = i_depment_table
                            i_source = '/LRN/DEPMENT_REL'
                           )
          TO tables.
    ENDIF.

    me->out = i_out.

  ENDMETHOD.

  METHOD run.

    LOOP AT tables INTO DATA(table).

      DATA(log) = table->compare( ).

      IF log IS NOT INITIAL.

        out->write( data = log
                    name = |Errors in Table { table->name } | ).

      ELSE.

        out->write( |Table { table->name } is correctly defined.| ).

        TRY.
            table->copy( ).
*             table->copy_with_modevi( ).
            out->write( |Filled table { table->name }| ).
          CATCH cx_root INTO DATA(excp).
            out->write( |Error during data copy: { excp->get_text( ) } | ).
        ENDTRY.
      ENDIF.
      out->write( `--------------------------------------------------` ).

    ENDLOOP.

  ENDMETHOD.

  METHOD run_custom_fill.
    LOOP AT tables INTO DATA(table).
      out->write( |[Modevi] Starting custom fill for: { table->name }| ).

      TRY.
          " Calling your specific mapping logic directly
          DATA(lv_lines) = table->copy_with_modevi( ).
          out->write( |Filled table { table->name }| ).
          out->write( |[Modevi] Total rows transferred: { lv_lines }| ).

        CATCH cx_root INTO DATA(lo_excp).
          out->write( |[Modevi] Error during execution: { lo_excp->get_text( ) }| ).
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
