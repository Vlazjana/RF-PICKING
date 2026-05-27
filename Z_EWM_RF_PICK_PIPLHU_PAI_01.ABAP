FUNCTION z_ewm_rf_pick_piplhu_pai_01.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  CHANGING
*"     REFERENCE(SELECTION) TYPE  /SCWM/S_RF_SELECTION
*"     REFERENCE(RESOURCE) TYPE  /SCWM/S_RSRC
*"     REFERENCE(WHO) TYPE  /SCWM/S_WHO_INT
*"     REFERENCE(ORDIM_CONFIRM) TYPE  /SCWM/S_RF_ORDIM_CONFIRM
*"     REFERENCE(NESTED_HU) TYPE  /SCWM/S_RF_NESTED_HU
*"     REFERENCE(TT_ORDIM_CONFIRM) TYPE  /SCWM/TT_RF_ORDIM_CONFIRM
*"     REFERENCE(TT_NESTED_HU) TYPE  /SCWM/TT_RF_NESTED_HU
*"     REFERENCE(T_RF_PICK_HUS) TYPE  /SCWM/TT_RF_PICK_HUS
*"     REFERENCE(WME_VERIF) TYPE  /SCWM/S_WME_VERIF
*"     REFERENCE(S_WHO_SCREEN) TYPE  ZSRF_ZPISYS_WHO_SCREEN OPTIONAL
*"----------------------------------------------------------------------

  DATA: lv_tablin              TYPE i.
  DATA: lv_restart_transaction TYPE xfeld VALUE IS INITIAL,
        lv_field               TYPE ddobjname,
        ls_dfies               TYPE dfies,
        lv_rvseq_not_allowed   TYPE xfeld VALUE IS INITIAL,
        lv_leave_trans         TYPE xfeld VALUE IS INITIAL,
        lv_fixpath             TYPE /scwm/de_fixpath,
        oref                   TYPE REF TO /scwm/cl_wm_packing,
        lv_applic              TYPE /scwm/de_applic,
        lv_pres_prf            TYPE /scwm/de_pres_prf,
        lv_ltrans              TYPE /scwm/de_ltrans,
        lv_step                TYPE /scwm/de_step,
        lv_fcode               TYPE /scwm/de_fcode,
        lv_state               TYPE /scwm/de_state,
        ls_who                 TYPE /scwm/who,
        lt_ordim_o             TYPE /scwm/tt_ordim_o,
        ls_ordim_o             TYPE /scwm/ordim_o,
        ls_ordim_confirm       TYPE /scwm/s_rf_ordim_confirm,
        ls_huhdr               TYPE /scwm/huhdr,
        ls_huhdr_int           TYPE /scwm/s_huhdr_int,
        lv_return_code         TYPE sy-subrc,
        lv_return              TYPE boole_d.

  DATA: lo_badi TYPE REF TO /scwm/ex_rf_prt_wo_hu.

  DATA: lv_lines_total TYPE i,
        lv_line_new    TYPE i,
        lv_line        TYPE i,
        lv_data_entry  TYPE /scwm/de_data_entry.

  BREAK-POINT ID /scwm/rf_picking.

* Get function code
  lv_fcode = /scwm/cl_rf_bll_srvc=>get_fcode( ).
  lv_ltrans = /scwm/cl_rf_bll_srvc=>get_ltrans( ).
  lv_step = /scwm/cl_rf_bll_srvc=>get_step( ).
  lv_state = /scwm/cl_rf_bll_srvc=>get_state( ).
  lv_data_entry = /scwm/cl_rf_bll_srvc=>get_data_entry( ).

* Set process mode to foreground as default
  /scwm/cl_rf_bll_srvc=>set_prmod( /scwm/cl_rf_bll_srvc=>c_prmod_foreground ).

* Normally the structure ORDIM_CONFIRM is filled in validation function module /scwm/rf_pick_hu_check
* IF some verification field(s) are switched off by customizing settings, this read did not happen
  lv_tablin = /scwm/cl_rf_bll_srvc=>get_line( ).
  IF lv_tablin = 0. lv_tablin = 1. ENDIF.
  READ TABLE tt_ordim_confirm INTO ordim_confirm INDEX lv_tablin.


  CASE lv_fcode.
  WHEN 'ZENT'. "ZPICK5

    WHEN 'ZFINAL'. "ZPICK5

    WHEN fcode_print.

      lv_applic   = /scwm/cl_rf_bll_srvc=>get_applic( ).
      lv_pres_prf = /scwm/cl_rf_bll_srvc=>get_pres_prf( ).
      lv_ltrans   = /scwm/cl_rf_bll_srvc=>get_ltrans( ).
      lv_step = /scwm/cl_rf_bll_srvc=>get_step( ).
      lv_state = /scwm/cl_rf_bll_srvc=>get_state( ).
      MOVE-CORRESPONDING who TO ls_who.

      CLEAR ls_ordim_o.
      REFRESH lt_ordim_o.
      LOOP AT tt_ordim_confirm INTO ls_ordim_confirm.
        MOVE-CORRESPONDING ls_ordim_confirm TO ls_ordim_o.
        APPEND ls_ordim_o  TO lt_ordim_o.
      ENDLOOP.

      IF NOT ordim_confirm-nlenr IS INITIAL.
*       create instance
        IF oref IS NOT BOUND.
          CREATE OBJECT oref.
        ENDIF.

        IF sy-subrc <> 0.
          MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                     WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        ENDIF.

*       Initiate
*        oref->init(
*          EXPORTING
*            iv_lgnum = ordim_confirm-lgnum
*          EXCEPTIONS
*            OTHERS   = 99 ).

*       check HU exist.
        oref->/scwm/if_pack_bas~get_hu(
            EXPORTING
              iv_huident = ordim_confirm-nlenr
            IMPORTING
              es_huhdr   = ls_huhdr_int
            EXCEPTIONS
              not_found = 1 ).

        IF sy-subrc <> 0.
          MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                     WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        ENDIF.
      ENDIF.

      TRY.
          GET BADI lo_badi
            FILTERS
              lgnum = ls_who-lgnum.

          MOVE-CORRESPONDING ls_huhdr_int TO ls_huhdr.

          CALL BADI lo_badi->print
            EXPORTING
              iv_lgnum    = ls_who-lgnum
              iv_applic   = lv_applic
              iv_pres_prf = lv_pres_prf
              iv_ltrans   = lv_ltrans
              iv_step     = lv_step
              iv_fcode    = lv_fcode
              iv_state    = lv_state
              is_who      = ls_who
              it_ordim_o  = lt_ordim_o
              is_huhdr    = ls_huhdr
              it_pick_hus = t_rf_pick_hus
            IMPORTING
              ev_return   = lv_return_code.

          IF lv_return_code <> 0.
            MESSAGE e053.
          ENDIF.

        CATCH cx_badi.
          MESSAGE e305(/scwm/ui_rf).
      ENDTRY.
      EXIT.

    WHEN fcode_backf.

      CALL FUNCTION '/SCWM/RF_PICK_BACKF_CHECK'
        CHANGING
          tt_ordim_confirm = tt_ordim_confirm
          lv_leave_trans   = lv_leave_trans.

      IF NOT lv_leave_trans IS INITIAL.
        CALL FUNCTION '/SCWM/RF_PICK_LEAVE_TRANS_CHCK'
          CHANGING
            who              = who
            resource         = resource
            ordim_confirm    = ordim_confirm
            tt_ordim_confirm = tt_ordim_confirm.
        EXIT.
      ELSE.
        EXIT.
      ENDIF.

    WHEN fcode_rvseq.

      CALL FUNCTION '/SCWM/FIXPATH_FLAG_READ'
        EXPORTING
          iv_lgnum    = ordim_confirm-lgnum
          iv_aarea    = ordim_confirm-aarea
          iv_actty    = ordim_confirm-act_type
*         IV_NOBUF    = 'X'
        IMPORTING
          ev_fixpath  = lv_fixpath
        EXCEPTIONS
          wrong_input = 1
          not_found   = 2
          OTHERS      = 3.
      IF sy-subrc <> 0.
        MESSAGE e048 WITH ordim_confirm-lgnum
                          ordim_confirm-aarea
                          ordim_confirm-act_type.
      ELSE.
        IF NOT lv_fixpath IS INITIAL.
          lv_rvseq_not_allowed = gc_xfeld.
        ENDIF.
      ENDIF.

      DATA: lo_badi2 TYPE REF TO /scwm/ex_rf_pick_wt_reseq.

      TRY.
          GET BADI lo_badi2
            FILTERS
              lgnum = who-lgnum.

          CALL BADI lo_badi2->resequence_allowed
            EXPORTING
              iv_lgnum               = who-lgnum
              is_who                 = who
              it_ordim_confirm       = tt_ordim_confirm
            CHANGING
              ev_resqnce_not_allowed = lv_rvseq_not_allowed.

        CATCH cx_badi.
      ENDTRY.

      IF NOT lv_rvseq_not_allowed IS INITIAL.
        MESSAGE e033.
      ELSE.

*       Change sort sequence.
        IF gv_pick_sort = gc_sort_ascending.
          gv_pick_sort = gc_sort_descending.
        ELSEIF gv_pick_sort = gc_sort_descending.
          gv_pick_sort = gc_sort_ascending.
        ENDIF.

*       Sorting TOs
        CALL FUNCTION '/SCWM/RF_PICK_WHO_TO_SORT'
          CHANGING
            ordim_confirm    = ordim_confirm
            tt_ordim_confirm = tt_ordim_confirm
            who              = who.
        /scwm/cl_rf_bll_srvc=>set_prmod(
                   /scwm/cl_rf_bll_srvc=>c_prmod_background ).

        /scwm/cl_rf_bll_srvc=>set_line( 1 ).

        CALL FUNCTION '/SCWM/RF_PICK_SET_STATE'
          CHANGING
            resource      = resource
            ordim_confirm = ordim_confirm.

        CALL FUNCTION '/SCWM/RF_PICK_SET_FCODE'
          CHANGING
            resource         = resource
            ordim_confirm    = ordim_confirm
            tt_ordim_confirm = tt_ordim_confirm.
      ENDIF.

      EXIT.

    WHEN fcode_emptyb.
      IF NOT ordim_confirm-place_inv_ind IS INITIAL.
        CLEAR ordim_confirm-place_inv_ind.
        ordim_confirm-place_inv = gc_place_inv_cancel.
      ELSE.
        MOVE '/SCWM/DE_RF_COUNT' TO lv_field.
        CALL FUNCTION 'DDIF_FIELDINFO_GET'
          EXPORTING
            tabname        = lv_field
            langu          = sy-langu
            all_types      = 'X'
          IMPORTING
            dfies_wa       = ls_dfies
          EXCEPTIONS
            not_found      = 1
            internal_error = 2
            OTHERS         = 3.

*       Fill in the Place Inventory indicator text
        IF sy-subrc = 0.
*         Move short text to Place Inventory indicator
          MOVE ls_dfies-scrtext_s TO ordim_confirm-place_inv_ind.
        ENDIF.

        ordim_confirm-place_inv = gc_place_inv_compl.
        MODIFY tt_ordim_confirm FROM ordim_confirm INDEX lv_tablin
            TRANSPORTING place_inv_ind place_inv.
      ENDIF.
    WHEN 'SKIP'.  "Pick by Voice "Jump to next entry
      lv_line = lv_tablin.
*     First check if we can jump to next entry
      DESCRIBE TABLE tt_ordim_confirm LINES lv_lines_total.
      lv_line_new = lv_line.
      DO.
        CLEAR ls_ordim_confirm.
        IF lv_line_new = lv_lines_total.  "End of table reached
          lv_line_new = 1.
        ELSE.
          ADD 1 TO lv_line_new.
        ENDIF.

        READ TABLE tt_ordim_confirm INTO ls_ordim_confirm
            INDEX lv_line_new.
*       filter out the 1st leg WTs
        IF ls_ordim_confirm-srsrc IS INITIAL.
          CONTINUE.
        ENDIF.
        EXIT.
      ENDDO.

*     in case of PbV, the next task button should reset the WT
      IF lv_data_entry = wmegc_data_entry_voice.
        PERFORM wt_refresh USING    lv_line
                           CHANGING tt_ordim_confirm.
      ENDIF.

*     We can jump to next entry; Simulate PGDN
      CALL METHOD /scwm/cl_rf_bll_srvc=>set_line
        EXPORTING
          iv_line = lv_line_new.

*     Check the next WT choosed by PGUP-PGDN for REC
      READ TABLE tt_ordim_confirm INTO ls_ordim_confirm
          INDEX lv_line_new TRANSPORTING tanum.
      CALL FUNCTION '/SCWM/REC_WT_CHECK'
        EXPORTING
          iv_tanum            = ls_ordim_confirm-tanum
        EXCEPTIONS
          internal_error      = 1
          rec_area_is_engaged = 2
          OTHERS              = 3.
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
          WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.
*     Get next TO data.
      READ TABLE tt_ordim_confirm INTO ordim_confirm
           INDEX lv_line_new.

*     Fill container for application specific verification
      CALL FUNCTION '/SCWM/RF_FILL_WME_VERIF'
        EXPORTING
          iv_lgnum     = ordim_confirm-lgnum
          iv_procty    = ordim_confirm-procty
          iv_trart     = ordim_confirm-trart
          iv_act_type  = ordim_confirm-act_type
          iv_aarea     = ordim_confirm-aarea
        IMPORTING
          es_wme_verif = wme_verif.

      CALL METHOD /scwm/cl_rf_bll_srvc=>set_rebuild_vrf.

      CALL FUNCTION '/SCWM/RF_PICK_SET_STATE'
        CHANGING
          resource      = resource
          ordim_confirm = ordim_confirm.

      CALL FUNCTION '/SCWM/RF_PICK_SET_FCODE'
        CHANGING
          resource         = resource
          ordim_confirm    = ordim_confirm
          tt_ordim_confirm = tt_ordim_confirm.

      CALL METHOD /scwm/cl_rf_bll_srvc=>set_field
        EXPORTING
          iv_field = ''.

      RETURN.

  ENDCASE.
*   WHEN fcode_next OR /scwm/cl_rf_bll_srvc=>c_fcode_enter OR
*         fcode_enterf.


      READ TABLE tt_ordim_confirm INTO ordim_confirm INDEX lv_tablin.

*     Raise query 'Was putaway inventory check succesful'
      IF ordim_confirm-place_inv_recomm IS NOT INITIAL AND
         ordim_confirm-place_inv IS INITIAL.
        IF /scwm/cl_rf_dynpro_srvc=>display_message(
                    iv_msgid           = gc_picking_msgid
                    iv_msgty           = 'Q' "gc_msgty_warning
                    iv_msgno           = '142' ) =
            /scwm/cl_rf_bll_srvc=>c_answer_yes.
          MOVE wmegc_place_inv_done TO ordim_confirm-place_inv.
        ELSE.
          MOVE wmegc_place_inv_reject TO ordim_confirm-place_inv.
        ENDIF.
      ENDIF.

      MODIFY tt_ordim_confirm FROM ordim_confirm INDEX lv_tablin
          TRANSPORTING place_inv.

      "for the asynchronous rf processing we have to check at this point in time whether
      "all the asynchronous processes have finished successfully
      /scwm/cl_rf_confirm_picking=>get_instance( )->complete_async_processing(
        EXPORTING
          iv_tablin              = lv_tablin
        IMPORTING
          ev_return              = lv_return
          ev_restart_transaction = lv_restart_transaction
        CHANGING
          cs_ordim_confirm = ordim_confirm
          ct_ordim_confirm = tt_ordim_confirm ).

      IF lv_return = abap_true.
        RETURN.
      ENDIF.

      IF lv_restart_transaction = abap_false.
        "After data is checked call confirmation function.
        CALL FUNCTION 'Z_EWM_RF_PICK_ORDIM_CONFIRM_01'
          IMPORTING
            ev_restart_transaction = lv_restart_transaction
          CHANGING
            resource               = resource
            tt_ordim_confirm       = tt_ordim_confirm
            ordim_confirm          = ordim_confirm
            tt_nested_hu           = tt_nested_hu
            who                    = who.
      ENDIF.

* If the posting was okay we check the navigation
      CALL FUNCTION 'Z_EWM_RF_PICK_NAVIGATION_01'
        EXPORTING
          iv_restart_transaction = lv_restart_transaction
        CHANGING
          tt_ordim_confirm       = tt_ordim_confirm
          ordim_confirm          = ordim_confirm
          resource               = resource
          selection              = selection
          who                    = who
          wme_verif              = wme_verif
          t_rf_pick_hus          = t_rf_pick_hus.

ENDFUNCTION.
