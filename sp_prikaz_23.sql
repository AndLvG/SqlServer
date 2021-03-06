USE [IESDB]
GO
/****** Object:  StoredProcedure [dbo].[sp_prikaz_23]    Script Date: 19.01.2021 10:56:05 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[sp_prikaz_23] (@month int, @year int, @date datetime,@filename varchar(500), @FileNameout varchar(max) out, @code varchar(20), @ret varchar(max) out)
AS 
BEGIN 

-------------------проверка выгружен ли
if (exists(select * from ies.T_SCHET where Order23Id is not null and [MONTH]=@month and [YEAR]=@year))
begin
	raiserror('За этот месяц приказ уже выгружен, удалите старую запись!',16,1)
	return
end

----------счетчик
update [IESDB].[IES].[R_NSI_GLOBAL_SETTINGS] set Order23num=Order23num+1
declare @count int = (select top 1 Order23num from [IES].[R_NSI_GLOBAL_SETTINGS])

-------случаи для выгрузки
select sz.FAM,sz.IM,sz.OT,sz.DR,ss.DS1,ss.DATE_2,ss.DATE_1,ss.SchetSluchID,s.SchetID
into #Ss
from ies.T_SCHET_SLUCH ss with(nolock)
join ies.T_SCHET_ZAP sz with(nolock) on (sz.SchetZapID=ss.SchetZap)
join ies.T_SCHET s with(nolock) on (sz.Schet=s.SchetID)
join ies.T_F003_MO f003 with(nolock) on (s.CODE_MO=f003.MCOD)
join ies.T_SCHET_SLUCH_ACCOMPLISHED ssa with(nolock) on (ssa.SchetSluchAccomplishedID=ss.SchetSluchAccomplished)
--join ies.T_REESTR_CLOSE_INFO ci on (s.SchetID=ci.Schet)-------------------------закрытые счета
where f003.TF_OKATO='29000' and 
(ssa.USL_OK in (1,2,21,22,23) or (ssa.USL_OK=3 and exists(select * from ies.T_SCHET_USL su with(nolock)join ies.T_V001_NOMENCLATURE v001 on v001.Code=su.CODE_USL where su.SchetSluch=ss.SchetSluchID and su.CODE_USL in (select u23.UslCode from ies.R_NSI_DIAL_USL_23 u23))))
and ss.SUMP>0
and s.IsDelete=0
and (s.type_=554 and (YEAR(s.receiveddate) = @year AND MONTH(s.receiveddate) = @month AND s.[YEAR] = @year OR s.[YEAR]= @year AND s.Order23Id IS NULL and month(s.ReceivedDate)<@month) and s.[Status]=1 
or (s.type_ = 693 and s.[MONTH]=@month and s.[YEAR]=@year or s.[YEAR]=@year and s.[MONTH]<@month and s.Order23Id is null) )
and year(ss.DATE_2)=@year and  s.FILENAME not like 'T%'



select ds.SchetSluch, ds.MKBType, t1.FAM,t1.IM,t1.OT,t1.DR,t1.DS1,t1.DATE_2,ds.MKB
into #SsDs
from #Ss t1
join ies.T_SCHET_SLUCH_DS ds with(nolock) on (t1.SchetSluchID=ds.SchetSluch)


----список людей
select
FAM,IM,OT,DR,DS1
into #peoples
from #SsDs 
group by FAM,IM,OT,DR,DS1

--------------Список всех случаев по этим людям
select
sz.FAM,sz.IM,sz.OT,sz.DR,ss.DS1,ss.DATE_2
into #sluchs
from ies.T_SCHET_SLUCH ss with(nolock)
join ies.T_SCHET_ZAP sz with(nolock) on (sz.SchetZapID=ss.SchetZap)
join ies.T_SCHET s with(nolock) on (sz.Schet=s.SchetID)
join ies.T_REESTR_CLOSE_INFO ci on (s.SchetID=ci.Schet)-------------------------закрытые счета
--join #peoples p on (p.DR=sz.DR and p.FAM=sz.FAM and p.IM=sz.IM and p.OT=sz.OT and p.DS1=ss.DS1)
where s.type_ in (693,554) 
and exists(select * from #peoples p where p.DR=sz.DR and p.FAM=sz.FAM and p.IM=sz.IM and p.OT=sz.OT and p.DS1=ss.DS1)
and s.IsDelete=0
---------------и только теперь ищу пересечения
select
t1.SchetSluch
into #pvtSluchs
from #SsDs t1
where 
exists(select * from #sluchs p
		where p.FAM=t1.FAM and p.IM=t1.IM and p.OT=t1.OT and p.DR=t1.DR
			and p.DS1=t1.DS1
			and ABS(DATEDIFF(DAY,p.DATE_2,t1.DATE_2))<=28)

/************************************************
----------------Соединяю справочник кслп, услуги и ксг?? !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!ДЛЯ IDSL!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
select
ss.SchetSluchID,su.SchetUslID,kk.IDSL,kk.ZKOEF, ROW_NUMBER() over(partition by ss.SchetSluchID order by ss.SchetSluchID) as 'number'
into #kslpDictionary
from ies.T_SCHET_USL su with(nolock)
join #Ss ss on (ss.SchetSluchID=su.SchetSluch)

join [IES].[R_NSI_KSLP_KOEFS] kk on (kk.[USL_CODE]=su.CODE_USL and kk.[DATEBEG]<=ss.DATE_1 and (kk.[DATEEND] is null or kk.[DATEEND]>ss.DATE_1) and kk.NPR is not null)
group by ss.SchetSluchID,kk.IDSL,kk.ZKOEF,su.SchetUslID

**************************************************/
---------------кслп в темповую.
select
ksg.KsgID, ROW_NUMBER() over(partition by ss.SchetSluchID order by ss.SchetSluchID) as 'number',kslp.KOEF, kslp.KOEF_TYPE
into #kslp
from ies.T_KSLP kslp 
join ies.T_KSG ksg with(nolock) on (ksg.KsgID=kslp.Ksg)
join #Ss ss on (ss.SchetSluchID=ksg.SchetSluch)



-----------------------------------Заполение таблички с выгруженными приказами!!!!!!!!!!!!!!!!!!!!!!
if ((select count(*) from #Ss)>0)
begin
insert into ies.R_NSI_LIST_OF_ORDERS ([OrderType],[OrderDate],[DictionaryBaseId],[RComment],[OrderMonth],[OrderYear])
select '23',getdate(),newid(),null,@month,@year

insert into IES.T_DICTIONARY_BASE([DictionaryBaseID],[type_]) 
select top 1 [DictionaryBaseID],9030
from ies.R_NSI_LIST_OF_ORDERS where [OrderType]='23'
order by [OrderDate] desc

---------------------------------апдейт Order23Id на счете
update ies.T_SCHET set Order23Id=(select top 1 [DictionaryBaseID] from ies.R_NSI_LIST_OF_ORDERS where [OrderType]='23' order by [OrderDate] desc)
where SchetID in (select distinct s.SchetID from #Ss s)

end

select @FileNameout = 
'TKR'+case when len(@filename)>0 then 'S' else '' end+'40'+substring(cast(@year as varchar(4)),3,2)+ format(@count,'0000') + '.xml'


---------сама выгрузка
select @ret = 
(select
 '2.0' as 'ZGLV/VERSION'
,convert(varchar(10),@date,126) as 'ZGLV/DATA'
,'TKR'+case when len(@filename)>0 then 'S' else '' end+'40'+substring(cast(@year as varchar(4)),3,2)+ format(@count,'0000') as 'ZGLV/FILENAME'
--format((select top 1 order23num from [IES].[R_NSI_GLOBAL_SETTINGS] with(nolock)),'0000') as 'ZGLV/FILENAME'
,(case when len(@filename)>0 then @filename else null end) as 'ZGLV/FIRSTNAME'
,ISNULL(@code,(select top 1 order23num from [IES].[R_NSI_GLOBAL_SETTINGS] with(nolock))) as 'SVD/CODE'
,@year as 'SVD/YEAR'
,@month as 'SVD/MONTH'

,(select
(select
		 ((ROW_NUMBER() over(order by sz.SchetZapId)) + 25857) as 'N_ZAP'
		,sz.VPOLIS as 'PACIENT/VPOLIS'
		,sz.NPOLIS as 'PACIENT/NPOLIS'
		,sz.W as 'PACIENT/W'
		,convert(varchar(10),sz.DR,126) as 'PACIENT/DR'
		,case 
			when DATEDIFF(DAY,sz.DR,ss.DATE_1)<=28
			then 1
			when DATEDIFF(DAY,sz.DR,ss.DATE_1)>=29 and DATEDIFF(DAY,sz.DR,ss.DATE_1)<=90
			then 2
			when DATEDIFF(DAY,sz.DR,ss.DATE_1)>=91 and 
			(case when not(day(ss.DATE_1)=day(sz.DR) and MONTH(ss.DATE_1)=MONTH(sz.DR))
					and	(month(sz.DR)<month(ss.DATE_1)
									or (month(sz.DR)=month(ss.DATE_1) and day(sz.DR)<day(ss.DATE_1)))
									then DATEDIFF (year, sz.DR,ss.DATE_1 ) else DATEDIFF (year, sz.DR,ss.DATE_1 )-1 
									end) < 1  
			
			
			--DATEDIFF(YEAR,sz.DR,ss.DATE_1)<=1
			then 3

			--when DATEDIFF(YEAR,sz.DR,ss.DATE_1)>=1 and DATEDIFF(YEAR,sz.DR,ss.DATE_1)<4
			--then 4
			--when DATEDIFF(YEAR,sz.DR,ss.DATE_1)>=4 and DATEDIFF(YEAR,sz.DR,ss.DATE_1)<18
			--then 5
			--when DATEDIFF(YEAR,sz.DR,ss.DATE_1)>=18 and DATEDIFF(YEAR,sz.DR,ss.DATE_1)<60
			--then 6
			--when DATEDIFF(YEAR,sz.DR,ss.DATE_1)>=60 and DATEDIFF(YEAR,sz.DR,ss.DATE_1)<75
			   when (case when month(sz.DR)<month(ss.DATE_1)
									or (month(sz.DR)=month(ss.DATE_1) and day(sz.DR)<day(ss.DATE_1))
									then DATEDIFF (year, sz.DR,ss.DATE_1 ) else DATEDIFF (year, sz.DR,ss.DATE_1 )-1 
									end) >= 1 
									and
									(case when month(sz.DR)<month(ss.DATE_1)
									or (month(sz.DR)=month(ss.DATE_1) and day(sz.DR)<day(ss.DATE_1))
									then DATEDIFF (year, sz.DR,ss.DATE_1 ) else DATEDIFF (year, sz.DR,ss.DATE_1 )-1 
									end) < 4  
									then 4
				--
				when (case when month(sz.DR)<month(ss.DATE_1)
									or (month(sz.DR)=month(ss.DATE_1) and day(sz.DR)<day(ss.DATE_1))
									then DATEDIFF (year, sz.DR,ss.DATE_1 ) else DATEDIFF (year, sz.DR,ss.DATE_1 )-1 
									end) >= 4 
									and
									(case when month(sz.DR)<month(ss.DATE_1)
									or (month(sz.DR)=month(ss.DATE_1) and day(sz.DR)<day(ss.DATE_1))
									then DATEDIFF (year, sz.DR,ss.DATE_1 ) else DATEDIFF (year, sz.DR,ss.DATE_1 )-1 
									end) < 18  
									then 5
									--
					when (case when month(sz.DR)<month(ss.DATE_1)
									or (month(sz.DR)=month(ss.DATE_1) and day(sz.DR)<day(ss.DATE_1))
									then DATEDIFF (year, sz.DR,ss.DATE_1 ) else DATEDIFF (year, sz.DR,ss.DATE_1 )-1 
									end) >= 18 
									and
									(case when month(sz.DR)<month(ss.DATE_1)
									or (month(sz.DR)=month(ss.DATE_1) and day(sz.DR)<day(ss.DATE_1))
									then DATEDIFF (year, sz.DR,ss.DATE_1 ) else DATEDIFF (year, sz.DR,ss.DATE_1 )-1 
									end) < 60  
									then 6

									--

									when (case when month(sz.DR)<month(ss.DATE_1)
									or (month(sz.DR)=month(ss.DATE_1) and day(sz.DR)<day(ss.DATE_1))
									then DATEDIFF (year, sz.DR,ss.DATE_1 ) else DATEDIFF (year, sz.DR,ss.DATE_1 )-1 
									end) >= 60 
									and
									(case when month(sz.DR)<month(ss.DATE_1)
									or (month(sz.DR)=month(ss.DATE_1) and day(sz.DR)<day(ss.DATE_1))
									then DATEDIFF (year, sz.DR,ss.DATE_1 ) else DATEDIFF (year, sz.DR,ss.DATE_1 )-1 
									end) < 75  
									then 7


when (case when month(sz.DR)<month(ss.DATE_1)
									or (month(sz.DR)=month(ss.DATE_1) and day(sz.DR)<day(ss.DATE_1))
									then DATEDIFF (year, sz.DR,ss.DATE_1 ) else DATEDIFF (year, sz.DR,ss.DATE_1 )-1 
									end) >= 75 then 8

			--then 7
			--when (case when month(sz.DR)<month(ss.DATE_1)
			--						or (month(sz.DR)=month(ss.DATE_1) and day(sz.DR)<=day(ss.DATE_1))
			--						then DATEDIFF (year, sz.DR,ss.DATE_1 ) else DATEDIFF (year, sz.DR,ss.DATE_1 )-1 
			--						end) >= 75 then  6
			else null end as 'PACIENT/VZST'
		,ssa.IDCASE as 'SLUCH/IDCASE'
		,ssa.FOR_POM as 'SLUCH/FOR_POM'
		,s.CODE_MO as 'SLUCH/LPU'

		,isnull((select top 1 isnull(so.idotd, CONCAT(ssa.usl_ok, (select top 1 l.LPU_CODE from [my_base].[dbo].[lpu] l where f003.MCOD = l.code), '999')) 
			from [my_base].[dbo].[SPR_OTD_MO] so 
			where ssa.usl_ok = so.idump and f003.MCOD = so.lpu and ss.PROFIL = so.prof ORDER BY so.idump, so.lpu,so.prof, so.podr ), -- с 2020 нет объёмов ни подразделения -- AND ss.LPU_1 = isnull(so.PODR,ss.LPU_1)),
			CONCAT(ssa.usl_ok, (select top 1 l.LPU_CODE from [my_base].[dbo].[lpu] l where f003.MCOD = l.code), '999')) as 'SLUCH/PODR'---------PODR!!

		--,convert(varchar(10),ss.DATE_1,126) as 'SLUCH/DATE_1'
		,case when ss.DATE_1<sz.DR then convert(varchar(10),ss.DATE_1+1,126) else convert(varchar(10),ss.DATE_1,126) end as 'SLUCH/DATE_1'
		,convert(varchar(10),ss.DATE_2,126) as 'SLUCH/DATE_2'
		
		,case when ss.DS1='K35.9' then 'K35.8'
			  when ss.DS1='K35.1' then 'K35.3'
			  when ss.DS1='K35.0' then 'K35.2'
			  else ss.DS1 end as 'SLUCH/DS1'
		--,ss.DS1 as 'SLUCH/DS1'
		,case
			when (select COUNT(*) from #SsDs ds where ds.SchetSluch=ss.SchetSluchID and ds.MKBType=0)>0
			then (select
					ds.MKB as 'DS2'
				  from #SsDs ds where ds.SchetSluch=ss.SchetSluchID and ds.MKBType=0
				  for xml path(''),type)
			else null end as 'SLUCH'
		,case
			when (select COUNT(*) from #SsDs ds where ds.SchetSluch=ss.SchetSluchID and ds.MKBType=1)>1
			then (select
					ds.MKB as 'DS3'
				  from #SsDs ds where ds.SchetSluch=ss.SchetSluchID and ds.MKBType=1
				  for xml path(''),type)
			else null end as 'SLUCH'
		--,ssa.RSLT as 'SLUCH/RSLT'
		,case when (select top 1 v009.DL_USLOV from ies.T_V009_RESULT v009 where v009.IDRMP=ssa.RSLT)<>ssa.USL_OK 
			  then cast(ssa.USL_OK as varchar(1))+substring(cast(ssa.RSLT as varchar(3)),2,2)
			  else ssa.RSLT end as 'SLUCH/RSLT'
		,case when ssa.USL_OK=3 then 'DIAL' 
			  else cast(ksg.N_KSG as varchar(20)) 
			  --case when exists(select * from ies.T_V023_KSG v023 where v023.V006MedicalTerms=ssa.USL_OK and v023.K_KSG=cast(ksg.N_KSG as varchar(20)) )
				 --  then cast(ksg.N_KSG as varchar(20)) 
					--else null end
			  
			  end as 'SLUCH/K_KSG'
		,case when len(cast(ksg.N_KSG as varchar(20))) > 8 THEN 1 ELSE 0 end as 'SLUCH/KSG_PG'
		--,case when (select top 1 v024.IDDKK from IES.T_V024_DOP_KR v024 where  v024.V024DopKrID= ksg.DKK1 and (v024.DATEEND is null or v024.DATEEND>ss.DATE_2) and v024.IDDKK  not like 'sh%') is null
		--	  then (select top 1 ec.DOPKRIT from IES.R_NSI_EXTRA_CRITERIA ec where ec.USL_OK=ssa.USL_OK and ec.N_KSG=cast(ksg.N_KSG as varchar(20)) and ec.DOPKRIT not like 'sh%')
		--	  else (select top 1 v024.IDDKK from IES.T_V024_DOP_KR v024 where  v024.V024DopKrID= ksg.DKK1 and (v024.DATEEND is null or v024.DATEEND>ss.DATE_2)) end
		-- as 'SLUCH/DKK1'
		--,case when (select top 1 v024.IDDKK from IES.T_V024_DOP_KR v024 where  v024.V024DopKrID= ksg.DKK2 and (v024.DATEEND is null or v024.DATEEND>ss.DATE_2)and v024.IDDKK like 'sh%') is null
		--	  then (select top 1 ec.DOPKRIT from IES.R_NSI_EXTRA_CRITERIA ec where ec.USL_OK=ssa.USL_OK and ec.N_KSG=cast(ksg.N_KSG as varchar(20)) and ec.DOPKRIT like 'sh%')
		--	  else (select top 1 v024.IDDKK from IES.T_V024_DOP_KR v024 where  v024.V024DopKrID= ksg.DKK2 and (v024.DATEEND is null or v024.DATEEND>ss.DATE_2)) end
		--  as 'SLUCH/DKK2'
		-------------------------new
		,(select 
				(select top 1 v024.IDDKK from ies.T_V024_DOP_KR v024 where v024.V024DopKrID=crit.V024DopKr) as 'CRIT'
		  from ies.T_KSG_CRIT crit where crit.Ksg=ksg.KsgID
		  for xml path(''),type) as 'SLUCH'
		,sso.K_FR as 'SLUCH/K_FR'
		,0 as 'SLUCH/UR_K'
		
		,case when exists(select * from ies.T_KSLP kslp where kslp.Ksg=ksg.KsgID and kslp.KOEF_TYPE in (select cast(koef23.IDSL as varchar(2)) from IES.R_NSI_KSLP koef23)) and ssa.USL_OK<>3
			  then 1
			  else 0 end as 'SLUCH/SL_K'
		,case when exists(select * from ies.T_KSLP kslp where kslp.Ksg=ksg.KsgID and kslp.KOEF_TYPE in (select cast(koef23.IDSL as varchar(2)) from IES.R_NSI_KSLP koef23)) and ssa.USL_OK<>3
			  then (select sum(kslp.KOEF) from ies.T_KSLP kslp 
					where kslp.Ksg=ksg.KsgID and kslp.KOEF_TYPE in (select cast(koef23.IDSL as varchar(2)) from IES.R_NSI_KSLP koef23))
			  else null end as 'SLUCH/IT_SL'
			-----------------------------------------------------------KSLP-------------------------------------------------------------------------------------
		,case when ssa.USL_OK<>3
			  then
			  (select
			-- (select top 1 ks.IDSL from ies.R_NSI_KSLP ks 
			--		where ks.ZKOEF=kslp.KOEF and ss.DATE_1>=ks.DATE_BEGIN and (ks.DATE_END is null or ks.DATE_END>=ss.DATE_1)
			--		 order by ks.IDSL) as 'IDSL'
			--,kslp.KOEF as 'Z_SL'
		 -- from ies.T_KSLP kslp 
			--where kslp.Ksg=ksg.KsgID and kslp.KOEF_TYPE in (select cast(koef23.IDSL as varchar(2)) from IES.R_NSI_SLK_23 koef23)
			--group by kslp.KOEF,kslp.KOEF_TYPE
				/*
				 isnull((select top 1 kd.IDSL from #kslpDictionary kd where kd.number=kslp.number and 
				 kd.SchetSluchID=ss.SchetSluchID)
						,(select top 1 ks.IDSL from ies.R_NSI_KSLP ks where ks.NPR is not null
										and ks.ZKOEF=kslp.KOEF and ss.DATE_2>=ks.DATE_BEGIN and (ks.DATE_END is null or ks.DATE_END>=ss.DATE_2) 
							order by ks.IDSL)) as 'IDSL'
				*/
				kslp.KOEF_TYPE as 'IDSL'
				,kslp.KOEF as 'Z_SL'
			from #kslp kslp
			where kslp.KsgID=ksg.KsgID and exists(select * from ies.T_KSLP kslp where kslp.Ksg=ksg.KsgID and kslp.KOEF_TYPE in (select cast(koef23.IDSL as varchar(2))
			from IES.R_NSI_KSLP koef23)) and ssa.USL_OK<>3
				and (select top 1 ks.IDSL from ies.R_NSI_KSLP ks where ks.NPR is not null
										and ks.ZKOEF=kslp.KOEF and ss.DATE_2>=ks.DATE_BEGIN and (ks.DATE_END is null or ks.DATE_END>=ss.DATE_2) 
							order by ks.IDSL) is not null
			for xml path('SL_KOEF'),type)
			else null end as 'SLUCH'
		--,case
		--	when not exists(select * from ies.T_SCHET_USL su where su.SchetSluch=ss.SchetSluchID and su.CODE_USL in (select usl23.UslCode from IES.R_NSI_DIAL_USL_23 usl23)and su.CODE_USL not like 'S%' and su.CODE_USL not like 'V%')
		--	then ss.SUMP
		--	else 0 end as 'SLUCH/SUM_KSG'
		--,case
		--	when exists(select * from ies.T_SCHET_USL su
		--			 join ies.T_V001_NOMENCLATURE v001 on v001.Code=su.CODE_USL
		--			 where su.SchetSluch=ss.SchetSluchID and su.CODE_USL in (select usl23.UslCode from IES.R_NSI_DIAL_USL_23 usl23)
		--							and su.CODE_USL not like 'S%' and su.CODE_USL not like 'V%')
		--	then (select sum(su.SUMV_USL) from ies.T_SCHET_USL su
		--			 join ies.T_V001_NOMENCLATURE v001 on v001.Code=su.CODE_USL
		--			 where su.SchetSluch=ss.SchetSluchID and su.CODE_USL in (select usl23.UslCode from IES.R_NSI_DIAL_USL_23 usl23)
		--							and su.CODE_USL not like 'S%' and su.CODE_USL not like 'V%')
		--	else 0 end as 'SLUCH/SUM_DIAL'
		,(ss.SUMP - isnull((select sum(su.SUMV_USL) from ies.T_SCHET_USL su
					 join ies.T_V001_NOMENCLATURE v001 on v001.Code=su.CODE_USL
					 where su.SchetSluch=ss.SchetSluchID and su.CODE_USL in (select usl23.UslCode from IES.R_NSI_DIAL_USL_23 usl23)
									and su.CODE_USL not like 'S%' and su.CODE_USL not like 'V%'), 0)) as 'SLUCH/SUM_KSG'
		,case
			when exists(select * from ies.T_SCHET_USL su
					 join ies.T_V001_NOMENCLATURE v001 on v001.Code=su.CODE_USL
					 where su.SchetSluch=ss.SchetSluchID and su.CODE_USL in (select usl23.UslCode from IES.R_NSI_DIAL_USL_23 usl23)
									and su.CODE_USL not like 'S%' and su.CODE_USL not like 'V%')
			then (select sum(su.SUMV_USL) from ies.T_SCHET_USL su
					 join ies.T_V001_NOMENCLATURE v001 on v001.Code=su.CODE_USL
					 where su.SchetSluch=ss.SchetSluchID and su.CODE_USL in (select usl23.UslCode from IES.R_NSI_DIAL_USL_23 usl23)
									and su.CODE_USL not like 'S%' and su.CODE_USL not like 'V%')
			else 0 end as 'SLUCH/SUM_DIAL'
		,ss.SUMP as 'SLUCH/SUM_IT'
		
		,case when exists(select * from #pvtSluchs ps where ps.SchetSluch=ss.SchetSluchID) then 1 else 0 end as 'SLUCH/PVT'
		
		,(select 
				 su.IDSERV as 'IDSERV'
				,su.CODE_USL as 'CODE_USL'
				,ISNULL(su.KOL_USL,0) as 'KOL_USL'
				,case when su.CODE_USL in (select p23.UslCode from ies.R_NSI_DIAL_USL_23 p23)and su.CODE_USL not like 'S%' and su.CODE_USL not like 'V%'
				then su.SUMV_USL 
				else null end as 'SUM_USL'
		  from ies.T_SCHET_USL su
		  join ies.T_V001_NOMENCLATURE v001 on (v001.Code=su.CODE_USL)
		  where su.SchetSluch=ss.SchetSluchID 
		  --and not exists(select * from ies.R_NSI_KSLP ks
				--				join ies.R_NSI_USL usl on (ks.CODE_USL=usl.DictionaryBaseID)
				--				 where usl.CODE_USL=su.CODE_USL) 
			and su.CODE_USL not like 'S%' and su.CODE_USL not like 'V%' 
			and (su.CODE_USL in (select UslCode from ies.R_NSI_DIAL_USL_23) and su.CODE_USL like 'A18%' or su.CODE_USL not like 'A18%')
		  for xml path('USL'),type) as 'SLUCH'
		  
 from ies.T_SCHET_SLUCH ss with(nolock)
 join ies.T_SCHET_ZAP sz with(nolock) on (sz.SchetZapID=ss.SchetZap)
 join ies.T_SCHET s with(nolock) on (sz.Schet=s.SchetID)
 join ies.T_F003_MO f003 with(nolock) on (s.CODE_MO=f003.MCOD)
 join ies.T_SCHET_SLUCH_ACCOMPLISHED ssa with(nolock) on (ssa.SchetSluchAccomplishedID=ss.SchetSluchAccomplished)
 left join ies.T_KSG ksg with(nolock) on (ss.SchetSluchID=ksg.SchetSluch)
 left join ies.T_SCHET_SLUCH_ONK sso with(nolock) on (sso.SchetSluch=ss.SchetSluchID)
 --join ies.T_REESTR_CLOSE_INFO ci on (s.SchetID=ci.Schet)-------------------------закрытые счета
where f003.TF_OKATO='29000' and 
(ssa.USL_OK in (1,2,21,22,23) or (ssa.USL_OK=3 and exists(select * from ies.T_SCHET_USL su with(nolock)join ies.T_V001_NOMENCLATURE v001 on v001.Code=su.CODE_USL where su.SchetSluch=ss.SchetSluchID and su.CODE_USL in (select u23.UslCode from ies.R_NSI_DIAL_USL_23 u23))))
and ss.SUMP>0
and s.IsDelete=0
and (s.type_=554 and (YEAR(s.receiveddate) = @year AND MONTH(s.receiveddate) = @month AND s.[YEAR] = @year OR s.[YEAR]= @year AND s.Order23Id IS NULL and month(s.ReceivedDate)<@month) and s.[Status]=1 
or (s.type_ = 693 and s.[MONTH]=@month and s.[YEAR]=@year or s.[YEAR]=@year and s.[MONTH]<@month and s.Order23Id is null) )
and year(ss.DATE_2)=@year and s.FILENAME not like 'T%'


order by N_ZAP
for xml path('ZAP'),type)
for xml path('PODR'),type)
for xml path(''),ROOT ('ISP_OB')
)


drop table #Ss
drop table #SsDs
drop table #sluchs
drop table #peoples
drop table #pvtSluchs
drop table #kslp

END


