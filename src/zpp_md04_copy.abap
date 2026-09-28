*********************************************************************************
*  程序名:ZPP_MD04_COPY
*  描述:
*    参考MD04功能，实现多个物料查询需求清单
*=================================================
*  修改日期   版本    修改人      修改描述
* BAPI_MATERIAL_STOCK_REQ_LIST
********************************************************************************
REPORT  zpp_md04_copy LINE-SIZE 130
                      LINE-COUNT 65
                      MESSAGE-ID 00
                      NO STANDARD PAGE HEADING.

*------------------------------------------------------------------------------*
*                             GLOBLE-DEFINATION                              *
*------------------------------------------------------------------------------*
TYPE-POOLS: slis,icon.

DEFINE data_alv. "宏定义
  CLEAR wa_fieldcat.
  wa_fieldcat-col_pos   = g_colpos.
  wa_fieldcat-fieldname = &1.
  wa_fieldcat-reptext   = &2.
  wa_fieldcat-no_zero   = &3.
  wa_fieldcat-no_out    = &4.
  wa_fieldcat-intlen    = &5.
  g_colpos = g_colpos + 1.
  APPEND wa_fieldcat TO lt_fieldcat.
END-OF-DEFINITION.

DATA: lt_fieldcat TYPE lvc_t_fcat,  "ALV输出字段
      t_fcat      TYPE lvc_t_fcat,
      wa_fieldcat LIKE LINE OF lt_fieldcat,
      wa_layout   TYPE lvc_s_layo.  "定义ALV样式

TABLES:mara,marc,mdtb,rm61r,mdez,mdkp.

DATA g_colpos TYPE lvc_colpos.

DATA:BEGIN OF gt_alv OCCURS 0,

       matnr          TYPE mara-matnr,
       maktx          TYPE makt-maktx,
       werks          TYPE marc-werks,
       berid          TYPE rm61r-berid,

       matl_type      TYPE  bapi_mrp_list-matl_type,
       base_uom       TYPE  bapi_mrp_list-base_uom,
       ll_code        TYPE  bapi_mrp_list-ll_code,
       proc_type      TYPE  bapi_mrp_list-proc_type,
       mrp_type       TYPE  bapi_mrp_list-mrp_type,
       mrp_ctrler     TYPE  bapi_mrp_list-mrp_ctrler,
       pur_group      TYPE  bapi_mrp_list-pur_group,
       rep_lead_time  TYPE  bapi_mrp_list-rep_lead_time,
       lotsizekey     TYPE  bapi_mrp_list-lotsizekey,
       fixed_lot      TYPE  bapi_mrp_list-fixed_lot,
       plnt_stock     TYPE  bapi_mrp_list-plnt_stock,
       mrp_group      TYPE  bapi_mrp_list-mrp_group,
       dayssupply     TYPE  bapi_mrp_list-dayssupply,
       reqdayssupply  TYPE  bapi_mrp_list-reqdayssupply,
       no_excmess_01  TYPE  bapi_mrp_list-no_excmess_01,
       no_excmess_02  TYPE  bapi_mrp_list-no_excmess_02,
       no_excmess_03  TYPE  bapi_mrp_list-no_excmess_03,
       no_excmess_04  TYPE  bapi_mrp_list-no_excmess_04,
       no_excmess_05  TYPE  bapi_mrp_list-no_excmess_05,
       no_excmess_06  TYPE  bapi_mrp_list-no_excmess_06,
       no_excmess_07  TYPE  bapi_mrp_list-no_excmess_07,
       no_excmess_08  TYPE  bapi_mrp_list-no_excmess_08,
       abc_id         TYPE  bapi_mrp_list-abc_id,
       reqdayssupply2 TYPE  bapi_mrp_list-reqdayssupply2.

       INCLUDE TYPE bapi_mrp_ind_lines.

DATA:END OF gt_alv.
DATA:gs_alv LIKE LINE OF gt_alv.

DATA:BEGIN OF lt_matnr OCCURS 0,
       matnr TYPE mara-matnr,
       werks TYPE marc-werks,
     END OF lt_matnr.

DATA:l_maktx       TYPE makt-maktx.
DATA:ls_bapimatdoa TYPE bapimatdoa.
DATA:gt_maktx TYPE STANDARD TABLE OF makt.
DATA:gs_maktx TYPE makt.


DATA:BEGIN OF gt_task OCCURS 0,
       matnr        TYPE mara-matnr,
       werks        TYPE marc-werks,
       berid        TYPE rm61r-berid,
       taskname(10) TYPE c, "任务名
       flag         TYPE c, "success = X
     END OF gt_task.

DATA: lv_berid       TYPE berid,
      lv_index       TYPE char20,
      gv_index       TYPE char20,
      g_taskname(20) TYPE c,                "task name（同时运行的任务名称必须保持唯一）
      g_classname    TYPE rzlli_apcl,          "Server Group Name
      g_applserver   TYPE rzllitab-applserver, "RFC Serve Group
      open_task_num  TYPE i,
      gv_snd_jobs    TYPE i  VALUE 0,
      gv_rcv_jobs    TYPE i  VALUE 0,
      gs_task        LIKE LINE OF gt_task,
      g_wp           TYPE c VALUE 5 .  "并发进程数（根据RZ12中的最大请求队列数设置）

DATA: lv_mod          TYPE i,
      lv_mod_left     TYPE i,
      lv_mod_dif      TYPE i,
      lv_mod_dif_next TYPE i,
      lv_lines        TYPE i,
      l_begin         TYPE i,
      l_end           TYPE i.
*------------------------------------------------------------------------------*
*                             SELECTION-SCREEN                                 *
*------------------------------------------------------------------------------*

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.

  SELECT-OPTIONS :
                   s_auskt FOR mdez-auskt ,
                   s_matnr FOR mara-matnr ,
                   s_werks FOR marc-werks  DEFAULT '2C40' OBLIGATORY,
                   s_berid FOR rm61r-berid DEFAULT '2C40',
                   s_dat00 FOR mdtb-dat00 ,
                   s_dispo FOR marc-dispo .

  PARAMETERS: p_plumi TYPE plumi.

SELECTION-SCREEN END OF BLOCK b1.

*------------------------------------------------------------------------------*
*                             INITIALIZATION                                 *
*------------------------------------------------------------------------------*
INITIALIZATION.

*------------------------------------------------------------------------------*
*                             AT SELECTION-SCREEN                              *
*------------------------------------------------------------------------------*
AT SELECTION-SCREEN OUTPUT.

*------------------------------------------------------------------------------*
*                             START-OF-SELECTION                               *
*------------------------------------------------------------------------------*
START-OF-SELECTION.

*  CALL FUNCTION 'ENQUEUE_EZPP_MD04_COPY'.
*  IF SY-SUBRC <> 0.
*    MESSAGE ID SY-MSGID TYPE 'S' NUMBER SY-MSGNO
*          WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4 DISPLAY LIKE SY-MSGTY.
*    EXIT.
*  ELSE.
  PERFORM frm_get_data.
  "  ENDIF.

END-OF-SELECTION.
  IF  lv_lines GT 100.
    CALL FUNCTION 'DEQUEUE_EZPP_MD04_COPY'.
  ENDIF.
  IF gt_alv[] IS NOT INITIAL.

    PERFORM frm_display_data."显示数据

  ELSE.

    MESSAGE s001(xw) WITH TEXT-t08 DISPLAY LIKE 'E'.

  ENDIF.

*&---------------------------------------------------------------------*
*&      Form  FRM_GET_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM frm_get_data .

  DATA:gt_mrp_ind_lines TYPE TABLE OF bapi_mrp_ind_lines,
       lt_mrp_ind_lines TYPE TABLE OF bapi_mrp_ind_lines,
       ls_mrp_list      TYPE bapi_mrp_list,
       ls_mrp_ind_lines TYPE bapi_mrp_ind_lines,

       l_berid          TYPE rm61r-berid.

*       LT_MD04_HEADER_SEL TYPE TABLE OF ZPP_MD04_HEADER,
*
*       LT_ZPP_MD04_HEADER TYPE TABLE OF ZPP_MD04_HEADER,
*       LS_ZPP_MD04_HEADER TYPE ZPP_MD04_HEADER,
*       LT_ZPP_MD04_ITEM   TYPE TABLE OF ZPP_MD04_ITEM,
*       LS_ZPP_MD04_ITEM   TYPE ZPP_MD04_ITEM.

  DATA:gt_mdlv TYPE TABLE OF mdlv,
       gs_mdlv TYPE mdlv.
  IF s_berid[] IS NOT INITIAL.
    REFRESH gt_mdlv[].
    SELECT *
      INTO TABLE gt_mdlv
      FROM mdlv
      WHERE berid IN s_berid.
  ENDIF.

  SELECT matnr werks
    INTO TABLE lt_matnr
    FROM marc
   WHERE matnr IN s_matnr
     AND werks IN s_werks
     AND dispo IN s_dispo.
  SORT lt_matnr.

  DESCRIBE TABLE lt_matnr LINES lv_lines.

  IF  lv_lines GT 100.
    CALL FUNCTION 'ENQUEUE_EZPP_MD04_COPY'.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 DISPLAY LIKE sy-msgty.
      EXIT.
    ELSE.

    ENDIF.
  ENDIF.
*  获取 RFC Serve Group name
* 一般系统默认g_classname = 'parallel_generators'，但为了通用性按照如下方法获取

  CALL 'C_SAPGPARAM' ID 'NAME'  FIELD 'rdisp/myname' ID 'VALUE' FIELD g_applserver.

  SELECT SINGLE classname
    FROM rzllitab
    INTO g_classname   "Server Group Name
    WHERE applserver = g_applserver
      AND grouptype  = 'S'.   "S:服务器组，空:登陆组



*get material descriptuion
  IF lt_matnr[] IS NOT INITIAL.
    SELECT * INTO TABLE gt_maktx FROM makt FOR ALL ENTRIES IN lt_matnr
      WHERE
      matnr = lt_matnr-matnr AND
      spras = '1'.
    SORT gt_maktx BY matnr ASCENDING.
    DELETE ADJACENT DUPLICATES FROM gt_maktx COMPARING matnr.
  ENDIF.
  IF lv_lines GT 100.

    REFRESH gt_alv[].

    IF gt_mdlv[] IS NOT INITIAL.
      CLEAR lv_index.

      LOOP AT lt_matnr.

        LOOP AT gt_mdlv INTO gs_mdlv WHERE werzg = lt_matnr-werks.
*多线程执行
          lv_index = lv_index + 1.
          CONDENSE lv_index.

          CLEAR g_taskname.
          CONCATENATE 'Task' lv_index INTO g_taskname.
          CONDENSE g_taskname.

          gs_task-taskname  = g_taskname.
          gs_task-matnr     = lt_matnr-matnr.
          gs_task-werks     = lt_matnr-werks.
          gs_task-berid     = gs_mdlv-berid.
          APPEND gs_task TO gt_task.

          lv_berid          = gs_mdlv-berid.
          SORT gt_task BY taskname.

          CALL FUNCTION 'BAPI_MATERIAL_STOCK_REQ_LIST' STARTING NEW TASK g_taskname
            DESTINATION IN GROUP g_classname
            PERFORMING frm_end_of_task ON END OF TASK
            EXPORTING
              material_long         = lt_matnr-matnr
              plant                 = lt_matnr-werks
              mrp_area              = lv_berid
            EXCEPTIONS
              communication_failure = 1
              system_failure        = 2
              resource_failure      = 3.
          IF sy-subrc = 0.
            gv_snd_jobs = gv_snd_jobs + 1.
          ENDIF.

          open_task_num = open_task_num + 1.   "记录启动的进程数量
          IF open_task_num = g_wp.    "p_wp = RZ12中的 Max. requests in queue
            WAIT UNTIL gv_rcv_jobs >= gv_snd_jobs.
            CLEAR:open_task_num,gv_rcv_jobs,gv_snd_jobs.
          ENDIF.

          CLEAR gs_mdlv.
        ENDLOOP.

        CLEAR lt_matnr.
      ENDLOOP.

    ELSE.

      LOOP AT lt_matnr.

*多线程执行
        lv_index = sy-tabix.
        CONDENSE lv_index.

        CLEAR g_taskname.
        CONCATENATE 'Task' lv_index INTO g_taskname.
        CONDENSE g_taskname.

        gs_task-taskname  = g_taskname.
        gs_task-matnr     = lt_matnr-matnr.
        gs_task-werks     = lt_matnr-werks.
        gs_task-berid     = lt_matnr-werks.
        APPEND gs_task TO gt_task.

        lv_berid          = lt_matnr-werks.
        SORT gt_task BY taskname.

        CALL FUNCTION 'BAPI_MATERIAL_STOCK_REQ_LIST' STARTING NEW TASK g_taskname
          DESTINATION IN GROUP g_classname
          PERFORMING frm_end_of_task ON END OF TASK
          EXPORTING
            material_long         = lt_matnr-matnr
            plant                 = lt_matnr-werks
            mrp_area              = lv_berid
          EXCEPTIONS
            communication_failure = 1
            system_failure        = 2
            resource_failure      = 3.
        IF sy-subrc = 0.
          gv_snd_jobs = gv_snd_jobs + 1.
        ENDIF.

        open_task_num = open_task_num + 1.   "记录启动的进程数量
        IF open_task_num = g_wp.    "p_wp = RZ12中的 Max. requests in queue
          WAIT UNTIL gv_rcv_jobs >= gv_snd_jobs.
          CLEAR:open_task_num,gv_rcv_jobs,gv_snd_jobs.
        ENDIF.

        CLEAR lt_matnr.
      ENDLOOP.

    ENDIF.

  ELSE.

    REFRESH gt_alv[].
    LOOP AT lt_matnr.
      CLEAR l_maktx.
      CLEAR ls_bapimatdoa.
*      CALL FUNCTION 'BAPI_MATERIAL_GET_DETAIL'
*        EXPORTING
*          material              = lt_matnr-matnr
*        IMPORTING
*          material_general_data = ls_bapimatdoa.
      READ TABLE gt_maktx INTO gs_maktx WITH KEY matnr = lt_matnr-matnr BINARY SEARCH.
      IF sy-subrc = 0.
        l_maktx = gs_maktx-maktx.
      ENDIF.
*      l_maktx = ls_bapimatdoa-matl_desc.

      IF gt_mdlv IS NOT INITIAL.
        LOOP AT gt_mdlv INTO gs_mdlv WHERE werzg = lt_matnr-werks.

          REFRESH lt_mrp_ind_lines[].
          CLEAR ls_mrp_list.
          CLEAR l_berid.
          l_berid = gs_mdlv-berid.
          CALL FUNCTION 'BAPI_MATERIAL_STOCK_REQ_LIST'
            EXPORTING
              material_long = lt_matnr-matnr
              plant         = lt_matnr-werks
              mrp_area      = l_berid
            IMPORTING
              mrp_list      = ls_mrp_list
            TABLES
              mrp_ind_lines = lt_mrp_ind_lines.
          LOOP AT lt_mrp_ind_lines INTO ls_mrp_ind_lines WHERE avail_date IN s_dat00
                                                           AND excmessage IN s_auskt.

            IF p_plumi IS NOT INITIAL AND ls_mrp_ind_lines-plus_minus NE p_plumi.
              CONTINUE.
            ENDIF.

            CLEAR gs_alv.
            MOVE-CORRESPONDING ls_mrp_ind_lines TO gs_alv.
            MOVE-CORRESPONDING ls_mrp_list TO gs_alv.

            CALL FUNCTION 'CONVERSION_EXIT_MATN1_OUTPUT'
              EXPORTING
                input  = lt_matnr-matnr
              IMPORTING
                output = gs_alv-matnr.

            gs_alv-maktx = l_maktx.
            gs_alv-werks = lt_matnr-werks.
            gs_alv-berid = gs_mdlv-berid.

            APPEND gs_alv TO gt_alv.
            CLEAR gs_alv.
          ENDLOOP.

          CLEAR gs_mdlv.
        ENDLOOP.
      ELSE.

        REFRESH lt_mrp_ind_lines[].
        CLEAR ls_mrp_list.
        l_berid = lt_matnr-werks.
        CALL FUNCTION 'BAPI_MATERIAL_STOCK_REQ_LIST'
          EXPORTING
            material_long = lt_matnr-matnr
            plant         = lt_matnr-werks
            mrp_area      = l_berid
          IMPORTING
            mrp_list      = ls_mrp_list
          TABLES
            mrp_ind_lines = lt_mrp_ind_lines.
        LOOP AT lt_mrp_ind_lines INTO ls_mrp_ind_lines WHERE avail_date IN s_dat00
                                                         AND excmessage IN s_auskt.

          IF p_plumi IS NOT INITIAL AND ls_mrp_ind_lines-plus_minus NE p_plumi.
            CONTINUE.
          ENDIF.

          CLEAR gs_alv.
          MOVE-CORRESPONDING ls_mrp_ind_lines TO gs_alv.
          MOVE-CORRESPONDING ls_mrp_list TO gs_alv.

          CALL FUNCTION 'CONVERSION_EXIT_MATN1_OUTPUT'
            EXPORTING
              input  = lt_matnr-matnr
            IMPORTING
              output = gs_alv-matnr.

          gs_alv-maktx = l_maktx.
          gs_alv-werks = lt_matnr-werks.
          gs_alv-berid = lt_matnr-werks.

          APPEND gs_alv TO gt_alv.
          CLEAR gs_alv.
        ENDLOOP.

      ENDIF.

      CLEAR lt_matnr.
    ENDLOOP.

  ENDIF.

ENDFORM.                    " FRM_GET_DATA


*&---------------------------------------------------------------------*
*&      Form  frm_display_data
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM frm_display_data .

**  REFRESH t_fcat[].
**  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
**    EXPORTING
**      i_structure_name       = 'BAPI_MRP_IND_LINES'
**    CHANGING
**      ct_fieldcat            = t_fcat
**    EXCEPTIONS
**      inconsistent_interface = 1
**      program_error          = 2
**      OTHERS                 = 3.
**  IF sy-subrc <> 0.
**    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
**            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
**  ENDIF.

  REFRESH lt_fieldcat.
  CLEAR wa_fieldcat.
  g_colpos = 1.
  data_alv          'MATNR'         '物料'     '' '' 18.
  data_alv          'MAKTX'         '物料描述' '' '' 40.
  data_alv          'WERKS'         '工厂'     '' '' 10.
  data_alv          'BERID'         'MRP范围'  '' '' 10.

**  APPEND LINES OF t_fcat[] TO lt_fieldcat[].


  data_alv   'PLNGSEGMT'              '物料需求计划段'  '' '' 10.
  data_alv   'PLNGSEGNO'              '计划段数'  '' '' 20.

  data_alv   'MRP_ELEMENT_IND'        'MRP 元素'  '' '' 10.
  data_alv   'PLUS_MINUS'             '收货/发货标识'  '' '' 10.
  data_alv   'AVAILABLE'              '可用性标识'  '' '' 10.
  data_alv   'AVAIL_DATE'             '收货/需求日期'  '' '' 10.
  data_alv   'FINISH_DATE'            '交货/订单完成日期'  '' '' 10.

  data_alv   'MRP_ELEMNT'             'MRP元素缩写'  '' '' 10.
  data_alv   'ELEMNT_DATA'            'MRP元素'  '' '' 40.
  data_alv   'REC_REQD_QTY'           '收货数量或需求数量'  'X' '' 15.
  data_alv   'AVAIL_QTY1'             '可用量1'  'X' '' 18.
  data_alv   'AVAIL_QTY2'             '可用量2'  'X' '' 18.
  data_alv   'ATP_QTY'                'ATP数量'  'X' '' 18.
  data_alv   'PROD_VERSION'           '生产版本'  '' '' 18.
  data_alv   'BOMEXPL_NO'             'BOM展开号'  '' '' 18.
  data_alv   'REV_LEV'                '版次'  '' '' 10.
  data_alv   'SCRAP'                  '可变的废品数'  'X' '' 16.
  data_alv   'START_DATE'             '开始/批准日期'  '' '' 10.
  data_alv   'OPEN_DATE'              '未清日期'  '' '' 10.
  data_alv   'SPPROCTYPE'             '特别采购类型'  '' '' 10.
  data_alv   'EXT_SPPROCTYPE'         '特殊采购外部显示'  '' '' 10.
  data_alv   'PLAN_PLANT1'            '计划工厂1'  '' '' 10.
  data_alv   'PLAN_PLANT2'            '计划工厂2'  '' '' 10.
  data_alv   'STG_LOC_2'              '发货/收货存储地点'  '' '' 10.
  data_alv   'STORAGE_LOC'            '库存地点'  '' '' 10.
  data_alv   'RESCHED_DATE'           '再计划日期'  '' '' 10.
  data_alv   'VENDOR_NO'              '供应商'  '' '' 10.
  data_alv   'CUSTOMER'               '客户'  '' '' 10.
  data_alv   'CUST_NAME'              '用户名'  '' '' 35.
  data_alv   'VEND_NAME'              '供应商姓名'  '' '' 35.
  data_alv   'REC_REQD_QTY_ALT_UOM'   '收货数量需求数量'  'X' '' 10.
  data_alv   'AVAIL_QTY_ALT_UOM'      '可用量'  'X' '' 10.

  data_alv  'SORT_DATE'           '数字字段长度为 8'  '' '' 10.
  data_alv  'SORTIND_00'          '日班（排序标识0）'  '' '' 10.
  data_alv  'SORTIND_01'          '排序标识01'  '' '' 10.
  data_alv  'SORTIND_02'          '排序标识02'  '' '' 10.
  data_alv  'EXCMSGKEY'           '异常消息键值'  '' '' 10.
  data_alv  'EXCMESSAGE'          '异常消息编号'  '' '' 10.
  data_alv  'FBYTE'               '单字符标记'  '' '' 10.
  data_alv  'INT_TABLE_IND1'      '内部表处理的行索引1'  '' '' 10.
  data_alv  'INT_TABLE_IND2'      '内部表处理的行索引2'  '' '' 10.
  data_alv  'SELECTION'           '选择标志'  '' '' 10.
  data_alv  'EXCEP_IND'           '例外标识'  '' '' 10.
  data_alv  'LOW_LEVEL_EXCPT'     '在低层BOM的例外'  '' '' 10.
  data_alv  'LOW_LEVEL_DELAY'     '低层BOM的延迟'  '' '' 10.
  data_alv  'STOCK_IN_TRANSIT'    'MRP：在途库存'  '' '' 10.
  data_alv  'USER_EXIT1'          '用户退出填充字段1'  '' '' 30.
  data_alv  'USER_EXIT2'          '用户退出填充字段2'  '' '' 30.
  data_alv  'USER_EXIT3'          '用户退出填充字段3'  '' '' 30.
  data_alv  'SORTIND_KD'          '单个客户区段的排序指示'  '' '' 10.
  data_alv  'TEXT_FIELD_ALT_UOM'  '文本字段'  '' '' 30.

  data_alv  'MATL_TYPE'     '物料类型'  '' '' 10.
  data_alv  'BASE_UOM'      '基本计量单位'  '' '' 10.
  data_alv  'LL_CODE'       '低层代码'  '' '' 10.
  data_alv  'PROC_TYPE'     '采购类型'  '' '' 10.
  data_alv  'MRP_TYPE'      'MRP类型'  '' '' 10.
  data_alv  'MRP_CTRLER'    '物料需求计划控制者'  '' '' 10.
  data_alv  'PUR_GROUP'     '采购组'  '' '' 10.
  data_alv  'REP_LEAD_TIME' '计划交货时间'  '' '' 10.
  data_alv  'LOTSIZEKEY'    '批量大小'  '' '' 10.
  data_alv  'FIXED_LOT'     '固定批量大小'  '' '' 15.
  data_alv  'PLNT_STOCK'    '非限制使用的库存'  '' '' 15.
  data_alv  'MRP_GROUP'     'MRP组'  '' '' 10.
  data_alv  'DAYSSUPPLY'    '库存供应天数'  '' '' 10.
  data_alv  'REQDAYSSUPPLY' '第一次日供应量接收'  '' '' 10.
  data_alv  'NO_EXCMESS_01' '例外组1'  '' '' 10.
  data_alv  'NO_EXCMESS_02' '例外组2'  '' '' 10.
  data_alv  'NO_EXCMESS_03' '例外组3'  '' '' 10.
  data_alv  'NO_EXCMESS_04' '例外组4'  '' '' 10.
  data_alv  'NO_EXCMESS_05' '例外组5'  '' '' 10.
  data_alv  'NO_EXCMESS_06' '例外组6'  '' '' 10.
  data_alv  'NO_EXCMESS_07' '例外组7'  '' '' 10.
  data_alv  'NO_EXCMESS_08' '例外组8'  '' '' 10.
  data_alv  'ABC_ID'        'ABC标识'  '' '' 10.
  data_alv  'REQDAYSSUPPLY2'  '第二接货日的供货'  '' '' 10.

  data_alv  'ICON_TEXT'           '图标的承运商字段'  '' '' 100.

*  wa_layout-box_fname         = 'BOX'.
  wa_layout-grid_title        = sy-title.
  wa_layout-cwidth_opt        = 'X'.
  wa_layout-zebra             = 'X'.
*  wa_layout-info_fname        = 'COLOR'.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
    EXPORTING
      i_callback_program = sy-repid
      i_save             = 'A'
      is_layout_lvc      = wa_layout
      it_fieldcat_lvc    = lt_fieldcat
*     I_CALLBACK_PF_STATUS_SET = 'FRM_SET_STATUS'
    TABLES
      t_outtab           = gt_alv
    EXCEPTIONS
      program_error      = 1
      OTHERS             = 2.

ENDFORM.                    " FRM_DISPLAY_DATA
*&---------------------------------------------------------------------*
*&      Form  frm_set_status
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->RT_EXTAB   text
*----------------------------------------------------------------------*
FORM frm_set_status USING rt_extab TYPE slis_t_extab.
  SET PF-STATUS 'STANDARD' ."EXCLUDING rt_extab.  BCALV_TEST_FULLSCREEN SAPLBSPL GRID_FULLSCREEN
ENDFORM.                    "build status
*&---------------------------------------------------------------------*
*&      Form  FRM_END_OF_TASK
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM frm_end_of_task USING g_taskname.

  DATA:
    lt_mrp_total_lines LIKE TABLE OF  bapi_mrp_total_lines,
    ls_mrp_total_lines TYPE bapi_mrp_total_lines,
*    ls_mrp_stock_detail TYPE  bapi_mrp_stock_detail,
    ls_return          TYPE bapiret2,
    lt_mrp_ind_lines   TYPE TABLE OF bapi_mrp_ind_lines,
    ls_mrp_list        TYPE bapi_mrp_list,
    ls_mrp_ind_lines   TYPE bapi_mrp_ind_lines,

    l_erdat            TYPE erdat,
    l_erzet            TYPE erzet.

  l_erdat = sy-datum.
  l_erzet = sy-uzeit.

  REFRESH:lt_mrp_total_lines[].

  gv_rcv_jobs = gv_rcv_jobs + 1.

  RECEIVE RESULTS FROM FUNCTION 'BAPI_MATERIAL_STOCK_REQ_LIST'
          IMPORTING
            mrp_list              = ls_mrp_list
            return                = ls_return
          TABLES
            mrp_ind_lines         = lt_mrp_ind_lines
          EXCEPTIONS
            resource_failure      = 1
            system_failure        = 2
            communication_failure = 3.

  IF sy-subrc NE 0.
  ENDIF.

  LOOP AT lt_mrp_ind_lines INTO ls_mrp_ind_lines WHERE avail_date IN s_dat00
                                                   AND excmessage IN s_auskt.

    IF p_plumi IS NOT INITIAL AND ls_mrp_ind_lines-plus_minus NE p_plumi.
      CONTINUE.
    ENDIF.

    CLEAR gs_alv.
    MOVE-CORRESPONDING ls_mrp_ind_lines TO gs_alv.
    MOVE-CORRESPONDING ls_mrp_list      TO gs_alv.

    CLEAR gs_task.
    READ TABLE gt_task INTO gs_task WITH KEY taskname = g_taskname BINARY SEARCH.
    gs_alv-matnr = gs_task-matnr.
    gs_alv-werks = gs_task-werks.
    gs_alv-berid = gs_task-berid.

    CLEAR ls_bapimatdoa.
*    CALL FUNCTION 'BAPI_MATERIAL_GET_DETAIL'
*      EXPORTING
*        material              = gs_alv-matnr
*      IMPORTING
*        material_general_data = ls_bapimatdoa.
*
*    gs_alv-maktx = ls_bapimatdoa-matl_desc.
    CLEAR:gs_maktx.
    READ TABLE gt_maktx INTO gs_maktx WITH KEY matnr = gs_alv-matnr BINARY SEARCH.
    IF sy-subrc = 0.
      gs_alv-maktx = gs_maktx-maktx.
    ENDIF.
    CALL FUNCTION 'CONVERSION_EXIT_MATN1_OUTPUT'
      EXPORTING
        input  = gs_alv-matnr
      IMPORTING
        output = gs_alv-matnr.

    APPEND gs_alv TO gt_alv.
    CLEAR gs_alv.
  ENDLOOP.

  LOOP AT gt_task INTO gs_task WHERE taskname = g_taskname.
    gs_task-flag = 'X'.
    MODIFY gt_task FROM gs_task .
  ENDLOOP.

ENDFORM.
