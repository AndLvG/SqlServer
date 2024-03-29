USE [IESDB]
GO
/****** Object:  StoredProcedure [dbo].[Refresh_NSI_USL_V001_Oracle]    Script Date: 23.03.2021 14:39:34 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Lvov
-- Create date: 04.03.2019
-- Description:	Обновление структуры услуги в Оракл
-- =============================================
ALTER PROCEDURE [dbo].[Refresh_NSI_USL_V001_Oracle]
AS
    BEGIN
        SET NOCOUNT ON;

        -- Обновляем информацию по существующим
        UPDATE v001
          SET  
              v001.name_usl = t.NAME_USL, 
              v001.usl_ok = t.usl_ok, 
              v001.vidpom = t.vidpom, 
              v001.profil = t.profil, 
              v001.prvs = t.prvs, 
              v001.idsp = t.idsp, 
              v001.p_cel = t.p_cel, 
              v001.voz_min = t.voz_min, 
              v001.voz_max = t.voz_max, 
              v001.w = t.w, 
              v001.vid_vme = t.vid_vme,
			  v001.group_id = t.group_id,
			  v001.f_aktual = t.f_aktual
        FROM   ORACLE..BUDJET.B_NSI_USL_V001 v001
        INNER JOIN
        (SELECT t0.CODE_USL, 
                t0.NAME_USL, 
                t0.usl_ok, 
                t0.VIDPOM, 
                ISNULL(t0.profil_t, CAST(t0.PROFIL_V002 AS VARCHAR(500))) PROFIL, 
                ISNULL(t0.PRVS_t, CAST(t6.CODE_SPEC AS VARCHAR(500))) PRVS, 
                ISNULL(t0.IDSP_t, CAST(t8.IDSP AS VARCHAR(500))) IDSP, 
                ISNULL(t0.P_CEL_T, CAST(t9.IDPC AS VARCHAR(500))) P_CEL, 
                t0.VOZ_MIN, 
                t0.VOZ_MAX, 
                t0.W, 
                t3.Code vid_vme,
				ut.id group_id,
				t0.F_AKTUAL
         FROM   IES.R_NSI_USL_V001 t0
         LEFT JOIN IES.T_V010_PAY t8 ON t8.V010PayID = t0.V010Pay
         LEFT JOIN IES.T_V025_KPC t9 ON t9.V025KpcID = t0.P_CEL
         LEFT JOIN IES.T_V001_NOMENCLATURE t3 ON t3.NomenclatureID = t0.Nomenclature
         LEFT JOIN IES.T_V021_MED_SPEC t6 ON t6.IDSPEC = t0.PRVS
		 LEFT JOIN IES.T_SPR_USL_TYPE_NAME ut WITH(NOLOCK) ON ut.DictionaryBaseID = t0.USLTYPE
         WHERE  t0.usl_ok IN(3, 4)
                OR t0.NAME_USL LIKE 'Кслп%'
				OR f_tarif = 1 AND t0.usltype <> 'EFAF2673-7453-40ED-A42C-E6BD3BECABDF' -- услуги при стационаре не входящие в состав КСГ
				) t ON v001.code_usl = t.code_usl;

        -- Добавялем отсутствующие услуги
        INSERT INTO ORACLE..BUDJET.B_NSI_USL_V001(code_usl, 
                                                  name_usl, 
                                                  usl_ok, 
                                                  vidpom, 
                                                  profil, 
                                                  prvs, 
                                                  idsp, 
                                                  p_cel, 
                                                  voz_min, 
                                                  voz_max, 
                                                  w, 
                                                  vid_vme, group_id)
               SELECT t0.CODE_USL, 
                      t0.NAME_USL, 
                      t0.usl_ok, 
                      t0.VIDPOM, 
                      ISNULL(t0.profil_t, CAST(t0.PROFIL_V002 AS VARCHAR(500))) PROFIL, 
                      ISNULL(t0.PRVS_t, CAST(t6.CODE_SPEC AS VARCHAR(500))) PRVS, 
                      ISNULL(t0.IDSP_t, CAST(t8.IDSP AS VARCHAR(500))) IDSP, 
                      ISNULL(t0.P_CEL_T, CAST(t9.IDPC AS VARCHAR(500))) P_CEL, 
                      t0.VOZ_MIN, 
                      t0.VOZ_MAX, 
                      t0.W, 
                      t3.Code vid_vme,
					  ut.id group_id
               FROM   IES.R_NSI_USL_V001 t0
               LEFT JOIN IES.T_V010_PAY t8 ON t8.V010PayID = t0.V010Pay
               LEFT JOIN IES.T_V025_KPC t9 ON t9.V025KpcID = t0.P_CEL
               LEFT JOIN IES.T_V001_NOMENCLATURE t3 ON t3.NomenclatureID = t0.Nomenclature
               LEFT JOIN IES.T_V021_MED_SPEC t6 ON t6.IDSPEC = t0.PRVS
               LEFT JOIN ORACLE..BUDJET.B_NSI_USL_V001 v001 ON v001.code_usl = t0.code_usl
			   LEFT JOIN IES.T_SPR_USL_TYPE_NAME ut WITH(NOLOCK) ON ut.DictionaryBaseID = t0.USLTYPE
               WHERE  (t0.usl_ok IN(3, 4)
               OR t0.NAME_USL LIKE 'Кслп%'
			   OR f_tarif = 1 AND t0.usltype <> 'EFAF2673-7453-40ED-A42C-E6BD3BECABDF' -- услуги при стационаре не входящие в состав КСГ
				)
                      AND v001.code_usl IS NULL
               ORDER BY t0.CODE_USL;

        --Сразу обновляем справочник услуг Бюджета
		-- Добавляем новые
        INSERT INTO ORACLE..BUDJET.B_SPR_USL(usl_code, 
                                             usl_name)
               SELECT t.code_usl, 
                      t.name_usl
               FROM   ORACLE..BUDJET.B_NSI_USL_V001 t
               LEFT JOIN ORACLE..BUDJET.B_SPR_USL u ON t.code_usl = u.usl_code
               WHERE  u.usl_code IS NULL;
		-- Исправляем названия если изменились
		UPDATE u
          SET u.usl_name = t.name_usl
        FROM   ORACLE..BUDJET.B_SPR_USL u
        INNER JOIN ORACLE..BUDJET.B_NSI_USL_V001 t ON t.code_usl = u.usl_code
		where u.usl_name != t.name_usl;

    END;