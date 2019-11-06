USE [IESDB]
GO
/****** Object:  StoredProcedure [dbo].[sp_OmsSchetLoad_3_1_1_285]    Script Date: 06.11.2019 15:28:19 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:  (C) Vitacard System 2011-2014
--              Шатков В.А., Филатов В.В.
-- Create date: 2011-12-02
-- Description: Загрузка счет-реестра ОМС
-- =============================================

ALTER PROCEDURE [dbo].[sp_OmsSchetLoad_3_1_1_285]
  @SchetID uniqueidentifier
 ,@xml xml
 ,@type int
 ,@Worker uniqueidentifier 
AS 
BEGIN 

-----------------[IES].T_SCHET---------------------------
SELECT
   T.c.value('./ZGLV[1]/VERSION[1]', 'varchar(5)') AS [VERSION]
 , T.c.value('./ZGLV[1]/DATA[1]', 'datetime') AS [DATA]
 , T.c.value('./ZGLV[1]/FILENAME[1]', 'varchar(26)') AS [FILENAME]
 , T.c.value('./ZGLV[1]/SD_Z[1]', 'int') AS [SD_Z]
 , T.c.value('./SCHET[1]/CODE[1]', 'varchar(8)') AS [CODE]
 , T.c.value('./SCHET[1]/CODE_MO[1]', 'varchar(6)') AS [CODE_MO]
 , T.c.value('./SCHET[1]/YEAR[1]', 'int') AS [YEAR]
 , T.c.value('./SCHET[1]/MONTH[1]', 'int') AS [MONTH]
 , T.c.value('./SCHET[1]/NSCHET[1]', 'varchar(15)') AS [NSCHET]
 , T.c.value('./SCHET[1]/DSCHET[1]', 'datetime') AS [DSCHET]
 , T.c.value('./SCHET[1]/PLAT[1]', 'varchar(5)') AS [PLAT]
 , T.c.value('./SCHET[1]/SUMMAV[1]', 'decimal(15,2)') AS [SUMMAV]
 , T.c.value('./SCHET[1]/COMENTS[1]', 'varchar(250)') AS [COMENTS]
 , T.c.value('./SCHET[1]/SUMMAP[1]', 'decimal(15,2)') AS [SUMMAP]
 , T.c.value('./SCHET[1]/SANK_MEK[1]', 'decimal(15,2)') AS [SANK_MEK]
 , T.c.value('./SCHET[1]/SANK_MEE[1]', 'decimal(15,2)') AS [SANK_MEE]
 , T.c.value('./SCHET[1]/SANK_EKMP[1]', 'decimal(15,2)') AS [SANK_EKMP]
 , T.c.value('./SCHET[1]/DISP[1]', 'varchar(3)') AS [DISP]
 , CAST(CAST(CAST(GETDATE() as float) as INT) as datetime) as [ReceivedDate]
 , GETDATE() as [ReceivedTime]
 into #SCHET
 FROM @xml.nodes('/ZL_LIST') T(c)

  
SELECT NEWID() AS [SchetZapID]
 ,T.c.value('./N_ZAP[1]', 'int') AS [N_ZAP]
 ,T.c.value('./PR_NOV[1]', 'int') AS [PR_NOV]
 ,T.c.value('./PACIENT[1]/ID_PAC[1]', 'varchar(36)') AS [ID_PAC]
 ,T.c.value('./PACIENT[1]/VPOLIS[1]', 'int') AS [VPOLIS]
 ,T.c.value('./PACIENT[1]/SPOLIS[1]', 'varchar(10)') AS [SPOLIS]
 ,T.c.value('./PACIENT[1]/NPOLIS[1]', 'varchar(20)') AS [NPOLIS] 
 ,T.c.value('./PACIENT[1]/ST_OKATO[1]', 'varchar(5)') AS [ST_OKATO]
 ,T.c.value('./PACIENT[1]/SMO[1]', 'varchar(5)') AS [SMO]
 ,T.c.value('./PACIENT[1]/SMO_OGRN[1]', 'varchar(15)') AS [SMO_OGRN]
 ,T.c.value('./PACIENT[1]/SMO_OK[1]', 'varchar(5)') AS [SMO_OK]
 ,T.c.value('./PACIENT[1]/SMO_NAM[1]', 'varchar(100)') AS [SMO_NAM]
 ,T.c.value('./PACIENT[1]/INV[1]', 'int') AS [INV]
 ,T.c.value('./PACIENT[1]/MSE[1]', 'int') AS [MSE]
 ,T.c.value('./PACIENT[1]/LPU_P[1]', 'varchar(6)') AS [LPU_P]	--!!
 ,T.c.value('./PACIENT[1]/NOVOR[1]', 'varchar(9)') AS [NOVOR]
 ,T.c.value('./PACIENT[1]/VNOV_D[1]', 'int') AS [VNOV_D]
 ,T.c.value('./PACIENT[1]/ENP[1]', 'varchar(16)') AS [ENP]	--!!
 ,T.c.value('./PACIENT[1]/INVAL[1]', 'int') AS [INVAL]	--!!
INTO #TEMP_ZAP
FROM @xml.nodes('/ZL_LIST/ZAP') T(c)

SELECT NEWID() AS [SchetSluchAccomplishedID]
 ,T.c.value('../N_ZAP[1]', 'int') AS [N_ZAP]
 ,T.c.value('./IDCASE[1]', 'varchar(12)') AS [IDCASE]
 ,T.c.value('./USL_OK[1]', 'int') AS [USL_OK]
 ,T.c.value('./VIDPOM[1]', 'int') AS [VIDPOM]
 ,T.c.value('./FOR_POM[1]', 'int') AS [FOR_POM]
 ,T.c.value('./NPR_MO[1]', 'varchar(6)') AS [NPR_MO]
 ,CASE WHEN LEN(T.c.value('./NPR_DATE[1]', 'varchar(20)'))>8 THEN T.c.value('./NPR_DATE[1]', 'datetime') ELSE NULL END AS [NPR_DATE]
 ,T.c.value('./P_DISP2[1]', 'int') AS [P_DISP2]	--!! excess
 ,T.c.value('./LPU[1]', 'varchar(6)') AS [LPU]
 ,T.c.value('./VBR[1]', 'int') AS [VBR]
 ,CASE WHEN LEN(T.c.value('./DATE_Z_1[1]', 'varchar(20)'))>8 THEN T.c.value('./DATE_Z_1[1]', 'datetime') ELSE NULL END AS [DATE_Z_1]
 ,CASE WHEN LEN(T.c.value('./DATE_Z_2[1]', 'varchar(20)'))>8 THEN T.c.value('./DATE_Z_2[1]', 'datetime') ELSE NULL END  AS [DATE_Z_2]
 ,T.c.value('./P_OTK[1]', 'int') AS [P_OTK]
 ,T.c.value('./RSLT_D[1]', 'int') AS [RSLT_D]
 ,T.c.value('./KD_Z[1]', 'int') AS [KD_Z]
 ,T.c.value('./VNOV_M[1]', 'int') AS [VNOV_M]
 ,T.c.value('./RSLT[1]', 'int') AS [RSLT]
 ,T.c.value('./ISHOD[1]', 'int') AS [ISHOD]
 ,T.c.value('./OS_SLUCH[1]', 'varchar(10)') AS [OS_SLUCH]
 ,T.c.value('./VB_P[1]', 'int') AS [VB_P]
 ,T.c.value('./IDSP[1]', 'int') AS [IDSP]
 ,T.c.value('./SUMV[1]', 'decimal(15,2)') AS [SUMV]
 ,T.c.value('./OPLATA[1]', 'int') AS [OPLATA]
 ,T.c.value('./SUMP[1]', 'decimal(15,2)') AS [SUMP]
 ,T.c.value('./SANK_IT[1]', 'decimal(15,2)') AS [SANK_IT]
INTO #TEMP_Z_SLUCH
FROM @xml.nodes('/ZL_LIST/ZAP/Z_SL') T(c)

SELECT NEWID() AS [SchetSluchID] 
 ,T.c.value('../../N_ZAP[1]', 'int') AS [N_ZAP]
 ,T.c.value('../IDCASE[1]', 'varchar(12)') AS [IDCASE]
 ,T.c.value('./SL_ID[1]', 'varchar(36)') as [SL_ID]
 ,T.c.value('./VID_HMP[1]', 'varchar(12)') AS [VID_HMP]	--T
 ,T.c.value('./METOD_HMP[1]', 'int') AS [METOD_HMP]	--T
 ,T.c.value('./LPU_1[1]', 'varchar(8)') AS [LPU_1]
 ,T.c.value('./PODR[1]', 'varchar(12)') AS [PODR]
 ,T.c.value('./PROFIL[1]', 'int') AS [PROFIL]
 ,T.c.value('./PROFIL_K[1]', 'int') AS [PROFIL_K]
 ,T.c.value('./DET[1]', 'int') AS [DET]
 ,CASE WHEN LEN(T.c.value('./TAL_D[1]', 'varchar(20)'))>8 THEN T.c.value('./TAL_D[1]', 'datetime') ELSE NULL END AS [TAL_D]		--T
 ,T.c.value('./TAL_NUM[1]', 'varchar(20)') AS [TAL_NUM]		--T
 ,CASE WHEN LEN(T.c.value('./TAL_P[1]', 'varchar(20)'))>8 THEN T.c.value('./TAL_P[1]', 'datetime') ELSE NULL END AS [TAL_P] 	--T
 ,T.c.value('./P_CEL[1]', 'varchar(3)') as [P_CEL]
 ,T.c.value('./NHISTORY[1]', 'varchar(50)') AS [NHISTORY]
 ,T.c.value('./P_PER[1]', 'int') AS [P_PER]
 ,CASE WHEN LEN(T.c.value('./DATE_1[1]', 'varchar(20)'))>8 THEN T.c.value('./DATE_1[1]', 'datetime') ELSE NULL END AS [DATE_1]
 ,CASE WHEN LEN(T.c.value('./DATE_2[1]', 'varchar(20)'))>8 THEN T.c.value('./DATE_2[1]', 'datetime') ELSE NULL END  AS [DATE_2]
 ,T.c.value('./KD[1]', 'int') AS [KD]
 ,T.c.value('./DS0[1]', 'varchar(10)') AS [DS0]
 ,T.c.value('./DS1[1]', 'varchar(10)') AS [DS1]
 ,T.c.value('./DS1_PR[1]', 'int') AS [DS1_PR]
 ,T.c.value('./PR_D_N[1]', 'int') AS [PR_D_N]
 ,T.c.value('./C_ZAB[1]', 'int') AS [C_ZAB]
 ,T.c.value('./DN[1]', 'int') AS [DN]
 ,T.c.value('./CODE_MES1[1]', 'varchar(16)') AS [CODE_MES1]
 ,T.c.value('./CODE_MES2[1]', 'varchar(16)') AS [CODE_MES2]
 ,T.c.value('./REAB[1]', 'int') AS [REAB]
 ,T.c.value('./PARA[1]', 'int') AS [PARA]	--!!
 ,T.c.value('./PRVS[1]', 'int') AS [PRVS]
 ,T.c.value('./VERS_SPEC[1]', 'varchar(4)') AS [VERS_SPEC]
 ,T.c.value('./IDDOKT[1]', 'varchar(16)') AS [IDDOKT]
 ,T.c.value('./ED_COL[1]', 'decimal(5,2)') AS [ED_COL]
 ,T.c.value('./TARIF[1]', 'decimal(15,2)') AS [TARIF]
 ,T.c.value('./SUM_M[1]', 'decimal(15,2)') AS [SUM_M]
 ,T.c.value('./DISP[1]', 'int') as [DISP]	--!!
 ,T.c.value('./COMENTSL[1]', 'varchar(250)') AS [COMENTSL]
 ,T.c.value('./EXTR[1]', 'int') AS [EXTR]	--!! reg?
 ,T.c.value('./TYPE_DISP[1]', 'varchar(2)') AS [TYPE_DISP]	--!! reg?
 ,T.c.value('./DOP_KL_KR[1]', 'varchar(7)') as [DOP_KL_KR]
 ,T.c.value('./DS_ONK[1]', 'int') as [DS_ONK]

INTO #TEMP_SLUCH
FROM @xml.nodes('/ZL_LIST/ZAP/Z_SL/SL') T(c)

SELECT 
 newid() AS [SchetUslID]
,T.c.value('../../IDCASE[1]', 'varchar(12)') AS [IDCASE]
,T.c.value('../SL_ID[1]', 'varchar(36)') AS [SL_ID] 
,T.c.value('./IDSERV[1]', 'varchar(36)') AS [IDSERV]
,T.c.value('./LPU[1]', 'varchar(6)') AS [LPU]
,T.c.value('./LPU_1[1]', 'varchar(8)') AS [LPU_1]
,T.c.value('./PODR[1]', 'varchar(12)') AS [PODR]
,T.c.value('./PROFIL[1]', 'int') AS [PROFIL]
,T.c.value('./VID_VME[1]', 'varchar(15)') AS [VID_VME]
,T.c.value('./DET[1]', 'int') AS [DET]
,CASE WHEN LEN(T.c.value('./DATE_IN[1]', 'varchar(20)'))>8 THEN T.c.value('./DATE_IN[1]', 'datetime') ELSE NULL END   AS [DATE_IN]
,CASE WHEN LEN(T.c.value('./DATE_OUT[1]', 'varchar(20)'))>8 THEN T.c.value('./DATE_OUT[1]', 'datetime') ELSE NULL END   AS [DATE_OUT]
,T.c.value('./P_OTK[1]', 'int') AS [P_OTK]
,T.c.value('./DS[1]', 'varchar(10)') AS [DS]
,T.c.value('./CODE_USL[1]', 'varchar(20)') AS [CODE_USL]
,T.c.value('./IDSP[1]', 'int') AS [IDSP]	--!!
,T.c.value('./PARA_N[1]', 'int') AS [PARA_N]	--!!
,T.c.value('./USL[1]', 'varchar(254)') AS [USL]	--!! reg? 404 not founded
,T.c.value('./KOL_USL[1]', 'decimal(6,2)') AS [KOL_USL]
,T.c.value('./TARIF[1]', 'decimal(15,2)') AS [TARIF]
,T.c.value('./SUMV_USL[1]', 'decimal(15,2)') AS [SUMV_USL]
,T.c.value('./PRVS[1]', 'int') AS [PRVS]
,T.c.value('./CODE_MD[1]', 'varchar(16)') AS [CODE_MD]
,T.c.value('./NPL[1]', 'int') AS [NPL]
,T.c.value('./DENT[1]', 'int') AS [DENT]	--!! reg?
,T.c.value('./COMENTU[1]', 'varchar(250)') AS [COMENTU]
INTO #SCHET_USL
FROM   @xml.nodes('/ZL_LIST/ZAP/Z_SL/SL/USL') T(c)

SELECT NEWID() as [KsgID]
    ,T.c.value('../../IDCASE[1]', 'varchar(12)') AS [IDCASE]
	,T.c.value('../SL_ID[1]', 'varchar(36)') AS [SL_ID] 
	,T.c.value('./N_KSG[1]', 'varchar(20)') as [N_KSG]
	,T.c.value('./VER_KSG[1]', 'varchar(4)') as [VER_KSG]
	,T.c.value('./KSG_PG[1]', 'int') as [KSG_PG]
	,T.c.value('./N_KPG[1]', 'varchar(4)') as [N_KPG]
	,T.c.value('./KOEF_Z[1]', 'decimal(7,5)') as [KOEF_Z]
	,T.c.value('./KOEF_UP[1]', 'decimal(7,5)') as [KOEF_UP]
	,T.c.value('./BZTSZ[1]', 'decimal(8,2)') as [BZTSZ]
	,T.c.value('./KOEF_D[1]', 'decimal(7,5)') as [KOEF_D]
	,T.c.value('./KOEF_U[1]', 'decimal(7,5)') as [KOEF_U]
	,T.c.value('./DKK1[1]', 'varchar(10)') as [DKK1]
	,T.c.value('./DKK2[1]', 'varchar(10)') as [DKK2]
	,T.c.value('./SL_K[1]', 'int') as [SL_K]
	,T.c.value('./IT_SL[1]', 'decimal(6,5)') as [IT_SL]
	--,T.c.value('./CRIT[1]', 'varchar(10)') as [CRIT] --new
INTO #SCHET_KSG
FROM   @xml.nodes('/ZL_LIST/ZAP/Z_SL/SL/KSG_KPG') T(c)

SELECT 
     T.c.value('../../../IDCASE[1]', 'varchar(12)') AS [IDCASE]
	,T.c.value('../../SL_ID[1]', 'varchar(36)') AS [SL_ID] 
	,T.c.value('.', 'varchar(10)') as [CRIT]
INTO #SCHET_KSG_CRIT
FROM   @xml.nodes('/ZL_LIST/ZAP/Z_SL/SL/KSG_KPG/CRIT') T(c)

SELECT NEWID() as [KslpID]
    ,T.c.value('../../../IDCASE[1]', 'varchar(12)') AS [IDCASE]
	,T.c.value('../../SL_ID[1]', 'varchar(36)') AS [SL_ID] 
	,T.c.value('../N_KSG[1]', 'varchar(20)') as [N_KSG]
	,T.c.value('./IDSL[1]', 'int') as [IDSL]
	,T.c.value('./Z_SL[1]', 'decimal(6,5)') as [Z_SL]
INTO #SCHET_KSG_KOEF
FROM   @xml.nodes('/ZL_LIST/ZAP/Z_SL/SL/KSG_KPG/SL_KOEF') T(c)

SELECT
  T.c.value('../../IDCASE[1]', 'varchar(12)') AS [IDCASE]
 ,T.c.value('../SL_ID[1]', 'varchar(36)') AS [SL_ID] 
 ,T.c.value('.', 'varchar(10)') AS [DS]
 , cast(null as int) as [DS2_PR]
 , cast(null as int) as [PR_DS2_N]
 ,0 AS DS_TYPE
 INTO #TEMP_DS
FROM   @xml.nodes('/ZL_LIST/ZAP/Z_SL/SL/DS2') T(c)

SELECT
  T.c.value('../../IDCASE[1]', 'varchar(12)') AS [IDCASE]
 ,T.c.value('../SL_ID[1]', 'varchar(36)') AS [SL_ID] 
 ,T.c.value('./PR_CONS[1]', 'int') AS [PR_CONS]
 ,T.c.value('./DT_CONS[1]', 'datetime') AS [DT_CONS]
 INTO #TEMP_SLUCH_CONS
FROM   @xml.nodes('/ZL_LIST/ZAP/Z_SL/SL/CONS') T(c)

INSERT INTO #TEMP_DS
SELECT
  T.c.value('../../IDCASE[1]', 'varchar(12)') AS [IDCASE]
 ,T.c.value('../SL_ID[1]', 'varchar(36)') AS [SL_ID] 
 ,T.c.value('./DS2[1]', 'varchar(10)') AS [DS]
 ,T.c.value('./DS2_PR[1]', 'int') AS [DS2_PR]
 ,T.c.value('./PR_DS2_N[1]', 'int') AS [PR_DS2_N]
 ,0 AS DS_TYPE
FROM   @xml.nodes('/ZL_LIST/ZAP/Z_SL/SL/DS2_N') T(c)

INSERT INTO #TEMP_DS
SELECT
  T.c.value('../../IDCASE[1]', 'varchar(12)') AS [IDCASE]
 ,T.c.value('../SL_ID[1]', 'varchar(36)') AS [SL_ID] 
 ,T.c.value('.', 'varchar(10)') AS [DS]
 , cast(null as int) as [DS2_PR]
 ,T.c.value('./PR_DS2_N[1]', 'int') AS [PR_DS2_N]
 ,1 AS DS_TYPE
FROM   @xml.nodes('/ZL_LIST/ZAP/Z_SL/SL/DS3') T(c)

SELECT
  T.c.value('../../IDCASE[1]', 'varchar(12)') AS [IDCASE]
 ,T.c.value('../SL_ID[1]', 'varchar(36)') AS [SL_ID] 
 ,T.c.value('./NAZ_N[1]', 'int') AS [NAZ_N]
 ,T.c.value('./NAZ_R[1]', 'int') AS [NAZ_R]
 ,T.c.value('./NAZ_SP[1]', 'int') AS [NAZ_SP]
 ,T.c.value('./NAZ_V[1]', 'int') AS [NAZ_V]
 ,T.c.value('./NAZ_PMP[1]', 'int') AS [NAZ_PMP]
 ,T.c.value('./NAZ_PK[1]', 'int') AS [NAZ_PK]
 ,T.c.value('./NAZ_USL[1]', 'varchar(15)') AS [NAZ_USL]
 ,T.c.value('./NAPR_DATE[1]', 'datetime') AS [NAPR_DATE]
 ,T.c.value('./NAPR_MO[1]', 'varchar(6)') AS [NAPR_MO]
 INTO #TEMP_SL_NAZ
FROM   @xml.nodes('/ZL_LIST/ZAP/Z_SL/SL/NAZ') T(c)

SELECT 
  newid() as [SchetSluchSankID]
 ,T.c.value('../IDCASE[1]', 'varchar(12)') AS [IDCASE]
 ,T.c.value('./S_CODE[1]', 'varchar(36)') AS [S_CODE]
 ,T.c.value('./S_SUM[1]', 'decimal(15,2)') AS [S_SUM]
 ,T.c.value('./S_TIP[1]', 'int') AS [S_TIP]
 ,T.c.value('./S_OSN[1]', 'int') AS [S_OSN]
 ,CASE WHEN LEN(T.c.value('./DATE_ACT[1]', 'varchar(20)'))>8 THEN T.c.value('./DATE_ACT[1]', 'datetime') ELSE NULL END   AS [DATE_ACT]
 ,T.c.value('./NUM_ACT[1]', 'varchar(30)') as [NUM_ACT]
 ,T.c.value('./S_COM[1]', 'varchar(250)') AS [S_COM]
 ,T.c.value('./S_IST[1]', 'int') AS [S_IST]
 ,T.c.value('./SL_ID[1]', 'varchar(36)') AS [SL_ID] -- new
 INTO #TEMP_SANK
FROM   @xml.nodes('/ZL_LIST/ZAP/Z_SL/SANK') T(c)

SELECT 
  newid() as [SchetSluchSankID]
 ,T.c.value('../../IDCASE[1]', 'varchar(12)') AS [IDCASE]
 ,T.c.value('../S_CODE[1]', 'varchar(36)') AS [S_CODE]
 ,T.c.value('.', 'varchar(36)') AS [SL_ID] -- new
 ,T.c.value('../S_SUM[1]', 'decimal(15,2)') AS [S_SUM]
 INTO #TEMP_SANK_SL
FROM   @xml.nodes('/ZL_LIST/ZAP/Z_SL/SANK/SL_ID') T(c)

SELECT 
	T.c.value('../../IDCASE[1]', 'varchar(12)') AS [IDCASE]
	,T.c.value('../S_CODE[1]', 'varchar(36)') AS [S_CODE]
	,T.c.value('.', 'varchar(8)') as [CODE_EXP]
INTO #TEMP_SANK_EXP
FROM @xml.nodes('/ZL_LIST/ZAP/Z_SL/SANK/CODE_EXP') T(c)


SELECT 
NEWID() as [SchetSluchOnkID],
T.c.value('../../IDCASE[1]', 'varchar(12)') AS [IDCASE]
,T.c.value('../SL_ID[1]', 'varchar(36)') AS [SL_ID] 
,T.c.value('./DS1_T[1]', 'int') AS [DS1_T]
,T.c.value('./STAD[1]', 'int') AS [STAD]
,T.c.value('./ONK_T[1]', 'int') AS [ONK_T]
,T.c.value('./ONK_N[1]', 'int') AS [ONK_N]
,T.c.value('./ONK_M[1]', 'int') AS [ONK_M]
,T.c.value('./MTSTZ[1]', 'int') AS [MTSTZ]
,T.c.value('./SOD[1]', 'decimal (5,2)') AS [SOD] 
,T.c.value('./K_FR[1]', 'int') AS [K_FR]-- new
  ,T.c.value('./WEI[1]', 'decimal (4,1)') AS [WEI]-- new
  ,T.c.value('./HEI[1]', 'int') AS [HEI]-- new
  ,T.c.value('./BSA[1]', 'decimal (3,2)') AS [BSA]-- new
 INTO #SCHET_SLUCH_ONK 
FROM   @xml.nodes('/ZL_LIST/ZAP/Z_SL/SL/ONK_SL') T(c)



SELECT 
NEWID() as [SchetSluchOnkDiagID],
T.c.value('../../../IDCASE[1]', 'varchar(12)') AS [IDCASE]
,T.c.value('../../SL_ID[1]', 'varchar(36)') AS [SL_ID] 
,T.c.value('./DIAG_DATE[1]', 'datetime') AS [DIAG_DATE]
,T.c.value('./DIAG_TIP[1]', 'int') AS [DIAG_TIP]
,T.c.value('./DIAG_CODE[1]', 'int') AS [DIAG_CODE]
,T.c.value('./DIAG_RSLT[1]', 'int') AS [DIAG_RSLT]
,T.c.value('./REC_RSLT[1]', 'int') AS [REC_RSLT]

 INTO #SCHET_SLUCH_ONK_DIAG
FROM   @xml.nodes('/ZL_LIST/ZAP/Z_SL/SL/ONK_SL/B_DIAG') T(c)


SELECT 
NEWID() as [SchetSluchOnkProtID],
T.c.value('../../../IDCASE[1]', 'varchar(12)') AS [IDCASE]
,T.c.value('../../SL_ID[1]', 'varchar(36)') AS [SL_ID] 
  ,T.c.value('./PROT[1]', 'int') AS [PROT]
 ,T.c.value('./D_PROT[1]', 'datetime') AS [D_PROT]

 INTO #SCHET_SLUCH_ONK_B_PROT
FROM   @xml.nodes('/ZL_LIST/ZAP/Z_SL/SL/ONK_SL/B_PROT') T(c)

--она переехала с услуг, на случай!!!
SELECT 
NEWID() as [SchetUslNaprID],
T.c.value('../../IDCASE[1]', 'varchar(12)') AS [IDCASE]
,T.c.value('../SL_ID[1]', 'varchar(36)') AS [SL_ID] 
,T.c.value('./NAPR_DATE[1]', 'datetime') AS [NAPR_DATE] 
,T.c.value('./NAPR_MO[1]', 'varchar(6)') AS [NAPR_MO]
,T.c.value('./NAPR_V[1]', 'int') AS [NAPR_V] 
,T.c.value('./MET_ISSL[1]', 'int') AS [MET_ISSL]
,T.c.value('./NAPR_USL[1]', 'varchar(15)') AS [NAPR_USL]
 INTO #SCHET_USL_NAPR
FROM   @xml.nodes('/ZL_LIST/ZAP/Z_SL/SL/NAPR')  T(c)

--она переехала с услуг, на случай онкологии!!!
SELECT 
NEWID() as [SchetUslOnkID],
T.c.value('../../../IDCASE[1]', 'varchar(12)') AS [IDCASE]
,T.c.value('../../SL_ID[1]', 'varchar(36)') AS [SL_ID] 
,T.c.value('./PR_CONS[1]', 'int') AS [PR_CONS] 
,T.c.value('./USL_TIP[1]', 'int') AS [USL_TIP] 
,T.c.value('./HIR_TIP[1]', 'int') AS [HIR_TIP] 
,T.c.value('./LEK_TIP_L[1]', 'int') AS [LEK_TIP_L] 
,T.c.value('./LEK_TIP_V[1]', 'int') AS [LEK_TIP_V] 
,T.c.value('./LUCH_TIP[1]', 'int') AS [LUCH_TIP] 
,T.c.value('./PPTR[1]', 'int') AS [PPTR]-- new
 INTO #SCHET_USL_ONK
FROM   @xml.nodes('/ZL_LIST/ZAP/Z_SL/SL/ONK_SL/ONK_USL')  T(c)

SELECT
	 newid() as [LekPrID]	
	,T.c.value('../../../../IDCASE[1]', 'varchar(12)') AS [IDCASE]
	,T.c.value('../../../SL_ID[1]', 'varchar(36)') AS [SL_ID] 
	,T.c.value('./REGNUM[1]', 'varchar(40)') as [REGNUM]
	,T.c.value('./CODE_SH[1]', 'varchar(10)') as [CODE_SH]
INTO #SCHET_USL_ONK_LEK_PR
FROM   @xml.nodes('/ZL_LIST/ZAP/Z_SL/SL/ONK_SL/ONK_USL/LEK_PR')  T(c)

SELECT	
	 T.c.value('../../../../../IDCASE[1]', 'varchar(12)') AS [IDCASE]
	,T.c.value('../../../../SL_ID[1]', 'varchar(36)') AS [SL_ID] 
	,T.c.value('.', 'datetime') as [DATE_INJ]
	,T.c.value('../REGNUM[1]', 'varchar(10)') as [REGNUM]
	,T.c.value('../CODE_SH[1]', 'varchar(10)') as [CODE_SH]
INTO #SCHET_USL_ONK_LEK_PR_DATE
FROM   @xml.nodes('/ZL_LIST/ZAP/Z_SL/SL/ONK_SL/ONK_USL/LEK_PR/DATE_INJ')  T(c)
----------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------
-- ФЛК второго уровня, проверка зависимостей невозможная с помощью XSD
declare @ActualDate datetime = (select [DSCHET] from #Schet)
create table #Errors
(
	IM_POL varchar(20),
	BAS_EL varchar(20),
	N_ZAP varchar(20),
	IDCASE varchar(20),
	SL_ID varchar(36),
	IDSERV varchar(36),
	OSHIB int,
	COMMENT varchar(500)
)


--=========================================================================
-- -=НАЧАЛО= Блок проверок по МТР от ЛПУ и Счетов от СМО.
--=========================================================================
if @type = 693 --in (693,554,562) 
BEGIN
 -- 147 Проверка правильности заполнения PR_NOV=0
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
  select 'PR_NOV', 'ZAP', zs.N_ZAP, zs.IDCASE, null, '904', 'Для основной записи PR_NOV="0" в базе уже есть оплаченная запись пераданная ранее (IDCASE="'+cast(zs.IDCASE as varchar)
 +'" LPU="'+isnull(zs.lpu,'')+'" USL_OK="'+isnull(cast(zs.USL_OK as varchar),'')+'" DATE_Z_1="'+format(zs.DATE_Z_1, 'dd.MM.yyyy')+'" DATE_Z_2="'+format(zs.DATE_Z_2, 'dd.MM.yyyy')
 +' переданная в счете CODE="'+cast(t2.CODE as varchar)+ '" NSCHET="'+t2.NSCHET+'" DSCHET="'+format(t2.DSCHET, 'dd.MM.yyyy')+'"'
  from #TEMP_Z_SLUCH zs
  inner join #TEMP_ZAP z on zs.N_ZAP=z.N_ZAP
  inner join #SCHET s on s.PLAT in ('40001','40002')
  inner join (select sc.CODE, sc.NSCHET, sc.DSCHET, sc.plat, bzs.IDCASE, bzs.lpu, bzs.USL_OK, bzs.DATE_Z_1, bzs.DATE_Z_2 from [IES].[T_SCHET_SLUCH_ACCOMPLISHED] bzs
  inner join [IES].[T_SCHET_ZAP] bz on  bzs.SchetZap=bz.SchetZapID
  inner join [IES].[T_SCHET] sc on bz.Schet=sc.SchetID  and sc.IsDelete=0  and sc.type_ = @type) t2
   on s.plat=t2.plat and zs.IDCASE=t2.IDCASE and zs.lpu=t2.lpu and zs.USL_OK=t2.USL_OK and zs.DATE_Z_1=t2.DATE_Z_1 and zs.DATE_Z_2=t2.DATE_Z_2 
 where z.PR_NOV = 0 and zs.OPLATA = 1

 -- 148 Проверка правильности заполнения PR_NOV=1
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PR_NOV', 'ZAP', zs.N_ZAP, zs.IDCASE, null, '904', 'Для исправленной записи PR_NOV="1" в базе нет отказанной первичной записи (IDCASE="'+cast(zs.IDCASE as varchar)
 +'" LPU="'+isnull(zs.lpu,'')+'" USL_OK="'+isnull(cast(zs.USL_OK as varchar),'')+'" DATE_Z_1="'+format(zs.DATE_Z_1, 'dd.MM.yyyy')+'" DATE_Z_2="'+format(zs.DATE_Z_2, 'dd.MM.yyyy')+'")'
 from #TEMP_Z_SLUCH zs
  inner join #TEMP_ZAP z on zs.N_ZAP=z.N_ZAP
  inner join #SCHET s on s.PLAT in ('40001','40002')
where not exists(select top 1 bzs.IDCASE from [IES].[T_SCHET_SLUCH_ACCOMPLISHED] bzs
  inner join [IES].[T_SCHET_ZAP] bz on  bzs.SchetZap=bz.SchetZapID
  inner join [IES].[T_SCHET] sc on bz.Schet=sc.SchetID  and sc.IsDelete=0  and sc.type_ in (693,554) 
   where bzs.SUMP=0 and 
   s.plat=sc.plat and zs.IDCASE=bzs.IDCASE and zs.lpu=bzs.lpu and zs.USL_OK=bzs.USL_OK and zs.DATE_Z_1=bzs.DATE_Z_1 and zs.DATE_Z_2=bzs.DATE_Z_2)
 and z.PR_NOV = 1

END

--=========================================================================
-- -=КОНЕЦ= Блок проверок по МТР от ЛПУ и Счетов от СМО.
--=========================================================================


--=========================================================================
-- -=НАЧАЛО= Блок проверок по МТР от ЛПУ добавленных сотрудниками КОФОМС.
--=========================================================================
if @type in (693,554,562) 
BEGIN
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_Z_2', 'Z_SL', ss.N_ZAP, ss.IDCASE, null, '905', 'Случаи лечения ранее 01.01.2019 не могут передаваться в данном формате'
 from #TEMP_Z_SLUCH ss
 where ss.DATE_Z_2 < '01.01.2019'
   and @type in (693,554,562)

-- Проверка №168.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'Z_SL', 'VNOV_M', ss.N_ZAP, ss.IDCASE,  null,  '905', 'Элемент VNOV_M="'+isnull(cast(ss.VNOV_M as varchar),'')+'" имеет не допустимое значение'
 from #TEMP_ZAP z
  join #TEMP_Z_SLUCH ss on ss.n_zap = z.n_zap
 where ss.VNOV_M < 300 or ss.VNOV_M > 2500

-- Проверка №168 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'Z_SL', 'VNOV_M', ss.N_ZAP, ss.IDCASE,  null,  '905', 'Элемент VNOV_M должен отсутствовать при наличии элемента VNOV_D'
 from #TEMP_ZAP z
  join #TEMP_Z_SLUCH ss on ss.n_zap = z.n_zap
 where ss.VNOV_M is not null and z.VNOV_D is not null

-- Проверка №167.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PACIENT', 'VNOV_D', ss.N_ZAP, ss.IDCASE,  null,  '905', 'Элемент VNOV_D="'+isnull(cast(z.VNOV_D as varchar),'')+'" имеет не допустимое значение'
 from #TEMP_ZAP z
  join #TEMP_Z_SLUCH ss on ss.n_zap = z.n_zap
 where z.VNOV_D < 300 or z.VNOV_D > 2500

-- Проверка №167 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PACIENT', 'VNOV_D', ss.N_ZAP, ss.IDCASE,  null,  '905', 'Элемент VNOV_D должен отсутствовать при NOVOR=0 или при наличии элемента VNOV_M'
 from #TEMP_ZAP z
  join #TEMP_Z_SLUCH ss on ss.n_zap = z.n_zap
 where (z.NOVOR=0 or ss.VNOV_M is not null) and z.VNOV_D is not null


-- Проверка №164 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SANK_IT', 'Z_SL', z.N_ZAP, z.IDCASE, null, '905', 'Сумма санкций SANK_IT не равна SUMV-SUMP'
 from #TEMP_Z_SLUCH z
 where isnull(SANK_IT,0) <> SUMV-isnull(SUMP,0)
   and @type in (693)

-- Проверка №160.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SCHET', 'S_OSN', ss.N_ZAP, ss.IDCASE,  null,  '905', 'Обязательно к заполнению в соответствии с F014 (Классификатор причин отказа в оплате медицинской помощи, Приложение А), если S_SUM не равна 0'
 from #TEMP_SANK s
  join #TEMP_Z_SLUCH ss on ss.IDCASE = s.IDCASE 
 where s.S_OSN is null and s.S_SUM <> 0

-- Проверка №160 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'S_TIP', 'SANK', z.N_ZAP, z.IDCASE, null, '905', 'Значение S_OSN="'+isnull(cast(s.S_OSN as varchar),'')+'" не соответствует допустимому значению  в справочнике F014'
 from #TEMP_Z_SLUCH z
  join #TEMP_SANK s on z.IDCASE=s.IDCASE
  LEFT JOIN [IES].T_F014_DENY_REASON f014 on f014.Kod = s.[S_OSN] and  z.DATE_Z_2 between DATEBEG and isnull(DATEEND,z.DATE_Z_2)
 where f014.F014DenyReasonID is null

-- Проверка №159 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'S_TIP', 'SANK', z.N_ZAP, z.IDCASE, null, '905', 'Значение S_TIP="'+isnull(cast(s.S_TIP as varchar),'')+'" не соответствует допустимому значению  в справочнике F006'
 from #TEMP_Z_SLUCH z
  join #TEMP_SANK s on z.IDCASE=s.IDCASE
  LEFT JOIN [IES].[T_F006_CONTROL_TYPE] f006 on f006.S_TIP = s.[S_TIP] and  z.DATE_Z_2 between DATEBEG and isnull(DATEEND,z.DATE_Z_2)
 where f006.S_TIP is null

 -- Проверка №158 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'SPOLIS', 'PACIENT', t.n_zap, z.idcase, null, '904',  'Серия полиса должна быть пустой при VPOLIS="3"' 
       from #TEMP_Z_SLUCH z
	    join #TEMP_ZAP t on z.N_ZAP=t.N_ZAP
      where t.VPOLIS=3 and t.SPOLIS is not null

-- Проверка №157.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'REC_RSLT', 'B_DIAG', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректное значение признака получения результата диагностики REC_RSLT="'+isnull(cast(t2.REC_RSLT as varchar),'')+'".'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK t on (t.IDCASE=zs.IDCASE) 
  join #SCHET_SLUCH_ONK_DIAG t2 on (t.IDCASE=t2.IDCASE and t.SL_ID=t2.SL_ID ) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where isnull(t2.REC_RSLT,1) != 1

-- Проверка №157 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'REC_RSLT', 'B_DIAG', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан признак получения результата диагностики (REC_RSLT).'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK t on (t.IDCASE=zs.IDCASE) 
  join #SCHET_SLUCH_ONK_DIAG t2 on (t.IDCASE=t2.IDCASE and t.SL_ID=t2.SL_ID ) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where isnull(t2.REC_RSLT,0) != 1 and t2.DIAG_RSLT is not null

 
-- Проверка №156.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'BSA', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Площадь тела имеет недопустимое значение BSA="'+isnull(cast(t.BSA as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK t on (t.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
   and (t.BSA > 6) 

-- Проверка №156 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'BSA', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указана площадь поверхности тела  (BSA).'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK t on (t.IDCASE=zs.IDCASE) 
  join #SCHET_KSG t1 on (t.IDCASE=t1.IDCASE and t.SL_ID=t1.SL_ID) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where t1.N_KSG in ('st19.027','st19.028','st19.029','st19.030','st19.031','st19.032','st19.033','st19.034','st19.035','st19.036',
                    'st19.039','st19.040','st19.041','st19.042','st19.043','st19.044','st19.045','st19.046','st19.047','st19.048',
					'st19.049','st19.050','st19.051','st19.052','st19.053','st19.054','st19.055',
					'ds19.001','ds19.002','ds19.003','ds19.004','ds19.005','ds19.006','ds19.007','ds19.008','ds19.009','ds19.010',
					'ds19.011','ds19.012','ds19.013','ds19.014','ds19.015','ds19.018','ds19.019','ds19.020','ds19.021','ds19.022',
					'ds19.023','ds19.024','ds19.025','ds19.026','ds19.027')
   and (t.BSA is null or t.BSA = 0) 
   and exists (select 1 from #SCHET_USL_ONK q1 where (t.IDCASE=q1.IDCASE and t.SL_ID=q1.SL_ID and q1.USL_TIP in (2,4)) )

-- Проверка №155.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'HEI', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Рост тела имеет недопустимое значение HEI="'+isnull(cast(t.HEI as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK t on (t.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
   and (t.HEI < 80 or t.HEI > 260) 

-- Проверка №155 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'HEI', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан рост (HEI).'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK t on (t.IDCASE=zs.IDCASE) 
  join #SCHET_KSG t1 on (t.IDCASE=t1.IDCASE and t.SL_ID=t1.SL_ID) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where t1.N_KSG in ('st19.027','st19.028','st19.029','st19.030','st19.031','st19.032','st19.033','st19.034','st19.035','st19.036',
                    'st19.039','st19.040','st19.041','st19.042','st19.043','st19.044','st19.045','st19.046','st19.047','st19.048',
					'st19.049','st19.050','st19.051','st19.052','st19.053','st19.054','st19.055',
					'ds19.001','ds19.002','ds19.003','ds19.004','ds19.005','ds19.006','ds19.007','ds19.008','ds19.009','ds19.010',
					'ds19.011','ds19.012','ds19.013','ds19.014','ds19.015','ds19.018','ds19.019','ds19.020','ds19.021','ds19.022',
					'ds19.023','ds19.024','ds19.025','ds19.026','ds19.027')
   and (t.HEI is null or t.HEI = 0) 
   and exists (select 1 from #SCHET_USL_ONK q1 where (t.IDCASE=q1.IDCASE and t.SL_ID=q1.SL_ID and q1.USL_TIP in (2,4)) )

-- Проверка №154.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'WEI', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Масса тела имеет недопустимое значение WEI="'+isnull(cast(t.WEI as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK t on (t.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
   and (t.WEI < 5 or t.WEI > 600) 
 


-- Проверка №154 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'WEI', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указана масса тела (WEI).'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK t on (t.IDCASE=zs.IDCASE) 
  join #SCHET_KSG t1 on (t.IDCASE=t1.IDCASE and t.SL_ID=t1.SL_ID) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where t1.N_KSG in ('st19.027','st19.028','st19.029','st19.030','st19.031','st19.032','st19.033','st19.034','st19.035','st19.036',
                    'st19.039','st19.040','st19.041','st19.042','st19.043','st19.044','st19.045','st19.046','st19.047','st19.048',
					'st19.049','st19.050','st19.051','st19.052','st19.053','st19.054','st19.055',
					'ds19.001','ds19.002','ds19.003','ds19.004','ds19.005','ds19.006','ds19.007','ds19.008','ds19.009','ds19.010',
					'ds19.011','ds19.012','ds19.013','ds19.014','ds19.015','ds19.018','ds19.019','ds19.020','ds19.021','ds19.022',
					'ds19.023','ds19.024','ds19.025','ds19.026','ds19.027')
   and (t.WEI is null or t.WEI = 0) 
   and exists (select 1 from #SCHET_USL_ONK q1 where (t.IDCASE=q1.IDCASE and t.SL_ID=q1.SL_ID and q1.USL_TIP in (2,4)) )


-- Проверка №153.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'K_FR', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Для USL_OK="'+isnull(cast(t1.USL_TIP as varchar),'')+'" количество фракций проведенной лучевой терапии (K_FR) должно быть пустым.'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK t on (t.IDCASE=zs.IDCASE) 
  join #SCHET_USL_ONK t1 on (t.IDCASE=t1.IDCASE and t.SL_ID=t1.SL_ID) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where t1.USL_TIP not in (3,4) and t.K_FR is not null

-- Проверка №153 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'K_FR', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указано количество фракций проведенной лучевой терапии (K_FR).'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK t on (t.IDCASE=zs.IDCASE) 
  join #SCHET_USL_ONK t1 on (t.IDCASE=t1.IDCASE and t.SL_ID=t1.SL_ID) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where t1.USL_TIP in (3,4) and t.K_FR is null


-- Проверка №152 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'TARIF', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан тариф по случаю.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where (t.tarif is null or t.tarif=0) and 
  (substring(t.ds1,1,1) = 'C' or t.ds1 between 'D00' and 'D09.99' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS from #TEMP_DS ds where (ds.DS between 'C00' and 'C80.9' or  ds.ds between 'C97' and 'C97.9')))) 
  
/*
-- Проверка №151.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CONS', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Блок CONS должен быть пустым.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  left join #TEMP_SLUCH_CONS t1 on t.IDCASE=t1.IDCASE and t.SL_ID=t1.SL_ID
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where t1.PR_CONS is not null and not (
  (substring(t.ds1,1,1) = 'C' or t.ds1 between 'D00' and 'D09.99' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS from #TEMP_DS ds where (ds.DS between 'C00' and 'C80.9' or  ds.ds between 'C97' and 'C97.9')))) 
  or (t.ds_onk = 1 and SUBSTRING(z.FILENAME,1,1)='T')
  )
*/
-- Проверка №151 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CONS', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не заполнен блок CONS'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  left join #TEMP_SLUCH_CONS t1 on t.IDCASE=t1.IDCASE and t.SL_ID=t1.SL_ID
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where t1.PR_CONS is null and (
  (substring(t.ds1,1,1) = 'C' or  t.ds1 between 'D00' and 'D09.99' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS from #TEMP_DS ds where (ds.DS between 'C00' and 'C80.9' or  ds.ds between 'C97' and 'C97.9')))) 
  or (t.ds_onk = 1 and SUBSTRING(z.FILENAME,1,1)='T')
  )

 -- Проверка №150.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'KOL_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Значение KOL_USL не может быть пустым или равным 0'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
 where isnull(u.KOL_USL,0)=0

 -- Проверка №150 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'KOL_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Значение KOL_USL не может быть больше 1 при значениие PROFIL="'+isnull(cast(s.PROFIL as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
 where u.KOL_USL > 1 and s.profil not in (34,38)

-- Проверка №149.6 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
 select 'DS_ONK', 'SL', zs.N_ZAP, zs.IDCASE, t.SL_ID, null, '904', 'При впервые установленном диагнозе ЗНО необходимо наличие результатов гистологии (мпаркер (ИГХ))'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
  left join #SCHET_SLUCH_ONK_DIAG n on t.IDCASE=n.IDCASE and t.SL_ID=n.SL_ID
 where t.ds_onk = 0 
   and (not(zs.lpu in ('400003') and zs.USL_OK=3) or getdate() > '01.06.2019') -- Временно исключаем онкодиспансер
   and t.C_ZAB = 2
   and n.DIAG_TIP is null
   and (substring(t.ds1,1,1) = 'C' or t.ds1 between 'D00' and 'D09.99' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS from #TEMP_DS ds where (ds.DS between 'C00' and 'C80.9' or  ds.ds between 'C97' and 'C97.9'))))
   --   and t.PRVS in (9,19,41)
   and (@type != 693 or getdate() > '01.05.2019')  

-- Проверка №149.5 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
 select 'DS_ONK', 'SL', zs.N_ZAP, zs.IDCASE, t.SL_ID, null, '904', 'При DS_ONK="1" и посещении врача онколога первичного звена при NAPR_V="'+isnull(cast(n.NAPR_V as varchar),'')+
  '" нельзя указывать NAPR_MO="'+isnull(cast(n.NAPR_MO as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
  left join #SCHET_USL_NAPR n on t.IDCASE=n.IDCASE and t.SL_ID=n.SL_ID
 where t.ds_onk = 1 
   and n.NAPR_V in (1,2) 
   and zs.lpu not in ('400003','400109')
   and n.NAPR_MO = zs.LPU
   and t.PRVS in (9,19,41)
   and (@type != 693 or getdate() > '01.05.2019') 

-- Проверка №149.3 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
 select 'DS_ONK', 'SL', zs.N_ZAP, zs.IDCASE, t.SL_ID, null, '904', 'При DS_ONK="1" и посещении врача онколога должно быть направление на диагностику или на госпитальзацию'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
  left join #SCHET_USL_NAPR n on t.IDCASE=n.IDCASE and t.SL_ID=n.SL_ID
 where t.ds_onk = 1 
   and not (isnull(n.NAPR_V,0) in (2,3,4) or zs.RSLT in (305,306,308,309) or (n.NAPR_V=1 and zs.lpu not in ('400003','400109')))
   and t.PRVS in (9,19,41)
   and (@type != 693 or getdate() > '01.05.2019') 

-- Проверка №149.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
 select 'DS_ONK', 'SL', zs.N_ZAP, zs.IDCASE, t.SL_ID, null, '904', 'При DS_ONK="1" и посещении не врача онколога должно быть направление к онкологу или на дополнительные диагностические исследования.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
  left join #SCHET_USL_NAPR n on t.IDCASE=n.IDCASE and t.SL_ID=n.SL_ID
 where t.ds_onk = 1 
   and isnull(n.NAPR_V,0) not in (1,3)
   and t.PRVS not in (9,19,41)
   and t.PROFIL not in (78,34,38,111,106,76,123) -- исключаем профили по диагностическим мероприятиям
   and (@type != 693 or getdate() > '01.05.2019') 
	  

-- Проверка №149.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, SL_ID, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS_ONK', 'SL', zs.N_ZAP, zs.IDCASE, t.SL_ID, null, '904', 'Не корректное значение DS_ONK="'+isnull(cast(DS_ONK as varchar),'')+'" для DS1="'+isnull(cast(DS1 as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where (t.ds_onk = 1 and (substring(t.ds1,1,1) = 'C' or t.ds1 between 'D00' and 'D09.99' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS from #TEMP_DS ds where (ds.DS between 'C00' and 'C80.9' or  ds.ds between 'C97' and 'C97.9'))))) 
--   or (t.ds_onk = 1 and zs.USL_OK=3 and (t.ds1 between 'D00' and 'D09.99' or t.ds1 between 'C00' and 'C80.99' or t.ds1 between 'C97' and 'C97.99') 
       and (@type != 693 or getdate() > '01.05.2019') 
--	  )

-- Проверка №149 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
 select 'DS_ONK', 'SL', zs.N_ZAP, zs.IDCASE, t.SL_ID, null, '904', 'Значение DS_ONK="'+isnull(cast(DS_ONK as varchar),'')+'" не соответствует допустимому значению  в справочнике'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where t.ds_onk not in (0,1)

 /*-- Проверка №146 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Код профиля ' + cast(u.profil as varchar) + ' не соответствует виду помощи ' +cast(vidpom as varchar)+' и условию оказания '+cast(usl_ok as varchar)
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  where (usl_ok = 3 and vidpom = 12 and not u.profil in (57,58,68,97))
	or (usl_ok = 3 and vidpom = 11 and not u.profil = 42)
	or (usl_ok = 3 and not vidpom = 11 and  u.profil = 42)
	or (usl_ok = 3 and not vidpom = 12 and u.profil in (57,58,68,97))
*/

 -- Проверка №145 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'FOR_POM', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение FOR_POM="'+cast(zs.for_pom as varchar)+'" не соответствует коду услуги "'+cast(t1.CODE_USL as varchar)+'"'
 from #TEMP_Z_SLUCH zs
  join  #SCHET_USL t1 on zs.IDCASE=t1.IDCASE
  where ((zs.USL_OK=3 and zs.FOR_POM = 2  and t1.CODE_USL not in ('B01.047.007', 'B01.050.006', 'B01.069.012', 'B01.069.090', 'B01.080.07', 'B03.059.01', 'B01.064.005', 
  'B01.064.007', 'B01.064.006', 'B01.026.070.01', 'B01.004.074.01', 'B01.001.075.01', 'B01.001.070.01', 'B01.008.074.01', 'B01.014.070.01', 'B01.014.075.01', 'B01.015.070.01', 
  'B01.023.070.01', 'B01.023.075.01', 'B01.027.072.01', 'B01.028.075.01', 'B01.029.075.01', 'B01.031.071.01', 'B01.047.071.01', 'B01.050.074.01', 'B01.053.072.01', 
  'B01.010.070.01', 'B01.057.071.01',  'B01.058.074.01', 'B01.028.070.01', 'B01.029.070.01', 'B01.044.070.01', 'B01.069.009','B03.059.03','B01.065.03'))
  or (zs.USL_OK=3 and zs.FOR_POM != 2  and t1.CODE_USL in ('B01.047.007', 'B01.050.006', 'B01.069.012', 'B01.069.090', 'B01.080.07', 'B03.059.01', 'B01.064.005', 
  'B01.064.007', 'B01.064.006', 'B01.026.070.01', 'B01.004.074.01', 'B01.001.075.01', 'B01.001.070.01', 'B01.008.074.01', 'B01.014.070.01', 'B01.014.075.01', 'B01.015.070.01', 
  'B01.023.070.01', 'B01.023.075.01', 'B01.027.072.01', 'B01.028.075.01', 'B01.029.075.01', 'B01.031.071.01', 'B01.047.071.01', 'B01.050.074.01', 'B01.053.072.01', 
  'B01.010.070.01', 'B01.057.071.01',  'B01.058.074.01', 'B01.028.070.01', 'B01.029.070.01', 'B01.044.070.01', 'B01.069.009','B03.059.03','B01.065.03'))
  ) and (@type != 693 or getdate() >= '01.03.2019')  

/*
 -- Проверка №144 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'ID_PAC', 'PACIENT', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение ID_PAC="'+cast(t.ID_PAC as varchar)+'" не найдено в файле персональных данных'
 from #TEMP_Z_SLUCH zs
  join #TEMP_ZAP t on zs.N_ZAP=t.N_ZAP
  where not exists (select 1 from #TEMP_PERS t1 where cast(t1.ID_PAC as varchar)=cast(t.ID_PAC as varchar)) 
*/

-- Проверка №143.10 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Услуга CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не может оказываться в LPU="'+isnull(cast(zs.lpu as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join  #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join  #SCHET_USL t1 on zs.IDCASE=t1.IDCASE
 where t1.CODE_USL in ('A09.30.090','A09.30.091','A09.30.092','A09.30.093','A12.31.002','A12.31.004','A12.31.007','A12.31.008') and zs.LPU not in ('400003','400109','400001')
   or t1.CODE_USL in ('A06.20.004.092','A06.20.004.093','A06.20.006.06.07','A07.03.001','A07.14.002','A07.22.002','A07.28.004') and zs.LPU not in ('400003','400109')
   or t1.CODE_USL in ('A08.20.004.002') and zs.LPU not in ('400003')

-- Проверка №143.7 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Услуга CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не может оказываться при P_CEL="'+isnull(cast(s.P_CEL as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join  #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join  #SCHET_USL t1 on zs.IDCASE=t1.IDCASE
  join [IES].[R_NSI_USL_V001] t3 on t1.CODE_USL=t3.CODE_USL and t3.USL_OK in (3,4)
  LEFT JOIN IES.T_V025_KPC t9 ON t9.V025KpcID = t3.P_CEL
 where t3.F_AKTUAL = 1 
   and (isnull(cast(t9.IDPC as varchar),t3.P_CEL_T) not like '%'+s.P_CEL+'%')
   and (t3.P_CEL is not null or t3.P_CEL_T is not null)
   and zs.USL_OK in (3,4)


-- Проверка №143.6 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Услуга CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не может оказываться при IDSP="'+isnull(cast(zs.IDSP as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join  #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join  #SCHET_USL t1 on zs.IDCASE=t1.IDCASE
  join [IES].[R_NSI_USL_V001] t3 on t1.CODE_USL=t3.CODE_USL and t3.USL_OK in (3,4)
  LEFT JOIN IES.T_V010_PAY t8 ON t8.V010PayID = t3.V010Pay
 where t3.F_AKTUAL = 1 
   and (case when  t8.IDSP is null then t3.IDSP_T else cast(t8.IDSP as varchar) end not like '%'+cast(zs.IDSP as varchar)+'%')
   and (t3.V010Pay is not null or t3.IDSP_T is not null)
   and zs.USL_OK in (3,4)

-- Проверка №143.5 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Услуга CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не может оказываться при PRVS="'+isnull(cast(s.PRVS as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join  #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join  #SCHET_USL t1 on zs.IDCASE=t1.IDCASE
  join [IES].[R_NSI_USL_V001] t3 on t1.CODE_USL=t3.CODE_USL and t3.USL_OK in (3,4)
 where t3.F_AKTUAL = 1 
   and (case when t3.PRVS is null then t3.PRVS_T else cast(t3.PRVS as varchar) end not like '%'+cast(s.PRVS as varchar)+'%')
   and (t3.PRVS is not null or t3.PRVS_T is not null)
   and zs.USL_OK in (3,4)

-- Проверка №143.4 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Услуга CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не может оказываться при PROFIL="'+isnull(cast(s.PROFIL as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join  #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join  #SCHET_USL t1 on zs.IDCASE=t1.IDCASE
  join [IES].[R_NSI_USL_V001] t3 on t1.CODE_USL=t3.CODE_USL and t3.USL_OK in (3,4)
 where t3.F_AKTUAL = 1 
   and (case when t3.PROFIL_V002 is null then t3.PROFIL_T else cast(t3.PROFIL_V002 as varchar) end not like '%'+cast(s.PROFIL as varchar)+'%')
   and (t3.PROFIL_V002 is not null or t3.PROFIL_T is not null)
   and zs.USL_OK in (3,4)

-- Проверка №143.3 по базе в ОРАКЛЕ 
-- убрать костыль на 11 Vidpom
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 SELECT 'CODE_USL', 
'USL', 
zs.N_ZAP, 
zs.IDCASE, 
NULL, 
'904', 
'Услуга CODE_USL="' + ISNULL(CAST(t1.CODE_USL AS VARCHAR), '') + '" не может оказываться при VIDPOM="' + ISNULL(CAST(zs.VIDPOM AS
VARCHAR), '') + '"'
FROM #TEMP_Z_SLUCH zs
JOIN #SCHET_USL t1 ON zs.IDCASE = t1.IDCASE
JOIN [IES].[R_NSI_USL_V001] t3 ON t1.CODE_USL = t3.CODE_USL
AND t3.USL_OK IN(3, 4)
WHERE t3.F_AKTUAL = 1
AND t3.VIDPOM != CASE WHEN zs.VIDPOM = 11 AND (t1.CODE_USL LIKE 'D%' OR t1.CODE_USL LIKE 'P%') THEN 12 ELSE zs.VIDPOM end
AND t3.VIDPOM IS NOT NULL
AND zs.USL_OK IN(3, 4);
---- select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Услуга CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не может оказываться при VIDPOM="'+isnull(cast(zs.VIDPOM as varchar),'')+'"'
---- from #TEMP_Z_SLUCH zs
----  join  #SCHET_USL t1 on zs.IDCASE=t1.IDCASE
--  join [IES].[R_NSI_USL_V001] t3 on t1.CODE_USL=t3.CODE_USL and t3.USL_OK in (3,4)
-- where t3.F_AKTUAL = 1 and t3.VIDPOM != zs.VIDPOM and t3.VIDPOM is not null
--   and zs.USL_OK in (3,4)

-- Проверка №143.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Услуга CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не может оказываться в USL_OK="'+isnull(cast(zs.USL_OK as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join  #SCHET_USL t1 on zs.IDCASE=t1.IDCASE
  join [IES].[R_NSI_USL_V001] t3 on t1.CODE_USL=t3.CODE_USL and t3.USL_OK in (3,4)
 where t3.F_AKTUAL = 1 and t3.USL_OK != zs.USL_OK
   and zs.USL_OK in (3,4)

-- Проверка №143.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не актуально в справочнике услуг ФЛК'
 from #TEMP_Z_SLUCH zs
  join  #SCHET_USL t1 on zs.IDCASE=t1.IDCASE
  left join [IES].[R_NSI_USL_V001] t3 on t1.CODE_USL=t3.CODE_USL
 where t3.F_AKTUAL = 0

-- Проверка №143 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не соответствует допустимому значению  в справочнике V001'
 from #TEMP_Z_SLUCH zs
  join  #SCHET_USL t1 on zs.IDCASE=t1.IDCASE
  left join [IES].[R_NSI_USL_V001] t3 on t1.CODE_USL=t3.CODE_USL
 where t3.CODE_USL is null

-- Проверка №142.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT) 
 select 'DS0', 'SL', zs.N_ZAP, zs.IDCASE, null, '905', 'Значение DS0="'+cast(s.ds0 as varchar)+'" в блоке SL не соответствует допустимому.' 
 from  #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  LEFT JOIN  ies.R_MKB_10 mkb on mkb.MKB10CODE = s.DS0 and mkb.priznak = 1
 where mkb.MKB10CODE is null and s.DS0 is not null

-- Проверка №142 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT) 
 select 'DS1', 'SL', zs.N_ZAP, zs.IDCASE, null, '905', 'Значение DS1="'+cast(s.ds1 as varchar)+'" в блоке SL не соответствует допустимому.' 
 from  #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  LEFT JOIN  ies.R_MKB_10 mkb on mkb.MKB10CODE = s.DS1 and mkb.priznak = 1
 where mkb.MKB10CODE is null and s.DS1 is not null

-- Проверка №141 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT) 
 select 'DS', 'USL', zs.N_ZAP, zs.IDCASE, null, '905', 'Значение DS="'+cast(s.ds as varchar)+'" в блоке USL не соответствует допустимому.' 
 from  #TEMP_Z_SLUCH zs
  join #SCHET_USL s on (s.IDCASE=zs.IDCASE) 
  LEFT JOIN  ies.R_MKB_10 mkb on mkb.MKB10CODE = s.DS and mkb.priznak = 1
 where mkb.MKB10CODE is null and s.DS is not null

-- Проверка №140 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'TARIF', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Не указан тариф для услуги.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  where u.TARIF is null

 -- Проверка №139 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'ED_COL', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не заполнено поле ED_COL для лабораторных исследований'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  where s.ed_col is null
        and s.profil in (34,38) 

 -- Проверка №138 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'ED_COL', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение в поле ED_COL > 1 только для лабораторных исследований'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  where s.ed_col > 1 
        and s.profil not in (34,38) 

 -- Проверка №137 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'KD', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение поля KD не соответствует периоду лечения.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C','T')
  where (CASE s.date_2-s.date_1 WHEN 0 THEN 1 ELSE s.date_2-s.date_1 END <> s.kd and zs.usl_ok = 1)
   or ( s.date_2-s.date_1+1 != s.kd and zs.usl_ok = 2)

 -- Проверка №136.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение PROFIL="'+cast(s.PROFIL as varchar)+'"  не соответствует значению N_KSG="'+cast(t1.n_ksg as varchar)
  +'" при USL_OK="'+cast(zs.USL_OK as varchar)+'".'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_KSG t1 on (t1.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H')
  where (s.profil = 137 and t1.n_ksg != 'ds02.005') 
     or (s.profil != 137 and t1.n_ksg = 'ds02.005')  

 -- Проверка №136 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение PROFIL="'+cast(s.PROFIL as varchar)+'"  не соответствует значению VIDPOM="'+cast(zs.vidpom as varchar)
  +'" при USL_OK="'+cast(zs.USL_OK as varchar)+'".'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C','D')
  where (s.profil in (68,97,57,58) and zs.usl_ok = 3 and zs.vidpom != 12) 
         or (s.profil not in (68,97,57,58) and zs.usl_ok = 3 and zs.vidpom = 12) 
         or (s.profil in (42,3,82,85) and zs.usl_ok = 3 and zs.vidpom != 11)          
         or (s.profil not in (42,3,82,85) and zs.usl_ok = 3 and zs.vidpom = 11)    
         or (s.profil = 84 and zs.usl_ok = 4 and zs.vidpom != 21)          
         or (s.profil != 84 and zs.usl_ok = 4 and zs.vidpom = 21)    



-- Проверка №135.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DISP', 'SCHET', zs.N_ZAP, zs.IDCASE, null, '905', 'При значении DISP="'+isnull(cast(t.disp as varchar),'')+'" нельзя использовать значение RSLT_D="'+isnull(cast(zs.rslt_d as varchar),'')+'".'
 from #TEMP_Z_SLUCH zs 
  join #SCHET t on SUBSTRING(t.FILENAME,1,1) in ('D')
 where (not exists (select 1 from [IESDB].[IES].[T_SPR_RSLT_D_TO_RSLT] t7 where t.DISP=t7.DISP and zs.RSLT_D=t7.RSLT_D and zs.DATE_Z_2<='31.05.2019'
					union
					select 1 from [IESDB].[IES].[T_SPR_RSLT_D_TO_RSLT_NEW] t8 where t.DISP=t8.DISP and zs.RSLT_D=t8.RSLT_D and zs.DATE_Z_2>='01.06.2019')) -- Новые соответствия с 01.06.2019 
   and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693 and GETDATE() > '15.03.2019')) 


-- Проверка №135 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DISP', 'SCHET', null, null, null, '905', 'Значение DISP="'+isnull(cast(z.disp as varchar),'')+'" не соответствует имени файла "'+z.filename+'".'
 from #TEMP_Z_SLUCH zs
  join #TEMP_ZAP c on c.N_ZAP=zs.N_ZAP
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('D')
 where substring(z.filename,1,1) = 'D' 
        and ( (substring(z.filename,2,1) = 'P' and z.disp not in ('ДВ1','ДВ3') and zs.date_z_2<='31.05.2019')
			 or (substring(z.filename,2,1) = 'P' and z.disp not in ('ДВ4') and zs.date_z_2>='01.06.2019')
             or (substring(z.filename,2,1) = 'V' and z.disp not in ('ДВ2','ДВ3'))
             or (substring(z.filename,2,1) = 'O' and z.disp not in ('ОПВ'))
             or (substring(z.filename,2,1) = 'S' and z.disp not in ('ДС1','ДС3'))
             or (substring(z.filename,2,1) = 'U' and z.disp not in ('ДС2','ДС4'))
             or (substring(z.filename,2,1) = 'F' and z.disp not in ('ПН1','ПН2'))
            ) 

 -- Проверка №134.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMP', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Сумма принятая не может быть меньше 0'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  where zs.SUMP < 0

 -- Проверка №134 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUM_M', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Сумма случая не может равняться 0.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  where s.sum_m = 0

 -- Проверка №133 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'VIDPOM', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Некорректное заполнение поля VIDPOM="'+cast(zs.VIDPOM as varchar)+'" в связке с именем файла "'+SUBSTRING(z.FILENAME,1,1)+'".'
 from #TEMP_Z_SLUCH zs
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C','T','D')
  where (SUBSTRING(z.FILENAME,1,1) in ('H','C') and zs.vidpom not in (11,12,13,31,21))
     or (SUBSTRING(z.FILENAME,1,1) = 'T' and zs.vidpom != 32)
     or (SUBSTRING(z.FILENAME,1,1) = 'D' and zs.vidpom not in (11,12,13))
/*
 -- Проверка №132.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', t.N_ZAP, t.IDCASE, u.IDSERV, '904', 'Вы не можете использовать услугу B01.069.098'  
 from #TEMP_Z_SLUCH s
  join #TEMP_SLUCH t on (s.IDCASE=t.IDCASE) 
  join #SCHET_USL u on (t.IDCASE=u.IDCASE and t.SL_ID=u.SL_ID) 
  where u.CODE_USL = 'B01.069.098' and s.LPU != '400064'
*/
 -- Проверка №132.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL', 'SL', t.N_ZAP, t.IDCASE, null, '904', 'Отсутствуют услуги для ВМП при ЗНО'  
 from #TEMP_Z_SLUCH s
  join #TEMP_SLUCH t on (s.IDCASE=t.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('T')
  where not exists (select 1 from #SCHET_USL t1 where t1.IDCASE=s.IDCASE)
   and (substring(t.ds1,1,1) = 'C' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS from #TEMP_DS ds where (ds.DS between 'C00' and 'C80.9' or  ds.ds between 'C97' and 'C97.9'))))


 -- Проверка №132 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMV', 'Z_SL', N_ZAP, IDCASE, null, '904', 'Отсутствуют услуги для  амбулаторно-поликлинической и скорой помощи (USL_OK={3,4})'  
 from #TEMP_Z_SLUCH s
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
  where s.USL_OK in (3,4) and (select count(*) from #SCHET_USL t1 where t1.IDCASE=s.IDCASE) = 0

 -- Проверка №131 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMV', 'Z_SL', N_ZAP, IDCASE, null, '904', 'Больше одной услуги с SUMV_USL больше 0 внутри одного случая при амбулаторно-поликлинической помощи (USL_OK=3)'  
 from #TEMP_Z_SLUCH s
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('D', 'H','C')
  where s.USL_OK=3 and (select count(*) from #SCHET_USL t1 where t1.IDCASE=s.IDCASE and t1.SUMV_USL > 0 and t1.CODE_USL not in ('D04.069.298','D04.069.299','D04.069.300')) > 1

 -- Проверка №131.0 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMV', 'Z_SL', N_ZAP, IDCASE, null, '904', 'Две услуги с одинаковым кодом внутри одного случая лечения.'  
 from #TEMP_Z_SLUCH s
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('D', 'H','C')
  where s.USL_OK=3 
    and exists (select top 1 t1.CODE_USL from #SCHET_USL t1 where t1.IDCASE=s.IDCASE and t1.CODE_USL in ('D04.069.298','D04.069.299','D04.069.300') group by t1.CODE_USL having count(*)>1)


 -- Проверка №130 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'VIDPOM', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NPOLIS "'+p.npolis+'" не соответствует VPOLIS "'+cast(p.VPOLIS as varchar)+'"'
 from #TEMP_Z_SLUCH zs
 join #TEMP_ZAP z on z.N_ZAP=zs.N_ZAP
 join #TEMP_ZAP p on p.N_ZAP=z.N_ZAP
  where p.VPOLIS = 3 and len(p.NPOLIS) <> 16

 -- Проверка №129.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMV', 'Z_SL', N_ZAP, IDCASE, null, '904', 'Сумма законченного случая не равна сумме случаев лечения в нем'  
 from #TEMP_Z_SLUCH s
  where s.SUMV != (select sum(SUM_M) from #TEMP_SLUCH t where t.IDCASE=s.IDCASE)

 -- Проверка №129 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMMAV', 'SCHET', null, null, null, '904', 'Сумма счета не равна сумме в случаях лечения'  
 from #SCHET s
  where s.SUMMAV != (select sum(SUM_M) from #TEMP_SLUCH t)

 -- Проверка №128 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'P_CEL', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Некорректное заполнение поля P_CEL="'+isnull(cast(s.P_CEL as varchar),'')+'" при указании IDSP="'
  +isnull(cast(zs.IDSP as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  where usl_ok = 3 and not ( 
        (s.p_cel in ('1.0','1.1','1.2','1.3','2.1','2.2','2.3','2.5','2.6') and zs.idsp = 29)
        or (s.p_cel in ('1.0','1.1','1.2','1.3','2.1','2.1','2.3','2.5','2.6','3.0') and zs.idsp = 25)
        or (s.p_cel in ('2.1','2.2','3.0') and zs.idsp = 30)
        or (s.p_cel = '2.6' and zs.idsp = 28)
		)
		
-- Проверка №127 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_Z_1', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Даты законченного случая не соответствуют отчетному периоду DATE_Z_1="'+cast(format(zs.DATE_Z_1,'dd.MM.yyyy') as varchar)
  +'" DATE_Z_2="'+cast(format(zs.DATE_Z_2,'dd.MM.yyyy') as varchar)+'" DSCHET="'+cast(format(t1.DSCHET,'dd.MM.yyyy') as varchar)+'"'
 from #TEMP_Z_SLUCH zs
  join #SCHET t1 on (zs.date_z_1 < t1.DSCHET-360 or zs.date_z_1 > t1.DSCHET or zs.date_z_2 < t1.DSCHET-90 or zs.date_z_2 > t1.DSCHET) 
  join #TEMP_ZAP z on zs.N_ZAP=z.N_ZAP and z.PR_NOV=0

-- Проверка №126.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_IN', 'USL', zs.N_ZAP, zs.IDCASE, s.IDSERV, '904', 'Даты услуги не соответствуют датам случая или законченного случая DATE_IN="'+cast(format(s.DATE_IN,'dd.MM.yyyy') as varchar)
  +'" DATE_OUT="'+cast(format(s.DATE_OUT,'dd.MM.yyyy') as varchar)+'" DATE_1="'+cast(format(sl.DATE_1,'dd.MM.yyyy') as varchar)+'"'
  +' DATE_2="'+cast(format(sl.DATE_2,'dd.MM.yyyy') as varchar)+'"'
  +' DATE_Z_1="'+cast(format(zs.DATE_Z_1,'dd.MM.yyyy') as varchar)+'"'
  +' DATE_Z_2="'+cast(format(zs.DATE_Z_2,'dd.MM.yyyy') as varchar)+'"'
 from #TEMP_Z_SLUCH zs
  join #SCHET_USL s on s.IDCASE=zs.IDCASE 
  join #TEMP_SLUCH sl on sl.IDCASE=zs.IDCASE 
  join #TEMP_ZAP z on zs.N_ZAP=z.N_ZAP and z.PR_NOV=0
where zs.USL_OK in (3,4)
  and @type = 554
  and (s.DATE_IN != zs.DATE_Z_1 
       or s.DATE_IN != sl.DATE_1
	   or s.DATE_OUT != zs.DATE_Z_2
	   or s.DATE_OUT != sl.DATE_2
	  )

-- Проверка №126 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_IN', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Даты оказанной услуги не соответствуют отчетному периоду DATE_IN="'+cast(format(s.DATE_IN,'dd.MM.yyyy') as varchar)
  +'" DATE_OUT="'+cast(format(s.DATE_OUT,'dd.MM.yyyy') as varchar)+'" DSCHET="'+cast(format(t1.DSCHET,'dd.MM.yyyy') as varchar)+'"'
 from #TEMP_Z_SLUCH zs
  join #SCHET_USL s on s.IDCASE=zs.IDCASE 
  join #SCHET t1 on (s.date_in < t1.DSCHET-360 or s.date_in > t1.DSCHET or s.date_out < t1.DSCHET-360 or s.date_out > t1.DSCHET) 
  join #TEMP_ZAP z on zs.N_ZAP=z.N_ZAP and z.PR_NOV=0

-- Проверка №125 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_1', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Даты случая лечения не соответствуют отчетному периоду DATE_1="'+cast(format(s.DATE_1,'dd.MM.yyyy') as varchar)
  +'" DATE_2="'+cast(format(s.DATE_2,'dd.MM.yyyy') as varchar)+'" DSCHET="'+cast(format(t1.DSCHET,'dd.MM.yyyy') as varchar)+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on s.IDCASE=zs.IDCASE 
  join #SCHET t1 on (s.date_1 < t1.DSCHET-360 or s.date_1 > t1.DSCHET or s.date_2 < t1.DSCHET-180 or s.date_2 > t1.DSCHET) 
  join #TEMP_ZAP z on zs.N_ZAP=z.N_ZAP and z.PR_NOV=0


-- Проверка №123.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Код профиля МП в случае "'+cast(s.PROFIL as varchar)+'" не соответствует коду профиля МП в услуге "'+cast(u.PROFIL as varchar)+'".'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_USL u on (s.IDCASE=u.IDCASE and s.SL_ID=u.SL_ID) 
  where (zs.USL_OK in (3,4) and s.PROFIL != u.PROFIL and u.CODE_USL not in ('D04.069.299','D04.069.298'))
     or (zs.USL_OK in (1,2) and u.SUMV_USL = 0 and s.PROFIL != u.PROFIL)

-- Проверка №123.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Код профиля МП "'+cast(s.PROFIL as varchar)+'" не соответствует коду специальности "'+cast(s.PRVS as varchar)+'".'
 from #TEMP_Z_SLUCH zs
  join #SCHET_USL s on (s.IDCASE=zs.IDCASE) 
  left join [IES].T_CHER_PROFIL_PRVS p ON s.profil = p.profil and s.prvs=p.prvs
  where p.profil is null

-- Проверка №123 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Код профиля МП "'+cast(s.PROFIL as varchar)+'" не соответствует коду специальности "'+cast(s.PRVS as varchar)+'".'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  left join [IES].T_CHER_PROFIL_PRVS p ON s.profil = p.profil and s.prvs=p.prvs
  where p.profil is null
/*
-- Проверка №122 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'FAM_P', 'PERS', zs.N_ZAP, zs.IDCASE, null, '904', 'Некорректно указаные данные представителя пациента.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_ZAP t on t.N_ZAP=zs.N_ZAP 
  join #TEMP_PERS s on cast(t.ID_PAC as varchar)=cast(s.ID_PAC as varchar) 
 where (s.fam_p is not null and (s.im_p is null or s.dr_p is null or s.w_p is null))
  or (s.fam_p is null and s.im_p is null and  (s.ot_p is not null or s.dr_p is not null or s.w_p is not null))

-- Проверка №121 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'FAM_P', 'PERS', zs.N_ZAP, zs.IDCASE, null, '904', 'Отсутствуют данные представителя у новорожденного.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_ZAP t on t.N_ZAP=zs.N_ZAP 
  join #TEMP_PERS s on cast(t.ID_PAC as varchar)=cast(s.ID_PAC as varchar) 
 where ((s.fam is null) or (s.im is null)) 
   and ((s.fam_p is null) or (s.im_p is null) or (s.dr_p is null))   
*/
-- Проверка №120.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL_OK', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Код условия оказания МП "'+cast(zs.USL_OK as varchar)+'" не соответствует виду оказания МП "'+cast(zs.VIDPOM as varchar)+'".'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where (zs.USL_OK=1 and zs.VIDPOM != 31)
    or (zs.USL_OK=2 and zs.VIDPOM not in (13,31))
    or (zs.USL_OK=3 and zs.VIDPOM not in (11,12,13,14))
    or (zs.USL_OK=4 and zs.VIDPOM !=21)

-- Проверка №120 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL_OK', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Код условия оказания МП "'+cast(zs.USL_OK as varchar)+'" не соответствует форме оказания МП "'+cast(zs.FOR_POM as varchar)+'".'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  left join [IES].T_CHER_USLOK_FORPOM  p ON zs.usl_ok = p.usl_ok and zs.for_pom=p.for_pom
 where p.usl_ok is null
/*
-- Проверка №119 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IM', 'PERS', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректное имя.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_ZAP t on t.N_ZAP=zs.N_ZAP 
  join #TEMP_PERS s on cast(t.ID_PAC as varchar)=cast(s.ID_PAC as varchar) 
 where s.IM  IN ('НЕТ', 'АЛИ', 'Нет','Н','-','Х','X','H','A','B','А','В')           
   or  s.IM_P IN ('НЕТ', 'АЛИ', 'Нет','Н','-','Х','X','H','A','B','А','В')           

-- Проверка №118 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Код услуги "'+u.CODE_USL+'" не сответствует коду типу помощи "'+cast(zs.USL_OK as varchar)+'".'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
  where u.code_usl IN ('B01.044.001.001', 'B01.044.005')
      AND zs.usl_ok != 4

-- Проверка №119 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IM', 'PERS', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректное отчество.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_ZAP t on t.N_ZAP=zs.N_ZAP 
  join #TEMP_PERS s on cast(t.ID_PAC as varchar)=cast(s.ID_PAC as varchar) 
 where s.OT  IN ('НЕТ', 'АЛИ', 'Нет','Н','-','Х','X','H','A','B','А','В')           
   or  s.OT_P IN ('НЕТ', 'АЛИ', 'Нет','Н','-','Х','X','H','A','B','А','В')           
*/
-- Проверка №116 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS3', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Диагноз осложнения заболевания указан без подрубрики.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #TEMP_DS t1 on (s.IDCASE=t1.IDCASE and s.SL_ID=t1.SL_ID and t1.ds_type=1) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C','T')
 where len(t1.DS) = 3
       AND t1.DS NOT IN
       ('A33', 'A34', 'A38', 'A46', 'A55', 'A57', 'A58', 'A64', 'A65', 'A70', 'A78', 'A89', 'A90', 'A91', 'A94', 'A99', 'B03', 'B04', 'B07', 'B09',
            'B54', 'B59', 'B64', 'B72', 'B73', 'B75', 'B79', 'B80', 'B86', 'B89', 'B91', 'B92', 'B99', 'C01', 'C07', 'C12', 'C20', 'C23', 'C33', 'C37',
            'C52', 'C55', 'C56', 'C58', 'C61', 'C64', 'C65', 'C66', 'C73', 'C97', 'D27', 'D34', 'D45', 'D65', 'D66', 'D67', 'D70', 'D71', 'D77', 'E02',
            'E15', 'E40', 'E41', 'E42', 'E43', 'E45', 'E46', 'E52', 'E54', 'E58', 'E59', 'E60', 'E65', 'E68', 'E86', 'E90', 'G07', 'G08', 'G09', 'G10',
            'G20', 'G26', 'G35', 'H55', 'H71', 'H82', 'I00', 'I10', 'I38', 'I81', 'I99', 'J00', 'J13', 'J14', 'J22', 'J36', 'J40', 'J46', 'J47', 'J60',
            'J61', 'J64', 'J65', 'J80', 'J81', 'J82', 'J90', 'J91', 'K20', 'K36', 'K37', 'L00', 'L14', 'L26', 'L42', 'L52', 'L80', 'L82', 'L83', 'L84',
            'L86', 'L88', 'L97', 'M45', 'N12', 'N19', 'N23', 'N26', 'N40', 'N44', 'N46', 'N47', 'N61', 'N62', 'N63', 'N72', 'N86', 'N96', 'O11', 'O13',
            'O16', 'O25', 'O40', 'O48', 'O85', 'O95', 'O96', 'O97', 'P38', 'P53', 'P60', 'P75', 'P77', 'P90', 'P93', 'P95', 'Q02', 'R05', 'R11', 'R12',
            'R13', 'R14', 'R15', 'R17', 'R18', 'R21', 'R31', 'R32', 'R33', 'R34', 'R35', 'R36', 'R42', 'R53', 'R55', 'R72', 'R51', 'R69', 'S16', 'S18',
            'T07', 'T16', 'T55', 'T58', 'T64', 'T66', 'T68', 'T97', 'Z21', 'B24', 'B49', 'C19', 'D24', 'D62', 'G01', 'G22', 'G92', 'G98', 'J42', 'K20',
            'K30', 'L22', 'L45', 'N10', 'R02', 'S47', 'Z33', 'T71', 'A35', 'A86', 'F03', 'F04', 'F09', 'F21', 'F24', 'F28', 'F29', 'F39', 'F54', 'F55',
            'F59', 'F61', 'F69', 'F82', 'F83', 'F88', 'F89', 'F99', 'G14', 'G64', 'H46', 'J09', 'O94', 'R54', 'R58', 'R64', 'R71', 'R75', 'R80', 'R81',
            'R91', 'R92', 'R95', 'R98', 'R99', 'T96', 'I64')
      AND zs.usl_ok != 4

-- Проверка №115 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS2', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Диагноз сопутствующего заболевания указан без подрубрики..'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #TEMP_DS t1 on (s.IDCASE=t1.IDCASE and s.SL_ID=t1.SL_ID and t1.ds_type=0) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C','T')
 where len(t1.DS) = 3
       AND t1.DS NOT IN
       ('A33', 'A34', 'A38', 'A46', 'A55', 'A57', 'A58', 'A64', 'A65', 'A70', 'A78', 'A89', 'A90', 'A91', 'A94', 'A99', 'B03', 'B04', 'B07', 'B09',
            'B54', 'B59', 'B64', 'B72', 'B73', 'B75', 'B79', 'B80', 'B86', 'B89', 'B91', 'B92', 'B99', 'C01', 'C07', 'C12', 'C20', 'C23', 'C33', 'C37',
            'C52', 'C55', 'C56', 'C58', 'C61', 'C64', 'C65', 'C66', 'C73', 'C97', 'D27', 'D34', 'D45', 'D65', 'D66', 'D67', 'D70', 'D71', 'D77', 'E02',
            'E15', 'E40', 'E41', 'E42', 'E43', 'E45', 'E46', 'E52', 'E54', 'E58', 'E59', 'E60', 'E65', 'E68', 'E86', 'E90', 'G07', 'G08', 'G09', 'G10',
            'G20', 'G26', 'G35', 'H55', 'H71', 'H82', 'I00', 'I10', 'I38', 'I81', 'I99', 'J00', 'J13', 'J14', 'J22', 'J36', 'J40', 'J46', 'J47', 'J60',
            'J61', 'J64', 'J65', 'J80', 'J81', 'J82', 'J90', 'J91', 'K20', 'K36', 'K37', 'L00', 'L14', 'L26', 'L42', 'L52', 'L80', 'L82', 'L83', 'L84',
            'L86', 'L88', 'L97', 'M45', 'N12', 'N19', 'N23', 'N26', 'N40', 'N44', 'N46', 'N47', 'N61', 'N62', 'N63', 'N72', 'N86', 'N96', 'O11', 'O13',
            'O16', 'O25', 'O40', 'O48', 'O85', 'O95', 'O96', 'O97', 'P38', 'P53', 'P60', 'P75', 'P77', 'P90', 'P93', 'P95', 'Q02', 'R05', 'R11', 'R12',
            'R13', 'R14', 'R15', 'R17', 'R18', 'R21', 'R31', 'R32', 'R33', 'R34', 'R35', 'R36', 'R42', 'R53', 'R55', 'R72', 'R51', 'R69', 'S16', 'S18',
            'T07', 'T16', 'T55', 'T58', 'T64', 'T66', 'T68', 'T97', 'Z21', 'B24', 'B49', 'C19', 'D24', 'D62', 'G01', 'G22', 'G92', 'G98', 'J42', 'K20',
            'K30', 'L22', 'L45', 'N10', 'R02', 'S47', 'Z33', 'T71', 'A35', 'A86', 'F03', 'F04', 'F09', 'F21', 'F24', 'F28', 'F29', 'F39', 'F54', 'F55',
            'F59', 'F61', 'F69', 'F82', 'F83', 'F88', 'F89', 'F99', 'G14', 'G64', 'H46', 'J09', 'O94', 'R54', 'R58', 'R64', 'R71', 'R75', 'R80', 'R81',
            'R91', 'R92', 'R95', 'R98', 'R99', 'T96', 'I64')
      AND zs.usl_ok != 4

-- Проверка №114.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS1', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Указанный код основного диагноза не может быть передан в файле C'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('C')
 where not ( t.ds_onk=1 or
  (substring(t.ds1,1,1) = 'C' or t.DS1 between 'D00.00' and 'D09.99' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS from #TEMP_DS ds where (ds.DS between 'C00' and 'C80.9' or  ds.ds between 'C97' and 'C97.9')))) 
  )

-- Проверка №114.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS1', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Указанный код основного диагноза не может быть передан в файле Н'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H')
 where (substring(t.ds1,1,1) = 'C' or t.DS1 between 'D00.00' and 'D09.99' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS from #TEMP_DS ds where (ds.DS between 'C00' and 'C80.9' or  ds.ds between 'C97' and 'C97.9')))) 

-- Проверка №114 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS1', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Основной код диагноза указан без подрубрики.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C','T')
 where len(s.DS1) = 3
       AND s.ds1 NOT IN
       ('A33', 'A34', 'A38', 'A46', 'A55', 'A57', 'A58', 'A64', 'A65', 'A70', 'A78', 'A89', 'A90', 'A91', 'A94', 'A99', 'B03', 'B04', 'B07', 'B09',
            'B54', 'B59', 'B64', 'B72', 'B73', 'B75', 'B79', 'B80', 'B86', 'B89', 'B91', 'B92', 'B99', 'C01', 'C07', 'C12', 'C20', 'C23', 'C33', 'C37',
            'C52', 'C55', 'C56', 'C58', 'C61', 'C64', 'C65', 'C66', 'C73', 'C97', 'D27', 'D34', 'D45', 'D65', 'D66', 'D67', 'D70', 'D71', 'D77', 'E02',
            'E15', 'E40', 'E41', 'E42', 'E43', 'E45', 'E46', 'E52', 'E54', 'E58', 'E59', 'E60', 'E65', 'E68', 'E86', 'E90', 'G07', 'G08', 'G09', 'G10',
            'G20', 'G26', 'G35', 'H55', 'H71', 'H82', 'I00', 'I10', 'I38', 'I81', 'I99', 'J00', 'J13', 'J14', 'J22', 'J36', 'J40', 'J46', 'J47', 'J60',
            'J61', 'J64', 'J65', 'J80', 'J81', 'J82', 'J90', 'J91', 'K20', 'K36', 'K37', 'L00', 'L14', 'L26', 'L42', 'L52', 'L80', 'L82', 'L83', 'L84',
            'L86', 'L88', 'L97', 'M45', 'N12', 'N19', 'N23', 'N26', 'N40', 'N44', 'N46', 'N47', 'N61', 'N62', 'N63', 'N72', 'N86', 'N96', 'O11', 'O13',
            'O16', 'O25', 'O40', 'O48', 'O85', 'O95', 'O96', 'O97', 'P38', 'P53', 'P60', 'P75', 'P77', 'P90', 'P93', 'P95', 'Q02', 'R05', 'R11', 'R12',
            'R13', 'R14', 'R15', 'R17', 'R18', 'R21', 'R31', 'R32', 'R33', 'R34', 'R35', 'R36', 'R42', 'R53', 'R55', 'R72', 'R51', 'R69', 'S16', 'S18',
            'T07', 'T16', 'T55', 'T58', 'T64', 'T66', 'T68', 'T97', 'Z21', 'B24', 'B49', 'C19', 'D24', 'D62', 'G01', 'G22', 'G92', 'G98', 'J42', 'K20',
            'K30', 'L22', 'L45', 'N10', 'R02', 'S47', 'Z33', 'T71', 'A35', 'A86', 'F03', 'F04', 'F09', 'F21', 'F24', 'F28', 'F29', 'F39', 'F54', 'F55',
            'F59', 'F61', 'F69', 'F82', 'F83', 'F88', 'F89', 'F99', 'G14', 'G64', 'H46', 'J09', 'O94', 'R54', 'R58', 'R64', 'R71', 'R75', 'R80', 'R81',
            'R91', 'R92', 'R95', 'R98', 'R99', 'T96', 'I64')
      AND zs.usl_ok != 4

-- Проверка №113 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS0', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Первичный код диагноза указан без подрубрики.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C','T')
 where len(s.DS0) = 3
       AND s.ds0 NOT IN
       ('A33', 'A34', 'A38', 'A46', 'A55', 'A57', 'A58', 'A64', 'A65', 'A70', 'A78', 'A89', 'A90', 'A91', 'A94', 'A99', 'B03', 'B04', 'B07', 'B09',
            'B54', 'B59', 'B64', 'B72', 'B73', 'B75', 'B79', 'B80', 'B86', 'B89', 'B91', 'B92', 'B99', 'C01', 'C07', 'C12', 'C20', 'C23', 'C33', 'C37',
            'C52', 'C55', 'C56', 'C58', 'C61', 'C64', 'C65', 'C66', 'C73', 'C97', 'D27', 'D34', 'D45', 'D65', 'D66', 'D67', 'D70', 'D71', 'D77', 'E02',
            'E15', 'E40', 'E41', 'E42', 'E43', 'E45', 'E46', 'E52', 'E54', 'E58', 'E59', 'E60', 'E65', 'E68', 'E86', 'E90', 'G07', 'G08', 'G09', 'G10',
            'G20', 'G26', 'G35', 'H55', 'H71', 'H82', 'I00', 'I10', 'I38', 'I81', 'I99', 'J00', 'J13', 'J14', 'J22', 'J36', 'J40', 'J46', 'J47', 'J60',
            'J61', 'J64', 'J65', 'J80', 'J81', 'J82', 'J90', 'J91', 'K20', 'K36', 'K37', 'L00', 'L14', 'L26', 'L42', 'L52', 'L80', 'L82', 'L83', 'L84',
            'L86', 'L88', 'L97', 'M45', 'N12', 'N19', 'N23', 'N26', 'N40', 'N44', 'N46', 'N47', 'N61', 'N62', 'N63', 'N72', 'N86', 'N96', 'O11', 'O13',
            'O16', 'O25', 'O40', 'O48', 'O85', 'O95', 'O96', 'O97', 'P38', 'P53', 'P60', 'P75', 'P77', 'P90', 'P93', 'P95', 'Q02', 'R05', 'R11', 'R12',
            'R13', 'R14', 'R15', 'R17', 'R18', 'R21', 'R31', 'R32', 'R33', 'R34', 'R35', 'R36', 'R42', 'R53', 'R55', 'R72', 'R51', 'R69', 'S16', 'S18',
            'T07', 'T16', 'T55', 'T58', 'T64', 'T66', 'T68', 'T97', 'Z21', 'B24', 'B49', 'C19', 'D24', 'D62', 'G01', 'G22', 'G92', 'G98', 'J42', 'K20',
            'K30', 'L22', 'L45', 'N10', 'R02', 'S47', 'Z33', 'T71', 'A35', 'A86', 'F03', 'F04', 'F09', 'F21', 'F24', 'F28', 'F29', 'F39', 'F54', 'F55',
            'F59', 'F61', 'F69', 'F82', 'F83', 'F88', 'F89', 'F99', 'G14', 'G64', 'H46', 'J09', 'O94', 'R54', 'R58', 'R64', 'R71', 'R75', 'R80', 'R81',
            'R91', 'R92', 'R95', 'R98', 'R99', 'T96', 'I64')
      AND zs.usl_ok != 4

-- Проверка №112 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Код диагноза в блоке сведений об услуге указан без подрубрики.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C','T')
 where len(u.DS) = 3
       AND u.ds NOT IN
       ('A33', 'A34', 'A38', 'A46', 'A55', 'A57', 'A58', 'A64', 'A65', 'A70', 'A78', 'A89', 'A90', 'A91', 'A94', 'A99', 'B03', 'B04', 'B07', 'B09',
            'B54', 'B59', 'B64', 'B72', 'B73', 'B75', 'B79', 'B80', 'B86', 'B89', 'B91', 'B92', 'B99', 'C01', 'C07', 'C12', 'C20', 'C23', 'C33', 'C37',
            'C52', 'C55', 'C56', 'C58', 'C61', 'C64', 'C65', 'C66', 'C73', 'C97', 'D27', 'D34', 'D45', 'D65', 'D66', 'D67', 'D70', 'D71', 'D77', 'E02',
            'E15', 'E40', 'E41', 'E42', 'E43', 'E45', 'E46', 'E52', 'E54', 'E58', 'E59', 'E60', 'E65', 'E68', 'E86', 'E90', 'G07', 'G08', 'G09', 'G10',
            'G20', 'G26', 'G35', 'H55', 'H71', 'H82', 'I00', 'I10', 'I38', 'I81', 'I99', 'J00', 'J13', 'J14', 'J22', 'J36', 'J40', 'J46', 'J47', 'J60',
            'J61', 'J64', 'J65', 'J80', 'J81', 'J82', 'J90', 'J91', 'K20', 'K36', 'K37', 'L00', 'L14', 'L26', 'L42', 'L52', 'L80', 'L82', 'L83', 'L84',
            'L86', 'L88', 'L97', 'M45', 'N12', 'N19', 'N23', 'N26', 'N40', 'N44', 'N46', 'N47', 'N61', 'N62', 'N63', 'N72', 'N86', 'N96', 'O11', 'O13',
            'O16', 'O25', 'O40', 'O48', 'O85', 'O95', 'O96', 'O97', 'P38', 'P53', 'P60', 'P75', 'P77', 'P90', 'P93', 'P95', 'Q02', 'R05', 'R11', 'R12',
            'R13', 'R14', 'R15', 'R17', 'R18', 'R21', 'R31', 'R32', 'R33', 'R34', 'R35', 'R36', 'R42', 'R53', 'R55', 'R72', 'R51', 'R69', 'S16', 'S18',
            'T07', 'T16', 'T55', 'T58', 'T64', 'T66', 'T68', 'T97', 'Z21', 'B24', 'B49', 'C19', 'D24', 'D62', 'G01', 'G22', 'G92', 'G98', 'J42', 'K20',
            'K30', 'L22', 'L45', 'N10', 'R02', 'S47', 'Z33', 'T71', 'A35', 'A86', 'F03', 'F04', 'F09', 'F21', 'F24', 'F28', 'F29', 'F39', 'F54', 'F55',
            'F59', 'F61', 'F69', 'F82', 'F83', 'F88', 'F89', 'F99', 'G14', 'G64', 'H46', 'J09', 'O94', 'R54', 'R58', 'R64', 'R71', 'R75', 'R80', 'R81',
            'R91', 'R92', 'R95', 'R98', 'R99', 'T96', 'I64')
      AND zs.usl_ok != 4

/*
-- Проверка №111 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Коду услуги "'+u.CODE_USL+'" не сответствует код цели посещения "'+s.p_cel+'".'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C','D')
 where (s.p_cel in ('1.1','3.0', '2.3','2.2','2.1') )
       and (
        (u.code_usl IN ('B01.047.007', 'B01.050.006', 'B01.069.012', 'B01.069.090', 'B01.080.07', 'B03.059.01', 'B03.059.02', 'B03.059.03', 'B01.064.005', 'B01.064.006', 'B01.064.007', 'B01.026.070.01', 
		'B01.004.074.01', 'B01.001.075.01', 'B01.001.070.01', 'B01.008.074.01', 'B01.014.070.01', 'B01.014.075.01', 'B01.015.070.01', 'B01.023.070.01', 'B01.023.075.01', 
		'B01.027.072.01', 'B01.028.075.01', 'B01.029.075.01', 'B01.031.071.01', 'B01.047.071.01', 'B01.050.074.01', 'B01.053.072.01', 'B01.010.070.01', 'B01.057.071.01', 
		'B01.058.074.01','B01.069.009', 'B01.028.070.01', 'B01.029.070.01', 'B01.044.070.01','B03.059.03','B01.065.03') AND s.p_cel != '1.1') 
        or  (u.code_usl not IN ('B01.047.007', 'B01.050.006', 'B01.069.012', 'B01.069.090', 'B01.080.07', 'B03.059.01', 'B03.059.02', 'B03.059.03', 'B01.064.005', 'B01.064.006', 'B01.064.007', 'B01.026.070.01', 
		'B01.004.074.01', 'B01.001.075.01', 'B01.001.070.01', 'B01.008.074.01', 'B01.014.070.01', 'B01.014.075.01', 'B01.015.070.01', 'B01.023.070.01', 'B01.023.075.01', 
		'B01.027.072.01', 'B01.028.075.01', 'B01.029.075.01', 'B01.031.071.01', 'B01.047.071.01', 'B01.050.074.01', 'B01.053.072.01', 'B01.010.070.01', 'B01.057.071.01', 
		'B01.058.074.01','B01.069.009', 'B01.028.070.01', 'B01.029.070.01', 'B01.044.070.01','B03.059.03','B01.065.03') AND s.p_cel = '1.1') 
        or (u.code_usl IN ('B04.066.01', 'B04.069.090', 'B03.029.001.090', 'B03.029.001.091','B01.007.080') AND s.p_cel != '2.3')
        or (u.code_usl not IN ('B04.066.01', 'B04.069.090', 'B03.029.001.090', 'B03.029.001.091','B01.007.080') AND s.p_cel = '2.3')
        or
        ((u.code_usl IN ('Z01.001.000', 'Z01.001.001', 'Z01.002.000', 'Z01.002.001', 'Z01.004.000', 'Z01.004.001', 'Z01.008.000', 'Z01.008.001', 'Z01.010.000', 'Z01.010.002',
               'Z01.014.000', 'Z01.014.001', 'Z01.014.002', 'Z01.015.000', 'Z01.015.001', 'Z01.015.002', 'Z01.016.000', 'Z01.016.001', 'Z01.018.000', 'Z01.023.000', 'Z01.023.001', 'Z01.025.000',
               'Z01.025.001', 'Z01.026.000', 'Z01.027.000', 'Z01.028.000', 'Z01.028.001', 'Z01.028.002', 'Z01.029.000', 'Z01.029.001', 'Z01.029.002',  'Z01.031.000', 'Z01.037.000', 'Z01.037.001',
               'Z01.040.000', 'Z01.043.000', 'Z01.046.000', 'Z01.046.001', 'Z01.047.000', 'Z01.050.000', 'Z01.050.001', 'Z01.050.002', 'Z01.053.000', 'Z01.053.001', 'Z01.057.000', 'Z01.058.000', 'Z01.058.001',
               'Z01.068.000', 'Z01.068.001', 'Z01.069.000', 'Z01.071.000','Z01.067.000') or u.sumv_usl = 0) AND s.p_cel != '3.0') 
        or
                (u.code_usl like 'D%' AND s.p_cel not in ('2.2')) 
        or
                (u.code_usl like 'P%' AND s.p_cel not in ('2.1')) )

-- Проверка №110 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMV_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Не корректная сумма стоматологической услуги.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  left join [IES].[T_CHER_USL_TARIF] t on t.LPU=u.LPU and t.USL_CODE=u.code_usl and u.date_out between t.DATE_B and t.DATE_E
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where u.sumv_usl != round(isnull(t.k_tarif,0)*isnull(u.kol_usl,0)/2.4,2)
        and zs.usl_ok in (3,4)
        and u.profil in (85,86,87,88,89,90,63,171,140) 
        and u.code_usl in ('Z01.063.001','Z01.064.000','Z01.064.001','Z01.067.000')                       
*/

-- Проверка №109 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUM_M', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректная сумма  случая ВМП (VID_HMP="'+isnull(cast(s.VID_HMP as varchar),'')+'" PROFIL="'+isnull(cast(s.PROFIL as varchar),'')
 +'" TARIF="'+isnull(cast(s.SUM_M as varchar),'')+'" K_TARIF="'+isnull(cast(t.K_TARIF as varchar),'')+'")'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('T')
  left join [IES].[R_NSI_VMP_TARIFFS] t on t.LPU=zs.LPU and t.ID_PR=s.PROFIL 
                                and cast(t.f_vmp as varchar) = substring(s.vid_hmp,dbo.instr(s.vid_hmp,'.',1,2)+1,case dbo.instr(s.vid_hmp,'.',1,3)-dbo.instr(s.vid_hmp,'.',1,2)-1 when -1 then 0 else dbo.instr(s.vid_hmp,'.',1,3)-dbo.instr(s.vid_hmp,'.',1,2)-1 end)
                                and s.date_2 between t.date_b and t.date_e
    where s.sum_m != isnull(cast(t.K_TARIF as decimal(15,2)),0)

-- Проверка №108.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, s.IDSERV, '904', 'Код услуги "'+isnull(s.CODE_USL,'')+'" нельзя использовать в случаях передаваемых файле '+SUBSTRING(z.FILENAME,1,1)
 from #TEMP_Z_SLUCH zs
  join #SCHET_USL s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','T','C')
 where substring(s.CODE_USL,1,1) in ('D','P')

-- Проверка №108 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, s.IDSERV, '904', 'Код услуги "'+isnull(s.CODE_USL,'')+'" нельзя использовать в случаях передаваемых файле D'
 from #TEMP_Z_SLUCH zs
  join #SCHET_USL s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('D')
 where substring(s.CODE_USL,1,1) not in ('D','P')

-- Проверка №107 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUM_M', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Cумма случая не равна сумме переданных к нему услуг'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  left join (select sum(u.sumv_usl) sumv_usl, u.idcase, u.sl_id from #SCHET_USL u group by u.idcase, u.sl_id) u on s.idcase=u.idcase and s.sl_id=u.sl_id        
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C','D')
 where isnull(u.sumv_usl,0) <> s.sum_m
   and zs.usl_ok in (3,4)
-- Проверка №106.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMV_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Не корректная сумма услуги. (Код услуги "'+isnull(u.CODE_USL,'')+'"TARIF="'+isnull(cast(u.TARIF as varchar),'')+'" KOL_USL="'
  +isnull(cast(u.KOL_USL as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C','D','T')
 where u.sumv_usl != round(isnull(u.tarif,0)*isnull(u.kol_usl,0),2)

-- Проверка №106 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMV_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Не корректная сумма услуги или отсутствует тариф на услугу. (Код услуги "'+isnull(u.CODE_USL,'')+'"TARIF="'+isnull(cast(u.TARIF as varchar),'')+'" K_TARIF="'
  +isnull(cast(t.k_tarif as varchar),'')+'" SUM_USL="'+isnull(cast(u.SUMV_USL as varchar),'')+'" K_SUM_USL="'+isnull(cast(round(isnull(t.k_tarif,0)*isnull(u.kol_usl,0),2) as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  left join [IES].[T_CHER_USL_TARIF_2018] t on (t.LPU=u.LPU or t.lpu is null) and t.USL_CODE=u.code_usl and u.date_out between t.DATE_B and t.DATE_E
   and t.k_tarif > 0
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C','D')
 where u.sumv_usl != round(isnull(t.k_tarif,0)*isnull(u.kol_usl,0),2)
       and zs.usl_ok in (3,4)
	   and zs.DATE_Z_2 < '01.01.2019'

-- Проверка №106 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMV_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Не корректная сумма услуги или отсутствует тариф на услугу. (Код услуги "'+isnull(u.CODE_USL,'')+'"TARIF="'+isnull(cast(u.TARIF as varchar),'')+'" K_TARIF="'
  +isnull(cast(t.k_tarif as varchar),'')+'" SUM_USL="'+isnull(cast(u.SUMV_USL as varchar),'')+'" K_SUM_USL="'+isnull(cast(round(isnull(t.k_tarif,0)*isnull(u.kol_usl,0),2) as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  left join [IES].[T_CHER_USL_TARIF] t on (t.LPU=u.LPU or t.lpu is null) and t.USL_CODE=u.code_usl and u.date_out between t.DATE_B and t.DATE_E
   and t.k_tarif > 0
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C','D')
 where u.sumv_usl != round(isnull(t.k_tarif,0)*isnull(u.kol_usl,0),2)
       and zs.usl_ok in (3,4)
	   and zs.DATE_Z_2 >= '01.01.2019'
--       and u.profil not in (85,86,87,88,89,90,63,171,140) 
--       and u.code_usl not in ('Z01.063.001','Z01.064.000','Z01.064.001','Z01.067.000')               

-- Проверка №105 (КС-2019) по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Диагноз DS1="'+isnull(cast(s.DS1 as varchar),'')+'"  + код услуги CODE_USL="'+isnull(cast(u.CODE_USL as varchar),'')+'" не может применяться в указанном КСГ N_KSG="'+isnull(cast(k.N_KSG as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  left join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID and u.sumv_usl = 0) 
  join #SCHET_KSG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where ((u.CODE_USL is not null and k.N_KSG not in  (SELECT a.[KSG]  FROM [IESDB].[IES].[T_GR_KSG_KS_2019] a
                     where (usl_code=u.CODE_USL or usl_code is null) 
					   and (s.DS1 between mkb and mkb_e or mkb is null  or s.DS1 between mkb2 and mkb2_e)
					   and a.ksg != 'st29.007'
                    )
				  ) 
  or (u.CODE_USL is null and k.N_KSG not in (SELECT  a.[KSG]  FROM [IESDB].[IES].[T_GR_KSG_KS_2019] a                      
                     where a.usl_code is null and (s.DS1 between mkb and mkb_e  or s.DS1 between mkb2 and mkb2_e) and a.ksg != 'st29.007'
)
				  )

    )
   and zs.USL_OK = 1 and k.VER_KSG = 2019
   and k.n_ksg != 'st29.007'
   and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693  and GETDATE() > '15.03.2019')) 
union 
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Диагноз DS1="'+isnull(cast(s.DS1 as varchar),'')+'"  + код услуги CODE_USL="'+isnull(cast(u.CODE_USL as varchar),'')+'" не может применяться в указанном КСГ N_KSG="'+isnull(cast(k.N_KSG as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  left join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID and u.sumv_usl = 0) 
  join #SCHET_KSG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where ((u.CODE_USL is not null and k.N_KSG not in  (SELECT a.[KSG]  FROM [IESDB].[IES].[T_GR_KSG_DS_2019] a
                     where (usl_code=u.CODE_USL or usl_code is null) 
					   and (s.DS1 between mkb and mkb_e or mkb is null or s.DS1 between mkb2 and mkb2_e)
                    )
				  ) 
  or (u.CODE_USL is null and k.N_KSG not in (SELECT  a.[KSG]  FROM [IESDB].[IES].[T_GR_KSG_DS_2019] a                      
                     where a.usl_code is null and (s.DS1 between mkb and mkb_e or s.DS1 between mkb2 and mkb2_e))
				  )

    )
   and zs.USL_OK = 2 and k.VER_KSG = 2019
   and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693  and GETDATE() > '15.03.2019')) 
 union
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Диагноз DS1="'+isnull(cast(s.DS1 as varchar),'')+'"  + код услуги CODE_USL="'+isnull(cast(u.CODE_USL as varchar),'')+'" не может применяться в указанном КСГ N_KSG="'+isnull(cast(k.N_KSG as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  left join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID and u.sumv_usl = 0) 
  join #SCHET_KSG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where ( 
    (u.CODE_USL is null and k.N_KSG in ('st01.010','st01.011','st14.001','st14.002','st21.001','st34.002','st30.006','st09.001','st31.002'))
     or (u.CODE_USL is not null and k.N_KSG in ('st02.008','st02.009','st04.002','st21.007','st34.001','st26.001','st30.003','st30.005','st31.017'))
    )
   and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693 and GETDATE() > '15.03.2019')) 

-- Проверка №104 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Отсутствует обязательная услуга для указанного КСГ'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  left join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID and u.sumv_usl = 0) 
  join #SCHET_KSG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join (select usl_ok, vers, n_ksg from [IES].[T_CHER_KSG_USL] group by usl_ok, vers, n_ksg) t on zs.usl_ok=t.usl_ok and k.n_ksg=t.n_ksg and k.ver_ksg=t.vers
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where u.idserv is null 

  -- Проверка №103.4  (FRAK) 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Количество фракций K_FR="'+isnull(cast(os.K_FR as varchar),'')+'"  не может применяться в указанном КСГ N_KSG="'+isnull(cast(k.N_KSG as varchar),'')+'" при DS1="'+
 isnull(cast(s.DS1 as varchar),'')+'" CRIT="'+isnull(cast(c.CRIT as varchar),'')+'" и CODE_USL="'+isnull(cast(u.CODE_USL as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  left join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID and u.sumv_usl = 0) 
  join #SCHET_KSG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  left join #SCHET_KSG_CRIT c on k.IDCASE=c.IDCASE and k.SL_ID=c.SL_ID
  left join #SCHET_SLUCH_ONK os on (os.IDCASE=s.IDCASE and os.SL_ID=s.SL_ID) 
 where exists (select 1 from [IES].[T_GR_KSG_KS_2019_1] a1 where k.N_KSG=a1.ksg and a1.frak is not null
 		                     and (a1.usl_code=u.CODE_USL or a1.usl_code is null) 
 		                     and (a1.crit=c.CRIT or a1.crit is null) 
                             and (s.DS1 between mkb and mkb_e or mkb is null  or s.DS1 between mkb2 and mkb2_e)
   )
   and (os.K_FR is null 
     or not exists (select 1 from [IES].[T_GR_KSG_KS_2019_1] a1 where k.N_KSG=a1.ksg and a1.usl_code=u.CODE_USL and isnull(a1.crit,'')=isnull(c.CRIT,'') and os.K_FR between a1.k_fr_min and a1.k_fr_max)
   )
   and zs.USL_OK = 1 and k.VER_KSG = 2019
   and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693  and GETDATE() > '15.03.2019')) 
   union
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Количество фракций K_FR="'+isnull(cast(os.K_FR as varchar),'')+'"  не может применяться в указанном КСГ N_KSG="'+isnull(cast(k.N_KSG as varchar),'')+'" при DS1="'+
 isnull(cast(s.DS1 as varchar),'')+'" и CODE_USL="'+isnull(cast(u.CODE_USL as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  left join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID and u.sumv_usl = 0) 
  join #SCHET_KSG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  left join #SCHET_KSG_CRIT c on k.IDCASE=c.IDCASE and k.SL_ID=c.SL_ID
  left join #SCHET_SLUCH_ONK os on (os.IDCASE=s.IDCASE and os.SL_ID=s.SL_ID) 
 where exists (select 1 from [IES].[T_GR_KSG_DS_2019_1] a1 where k.N_KSG=a1.ksg and a1.frak is not null
 		                     and (a1.usl_code=u.CODE_USL or a1.usl_code is null) 
 		                     and (a1.crit=c.CRIT or a1.crit is null) 
                             and (s.DS1 between mkb and mkb_e or mkb is null  or s.DS1 between mkb2 and mkb2_e)
   )
   and (os.K_FR is null 
     or not exists (select 1 from [IES].[T_GR_KSG_DS_2019_1] a1 where k.N_KSG=a1.ksg and a1.usl_code=u.CODE_USL  and isnull(a1.crit,'')=isnull(c.CRIT,'') and os.K_FR between a1.k_fr_min and a1.k_fr_max)
   )
   and zs.USL_OK = 2 and k.VER_KSG = 2019
   and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693  and GETDATE() > '15.03.2019')) 

-- Проверка №103.1  (ДС-2019) 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Классификационный критерий CRIT="'+isnull(cast(c.CRIT as varchar),'')+'"  не может применяться в указанном КСГ N_KSG="'+isnull(cast(k.N_KSG as varchar),'')+'" при DS1="'+
 isnull(cast(s.DS1 as varchar),'')+'" и CODE_USL="'+isnull(cast(u.CODE_USL as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  left join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID and u.sumv_usl = 0) 
  join #SCHET_KSG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  left join #SCHET_KSG_CRIT c on k.IDCASE=c.IDCASE and k.SL_ID=c.SL_ID
 where ((
         exists (select 1 from [IES].[T_GR_KSG_KS_2019] a1 where k.N_KSG=a1.ksg and a1.crit is not null
 		                        and (a1.usl_code=u.CODE_USL or a1.usl_code is null) 
                               and (s.DS1 between mkb and mkb_e or mkb is null  or s.DS1 between mkb2 and mkb2_e)
                )
        and (c.CRIT is null 
             or c.CRIT not in (select a1.crit from [IES].[T_GR_KSG_KS_2019] a1 where k.N_KSG=a1.ksg and a1.crit is not null)
         )
		) 
		or
   (
      c.CRIT not in (select a1.CRIT from [IES].[T_GR_KSG_KS_2019] a1 where k.N_KSG=a1.ksg and a1.crit is not null
 		                        and (a1.usl_code=u.CODE_USL or a1.usl_code is null) 
                               and (s.DS1 between mkb and mkb_e or mkb is null  or s.DS1 between mkb2 and mkb2_e)
                )
        and c.CRIT is not null 
	))
   and zs.USL_OK = 1 and k.VER_KSG = 2019
   and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693  and GETDATE() > '15.03.2019')) 
   union
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Классификационный критерий CRIT="'+isnull(cast(c.CRIT as varchar),'')+'"  не может применяться в указанном КСГ N_KSG="'+isnull(cast(k.N_KSG as varchar),'')+'" при DS1="'+
 isnull(cast(s.DS1 as varchar),'')+'" и CODE_USL="'+isnull(cast(u.CODE_USL as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  left join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID and u.sumv_usl = 0) 
  join #SCHET_KSG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  left join #SCHET_KSG_CRIT c on k.IDCASE=c.IDCASE and k.SL_ID=c.SL_ID
 where ((
         exists (select 1 from [IES].[T_GR_KSG_DS_2019] a1 where k.N_KSG=a1.ksg and a1.crit is not null
 		                        and (a1.usl_code=u.CODE_USL or a1.usl_code is null) 
                               and (s.DS1 between mkb and mkb_e or mkb is null  or s.DS1 between mkb2 and mkb2_e)
                )
        and (c.CRIT is null 
             or c.CRIT not in (select a1.crit from [IES].[T_GR_KSG_DS_2019] a1 where k.N_KSG=a1.ksg and a1.crit is not null)
         )
		) 
		or
   (
      c.CRIT not in (select a1.CRIT from [IES].[T_GR_KSG_DS_2019] a1 where k.N_KSG=a1.ksg and a1.crit is not null
 		                        and (a1.usl_code=u.CODE_USL or a1.usl_code is null) 
                               and (s.DS1 between mkb and mkb_e or mkb is null  or s.DS1 between mkb2 and mkb2_e)
                )
        and c.CRIT is not null 
	))
and zs.USL_OK = 2 and k.VER_KSG = 2019
   and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693  and GETDATE() > '15.03.2019')) 
/*
  -- Проверка №103 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Некорректный код услуги в рамках КСГ'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  inner join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID and u.sumv_usl = 0) 
  join #SCHET_KSG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where exists (select 1 from [IES].[T_CHER_KSG_USL] t where zs.usl_ok=t.usl_ok and k.n_ksg=t.n_ksg and k.ver_ksg=t.vers)
   and not exists (select 1 from [IES].[T_CHER_KSG_USL] t where zs.usl_ok=t.usl_ok and k.n_ksg=t.n_ksg and k.ver_ksg=t.vers and u.CODE_USL=t.usl_code)
   and u.code_usl like 'A%'
   and u.code_usl not in (select t.usl_code from [IES].T_CHER_KSG_KSLP t)
*/
-- Проверка №102.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMV_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'При ВМП стоимость услуги не должна быть больше 0'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_USL u on u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('T')
 where u.sumv_usl > 0 and u.CODE_USL not in ('A18.05.002', 'A18.05.002.001', 'A18.05.002.002', 'A18.05.002.003', 'A18.05.002.005', 'A18.05.003', 'A18.05.003.002', 
 'A18.05.004', 'A18.05.004.001','A18.05.011','A18.05.011.001','A18.05.011.002','A18.30.001','A18.30.001.001','A18.30.001.002','A18.30.001.003','A18.05.001.001','A18.05.001.004')

-- Проверка №102 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMV_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'При использовании КСГ стоимость услуги не должна быть больше 0'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_USL u on u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID 
  join #SCHET_KSG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where u.sumv_usl > 0 and u.CODE_USL not in ('A18.05.002', 'A18.05.002.001', 'A18.05.002.002', 'A18.05.002.003', 'A18.05.002.005', 'A18.05.003', 'A18.05.003.002', 
 'A18.05.004', 'A18.05.004.001','A18.05.011','A18.05.011.001','A18.05.011.002','A18.30.001','A18.30.001.001','A18.30.001.002','A18.30.001.003','A18.05.001.001','A18.05.001.004')

-- Проверка №101 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PLAT', 'SCHET', null, null, null, '904', 'Для счетов по МТР поле PLAT должно быть пустым.'
 from #SCHET t
 where t.PLAT is not null and @type=554

-- Проверка №100 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PLAT', 'SCHET', null, null, null, '904', 'Не указан прательщик.'
 from #SCHET t
 where t.PLAT is null and @type=693

-- Проверка №99 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PLAT', 'SCHET', null, null, null, '904', 'Значение PLAT="'+isnull(cast(t.PLAT as varchar),'')+'" не соответствует допустимому значению  в справочнике F002'
 from #SCHET t
  left join [IES].[T_F002_SMO] t3 on t.plat=t3.SMOCOD and t.DSCHET between t3.D_BEGIN and isnull(t3.D_END,t.DSCHET)
 where t3.SMOCOD is null and @type=693

-- Проверка №98.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAPR_USL', 'NAPR', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан код медицинской услуги (NAPR_USL) при заполненном методе диагностического исследования'
 from #TEMP_Z_SLUCH zs
  join  #TEMP_SLUCH t1 on zs.IDCASE=t1.IDCASE
  join #SCHET_USL_NAPR t on (t.IDCASE=t1.IDCASE and t.SL_ID=t1.SL_ID) 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('T','C')
 where t.MET_ISSL is not null and t.NAPR_USL is null

-- Проверка №98 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAPR_USL', 'NAPR', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAPR_USL="'+isnull(cast(t.NAPR_USL as varchar),'')+'" не соответствует допустимому значению  в справочнике V001'
 from #TEMP_Z_SLUCH zs
  join  #TEMP_SLUCH t1 on zs.IDCASE=t1.IDCASE
  join #SCHET_USL_NAPR t on (t.IDCASE=t1.IDCASE and t.SL_ID=t1.SL_ID) 
  left join [IES].[T_V001_NOMENCLATURE] t3 on t.NAPR_USL=t3.Code --and t1.DATE_1 between t3.DATEBEG and isnull(t3.DATEEND,t1.DATE_1)
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('T','C')
 where t3.Code is null and t.NAPR_USL is not null

-- Проверка №97.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'VID_VME', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Указанный код ВМВ VID_VME="'+isnull(cast(s.VID_VME as varchar),'')+'" не может применяться для услуги CODE_USL="'+
  isnull(cast(s.CODE_USL as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join  #TEMP_SLUCH t on zs.IDCASE=t.IDCASE
  join #SCHET_USL s on s.IDCASE=t.IDCASE and s.SL_ID=t.SL_ID 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('T','C')
  join IES.R_NSI_USL_V001 t0 on s.CODE_USL=t0.CODE_USL
  left join IES.T_V001_NOMENCLATURE t14 on t0.Nomenclature=t14.NomenclatureID
 where s.VID_VME is not null 
   and s.VID_VME != t14.Code
   and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693 and GETDATE() > '15.03.2019')) 

-- Проверка №97.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'VID_VME', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан код ВМВ при установленном диагнозе ЗНО'
 from #TEMP_Z_SLUCH zs
  join  #TEMP_SLUCH t on zs.IDCASE=t.IDCASE
  join #SCHET_USL s on s.IDCASE=t.IDCASE and s.SL_ID=t.SL_ID 
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('T','C')
 where s.VID_VME is null 
   and (substring(t.ds1,1,1) = 'C' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS from #TEMP_DS ds where (ds.DS between 'C00' and 'C80.9' or  ds.ds between 'C97' and 'C97.9'))))

-- Проверка №97 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'VID_VME', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение VID_VME="'+isnull(cast(s.VID_VME as varchar),'')+'" не соответствует допустимому значению  в справочнике V001'
 from #TEMP_Z_SLUCH zs
   join #TEMP_SLUCH sl on (sl.IDCASE=zs.IDCASE) 
  join #SCHET_USL s on (s.IDCASE=sl.IDCASE and  s.SL_ID=sl.SL_ID) 
  left join [IES].[T_V001_NOMENCLATURE] t3 on s.VID_VME=t3.Code --and zs.DATE_Z_2 between t3.DATEBEG and isnull(t3.DATEEND,zs.DATE_Z_2)
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','T','C')
 where t3.Code is null and s.VID_VME is not null

-- Проверка №95.3 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDSL', 'SL_KOEF', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение поля IT_SL не соответствует сумме переданных коэфециентов в блоке SL_KOEF'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_KSG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where  k.IT_SL != (SELECT sum(sl.Z_SL-1)+1 FROM #SCHET_KSG_KOEF sl where sl.IDCASE=s.IDCASE and sl.SL_ID=s.SL_ID)


-- Проверка №95.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDSL', 'SL_KOEF', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректный КСЛП либо коэффециенты к нему'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_KSG_KOEF sl on sl.IDCASE=s.IDCASE and sl.SL_ID=s.SL_ID
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where not exists(SELECT top 1 t.DictionaryBaseID FROM [IES].[R_NSI_KSLP] t WHERE t.IDSL=sl.IDSL and t.ZKOEF=sl.Z_SL and s.DATE_2 between t.DATE_BEGIN and t.DATE_END)
 
-- Проверка №95.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'N_KSG', 'KSG_KPG', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение CRIT="'+isnull(cast(k.CRIT as varchar),'')+'" не соответствует допустимому значению  в справочнике'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_KSG_CRIT k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  left join [IES].[T_V024_DOP_KR] t3 on k.CRIT=t3.IDDKK and zs.DATE_Z_2 between t3.DATEBEG and isnull(t3.DATEEND,zs.DATE_Z_2)
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where t3.IDDKK is null and k.CRIT is not null

-- Проверка №95 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'N_KSG', 'KSG_KPG', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректный КСГ либо коэффециенты к нему'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_KSG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where (not exists(SELECT top 1 t.DictionaryBaseID FROM [IES].[T_SPR_KSG_TARIF] t WHERE t.LPU=zs.lpu and t.USL_OK=zs.usl_ok and t.F_KSG_CODE=k.n_ksg and t.VERS=k.ver_ksg
  and t.K_BAZA=k.bztsz and t.K_ZATR=k.koef_z and t.K_UPR=k.koef_up and t.K_UR=k.koef_u and t.IDPR = s.PROFIL)
  and zs.lpu not in ('400130','400131','400132'))
  or k.KOEF_D <> 1 

-- Проверка №95.0 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'N_KSG', 'KSG_KPG', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректный КСГ либо коэффециенты к нему'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_KSG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where (not exists(SELECT top 1 t.DictionaryBaseID FROM [IES].[T_SPR_KSG_TARIF] t WHERE t.LPU=zs.lpu and t.LPU_1=s.LPU_1 and t.USL_OK=zs.usl_ok and t.F_KSG_CODE=k.n_ksg and t.VERS=k.ver_ksg
  and t.K_BAZA=k.bztsz and t.K_ZATR=k.koef_z and t.K_UPR=k.koef_up and t.K_UR=k.koef_u and t.IDPR = s.PROFIL)
  and zs.lpu in ('400130','400131','400132'))
  or k.KOEF_D <> 1 

  -- Проверка №94 (расчет на 2019 год) 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUM_M', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректный расчет стоимости по КСГ '+cast(k.N_KSG as varchar)+' SUM_M="'+cast(s.sum_m as varchar)+'" SUM_M_R="'+cast(
  round(k.koef_z * k.koef_up * case k.koef_d when 0 then 1 else k.koef_d end * k.koef_u * k.bztsz * case k.SL_K when 1 then k.IT_SL else 1 end * 
	   isnull(l.koef, case when s.kd in (1,2,3) then 0.5 else 1 end) ,2) + (select isnull(sum(u.sumv_usl),0) from #SCHET_USL u where u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) as varchar)+
	   '"' 
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_KSG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  left join [IES].[T_CHER_KSG_KDP] l on cast(l.n_ksg as varchar)=k.n_ksg 
                                         and s.date_2 between l.date_b and l.date_e 
                                         and s.kd between l.kdp_b and l.kdp_e 
                                         and zs.usl_ok=l.usl_ok
  left join (SELECT v.idcase, v.sl_id, 1 + SUM (v.idsl - 1) kslp_koef from  #SCHET_KSG_KOEF v group by v.idcase, v.sl_id) v on s.idcase=v.idcase and s.sl_id=v.sl_id
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
      where s.sum_m != round(k.koef_z * k.koef_up * case k.koef_d when 0 then 1 else k.koef_d end * k.koef_u * k.bztsz * case k.SL_K when 1 then k.IT_SL else 1 end *--isnull(v.kslp_koef,1) * 
	   isnull(l.koef, case when s.kd in (1,2,3) then 0.5 else 1 end) ,2) + (select isnull(sum(u.sumv_usl),0) from #SCHET_USL u where u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID)
		and zs.DATE_Z_2 >= '01.01.2019'

  -- Проверка №94 (расчет на 2018 год)
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUM_M', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректный расчет стоимости по КСГ'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_KSG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  left join [IES].[T_CHER_KSG_KDP] l on cast(l.ksg as varchar)=k.n_ksg 
                                         and s.date_1 between l.date_b and l.date_e 
                                         and s.kd between l.kdp_b and l.kdp_e 
                                         and zs.usl_ok=l.usl_ok
  left join (SELECT v.idcase, v.sl_id, 1 + SUM (v.idsl - 1) kslp_koef from  #SCHET_KSG_KOEF v group by v.idcase, v.sl_id) v on s.idcase=v.idcase and s.sl_id=v.sl_id
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
      where s.sum_m != round(k.koef_z * k.koef_up * case k.koef_d when 0 then 1 else k.koef_d end * k.koef_u * k.bztsz * isnull(v.kslp_koef,1) * 
	   isnull(l.koef, case zs.usl_ok when 1 then case s.kd when 1 then 0.2 when 2 then 0.3 when 3 then 0.4 else 1 end
	                                 when 2 then case s.kd when 1 then 0.5 when 2 then 0.5 when 3 then 0.5 else 1 end 
					  end) ,2)
		and zs.DATE_Z_2 < '01.01.2019'


-- Проверка №93.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_PK', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан код профиля койки (NAZ_PK) при направлении на реабилитацию'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
  inner join #TEMP_SL_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
 where n.naz_r = 6 and n.naz_pk is null

-- Проверка №93 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_PK', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAZ_PK="'+isnull(cast(n.NAZ_PK as varchar),'')+'" не соответствует допустимому значению  в справочнике'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
  inner join #TEMP_SL_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
  left join [IES].[T_V020_BED_PROFILE] v on n.naz_pk = v.idk_pr
 where v.idk_pr is null and n.naz_pk is not null
   

-- Проверка №92.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_PMP', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан код профиля медицинской помощи (NAZ_PMP) при направлении на госпитализацию'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
  inner join #TEMP_SL_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
 where n.naz_r in (4,5) and n.naz_pmp is null
   

-- Проверка №92 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_PMP', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAZ_PMP="'+isnull(cast(n.NAZ_PMP as varchar),'')+'>" не соответствует допустимому значению  в справочнике V002'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
  inner join #TEMP_SL_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
  left join [IES].[T_V002_PROFILE] v on n.naz_pmp = v.idpr
 where n.naz_pmp is not null and v.idpr is null
   

-- Проверка №91.6 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAPR_DATE', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Дата направления (NAPR_DATE) выходит за пределы случая лечения (DATE_1-DATE_2).'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
  inner join #TEMP_SL_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
 where n.NAPR_DATE < s.DATE_1 and n.NAPR_DATE > s.DATE_2

-- Проверка №91.6 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAPR_MO', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAPR_MO="'+isnull(cast(n.NAPR_MO as varchar),'')+'" не соответствует допустимому значению  в справочнике F003'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
  inner join #TEMP_SL_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
  left join [IES].[T_F003_MO] t1 on n.NAPR_MO=t1.MCOD and n.NAPR_DATE between t1.D_BEGIN and isnull(t1.D_END,n.NAPR_DATE)
 where t1.MCOD is null and n.napr_mo is not null

-- Проверка №91.5 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAPR_MO', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан код МО (NAPR_MO) в которое отправили на консультацию при подозрении на ЗНО'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
  inner join #TEMP_SL_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
 where n.NAZ_R in (2,3) and s.ds_onk=1 and n.napr_mo is null

-- Проверка №91.4 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAPR_DATE', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указана дата направления (NAPR_DATE) на консультацию в другое МО при подозрении на ЗНО'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
  inner join #TEMP_SL_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
 where n.NAZ_R in (2,3) and s.ds_onk=1 and n.napr_date is null

-- Проверка №91.3 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_USL', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан код медицинской услуги (NAZ_USL) при направлении на обследование при подозрении на ЗНО'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
  inner join #TEMP_SL_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
 where n.NAZ_R=3 and s.ds_onk=1 and n.naz_usl is null

-- Проверка №91.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_USL', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAZ_USL="'+isnull(cast(n.NAZ_USL as varchar),'')+'" не соответствует допустимому значению  в справочнике V001'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
  inner join #TEMP_SL_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
   left join [IES].[T_V001_NOMENCLATURE] t3 on n.NAZ_USL=t3.Code --and s.DATE_1 between t3.DATEBEG and isnull(t3.DATEEND,s.DATE_1)
 where t3.Code is null and n.NAZ_USL is not null

-- Проверка №91.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_V', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан метод диагностического исследования (NAZ_V) при направлении на обследование'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
  inner join #TEMP_SL_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
 where n.NAZ_R=3 and n.naz_v is null

-- Проверка №91 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_V', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAZ_V="'+isnull(cast(n.NAZ_V as varchar),'')+'" не соответствует допустимому значению  в справочнике'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
  inner join #TEMP_SL_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
  left join [IES].[T_V029_MET_ISSL] v on n.naz_v = v.IDMET and zs.DATE_Z_1 between v.DATEBEG and isnull(v.DATEEND,zs.DATE_Z_1)
 where v.IDMET is null and n.naz_v is not null

-- Проверка №90.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_SP', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указана специальность врача (NAZ_SP) при направлении на консультацию'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
  join #TEMP_SL_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
 where n.naz_r in (1,2) and n.NAZ_SP is null

-- Проверка №90 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_SP', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAZ_SP="'+isnull(cast(n.naz_sp as varchar),'')+'" не соответствует допустимому значению  в справочнике'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
  inner join #TEMP_SL_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
  left join [IES].[T_V021_MED_SPEC] v on n.naz_sp = v.idspec
 where v.idspec is null and n.naz_sp is not null

-- Проверка №89.2 по базе в ОРАКЛЕ 
 --insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 --select 'NAZ', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Блок NAZ должен быть заполнен при присвоении группы здоровья отличной от I или II.'
 --from #TEMP_Z_SLUCH zs
 -- join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
 -- join #SCHET z on substring(z.FILENAME,1,1) in ('D')
 --where zs.rslt_d in (3,4,5,14,15,17,18,19,31,32) and not exists(select 1 from #TEMP_SL_NAZ n where s.idcase=n.idcase and s.sl_id=n.sl_id)


-- Проверка №89.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Блок NAZ должен быть пустым при присвоении группы здоровья I или II.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
 where zs.rslt_d in (1,2,11,12) and exists(select 1 from #TEMP_SL_NAZ n where s.idcase=n.idcase and s.sl_id=n.sl_id)

-- Проверка №89 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_R', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAZ_R="'+isnull(cast(n.naz_r as varchar),'')+'" не соответствует допустимому (1,2,3,4,5,6).'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
  inner join #TEMP_SL_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
 where n.naz_r not in (1,2,3,4,5,6) or n.naz_r is null

-- Проверка №88.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS2', 'DS2_N', zs.N_ZAP, zs.IDCASE, null, '904', 'Код DS2 в блоке DS2_N указан без подрубрики.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
  inner join #TEMP_DS n on s.idcase=n.idcase and s.sl_id=n.sl_id and n.DS_TYPE=0 and n.DS2_PR is not null
  LEFT JOIN  ies.R_MKB_10 mkb on mkb.MKB10CODE = n.DS and mkb.priznak = 1
 where len(n.DS) = 3
       AND n.DS NOT IN
       ('A33', 'A34', 'A38', 'A46', 'A55', 'A57', 'A58', 'A64', 'A65', 'A70', 'A78', 'A89', 'A90', 'A91', 'A94', 'A99', 'B03', 'B04', 'B07', 'B09',
            'B54', 'B59', 'B64', 'B72', 'B73', 'B75', 'B79', 'B80', 'B86', 'B89', 'B91', 'B92', 'B99', 'C01', 'C07', 'C12', 'C20', 'C23', 'C33', 'C37',
            'C52', 'C55', 'C56', 'C58', 'C61', 'C64', 'C65', 'C66', 'C73', 'C97', 'D27', 'D34', 'D45', 'D65', 'D66', 'D67', 'D70', 'D71', 'D77', 'E02',
            'E15', 'E40', 'E41', 'E42', 'E43', 'E45', 'E46', 'E52', 'E54', 'E58', 'E59', 'E60', 'E65', 'E68', 'E86', 'E90', 'G07', 'G08', 'G09', 'G10',
            'G20', 'G26', 'G35', 'H55', 'H71', 'H82', 'I00', 'I10', 'I38', 'I81', 'I99', 'J00', 'J13', 'J14', 'J22', 'J36', 'J40', 'J46', 'J47', 'J60',
            'J61', 'J64', 'J65', 'J80', 'J81', 'J82', 'J90', 'J91', 'K20', 'K36', 'K37', 'L00', 'L14', 'L26', 'L42', 'L52', 'L80', 'L82', 'L83', 'L84',
            'L86', 'L88', 'L97', 'M45', 'N12', 'N19', 'N23', 'N26', 'N40', 'N44', 'N46', 'N47', 'N61', 'N62', 'N63', 'N72', 'N86', 'N96', 'O11', 'O13',
            'O16', 'O25', 'O40', 'O48', 'O85', 'O95', 'O96', 'O97', 'P38', 'P53', 'P60', 'P75', 'P77', 'P90', 'P93', 'P95', 'Q02', 'R05', 'R11', 'R12',
            'R13', 'R14', 'R15', 'R17', 'R18', 'R21', 'R31', 'R32', 'R33', 'R34', 'R35', 'R36', 'R42', 'R53', 'R55', 'R72', 'R51', 'R69', 'S16', 'S18',
            'T07', 'T16', 'T55', 'T58', 'T64', 'T66', 'T68', 'T97', 'Z21', 'B24', 'B49', 'C19', 'D24', 'D62', 'G01', 'G22', 'G92', 'G98', 'J42', 'K20',
            'K30', 'L22', 'L45', 'N10', 'R02', 'S47', 'Z33', 'T71', 'A35', 'A86', 'F03', 'F04', 'F09', 'F21', 'F24', 'F28', 'F29', 'F39', 'F54', 'F55',
            'F59', 'F61', 'F69', 'F82', 'F83', 'F88', 'F89', 'F99', 'G14', 'G64', 'H46', 'J09', 'O94', 'R54', 'R58', 'R64', 'R71', 'R75', 'R80', 'R81',
            'R91', 'R92', 'R95', 'R98', 'R99', 'T96', 'I64')

-- Проверка №88.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS2', 'DS2_N', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение DS2="'+isnull(cast(n.DS as varchar),'')+'" не соответствует допустимому.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
  inner join #TEMP_DS n on s.idcase=n.idcase and s.sl_id=n.sl_id and n.DS_TYPE=0 and n.DS2_PR is not null
  LEFT JOIN  ies.R_MKB_10 mkb on mkb.MKB10CODE = n.DS and mkb.priznak = 1
 where mkb.MKB10CODE is null and n.DS is not null

-- Проверка №88 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS2', 'DS2_N', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение PR_DS2_N="'+isnull(cast(n.pr_ds2_n as varchar),'')+'" не соответствует допустимому.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
  inner join #TEMP_DS n on s.idcase=n.idcase and s.sl_id=n.sl_id and n.DS_TYPE=0 and n.DS2_PR is not null
 where n.pr_ds2_n not in (1,2,3) or n.pr_ds2_n is null
 
-- Проверка №87 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PR_D_N', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение PR_D_N="'+isnull(cast(s.pr_d_n as varchar),'')+'" не соответствует допустимому.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
 where s.pr_d_n not in (1,2,3)

-- Проверка №86 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'P_OTK', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение P_OTK="'+isnull(cast(zs.P_OTK as varchar),'')+'" не соответствует допустимому.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
 where zs.p_otk not in (0,1) or zs.p_otk is null

-- Проверка №85 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'VBR', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение VBR="'+isnull(cast(zs.VBR as varchar),'')+'" не соответствует допустимому.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
 where zs.vbr not in (0,1) or zs.vbr is null

-- Проверка №84 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'TAL_P', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Датавыдачи талона на ВМП (TAL_P) больше даты госпитализации  при плановой помощи'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('T')
 where s.tal_p > s.date_1 and zs.FOR_POM = 3

-- Проверка №83 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'TAL_D', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Датавыдачи талона на ВМП (TAL_D) больше даты госпитализации при плановой помощи'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET z on substring(z.FILENAME,1,1) in ('T')
 where s.tal_d > s.date_1 and zs.FOR_POM = 3

 -- Проверка №82.7 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_SH', 'LEK_PR', zs.N_ZAP, zs.IDCASE, null, '904', 'Для значения CODE_SH="'+isnull(cast(t2.CODE_SH as varchar),'')+'" не указано значение  классификационного критерия (CRIT)'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK t1 on t1.IDCASE=zs.IDCASE
  join #SCHET_USL_ONK uo on uo.idcase=t1.idcase and uo.SL_ID=t1.SL_ID
  join #SCHET_USL_ONK_LEK_PR t2 on uo.idcase=t2.idcase and uo.SL_ID=t2.SL_ID
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('C')
 where not exists (select 1 from #SCHET_KSG_CRIT c where c.IDCASE=t1.IDCASE and c.SL_ID=t1.SL_ID) 

 -- Проверка №82.6 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_INJ', 'LEK_PR', zs.N_ZAP, zs.IDCASE, null, '904', 'Дата введения лекарственного препарата (DATE_INJ) выходит за пределы случая лечения (DATE_1-DATE_2).'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK t1 on t1.IDCASE=zs.IDCASE
  join #SCHET_USL_ONK uo on uo.idcase=t1.idcase and uo.SL_ID=t1.SL_ID
  join #SCHET_USL_ONK_LEK_PR t2 on uo.idcase=t2.idcase and uo.SL_ID=t2.SL_ID
  join #SCHET_USL_ONK_LEK_PR_DATE t4 on t4.idcase=t2.idcase and t4.SL_ID=t2.SL_ID
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where t4.DATE_INJ < zs.DATE_Z_1 or t4.DATE_INJ > zs.DATE_Z_2

 -- Проверка №82.5 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_INJ', 'LEK_PR', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указана дата введения лекарственного препарата (DATE_INJ)'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK t1 on t1.IDCASE=zs.IDCASE
  join #SCHET_USL_ONK uo on uo.idcase=t1.idcase and uo.SL_ID=t1.SL_ID
  join #SCHET_USL_ONK_LEK_PR t2 on uo.idcase=t2.idcase and uo.SL_ID=t2.SL_ID
  left join #SCHET_USL_ONK_LEK_PR_DATE t4 on t4.idcase=t2.idcase and t4.SL_ID=t2.SL_ID
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where t4.DATE_INJ is null and t2.REGNUM is not null

 -- Проверка №82.4 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_SH', 'LEK_PR', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение CODE_SH="'+isnull(cast(t2.CODE_SH as varchar),'')+'" не соответствует допустимому значению  в справочнике N024'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK t1 on t1.IDCASE=zs.IDCASE
  join #SCHET_USL_ONK uo on uo.idcase=t1.idcase and uo.SL_ID=t1.SL_ID
  join #SCHET_USL_ONK_LEK_PR t2 on uo.idcase=t2.idcase and uo.SL_ID=t2.SL_ID
  left join [IES].[T_V024_DOP_KR] t3 on t2.CODE_SH=t3.IDDKK and zs.DATE_Z_2 between t3.DATEBEG and isnull(t3.DATEEND,zs.DATE_Z_2)
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where t3.IDDKK is null
 -- Проверка №82.3 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'REGNUM', 'LEK_PR', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение REGNUM="'+isnull(cast(t2.REGNUM as varchar),'')+'" не соответствует допустимому значению  в справочнике N020'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK t1 on t1.IDCASE=zs.IDCASE
  join #SCHET_USL_ONK uo on uo.idcase=t1.idcase and uo.SL_ID=t1.SL_ID
  join #SCHET_USL_ONK_LEK_PR t2 on uo.idcase=t2.idcase and uo.SL_ID=t2.SL_ID
  left join [IES].[T_N020_ONK_LEKP] t3 on t2.REGNUM=t3.ID_LEKP and zs.DATE_Z_2 between t3.DATEBEG and isnull(t3.DATEEND,zs.DATE_Z_2)
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where t3.ID_LEKP is null

 -- Проверка №82.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'LEK_PR', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указаны сведения о введенном противоопухолевом лекарственном препарате (LEK_PR)'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK t1 on t1.IDCASE=zs.IDCASE
  join #SCHET_USL_ONK uo on uo.idcase=t1.idcase and uo.SL_ID=t1.SL_ID
  left join #SCHET_USL_ONK_LEK_PR t2 on uo.idcase=t2.idcase and uo.SL_ID=t2.SL_ID
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where t2.REGNUM is null and uo.usl_tip in (2,4)
 
 
 -- Проверка №82.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'LUCH_TIP', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'При USL_TIP="'+isnull(cast(uo.USL_TIP as varchar),'')+'" поле LUCH_TIP должно быть пустым.'
 from #TEMP_Z_SLUCH zs
  join #SCHET_USL_ONK uo on uo.idcase=zs.idcase
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
  where (uo.LUCH_TIP is not null and uo.usl_tip not in (3,4))
 
 -- Проверка №82 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'LUCH_TIP', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение LUCH_TIP="'+isnull(cast(uo.LUCH_TIP as varchar),'')+'" не соответствует допустимому значению  в справочнике'
 from #TEMP_Z_SLUCH zs
  join #SCHET_USL_ONK uo on uo.idcase=zs.idcase
  left join [IES].[T_N017_RADIATION_THERAPY_TYPES] n on uo.luch_tip=n.id_tluch  and zs.DATE_Z_2 between n.DATEBEG and isnull(n.DATEEND,zs.DATE_Z_2)
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
      where n.id_tluch is null and uo.usl_tip in (3,4)

-- Проверка №81.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PPTR', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение PPTR="'+isnull(cast(uo.PPTR as varchar),'')+'" не соответствует допустимому.'
 from #TEMP_Z_SLUCH zs
  join #SCHET_USL_ONK uo on uo.idcase=zs.idcase
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
     where uo.PPTR is not null and uo.PPTR != 1

-- Проверка №81.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'LEK_TIP_V', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'При USL_TIP не равном 2 поле LEK_TIP_V должно быть пустым.'
 from #TEMP_Z_SLUCH zs
  join #SCHET_USL_ONK uo on uo.idcase=zs.idcase
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
     where uo.LEK_TIP_V is not null and uo.USL_TIP != 2

-- Проверка №81 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'LEK_TIP_V', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение LEK_TIP_V="'+isnull(cast(uo.lek_tip_v as varchar),'')+'" не соответствует допустимому значению  в справочнике N016'
 from #TEMP_Z_SLUCH zs
  join #SCHET_USL_ONK uo on uo.idcase=zs.idcase
  left join [IES].[T_N016_DRUG_THERAPY_CYCLES] n on uo.lek_tip_v=n.id_tlek_v and zs.DATE_Z_2 between n.DATEBEG and isnull(n.DATEEND,zs.DATE_Z_2)
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
      where n.id_tlek_v is null and uo.USL_TIP = 2

-- Проверка №80.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'LEK_TIP_L', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'При USL_TIP не равном 2 поле LEK_TIP_L должно быть пустым.'
 from #TEMP_Z_SLUCH zs
  join #SCHET_USL_ONK uo on uo.idcase=zs.idcase
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
     where uo.LEK_TIP_L is not null and uo.USL_TIP != 2

-- Проверка №80 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'LEK_TIP_L', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение LEK_TIP_L="'+isnull(cast(uo.lek_tip_l as varchar),'')+'" не соответствует допустимому значению  в справочнике N015'
 from #TEMP_Z_SLUCH zs
  join #SCHET_USL_ONK uo on uo.idcase=zs.idcase
  left join [IES].[T_N015_DRUG_THERAPY_LINES] n on uo.lek_tip_l=n.id_tlek_l and zs.DATE_Z_2 between n.DATEBEG and isnull(n.DATEEND,zs.DATE_Z_2)
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
     where n.id_tlek_l is null and uo.USL_TIP = 2

-- Проверка №79.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'HIR_TIP', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'При значение USL_TIP не равном 1, поле HIR_TIP должно быть пустым'
 from #TEMP_Z_SLUCH zs
  join #SCHET_USL_ONK uo on uo.idcase=zs.idcase
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
     where uo.HIR_TIP is not null and uo.usl_tip != 1

-- Проверка №79 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'HIR_TIP', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение HIR_TIP="'+isnull(cast(uo.HIR_TIP as varchar),'')+'" не соответствует допустимому значению  в справочнике N014'
 from #TEMP_Z_SLUCH zs
  join #SCHET_USL_ONK uo on uo.idcase=zs.idcase
  left join [IES].[T_N014_SURG_TREAT] n on uo.hir_tip=n.id_thir and zs.DATE_Z_2 between n.DATEBEG and isnull(n.DATEEND,zs.DATE_Z_2)
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
     where (n.id_thir is null and uo.usl_tip = 1)
--         or (n.id_thir is not null and uo.usl_tip != 1)

-- Проверка №78.6 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS1_T', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение DS1_T="'+isnull(cast(uo.DS1_T as varchar),'')+'" не соответствует примененному коду услуги CODE_USL="'+isnull(cast(u.CODE_USL as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH sl on sl.idcase=zs.idcase
  join #SCHET_USL u on u.idcase=sl.idcase and u.SL_ID=sl.SL_ID
  join ies.R_NSI_USL_V001 v001 on u.CODE_USL=v001.CODE_USL and v001.usltype = '2c0c3297-8235-4e38-9bd1-d5357a9265df'
  left join #SCHET_SLUCH_ONK uo on uo.idcase=zs.idcase and uo.SL_ID=sl.SL_ID
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('C','T')
 where (zs.usl_ok=3 and ds_onk=0 and isnull(uo.DS1_T,6) != 6)

-- Проверка №78.5 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS1_T', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение DS1_T="'+isnull(cast(uo.DS1_T as varchar),'')+'" не соответствует примененному условию оказания МП USL_OK="'+isnull(cast(zs.USL_OK as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH sl on sl.idcase=zs.idcase
  left join #SCHET_SLUCH_ONK uo on uo.idcase=zs.idcase and uo.SL_ID=sl.SL_ID
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('C')
 where (zs.usl_ok in (1,2) and ds_onk=0 and isnull(uo.DS1_T,3) in (3,4))
    or (zs.usl_ok=3 and ds_onk=0 and isnull(uo.DS1_T,3) in (0,1,2))
	or (zs.usl_ok=3 and ds_onk=0 and isnull(uo.DS1_T,5) = 5 and sl.PROFIL not in(78,34,38,111,106))

-- Проверка №78.5 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS1_T', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение DS1_T="'+isnull(cast(uo.DS1_T as varchar),'')+'" не соответствует примененному условию оказания МП USL_OK="'+isnull(cast(zs.USL_OK as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH sl on sl.idcase=zs.idcase
  left join #SCHET_SLUCH_ONK uo on uo.idcase=zs.idcase and uo.SL_ID=sl.SL_ID
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T')
 where (isnull(uo.DS1_T,3) in (3,4) and  (substring(sl.ds1,1,1) = 'C' or  sl.ds1 between 'D00' and 'D09.99' or (substring(sl.ds1,1,3) = 'D70' and exists (select top 1 ds.DS from #TEMP_DS ds where (ds.DS between 'C00' and 'C80.9' or  ds.ds between 'C97' and 'C97.9')))) 
)

-- Проверка №78.4 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS1_T', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение DS1_T="'+isnull(cast(uo.DS1_T as varchar),'')+'" не соответствует примененному коду КСГ N_KSG="'+isnull(cast(q.N_KSG as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH sl on sl.idcase=zs.idcase
  left join #SCHET_SLUCH_ONK uo on uo.idcase=zs.idcase and uo.SL_ID=sl.SL_ID
  join #SCHET_KSG q on zs.idcase=q.idcase and sl.SL_ID=q.SL_ID
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('C')
 where (q.N_KSG in ('st05.007','st05.011','st08.001','st19.027','st19.028','st19.029','st19.030','st19.031','st19.032','st19.033','st19.034','st19.035','st19.036',
  'st19.038','st02.008','st20.001','st23.003','st27.002','st30.003','st31.011','st31.017','st35.006','st19.039','st19.040','st19.041','st19.042','st19.043','st19.044',
  'st19.045','st19.046','st19.047','st19.048','st19.001','st19.002','st19.003','st19.004','st19.005','st19.006','st19.007','st19.008','st19.009','st19.010','st19.011',
  'st19.013','st19.014','st19.015','st19.012','st19.016','st19.017','st19.018','st19.019','st19.020','st19.021','st19.022','st19.023','st19.024','st19.025','st19.026',
  'st19.049','st19.050','st19.051','st19.052','st19.053','st19.054','st19.055') and isnull(uo.DS1_T,10) not in (0,1,2))
  or (q.N_KSG ='st36.012' and isnull(uo.DS1_T,10) not in (0,1,2,6))

-- Проверка №78.3 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL_TIP', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение USL_TIP="'+isnull(cast(uo.USL_TIP as varchar),'')+'" не соответствует примененному виду ВМП VID_HMP="'+isnull(cast(sl.vid_hmp as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH sl on sl.idcase=zs.idcase
  join #SCHET_USL_ONK uo on uo.idcase=zs.idcase and uo.SL_ID=sl.SL_ID
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T')
where (sl.VID_HMP ='09.00.22.005' and uo.USL_TIP != 2)
   or (sl.VID_HMP ='09.00.21.004' and uo.USL_TIP != 3)

-- Проверка №78.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL_TIP', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение USL_TIP="'+isnull(cast(uo.USL_TIP as varchar),'')+'" не соответствует примененному виду ВМП VID_VMP="'+isnull(cast(sl.vid_hmp as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH sl on sl.idcase=zs.idcase
  join #SCHET_USL_ONK uo on uo.idcase=zs.idcase and uo.SL_ID=sl.SL_ID
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T')
 where (substring(sl.vid_hmp,dbo.instr(sl.vid_hmp,'.',1,2)+1,case dbo.instr(sl.vid_hmp,'.',1,3)-dbo.instr(sl.vid_hmp,'.',1,2)-1 when -1 then 0 else dbo.instr(sl.vid_hmp,'.',1,3)-dbo.instr(sl.vid_hmp,'.',1,2)-1 end) = '22'
    and uo.USL_TIP != 2)
  or  (substring(sl.vid_hmp,dbo.instr(sl.vid_hmp,'.',1,2)+1,case dbo.instr(sl.vid_hmp,'.',1,3)-dbo.instr(sl.vid_hmp,'.',1,2)-1 when -1 then 0 else dbo.instr(sl.vid_hmp,'.',1,3)-dbo.instr(sl.vid_hmp,'.',1,2)-1 end) = '21'
    and uo.USL_TIP != 3)

/*
-- Проверка №78.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL_TIP', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'При примененнии кода КСГ N_KSG="'+isnull(cast(q.N_KSG as varchar),'')+'" должно быть две онкоуслуги с USL_TIP="2" и "3"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH sl on sl.idcase=zs.idcase
  join #SCHET_KSG q on zs.idcase=q.idcase and sl.SL_ID=q.SL_ID
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('C')
 where q.N_KSG in ('ds19.011','ds19.012','ds19.013','st19.049','st19.050','st19.051','st19.052','st19.053','st19.054','st19.055') 
   and not exists (select 1 from #SCHET_USL_ONK uo where uo.idcase=zs.idcase and uo.SL_ID=sl.SL_ID and uo.USL_TIP = 2)
   and not exists (select 1 from #SCHET_USL_ONK uo where uo.idcase=zs.idcase and uo.SL_ID=sl.SL_ID and uo.USL_TIP = 3)
*/   



-- Проверка №78.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL_TIP', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение USL_TIP="'+isnull(cast(uo.USL_TIP as varchar),'')+'" не соответствует примененному коду КСГ N_KSG="'+isnull(cast(q.N_KSG as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH sl on sl.idcase=zs.idcase
  join #SCHET_USL_ONK uo on uo.idcase=zs.idcase and uo.SL_ID=sl.SL_ID
  join #SCHET_KSG q on zs.idcase=q.idcase and sl.SL_ID=q.SL_ID
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('C')
 where (q.N_KSG in ('ds19.018','ds19.019','ds19.020','ds19.021','ds19.022','ds19.023','ds19.024','ds19.025','ds19.026','ds19.027',
                   'st19.027','st19.028','st19.029','st19.030','st19.031','st19.032','st19.033','st19.034','st19.035','st19.036') and uo.USL_TIP != 2)
    or (q.N_KSG in ('ds19.001','ds19.002','ds19.003','ds19.004','ds19.006','ds19.007','ds19.008','ds19.009','ds19.010','st19.039','st19.040','st19.041',
					'st19.042','st19.043','st19.044','st19.045','st19.046','st19.047','st19.048') and uo.USL_TIP != 3)
    or (q.N_KSG in ('ds19.011','ds19.012','ds19.013','ds19.014','ds19.015','st19.049','st19.050','st19.051','st19.052','st19.053','st19.054','st19.055') and uo.USL_TIP != 4)
    or (q.N_KSG in ('st19.038','ds19.028') and uo.USL_TIP != 5)


-- Проверка №78 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL_TIP', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение USL_TIP="'+isnull(cast(uo.USL_TIP as varchar),'')+'" не соответствует допустимому значению  в справочнике N013'
 from #TEMP_Z_SLUCH zs
  join #SCHET_USL_ONK uo on uo.idcase=zs.idcase
  left join [IES].[T_N013_TREAT_TYPE] t1 on uo.usl_tip=t1.id_tlech and zs.DATE_Z_2 between t1.DATEBEG and isnull(t1.DATEEND,zs.DATE_Z_2)
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
     where t1.id_tlech is null

-- Проверка №77.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PR_CONS', 'CONS', zs.N_ZAP, zs.IDCASE, null, '904', 'Дата проведения консилиума (DT_CONS) выходит за пределы случая лечения (DATE_1-DATE_2).'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH o on o.idcase=zs.idcase
  join #TEMP_SLUCH_CONS u on u.idcase=o.idcase and u.sl_id=o.sl_id
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
where u.DT_CONS < zs.DATE_Z_1 or u.DT_CONS > zs.DATE_Z_2 


-- Проверка №77.3 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PR_CONS', 'CONS', zs.N_ZAP, zs.IDCASE, null, '904', 'Указана дата проведения консилиума (DT_CONS) при PR_CONS=0'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH o on o.idcase=zs.idcase
  join #TEMP_SLUCH_CONS u on u.idcase=o.idcase and u.sl_id=o.sl_id
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
where u.DT_CONS is not null and u.PR_CONS = 0

-- Проверка №77.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PR_CONS', 'CONS', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указана дата проведения консилиума (DT_CONS)'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH o on o.idcase=zs.idcase
  join #TEMP_SLUCH_CONS u on u.idcase=o.idcase and u.sl_id=o.sl_id
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
where u.DT_CONS is null and u.PR_CONS in (1,2,3)

-- Проверка №77 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PR_CONS', 'CONS', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение PR_CONS="'+isnull(cast(u.PR_CONS as varchar),'')+'" не соответствует допустимому значению  в справочнике N019'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH o on o.idcase=zs.idcase
  join #TEMP_SLUCH_CONS u on u.idcase=o.idcase and u.sl_id=o.sl_id
  left join [IES].[T_N019_ONK_CONS] t1 on u.PR_CONS=t1.ID_CONS and zs.DATE_Z_2 between t1.DATEBEG and isnull(t1.DATEEND,zs.DATE_Z_2)
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
where t1.ID_CONS is null

-- Проверка №76.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'MET_ISSL', 'NAPR', zs.N_ZAP, zs.IDCASE, null, '904', 'При значении NAPR_V не равном "3", поле MET_ISSL должно быть пустым'
 from #TEMP_Z_SLUCH zs
  join #SCHET_USL_NAPR n on n.idcase=zs.idcase
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
where n.MET_ISSL is not null and n.napr_v != 3

-- Проверка №76 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'MET_ISSL', 'NAPR', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение MET_ISSL="'+isnull(cast(n.MET_ISSL as varchar),'')+'" не соответствует допустимому значению  в справочнике V029'
 from #TEMP_Z_SLUCH zs
  join #SCHET_USL_NAPR n on n.idcase=zs.idcase
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
  left join [IES].[T_V029_MET_ISSL] t1 on n.MET_ISSL=t1.IDMET and zs.DATE_Z_1 between t1.DATEBEG and isnull(t1.DATEEND,zs.DATE_Z_1)
where (t1.IDMET is null and n.napr_v = 3)

-- Проверка №75.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAPR_DATE', 'NAPR', zs.N_ZAP, zs.IDCASE, null, '904', 'Дата направления (NAPR_DATE) выходит за пределы случая лечения (DATE_1-DATE_2).'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_USL_NAPR n on n.idcase=s.idcase and n.sl_id=s.sl_id
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('T','C')
 where n.NAPR_DATE < s.DATE_1 or n.NAPR_DATE > s.DATE_2
 
 -- Проверка №75.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAPR_MO', 'NAPR', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAPR_MO="'+isnull(cast(n.NAPR_MO as varchar),'')+'" не соответствует допустимому значению  в справочнике F003'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_USL_NAPR n on n.idcase=s.idcase and n.sl_id=s.sl_id
  left join [IES].[T_F003_MO] t1 on n.NAPR_MO=t1.MCOD and n.NAPR_DATE between t1.D_BEGIN and isnull(t1.D_END,n.NAPR_DATE)
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('T','C')
 where t1.MCOD is null

-- Проверка №75 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAPR_V', 'NAPR', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAPR_V="'+isnull(cast(n.NAPR_V as varchar),'')+'" не соответствует допустимому значению  в справочнике V028'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_USL_NAPR n on n.idcase=s.idcase and n.sl_id=s.sl_id
  left join [IES].[T_V028_NAPR_V] t1 on n.NAPR_V=t1.IDVN and s.DATE_1 between t1.DATEBEG and isnull(t1.DATEEND,s.DATE_1)
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('T','C')
 where t1.IDVN is null

-- Проверка №74 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAPR_V', 'NAPR', zs.N_ZAP, zs.IDCASE, null, '904', 'Отсутствует направление на лечение (диагностику)'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  left join #SCHET_USL_NAPR n on n.idcase=t.idcase and n.sl_id=t.sl_id
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('T','C')
 where n.napr_v is null 
   and t.ds_onk = 1 
   and t.PROFIL not in (78,34,38,111,106,76,123) -- исключаем профили по диагностическим мероприятиям

-- Проверка №73 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'ONK_USL', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Отсутствует онкоуслуга для онкослучя'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK o on o.idcase=zs.idcase
  left join #SCHET_USL_ONK u on u.idcase=o.idcase and u.sl_id=o.sl_id
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
where u.usl_tip is null      
        and zs.usl_ok in (1,2)
        and o.DS1_T in (0,1,2)

-- Проверка №72 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'KSG_KPG', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не заполнен блок КСГ'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  left join #SCHET_KSG k on s.idcase=k.idcase and s.sl_id=k.sl_id
  join #SCHET t on SUBSTRING(t.FILENAME,1,1) in ('H','C')
  where k.n_ksg is null and zs.usl_ok in (1,2)        


-- Проверка №71.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DIAG_DATE', 'B_DIAG', zs.N_ZAP, zs.IDCASE, null, '904', 'Дата взятия материала (DIAG_DATE) выходит за пределы случая лечения (DATE_1-DATE_2).'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_SLUCH_ONK_DIAG d on d.idcase=s.idcase and d.sl_id=s.sl_id
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('T','C')
 where d.DIAG_DATE < s.DATE_1 or d.DIAG_DATE > s.DATE_2

-- Проверка №71 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DIAG_TIP', 'B_DIAG', zs.N_ZAP, zs.IDCASE, null, '904', 'Некорректное заполнение поля DIAG_TIP="'+isnull(cast(d.DIAG_TIP as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_SLUCH_ONK_DIAG d on d.idcase=s.idcase and d.sl_id=s.sl_id
  join #SCHET z on SUBSTRING(z.FILENAME,1,1) in ('T','C')
 where d.diag_tip not in (1,2) and d.diag_date is null        

-- Проверка №70 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SOD', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Некорректное заполнение поля SOD'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK o on o.idcase=zs.idcase
  left join #SCHET_USL_ONK u on u.idcase=o.idcase and u.sl_id=o.sl_id
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where (o.sod is not null and u.usl_tip is null)
    or (o.sod is null and u.usl_tip in (3,4))
    or (o.sod is not null and u.usl_tip not in (3,4))

-- Проверка №69 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'MTSTZ', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Некорректное заполнение поля MTSTZ="'+isnull(cast(o.MTSTZ as varchar),'')+'" при DS1_T="'+isnull(cast(o.DS1_T as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK o on o.idcase=zs.idcase
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where isnull(o.mtstz,1) != 1 and o.ds1_t in (1,2)
   or isnull(o.mtstz,0) = 1 and o.ds1_t not in (1,2)
 
-- Проверка №68 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS1_T', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение DS1_T="'+isnull(cast(o.DS1_T as varchar),'')+'" не соответствует допустимому значению  в справочнике N018'
 from #TEMP_Z_SLUCH zs
  join #SCHET_SLUCH_ONK o on o.idcase=zs.idcase
  left join [IES].[T_N018_ONK_REAS] t1 on o.DS1_T=t1.ID_REAS and zs.DATE_Z_1 between t1.DATEBEG and isnull(t1.DATEEND,zs.DATE_Z_1)
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where t1.ID_REAS is null        
        
-- Проверка №66.3 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDSP', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Для CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" значение поля IDSP не должно равняться "'
 +isnull(cast(zs.IDSP as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join #SCHET_USL t1 on (t1.IDCASE=t.IDCASE and t1.SL_ID=t.SL_ID) 
      where (
	         (zs.idsp != 28 and t1.CODE_USL like 'A%' and zs.USL_OK=3 and @type=554)
	         or (zs.idsp not in (25,28) and t1.CODE_USL like 'A%' and zs.USL_OK=3 and @type in (693,562))
			 )
        and t1.CODE_USL not in ('A18.05.012.082','A18.05.012.081','A11.12.003.080','A18.05.012.080','A11.12.003.001')

-- Проверка №66.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDSP', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При значении поля IDSP = 29, DATE_Z_1 должно равняться DATE_Z_2'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
      where (zs.idsp = 29 and zs.date_z_1 != zs.date_z_2)

-- Проверка №66.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDSP', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При значении поля IDSP = 30, DATE_Z_1 не может равняться DATE_Z_2'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
      where (zs.idsp = 30 and zs.date_z_1 = zs.date_z_2)
        

-- Проверка №66 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDSP', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При значении поля IDSP="'+isnull(cast(zs.IDSP as varchar),'')+'"  значение поля USL_OK не может равгяться "'
  +isnull(cast(zs.USL_OK as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C','H','D')
      where (zs.usl_ok in (1,2) and zs.idsp != 33)
         or (zs.usl_ok =4 and zs.idsp != 24) and @type=554
         or (zs.usl_ok =4 and zs.idsp not in (24,36)) and @type in (693,562)
         or (zs.usl_ok =3 and zs.idsp not in (28,29,30) and @type=554)
		 or (zs.usl_ok =3 and zs.idsp not in (25,28,29,30) and @type in (693,562) and SUBSTRING(s.FILENAME,1,1) in ('C','T','H','D'))

-- Проверка №65 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'VERS_SPEC', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение поля VERS_SPEC должно быть равно значению "V021"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','T','C')
 where t.vers_spec != 'V021' or t.vers_spec is null

-- Проверка №64 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'REAB', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При значении поля REAB =  "'+isnull(cast(t.REAB as varchar),'')+'" значение поля PROFIL не может равняться "'
 +isnull(cast(t.PROFIL as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','T','C')
 where (t.reab != 1 and t.profil = 158)
         or (t.reab = 1 and t.profil != 158)
         or (isnull(t.reab,1) != 1)	  

-- Проверка №63 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DN', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При значении поля DN = "'+isnull(cast(t.DN as varchar),'')+'" значение поля P_CEL не может равняться "'
 +isnull(cast(t.P_CEL as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','C')
 where (t.dn is null and t.p_cel = '1.3')

-- Проверка №62 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'KD', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При значении поля KD = "'+isnull(cast(t.KD as varchar),'')+'" значение поля USL_OK не может равняться "'
 +isnull(cast(zs.USL_OK as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','C')
      where (t.kd is null and zs.usl_ok in (1,2))
           or (t.kd is not null and zs.usl_ok in (3,4))

-- Проверка №61 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'P_CEL', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При значении поля P_CEL = "'+isnull(cast(t.P_CEL as varchar),'')+'" значение поля USL_OK не может равняться "'
 +isnull(cast(zs.USL_OK as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
      where (t.p_cel is null and zs.usl_ok = 3)
           or (t.p_cel is not null and zs.usl_ok != 3)

-- Проверка №60 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DET', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При значении поля DET = "'+isnull(cast(t.DET as varchar),'')+'" значение поля PROFIL не может равняться "'
 +isnull(cast(t.PROFIL as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','T','C')
     where (t.det = 0 and t.profil in (17,18,19,20,21,68,86,55))
           or (t.det = 1 and t.profil not in (17,18,19,20,21,68,86,55))
 

-- Проверка №59 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'C_ZAB', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан характер осносного заболевания (C_ZAB)'
 from #TEMP_SLUCH t
  join #TEMP_Z_SLUCH zs on zs.IDCASE=t.IDCASE 
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','T','C')
 where t.c_zab is null 
   and (
        (SUBSTRING(s.FILENAME,1,1) in ('T','C') and USL_OK in (1,2,3) and (substring(t.ds1,1,1) = 'C' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS from #TEMP_DS ds where (ds.DS between 'C00' and 'C80.9' or  ds.ds between 'C97' and 'C97.9')))) )
        or 
		(SUBSTRING(s.FILENAME,1,1)='H' and zs.USL_OK = 3 and substring(t.ds1,1,1) != 'Z') 
	)

-- Проверка №58 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'C_ZAB', 'SL', N_ZAP, IDCASE, null, '904', 'Значение C_ZAB="'+isnull(cast(C_ZAB as varchar),'')+'" не соответствует допустимому значению  в справочнике'
 from #TEMP_SLUCH t1
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','T','C')
  left join [IES].[T_V027_C_ZAB] t2 on c_zab=t2.IDCZ and DATE_1 between t2.DATEBEG and isnull(t2.DATEEND,DATE_1) 
 where t2.IDCZ is null and t1.c_zab is not null


-- Проверка №57 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_Z_1', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Дата DATE_Z_1 не может быть больше дата DATE_Z_2'
 from #TEMP_Z_SLUCH zs
 where zs.date_z_1 > zs.date_z_2

-- Проверка №56 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_IN', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Даты услуги выходят за пределы случая.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join #SCHET_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  where u.DATE_IN < s.DATE_1 or u.DATE_OUT > s.DATE_2 or u.DATE_IN > u.DATE_OUT


-- Проверка №55 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_1', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Даты случая выходят за пределы законченного случая.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  where s.DATE_1 <zs.DATE_Z_1 or s.DATE_2 >zs.DATE_Z_2 or s.DATE_1 > s.DATE_2

-- Проверка №54.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'KD', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Поле KD обязательно для заполенния для USL_OK = 1 и 2.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on zs.idcase=t.idcase  
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','C')
  where zs.usl_ok in (1,2)
    and isnull(t.kd,0)=0 

-- Проверка №54 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'KD_Z', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Поле KD_Z обязательно для заполенния для USL_OK = 1 и 2.'
 from #TEMP_Z_SLUCH zs
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','T','C')
  where zs.usl_ok in (1,2)
    and isnull(zs.kd_z,0)=0 

-- Проверка №53 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'ONK_SL', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Заполнен блок онкослучая при не соблюдении условий.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join #SCHET_SLUCH_ONK o on o.idcase=t.idcase
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where not(
        (substring(t.ds1,1,1) = 'C' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS from #TEMP_DS ds where (ds.DS between 'C00' and 'C80.9' or  ds.ds between 'C97' and 'C97.9')))) 
        or 
		(SUBSTRING(s.FILENAME,1,1)='C' and zs.USL_OK != 4 and t.REAB != 1 and t.ds_onk != 1) 
		)
		 

-- Проверка №52 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'ONK_SL', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не заполнен блок онкослучая.'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  left join #SCHET_SLUCH_ONK o on o.idcase=t.idcase
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where o.IDCASE is null 
   and (
		 (SUBSTRING(s.FILENAME,1,1) = 'T' and (t.ds1 between 'D00' and 'D09.99' or substring(t.ds1,1,1) = 'C' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS from #TEMP_DS ds where (ds.DS between 'C00' and 'C80.9' or  ds.ds between 'C97' and 'C97.9')))))
        or (SUBSTRING(s.FILENAME,1,1) = 'C' and zs.USL_OK != 4 and isnull(t.REAB,0) != 1 and t.ds_onk != 1
		    and (t.ds1 between 'D00' and 'D09.99' or substring(t.ds1,1,1) = 'C' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS from #TEMP_DS ds where (ds.DS between 'C00' and 'C80.9' or  ds.ds between 'C97' and 'C97.9'))))) 
		)

-- Проверка №51.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'LPU_1', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение LPU_1="'+isnull(t.LPU_1,'')+'" не соответствует допустимому значению коду LPU="'+isnull(zs.LPU,'')+'"'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join [IES].[T_CHER_MO_PODR]  p on t.lpu_1=p.id
  where zs.lpu != p.lpu

-- Проверка №51 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'LPU_1', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение "'+isnull(t.LPU_1,'')+'" не соответствует допустимому значению кода МО'
 from #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  left join [IES].[T_CHER_MO_PODR]  p on t.lpu_1=p.id and zs.lpu=p.lpu
  where p.id is null
       and zs.lpu in (select lpu from [IES].[T_CHER_MO_PODR])		  

-- Проверка №50 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL_OK', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение USL_OK="'+isnull(cast(zs.USL_OK as varchar),'')+'" не может передаваться в данном типе файла "'+
 SUBSTRING(s.FILENAME,1,1)+'".'
 from #TEMP_Z_SLUCH zs
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','T','C','D')
   where  (zs.usl_ok not in (1,2,3,4) and SUBSTRING(s.FILENAME,1,1) in ('H'))
		  or (zs.usl_ok not in (1,2,3) and SUBSTRING(s.FILENAME,1,1) in ('C'))	
          or (zs.usl_ok != 1 and SUBSTRING(s.FILENAME,1,1) in ('T'))
          or (zs.usl_ok != 3 and SUBSTRING(s.FILENAME,1,1) in ('D'))


-- Проверка №49 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'ISHOD', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение ISHOD="'+isnull(cast(zs.ishod as varchar),'')+'" не соответствует допустимому значению USL_OK="'
 +isnull(cast(zs.USL_OK as varchar),'')+'"'
 from #TEMP_Z_SLUCH zs 
 where substring(cast(zs.ishod as varchar),1,1) != cast(zs.usl_ok as varchar)
		
-- Проверка №48 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'RSLT_D', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение RSLT_D="'+isnull(cast(zs.ishod as varchar),'')+'" не соответствует допустимому значению в справочнике V017'
 from #TEMP_Z_SLUCH zs 
  left join [IES].[T_V017_DISP_RESULT] f on zs.RSLT_D=f.iddr  and zs.DATE_Z_1 between f.DATEBEG and isnull(f.DATEEND,zs.DATE_Z_1) 
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('D')
 where f.iddr is null
 
-- Проверка №47 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'RSLT', 'Z_SL', t.N_ZAP, t.IDCASE, null, '904', 'Значение RSLT="'+isnull(cast(t.RSLT as varchar),'')+'" не соответствует допустимому значению USL_OK="'
  +isnull(cast(t.USL_OK as varchar),'')+'"'
 from  #TEMP_Z_SLUCH t 
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','T','C')
 where substring(cast(t.RSLT as varchar),1,1) != cast(t.usl_ok as varchar)
		
 
-- Проверка №46 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NPR_DATE', 'Z_SL', t.N_ZAP, t.IDCASE, null, '904', 'Дата направления больше даты начала лечения'
 from #TEMP_Z_SLUCH t
 where t.npr_date > t.date_z_1
   and t.npr_date is not null


 -- Проверка №45 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDSERV', 'USL', t2.N_ZAP, t1.IDCASE, t1.IDSERV, '905', 'Дублирующий идентификатор IDSERV="'+isnull(cast(IDSERV as varchar),'')+'" в пределах одного случая SL_ID="' +
  isnull(cast(SL_ID as varchar),'')+'"'
  from #SCHET_USL t1
   join #TEMP_Z_SLUCH t2 on t1.IDCASE=t2.IDCASE
 group by t2.N_ZAP, t1.IDCASE, t1.SL_ID, t1.IDSERV
 having count(*)>1

 -- Проверка №44 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDSERV', 'SL', max(t2.N_ZAP), t1.IDCASE, null, '905', 'Дублирующий идентификатор SL_ID="'+isnull(cast(t1.SL_ID as varchar),'')+'" в пределах одного закончкнного случая IDСASE="' +
  isnull(cast(t1.IDCASE as varchar),'')+'"'
  from #TEMP_SLUCH t1
   join #TEMP_Z_SLUCH t2 on t1.IDCASE=t2.IDCASE
 group by t1.IDCASE, t1.SL_ID
 having count(*)>1

 -- Проверка №43 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDCASE', 'ZSL', max(N_ZAP), IDCASE, null, '905', 'Дублирующий идентификатор IDCASE="'+isnull(cast(IDCASE as varchar),'')+'"'
  from #TEMP_Z_SLUCH
 group by IDCASE
 having count(*)>1

 -- Проверка №42 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'N_ZAP', 'ZAP', N_ZAP, null, null, '905', 'Дублирующий идентификатор N_ZAP="'+isnull(cast(N_ZAP as varchar),'')+'"'
  from #TEMP_ZAP
 group by N_ZAP
 having count(*)>1
/*
 -- Проверка №41 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PERS', 'ID_PAC', null, null, null, '905', 'Дублирующий идентификатор ID_PAC="'+isnull(cast(ID_PAC as varchar),'')+'"'
  from #TEMP_PERS
 group by cast(ID_PAC as varchar)
 having count(*)>1
*/
-- Проверка №40 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_Z_2', 'Z_SL', t.N_ZAP, t.IDCASE, null, '904', 'Случай лечения с DATE_Z_2="'+format(t.DATE_Z_2, 'dd.MM.yyyy')+'" н не может быть выставлен в реестре счета за YEAR="'
 +isnull(cast(s.YEAR as varchar),'')+'" и MONTH="'+isnull(cast(s.MONTH as varchar),'')+'"'
 from  #TEMP_Z_SLUCH t 
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','T','C')
 where (not (YEAR(t.DATE_Z_2)=s.YEAR and MONTH(t.DATE_Z_2)=s.MONTH) and @type=554)
   or (YEAR(t.DATE_Z_2)=s.YEAR and MONTH(t.DATE_Z_2)>s.MONTH and @type in (693,562))


 -- Проверка №39 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'N_KSG', 'KSG_KPG', z.n_zap, t.idcase, null, '904',  'Значение N_KSG="'+isnull(t.N_KSG,'')+'" не соответствует допустимому в справочнике V023' 
       from #SCHET_KSG t
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_V023_KSG] f on t.N_KSG=f.k_ksg and z.DATE_2 between f.DATEBEG and isnull(f.DATEEND,z.DATE_2) 
      where f.k_ksg is null 
        and t.n_kpg is null

-- Проверка №38 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'PROT', 'B_PROT', z.n_zap, t.idcase, null, '904',  'Значение PROT="'+isnull(cast(t.PROT as varchar),'')+'" не соответствует допустимому в справочнике N001' 
       from #SCHET_SLUCH_ONK_B_PROT t
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_N001_PrOt] f on t.PROT=f.id_prot and z.DATE_2 between f.DATEBEG and isnull(f.DATEEND,z.DATE_2) 
       join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
      where f.id_prot is null 

-- Проверка №37.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DIAG_CODE', 'B_DIAG', z.n_zap, t.idcase, null, '904',  'Значение кода МКБ (DS1) "'+ isnull(cast(z.ds1 as varchar),'')+'" не соответствует коду диагностического показателя (DIAG_CODE) "'+ isnull(cast(t.DIAG_CODE as varchar),'')+'" по справочнику N012.' 
       from #SCHET_SLUCH_ONK_DIAG t
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
  	   join [ies].T_N012_MARK_DIAG d on z.ds1 like d.DS_Igh+'%'
       join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
      where not exists (select 1 from [ies].T_N012_MARK_DIAG d 
	                     inner join [ies].T_N010_MARK m on d.N010Mark=m.N010MarkID where z.ds1 like d.DS_Igh+'%' and m.ID_Igh=t.DIAG_CODE )
		and t.diag_tip = 2  

-- Проверка №37.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DIAG_RSLT', 'B_DIAG', z.n_zap, t.idcase, null, '904',  'Значение Кода результата диагностики  (DIAG_RSLT) "'+ isnull(cast(t.DIAG_RSLT as varchar),'')+'" не найдено в справочнике N011 для кода диагностического показателя (DIAG_CODE) "'+ isnull(cast(t.DIAG_CODE as varchar),'')+'" из справочника N010.' 
       from #SCHET_SLUCH_ONK_DIAG t
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_N010_MARK] t1 on t1.ID_Igh=t.DIAG_CODE and t.DIAG_DATE between t1.DATEBEG and isnull(t1.DATEEND,t.DIAG_DATE) 
       left join [IES].[T_N011_MARK_VALUE] f on t.DIAG_RSLT=f.id_r_i and t.DIAG_DATE between f.DATEBEG and isnull(f.DATEEND,t.DIAG_DATE) and t1.N010MarkID=f.N010Mark
       join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
      where (f.id_r_i is null or t1.ID_Igh is null)
	    and (t.DIAG_RSLT is not null or t.DIAG_CODE is not null)
		and t.diag_tip = 2  
		and t.REC_RSLT = 1   

-- Проверка №37 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DIAG_RSLT', 'B_DIAG', z.n_zap, t.idcase, null, '904',  'Значение DIAG_RSLT="'+ isnull(cast(t.DIAG_RSLT as varchar),'')+'" не соответствует допустимому в справочнике N011' 
       from #SCHET_SLUCH_ONK_DIAG t
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_N011_MARK_VALUE] f on t.DIAG_RSLT=f.id_r_i and z.DATE_1 between f.DATEBEG and isnull(f.DATEEND,z.DATE_1) 
       join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
      where f.id_r_i is null 
        and t.diag_tip = 2    
		and t.REC_RSLT = 1   


-- Проверка №36.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DIAG_CODE', 'B_DIAG', z.n_zap, t.idcase, null, '904',  'Значение кода МКБ (DS1) "'+ isnull(cast(z.ds1 as varchar),'')+'" не соответствует коду диагностического показателя (DIAG_CODE) "'+ isnull(cast(t.DIAG_CODE as varchar),'')+'" по справочнику N009.' 
       from #SCHET_SLUCH_ONK_DIAG t
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
  	   join [ies].T_N009_MRT_DS d on z.ds1 like d.DS_Mrf+'%'
       join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
      where not exists (select 1 from [ies].T_N009_MRT_DS d 
	                     inner join [ies].T_N007_MRF m on d.N007Mrf=m.N007MrfID where z.ds1 like d.DS_Mrf+'%' and m.ID_Mrf=t.DIAG_CODE)
		and t.diag_tip = 1  

-- Проверка №36.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DIAG_RSLT', 'B_DIAG', z.n_zap, t.idcase, null, '904',  'Значение Кода результата диагностики  (DIAG_RSLT) "'+ isnull(cast(t.DIAG_RSLT as varchar),'')+'" не найдено в справочнике N008 для кода диагностического показателя (DIAG_CODE) "'+ isnull(cast(t.DIAG_CODE as varchar),'')+'" из справочника N007.' 
       from #SCHET_SLUCH_ONK_DIAG t
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_N007_MRF] t1 on t1.ID_Mrf=t.DIAG_CODE and t.DIAG_DATE between t1.DATEBEG and isnull(t1.DATEEND,t.DIAG_DATE) 
       left join [IES].[T_N008_MRF_RT] f on t.DIAG_RSLT=f.ID_R_M and t.DIAG_DATE between f.DATEBEG and isnull(f.DATEEND,t.DIAG_DATE) and t1.N007MrfID=f.N007Mrf
       join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
      where (f.ID_R_M is null or t1.ID_Mrf is null)
	    and (t.DIAG_RSLT is not null or t.DIAG_CODE is not null)
		and t.diag_tip = 1  
		and t.REC_RSLT = 1   

-- Проверка №36 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DIAG_RSLT', 'B_DIAG', z.n_zap, t.idcase, null, '904',  'Значение DIAG_RSLT="'+isnull(cast(t.DIAG_RSLT as varchar),'')+'" не соответствует допустимому в справочнике N008' 
       from #SCHET_SLUCH_ONK_DIAG t
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_N008_MRF_RT] f on t.DIAG_RSLT=f.id_r_m and z.DATE_2 between f.DATEBEG and isnull(f.DATEEND,z.DATE_2) 
       join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
      where f.id_r_m is null
        and t.diag_tip = 1 
		and t.REC_RSLT = 1   

-- Проверка №35 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DIAG_CODE', 'B_DIAG', z.n_zap, t.idcase, null, '904',  'Значение DIAG_CODE="'+isnull(cast(t.DIAG_CODE as varchar),'')+'" не соответствует допустимому в справочнике N007' 
       from #SCHET_SLUCH_ONK_DIAG t
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
       left join [IES].[T_N007_MRF] f on t.DIAG_CODE=f.id_mrf and z.DATE_2 between f.DATEBEG and isnull(f.DATEEND,z.DATE_2)  
      where f.id_mrf is null
        and t.diag_tip = 1 

-- Проверка №34.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DIAG_CODE', 'B_DIAG', s.n_zap, t.idcase, null, '904',  'При применении кода ВМП VID_HMP="'+isnull(cast(s.VID_HMP as varchar),'')+'" обязательно наличие результатов гистологии.' 
       from #TEMP_SLUCH s
	   left join #SCHET_SLUCH_ONK_DIAG t on s.IDCASE=t.IDCASE and s.SL_ID=t.SL_ID
       join #SCHET sc on SUBSTRING(sc.FILENAME,1,1) in ('T')
      where ((substring(s.vid_hmp,dbo.instr(s.vid_hmp,'.',1,2)+1,case dbo.instr(s.vid_hmp,'.',1,3)-dbo.instr(s.vid_hmp,'.',1,2)-1 when -1 then 0 else dbo.instr(s.vid_hmp,'.',1,3)-dbo.instr(s.vid_hmp,'.',1,2)-1 end) in ('20') 
	          and s.METOD_HMP in (105,106,107,109,110,111,112,113,114,115,118,124,128,129,153,180,183,186,187,188,192,193,194,195,196,197,199,204,210,211,215,216,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,250,251,
			  252,253,254,255,256,257,258,259,260,261,262,263,264,265,266,268,269,270,271,272,273,274,275,276,277,278,279,280,281,282,283,284,285,286,287,288,289,290,291,292,293,294,295,297,298,299,300,301,303,305,306,307,308,309,310,311,312,314,315,316,318,321,322,
			  323,324,325,326,327,328,329,330,331,332,333,335,336,338,339,340,341,341,343,344,345,347,348,349)
			 )
	         or (substring(s.vid_hmp,dbo.instr(s.vid_hmp,'.',1,2)+1,case dbo.instr(s.vid_hmp,'.',1,3)-dbo.instr(s.vid_hmp,'.',1,2)-1 when -1 then 0 else dbo.instr(s.vid_hmp,'.',1,3)-dbo.instr(s.vid_hmp,'.',1,2)-1 end) = '12' 
			     and (substring(s.DS1,1,1) in ('C'))
				)
			)
        and t.DIAG_CODE is null
        and (@type != 693 or getdate() > '01.05.2019') 
/*
      where ((substring(s.vid_hmp,dbo.instr(s.vid_hmp,'.',1,2)+1,case dbo.instr(s.vid_hmp,'.',1,3)-dbo.instr(s.vid_hmp,'.',1,2)-1 when -1 then 0 else dbo.instr(s.vid_hmp,'.',1,3)-dbo.instr(s.vid_hmp,'.',1,2)-1 end) in ('1','2','4','8','20') )
	         or (substring(s.vid_hmp,dbo.instr(s.vid_hmp,'.',1,2)+1,case dbo.instr(s.vid_hmp,'.',1,3)-dbo.instr(s.vid_hmp,'.',1,2)-1 when -1 then 0 else dbo.instr(s.vid_hmp,'.',1,3)-dbo.instr(s.vid_hmp,'.',1,2)-1 end) = '24' 
			     and s.DS1 in ('J32.3','J38.6', 'D14.1', 'D14.2', 'J38.0', 'J38.3', 'R49.0', 'R49.1')
				)
	         or (substring(s.vid_hmp,dbo.instr(s.vid_hmp,'.',1,2)+1,case dbo.instr(s.vid_hmp,'.',1,3)-dbo.instr(s.vid_hmp,'.',1,2)-1 when -1 then 0 else dbo.instr(s.vid_hmp,'.',1,3)-dbo.instr(s.vid_hmp,'.',1,2)-1 end) = '50' 
			     and s.DS1 in ('N28.1', 'Q61.0', 'N13.0', 'N13.1', 'N13.2', 'I86.1')
				)
	         or (substring(s.vid_hmp,dbo.instr(s.vid_hmp,'.',1,2)+1,case dbo.instr(s.vid_hmp,'.',1,3)-dbo.instr(s.vid_hmp,'.',1,2)-1 when -1 then 0 else dbo.instr(s.vid_hmp,'.',1,3)-dbo.instr(s.vid_hmp,'.',1,2)-1 end) = '52' 
			     and s.DS1 in ('D11.0', 'D11.9', 'D16.4', 'D16.5')
				)
	         or (substring(s.vid_hmp,dbo.instr(s.vid_hmp,'.',1,2)+1,case dbo.instr(s.vid_hmp,'.',1,3)-dbo.instr(s.vid_hmp,'.',1,2)-1 when -1 then 0 else dbo.instr(s.vid_hmp,'.',1,3)-dbo.instr(s.vid_hmp,'.',1,2)-1 end) = '12' 
			     and (substring(s.DS1,1,1) in ('C','D') or s.DS1 in ('Q28.2', 'M85.5', 'Q06.8', 'M85.4', 'M85.5','Q04.6','Q85.0','Q85.1','Q85.8','Q85.9','Q28.3'))
				)
			)
			*/


-- Проверка №34.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DIAG_CODE', 'B_DIAG', z.n_zap, t.idcase, null, '904',  'При применении кода КСГ N_KSG="'+isnull(cast(k.N_KSG as varchar),'')+'" обязательно наличие результатов гистологии.' 
       from #TEMP_SLUCH z
	   left join #SCHET_SLUCH_ONK_DIAG t on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
	   join #SCHET_KSG k on z.IDCASE=k.IDCASE and z.SL_ID=k.SL_ID
       join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('C')
      where k.N_KSG in ('st19.001','st19.002','st19.003','st19.004','st19.005','st19.006','st19.007','st19.008','st19.009','st19.010','st19.011',
				  'st19.013','st19.014','st19.015','st19.012','st19.016','st19.017','st19.018','st19.019','st19.020','st19.021','st19.022','st19.023','st19.024',
				  'st19.025','st19.026','ds19.016','ds19.017')
        and t.DIAG_CODE is null
        and (@type != 693 or getdate() > '01.05.2019') 

-- Проверка №34 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DIAG_CODE', 'B_DIAG', z.n_zap, t.idcase, null, '904',  'Значение DIAG_CODE="'+isnull(cast(t.DIAG_CODE as varchar),'')+'" не соответствует допустимому в справочнике N010' 
       from #SCHET_SLUCH_ONK_DIAG t
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
       left join [IES].[T_N010_MARK] f on t.DIAG_CODE=f.id_igh and z.DATE_2 between f.DATEBEG and isnull(f.DATEEND,z.DATE_2)        
      where f.id_igh is null 
        and t.diag_tip = 2 
/*
-- Проверка №33.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'ONK_T', 'ONK_SL', z.n_zap, t.idcase, null, '904',  'Не указано значение Metastasis (ONK_M)' 
       from #SCHET_SLUCH_ONK t
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
	   join #TEMP_Z_SLUCH t2 on t2.IDCASE=z.IDCASE
	   join #TEMP_ZAP t1 on t1.N_ZAP=t2.N_ZAP
	   join #TEMP_PERS t3 on cast(t3.ID_PAC as varchar)=cast(t1.ID_PAC as varchar)
      where DATEADD(YEAR,18,t3.DR) >= z.DATE_1 and t.ONK_M is null
*/      
-- Проверка №33 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'ONK_M', 'ONK_SL', z.n_zap, t.idcase, null, '904',  'Значение ONK_M="'+isnull(cast(t.ONK_M as varchar),'')+'" не соответствует допустимому в справочнике N005' 
       from #SCHET_SLUCH_ONK t
       join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_N005_METASTASIS] f on t.ONK_M=f.id_m and z.DATE_2 between f.DATEBEG and isnull(f.DATEEND,z.DATE_2)
      where f.id_m is null and t.ONK_M is not null 
/*
-- Проверка №32.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'ONK_T', 'ONK_SL', z.n_zap, t.idcase, null, '904',  'Не указано значение Nodus (ONK_N)' 
       from #SCHET_SLUCH_ONK t
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
	   join #TEMP_Z_SLUCH t2 on t2.IDCASE=z.IDCASE
	   join #TEMP_ZAP t1 on t1.N_ZAP=t2.N_ZAP
	   join #TEMP_PERS t3 on cast(t3.ID_PAC as varchar)=cast(t1.ID_PAC as varchar)
      where DATEADD(YEAR,18,t3.DR) >= z.DATE_1 and t.ONK_N is null
*/      
-- Проверка №32 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'ONK_N', 'ONK_SL', z.n_zap, t.idcase, null, '904',  'Значение ONK_N="'+isnull(cast(t.ONK_N as varchar),'')+'" не соответствует допустимому в справочнике N004' 
       from #SCHET_SLUCH_ONK t
       join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_N004_NODUS] f on t.ONK_N=f.id_n and z.DATE_2 between f.DATEBEG and isnull(f.DATEEND,z.DATE_2)
      where f.id_n is null and t.ONK_N is not null 
/*      
-- Проверка №31.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'ONK_T', 'ONK_SL', z.n_zap, t.idcase, null, '904',  'Не указано значение Tumor (ONK_T)' 
       from #SCHET_SLUCH_ONK t
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
	   join #TEMP_Z_SLUCH t2 on t2.IDCASE=z.IDCASE
	   join #TEMP_ZAP t1 on t1.N_ZAP=t2.N_ZAP
	   join #TEMP_PERS t3 on cast(t3.ID_PAC as varchar)=cast(t1.ID_PAC as varchar)
      where DATEADD(YEAR,18,t3.DR) >= z.DATE_1 and t.ONK_T is null
*/      
-- Проверка №31 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'ONK_T', 'ONK_SL', z.n_zap, t.idcase, null, '904',  'Значение ONK_T="'+isnull(cast(t.ONK_T as varchar),'')+'" не соответствует допустимому в справочнике N003' 
       from #SCHET_SLUCH_ONK t
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
       left join [IES].[T_N003_TUMOR] f on t.ONK_T=f.id_t and z.DATE_2 between f.DATEBEG and isnull(f.DATEEND,z.DATE_2)
      where f.id_t is null and t.ONK_T is not null
      
-- Проверка №30.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'STAD', 'ONK_SL', z.n_zap, t.idcase, null, '904',  'Значение STAD="'+isnull(cast(t.STAD as varchar),'')+'" не соответствует указанному коду основного диагноза DS1="'
	  +isnull(cast(z.DS1 as varchar),'')+'"' 
       from #SCHET_SLUCH_ONK t
	   join #TEMP_SLUCH z on t.IDCASE=z.IDCASE and t.SL_ID=z.SL_ID
       join [IES].[T_N002_STADIUM] f on t.STAD=f.id_st and z.DATE_2 between f.DATEBEG and isnull(f.DATEEND,z.DATE_2)
       join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
      where (len(isnull(f.DS_St,'')) in (0,5) and z.DS1 != case f.DS_St when '' then z.DS1 when null then z.DS1 else f.DS_St end)
	    or (len(isnull(f.DS_St,'')) in (0,3) and substring(z.DS1,1,3) != case f.DS_St when '' then substring(z.DS1,1,3) when null then substring(z.DS1,1,3) else f.DS_St end)

-- Проверка №30.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'STAD', 'ONK_SL', z.n_zap, t.idcase, null, '904',  'Не указана стадия заболевания (STAD)' 
       from #SCHET_SLUCH_ONK t
       join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
      where t.DS1_T in (0,1,2,3,4) and t.stad is null

-- Проверка №30 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'STAD', 'ONK_SL', z.n_zap, t.idcase, null, '904',  'Значение STAD="'+isnull(cast(t.STAD as varchar),'')+'" не соответствует допустимому в справочнике N002' 
       from #SCHET_SLUCH_ONK t
       join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_N002_STADIUM] f on t.STAD=f.id_st and z.DATE_2 between f.DATEBEG and isnull(f.DATEEND,z.DATE_2)
      where f.id_st is null and t.STAD is not null

-- Проверка №29 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'PRVS', 'USL', z.n_zap, t.idcase, t.IDSERV, '904',  'Значение PRVS="'+isnull(cast(t.PRVS as varchar),'')+'" не соответствует допустимому в справочнике V021' 
       from #SCHET_USL t
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_V021_MED_SPEC] f on t.PRVS=f.idspec and z.DATE_2 between f.DATEBEG and isnull(f.DATEEND,z.DATE_2)
      where f.idspec is null 

-- Проверка №28 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'PRVS', 'SL', t.n_zap, t.idcase, null, '904',  'Значение PRVS="'+isnull(cast(t.PRVS as varchar),'')+'" не соответствует допустимому в справочнике V021' 
       from #TEMP_SLUCH t
       left join [IES].[T_V021_MED_SPEC] f on t.PRVS=f.idspec and t.DATE_2 between f.DATEBEG and isnull(f.DATEEND,t.DATE_2)
      where f.idspec is null 

-- Проверка №27 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DN', 'SL', t.n_zap, t.idcase, null, '904',  'Значение DN="'+isnull(cast(t.DN as varchar),'')+'" не соответствует допустимому значению (1,2,4,6)' 
       from #TEMP_SLUCH t
		join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','C','D')
  where t.DN not in (1,2,4,6)

-- Проверка №26.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'P_PER', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Некорректное заполнение поля P_PER'
 from #TEMP_Z_SLUCH zs
  join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','C')
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
      where (t.p_per = 4 and zs.date_z_1 = t.date_1)
         or (t.p_per is null and zs.usl_ok in (1,2))
         or (t.p_per is not null and zs.usl_ok in (3,4))
         or (t.p_per = 2 and zs.for_pom = 3)

-- Проверка №26 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'P_PER', 'SL', t.n_zap, t.idcase, null, '904',  'Значение P_PER="'+isnull(cast(t.P_PER as varchar),'')+'" не соответствует допустимому значению (1,2,3,4)' 
       from #TEMP_SLUCH t
	   join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','C')
 where t.P_PER not in (1,2,3,4)

-- Проверка №25 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'P_CEL', 'SL', t.n_zap, t.idcase, null, '904',  'Значение P_CEL="'+isnull(cast(t.P_CEL as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from #TEMP_SLUCH t
	    join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','C','D')
        left join [IES].[T_V025_KPC] f on t.P_CEL=f.idpc and t.DATE_2 between f.DATEBEG and isnull(f.DATEEND,t.DATE_2)
      where f.idpc is null 
        and t.p_cel is not null

-- Проверка №24 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DET', 'SL', t.n_zap, t.idcase, null, '904',  'Значение DET="'+isnull(cast(t.DET as varchar),'')+'" не соответствует допустимому значению (0,1)' 
       from #TEMP_SLUCH t
	   join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','C','T')
      where t.det not in (0,1)

-- Проверка №23.5 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL_K', 'SL', ss.N_ZAP, ss.IDCASE, null, '904', 'На профиль PROFIL="'+isnull(cast(ss.profil as varchar),'')+'" нет утвержденных объемов'
 from #TEMP_SLUCH ss 
  JOIN #TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
	   join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','C','T')
 where not exists (SELECT 1 FROM IES.T_CHER_PROFIL_PROFIL_K t0 
                   JOIN IES.T_DICTIONARY_BASE t1 ON t1.DictionaryBaseID = t0.DictionaryBaseID
                   LEFT JOIN IES.T_V020_BED_PROFILE t2 ON t2.V020BedProfileID = t0.V020BedProfile
				   where t0.PROFIL=ss.PROFIL 
				     and year(ss.DATE_2) between t1.YearBegin and t1.YearEnd 
				     and month(ss.DATE_2) between t1.MonthBegin and t1.MonthEnd 
				  )
   and ssa.USL_OK in (1,2)
   and (@type != 693 or getdate() >= '01.03.2019')  

-- Проверка №23.4 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL_K', 'SL', ss.N_ZAP, ss.IDCASE, null, '904', 'Значение поля PROFIL_K="'+isnull(cast(ss.profil_k as varchar),'')+'"  не соответствует значению полю  PROFIL="'+isnull(cast(ss.profil as varchar),'')+'"'
 from #TEMP_SLUCH ss 
  JOIN #TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
	   join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','C','T')
 where not exists (SELECT 1 FROM IES.T_CHER_PROFIL_PROFIL_K t0 
                   JOIN IES.T_DICTIONARY_BASE t1 ON t1.DictionaryBaseID = t0.DictionaryBaseID
                   LEFT JOIN IES.T_V020_BED_PROFILE t2 ON t2.V020BedProfileID = t0.V020BedProfile
				   where t2.IDK_PR=ss.PROFIL_K and t0.PROFIL=ss.PROFIL 
				  )
   and ssa.USL_OK in (1,2)
   and (@type != 693 or getdate() >= '01.03.2019')  
             

-- Проверка №23.3 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL_K', 'SL', ss.N_ZAP, ss.IDCASE, null, '904', 'Значение поля PROFIL_K="'+isnull(cast(ss.profil_k as varchar),'')+'"  не соответствует значению полю  PROFIL="'+isnull(cast(ss.profil as varchar),'')+'" для медицинской реабилитации'
 from #TEMP_SLUCH ss 
  JOIN #TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
	   join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','C','T')
 where (ss.PROFIL != 158 and ss.PROFIL_K in (30,31,32))

-- Проверка №23.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL_K', 'SL', ss.N_ZAP, ss.IDCASE, null, '904', 'Заполнено поле PROFIL_K для USL_OK="'+isnull(cast(ssa.USL_OK as varchar),'')+'"'
 from #TEMP_SLUCH ss 
  JOIN #TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
	   join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','C','T')
 where ssa.USL_OK in (3,4) and ss.PROFIL_K is not null

-- Проверка №23.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL_K', 'SL', ss.N_ZAP, ss.IDCASE, null, '904', 'Не заполнено поле PROFIL_K для USL_OK="'+isnull(cast(ssa.USL_OK as varchar),'')+'"'
 from #TEMP_SLUCH ss 
  JOIN #TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
	   join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','C','T')
 where ssa.USL_OK in (1,2) and ss.PROFIL_K is null

-- Проверка №23 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'PROFIL_K', 'SL', t.n_zap, t.idcase, null, '904',  'Значение PROFIL_K="'+isnull(cast(t.PROFIL_K as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from #TEMP_SLUCH t
	   join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','C','T')
       left join [IES].[T_V020_BED_PROFILE] f on t.PROFIL_K=f.idk_pr and t.DATE_2 between f.DATEBEG and isnull(f.DATEEND,t.DATE_2)
      where f.idk_pr is null 
        and t.profil_k is not null

-- Проверка №22 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'PROFIL', 'USL', z.n_zap, t.idcase, t.IDSERV, '904',  'Значение PROFIL="'+isnull(cast(t.PROFIL as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from #SCHET_USL t
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_V002_PROFILE] f on t.PROFIL=f.idpr and t.DATE_IN between f.DATEBEG and isnull(f.DATEEND,t.DATE_IN)
      where f.idpr is null 

-- Проверка №21 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'PROFIL', 'SL', t.n_zap, t.idcase, null, '904',  'Значение PROFIL="'+isnull(cast(t.PROFIL as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from #TEMP_SLUCH t
       left join [IES].[T_V002_PROFILE] f on t.PROFIL=f.idpr and t.DATE_2 between f.DATEBEG and isnull(f.DATEEND,t.DATE_2)
      where f.idpr is null 

-- Проверка №20 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'METOD_HMP', 'SL', t.n_zap, t.idcase, null, '904',  'Значение METOD_HMP="'+cast(t.METOD_HMP as varchar)+'" не соответствует допустимому в справочнике' 
       from #TEMP_SLUCH t
	   join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T')
       left join [IES].[T_V019_VMP_METHOD] f on t.METOD_HMP=f.idhm and t.DATE_2 between f.DATEBEG and isnull(f.DATEEND,t.DATE_2)
      where f.idhm is null

-- Проверка №20.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'METOD_HMP', 'SL', t.n_zap, t.idcase, null, '904',  'Значение METOD_HMP="'+cast(t.METOD_HMP as varchar)+'" не соответствует указанному коду МКБ DS1="'
	   +cast(t.DS1 as varchar)+'"' 
       from #TEMP_SLUCH t
	   join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T')
       left join [IES].[T_V019_VMP_METHOD] f on t.METOD_HMP=f.idhm and t.DATE_2 between f.DATEBEG and isnull(f.DATEEND,t.DATE_2)
	    and (f.DIAG = SUBSTRING(t.DS1,1,3)
			or f.DIAG like '%'+SUBSTRING(t.DS1,1,3)
			or f.DIAG like '%'+SUBSTRING(t.DS1,1,3)+';%'
			or f.DIAG like '%'+t.DS1+';%'
			or f.DIAG = t.DS1
			or f.DIAG like '%'+t.DS1
			)
      where f.idhm is null

-- Проверка №19.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'VID_HMP', 'SL', t.n_zap, t.idcase, null, '904',  'Значение VID_HMP="'+cast(t.VID_HMP as varchar)+'" не соответствует допустимому профилю МП PROFIL="'+cast(t.PROFIL as varchar)+'"' 
       from #TEMP_SLUCH t
	   join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T')
       left join [IES].[T_CHER_GR_VMP_PROFIL] f on cast(f.gr_vmp as varchar) = substring(t.vid_hmp,dbo.instr(t.vid_hmp,'.',1,2)+1,case dbo.instr(t.vid_hmp,'.',1,3)-dbo.instr(t.vid_hmp,'.',1,2)-1 when -1 then 0 else dbo.instr(t.vid_hmp,'.',1,3)-dbo.instr(t.vid_hmp,'.',1,2)-1 end)
	                                                and f.profil=t.PROFIL  
      where f.profil is null
        and (@type != 693 or getdate() >= '01.03.2019')  

-- Проверка №19 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'VID_HMP', 'SL', t.n_zap, t.idcase, null, '904',  'Значение VID_HMP="'+cast(t.VID_HMP as varchar)+'" не соответствует допустимому в справочнике' 
       from #TEMP_SLUCH t
	   join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('T')
       left join [IES].[T_V018_VMP_TYPE] f on t.VID_HMP=f.idhvid and t.DATE_2 between f.DATEBEG and isnull(f.DATEEND,t.DATE_2)
      where f.idhvid is null

-- Проверка №18 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'IDSP', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Значение IDSP="'+isnull(cast(t.IDSP as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from #TEMP_Z_SLUCH t
       left join [IES].[T_V010_PAY] f on t.IDSP=f.idsp and t.DATE_Z_1 between f.DATEBEG and isnull(f.DATEEND,t.DATE_Z_1)
      where f.idsp is null 


-- Проверка №17 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'ISHOD', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Значение ISHOD="'+isnull(cast(t.ISHOD as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from #TEMP_Z_SLUCH t
       left join [IES].[T_V012_OUTCOME] f on t.ISHOD=f.idiz and t.DATE_Z_1 between f.DATEBEG and isnull(f.DATEEND,t.DATE_Z_1)
      where f.idiz is null 

-- Проверка №16 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'RSLT', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Значение RSLT="'+isnull(cast(t.RSLT as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from #TEMP_Z_SLUCH t
	   join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','C','T')
       left join [IES].[T_V009_RESULT] f on t.RSLT=f.idrmp and t.DATE_Z_1 between f.DATEBEG and isnull(f.DATEEND,t.DATE_Z_1)
      where f.idrmp is null 


-- Проверка №15 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'LPU', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Значение LPU="'+isnull(cast(t.LPU as varchar),'')+'" в блоке Z_SL не соответствует допустимому значению в справочнике' 
       from #TEMP_Z_SLUCH t
       left join [IES].[T_F003_MO] f on t.LPU=f.mcod and t.DATE_Z_2 between f.D_BEGIN and isnull(f.D_END,t.DATE_Z_2)
      where f.mcod is null
			
-- Проверка №14.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'LPU', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Значение LPU="'+isnull(cast(t.LPU as varchar),'')+'" в блоке Z_SL не соответствует значению поля CODE_MO="'+isnull(cast(t.LPU as varchar),'')+'" в заголовке счета.' 
       from #TEMP_Z_SLUCH t
	   join #SCHET s on t.LPU != s.CODE_MO
 where  (@type != 693 or getdate() >= '01.03.2019')  

-- Проверка №14 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'LPU', 'USL', z.n_zap, t.idcase, t.IDSERV, '904',  'Значение LPU="'+isnull(cast(t.LPU as varchar),'')+'" в блоке USL не соответствует допустимому значению в справочнике' 
       from #SCHET_USL t
	   join #TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_F003_MO] f on t.LPU=f.mcod and z.DATE_2 between f.D_BEGIN and isnull(f.D_END,z.DATE_2)
      where f.mcod is null


-- Проверка №13 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'NPR_DATE', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Не заполнено обязательное поле NPR_DATE' 
       from #TEMP_Z_SLUCH t
        inner join #TEMP_SLUCH s on t.idcase=s.idcase
      where (
	   (t.FOR_POM=3 and t.USL_OK = 1) 
	or (t.USL_OK=2) 
--	or (s.DS1 like 'C%') 
--  or (s.DS1 between 'D00.00' and 'D09.99') 
--	or (s.DS1 between 'D70.00' and 'D70.99' and  exists(select 1 from #TEMP_DS t3  where t3.idcase=s.idcase and t3.sl_id=s.sl_id and (t3.ds between 'C00.00' and 'C80.99' or t3.ds between 'C97.00' and 'C97.99')))
	) and isnull(t.NPR_DATE,'')='' 

-- Проверка №12 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'NPR_MO', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Не заполнено обязательное поле NPR_MO' 
       from #TEMP_Z_SLUCH t
        inner join #TEMP_SLUCH s on t.idcase=s.idcase
      where (
	   (t.FOR_POM=3 and t.USL_OK = 1) 
	or (t.USL_OK=2) 
--	or (s.DS1 like 'C%') 
--    or (s.DS1 between 'D00.00' and 'D09.99') 
--	or (s.DS1 between 'D70.00' and 'D70.99' and  exists(select 1 from #TEMP_DS t3  where t3.idcase=s.idcase and t3.sl_id=s.sl_id and (t3.ds between 'C00.00' and 'C80.99' or t3.ds between 'C97.00' and 'C97.99')))
	) and isnull(t.NPR_MO,'')='' 

-- Проверка №11 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'NPR_MO', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Значение NPR_MO="'+isnull(cast(t.NPR_MO as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from #TEMP_Z_SLUCH t
       left join [IES].[T_F003_MO] f on t.NPR_MO=f.mcod and t.NPR_DATE between f.D_BEGIN and isnull(f.D_END,t.NPR_DATE)
      where f.mcod is null 
        and t.npr_mo is not null

-- Проверка №10 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'FOR_POM', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Значение FOR_POM="'+isnull(cast(t.FOR_POM as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from #TEMP_Z_SLUCH t
       left join [IES].[T_V014_MEDICAL_FORM] f on t.for_pom=f.idfrmmp and t.DATE_Z_2 between f.DATEBEG and isnull(f.DATEEND,t.DATE_Z_2)
      where f.idfrmmp is null

-- Проверка №9 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'VID_POM', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Значение VID_POM="'+isnull(cast(t.VIDPOM as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from #TEMP_Z_SLUCH t
       left join [IES].[T_V008_MEDICAL_TYPE] f on t.vidpom=f.idvmp and t.DATE_Z_2 between f.DATEBEG and isnull(f.DATEEND,t.DATE_Z_2)
      where f.idvmp is null 

-- Проверка №8 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'USL_OK', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Значение USL_OK="'+isnull(cast(t.USL_OK as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from #TEMP_Z_SLUCH t
       left join [IES].[T_V006_MEDICAL_TERMS] f on t.usl_ok=f.idump and t.DATE_Z_2 between f.DATEBEG and isnull(f.DATEEND,t.DATE_Z_2)
      where f.idump is null

-- Проверка №7 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'INV', 'PACIENT', t.n_zap, t.idcase, null, '904',  'Значение INV="'+isnull(cast(z.INV as varchar),'')+'" не соответствует допустимому (0,1,2,3,4)' 
       from #TEMP_Z_SLUCH t
	    join #TEMP_ZAP z on z.N_ZAP=t.N_ZAP
		join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('H','C')
      where z.INV not in (0,1,2,3,4) 

-- Проверка №6.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'ST_OKATO', 'PACIENT', t.n_zap, z.idcase, null, '904',  'Значение ST_OKATO не соотвертсвует справочнику' 
       from #TEMP_Z_SLUCH z
	    join #TEMP_ZAP t on z.N_ZAP=t.N_ZAP
        left join [IES].[T_F002_SMO] f on t.ST_OKATO=f.TF_OKATO and z.DATE_Z_2 between f.D_BEGIN and isnull(f.D_END, z.DATE_Z_2)
      where t.ST_OKATO is not null
        and f.SMOCOD is null

-- Проверка №6.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'SMO_OK', 'PACIENT', t.n_zap, z.idcase, null, '904',  'Значение SMO_OK не соотвертсвует справочнику' 
       from #TEMP_Z_SLUCH z
	    join #TEMP_ZAP t on z.N_ZAP=t.N_ZAP
        left join [IES].[T_F002_SMO] f on t.SMO_OK=f.TF_OKATO and z.DATE_Z_2 between f.D_BEGIN and isnull(f.D_END, z.DATE_Z_2)
      where t.SMO_OK is not null
        and f.SMOCOD is null

-- Проверка №6 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'SMO_OK', 'PACIENT', t.n_zap, z.idcase, null, '904',  'Не заполнено обязательное поле SMO_OK' 
       from #TEMP_Z_SLUCH z
	    join #TEMP_ZAP t on z.N_ZAP=t.N_ZAP
      where t.smo_ok is null 
        and t.smo is null
        and t.SMO_OGRN is null
		and @type in (554,693)

-- Проверка №5 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'SMO_OGRN', 'PACIENT', t.n_zap, z.idcase, null, '904',  'Не заполнено обязательное поле SMO_OGRN' 
       from #TEMP_Z_SLUCH z
	    join #TEMP_ZAP t on z.N_ZAP=t.N_ZAP
      where t.smo_ogrn is null 
        and t.smo is null
        and t.smo_nam is null

-- Проверка №4 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'SMO', 'PACIENT', t.n_zap, z.idcase, null, '904',  'Значение SMO="'+isnull(cast(t.SMO as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from #TEMP_Z_SLUCH z
	    join #TEMP_ZAP t on z.N_ZAP=t.N_ZAP
        left join [IES].[T_F002_SMO] f on t.smo=f.smocod and z.DATE_Z_1 between f.D_BEGIN and isnull(f.D_END,z.DATE_Z_1)
      where f.smocod is null 
        and t.smo is not null

-- Проверка №3.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'SPOLIS', 'PACIENT', t.n_zap, z.idcase, null, '904',  'При значение VPOLIS="'+isnull(cast(t.VPOLIS as varchar),'')+'" SPOLIS должен отсутствовать' 
       from #TEMP_Z_SLUCH z
	    join #TEMP_ZAP t on z.N_ZAP=t.N_ZAP
      where t.VPOLIS in (2,3) and t.SPOLIS is not null

-- Проверка №3.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'NPOLIS', 'PACIENT', t.n_zap, z.idcase, null, '904',  'При значение VPOLIS="'+isnull(cast(t.VPOLIS as varchar),'')+'" NPOLIS не равен 9 знакам' 
       from #TEMP_Z_SLUCH z
	    join #TEMP_ZAP t on z.N_ZAP=t.N_ZAP
      where t.VPOLIS = 2 and len(t.NPOLIS) != 9

-- Проверка №3.3 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'NPOLIS', 'PACIENT', t.n_zap, z.idcase, null, '904',  'При значение VPOLIS="'+isnull(cast(t.VPOLIS as varchar),'')+'" NPOLIS не равен 16 знакам' 
       from #TEMP_Z_SLUCH z
	    join #TEMP_ZAP t on z.N_ZAP=t.N_ZAP
      where t.VPOLIS = 3 and len(t.NPOLIS) != 16

-- Проверка №3 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'VPOLIS', 'PACIENT', t.n_zap, z.idcase, null, '904',  'Значение VPOLIS="'+isnull(cast(t.VPOLIS as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from #TEMP_Z_SLUCH z
	    join #TEMP_ZAP t on z.N_ZAP=t.N_ZAP
       left join [IES].[T_F008_OMS_TYPE] f on t.vpolis=f.iddoc and z.DATE_Z_1 between f.DATEBEG and isnull(f.DATEEND,z.DATE_Z_1)
      where f.iddoc is null

-- Проверка №2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'PR_NOV', 'ZAP', t.n_zap, z.idcase, null, '904',  'Значение PR_NOV="'+isnull(cast(t.PR_NOV as varchar),'')+'" не соответствует допустимому значению (0,1)' 
       from #TEMP_Z_SLUCH z
	    join #TEMP_ZAP t on z.N_ZAP=t.N_ZAP
      where t.pr_nov not in (0,1) 	   

-- Проверка №1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'CODE_MO', 'SCHET', null, null, null, '904',  'Значение CODE_MO="'+isnull(cast(t.CODE_MO as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from #SCHET t
       left join [IES].[T_F003_MO] f on t.code_mo=f.mcod and t.DSCHET between f.D_BEGIN and ISNULL(f.D_END,t.dschet)
      where f.mcod is null 
END
      
--=========================================================================
-- -=КОНЕЦ=  Блок проверок по МТР от ЛПУ добавленных сотрудниками КОФОМС.
--=========================================================================



--проверка PRVS'ов на случаях
IF EXISTS(SELECT * FROM sys.foreign_keys WHERE object_id = object_id(N'[FK_T_V004_SPECIALITY_T_SCHET_SLUCH_PRVS]')) or EXISTS(SELECT * FROM sys.foreign_keys WHERE object_id = object_id(N'[FK_T_V015_MEDSPEC_T_SCHET_SLUCH_PRVS2]'))
BEGIN

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'PRVS', 'SLUCH', ss.N_ZAP, ss.IDCASE, null, '904', 'Значение поля PRVS не соответствует справочнику V004, поле VERS_SPEC=' + ISNULL(VERS_SPEC, 'НЕ заполнено, по умолчанию  V004')
from #TEMP_SLUCH ss
JOIN #TEMP_Z_SLUCH zs on (zs.IDCASE = ss.IDCASE)
left join [IES].T_V004_SPECIALITY v004 on (ss.PRVS = v004.IDMSP)
where ISNULL(VERS_SPEC, '') <> 'V015' and IDMSP is null and zs.[RSLT_D] is null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'PRVS', 'SLUCH', ss.N_ZAP, ss.IDCASE, null, '904', 'Значение поля PRVS не соответствует справочнику V015, поле VERS_SPEC=' + ISNULL(VERS_SPEC, 'НЕ заполнено, по умолчанию  V004')
from #TEMP_SLUCH ss
left join  IES.T_V015_MEDSPEC v015 on (ss.PRVS = v015.CODE)
where ISNULL(VERS_SPEC, '') = 'V015' and CODE is null

END

--проверка PRVS'ов на услугах
IF EXISTS(SELECT * FROM sys.foreign_keys WHERE object_id = object_id(N'[FK_T_V004_SPECIALITY_T_SCHET_USL_PRVS]')) or EXISTS(SELECT * FROM sys.foreign_keys WHERE object_id = object_id(N'[FK_T_V015_MEDSPEC_T_SCHET_USL_PRVS2]'))
BEGIN

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'PRVS', 'USL', ss.N_ZAP, su.IDCASE, su.IDSERV, '904', 'Значение поля PRVS не соответствует справочнику V004, поле VERS_SPEC=' + ISNULL(VERS_SPEC, 'НЕ заполнено, по умолчанию  V004')
from #SCHET_USL su
JOIN #TEMP_SLUCH ss on (ss.IDCASE=su.IDCASE)
JOIN #TEMP_Z_SLUCH zs on (zs.IDCASE = ss.IDCASE)
left join [IES].T_V004_SPECIALITY v004 on (su.PRVS = v004.IDMSP)
where ISNULL(VERS_SPEC, '') <> 'V015' and IDMSP is null and zs.[RSLT_D] is null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'PRVS', 'USL', ss.N_ZAP, su.IDCASE, su.IDSERV, '904', 'Значение поля PRVS не соответствует справочнику V015, поле VERS_SPEC=' + ISNULL(cast(VERS_SPEC as varchar(40)), 'НЕ заполнено, по умолчанию  V004')
from #SCHET_USL su
JOIN #TEMP_SLUCH ss on (ss.IDCASE=su.IDCASE)
left join  IES.T_V015_MEDSPEC v015 on (su.PRVS = v015.CODE)
where ISNULL(VERS_SPEC, '') = 'V015' and CODE is null

END

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'PRVS', 'USL', ss.N_ZAP, su.IDCASE, su.IDSERV, '904', 'Значение поля PRVS не соответствует справочнику V021(' + ISNULL(cast(ss.PRVS as varchar(10)), 'NULL') +'), поле VERS_SPEC=' + ISNULL(cast(VERS_SPEC as varchar(40)), 'НЕ заполнено, по умолчанию  V021')
from #SCHET_USL su
JOIN #TEMP_SLUCH ss on (ss.SL_ID=su.SL_ID)
JOIN #TEMP_Z_SLUCH zs on (zs.IDCASE = ss.IDCASE)
left join  IES.T_V021_MED_SPEC v021 on (su.PRVS = v021.IDSPEC)
where (ISNULL(VERS_SPEC, 'V021') = 'V021'or zs.RSLT_D is not null) and IDSPEC is null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'C_ZAB', 'SL', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '904', 'C_ZAB Обязательно к заполнению, если USL_OK не равен 4 или основной диагноз (DS1) не входит в рубрику Z'
from #TEMP_SLUCH ss
join #TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
where ss.C_ZAB is null and (ssa.USL_OK<>4 and ss.DS1 not like 'Z%') and (select s.[FILENAME] from #SCHET s) not like 'D%'

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'KD_Z', 'SLUCH', zs.N_ZAP, null, NULL,  '905', 'Не заполнено поле KD_Z'
from #TEMP_Z_SLUCH zs join #TEMP_SLUCH ss on zs.IDCASE=ss.IDCASE
where ((zs.USL_OK = 1 or zs.USL_OK = 2) or (select [filename] from #SCHET ) like 'T%' ) and zs.KD_Z is null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAPR_MO', 'NAZ', ss.N_ZAP, ss.IDCASE, ss.SL_ID,  null, '905', 'Значение поля NAPR_MO не соответствует справочнику f003'
from #TEMP_SL_NAZ naz 
join #TEMP_SLUCH ss on ss.IDCASE = naz.IDCASE and naz.SL_ID = ss.SL_ID
left join ies.T_F003_MO f003 on (naz.NAPR_MO = f003.MCOD)
where f003.MCOD is null and naz.NAPR_MO is not null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAPR_MO', 'NAPR', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Значение поля NAPR_MO не соответствует справочнику f003'
from #SCHET_USL_NAPR napr
join #TEMP_SLUCH ss on ss.IDCASE = napr.IDCASE and napr.SL_ID = ss.SL_ID
left join ies.T_F003_MO f003 on (napr.NAPR_MO = f003.MCOD)
where f003.MCOD is null and napr.NAPR_MO is not null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAPR_V', 'NAPR', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Значение поля NAPR_V не соответствует справочнику v028'
from #SCHET_USL_NAPR napr
join #TEMP_SLUCH ss on ss.IDCASE = napr.IDCASE and napr.SL_ID = ss.SL_ID
left join ies.T_V028_NAPR_V V028 on (napr.NAPR_V = V028.IDVN)
where V028.IDVN is null and napr.NAPR_V is not null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'MET_ISSL', 'NAPR', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Значение поля MET_ISSL не соответствует справочнику v029'
from #SCHET_USL_NAPR napr
join #TEMP_SLUCH ss on ss.IDCASE = napr.IDCASE and napr.SL_ID = ss.SL_ID
left join ies.T_V029_MET_ISSL V029 on (napr.MET_ISSL = v029.IDMET)
where v029.IDMET is null and napr.MET_ISSL is not null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'MET_ISSL', 'NAPR', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Поле NAPR.MET_ISSL  Обязательно  к заполнению для случаев с  NAPR.NAPR_V=3'
from #SCHET_USL_NAPR napr
join #TEMP_SLUCH ss on ss.IDCASE = napr.IDCASE and napr.SL_ID = ss.SL_ID
where napr.NAPR_V = 3 and napr.MET_ISSL is null and (select s.[FILENAME] from #SCHET s) not like 'D%' and (select s.[FILENAME] from #SCHET s) not like 'H%'

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'NAPR_USL', 'NAPR', ss.N_ZAP, ss.IDCASE, null, '905', 'Поле NAPR.NAPR_USL Обязательно  к заполнению для случаев с  заполненным полем NAPR.MET_ISSL'
from #SCHET_USL_NAPR napr
join #TEMP_SLUCH ss on ss.IDCASE = napr.IDCASE and napr.SL_ID = ss.SL_ID
where napr.MET_ISSL is not null and napr.NAPR_USL is null and (select s.[FILENAME] from #SCHET s) not like 'H%'

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAPR_USL', 'NAPR', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Поле NAPR.NAPR_USL не соответствует значениям справочника V001'
from #SCHET_USL_NAPR napr
join #TEMP_SLUCH ss on ss.IDCASE = napr.IDCASE and napr.SL_ID = ss.SL_ID
left join ies.T_V001_NOMENCLATURE V001 on (napr.NAPR_USL = V001.Code)
where V001.Code is null and napr.NAPR_USL is not null 

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PR_CONS', 'CONS', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Поле PR_CONS не соответствует значениям справочника v019'
from #TEMP_SLUCH_CONS co
join #TEMP_SLUCH ss on ss.IDCASE = co.IDCASE and co.SL_ID = ss.SL_ID
left join ies.T_N019_ONK_CONS n019 on (co.PR_CONS = n019.ID_CONS)
where n019.ID_CONS is null and co.PR_CONS is not null 

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE,SL_ID, IDSERV, OSHIB, COMMENT)
select 'DT_CONS', 'CONS', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Поле CONS.DT_CONS Обязательно к заполнению при PR_CONS <> 0'
from #TEMP_SLUCH_CONS co
join #TEMP_SLUCH ss on ss.IDCASE = co.IDCASE and co.SL_ID = ss.SL_ID
where co.PR_CONS <> 0 and co.DT_CONS is null and (select s.[FILENAME] from #SCHET s) not like 'D%' and (select s.[FILENAME] from #SCHET s) not like 'H%' and ss.DS1 like 'C%'

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DT_CONS', 'CONS', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Поле CONS.DT_CONS Обязательно  к заполнению, если CONS.PR_CONS не равен 0'
from #TEMP_SLUCH_CONS co
join #TEMP_SLUCH ss on ss.IDCASE = co.IDCASE and co.SL_ID = ss.SL_ID
where co.DT_CONS is null and co.PR_CONS <> 0 and (select s.[FILENAME] from #SCHET s) not like 'D%' and (select s.[FILENAME] from #SCHET s) not like 'H%' and ss.DS1 like 'C%'

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'LEK_PR', 'REGNUM', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Поле LEK_PR. REGNUM Обязательно к заполнению при ONK_USL. USL_TIP=2 или  ONK_USL. USL_TIP=4'
from #SCHET_USL_ONK_LEK_PR co
join #TEMP_SLUCH ss on ss.IDCASE = co.IDCASE and co.SL_ID = ss.SL_ID
join #SCHET_USL_ONK usl on ss.IDCASE = co.IDCASE and co.SL_ID = ss.SL_ID
where (usl.USL_TIP = 2 or usl.USL_TIP = 4) and co.REGNUM is null and ((select s.[FILENAME] from #SCHET s) like 'C%' or (select s.[FILENAME] from #SCHET s) like 'T%')

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DIAG_CODE', 'B_DIAG', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', ' DIAG_CODE При DIAG_TIP=1 не соответствует значениям справочника N007.При DIAG_TIP=2 не соответствует значениям справочника N010'
from #SCHET_SLUCH_ONK_DIAG d
join #TEMP_SLUCH ss on ss.IDCASE = d.IDCASE and d.SL_ID = ss.SL_ID
left join ies.T_N007_MRF n007 on (d.DIAG_CODE = n007.ID_Mrf)
left join ies.T_N010_MARK n010 on (d.DIAG_CODE = n010.ID_Igh)
where (d.DIAG_TIP = 1 and n007.ID_Mrf is null and d.DIAG_CODE is not null) or (d.DIAG_TIP = 2 and n010.ID_Igh is null and d.DIAG_CODE is not null)

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DIAG_RSLT', 'B_DIAG', ss.N_ZAP, ss.IDCASE, ss.SL_ID,  null, '905', 'Поле B_DIAG. DIAG_RSLT При DIAG_TIP=1 не соответствует значениям справочника N008.При DIAG_TIP=2 не соответствует значениям справочника N011'
from #SCHET_SLUCH_ONK_DIAG d
join #TEMP_SLUCH ss on ss.IDCASE = d.IDCASE and d.SL_ID = ss.SL_ID
left join ies.T_N008_MRF_RT n008 on (d.DIAG_RSLT = n008.ID_R_M)
left join ies.T_N011_MARK_VALUE n011 on (d.DIAG_RSLT = n011.ID_R_I)
where (d.DIAG_TIP = 1 and n008.ID_R_M is null and d.DIAG_RSLT is not null) or (d.DIAG_TIP = 2 and n011.ID_R_I is null and d.DIAG_RSLT is not null)

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DKK1', 'KSG_KPG', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Поле KSG_KPG.DKK1 не соответствует значениям справочника V024 '
from #SCHET_KSG ksg
join #TEMP_SLUCH ss on ss.IDCASE = ksg.IDCASE and ksg.SL_ID = ss.SL_ID
left join ies.T_V024_DOP_KR v024 on (ksg.DKK1 = v024.IDDKK)
where v024.IDDKK is null and ksg.DKK1 is not null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'C_ZAB', 'SLUCH', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Значение поля C_ZAB не соответствует справочнику V027'
from #TEMP_SLUCH ss 
left join ies.T_V027_C_ZAB v027 on (ss.C_ZAB = v027.IDCZ)
where v027.IDCZ is null and ss.C_ZAB is not null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DS1_T', 'SLUCH', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Значение поля DS1_T не соответствует справочнику n018'
from #SCHET_SLUCH_ONK onk 
join #TEMP_SLUCH ss on ss.IDCASE = onk .IDCASE and onk.SL_ID = ss.SL_ID
left join ies.T_N018_ONK_REAS n018 on (onk.DS1_T = n018.ID_REAS)
where n018.ID_REAS is null and onk.DS1_T is not null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PRVS', 'SL', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '904', 'Значение поля PRVS не соответствует справочнику V021 (' + ISNULL(cast(ss.PRVS as varchar(10)), 'NULL') +') , поле VERS_SPEC=' + ISNULL(cast(VERS_SPEC as varchar(40)), 'НЕ заполнено, по умолчанию  V021')
from #TEMP_SLUCH ss
JOIN #TEMP_Z_SLUCH zs on (zs.IDCASE = ss.IDCASE)
left join  IES.T_V021_MED_SPEC v021 on (ss.PRVS = v021.IDSPEC)
where (ISNULL(VERS_SPEC, 'V021') = 'V021' and zs.RSLT_D is null) and IDSPEC is null


insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'PRVS', 'SLUCH', ss.N_ZAP, ss.IDCASE, null, '904', 'Значение поля NPR_MO не соответствует справочнику F003'
from #TEMP_Z_SLUCH ss
left join  IES.T_F003_MO f003 on (f003.MCOD = ss.npr_mo)
where ss.npr_mo is not null and f003.MCOD is null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'OPLATA', 'SLUCH', op.N_ZAP, op.IDCASE, null, '905', 'Значение поля RSLT_D не соответствует справочнику V017'
from #TEMP_Z_SLUCH op 
left join ies.T_V017_DISP_RESULT v017 on (op.RSLT_D = v017.IDDR)
where v017.IDDR is null and op.RSLT_D is not null

--проверка уникальности идентификаторов
insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'N_ZAP', 'ZAP', N_ZAP, null, null, '905', 'Дублирующий идентификатор N_ZAP' from #TEMP_ZAP
group by N_ZAP
having count(*)>1

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'IDCASE', 'SLUCH', null, IDCASE, null, '905', 'Дублирующий идентификатор IDCASE' from #TEMP_Z_SLUCH
group by IDCASE
having count(*)>1

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'SL_ID', 'SLUCH', null, IDCASE, null, '905', 'Дублирующий идентификатор SL_ID в рамках IDCASE ' + SL_ID from #TEMP_SLUCH
group by IDCASE, SL_ID
having count(*)>1

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'IDSERV', 'USL', null, IDCASE, IDSERV, '905', 'Дублирующий идентификатор IDSERV в пределах одного SL' from #SCHET_USL
group by IDSERV, SL_ID, IDCASE
having count(*)>1

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
--select 'SCHET', 'DISP', null, null, null, '905', 'Не существует актуального кода диспансеризации = ' + cast(s.DISP as varchar(36))
--from #SCHET s
-- join #SCHET t on SUBSTRING(t.FILENAME,1,1) in ('D')  
--LEFT JOIN  IES.T_V016_DISPT d on (s.DISP = d.IDDT and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate))
--where d.V016ID is null and s.DISP is not null
select 'DISP', 'SCHET', zs.N_ZAP, zs.IDCASE, null, '905', 'Не существует актуального кода диспансеризации = ' + cast(s.DISP as varchar(36))
from #TEMP_Z_SLUCH zs
 join #SCHET s on SUBSTRING(s.FILENAME,1,1) in ('D')  
LEFT JOIN  IES.T_V016_DISPT d on (s.DISP = d.IDDT and DATEBEG<=zs.DATE_Z_2 and (DATEEND is null or DATEEND>=zs.DATE_Z_2))
where d.V016ID is null and s.DISP is not null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'SCHET', 'S_OSN', null, null, null, '905', 'Не существует актуального основания отказа = ' + cast(s.S_OSN as varchar(36))
from #TEMP_SANK s
LEFT JOIN  IES.T_F014_DENY_REASON f014 on (f014.kod = s.[S_OSN] and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate))
where f014.F014DenyReasonID is null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'SCHET', 'S_OSN', ss.N_ZAP, ss.IDcase,  null,  '905', 'Обязательно к заполнению в соответствии с F014 (Классификатор причин отказа в оплате медицинской помощи, Приложение А), если S_SUM не равна 0'
from #TEMP_SANK s
join #TEMP_Z_SLUCH ss on ss.IDCASE = s.IDCASE 
where s.S_OSN is null and s.S_SUM <> 0

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'OPLATA', 'SLUCH', op.N_ZAP, op.IDCASE, null, '904', 'OPLATA = 2 (не оплачено), но отсутствует коллекции SANK'
from #TEMP_Z_SLUCH op 
left join #TEMP_SANK ss on (op.IDCASE = ss.IDCASE)
where op.OPLATA = 2 and ss.S_CODE is null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'OPLATA', 'SLUCH', op.N_ZAP, op.IDCASE, null, '904', 'OPLATA = 2 (не оплачено), но сумма принятая не удержана'
from #TEMP_Z_SLUCH op 
where op.OPLATA = 2 and ISNULL(op.SUMP, -1) <> 0

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'OPLATA', 'SLUCH', op.N_ZAP, op.IDCASE, null, '904', 'OPLATA = 1 (полная оплата), но сумма принятая равна 0'
from #TEMP_Z_SLUCH op 
where op.OPLATA = 1 and ISNULL(op.SUMP, 0) = 0 and ISNULL(op.SUMV, 0) <> 0

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'OPLATA', 'SLUCH', op.N_ZAP, op.IDCASE, null, '904', 'OPLATA = 0 (не принято решение об оплате), но сумма принятая равна 0'
from #TEMP_Z_SLUCH op 
where op.OPLATA = 0 and ISNULL(op.SUMP, 0) = 0 and ISNULL(op.SUMV, 0) <> 0

--insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
--select 'N_KSG', 'SLUCH', ss.N_ZAP, ss.IDCASE, null, '905', 'При заполненном CODE_MES1, N_KSG обязателен'
--from #TEMP_SLUCH ss
--left join #SCHET_KSG ksg on (ss.IDCASE = ksg.IDCASE and ss.SL_ID = ksg.SL_ID)
--where ss.CODE_MES1 is not null and ksg.N_KSG is null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'P_CEL', 'SLUCH', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '904', 'Значение поля P_CEL обязательно для заполнения при АПП'
from #TEMP_SLUCH ss
join #TEMP_Z_SLUCH ssa on (ss.IDCASE = ssa.IDCASE)
where ssa.USL_OK = 3 and ss.P_CEL is null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'VERSION', 'SCHET', null, null, null, '905', 'счета мтр от лпу не должны выставляться в версии 3.11' from #SCHET
where @type = 554 and [VERSION] = '3.11'

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE,SL_ID, IDSERV, OSHIB, COMMENT)
select 'VID_HMP', 'SLUCH', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '904', 'Значение поля VID_HMP не соответствует справочнику v018 (Нет значения ' + ss.VID_HMP + ')'
from #TEMP_SLUCH ss
left join IES.T_V018_VMP_TYPE v018 on (ss.VID_HMP = v018.IDHVID)
where ss.VID_HMP is not null and  v018.IDHVID is null

--	--	old checks (warning)
--insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
--select 'ENP', 'ZAP', N_ZAP, null, null, '905', 'ENP не заполнено' from #TEMP_ZAP
--where @type = 554 and (ENP is null or len(enp) < 1)
--нет поля ENP!!!!

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PROFIL', 'SLUCH', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '904', 'Значение поля PROFIL не соответствует справочнику v002 (Нет значения ' + cast(ss.PROFIL as varchar(500))+ ') на дату окончания случая'
from #TEMP_SLUCH ss
left join [IES].T_V002_PROFILE v002 on (ss.PROFIL = v002.IDPR and (v002.DATEEND is null  or DATEEND >= ss.DATE_2))
where ss.PROFIL is not null and  v002.IDPR is null 

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'RSLT_D', 'SLUCH', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '904', 'Значение поля RSLT_D не соответствует справочнику v017 (Нет значения ' + cast(zs.RSLT_D as varchar(500)) + ') на дату окончания случая'
from #TEMP_SLUCH ss
JOIN #TEMP_Z_SLUCH zs on (zs.IDCASE = ss.IDCASE)
left join [IES].T_V017_DISP_RESULT v017 on (zs.RSLT_D = v017.IDDR and (v017.DATEEND is null  or DATEEND >= ss.DATE_2))
where zs.RSLT_D is not null and  v017.IDDR is null 

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'RSLT', 'SLUCH', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '904', 'Значение поля RSLT не соответствует справочнику v009 (Нет значения ' + cast(zs.RSLT as varchar(500)) + ') на дату окончания случая'
from #TEMP_SLUCH ss
JOIN #TEMP_Z_SLUCH zs on (zs.IDCASE = ss.IDCASE)
left join [IES].T_V009_RESULT v009 on (zs.RSLT = v009.IDRMP and (v009.DATEEND is null  or DATEEND >= ss.DATE_2))
where zs.RSLT is not null and  v009.IDRMP is null 

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'METOD_HMP', 'SLUCH', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '904', 'Значение поля METOD_HMP не соответствует справочнику v009 (Нет значения ' + cast(ss.METOD_HMP as varchar(500)) + ') на дату окончания случая'
from #TEMP_SLUCH ss
left join [IES].T_V019_VMP_METHOD v019 on (ss.METOD_HMP = v019.IDHM and (v019.DATEEND is null  or DATEEND >= ss.DATE_2))
where ss.METOD_HMP is not null and v019.IDHM is null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'TYPE', 'SCHET', null, null,null, '905', 'Неправильное имя файла на идентификацию в ТФОМС' 
from #SCHET schet
where @type = '562' and schet.[FILENAME] like '%S400%'

-- Уникальность счёта
insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'CODE', 'SCHET', null, null,null, '905', 
	'Счет с таким CODE=' + schet.code + ' и CODE_MO=' + schet.CODE_MO + ' уже загружен, со следующими полями NSCHET=' + schet.NSCHET + 
	',PLAT=' + isnull(schet.PLAT, '') + ',YEAR=' + cast(schet.[YEAR] as varchar(10)) + ',MONTH=' + cast(schet.[MONTH] as varchar(10)) + 
	',DSCHET=' + cast(schet.DSCHET as varchar(10)) + ',FILENAME=' + schet.[FILENAME] + '' 
from #SCHET schet
join ies.T_SCHET s on s.CODE = schet.code and s.CODE_MO = schet.CODE_MO and s.PLAT=schet.PLAT
where (s.NSCHET <> schet.NSCHET or isnull(s.PLAT, 0) <> isnull(schet.PLAT, 0) 
	or s.[FILENAME] <> schet.[FILENAME] or s.[YEAR] <> schet.[YEAR] or s.[MONTH] <> schet.[MONTH] or s.DSCHET <> schet.DSCHET) 
	and s.type_ <> '562' and @type <> '562' and s.type_ = @type and s.IsDelete = 0

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'TYPE', 'SCHET', null, null,null, '905', 'Неправильное имя файла территорального счета на загрузку от СМО' 
from #SCHET schet
where @type = '693' and substring ([FILENAME],1,3) not in ('HS4', 'TS4', 'DVS', 'DPS', 'DFS', 'DOS', 'DUS', 'DSS', 'CS4')

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'SCHET', 'PLAT', null, null, null, '905', 'Не временный счет. Поле PLAT не заполнено'
from #SCHET s 
where s.PLAT is null and @type <> '562' and @type <> '554'

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PROFIL_K', 'SL', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '904', 'Значение поля PROFIL_K не подано для стационара и дневного стационара'
from #TEMP_SLUCH ss
JOIN #TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
where (ssa.USL_OK = 1 or ssa.USL_OK = 2) and ss.PROFIL_K is null and (select top 1 [filename] from #SCHET) not like 'T%'

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'SCHET', 'PLAT', null, null, null, '905', 'Значение поля PLAT не соответствует справочнику f002 = ' + cast(s.PLAT as varchar(36))
from #SCHET s 
LEFT JOIN  IES.T_F002_SMO f002 on (s.PLAT = f002.SMOCOD)
where f002.SMOCOD is null and s.PLAT is not null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'SUMP', 'SLUCH', ssa.N_ZAP, ssa.IDCASE, null, '904', 'SUMP, суммая принятам к оплаете должна быть больше 0'
from #TEMP_Z_SLUCH ssa 
where ssa.SUMP < 0 and @type <> '562'

/*
-- перенесена в блок проверок ТФОМС
insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CODE_USL', 'USL', ss.N_ZAP, su.IDCASE, ss.SL_ID, su.IDSERV, '904', 'Значение поля CODE_USL в USL не соответствует региональному справочнику (Нет значения ' + cast(su.CODE_USL as varchar(36)) + ')'
from #SCHET_USL su
JOIN #TEMP_SLUCH ss on (ss.IDCASE=su.IDCASE)
left join  IES.R_NSI_USL nsi on (su.CODE_USL = nsi.CODE_USL)
where su.CODE_USL is not null and  nsi.CODE_USL is null
*/
--просили убрать тк такая логика только для поля RSLT
--insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
--select 'USL_OK', 'SL', ssa.N_ZAP, ssa.IDCASE, null, '904', 'Условия оказания мед помощи не соответствуют результату обращения USL_OK и RSLT(RSLT_D)'
--from #TEMP_Z_SLUCH ssa 
--where ssa.USL_OK <> ISNULL(ISNULL(CAST((substring (cast(ssa.RSLT as varchar), 1 ,1)) as int),CAST((substring (cast(ssa.RSLT_D as varchar), 1 ,1)) as int)), 0)
/*
insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'RSLT', 'Z_SL', ssa.N_ZAP, ssa.IDCASE, null, '904', 'Условия оказания мед помощи не соответствуют результату обращения USL_OK и RSLT'
from #TEMP_Z_SLUCH ssa 
 join #SCHET s on s.YEAR >= 2018 and s.MONTH >= 9 and substring(s.FILENAME,1,1) in ('H','T','C','h','t','c')
where ssa.USL_OK <> ISNULL(CAST((substring (isnull(cast(ssa.RSLT as varchar),''), 1 ,1)) as int),0) and ssa.RSLT is not null -- and (select [FILENAME] from #SCHET) not like 'D%'
*/
insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'N_KSG', 'KSG', ssa.N_ZAP, ssa.IDCASE, ss.SL_ID,  null, '905', 'Код КСГ не соответствует справочнику КСГ на условие оказание МП' 
from #SCHET_KSG ksg 
join #TEMP_Z_SLUCH ssa on ssa.IDCASE = ksg.IDCASE
join #TEMP_SLUCH ss on ss.IDCASE = ksg.IDCASE and ss.SL_ID = ksg.SL_ID
left join [IES].[T_V023_KSG] v023 on ksg.N_KSG = v023.K_KSG
left join ies.T_V006_MEDICAL_TERMS v006 on v023.V006MedicalTerms = v006.IDUMP and cast(ssa.USL_OK as int) = v006.IDUMP
where ssa.USL_OK <> v006.IDUMP and ksg.N_KSG is not null and v006.IDUMP is not null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SCHET', 'NSCHET', ss.IDCASE, ss.IDCASE, ss.SL_ID, null, '905', 'Поле IDSL не соответствует справочнику КСЛП, нет значения ' + cast(s.IDSL as varchar(10)) 
from #SCHET_KSG_KOEF s
join #TEMP_SLUCH ss on ss.IDCASE = s.IDCASE and ss.SL_ID = s.SL_ID 
left join [IES].[R_NSI_KSLP] ks on ks.IDSL = s.IDSL
where s.IDSL is not null and ks.IDSL is null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'SUM_M', 'SL', ssa.N_ZAP, ssa.IDCASE, null, '904', 'Сумма высталенная к оплате на законченном случае SUMV не равна сумме выставленной на случаях SUM_M'
from #TEMP_Z_SLUCH ssa 
where ssa.SUMV <> (select sum(ss.SUM_M) from #TEMP_SLUCH ss where ssa.IDCASE = ss.IDCASE)

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'SUMMAP', 'SCHET', ssa.N_ZAP, ssa.IDCASE, null, '904', 'Сумма оплаты на законченном случае SUMP не равна сумме на шапке SUMMAP'
from #TEMP_Z_SLUCH ssa 
where (select SUMMAP from #SCHET) <> (select sum(ssa.SUMP) from #TEMP_Z_SLUCH ssa)

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NPR_MO', 'Z_SL', ssa.N_ZAP, ssa.IDCASE, null, null, '904', 'Не заполнено NPR_DATE'
from #TEMP_Z_SLUCH ssa
where (((ssa.FOR_POM=3 and ssa.USL_OK=1) or ssa.USL_OK=2) or (ssa.FOR_POM=2 and ssa.USL_OK=1)) and isnull(ssa.NPR_DATE,'')='' 

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VID_HMP', 'SLUCH', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '904', 'Значение поля VID_HMP не соответствует справочнику v018 (значаение таким кодом ' + cast (ss.VID_HMP as varchar(50)) + ' имеет дату окончания' + cast (format(v018.DATEEND,'dd.mm.yyyy') as varchar(50)) + ')'
from #TEMP_SLUCH ss
left join IES.T_V018_VMP_TYPE v018 on (ss.VID_HMP = v018.IDHVID)
where ss.VID_HMP is not null and  v018.IDHVID is not null and ss.DATE_2 > isnull(v018.DATEEND,ss.DATE_2)

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VID_HMP', 'SLUCH', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '904', 'Значение поля METOD_HMP не соответствует справочнику v019 (значаение таким кодом ' + cast (ss.METOD_HMP as varchar(50)) + ' имеет дату окончания' + cast (format(v019.DATEEND,'dd.mm.yyyy')  as varchar(50)) + ')'
from #TEMP_SLUCH ss
left join IES.T_V019_VMP_METHOD v019 on (ss.METOD_HMP = v019.IDHM)
where ss.VID_HMP is not null and  v019.IDHM is not null  and ss.DATE_2 > isnull(v019.DATEEND,ss.DATE_2)

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'P_CEL', 'SL', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '904', 'Значение поля P_CEL не подано при USL_OK =3'
from #TEMP_SLUCH ss
JOIN #TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
where ssa.USL_OK = 3 and ss.P_CEL is null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE,  IDSERV, OSHIB, COMMENT)
select 'SD_Z', 'ZGLV', null, null, null, '905', 'SD_Z не равно кол-ву запов в счёте'
from #SCHET t1
where t1.SD_Z <> (select count(*) from #TEMP_ZAP)

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_USL', 'ONK_SL', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Поле ONK_USL обязательно при USL_OK = 1 или 2'
from #SCHET_USL_ONK sou
join #TEMP_SLUCH ss on ss.IDCASE = sou.IDCASE and sou.SL_ID = ss.SL_ID
join #TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
where (ssa.USL_OK = 1 or ssa.USL_OK = 2) and sou.USL_TIP is null and (select s.[FILENAME] from #SCHET s) like 'C%'

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_USL', 'ONK_SL', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Поле ONK_USL обязательно для ВМП'
from #SCHET_USL_ONK sou
join #TEMP_SLUCH ss on ss.IDCASE = sou.IDCASE and sou.SL_ID = ss.SL_ID
join #TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
where sou.USL_TIP is null and (select s.[FILENAME] from #SCHET s) like 'T%'

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DKK1', 'KSG', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Поле DKK1 не соответствует справочнику. (при USL_OK = 2 и DKK1 = ' + cast (ksg.DKK1 as varchar(50)) + ' и N_KSG= ' + cast (ksg.N_KSG as varchar(50)) + ')'
from #TEMP_SLUCH ss
join #TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
join #SCHET_KSG ksg on (ksg.IDCASE = ss.IDCASE and ksg.SL_ID  = ss.SL_ID)
--left join [IES].[R_NSI_KSG_DS_KC] ds on ksg.N_KSG = ds.N_KSG
where ssa.USL_OK = 2 and ISnull(ksg.DKK1,'') <> (select top 1 isnull(ds.DKK,'') from [IES].[R_NSI_KSG_DS_KC] ds where ds.DKK = ksg.DKK1 and ksg.N_KSG = ds.N_KSG and ds.N_KSG is not null) and ksg.N_KSG is not null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DKK1', 'KSG', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Поле DKK1 не соответствует справочнику. (при USL_OK = 1 и DKK1 = ' + cast (ksg.DKK1 as varchar(50)) + ' и N_KSG= ' + cast (ksg.N_KSG as varchar(50)) + ')'
from #TEMP_SLUCH ss
join #TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
join #SCHET_KSG ksg on (ksg.IDCASE = ss.IDCASE and ksg.SL_ID  = ss.SL_ID)
--left join [IES].[R_NSI_KSG_KC] ds on  ksg.N_KSG = ds.N_KSG
where ssa.USL_OK = 1 and ISnull(ksg.DKK1,'') <> (select top 1 isnull(ds.DKK,'') from [IES].[R_NSI_KSG_KC] ds where ds.DKK = ksg.DKK1 and ksg.N_KSG = ds.N_KSG and ds.N_KSG is not null) and ksg.N_KSG is not null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'DS1', 'SL', null, IDCASE,null, '905', 'DS1 не найден в справочнике' 
from #TEMP_SLUCH s
LEFT JOIN  ies.R_MKB_10 mkb on mkb.MKB10CODE = s.DS1 and mkb.priznak = 1
where mkb.MKB10CODE is null and s.DS1 is not null


insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'DS0', 'SL', null, IDCASE,null, '905', 'DS0 не найден в справочнике' 
from #TEMP_SLUCH s
LEFT JOIN  ies.R_MKB_10 mkb on mkb.MKB10CODE = s.DS0 and mkb.priznak = 1
where mkb.MKB10CODE is null and s.DS0 is not null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'CODE_USL', 'USL', null, IDCASE,null, '905', 'Символ * в CODEUSL' 
from #SCHET_USL s
where s.CODE_USL like '%*%'

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'KSG_KPG', 'SL', null, ssa.IDCASE,ss.SL_ID, null, '905', 'отсутствует КСГ при USL_OK = 1,2' 
from #TEMP_Z_SLUCH ssa
join #TEMP_SLUCH ss on ss.IDCASE = ssa.IDCASE
join #SCHET_KSG ks on ss.IDCASE = ks.IDCASE and ss.SL_ID = ks.SL_ID
where (ssa.USL_OK = 1 or ssa.USL_OK = 2) and ks.VER_KSG is null 

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'REGNUM', 'LEK_PR', ss.N_ZAP, ss.IDCASE, null, '905', 'Значение поля REGNUM не соответствует справочнику n020 (Нет значения ' + cast(lek.REGNUM  as varchar(30)) + ') '
from #SCHET_USL_ONK_LEK_PR lek 
join #SCHET_SLUCH_ONK onk on lek.IDCASE = onk.IDCASE and onk.SL_ID = lek.SL_ID
join #TEMP_SLUCH ss on ss.IDCASE = onk.IDCASE and onk.SL_ID = ss.SL_ID
left join ies.T_N020_ONK_LEKP n020 on (lek.REGNUM = n020.ID_LEKP)
where n020.ID_LEKP is null and lek.REGNUM is not null

-- проверка №165
insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'REGNUM', 'LEK_PR', null, lek.IDCASE, null, '905', 'Дублирующее значение REGNUM =' + cast(lek.REGNUM  as varchar(30)) + ') '
from #SCHET_USL_ONK_LEK_PR lek 
group by lek.IDCASE, lek.SL_ID, lek.REGNUM
having count(*)>1

-- проверка №166
insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'REGNUM', 'LEK_PR', null, lek.IDCASE, null, '905', 'Дублирующее значение DATE_INJ у REGNUM =' + cast(lek.REGNUM  as varchar(30)) + ') '
from #SCHET_USL_ONK_LEK_PR_DATE lek 
group by lek.IDCASE, lek.SL_ID, lek.REGNUM, lek.DATE_INJ
having count(*)>1

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'CODE_SH', 'LEK_PR', ss.N_ZAP, ss.IDCASE, null, '905', 'Значение поля CODE_SH не соответствует справочнику v024 (Нет значения ' + cast(lek.CODE_SH  as varchar(30)) + ') '
from #SCHET_USL_ONK_LEK_PR lek 
join #SCHET_SLUCH_ONK onk on lek.IDCASE = onk.IDCASE and onk.SL_ID = lek.SL_ID
join #TEMP_SLUCH ss on ss.IDCASE = onk.IDCASE and onk.SL_ID = ss.SL_ID
left join ies.T_V024_DOP_KR v024 on (lek.CODE_SH = v024.IDDKK)
where v024.IDDKK is null and lek.CODE_SH is not null


insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'STAD', 'ONK_SL', ss.N_ZAP, ss.IDCASE, null, '905', 'Поле STAD не соответствует значениям справочника n002 на дату лечения(' + CONVERT(VARCHAR(10),ss.DATE_2,126)+ ')' 
from #SCHET_SLUCH_ONK onk
join #TEMP_SLUCH ss on ss.IDCASE = onk.IDCASE and onk.SL_ID = ss.SL_ID
--cross apply (select top 1 [ID_T] from ies.T_N003_TUMOR n003 where n003.[ID_T] = onk.ONK_T and n003.DATEBEG<=ss.DATE_2 and (n003.DATEBEG is null or n003.DATEEND>=ss.DATE_2)) id
left join ies.T_N002_STADIUM n002 on n002.ID_St = onk.STAD and n002.DATEBEG<=ss.DATE_2 and (n002.DATEEND is null or n002.DATEEND>=ss.DATE_2)
where n002.ID_St is null and onk.STAD is not null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'ONK_T', 'ONK_SL', ss.N_ZAP, ss.IDCASE, null, '905', 'Поле ONK_T не соответствует значениям справочника n003 на дату лечения(' + CONVERT(VARCHAR(10),ss.DATE_2,126)+ ')' 
from #SCHET_SLUCH_ONK onk
join #TEMP_SLUCH ss on ss.IDCASE = onk.IDCASE and onk.SL_ID = ss.SL_ID
--cross apply (select top 1 [ID_T] from ies.T_N003_TUMOR n003 where n003.[ID_T] = onk.ONK_T and n003.DATEBEG<=ss.DATE_2 and (n003.DATEBEG is null or n003.DATEEND>=ss.DATE_2)) id
left join ies.T_N003_TUMOR n003 on n003.[ID_T] = onk.ONK_T and n003.DATEBEG<=ss.DATE_2 and (n003.DATEEND is null or n003.DATEEND>=ss.DATE_2)
where n003.ID_T is null and onk.ONK_T is not null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'ONK_N', 'ONK_SL', ss.N_ZAP, ss.IDCASE, null, '905', 'Поле ONK_N не соответствует значениям справочника n004 на дату лечения(' + CONVERT(VARCHAR(10),ss.DATE_2,126)+ ')' 
from #SCHET_SLUCH_ONK onk
join #TEMP_SLUCH ss on ss.IDCASE = onk.IDCASE and onk.SL_ID = ss.SL_ID
--cross apply (select top 1 ID_N from ies.T_N004_NODUS n004 where n004.ID_N = onk.ONK_N and n004.DATEBEG<=ss.DATE_2 and (n004.DATEBEG is null or n004.DATEEND>=ss.DATE_2)) id
left join ies.T_N004_NODUS n004 on n004.ID_N = onk.ONK_N and n004.DATEBEG<=ss.DATE_2 and (n004.DATEEND is null or n004.DATEEND>=ss.DATE_2)
where n004.ID_N is null and onk.ONK_N is not null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'ONK_M', 'ONK_SL', ss.N_ZAP, ss.IDCASE, null, '905', 'Поле ONK_M не соответствует значениям справочника n005 на дату лечения(' + CONVERT(VARCHAR(10),ss.DATE_2,126)+ ')' 
from #SCHET_SLUCH_ONK onk
join #TEMP_SLUCH ss on ss.IDCASE = onk.IDCASE and onk.SL_ID = ss.SL_ID
--cross apply (select top 1 ID_M from ies.T_N005_METASTASIS n005 where n005.ID_M = onk.ONK_T and n005.DATEBEG<=ss.DATE_2 and (n005.DATEBEG is null or n005.DATEEND>=ss.DATE_2)) id
left join ies.T_N005_METASTASIS n005 on n005.ID_M = onk.ONK_M and n005.DATEBEG<=ss.DATE_2 and (n005.DATEEND is null or n005.DATEEND>=ss.DATE_2)
where n005.ID_M is null and onk.ONK_M is not null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'DIAG_CODE', 'B_DIAG', ss.N_ZAP, ss.IDCASE, null, '905', 'Поле DIAG_CODE не соответствует значениям справочника n007 на дату лечения(' + CONVERT(VARCHAR(10),ss.DATE_2,126)+ ')' 
from #SCHET_SLUCH_ONK_DIAG diag
join #TEMP_SLUCH ss on ss.IDCASE = diag.IDCASE and diag.SL_ID = ss.SL_ID
--cross apply (select top 1 ID_M from ies.T_N005_METASTASIS n005 where n005.ID_M = onk.ONK_T and n005.DATEBEG<=ss.DATE_2 and (n005.DATEBEG is null or n005.DATEEND>=ss.DATE_2)) id
left join ies.T_N007_MRF n007 on n007.ID_Mrf = diag.DIAG_CODE and n007.DATEBEG<=ss.DATE_2 and (n007.DATEEND is null or n007.DATEEND>=ss.DATE_2)
where n007.ID_Mrf is null and diag.DIAG_CODE is not null and diag.DIAG_TIP =1

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'DIAG_CODE', 'B_DIAG', ss.N_ZAP, ss.IDCASE, null, '905', 'Поле DIAG_CODE не соответствует значениям справочника n010 на дату лечения(' + CONVERT(VARCHAR(10),ss.DATE_2,126)+ ')' 
from #SCHET_SLUCH_ONK_DIAG diag
join #TEMP_SLUCH ss on ss.IDCASE = diag.IDCASE and diag.SL_ID = ss.SL_ID
--cross apply (select top 1 ID_M from ies.T_N005_METASTASIS n005 where n005.ID_M = onk.ONK_T and n005.DATEBEG<=ss.DATE_2 and (n005.DATEBEG is null or n005.DATEEND>=ss.DATE_2)) id
left join ies.T_N010_MARK n010 on n010.ID_Igh = diag.DIAG_CODE and n010.DATEBEG<=ss.DATE_2 and (n010.DATEEND is null or n010.DATEEND>=ss.DATE_2)
where n010.ID_Igh is null and diag.DIAG_CODE is not null and diag.DIAG_TIP =2

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'DIAG_RSLT', 'B_DIAG', ss.N_ZAP, ss.IDCASE, null, '905', 'Поле DIAG_RSLT не соответствует значениям справочника n008 на дату лечения(' + CONVERT(VARCHAR(10),ss.DATE_2,126)+ ')' 
from #SCHET_SLUCH_ONK_DIAG diag
join #TEMP_SLUCH ss on ss.IDCASE = diag.IDCASE and diag.SL_ID = ss.SL_ID
--cross apply (select top 1 ID_M from ies.T_N005_METASTASIS n005 where n005.ID_M = onk.ONK_T and n005.DATEBEG<=ss.DATE_2 and (n005.DATEBEG is null or n005.DATEEND>=ss.DATE_2)) id
left join ies.T_N008_MRF_RT n008 on n008.ID_R_M= diag.DIAG_RSLT and n008.DATEBEG<=ss.DATE_2 and (n008.DATEEND is null or n008.DATEEND>=ss.DATE_2)
where n008.ID_R_M is null and diag.DIAG_RSLT is not null and diag.DIAG_TIP =1

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'DIAG_RSLT', 'B_DIAG', ss.N_ZAP, ss.IDCASE, null, '905', 'Поле DIAG_RSLT не соответствует значениям справочника n011 на дату лечения(' + CONVERT(VARCHAR(10),ss.DATE_2,126)+ ')' 
from #SCHET_SLUCH_ONK_DIAG diag
join #TEMP_SLUCH ss on ss.IDCASE = diag.IDCASE and diag.SL_ID = ss.SL_ID
--cross apply (select top 1 ID_M from ies.T_N005_METASTASIS n005 where n005.ID_M = onk.ONK_T and n005.DATEBEG<=ss.DATE_2 and (n005.DATEBEG is null or n005.DATEEND>=ss.DATE_2)) id
left join ies.T_N011_MARK_VALUE n011 on n011.ID_R_I = diag.DIAG_RSLT and n011.DATEBEG<=ss.DATE_2 and (n011.DATEEND is null or n011.DATEEND>=ss.DATE_2)
where n011.ID_R_I is null and diag.DIAG_RSLT is not null and diag.DIAG_TIP =2

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'PROT', 'B_PROT', ss.N_ZAP, ss.IDCASE, null, '905', 'Поле PROT не соответствует значениям справочника n001 на дату лечения(' + CONVERT(VARCHAR(10),ss.DATE_2,126)+ ')' 
from #SCHET_SLUCH_ONK_B_PROT prot
join #TEMP_SLUCH ss on ss.IDCASE = prot.IDCASE and prot.SL_ID = ss.SL_ID
--cross apply (select top 1 ID_M from ies.T_N005_METASTASIS n005 where n005.ID_M = onk.ONK_T and n005.DATEBEG<=ss.DATE_2 and (n005.DATEBEG is null or n005.DATEEND>=ss.DATE_2)) id
left join ies.T_N001_PrOt n001 on n001.ID_PrOt = prot.PROT and n001.DATEBEG<=ss.DATE_2 and (n001.DATEEND is null or n001.DATEEND>=ss.DATE_2)
where n001.ID_PrOt is null and prot.PROT is not null 

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'DS1_T', 'ONK_SL', ss.N_ZAP, ss.IDCASE, null, '905', 'Поле DS1_T не соответствует значениям справочника n018 на дату лечения(' + CONVERT(VARCHAR(10),ss.DATE_2,126)+ ')' 
from #SCHET_SLUCH_ONK onk
join #TEMP_SLUCH ss on ss.IDCASE = onk.IDCASE and onk.SL_ID = ss.SL_ID
--cross apply (select top 1 [ID_T] from ies.T_N003_TUMOR n003 where n003.[ID_T] = onk.ONK_T and n003.DATEBEG<=ss.DATE_2 and (n003.DATEBEG is null or n003.DATEEND>=ss.DATE_2)) id
left join ies.T_N018_ONK_REAS n018 on n018.ID_REAS = onk.DS1_T and n018.DATEBEG<=ss.DATE_2 and (n018.DATEEND is null or n018.DATEEND>=ss.DATE_2)
where n018.ID_REAS is null and onk.DS1_T is not null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'C_ZAB', 'SL', ss.N_ZAP, ss.IDCASE, null, '905', 'Поле C_ZAB не соответствует значениям справочника v027 на дату лечения(' + CONVERT(VARCHAR(10),ss.DATE_2,126)+ ')' 
from  #TEMP_SLUCH ss 
--cross apply (select top 1 ID_N from ies.T_N004_NODUS n004 where n004.ID_N = onk.ONK_N and n004.DATEBEG<=ss.DATE_2 and (n004.DATEBEG is null or n004.DATEEND>=ss.DATE_2)) id
left join ies.T_V027_C_ZAB V027 on V027.IDCZ = ss.C_ZAB and V027.DATEBEG<=ss.DATE_2 and (V027.DATEEND is null or V027.DATEEND>=ss.DATE_2)
where V027.IDCZ is null and ss.C_ZAB is not null

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'SANK_IT', 'Z_SL', ssa.N_ZAP, ssa.IDCASE, null, '905', 'SANK_IT не равна сумме SANK.S_SUM' 
from  #TEMP_Z_SLUCH ssa
--join #TEMP_SANK sank on sank.IDCASE = ssa.IDCASE
where ssa.SANK_IT <> (select sum(sank.S_SUM)  from #TEMP_SANK sank where sank.IDCASE = ssa.IDCASE)

insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'SL_ID', 'SANK', ssa.N_ZAP, ssa.IDCASE, null, '905', 'Обязательно к заполнению, если S_SUM не равна 0' 
from  #TEMP_Z_SLUCH ssa
join #TEMP_SANK sank on sank.IDCASE = ssa.IDCASE
where sank.S_SUM <> 0 and sank.SL_ID is null

--insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
--select 'SL_ID', 'SANK', z.N_ZAP, z.IDCASE, null, '905', 'Сумма санкции по SL_ID не равна сумме выставленной по случаю с такими SL_ID' 
--from #TEMP_SANK_SL a  
--join #TEMP_Z_SLUCH z on z.IDCASE = a.IDCASE
--where (select sum(ss.SUM_M) from #TEMP_SLUCH ss where a.IDCASE = ss.IDCASE and ss.SL_ID = a.SL_ID)<> a.S_SUM

if (Select COUNT(*) from #Errors)> 0
BEGIN
select 
'<?xml version="1.0" encoding="Windows-1251"?>
' + (
select 
	OSHIB AS 'OSHIB',
	IM_POL AS 'IM_POL',
	BAS_EL AS 'BAS_EL',
	N_ZAP AS 'N_ZAP',
	IDCASE AS 'IDCASE',
	SL_ID as 'SL_ID',
	IDSERV AS 'IDSERV',
	COMMENT AS 'COMMENT'
FROM #Errors
FOR XML PATH('PR'),
ROOT('FLK_P')
)
END
----------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------
ELSE
BEGIN
--проверка, что суммы сходятся
declare @sumsluch decimal
select @sumsluch =  Sum([SUMV]) from #TEMP_Z_SLUCH
declare @sumschet decimal
select @sumschet = SUM([SUMMAV]) from #SCHET
if (@sumsluch <> @sumschet)
begin
	raiserror('ОШИБКА В ФАЙЛЕ СЧЕТ-РЕЕСТРА: Сумма на случаях не равна сумме на счете', 18,1)
end

-- добавиление RSLT по RSLT_D в диспе мтр от лпу
if (select top 1 [FILENAME] from #SCHET) like 'D%' and @type = 554
begin
update zs
set zs.RSLT = t7.RSLT
from #TEMP_Z_SLUCH zs
join [IESDB].[IES].[T_SPR_RSLT_D_TO_RSLT] t7 on zs.RSLT_D=t7.RSLT_D
where (select top 1 s.DISP from #SCHET s) = t7.DISP and zs.RSLT is null
end


-----------------T_SCHET (SCHET)-----------------------------
INSERT INTO [IES].[T_SCHET]
           ([VERSION],[DATA],[CODE],[YEAR],[MONTH],[NSCHET],[DSCHET]
		   ,[SUMMAV],[COMENTS],[SUMMAP],[SANK_MEK_R],[SANK_MEE_R],[SANK_EKMP_R]
		   ,[ReceivedDate],[ReceivedTime],[FILENAME],[CODE_MO],[PLAT],[Worker],[SchetID],[type_], [Status], SchetKind
		   , DISP, SD_Z)
     SELECT [VERSION],[DATA],[CODE],[YEAR],[MONTH],[NSCHET],[DSCHET]
			,[SUMMAV],[COMENTS],[SUMMAP],[SANK_MEK],[SANK_MEE],[SANK_EKMP]
			,[ReceivedDate],[ReceivedTime],[FILENAME],[CODE_MO],[PLAT],@Worker, @SchetID, @type, 0 ,0
			, (SELECT V016ID from IES.T_V016_DISPT where IDDT = DISP and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate))
			, SD_Z
     FROM #SCHET
		
-----------------T_SCHET_ZAP-----------------------------
CREATE NONCLUSTERED INDEX [IX_TEMP_ZAP_N_ZAP] ON #TEMP_ZAP
(
	[N_ZAP] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

INSERT INTO [IES].[T_SCHET_ZAP]
           ([SchetZapID],[SPOLIS],[NPOLIS],[NOVOR],[N_ZAP]
		   ,[VPOLIS]
		   ,[ID_PAC],[SMO],[SMO_OGRN],[SMO_OK],[SMO_NAM],[PR_NOV],[Schet],[type_],ST_OKATO, VNOV_D, INV, MSE, ENP)
 SELECT  [SchetZapID],[SPOLIS],[NPOLIS],[NOVOR],[N_ZAP]
 , (SELECT TOP 1 f008.IDDOC FROM IES.T_F008_OMS_TYPE f008 WHERE f008.IDDOC = [VPOLIS])
 ,[ID_PAC],(SELECT TOP 1 mo.SMOCOD FROM IES.T_F002_SMO mo WHERE mo.SMOCOD = zap.[SMO]),[SMO_OGRN],[SMO_OK],[SMO_NAM],[PR_NOV],@SchetID, 698,ST_OKATO, VNOV_D
 , INV, MSE, ENP
 FROM #TEMP_ZAP zap
 
 -- Заполняет значение результата для диспансеризации
 declare @rstl int 
 set @rstl = (SELECT top 1 t7.RSLT
  FROM  #TEMP_Z_SLUCH zs
  join #TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join #SCHET t1 on t1.DISP is not null
  join [IESDB].[IES].[T_SPR_RSLT_D_TO_RSLT] t7 on t1.DISP=t7.DISP and zs.RSLT_D=t7.RSLT_D)

 ----------------T_SCHET_SLUCH_ACCOMPLISHED (Z_SL)--------------
INSERT INTO [IES].[T_SCHET_SLUCH_ACCOMPLISHED]
		([SchetSluchAccomplishedID],[SchetZap]
		,IDCASE,USL_OK,VIDPOM,FOR_POM,NPR_MO,NPR_DATE,LPU,VBR,DATE_Z_1,DATE_Z_2,P_OTK,RSLT_D,KD_Z,VNOV_M
		,RSLT
		,ISHOD,OS_SLUCH,VB_P,IDSP,SUMV,OPLATA,SUMP,SANK_IT, P_DISP2 --, DISP_R, OBR_U_R
		)
SELECT	[SchetSluchAccomplishedID],t2.[SchetZapID]
		,IDCASE,USL_OK,VIDPOM,FOR_POM,NPR_MO,NPR_DATE,LPU,VBR,DATE_Z_1,DATE_Z_2,P_OTK,RSLT_D,KD_Z,VNOV_M
		,(SELECT TOP 1 v009.[IDRMP] FROM [IES].T_V009_RESULT v009 WHERE v009.[IDRMP] = ISNULL(t1.[RSLT], @rstl)) as RSLT
		,ISHOD,OS_SLUCH,VB_P,IDSP,SUMV,OPLATA,SUMP,SANK_IT, P_DISP2 --, DISP, OBR_U
FROM #TEMP_Z_SLUCH t1
JOIN #TEMP_ZAP t2 on t2.N_ZAP = t1.N_ZAP

-----------------T_SCHET_SLUCH (SL)---------------------------
INSERT INTO [IES].[T_SCHET_SLUCH]
		([SchetSluchID],[SchetZap],[SchetSluchAccomplished],[type_]
		,[SL_ID],[VID_HMP],[METOD_HMP],[LPU_1],[PODR],[PROFIL]
		,[PROFIL_K]
		,[DET],[TAL_D],[TAL_NUM],[TAL_P]
		,[P_CEL]
		,[NHISTORY],[P_PER],[DATE_1],[DATE_2],[KD],[DS0],[DS1],[DS1_PR],[DN],[PR_D_N],[CODE_MES1],[CODE_MES2],[REAB]
		,[PRVS],[PRVS2],[PRVS3],[VERS_SPEC],[IDDOKT],[ED_COL],[TARIF],[SUMV],[SUMP]
		,[DISP]
		,[COMENTSL]
		,[EXTR],[DS_ONK], [C_ZAB]
	  )
  SELECT t1.[SchetSluchID],t2.[SchetZapID],t3.[SchetSluchAccomplishedID],700
		,t1.[SL_ID],t1.[VID_HMP],[METOD_HMP],[LPU_1],[PODR],t1.[PROFIL]
		,(select V020BedProfileId from IES.T_V020_BED_PROFILE where  t1.[PROFIL_K] = IDK_PR and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate) ) as [PROFIL_K]
		,t1.[DET],[TAL_D],[TAL_NUM],[TAL_P]
		,(select V025KpcID from IES.T_V025_KPC where IDPC = [P_CEL] and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate) ) as [P_CEL]
		,t1.[NHISTORY],[P_PER],t1.[DATE_1],t1.[DATE_2],[KD],t1.[DS0],t1.[DS1],t1.[DS1_PR],t1.[DN],t1.[PR_D_N],t1.[CODE_MES1],t1.[CODE_MES2],[REAB]
		,case when [VERS_SPEC] = 'V004' THEN [PRVS] ELSE null END as [PRVS]
		,case when [VERS_SPEC] = 'V015' THEN [PRVS] ELSE null END as [PRVS2]
		,case when [VERS_SPEC] = 'V021'  or [VERS_SPEC] is null THEN [PRVS] ELSE null END as [PRVS3]
		,t1.[VERS_SPEC],[IDDOKT],t1.[ED_COL],t1.[TARIF],t1.SUM_M,t1.SUM_M
		,t1.DISP--,(SELECT V016ID from [IES].T_V016_DISPT where IDDT = t1.DISP and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate)) as [DISP]
		,ISNULL(t1.[TYPE_DISP], t1.[COMENTSL])
		,t1.[EXTR],t1.[DS_ONK], (select V027CZabID from ies.T_V027_C_ZAB zab where IDCZ=t1.C_ZAB and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate))
  FROM #TEMP_SLUCH t1
  JOIN #TEMP_ZAP t2 on t2.N_ZAP = t1.N_ZAP
  JOIN #TEMP_Z_SLUCH t3 on t1.IDCASE = t3.IDCASE

-----------------T_SCHET_SLUCH_NAZ (NAZ)---------------------
INSERT INTO [IES].[T_SCHET_SLUCH_NAZ](
		SchetSluchNazID,SchetSluch
		,NAZ_N,NAZR
		,[NAZ_SP]
		,NAZ_V,NAZ_PMP
		,[NAZ_PK]
		,NAZ_USL
		,NAPR_DATE
		,NAPR_MO
		)
SELECT	NEWID(),ts.SchetSluchID
		,tn.NAZ_N,tn.NAZ_R
		,(select top 1 IDSPEC from IES.T_V021_MED_SPEC where IDSPEC = tn.NAZ_SP) as [NAZ_SP]
		,tn.NAZ_V,tn.NAZ_PMP
		,(select top 1 V020BedProfileID from IES.T_V020_BED_PROFILE where IDK_PR = tn.NAZ_PK) as [NAZ_PK]
		,NAZ_USL ,NAPR_DATE ,NAPR_MO
FROM #TEMP_SL_NAZ tn
JOIN #TEMP_SLUCH ts on ts.[SL_ID] = tn.[SL_ID] and ts.IDCASE = tn.IDCASE

---------------------T_KSG (KSG_KPG)-----------------------------
INSERT INTO [IES].[T_KSG](
		KsgID,SchetSluch
		,N_KSG
		,VER_KSG,KSG_PG
		,N_KPG
		,KOEF_Z,KOEF_UP,BZTSZ,KOEF_D,KOEF_U
		,DKK1
		,DKK2
		,SL_K,IT_SL
		)
SELECT	[KsgID],ts.SchetSluchID
		,N_KSG
		,VER_KSG,KSG_PG
		,(select top 1 V026KpgID from IES.T_V026_KPG where K_KPG = t1.N_KPG) as N_KPG
		,KOEF_Z,KOEF_UP,BZTSZ,KOEF_D,KOEF_U
		,(select top 1 V024DopKrID from IES.T_V024_DOP_KR where IDDKK = t1.DKK1) as DKK1
		,(select top 1 V024DopKrID from IES.T_V024_DOP_KR where IDDKK = t1.DKK2) as DKK2
		,SL_K,IT_SL
FROM #SCHET_KSG t1
JOIN #TEMP_SLUCH ts on ts.[SL_ID] = t1.[SL_ID] and t1.IDCASE = ts.IDCASE

---------------------[IES].[T_KSG_CRIT]-----------------------------
insert into [IES].[T_KSG_CRIT](
	KsgCritID, Ksg, 
	V024DopKr
	)
select 
	newID(), t2.KsgID, 
	(select top 1 V024DopKrID from IES.T_V024_DOP_KR where IDDKK = t1.CRIT)
FROM #SCHET_KSG_CRIT t1
join #SCHET_KSG t2 on t2.[SL_ID] = t1.[SL_ID] and t1.IDCASE = t2.IDCASE
JOIN #TEMP_SLUCH ts on ts.[SL_ID] = t1.[SL_ID] and t1.IDCASE = ts.IDCASE

---------------------T_KSLP (SL_KOEF)-----------------------------
INSERT INTO [IES].[T_KSLP](
		KslpID,OmsSchetSluch,Ksg
		,KOEF_TYPE,KOEF
		)
SELECT	[KslpID],t2.[SchetSluchID],t3.KsgID
		,t1.IDSL,t1.Z_SL
FROM #SCHET_KSG_KOEF t1
JOIN #TEMP_SLUCH t2 on t2.[SL_ID] = t1.[SL_ID] and t1.IDCASE = t2.IDCASE
JOIN #SCHET_KSG t3 on t2.[SL_ID] = t3.[SL_ID] and t2.IDCASE = t3.IDCASE

-----------------T_SCHET_USL (USL)---------------------------
INSERT INTO [IES].[T_SCHET_USL](
		[SchetUslID],[SchetSluch],[type_]
		,[IDSERV],[LPU],[LPU_1],[PODR],[PROFIL],[VID_VME],[DET],[DATE_IN],[DATE_OUT]
		,[P_OTK],[DS],[CODE_USL],[KOL_USL],[TARIF],[SUMV_USL]
		,[PRVS]
		,[PRVS2]
		,[PRVS3]
		,[CODE_MD],[NPL],[COMENTU],[USL]
		)
SELECT	t1.[SchetUslID],t2.[SchetSluchID],710
		,t1.[IDSERV],t1.[LPU],t1.[LPU_1],t1.[PODR],t1.[PROFIL],t1.[VID_VME],t1.[DET],t1.[DATE_IN],t1.[DATE_OUT]
		,t1.[P_OTK],t1.[DS],t1.[CODE_USL],t1.[KOL_USL],t1.[TARIF],t1.[SUMV_USL]
		,case when [VERS_SPEC] = 'V004' THEN t1.[PRVS] ELSE null END as [PRVS]
		,case when [VERS_SPEC] = 'V015' THEN t1.[PRVS] ELSE null END as [PRVS2]
		,case when [VERS_SPEC] = 'V021' or [VERS_SPEC] is null THEN t1.[PRVS] ELSE null END as [PRVS3]			
		,t1.[CODE_MD],t1.[NPL],t1.[COMENTU], (select b.code_usl from ies.R_NSI_USL_V001 b where t1.CODE_USL=b.CODE_USL)
 FROM #SCHET_USL t1
 JOIN #TEMP_SLUCH t2 on t2.[SL_ID] = t1.[SL_ID] and t1.IDCASE = t2.IDCASE
 join #TEMP_Z_SLUCH t3 on (t3.IDCASE = t2.IDCASE)

-----------------T_SCHET_SLUCH_DS (DS2_N)---------------------------
INSERT INTO [IES].[T_SCHET_SLUCH_DS](
		[SchetSluchDsID],[SchetSluch],[MKB],[MKBType], DS2_PR, PR_DS2_N
		)
SELECT	NEWID(),t2.[SchetSluchID],t1.[DS],DS_TYPE, DS2_PR, PR_DS2_N
FROM #TEMP_DS t1
JOIN #TEMP_SLUCH t2 on t2.[SL_ID] = t1.[SL_ID] and t1.IDCASE = t2.IDCASE

-----------------T_SCHET_SLUCH_SANK (SANK)---------------------------
INSERT INTO [IES].[T_SCHET_SLUCH_SANK](
		SchetSluchSankID,[SchetSluchAccomplished]
		,[S_CODE],[S_SUM],[S_TIP]
		,[S_OSN]
		,[S_COM],[S_IST], DATE_ACT, NUM_ACT,SchetSluch
		)
SELECT	t1.SchetSluchSankID,t2.[SchetSluchAccomplishedID]
		,t1.[S_CODE],t3.[S_SUM],t3.[S_TIP]
		,(select top 1 f014.F014DenyReasonID from IES.T_F014_DENY_REASON f014 where f014.kod = t3.[S_OSN] and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate)) as [S_OSN]-- падало добавил топ 1. Потом можно над этим подумать.
		,t3.[S_COM],t3.[S_IST], t3.DATE_ACT, t3.NUM_ACT, (select [SchetSluchID] from #TEMP_SLUCH s where s.SL_ID = t1.SL_ID and s.IDCASE = t1.IDCASE)
from #TEMP_SANK_SL t1
join #TEMP_SANK t3 on (t1.S_CODE = t3.S_CODE and t1.IDCASE = t3.IDCASE)
JOIN #TEMP_Z_SLUCH t2 on (t1.IDCASE = t2.IDCASE)

-----------------[IES].[[T_SCHET_SLUCH_SANK_EXP](SANK)---------------------------
INSERT INTO [IES].[T_SCHET_SLUCH_SANK_EXP](
		SchetSluchSankExpID, SchetSluchSank, F004Expert)
SELECT newid(), t1.SchetSluchSankID, t2.CODE_EXP
from #TEMP_SANK_SL t1
join #TEMP_SANK t3 on (t1.S_CODE = t3.S_CODE and t1.IDCASE = t3.IDCASE)
JOIN #TEMP_SANK_EXP t2 on (t1.IDCASE = t2.IDCASE and t1.S_CODE = t2.S_CODE)

------------------[IES].[T_SCHET_SLUCH_ONK]------------------------------
INSERT INTO [IES].[T_SCHET_SLUCH_ONK] (SchetSluchOnkID, DS1_T, STAD, ONK_T, ONK_N, ONK_M, MTSTZ, SOD, SchetSluch, K_FR, WEI, HEI, BSA)

SELECT SchetSluchOnkID, (select n018.N018OnkReasID from ies.T_N018_ONK_REAS n018 where n018.ID_REAS = DS1_T and DATEBEG<=ts.DATE_2 and (DATEEND is null or DATEEND>=ts.DATE_2)), 
(select top 1 tn002.[N002StadiumID] from [IES].[T_N002_STADIUM] tn002 where tn002.ID_st = tsso.STAD and DATEBEG<=ts.DATE_2 and (DATEEND is null or DATEEND>=ts.DATE_2)),
	(select top 1 tn003.[N003TumorID] from [IES].[T_N003_TUMOR] tn003 where tn003.[ID_T] = tsso.ONK_T and DATEBEG<=ts.DATE_2 and (DATEEND is null or DATEEND>=ts.DATE_2)),
	(select top 1 tn004.[N004NodusID] from [IES].[T_N004_NODUS] tn004 where tn004.[ID_N] = tsso.ONK_N and DATEBEG<=ts.DATE_2 and (DATEEND is null or DATEEND>=ts.DATE_2)),
	(select top 1 tn005.[N005MetastasisID] from [IES].[T_N005_METASTASIS] tn005 where tn005.[ID_M] = tsso.ONK_M and DATEBEG<=ts.DATE_2 and (DATEEND is null or DATEEND>=ts.DATE_2)),
	[MTSTZ],[SOD],ts.SchetSluchID, K_FR, WEI, HEI, BSA

FROM #SCHET_SLUCH_ONK  tsso
join #TEMP_SLUCH ts on (tsso.IDCASE = ts.IDCASE and tsso.SL_ID = ts.SL_ID)

--------------[IES].[T_SCHET_SLUCH_CONS]
INSERT INTO [IES].[T_SCHET_SLUCH_CONS](SchetSluchConsID, SchetSluch, N019OnkCons, DT_CONS)
select newid(), ts.SchetSluchID, (select top 1 n019.N019OnkConsID from ies.T_N019_ONK_CONS n019 where n019.ID_CONS = tss.PR_CONS), tss.DT_CONS
from #TEMP_SLUCH_CONS tss
join #TEMP_SLUCH ts on (tss.IDCASE = ts.IDCASE and tss.SL_ID = ts.SL_ID)

------------------[IES].[T_SCHET_SLUCH_ONK_DIAG]------------------------------

INSERT INTO [IES].[T_SCHET_SLUCH_ONK_DIAG]  (SchetSluchOnkDiagID, SchetSluchOnk, DIAG_TIP, DIAG_CODE, DIAG_RSLT, DIAG_DATE, REC_RSLT) 
SELECT NEWID(),tsso.SchetSluchOnkID , [DIAG_TIP],[DIAG_CODE],[DIAG_RSLT], DIAG_DATE, REC_RSLT
from  #SCHET_SLUCH_ONK_DIAG ssod
join #SCHET_SLUCH_ONK tsso on (tsso.IDCASE = ssod.IDCASE and tsso.SL_ID = ssod.SL_ID)

------------------[IES].[T_SCHET_SLUCH_ONK_PROT]------------------------------

INSERT INTO [IES].[T_SCHET_SLUCH_ONK_PROT] (SchetSluchOnkProtID, SchetSluchOnk, PROT, D_PROT)
SELECT SchetSluchOnkProtID, tsso.SchetSluchOnkID, 
(select top 1 tn001.[N001PrOtID] from [IES].[T_N001_PrOt] tn001 where tn001.[ID_PrOt] = ssobp.PROT and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate))
, D_PROT FROM #SCHET_SLUCH_ONK_B_PROT ssobp
join #SCHET_SLUCH_ONK tsso on (tsso.IDCASE = ssobp.IDCASE and tsso.SL_ID = ssobp.SL_ID)


------------------[IES].[T_SCHET_USL_NAPR]------------------------------

INSERT INTO [IES].[T_SCHET_USL_NAPR] (SchetUslNaprID, NAPR_DATE, NAPR_V, MET_ISSL, NAPR_USL, SchetSluch, NAPR_MO)
SELECT SchetUslNaprID, NAPR_DATE, NAPR_V, MET_ISSL, NAPR_USL, ss.SchetSluchID, tsun.NAPR_MO
FROM #SCHET_USL_NAPR tsun
join #TEMP_SLUCH ss on (tsun.IDCASE = ss.IDCASE and tsun.SL_ID = ss.SL_ID)

------------------[IES].[T_SCHET_USL_ONK]------------------------------

INSERT INTO [IES].[T_SCHET_USL_ONK] (SchetUslOnkID, PR_CONS, USL_TIP, HIR_TIP, LEK_TIP_L, LEK_TIP_V, LUCH_TIP, SchetSluchOnk,PPTR)

SELECT SchetUslOnkID , PR_CONS,
(select top 1 tn013.[N013TreatTypeID] from [IES].[T_N013_TREAT_TYPE] tn013 where tn013.[ID_TLech] = tsuo.USL_TIP and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate)),
(select top 1 tn014.[N014SurgTreatID] from [IES].[T_N014_SURG_TREAT] tn014 where tn014.[ID_THir] = tsuo.HIR_TIP and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate)),
(select top 1 tn015.[N015DrugTherapyLinesID] from [IES].[T_N015_DRUG_THERAPY_LINES] tn015 where tn015.[ID_TLek_L] = tsuo.LEK_TIP_L and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate)),
(select top 1 tn016.[N016DrugTherapyCyclesID] from [IES].[T_N016_DRUG_THERAPY_CYCLES] tn016 where tn016.[ID_TLek_V] = tsuo.LEK_TIP_V and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate)),
(select top 1 tn017.[N017RadiationTherapyTypesID] from [IES].[T_N017_RADIATION_THERAPY_TYPES] tn017 where tn017.[ID_TLuch] = tsuo.LUCH_TIP and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate)),
su.SchetSluchOnkID ,PPTR
 from #SCHET_USL_ONK tsuo
join #SCHET_SLUCH_ONK su on (tsuo.IDCASE = su.IDCASE and tsuo.SL_ID = su.SL_ID)

------------------[IES].[T_SCHET_USL_ONK_LEK_PR]------------------------------
INSERT INTO [IES].[T_SCHET_USL_ONK_LEK_PR]
           ([SchetUslOnkLekPrID],[REGNUM],[SchetUslOnk],V024DopKr)
select
	 [LekPrID], (select top 1 N020OnkLekpID from [IES].[T_N020_ONK_LEKP] N020 where N020.ID_LEKP =  [REGNUM] and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate)) 
	 ,ca.SchetUslOnkID,(select top 1 V024DopKrID from ies.T_V024_DOP_KR where CODE_SH = IDDKK and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate))
	from #SCHET_USL_ONK_LEK_PR t1
	cross apply(select top 1 t2.[SchetUslOnkID] from #SCHET_USL_ONK t2 
				where t1.IDCASE=t2.IDCASE and t1.SL_ID=t2.SL_ID )ca

INSERT INTO [IES].[T_SCHET_USL_ONK_LEK_PR_DATE]
           ([SchetUslOnkLekPr],[DATE_INJ],[SchetUslOnkLekPrDateID])
select
	 [LekPrID],[DATE_INJ],newID()
	from #SCHET_USL_ONK_LEK_PR_DATE prd
	join #SCHET_USL_ONK_LEK_PR pr on pr.IDCASE= prd.IDCASE and pr.SL_ID = prd.SL_ID and pr.REGNUM = prd.REGNUM and prd.CODE_SH = pr.CODE_SH

END

DROP TABLE #SCHET
DROP TABLE #TEMP_ZAP
DROP TABLE #TEMP_Z_SLUCH
DROP TABLE #TEMP_SLUCH
DROP TABLE #SCHET_USL
DROP TABLE #TEMP_DS
DROP TABLE #TEMP_SANK
DROP TABLE #SCHET_KSG
DROP TABLE #TEMP_SL_NAZ
drop table #SCHET_KSG_KOEF
drop table #SCHET_SLUCH_ONK
drop table #SCHET_SLUCH_ONK_DIAG
drop table #SCHET_SLUCH_ONK_B_PROT
drop table #SCHET_USL_NAPR
drop table #SCHET_USL_ONK
drop table #SCHET_USL_ONK_LEK_PR
END
