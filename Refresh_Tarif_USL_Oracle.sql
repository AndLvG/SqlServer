USE [IESDB]
GO
/****** Object:  StoredProcedure [dbo].[Refresh_Tarif_USL_Oracle]    Script Date: 17.12.2020 10:51:12 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Lvov
-- Create date: 26.02.2019
-- Description:	Обновление тарифов по услугам
-- =============================================
ALTER PROCEDURE [dbo].[Refresh_Tarif_USL_Oracle]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	TRUNCATE TABLE [IES].[T_CHER_USL_TARIF];
	INSERT INTO [IES].[T_CHER_USL_TARIF] ([LPU]
	, [usl_code]
	, [DATE_B]
	, [DATE_E]
	, [K_TARIF], lpu_1, usl_ok)
		SELECT code_lpu,
			   usl_code,
			   DATE_B,
			   DATE_E,
			   K_TARIF, lpu_1, usl_ok
		FROM ORACLE..BUDJET.B_V_UNLOAD_USL_TARIF
		UNION
		SELECT LPU,
			   usl_code,
			   DATE_B,
			   DATE_E,
			   K_TARIF, lpu_1, usl_ok
		FROM ORACLE..BUDJET.B_V_UNLOAD_POL_TARIF

  -- Удаление старых ссылок на данные сущности "Тарифы по поликлинике (по услугам)"
   DELETE [IESDB].IES.T_DICTIONARY_BASE 
   where type_=9022
 -- Добавление новых ссылок на данные сущности "Тарифы по поликлинике (по услугам)"
  insert [IESDB].IES.T_DICTIONARY_BASE(DictionaryBaseID,type_)
  select t0.DictionaryBaseID, 9022
  FROM [IESDB].IES.T_CHER_USL_TARIF t0 
  LEFT JOIN [IESDB].IES.T_DICTIONARY_BASE t1 ON t1.DictionaryBaseID = t0.DictionaryBaseID
  where t1.DictionaryBaseID is null;

  -- Обновление статуса "Есть тариф на услугу" в справочнике услуг
  UPDATE IESDB.IES.R_NSI_USL_V001
  SET  
      f_tarif = CASE WHEN t.usl_code IS NULL THEN 0 ELSE 1 END
FROM   IESDB.IES.R_NSI_USL_V001 v
LEFT JOIN
(SELECT DISTINCT 
        usl_code
 FROM   IESDB.IES.T_CHER_USL_TARIF
 WHERE  date_b >= '20200101') t ON v.CODE_USL = t.usl_code
WHERE(t.usl_code IS NULL
      AND f_tarif = 1
      OR t.usl_code IS NOT NULL
      AND f_tarif = 0)
END
