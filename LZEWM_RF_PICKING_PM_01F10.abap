*----------------------------------------------------------------------*
***INCLUDE LZEWM_RF_PICKING_PM_01F10.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form print_picking_label
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> RESOURCE
*&      --> WHO
*&      --> S_WHO_SCREEN
*&      <-- ORDIM_CONFIRM
*&---------------------------------------------------------------------*
FORM print_label
    USING   resource   TYPE /scwm/s_rsrc
            who        TYPE /scwm/s_who_int
  CHANGING  s_who_screen TYPE zsrf_zpisys_who_screen..

  CONSTANTS: lc_smartform TYPE tdsfname VALUE 'ZEWM_PICKING_PROC_01'.

  DATA : lv_fm_name TYPE rs38l_fnam,
         lv_printer TYPE rspopname,
         ls_ctrl_op TYPE ssfctrlop,
         ls_comp_op TYPE ssfcompop,
         ls_return  TYPE ssfcrescl,
         lv_msg     TYPE string.
  DATA : lt_print_label TYPE TABLE OF zsrf_zpisys_who_screen.

  DATA: lv_barcode TYPE /scwm/de_huident.

  " 1. Check at least one WT confirmed
  SELECT COUNT(*) FROM /scwm/ordim_c
    WHERE lgnum = @who-lgnum
      AND who   = @who-who
    INTO @DATA(lv_confirmed_count).

  IF lv_confirmed_count = 0.
    MESSAGE e042(zewm_rf_msg).
    RETURN.
  ENDIF.

  " Get DLOC from confirmed tasks

  SELECT SINGLE nlpla
    FROM /scwm/ordim_O
    WHERE lgnum = @resource-lgnum
      AND who   = @who-who
    INTO @DATA(lv_dloc).


  DATA(lv_outb_del) = s_who_screen-pdo.
  SHIFT lv_outb_del LEFT DELETING LEADING '0'.

  s_who_screen-pdo = lv_outb_del.
  s_who_screen-lgnum =  resource-lgnum.
  s_who_screen-rsrc =  resource-rsrc.
  s_who_screen-z_dats = sy-datum.
  s_who_screen-nlpla  = lv_dloc.


  APPEND s_who_screen TO lt_print_label.
* Stampa etichetta
* Stampa Smartform*******************************************************************************
  CALL FUNCTION 'SSF_FUNCTION_MODULE_NAME'
    EXPORTING
      formname           = lc_smartform
    IMPORTING
      fm_name            = lv_fm_name
    EXCEPTIONS
      no_form            = 1
      no_function_module = 2
      OTHERS             = 3.

  IF sy-subrc <> 0.
*    MESSAGE 'SmartForm non trovato/attivato' TYPE 'E'.  " message class
    MESSAGE e035(zewm_rf_msg).
  ENDIF.

  ls_ctrl_op-no_dialog   = abap_true.
*  ls_ctrl_op-preview     = abap_false.
  ls_ctrl_op-preview     = abap_true.
  ls_comp_op-tdprinter   = 'PDFPRINTER'.
  ls_comp_op-tddest      = 'ZPDF'.
  ls_comp_op-tdcopies    = 1.
  ls_comp_op-tdimmed     = abap_true.   " stampa immediata (non trattiene in spool)
*  ls_comp_op-tddelete    = abap_true.   " cancella spool dopo stampa
  ls_comp_op-tddelete    = abap_false.   " non cancella spool dopo stampa
  ls_comp_op-tdfinal     = abap_true.   " chiude il job di stampa

  CALL FUNCTION lv_fm_name
    EXPORTING
      control_parameters = ls_ctrl_op
      output_options     = ls_comp_op
      user_settings      = abap_false     "non usare impostazioni utente?
    IMPORTING
      job_output_info    = ls_return
    TABLES
      it_zrf_picking     = lt_print_label
    EXCEPTIONS
      formatting_error   = 1
      internal_error     = 2
      send_error         = 3
      user_canceled      = 4
      OTHERS             = 5.

  CASE sy-subrc.
    WHEN 0.
      "OK
*      aggiungi data_stampa
      MODIFY zrf_picking FROM TABLE lt_print_label.
      IF sy-subrc = 0.
        COMMIT WORK AND WAIT.
      ELSE.
        MESSAGE e043(zewm_rf_msg).
      ENDIF.

*        gv_stampato = 'X'.

    WHEN 1.
      "Errore di formattazione (es. reference field mancante, overflow)
      MESSAGE e036(zewm_rf_msg).
    WHEN 2.
      "Errore interno SmartForms
      MESSAGE e037(zewm_rf_msg).
    WHEN 3.
      "Errore invio alla stampante
      MESSAGE e038(zewm_rf_msg).
    WHEN 4.
      "Operatore ha cancellato (non dovrebbe accadere perchè si manda in stampa senza popup)
      MESSAGE e039(zewm_rf_msg).
    WHEN OTHERS.
      MESSAGE e040(zewm_rf_msg).
  ENDCASE.


ENDFORM.
*&---------------------------------------------------------------------*
*& Form handle_sc6_enter
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> RESOURCE
*&      --> WHO
*&      <-- GT_WHO_SCREEN
*&---------------------------------------------------------------------*
FORM handle_sc6_enter
  USING    is_resource   TYPE /scwm/s_rsrc
           is_who        TYPE /scwm/s_who_int
  CHANGING ct_who_screen TYPE zttrf_zpisys_who_screen.

  DATA: lt_compact   TYPE zttrf_zpisys_who_screen,
        lv_check_tab TYPE i,
        lv_matnr     TYPE matnr.

  DATA: lt_sc6       TYPE ztt_ewm_rf_rcv_sc6_ctx,
        ls_ctx_f10   TYPE zss_ewm_rf_recov_ctx,
        lv_found_f10 TYPE abap_bool.

  LOOP AT ct_who_screen ASSIGNING FIELD-SYMBOL(<ls_row>).

    IF <ls_row>-matnr IS NOT INITIAL.

      IF strlen( <ls_row>-matnr ) = 1.
        " Scenario 1 - typed ZZCODE
        DATA(lv_zzcode) = <ls_row>-matnr.
        SELECT SINGLE matnr
          FROM ztewm_mat_imb
          WHERE lgnum  = @is_resource-lgnum
            AND zzcode = @lv_zzcode
          INTO @lv_matnr.
      ELSE.
        " Scenario 2 - typed full matnr
        CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
          EXPORTING
            input  = <ls_row>-matnr
          IMPORTING
            output = lv_matnr
          EXCEPTIONS
            OTHERS = 1.
        IF sy-subrc <> 0.
          MESSAGE e029(zewm_rf_msg).
          RETURN.
        ENDIF.
        SELECT SINGLE matnr
          FROM ztewm_mat_imb
          WHERE lgnum = @is_resource-lgnum
            AND matnr = @<ls_row>-matnr
          INTO @lv_matnr.
      ENDIF.

      IF sy-subrc <> 0.
        MESSAGE e030(zewm_rf_msg).
        RETURN.
      ENDIF.

      <ls_row>-matnr = to_upper( lv_matnr ).

      READ TABLE lt_compact WITH KEY matnr = lv_matnr
        TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        MESSAGE e031(zewm_rf_msg) WITH sy-tabix.
        RETURN.
      ENDIF.

      SELECT SINGLE maktx
        FROM makt
        WHERE matnr = @lv_matnr
          AND spras = @sy-langu
        INTO @<ls_row>-maktx.

      APPEND <ls_row> TO lt_compact.

    ELSE.

      IF <ls_row>-nr_packaging IS NOT INITIAL.
        MESSAGE e032(zewm_rf_msg).
        RETURN.
      ENDIF.

      " Both empty
      CLEAR <ls_row>-maktx.
      lv_check_tab += 1.

    ENDIF.
  ENDLOOP.

  DO lv_check_tab TIMES.
    APPEND INITIAL LINE TO lt_compact.
  ENDDO.

  ct_who_screen = lt_compact.

  IF gt_certificazione IS INITIAL.
    MESSAGE e033(zewm_rf_msg).
    RETURN.
  ENDIF.

  LOOP AT ct_who_screen INTO DATA(ls_pkg)
    WHERE matnr        IS NOT INITIAL
      AND nr_packaging >  0.
    APPEND VALUE zss_ewm_rf_rcv_sc6_ctx(
      matnr        = ls_pkg-matnr
      nr_packaging = ls_pkg-nr_packaging
      maktx        = ls_pkg-maktx
    ) TO lt_sc6.
  ENDLOOP.

  IF lt_sc6 IS NOT INITIAL.
    PERFORM load_recov_ctx
    USING    is_resource-lgnum
             is_resource-rsrc
             is_who-who
  CHANGING ls_ctx_f10 lv_found_f10.
    IF lv_found_f10 = abap_true.

      CLEAR ls_ctx_f10-tt_rcv_sc6.
      LOOP AT lt_sc6 INTO DATA(ls_sc6_save).
        APPEND INITIAL LINE TO ls_ctx_f10-tt_rcv_sc6
          ASSIGNING FIELD-SYMBOL(<ls_ctx_sc6>).
        MOVE-CORRESPONDING ls_sc6_save TO <ls_ctx_sc6>.
      ENDLOOP.

      PERFORM save_recov_ctx_partial
        USING    is_resource-lgnum
                 is_resource-rsrc
                 is_who-who
        CHANGING ls_ctx_f10.
    ENDIF.
    COMMIT WORK AND WAIT.
  ENDIF.
ENDFORM.
