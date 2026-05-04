CLASS zcl_98_01_intro DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_98_01_intro IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    " Step 1: Using a primitive type
    DATA var_string TYPE string.

    DATA var_cds TYPE /DMO/I_Flight.

    DATA ls_table TYPE /dmo/flight.

    ls_table-carrier_id    = 'AA'.
    ls_table-connection_id = '0017'.
    ls_table-flight_date   = '20250101'.

    " Example of DML operations
    " Caution: You might not have authorization to DELETE from /DMO/ tables in some systems
    DELETE FROM /dmo/flight WHERE connection_id = '2678'.

    " Fetching data from the database
    SELECT FROM /dmo/flight
      FIELDS *
      INTO TABLE @DATA(result)
      UP TO 20 ROWS.

    out->write( result ).

  ENDMETHOD.
ENDCLASS.
