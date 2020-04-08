USE [IESDB]
GO
/****** Object:  StoredProcedure [dbo].[Refresh_PLAN_KSG_VMP_FROM_Oracle]    Script Date: 25.03.2020 12:02:16 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Lvov
-- Create date: 25.02.2019
-- Description:	Обновление плана по КСГ и ВМП из Oracle (Бюджет)
-- =============================================
ALTER PROCEDURE [dbo].[Refresh_PLAN_KSG_VMP_FROM_Oracle]
AS
    BEGIN
        SET NOCOUNT ON;

        DECLARE @TName VARCHAR(50), 
                @Descr VARCHAR(200), 
                @eID   INT;
        SET @TName = 'BUDJET_PLAN_STAC_VMP';
        SET @eID =
        (SELECT EntityID
         FROM   [VCLib].[T_ENTITIES]
         WHERE  EntName = @TName);
        EXECUTE ('truncate table [IESDB].[IES].R_BUDJET_PLAN_STAC_VMP');

        EXECUTE ('
		INSERT INTO [IES].[R_BUDJET_PLAN_STAC_VMP]([USL_OK], [lpu], [idpr], [prof_name], [KSG_CODE], [KSG_NAME], [K_ZATR], [gg_gosp], [gg_sum], [YEAR], [MONTH], podr_lpu_1, DictionaryBaseID)
       SELECT [USL_OK], [lpu], [idpr], [prname], [F_KSG_CODE], [KSG_NAME], [K_ZATR], [gg_gosp], [gg_sum], [YEAR], [MONTH], podr, newid()
       FROM
       (
           -- План КСГ
           SELECT b.vidpom_id USL_OK, b.code_f lpu, b.idpr, prname, F_KSG_CODE, KSG_NAME, b.K_ZATR, B.GOSPIT gg_gosp, B.SUMMA gg_sum, YEAR(CONVERT(DATETIME, jrn_id + ''01'', 12)) YEAR, MONTH(CONVERT(DATETIME, jrn_id + ''01'', 12)) MONTH, podr
           FROM ORACLE..BUDJET.B_V_KSG_DOHOD B
           WHERE jrn_id >= ''1901''
           UNION ALL
           -- План ВМП
           SELECT 5, b.code_f lpu, b.idpr, B.prname, CONVERT(VARCHAR, vmp_group) n_gr, vmp_name, 0 K_ZATR, B.VMP_VAL gg_gosp, B.SUMMA gg_sum, YEAR(CONVERT(DATETIME, jrn_id + ''01'', 12)) YEAR, MONTH(CONVERT(DATETIME, jrn_id + ''01'', 12)) MONTH, podr
           FROM ORACLE..BUDJET.B_V_VMP_FULL B
           WHERE jrn_id >= ''1901''
       ) a
');
        EXECUTE ('delete from IES.T_DICTIONARY_BASE where type_ = '+@eID);

        --Тут type_ - наш айдишник
        EXECUTE ('INSERT INTO IES.T_DICTIONARY_BASE ([DictionaryBaseID], [type_])
		SELECT	DictionaryBaseID,'+@eID+' FROM [IESDB].[IES].R_BUDJET_PLAN_STAC_VMP');
    END;