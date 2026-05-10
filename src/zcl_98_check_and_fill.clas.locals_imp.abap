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
    " Helper to provide consistent department data
    METHODS get_department_data RETURNING VALUE(r_data) TYPE string_table.

    " Independent method to fill department table
    METHODS fill_depment_manual RETURNING VALUE(r_count) TYPE i RAISING cx_root.


    METHODS get_source RETURNING VALUE(r_source) TYPE tabname.

  PROTECTED SECTION.

  PRIVATE SECTION.


    DATA source TYPE tabname.
    METHODS assign_managers_to_depts IMPORTING it_employees TYPE ANY TABLE.

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
    DATA lv_today     TYPE d.

    " Get centralized department data
    DATA(lt_dept_raw) = get_department_data( ).
    DATA(lv_max_dept) = lines( lt_dept_raw ).

    DATA lv_dept_assigned TYPE abap_bool VALUE abap_false.

    " Initialize randomizer
    DATA(lo_rand) = cl_abap_random_int=>create( seed = cl_abap_random=>seed( )
                                                min  = 1
                                                max  = lv_max_dept ).

    GET TIME STAMP FIELD lv_timestamp.
    lv_today = cl_abap_context_info=>get_system_date( ).

    " Create dynamic tables based on source and target
    CREATE DATA r_source TYPE TABLE OF (source).
    CREATE DATA r_target TYPE TABLE OF (name).

    ASSIGN r_source->* TO FIELD-SYMBOL(<source>).
    ASSIGN r_target->* TO FIELD-SYMBOL(<target>).

    " Fetch data from source (e.g., /DMO/EMPLOYEE_HR)
    SELECT FROM (source) FIELDS * ORDER BY PRIMARY KEY INTO TABLE @<source> UP TO 100 ROWS.

    LOOP AT <source> ASSIGNING FIELD-SYMBOL(<source_row>).
      INSERT INITIAL LINE INTO TABLE <target> ASSIGNING FIELD-SYMBOL(<target_row>).

      " 1. Map identical fields (first_name, last_name, etc.)
      MOVE-CORRESPONDING <source_row> TO <target_row>.

      " 2. Map fields with different names in Z98_EMPLOY
      " Map Employee -> Employee_ID
      ASSIGN COMPONENT 'EMPLOYEE' OF STRUCTURE <source_row> TO FIELD-SYMBOL(<s_id>).
      ASSIGN COMPONENT 'EMPLOYEE_ID' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<t_id>).
      IF <s_id> IS ASSIGNED AND <t_id> IS ASSIGNED. <t_id> = <s_id>. ENDIF.

      " Map Salary -> Annual_Salary
      ASSIGN COMPONENT 'SALARY' OF STRUCTURE <source_row> TO FIELD-SYMBOL(<s_sal>).
      ASSIGN COMPONENT 'ANNUAL_SALARY' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<t_sal>).
      IF <s_sal> IS ASSIGNED AND <t_sal> IS ASSIGNED. <t_sal> = <s_sal>. ENDIF.

      " Map Salary_Currency -> Currency_Code
      ASSIGN COMPONENT 'SALARY_CURRENCY' OF STRUCTURE <source_row> TO FIELD-SYMBOL(<s_cur>).
      ASSIGN COMPONENT 'CURRENCY_CODE' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<t_cur>).
      IF <s_cur> IS ASSIGNED AND <t_cur> IS ASSIGNED. <t_cur> = <s_cur>. ENDIF.

      " 3. Generate Dates
      ASSIGN COMPONENT 'BIRTH_DATE' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<t_birth>).
      IF <t_birth> IS ASSIGNED AND <s_id> IS ASSIGNED.
        <t_birth> = |{ 1980 + ( <s_id> MOD 25 ) }{ ( <s_id> MOD 12 ) + 1 WIDTH = 2 ALIGN = RIGHT PAD = '0' }01|.
      ENDIF.

      ASSIGN COMPONENT 'ENTRY_DATE' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<t_entry>).
      IF <t_entry> IS ASSIGNED. <t_entry> = lv_today - ( <s_id> MOD 365 ). ENDIF.

      " 4. FIX: Dynamic Department Mapping (Must be UPPERCASE for component name)
      ASSIGN COMPONENT 'DEPARTMENT_ID' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<t_dept>).
      IF <t_dept> IS ASSIGNED.
        DATA(lv_dept_line) = lt_dept_raw[ lo_rand->get_next( ) ].
        SPLIT lv_dept_line AT '|' INTO DATA(lv_did) DATA(lv_dtext).

        " Clean and assign
        CONDENSE lv_did.
        <t_dept> = CONV z98_department_id( lv_did ).

        " Set flag to true as a department was assigned
        lv_dept_assigned = abap_true.
      ENDIF.

      " 4b. Custom Fields Mapping (Title & Country)
      ASSIGN COMPONENT 'ZZCOUNTRY_ZEM' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<t_country>).
      IF <t_country> IS ASSIGNED.
        <t_country> = 'DE'. " Deutschland as default country for all employees
      ENDIF.

      ASSIGN COMPONENT 'ZZTITLE_ZEM' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<t_title>).
      IF <t_title> IS ASSIGNED.
        <t_title> = 'Mr.'.
      ENDIF.

      " 5. Admin Data (z98_s_admin)
      ASSIGN COMPONENT 'CREATED_BY' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<c_by>).
      IF <c_by> IS ASSIGNED. <c_by> = sy-uname. ENDIF.

      ASSIGN COMPONENT 'CREATED_AT' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<c_at>).
      IF <c_at> IS ASSIGNED. <c_at> = lv_timestamp. ENDIF.

      ASSIGN COMPONENT 'LOCAL_LAST_CHANGED_BY' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<l_l_by>).
      IF <l_l_by> IS ASSIGNED. <l_l_by> = sy-uname. ENDIF.

      ASSIGN COMPONENT 'LOCAL_LAST_CHANGED_AT' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<l_l_at>).
      IF <l_l_at> IS ASSIGNED. <l_l_at> = lv_timestamp. ENDIF.

      ASSIGN COMPONENT 'LAST_CHANGED_AT' OF STRUCTURE <target_row> TO FIELD-SYMBOL(<l_at>).
      IF <l_at> IS ASSIGNED. <l_at> = lv_timestamp. ENDIF.

*      INSERT <target_row> INTO TABLE <target>.
    ENDLOOP.

    DELETE FROM (name).
    INSERT (name) FROM TABLE @<target>.
    r_count = lines( <target> ).

    " 2. Update managers only if the flag is true
    IF lv_dept_assigned = abap_true.
      me->assign_managers_to_depts( it_employees = <target> ).
    ENDIF.

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

  METHOD fill_depment_manual.
    " Fill the department table using centralized data and administrative fields
    DATA lt_departments TYPE TABLE OF z98_depment.
    DATA(lt_raw_data)   = get_department_data( ).

    GET TIME STAMP FIELD DATA(lv_timestamp).

    DATA(lo_random) = cl_abap_random_int=>create( seed = cl_abap_random=>seed( )
                                                  min  = 0
                                                  max  = 100 ).

    " 1. Clear existing entries to prevent duplicate key errors and ensure data consistency
    DELETE FROM (name).

    LOOP AT lt_raw_data INTO DATA(lv_line).
      " Use modern APPEND VALUE for cleaner syntax
      SPLIT lv_line AT '|' INTO DATA(lv_id) DATA(lv_description).
      CONDENSE: lv_id, lv_description.

      APPEND VALUE #(
        client                = sy-mandt
        id                    = lv_id
        description           = lv_description
*        head_id               = lo_random->get_next( )
*        assistant_id          = lo_random->get_next( )
        created_by            = sy-uname
        created_at            = lv_timestamp
        local_last_changed_by = sy-uname
        local_last_changed_at = lv_timestamp
        last_changed_at       = lv_timestamp
      ) TO lt_departments.

    ENDLOOP.

    " 2. Insert fresh master data into the database
    " Using (name) to target the table dynamically
    IF lt_departments IS NOT INITIAL.
      INSERT (name) FROM TABLE @lt_departments.
    ENDIF.

    r_count = lines( lt_departments ).
  ENDMETHOD.

 METHOD assign_managers_to_depts.
  " 1. Fetch data
  SELECT * FROM z98_employ INTO TABLE @DATA(lt_employees).
  SELECT * FROM z98_depment INTO TABLE @DATA(lt_departments).

  " 2. Process each department
  LOOP AT lt_departments ASSIGNING FIELD-SYMBOL(<ls_dept>).

    " Create a temporary table of the SAME TYPE as lt_employees
    DATA lt_dept_staff LIKE lt_employees.
    CLEAR lt_dept_staff.

    " Fill the temp table with employees of the current department
    lt_dept_staff = VALUE #( FOR emp IN lt_employees
                             WHERE ( department_id = <ls_dept>-id ) ( emp ) ).

    DATA(lv_count) = lines( lt_dept_staff ).
    IF lv_count = 0.
      CONTINUE.
    ENDIF.

    " 3. Random assignment logic
    DATA(lo_rand) = cl_abap_random_int=>create( seed = cl_abap_random=>seed( )
                                                min  = 1
                                                max  = lv_count ).

    " Get Random Head
    DATA(lv_h_idx) = lo_rand->get_next( ).
    <ls_dept>-head_id = lt_dept_staff[ lv_h_idx ]-employee_id.

    " Get Random Assistant (if more than 1 person in dept)
    IF lv_count > 1.
      DATA(lv_a_idx) = lo_rand->get_next( ).
      WHILE lv_a_idx = lv_h_idx.
        lv_a_idx = lo_rand->get_next( ).
      ENDWHILE.
      <ls_dept>-assistant_id = lt_dept_staff[ lv_a_idx ]-employee_id.
    ENDIF.

  ENDLOOP.

  " 4. Update the database
  MODIFY z98_depment FROM TABLE @lt_departments.
ENDMETHOD.


  METHOD get_department_data.
    " Centralized source for department IDs and Descriptions
    r_data = VALUE #( ( `IT|Information Technology` )
                      ( `HR|Human Resources` )
                      ( `SALES|Sales and Marketing` )
                      ( `FIN|Finance and Accounting` )
                      ( `PROD|Production and Logistics` ) ).
  ENDMETHOD.

  METHOD get_source.
    r_source = me->source.
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
    DATA depment_table TYPE tabname.
ENDCLASS.

CLASS lcl_generator IMPLEMENTATION.

  METHOD constructor.

    IF i_version = with_relationships.
      APPEND NEW lcl_table( i_name = i_depment_table
                            i_source = 'Z98_DEPMENT'
                           )
          TO tables.
    ENDIF.

    APPEND NEW lcl_table( i_name = i_employ_table
                          i_source =  SWITCH #( i_version
                                           WHEN employee_table_only    THEN '/DMO/EMPLOYEE_HR' "'/LRN/EMPLOY'
                                           WHEN with_relationships     THEN '/DMO/EMPLOYEE_HR' "'/LRN/EMPLOY_REL'
                                           "WHEN with_extensions       THEN '/DMO/EMPLOYEE_HR' "'/LRN/EMPLOY_EXT'
                                           )
                         )
        TO tables.



    me->out = i_out.
    me->depment_table = i_depment_table.

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

      " Use the getter method to access the private attribute 'source'
      IF table->get_source( ) = 'Z98_DEPMENT'.
        TRY.
            DATA(lv_dep_count) = table->fill_depment_manual( ).
            out->write( |[Master Data] Filled { table->name } using manual logic ({ lv_dep_count } rows)| ).
          CATCH cx_root INTO DATA(ex_dep).
            out->write( |[Error] Failed to fill master data { table->name }: { ex_dep->get_text( ) }| ).
        ENDTRY.

        out->write( `--------------------------------------------------` ).
        CONTINUE.
      ENDIF.

      " Standard processing for Employee and other tables
      out->write( |Table { table->name } is correctly defined.| ).

      TRY.
          DATA(lv_emp_count) = table->copy_with_modevi( ).
          out->write( |Filled table { table->name } ({ lv_emp_count } rows)| ).
        CATCH cx_root INTO DATA(ex_emp).
          out->write( |[Error] Data copy failed for { table->name }: { ex_emp->get_text( ) }| ).
      ENDTRY.

      out->write( `--------------------------------------------------` ).
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
