USE [IESDB];
GO

/****** Object:  StoredProcedure [dbo].[Refresh_Tarif_KSG_Oracle]    Script Date: 05.01.2020 11:19:29 ******/

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- Author:		Lvov
-- Create date: 25.02.2019
-- Description:	Обновление тарифов по Ксг (с коэффициентами) из Oracle (Бюджет)
-- =============================================
ALTER PROCEDURE [dbo].[Refresh_Tarif_KSG_Oracle]
AS
    BEGIN
        SET NOCOUNT ON;
        DECLARE @p2 INT = 9019;

        -- Удаление старых записей по тарифам
        DELETE IESDB.IES.T_SPR_KSG_TARIF;

        -- Удаление ссылок на записи по тарифам
        DELETE IESDB.IES.T_DICTIONARY_BASE
        WHERE  (type_ = @p2);

        -- Добавление новых записей по тарифам
        INSERT INTO IESDB.IES.T_SPR_KSG_TARIF(LPU, 
                                              USL_OK, 
                                              IDPR, 
                                              KSG, 
                                              K_TARIF, 
                                              K_BAZA, 
                                              K_ZATR, 
                                              K_UR, 
                                              DATE_B, 
                                              DATE_E, 
                                              VERS, 
                                              DictionaryBaseID, 
                                              KSG_BEZ_UR, 
                                              K_OTD, 
                                              F_KSG_CODE, 
                                              EditDate, 
                                              K_UPR, 
                                              lpu_1, 
                                              profil_k)
               SELECT LPU, 
                      USL_OK, 
                      IDPR, 
                      KSG, 
                      K_TARIF, 
                      K_BAZA, 
                      K_ZATR, 
                      K_UR, 
                      DATE_B, 
                      DATE_E, 
                      VERS, 
                      NEWID(), 
                      KSG_BEZ_UR, 
                      K_OTD, 
                      f_KSG, 
                      GETDATE(), 
                      K_UPR, 
                      lpu_1, 
                      profil_k
               FROM
               (SELECT DISTINCT 
                       LPU, 
                       USL_OK, 
                       IDPR, 
                       KSG, 
                       K_TARIF, 
                       K_BAZA, 
                       K_ZATR, 
                       CASE WHEN KSG_BEZ_UR IS NULL THEN ISNULL(K_OTD, ISNULL(K_UR, 1)) ELSE 1 END AS K_UR, 
                       DATE_B, 
                       DATE_E, 
                       VERS, 
                       KSG_BEZ_UR, 
                       K_OTD, 
                       ISNULL(F_KSG_CODE, KSG) AS F_KSG, 
                       K_UPR, 
                       lpu_1, 
                       profil_k
                FROM   ORACLE..BUDJET.B_V_UNLOAD_KSG_TARIF_79) AS a;

        -- Добавление новых ссылок на данные
        INSERT INTO IESDB.IES.T_DICTIONARY_BASE(DictionaryBaseID, 
                                                type_)
               SELECT t1.DictionaryBaseID, 
                      @p2
               FROM   IESDB.IES.T_SPR_KSG_TARIF t1
               LEFT JOIN IESDB.IES.T_DICTIONARY_BASE t2 ON t2.DictionaryBaseID = t1.DictionaryBaseID
               WHERE  t2.DictionaryBaseID IS NULL;

        -- Обновляем тарифы по ВМП

        DECLARE @TName VARCHAR(50), 
                @Descr VARCHAR(200), 
                @eID   INT;
        SET @TName = 'R_NSI_VMP_TARIFFS';
        SET @eID =
        (SELECT EntityID
         FROM   [VCLib].[T_ENTITIES]
         WHERE  EntName = @TName);
        EXECUTE ('truncate table [IESDB].[IES].'+@TName);

        -- Тарифы по ВМП
        EXECUTE ('INSERT INTO [IESDB].[IES].'+@TName+' (LPU, USL_OK, ID_PR, F_VMP, K_TARIF, DATE_B, DATE_E, DictionaryBaseID)
SELECT LPU, USL_OK, IDPR, F_VMP, K_TARIF, DATE_B, DATE_E, NEWID()
FROM ORACLE..BUDJET.B_V_UNLOAD_VMP_TARIF_79
');
        EXECUTE ('delete from IES.T_DICTIONARY_BASE where type_ = '+@eID);

        --Тут type_ - наш айдишник
        EXECUTE ('INSERT INTO IES.T_DICTIONARY_BASE ([DictionaryBaseID], [type_])
		SELECT	DictionaryBaseID,'+@eID+' FROM [IESDB].[IES].'+@TName);
    END;