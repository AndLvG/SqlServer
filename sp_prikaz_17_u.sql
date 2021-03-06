USE [IESDB]
GO
/****** Object:  StoredProcedure [dbo].[sp_prikaz_17_u]    Script Date: 12.02.2021 13:04:38 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[sp_prikaz_17_u] (@Y int, @M int, @date datetime, @code varchar(20),@FileName varchar(max), @FileNameout varchar(max) out, @firstname varchar(50), @NSVD varchar(20), @DSVD datetime, @ret varchar(max) out)
AS 
BEGIN 

If (@Y is null or @NSVD is null or @DSVD is null)
begin
	raiserror('Не все поля заполнены!',16,1)
	Return
end


-- TODO: задайте здесь значения параметров.
Declare 
 @tfoms varchar(5)

Select
 @FileName = ISNULL(@FileName,'')
,@date = ISNULL(@date,GETDATE())
,@Y = ISNULL(@Y,YEAR(GETDATE()))
,@M = ISNULL(@M,MONTH(GETDATE())-1)
,@tfoms = (Select top 1 cast(t2.Tfoms as varchar(5))
			from [IES].T_COMPANY_SETTINGS t1 
			join [IES].T_COMPANY t2 on t2.CompanyID = t1.Company)



--Для итога
if OBJECT_ID('tempdb..#schets','U') is not null 
	drop table #schets
Select --s.SchetID, SUM(ssa.KD_Z) as IT_DL, SUM(ss.SUMP) as IT_ST s
--r17.PROFIL_VMP as 'PROFIL' , 
sv.profil as 'PROFIL' , 
v019.HGR as 'N_GR', count(*) as 'KOL', sum(ss.SUMP) as 'S_KOL',ssa.LPU as 'LPU'
into #schets
FROM IES.T_SCHET_SLUCH ss with(nolock) 
JOIN IES.T_SCHET_SLUCH_ACCOMPLISHED ssa with(nolock) ON ssa.SchetSluchAccomplishedID = ss.SchetSluchAccomplished 
JOIN IES.T_SCHET_ZAP sz with(nolock) ON sz.SchetZapID = ssa.SchetZap
JOIN IES.T_SCHET s with(nolock) ON s.SchetID = sz.Schet 
LEFT OUTER JOIN IES.T_V019_VMP_METHOD AS v019 ON ss.METOD_HMP = v019.V019VmpMethodID
                                                      AND ss.DATE_2 BETWEEN v019.DATEBEG AND ISNULL(v019.DATEEND, ss.DATE_2)
													 
join [IES].T_V002_PROFILE v002 on (ss.PROFIL = v002.IDPR and (v002.DATEEND is null  or v002.DATEEND >= ss.DATE_2))
--join [IESDB].[IES].[R_NSI_VMP17_PROFIL] r17 on (r17.PROFIL_V002= v002.IDPR)
join ies.R_NSI_SPR_VMP sv on sv.hgr = v019.HGR AND sv.[year] = @y
WHERE  s.YEAR = @y
       AND s.type_ IN('554')
       AND (ssa.USL_OK IN(1, 2))
AND s.STATUS = 1
AND ss.VID_HMP IS NOT NULL
AND ssa.SUMP > 0
AND s.IsDelete = 0
AND MONTH(s.receiveddate) <= @M  --and Order17uId is null --Pudov raskomentil 05 03
group by sv.profil--r17.PROFIL_VMP
,v019.HGR,ssa.LPU

--
update [IESDB].[IES].[R_NSI_GLOBAL_SETTINGS] set Order17num=Order17num+1
-- обходим юнион


create table #TT
(
PROFIL int,
N_GR int,
KOL int,
S_KOL decimal(17,2),
LPU varchar(50),
[TYPE] varchar(50)
)

-- Сливаем данные
insert into #TT 
select * from (select 
				 cast(t1.[prof] as int)	as 'PROFIL'
				,cast(t1.[n_gr]	as int) as 'N_GR'
				,cast(t1.[kol] as int)	as 'KOL'
				,cast(t1.[s_kol] as decimal(17,2)) as 'S_KOL'
				,cast(t1.mo_sv as varchar(50)) as 'LPU'
				,'PLAN'  as 'TYPE'
			
				from IES.[PLAN_BUDJET_GOD] t1 
				join IES.T_F003_MO f003 
				on t1.mo_sv = f003.MCOD
				WHERE t1.God = @y
				union
				select 
				 cast(t2.PROFIL as int)	as 'PROFIL'
				,cast(t2.N_GR	as int) as 'N_GR'
				,cast(t2.KOL as int)	as 'KOL'
				,cast(t2.S_KOL as decimal(17,2)) as 'S_KOL'
				,cast (t2.LPU as varchar(50)) as 'LPU'
				,'MTR' as 'TYPE'
				 from #schets t2 
				) as Main
				group by N_GR, PROFIL,KOL,S_KOL,LPU,[TYPE] --по факту бессмыслена но досталось в наследство

				-- Группировки и подсчёт

				
		--2

		create table #TT2
(
PROFIL int,
N_GR int,
LPU varchar(50),
KOL int,
S_KOL decimal(17,2)
,[TYPE] varchar (50)

)

insert into #TT2 (PROFIL,N_GR,LPU,[TYPE])
select PROFIL,N_GR,LPU,[TYPE] from #TT
group by PROFIL,N_GR,LPU,[TYPE]
--3
select t1.PROFIL,t1.N_GR,t1.LPU,sum(t2.KOL) as 'KOL',sum (t2.S_KOL) as 'S_KOL',t1.[TYPE] INTO #TT3
from #TT2 t1 
join #TT t2 on (t1.PROFIL=t2.PROFIL and t1.N_GR=t2.N_GR AND t1.LPU=t2.LPU and t1.[TYPE]=t2.[TYPE]) 
group by t1.PROFIL,t1.N_GR,t1.LPU,t1.[TYPE]

--результат вычеслений #TT3 --Да мы знаем что за такой код убивают
--для пометки

if OBJECT_ID('tempdb..#schets2','U') is not null 
	drop table #schets2
Select -- SUM(ssa.KD_Z) as IT_DL, SUM(ss.SUMP) as IT_ST s
s.SchetID,
--r17.PROFIL_VMP as 'PROFIL' ,
sv.profil as 'PROFIL' ,
 v019.HGR as 'N_GR', count(*) as 'KOL', sum(ss.SUMP) as 'S_KOL',ssa.LPU as 'LPU'
into #schets2
FROM IES.T_SCHET_SLUCH ss with(nolock) 
JOIN IES.T_SCHET_SLUCH_ACCOMPLISHED ssa with(nolock) ON ssa.SchetSluchAccomplishedID = ss.SchetSluchAccomplished 
JOIN IES.T_SCHET_ZAP sz with(nolock) ON sz.SchetZapID = ssa.SchetZap
JOIN IES.T_SCHET s with(nolock) ON s.SchetID = sz.Schet 
LEFT OUTER JOIN IES.T_V019_VMP_METHOD AS v019 ON ss.METOD_HMP = v019.V019VmpMethodID
                                                      AND ss.DATE_2 BETWEEN v019.DATEBEG AND ISNULL(v019.DATEEND, ss.DATE_2)
													 

													 
join [IES].T_V002_PROFILE v002 on (ss.PROFIL = v002.IDPR and (v002.DATEEND is null  or v002.DATEEND >= ss.DATE_2))
--join [IESDB].[IES].[R_NSI_VMP17_PROFIL] r17 on (r17.PROFIL_V002= v002.IDPR)
join ies.R_NSI_SPR_VMP sv on sv.hgr = v019.HGR AND sv.[year] = @y
WHERE  s.YEAR = @y
       AND s.type_ IN('554')
       AND (ssa.USL_OK IN(1, 2))
AND s.STATUS = 1
AND ss.VID_HMP IS NOT NULL
AND ssa.SUMP > 0
AND s.IsDelete = 0
AND MONTH(s.receiveddate) <= @M  --and Order17uId is null
group by s.SchetID,
sv.profil--r17.PROFIL_VMP
,v019.HGR,ssa.LPU


insert into ies.R_NSI_LIST_OF_ORDERS ([OrderType],[OrderDate],[DictionaryBaseId],[RComment],[OrderMonth],[OrderYear])
select '17u',getdate(),newid(),null,@M,@Y

insert into IES.T_DICTIONARY_BASE([DictionaryBaseID],[type_]) 
select top 1 t1.[DictionaryBaseID],9030
from ies.R_NSI_LIST_OF_ORDERS t1
left join IES.T_DICTIONARY_BASE t2 on t2.DictionaryBaseID = t1.DictionaryBaseId
where t1.[OrderType]='17u' and t2.DictionaryBaseID is null

update ies.T_SCHET set Order17uId=(select top 1 [DictionaryBaseID] from ies.R_NSI_LIST_OF_ORDERS where [OrderType]='17u' order by [OrderDate] desc)
where SchetID in (select distinct s.SchetID from #schets2 s)


---------сама выгрузка
select @ret = (
	select
	 '1.0' as 'ZGLV/VERSION'
	,convert(varchar(10),@date,126) as 'ZGLV/DATA'
	,case 
		when @FileName is null or @FileName = '' then
			case when @firstname is null or @firstname = '' then 'VI40' else 'VJ40' end 
			+ RIGHT(format(@Y,'0000'),2) 
			+ format((select top 1 order17num from [IES].[R_NSI_GLOBAL_SETTINGS] with(nolock)),'0000')
		else @FileName
	end  as 'ZGLV/FILENAME'
	,case when @firstname is null or @firstname = '' then NULL else @firstname end as 'ZGLV/FIRSTNAME'
	,case when @code is null or @code = '' then (select top 1 order17num from [IES].[R_NSI_GLOBAL_SETTINGS] with(nolock) ) else @code end as 'SVD/CODE'
	,@Y as 'SVD/YEAR'
	,@NSVD as 'SVD/NSVD'
	,convert(varchar(10),@DSVD,126) as 'SVD/DSVD'
	,(
		select 
			( ROW_NUMBER() over(order by f003.MCOD) ) as 'N_SV'
			,f003.MCOD as 'MO_SV'
			,1 as 'DIF_KOEF'
			,(select 
				 cast(t1.PROFIL as int)	as 'PROFIL'
				,cast(t1.N_GR	as int) as 'N_GR'
				,sum (cast(t1.[kol] as int))	as 'KOL'
				,sum (cast(t1.[s_kol] as decimal(17,2))) as 'S_KOL'
				from #TT3  t1 
				where t1.lpu = f003.MCOD
				group by N_GR,PROFIL
				for xml path('IT_SV'),type
			) 
		from IES.T_F003_MO f003
		where f003.IsActive = 1
		and exists(select * from IES.[PLAN_BUDJET_GOD] t2 where t2.mo_sv = f003.MCOD and t2.GOD = @Y)
		for xml path('UTV_MP'),type
	)
	
	for xml path(''),ROOT ('H_MP')
)

select @FileNameout =
case 
		when @FileName is null or @FileName = '' THEN
			case when @firstname is null or @firstname = '' then 'VI40' else 'VJ40' end 
			+ RIGHT(format(@Y,'0000'),2) 
			+ format((select top 1 order17num from [IES].[R_NSI_GLOBAL_SETTINGS] with(nolock)),'0000') + '.xml' 
		else @FileName + '.xml' 
	end 

END