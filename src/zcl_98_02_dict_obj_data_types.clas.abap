CLASS zcl_98_02_dict_obj_data_types DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_98_02_dict_obj_data_types IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.


* Declarations
    DATA travel1 TYPE /dmo/travel_id.
    DATA travel2 TYPE /dmo/s_travel_key.
    DATA travel3 TYPE /dmo/travel.
    DATA travel4 TYPE /dmo/t_travel.

* Assignments
    travel1 = '123'.                              "elementary
    travel2 = VALUE #(     travel_id = '123'   ). "structure
    travel4 = VALUE #(  (  travel_id = '123' ) ). "table


  ENDMETHOD.
ENDCLASS.
