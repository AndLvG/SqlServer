DECLARE @DB DATE = '20190101';
DECLARE @DE DATE = '20190801';
--
WITH amb_plan
     AS (SELECT ISNULL(mc.new_code, pl.lpu) lpu, 
                pl.usl_code, 
                ut.name, 
                pl.usl_val, 
                pl.dohod, 
                ut.ID uType, 
                pl.usl_ok
         FROM   IESDB.IES.R_BUDJET_PLAN_USL AS pl
         LEFT JOIN IESDB.IES.R_NSI_USL_V001 v ON v.CODE_USL = pl.usl_code
         LEFT JOIN IESDB.IES.T_SPR_USL_TYPE_NAME ut ON ut.DictionaryBaseID = v.USLTYPE
         LEFT JOIN my_base.dbo.MO_CODE_CONVERT mc ON mc.old_code = pl.lpu
         WHERE  pl.YEAR BETWEEN YEAR(@DB) AND YEAR(@DE)
                AND lpu = '400008'
                AND pl.MONTH BETWEEN MONTH(@DB) AND MONTH(@DE)
         --AND ut.ID IN(1, 3, 4, 5, 11, 17, 22, 24, 28, 30, 33, 10, 29, 26, 27, 7, 8, 10, 9)
         )
     SELECT lpu, 
            usl_code, 
            name, 
            usl_val, 
            dohod, 
            uType
     FROM   amb_plan
     WHERE  usl_code IN
     (SELECT code_usl
      FROM   [IESDB].[IES].[R_NSI_SOUL_ALL]
      WHERE  dateend IS NULL)
;