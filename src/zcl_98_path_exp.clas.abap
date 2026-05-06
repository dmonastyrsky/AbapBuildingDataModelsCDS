CLASS zcl_98_path_exp DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.


CLASS zcl_98_path_exp IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    SELECT FROM Z98_C_EmployeeQuery
      FIELDS employeeid,
             firstname,
             lastname,
             departmentid,
             departmentdescription,
             assistantname,
             \_Department\_Head-LastName AS headname
      INTO TABLE @DATA(result).

    out->write( result ).
  ENDMETHOD.
ENDCLASS.
