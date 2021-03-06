USE [IESDB]
GO
/****** Object:  StoredProcedure [dbo].[sp_prikaz_17]    Script Date: 16.03.2020 11:37:39 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:  (C) Vitacard System 2014
--              Шатков В.А.
-- Create date: 2012-12-19
-- Description: Формирование отчета по ВМП (ФАКТ) в XML формате
-- =============================================

ALTER PROCEDURE [dbo].[sp_prikaz_17](@Y int,@M int, @FileName varchar(255) out, @firstname varchar(50), @FileNameout varchar(max) out, @DATA datetime, @ret varchar(max) out)
as
Begin

-- TODO: задайте здесь значения параметров.
Declare 
 @tfoms int

Select
 @FileName = ISNULL(@FileName,'')
,@DATA = ISNULL(@DATA,GETDATE())
,@Y = ISNULL(@Y,YEAR(GETDATE()))
,@M = ISNULL(@M,MONTH(GETDATE())-1)
,@tfoms = (Select top 1 t2.Tfoms from [IES].T_COMPANY_SETTINGS t1 join [IES].T_COMPANY t2 on t2.CompanyID = t1.Company)

if (exists(select * from ies.T_SCHET where Order17Id is not null and [MONTH]=@M and [YEAR]=@Y) and @Y>2018)
begin
	raiserror('За этот месяц приказ уже выгружен, удалите старую запись!',16,1)
	return
end

if OBJECT_ID('tempdb..#schets','U') is not null 
	drop table #schets

Select s.SchetID, SUM(dbo.DateTimeDiff('Day',ss.DATE_1,ss.DATE_2)) as IT_DL, SUM(ssa.SUMP) as IT_ST,count (ssa.SchetSluchAccomplishedID) as COL
into #schets
FROM IES.T_SCHET_SLUCH ss with(nolock) 
JOIN IES.T_SCHET_SLUCH_ACCOMPLISHED ssa with(nolock) ON ssa.SchetSluchAccomplishedID = ss.SchetSluchAccomplished 
JOIN IES.T_SCHET_ZAP sz with(nolock) ON sz.SchetZapID = ssa.SchetZap
JOIN IES.T_SCHET s with(nolock) ON s.SchetID = sz.Schet 
WHERE (s.FILENAME LIKE 'T%' AND NOT ss.VID_HMP IS NULL AND s.Status=1 AND ss.IsDelete=0 AND ssa.SUMP>0 AND ss.OPLATA = 1 AND year(ssa.date_z_2) = @Y
AND 
	(
		(s.type_ = 693 AND s.[YEAR]=@Y AND (cast(s.[MONTH] as [int]) = @M or s.[MONTH] < @M and s.Order17Id is NULL )
			AND NOT EXISTS (SELECT * FROM IES.T_SCHET_SLUCH_SANK sss  WHERE ssa.SchetSluchAccomplishedID = sss.SchetSluchAccomplished AND sss.IsDelete=0)
		)
		OR 
		(s.type_ = 554 AND s.[YEAR]=@Y AND DATEPART(Year,s.ReceivedDate)=@Y AND (DATEPART(Month,s.ReceivedDate)=@M or DATEPART(Month,s.ReceivedDate)<@M and s.Order17Id is null)
			AND NOT EXISTS (SELECT * FROM IES.T_SCHET_ACT_ITEM sai WHERE sai.SchetSluchAccomplished = ssa.SchetSluchAccomplishedID AND sai.IsAddToAct=0 OR sai.SchetActItemID IS NULL) 
		)
	)
)
group by s.SchetID


if not exists(select SchetID from #schets)
Begin
	raiserror('Данные для выгрузки отсутствуют за данный период!',16,1)
	return
End

insert into ies.R_NSI_LIST_OF_ORDERS ([OrderType],[OrderDate],[DictionaryBaseId],[RComment],[OrderMonth],[OrderYear])
select '17',getdate(),newid(),null,@M,@Y

insert into IES.T_DICTIONARY_BASE([DictionaryBaseID],[type_]) 
select top 1 t1.[DictionaryBaseID],9030
from ies.R_NSI_LIST_OF_ORDERS t1
left join IES.T_DICTIONARY_BASE t2 on t2.DictionaryBaseID = t1.DictionaryBaseId
where t1.[OrderType]='17' and t2.DictionaryBaseID is null

---------------------------------апдейт Order17Id на счете
update ies.T_SCHET set Order17Id=(select top 1 [DictionaryBaseID] from ies.R_NSI_LIST_OF_ORDERS where [OrderType]='17' order by [OrderDate] desc)
where SchetID in (select distinct s.SchetID from #schets s)



IF not exists(Select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA = 'IES' and TABLE_NAME = 'T_SCHET_SLUCH' and COLUMN_NAME = 'Report17XML')
	Alter table IES.T_SCHET_SLUCH add Report17XML bit

SELECT 
@ret =
(SELECT TOP 1 
 '1.0' AS 'ZGLV/VERSION'
,convert(varchar(10),cast(@DATA as date)) AS 'ZGLV/DATA'
,case 
		when @filename is null or @filename = '' then
			case when @firstname is null or @firstname = '' then 'VR40' else 'VS40' end 
			+ RIGHT(format(@Y,'0000'),2) 
			+ format((select top 1 order17num from [IES].[R_NSI_GLOBAL_SETTINGS] with(nolock)),'0000')
		else @filename
	end  as 'ZGLV/FILENAME'
	,case when @firstname is null or @firstname = '' then NULL else @firstname end as 'ZGLV/FIRSTNAME'
,t0.Number AS 'SVD/CODE'
,@Y AS 'SVD/YEAR'
,@M AS 'SVD/MONTH'
,(select sum (col) from  #schets)  AS 'IT_MP/PC_KOL'
,(select SUM(IT_DL) from #schets) AS 'IT_MP/IT_DL'
,(select SUM(IT_ST) from #schets) AS 'IT_MP/IT_ST'
,(SELECT --s.type_ AS 'TIP', Для проверки мтр и тер счетов
	 ROW_NUMBER() OVER (ORDER BY ss.SchetSluchID) AS 'N_SV'
	 ,CASE s.type_ WHEN '693' THEN '29000' ELSE isnull(smo_ok, st_okato) END AS 'PACIENT/SMO_OK' -- Львов 16-03-2020
	--,ISNULL(s.OKATO_OMS,cast(@tfoms*1000 as varchar(5))) AS 'PACIENT/SMO_OK'
	,sz.VPOLIS AS 'PACIENT/VPOLIS'
	,sz.SPOLIS AS 'PACIENT/SPOLIS'
	,sz.NPOLIS AS 'PACIENT/NPOLIS'
	,sz.W AS 'PACIENT/W'
	,dbo.DateTimeDiff('Year',sz.DR,cast(cast(((10000*@Y)+(100*1))+1 as [varchar](255)) as [datetime])) AS 'PACIENT/VZST'
	,ssa.IDCASE  AS 'SLUCH/IDCASE'
	,v019.HGR AS 'SLUCH/N_GR'
	,v018.IDHVID AS 'SLUCH/VID_HMP'
	,v019.IDHM AS 'SLUCH/METOD_HMP'
	,ssa.LPU AS 'SLUCH/LPU'
	,dbo.DateTimeDiff('Day',ss.DATE_1,ss.DATE_2) AS 'SLUCH/DATE_I'
	,ss.DS1 AS 'SLUCH/DS'
	,ssa.SUMP AS 'SLUCH/SUM' 

FROM IES.T_SCHET_SLUCH ss with(nolock) 
LEFT JOIN IES.T_SCHET_SLUCH_ACCOMPLISHED ssa with(nolock) ON ssa.SchetSluchAccomplishedID = ss.SchetSluchAccomplished 
LEFT JOIN IES.T_SCHET_ZAP sz with(nolock) ON sz.SchetZapID = ssa.SchetZap
LEFT JOIN IES.T_SCHET s with(nolock) ON s.SchetID = sz.Schet 
--
--ies.T_V018_VMP_TYPE

--


LEFT JOIN IES.T_V018_VMP_TYPE   v018 ON v018.IDHVID = ss.VID_HMP
LEFT JOIN IES.T_V019_VMP_METHOD v019 ON v019.IDHM = ss.METOD_HMP
--LEFT JOIN ies.T_V018_VMP_TYPE   v018 ON  v018.IDHVID = ss.VID_HMP  and v018.DATEBEG<=ss.DATE_2 and (v018.DATEEND is null or v018.DATEEND>=ss.DATE_2) 
--LEFT JOIN ies.T_V018_VMP_TYPE_PREV v019 ON v019.V018VmpType= ss.VID_HMP and v019.DATEBEG<=ss.DATE_2 and (v019.DATEEND is null or v019.DATEEND>=ss.DATE_2) 
WHERE s.SchetID in (select SchetID from #schets)
AND (s.FILENAME LIKE 'T%' AND NOT ss.VID_HMP IS NULL AND s.[YEAR]=@Y AND s.Status=1 AND ss.IsDelete=0 AND ssa.SUMP>0 AND ss.OPLATA = 1  AND year(ssa.date_z_2) = @Y
AND 
	(
		(s.type_ = 693 AND s.[YEAR]=@Y AND cast(s.[MONTH] as [int]) = @M 
			AND NOT EXISTS (SELECT * FROM IES.T_SCHET_SLUCH_SANK sss  WHERE ssa.SchetSluchAccomplishedID = sss.SchetSluchAccomplished AND sss.IsDelete=0)
		)
		OR 
		(s.type_ = 554 AND s.[YEAR]=@Y AND DATEPART(Year,s.ReceivedDate)=@Y AND DATEPART(Month,s.ReceivedDate)=@M 
			AND NOT EXISTS (SELECT * FROM IES.T_SCHET_ACT_ITEM sai WHERE sai.SchetSluchAccomplished = ssa.SchetSluchAccomplishedID AND sai.IsAddToAct=0 OR sai.SchetActItemID IS NULL) 
		)
	)
)

FOR XML PATH('SV_H_MP'), TYPE
) 

FROM IES.T_COMPANY_SETTINGS t11  
FOR XML PATH(''), ROOT('H_MP')
) 

FROM VCLib.T_XML_REPORT_RESULT t0  
WHERE (t0.XmlReportResultID='A2797F95-9DD4-4B0B-8AC2-97C613363596')

Drop table #schets

select @FileNameout =
case 
		when @FileName is null or @FileName = '' then
			case when @FileName is null or @FileName = '' then 'VR40' else 'VS40' end 
			+ RIGHT(format(@Y,'0000'),2) 
			+ format((select top 1 order17num from [IES].[R_NSI_GLOBAL_SETTINGS] with(nolock)),'0000') + '.xml' 
		else @FileName + '.xml' 
	end 


End