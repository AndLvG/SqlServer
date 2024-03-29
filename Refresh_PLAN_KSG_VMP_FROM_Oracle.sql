USE [IESDB]
GO
/****** Object:  StoredProcedure [dbo].[Refresh_PLAN_KSG_VMP_FROM_Oracle]    Script Date: 11.05.2021 11:50:59 ******/
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
        EXECUTE ('delete from [IESDB].[IES].R_BUDJET_PLAN_STAC_VMP where year >= 2021');

		INSERT INTO [IES].[R_BUDJET_PLAN_STAC_VMP]([USL_OK], [lpu], [idpr], [prof_name], [KSG_CODE], [KSG_NAME], [K_ZATR], [gg_gosp], [gg_sum], 
			[YEAR], [MONTH], podr_lpu_1, SMO_SOGAZ_GOSP, SMO_SOGAZ_SUM, SMO_MAKS_GOSP, SMO_MAKS_SUM, DictionaryBaseID)
       SELECT [USL_OK], [lpu], [idpr], [prname], [F_KSG_CODE], [KSG_NAME], [K_ZATR], [gg_gosp], [gg_sum], [YEAR], [MONTH], podr,
		SMO_SOGAZ_GOSP, SMO_SOGAZ_SUM, SMO_MAKS_GOSP, SMO_MAKS_SUM, newid()
       FROM
       (
           -- План КСГ
		   SELECT * FROM OPENQUERY(ORACLE,
		   'SELECT b.vidpom_id USL_OK, b.code_f lpu, b.idpr, prname, F_KSG_CODE, KSG_NAME, b.K_ZATR, B.GOSPIT gg_gosp, B.SUMMA gg_sum, 
extract(year from to_date(jrn_id,''yymm'')) YEAR, extract(month from to_date(jrn_id,''yymm'')) MONTH, podr,
B.GOSPIT * val_158 SMO_SOGAZ_GOSP, B.SUMMA * val_158 SMO_SOGAZ_SUM, B.GOSPIT * val_155 SMO_MAKS_GOSP, B.SUMMA * val_155 SMO_MAKS_SUM
           FROM BUDJET.B_V_KSG_DOHOD B
		   left join LPU.VW_LPU_COEFF_SMO s on s.code_lpu = b.code_lpu AND
                to_date(jrn_id || ''01'', ''yymmdd'') BETWEEN s.db AND s.de
                AND s.type_lpu + 1 = b.vidpom_id
           WHERE jrn_id >= ''2101'' ')
   --        SELECT b.vidpom_id USL_OK, b.code_f lpu, b.idpr, prname, F_KSG_CODE, KSG_NAME, b.K_ZATR, B.GOSPIT gg_gosp, B.SUMMA gg_sum, 
			--YEAR(CONVERT(DATETIME, jrn_id + ''01'', 12)) YEAR, MONTH(CONVERT(DATETIME, jrn_id + ''01'', 12)) MONTH, podr,
			--B.GOSPIT * val_158 SMO_SOGAZ_GOSP, B.SUMMA * val_158 SMO_SOGAZ_SUM, B.GOSPIT * val_155 SMO_MAKS_GOSP, B.SUMMA * val_155 SMO_MAKS_SUM
   --        FROM ORACLE..BUDJET.B_V_KSG_DOHOD B, ORACLE..LPU.VW_LPU_COEFF_SMO s
   --        WHERE jrn_id >= ''1901'' AND s.code_lpu = b.code_lpu
   --             AND cast(jrn_id + ''01'' as date) BETWEEN s.db AND s.de
   --             AND s.type_lpu + 1 = b.vidpom_id
           UNION ALL
           -- План ВМП
		   SELECT * FROM OPENQUERY(ORACLE,
'SELECT 5, b.code_f lpu, b.idpr, B.prname, to_char(vmp_group) n_gr, vmp_name, 0 K_ZATR, B.VMP_VAL gg_gosp, B.SUMMA gg_sum, 
extract(year from to_date(jrn_id,''yymm'')) YEAR, extract(month from to_date(jrn_id,''yymm'')) MONTH, podr,
B.VMP_VAL * val_158 SMO_SOGAZ_GOSP, B.SUMMA * val_158 SMO_SOGAZ_SUM, B.VMP_VAL * val_155 SMO_MAKS_GOSP, B.SUMMA * val_155 SMO_MAKS_SUM
           FROM BUDJET.B_V_VMP_FULL B
		   left join LPU.VW_LPU_COEFF_SMO s on s.code_lpu = b.CODE AND
                to_date(jrn_id || ''01'', ''yymmdd'') BETWEEN s.db AND s.de
				 AND s.type_lpu = 3
           WHERE jrn_id >= ''2101'' ')
   --        SELECT 5, b.code_f lpu, b.idpr, B.prname, CONVERT(VARCHAR, vmp_group) n_gr, vmp_name, 0 K_ZATR, B.VMP_VAL gg_gosp, B.SUMMA gg_sum, 
			--YEAR(CONVERT(DATETIME, jrn_id + ''01'', 12)) YEAR, MONTH(CONVERT(DATETIME, jrn_id + ''01'', 12)) MONTH, podr,
			--B.VMP_VAL * val_158 SMO_SOGAZ_GOSP, B.SUMMA * val_158 SMO_SOGAZ_SUM, B.VMP_VAL * val_155 SMO_MAKS_GOSP, B.SUMMA * val_155 SMO_MAKS_SUM
   --        FROM ORACLE..BUDJET.B_V_VMP_FULL B, ORACLE..LPU.VW_LPU_COEFF_SMO s
   --        WHERE jrn_id >= ''1901'' AND s.code_lpu = b.CODE AND
   --             cast(jrn_id + ''01'' as date) BETWEEN s.db AND s.de
			--	 AND s.type_lpu = 3
       ) a
;
        EXECUTE ('delete from IES.T_DICTIONARY_BASE where type_ = '+@eID);

        --Тут type_ - наш айдишник
        EXECUTE ('INSERT INTO IES.T_DICTIONARY_BASE ([DictionaryBaseID], [type_])
		SELECT	DictionaryBaseID,'+@eID+' FROM [IESDB].[IES].R_BUDJET_PLAN_STAC_VMP');
    END;