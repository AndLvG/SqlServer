USE [IESDB];
GO

/****** Object:  StoredProcedure [dbo].[Refresh_NSI_USL_V001_Oracle]    Script Date: 27.11.2019 10:56:01 ******/

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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
              v001.vid_vme = t.vid_vme
        FROM   ORACLE..BUDJET.B_NSI_USL_V001 v001
        INNER JOIN
        (SELECT t0.CODE_USL, 
                t0.NAME_USL, 
                t0.usl_ok, 
                t0.VIDPOM, 
                ISNULL(CAST(t0.PROFIL_V002 AS VARCHAR), t0.PROFIL_T) PROFIL, 
                ISNULL(CAST(t0.PRVS AS VARCHAR), t0.PRVS_T) PRVS, 
                ISNULL(CAST(t8.IDSP AS VARCHAR), t0.IDSP_T) IDSP, 
                ISNULL(CAST(t9.IDPC AS VARCHAR), t0.P_CEL_T) P_CEL, 
                t0.VOZ_MIN, 
                t0.VOZ_MAX, 
                t0.W, 
                t3.Code vid_vme
         FROM   IES.R_NSI_USL_V001 t0
         LEFT JOIN IES.T_V010_PAY t8 ON t8.V010PayID = t0.V010Pay
         LEFT JOIN IES.T_V025_KPC t9 ON t9.V025KpcID = t0.P_CEL
         LEFT JOIN IES.T_V001_NOMENCLATURE t3 ON t3.NomenclatureID = t0.Nomenclature
         WHERE  t0.F_AKTUAL = 1
                AND t0.usl_ok IN(3, 4)) t ON v001.code_usl = t.code_usl;

        -- Добавялем отсутствующие услуги
        INSERT INTO ORACLE..BUDJET.B_NSI_USL_V001
               SELECT t0.CODE_USL, 
                      t0.NAME_USL, 
                      t0.usl_ok, 
                      t0.VIDPOM, 
                      ISNULL(CAST(t0.PROFIL_V002 AS VARCHAR), t0.PROFIL_T) PROFIL, 
                      ISNULL(CAST(t0.PRVS AS VARCHAR), t0.PRVS_T) PRVS, 
                      ISNULL(CAST(t8.IDSP AS VARCHAR), t0.IDSP_T) IDSP, 
                      ISNULL(CAST(t9.IDPC AS VARCHAR), t0.P_CEL_T) P_CEL, 
                      t0.VOZ_MIN, 
                      t0.VOZ_MAX, 
                      t0.W, 
                      t3.Code vid_vme
               FROM   IES.R_NSI_USL_V001 t0
               LEFT JOIN IES.T_V010_PAY t8 ON t8.V010PayID = t0.V010Pay
               LEFT JOIN IES.T_V025_KPC t9 ON t9.V025KpcID = t0.P_CEL
               LEFT JOIN IES.T_V001_NOMENCLATURE t3 ON t3.NomenclatureID = t0.Nomenclature
               LEFT JOIN ORACLE..BUDJET.B_NSI_USL_V001 v001 ON v001.code_usl = t0.code_usl
               WHERE  t0.F_AKTUAL = 1
                      AND t0.usl_ok IN(3, 4)
                      AND v001.code_usl IS NULL
               ORDER BY t0.CODE_USL;
    END;