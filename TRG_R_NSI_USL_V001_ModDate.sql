USE [IESDB]
GO
/****** Object:  Trigger [IES].[R_NSI_USL_V001_ModDate]    Script Date: 27.11.2019 11:36:16 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
ALTER TRIGGER [IES].[R_NSI_USL_V001_ModDate] ON [IESDB].[IES].[R_NSI_USL_V001]
AFTER INSERT, UPDATE
AS
     DECLARE @n INT;
     BEGIN
         UPDATE X
           SET  
               ModifiedDate = GETDATE()
         FROM   [IESDB].[IES].[R_NSI_USL_V001] X
         JOIN inserted i ON X.DictionaryBaseID = i.DictionaryBaseID;

         SET @n =
         (SELECT COUNT(*)
          FROM   [my_base].[dbo].[ModifiedTables] mt
          WHERE  mt.Table_name = '[IESDB].[IES].[R_NSI_USL_V001]');
         IF @n = 0
             INSERT INTO [my_base].[dbo].[ModifiedTables]([Table_name], 
                                                          [Modified_flag])
             VALUES('[IESDB].[IES].[R_NSI_USL_V001]', 1);
         ELSE
             UPDATE [my_base].[dbo].[ModifiedTables]
               SET  
                   [Modified_flag] = 1, Modified_Date = GETDATE()
             WHERE  [Table_name] = '[IESDB].[IES].[R_NSI_USL_V001]';
     END;