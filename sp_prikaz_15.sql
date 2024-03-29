USE [IESDB]
GO
/****** Object:  StoredProcedure [dbo].[sp_prikaz_15]    Script Date: 21.05.2021 12:03:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[sp_prikaz_15] (@month [int], @year [int],@mo varchar(6), @filename varchar(20), @filename1 varchar(20), @FileNameout varchar(max) out,@ret varchar(max) out)
AS 
BEGIN 
if (@month is null or @year is null or len(isnull(@filename,''))=0)
begin
	raiserror('Не все поля заполнены!',16,1)
end

-------------------------удалить если не нужно
if (exists(select * from ies.T_SCHET where Order15Id is not null and [MONTH]=@month and [YEAR]=@year) and @year>2018)
begin
	raiserror('За этот месяц приказ уже выгружен, удалите старую запись!',16,1)
end

----------счетчик
update [IESDB].[IES].[R_NSI_GLOBAL_SETTINGS] set Order15num=Order15num+1
declare @count int = (select top 1 Order15num from [IES].[R_NSI_GLOBAL_SETTINGS])
---20210322 Исправления для МО 400001 из за подушёвки сумм

--для 1 показателя по данным планового отдела из Оракла
--SELECT profil_mp as PROFIL, round(ot_s_kol / 12, 2) as [SUM] into #TEMP_1P
--FROM   ORACLE..LPU.MED_OI_PR_SV pr
--INNER  JOIN ORACLE..LPU.MED_OI_IT_SV it ON pr.it_sv_id = it.it_sv_id
--INNER  JOIN ORACLE..LPU.MED_OI_OB_SV ob ON it.ob_sv_id = ob.ob_sv_id
--WHERE  zglv_id = (SELECT MAX(zglv_id) FROM ORACLE..LPU.MED_OI_ZGLV)
--			 AND mo_sv = '400001'
--			 AND ot_naim = 1 -- посещения с проф целью
--       and profil_mp not in (85,86,87,88,89) -- исключаем стоматологию

--для 1 показателя по данным отдела статистики (Медэскперт - плановые показатели для 15 приказа)
SELECT mo,profil,plansumm as SUM
 into #TEMP_1P
FROM IES.R_NSI_15_prikaz p15
WHERE year = @year
      AND month = @month
      AND pokaz_code = 1

--для 3 показателя
--SELECT profil_mp as PROFIL, round(ot_s_kol / 12, 2)  as [SUM] into #TEMP_3P
--FROM   ORACLE..LPU.MED_OI_PR_SV pr
--INNER  JOIN ORACLE..LPU.MED_OI_IT_SV it ON pr.it_sv_id = it.it_sv_id
--INNER  JOIN ORACLE..LPU.MED_OI_OB_SV ob ON it.ob_sv_id = ob.ob_sv_id
--WHERE  zglv_id = (SELECT MAX(zglv_id) FROM ORACLE..LPU.MED_OI_ZGLV)
--			 AND mo_sv = '400001'
--			 AND ot_naim = 3 -- посещения с проф целью
--       and profil_mp not in (85,86,87,88,89)

--для 3 показателя по данным отдела статистики (Медэскперт - плановые показатели для 15 приказа)
SELECT mo,profil,plansumm as SUM
 into #TEMP_3P
FROM IES.R_NSI_15_prikaz p15
WHERE year = @year
      AND month = @month
      AND pokaz_code = 3

--для 12 показателя - скорая помощь

SELECT profil_mp as PROFIL, round(ot_s_kol / 12, 2)  as [SUM] into #TEMP_12P
FROM   ORACLE..LPU.MED_OI_PR_SV pr
INNER  JOIN ORACLE..LPU.MED_OI_IT_SV it ON pr.it_sv_id = it.it_sv_id
INNER  JOIN ORACLE..LPU.MED_OI_OB_SV ob ON it.ob_sv_id = ob.ob_sv_id
WHERE  zglv_id = (SELECT MAX(zglv_id) FROM ORACLE..LPU.MED_OI_ZGLV)
			 AND mo_sv = '400001'
			 AND ot_naim = 12 -- СМП
       and profil_mp not in (85,86,87,88,89)
--Конец


----------Гружу случаи по территориалкам и мтр 
----------oms
select 
	ss.PROFIL, ss.CEL, ssa.IDSP, ssa.USL_OK, ssa.RSLT, ssa.SchetSluchAccomplishedID, ss.SchetSluchID, ssa.SUMP, 'oms' as 'type', ssa.OPLATA, ss.ED_COL, ssa.SUMV, ssa.KD_Z, sz.FAM, 
	sz.IM, sz.OT, sz.DR, f002.TF_OKATO, sz.W, ss.DATE_1, ssa.IDCASE, ssa.VIDPOM, ssa.FOR_POM, ss.COMENTSL, ss.VID_HMP, ss.METOD_HMP, ssa.LPU, ss.SUMV as 'SUMVS', ss.SUMP as 'SUMPS', sz.SchetZapID
	,row_number() over(partition by ss.SchetSluchAccomplished order by ss.SchetSluchAccomplished) as 'Number'
	,1 as 'MoNumber'
	,s.CODE_MO,s.SchetID, u.kol_usl,
	-- неподушевые услуги для 400001 кб8
	case when isnull(code_usl,'0') in ('A03.16.001','A04.10.002','A04.12.002.001','A04.12.005.003','A05.03.002','A05.04.001','A05.23.009','A05.23.009.001','A05.30.004','A05.30.005','A05.30.006.001','A05.30.011','A05.30.012','A06.30.003.008')
	then 0 else 1 end podush
into #Sluchs
from ies.T_SCHET_SLUCH ss
join ies.T_SCHET_ZAP sz on (sz.SchetZapID=ss.SchetZap)
join ies.T_SCHET s on (s.SchetID=sz.Schet)
join ies.T_SCHET_SLUCH_ACCOMPLISHED ssa on (ssa.SchetSluchAccomplishedID=ss.SchetSluchAccomplished)
OUTER APPLY -- считаем количество услуг (нужно для стоматологии)
(SELECT code_usl, sum(usl.KOL_USL) kol_usl, sum(usl.SUMV_USL) sum_usl
 FROM   IES.T_SCHET_USL usl WITH(NOLOCK)
 WHERE  usl.sumv_usl > 0 and ss.SchetSluchID = usl.SchetSluch 
 group by code_usl
) u
left join ies.T_F002_SMO f002 on f002.SMOCOD=s.PLAT
join ies.T_REESTR_CLOSE_INFO rci on (s.SchetID=rci.Schet)--закрытые
where s.[YEAR] = @year and s.CODE_MO like (@mo+'%') and s.type_ = 693 and ssa.SUMP>0 and s.CODE_MO in ('400001','400004','400109','400072') 
   and ssa.LPU in ('400001','400004','400109','400072') and s.IsDelete=0 AND
-----app
((exists(select * from ies.T_SCHET_USL su
			cross apply(select top 1 ut.ID as UTYPE from IES.R_NSI_USL_V001 spr
						inner JOIN IES.T_SPR_USL_TYPE_NAME ut ON ut.DictionaryBaseID = spr.USLTYPE  where spr.CODE_USL=su.CODE_USL) r
			where su.SchetSluch=ss.SchetSluchID and (r.UTYPE in (3,4,5, 11, 14, 17, 22, 24, 28,30,33,36,26,27,10,29,7,8) or r.UTYPE in (1) and su.SUMV_USL<>0))

) and ssa.USL_OK = 3
----skor
 or (ssa.USL_OK=4 and ssa.VIDPOM<>13 
		and exists(select * from ies.T_SCHET_USL su
			cross apply(select top 1 ut.ID as UTYPE from IES.R_NSI_USL_V001 spr
						inner JOIN IES.T_SPR_USL_TYPE_NAME ut ON ut.DictionaryBaseID = spr.USLTYPE  where spr.CODE_USL=su.CODE_USL) r
			where su.SchetSluch=ss.SchetSluchID and r.UTYPE=9)
	)

------vmp
or
 ssa.VIDPOM=32
------stac
or ssa.USL_OK in (1,2)
 )
 and (s.MONTH=@month or (s.month < @month and s.MONTH>=(case when @month<4 then 1 else @month-3 end) and s.Order15Id is null) and s.YEAR>=2019)
----------mtr
insert into #Sluchs
select 
	ss.PROFIL, ss.CEL, ssa.IDSP, ssa.USL_OK, ssa.RSLT, ssa.SchetSluchAccomplishedID, ss.SchetSluchID, ssa.SUMP, 'mtr', ssa.OPLATA, ss.ED_COL, ssa.SUMV, ssa.KD_Z, sz.FAM, 
	sz.IM, sz.OT, sz.DR, f002.TF_OKATO, sz.W, ss.DATE_1, ssa.IDCASE, ssa.VIDPOM, ssa.FOR_POM, ss.COMENTSL, ss.VID_HMP, ss.METOD_HMP, ssa.LPU, ss.SUMV as 'SUMVS', ss.SUMP as 'SUMPS', sz.SchetZapID
	,row_number() over(partition by ss.SchetSluchAccomplished order by ss.SchetSluchAccomplished) as 'Number'
	,1 as 'MoNumber'
	,s.CODE_MO,s.SchetID, u.kol_usl, 0 podush
from ies.T_SCHET_SLUCH ss
join ies.T_SCHET_ZAP sz on (sz.SchetZapID=ss.SchetZap)
join ies.T_SCHET s on (s.SchetID=sz.Schet)
join ies.T_SCHET_SLUCH_ACCOMPLISHED ssa on (ssa.SchetSluchAccomplishedID=ss.SchetSluchAccomplished)
OUTER APPLY -- считаем количество услуг (нужно для стомтаологии)
(SELECT sum(usl.KOL_USL) kol_usl, sum(usl.SUMV_USL) sum_usl
 FROM   IES.T_SCHET_USL usl WITH(NOLOCK)
 WHERE  usl.sumv_usl > 0 and ss.SchetSluchID = usl.SchetSluch 
) u
left join ies.T_F002_SMO f002 on f002.SMOCOD=s.PLAT
left join ies.T_SCHET_ACT_ITEM sai on (sai.SchetSluch=ss.SchetSluchID)
join ies.T_REESTR_CLOSE_INFO rci on (s.SchetID=rci.Schet)--закрытые
where s.[YEAR] = @year  and s.CODE_MO like (@mo+'%') and s.type_ = 554 and ssa.SUMP>0 and s.CODE_MO in ('400001','400004','400109','400072') 
	and ssa.LPU in ('400001','400004','400109','400072') and s.IsDelete=0 and
-----app
((exists(select * from ies.T_SCHET_USL su
			cross apply(select top 1 ut.ID as UTYPE from IES.R_NSI_USL_V001 spr
						inner JOIN IES.T_SPR_USL_TYPE_NAME ut ON ut.DictionaryBaseID = spr.USLTYPE  where spr.CODE_USL=su.CODE_USL) r
			where su.SchetSluch=ss.SchetSluchID and (r.UTYPE in (3,4,5, 11, 14, 17, 22, 24, 28,30,33,36,26,27,10,29) or r.UTYPE in (1) and su.SUMV_USL<>0))
) and ssa.USL_OK = 3
----skor
 or (ssa.USL_OK=4 and ssa.VIDPOM<>13 
		and exists(select * from ies.T_SCHET_USL su
			cross apply(select top 1 ut.ID as UTYPE from IES.R_NSI_USL_V001 spr
						inner JOIN IES.T_SPR_USL_TYPE_NAME ut ON ut.DictionaryBaseID = spr.USLTYPE  where spr.CODE_USL=su.CODE_USL) r
			where su.SchetSluch=ss.SchetSluchID and r.UTYPE=9)
	)
------vmp
or
 ssa.VIDPOM=32
------stac
or ssa.USL_OK in (1,2)
 )
 and (s.MONTH=@month or (s.month < @month and s.MONTH>=(case when @month<4 then 1 else @month-3 end) and s.Order15Id is null) and s.YEAR>=2019)

 -------------------------исключения!!!!!
 -- Как оказалось услуги из группы 7,8 должны как раз считаться в сумму и НЕ увеличивать объёмы
 -- поэтому переделал кокретно в 1м показателе
 -- а это исключение закоментировал
 -- условие на 7,8 группу доьавил в основную выборку
-- insert into #Sluchs
--select 
--	ss.PROFIL, ss.CEL, ssa.IDSP, ssa.USL_OK, ssa.RSLT, ssa.SchetSluchAccomplishedID, ss.SchetSluchID, 0, 'oms', ssa.OPLATA, ss.ED_COL, 0, ssa.KD_Z, sz.FAM, 
--	sz.IM, sz.OT, sz.DR, f002.TF_OKATO, sz.W, ss.DATE_1, ssa.IDCASE, ssa.VIDPOM, ssa.FOR_POM, ss.COMENTSL, ss.VID_HMP, ss.METOD_HMP, ssa.LPU, 0 as 'SUMVS', 0 as 'SUMPS', sz.SchetZapID
--	,row_number() over(partition by ss.SchetSluchAccomplished order by ss.SchetSluchAccomplished) as 'Number'
--	,1 as 'MoNumber'
--	,s.CODE_MO,s.SchetID
--from ies.T_SCHET_SLUCH ss
--join ies.T_SCHET_ZAP sz on (sz.SchetZapID=ss.SchetZap)
--join ies.T_SCHET s on (s.SchetID=sz.Schet)
--join ies.T_SCHET_SLUCH_ACCOMPLISHED ssa on (ssa.SchetSluchAccomplishedID=ss.SchetSluchAccomplished)
--left join ies.T_F002_SMO f002 on f002.SMOCOD=s.PLAT
--left join ies.T_SCHET_ACT_ITEM sai on (sai.SchetSluch=ss.SchetSluchID)
--join ies.T_REESTR_CLOSE_INFO rci on (s.SchetID=rci.Schet)--закрытые
--where s.IsDelete=0 and s.CODE_MO  in ('400109','400001') and exists(select * from ies.T_SCHET_USL su
--			cross apply(select top 1 spr.UTYPE from ies.T_SPR_USL_TYPE spr where spr.UCODE=su.CODE_USL) r
--			where su.SchetSluch=ss.SchetSluchID and r.UTYPE in (7,8))
-- and s.[YEAR] = @year  and s.CODE_MO like (@mo+'%') and s.type_ = 693 and ssa.SUMP>0 
-- and (s.MONTH=@month or (s.month < @month and s.MONTH>=(case when @month<4 then 1 else @month-3 end) and s.Order15Id is null) and s.MONTH>=2019)


--insert into #Sluchs
--select 
--	ss.PROFIL, ss.CEL, ssa.IDSP, ssa.USL_OK, ssa.RSLT, ssa.SchetSluchAccomplishedID, ss.SchetSluchID, 0, 'mtr', ssa.OPLATA, ss.ED_COL, 0, ssa.KD_Z, sz.FAM, 
--	sz.IM, sz.OT, sz.DR, f002.TF_OKATO, sz.W, ss.DATE_1, ssa.IDCASE, ssa.VIDPOM, ssa.FOR_POM, ss.COMENTSL, ss.VID_HMP, ss.METOD_HMP, ssa.LPU, 0 as 'SUMVS', 0 as 'SUMPS', sz.SchetZapID
--	,row_number() over(partition by ss.SchetSluchAccomplished order by ss.SchetSluchAccomplished) as 'Number'
--	,1 as 'MoNumber'
--	,s.CODE_MO,s.SchetID
--from ies.T_SCHET_SLUCH ss
--join ies.T_SCHET_ZAP sz on (sz.SchetZapID=ss.SchetZap)
--join ies.T_SCHET s on (s.SchetID=sz.Schet)
--join ies.T_SCHET_SLUCH_ACCOMPLISHED ssa on (ssa.SchetSluchAccomplishedID=ss.SchetSluchAccomplished)
--left join ies.T_F002_SMO f002 on f002.SMOCOD=s.PLAT
--left join ies.T_SCHET_ACT_ITEM sai on (sai.SchetSluch=ss.SchetSluchID)
--join ies.T_REESTR_CLOSE_INFO rci on (s.SchetID=rci.Schet)--закрытые
--where s.IsDelete=0 and s.CODE_MO  in ('400109','400001') and exists(select * from ies.T_SCHET_USL su
--			cross apply(select top 1 spr.UTYPE from ies.T_SPR_USL_TYPE spr where spr.UCODE=su.CODE_USL) r
--			where su.SchetSluch=ss.SchetSluchID and r.UTYPE in (7,8))
--and s.[YEAR] = @year  and s.CODE_MO like (@mo+'%') and s.type_ = 554 and ssa.SUMP>0 
--and (s.MONTH=@month or (s.month < @month and s.MONTH>=(case when @month<4 then 1 else @month-3 end) and s.Order15Id is null) and s.MONTH>=2019)

-------УДАЛЯЮ ИСКЛЮЧЕНИЯ
delete from #Sluchs where SchetSluchID in ('1d25f6da-90e6-48b2-8fbc-92cdd610cbc4','1d25f6da-90e6-48b2-8fbc-92cdd610cbc4')


 --НУМЕРАЦИЯ ДЛЯ МО
 select s.SchetSluchID, row_number() over(partition by s.CODE_MO order by s.CODE_MO) as 'Num'
 into #MoNumbersTable
 from #Sluchs s

 update t1 set t1.MoNumber=t2.Num
 from #Sluchs t1
 join #MoNumbersTable t2 on (t1.SchetSluchID=t2.SchetSluchID)

----------------Узнаю сколько омс зак. случаев
declare @omsCount int = (select count(*) from #Sluchs s where s.SchetSluchID = (select top 1 t2.SchetSluchID from #Sluchs t2 where t2.[type] = 'oms' and t2.SchetSluchAccomplishedID=s.SchetSluchAccomplishedID))

-----------услуги для стационара
select
	 ss.[type] as 'type_'
	,(case when ss.USL_OK=1 and DATEDIFF(day,su.DATE_IN, su.DATE_OUT)>0 then DATEDIFF(day,su.DATE_IN, su.DATE_OUT)
		   when ss.USL_OK=2 and DATEDIFF(day,su.DATE_IN, su.DATE_OUT)>0 then DATEDIFF(day,su.DATE_IN, su.DATE_OUT)+1
		   else 0 end) as 'ED_COL_R'
	,ss.SchetSluchID
	,su.SchetUslID
	,ss.USL_OK
	,ss.PROFIL
into #Usls
from ies.T_SCHET_USL su
join #Sluchs ss on (ss.SchetSluchID=su.SchetSluch and ss.USL_OK=2)


-------------------------------------------------COUNTS---------------------------------------------------------------
--------3 count
select *
into #omsCount3
from #Sluchs t1
where RSLT in (301,302,303,304,305,306,307,308,309,310,311,313,314,315) and (USL_OK = 3 or IDSP = 9)
		and CEL in (1,26,21,22) 
		and exists(select * from #Sluchs t2 where t1.SchetSluchAccomplishedID=t2.SchetSluchAccomplishedID and t1.SchetSluchID<>t2.SchetSluchID)
		and [type] = 'oms'

select t1.SchetSluchAccomplishedID,(select top 1 t10.PROFIL from #Sluchs t10 where t10.SchetSluchAccomplishedID=t1.SchetSluchAccomplishedID) as 'PROFIL'
into #mtrCount3
from #Sluchs t1
where RSLT in (301,302,303,304,305,306,307,308,309,310,311,313,314,315) and (USL_OK = 3 or IDSP = 9)
		and CEL in (1,26,21,22)
		and exists(select * from #Sluchs t2 where t1.SchetSluchAccomplishedID=t2.SchetSluchAccomplishedID and t1.SchetSluchID<>t2.SchetSluchID)
		and [type] = 'mtr'
group by t1.SchetSluchAccomplishedID

--Костыль
--DELETE FROM #sluchs
--WHERE CODE_MO = 400109 and SUMP=0

-----------------------------------Заполение таблички с выгруженными приказами!!!!!!!!!!!!!!!!!!!!!!
if ((select count(*) from #sluchs)>0)
begin
insert into ies.R_NSI_LIST_OF_ORDERS ([OrderType],[OrderDate],[DictionaryBaseId],[RComment],[OrderMonth],[OrderYear])
select '15',getdate(),newid(),null,@month,@year

insert into IES.T_DICTIONARY_BASE([DictionaryBaseID],[type_]) 
select top 1 [DictionaryBaseID],9030
from ies.R_NSI_LIST_OF_ORDERS where [OrderType]='15'
order by [OrderDate] desc

---------------------------------апдейт Order15Id на счете
update ies.T_SCHET set Order15Id=(select top 1 [DictionaryBaseID] from ies.R_NSI_LIST_OF_ORDERS where [OrderType]='15' order by [OrderDate] desc)
where SchetID in (select distinct s.SchetID from #sluchs s)

end



select @FileNameout = 
case when len(isnull(@filename,''))>0 then @filename + '.xml' else 'null.xml' end 


--------------------------------------------------MAIN----------------------------------------------------------------
select @ret =
(select
'1.0' as 'ZGLV/VERSION'
,cast(convert(varchar, getdate(), 20) as varchar(10)) as 'ZGLV/DATA'
,case when len(isnull(@filename,''))>0 then @filename else null end as 'ZGLV/FILENAME'
,case when len(isnull(@filename1,''))>0 then @filename1 else null end as 'ZGLV/FIRSTNAME'
,@count as 'SVD/CODE'
,@year as 'SVD/YEAR'
,@month as 'SVD/MONTH'
,1 as 'SVD/OBLM'
,(select
row_number() over(partition by 1 order by t100.CODE_MO) as 'N_SV'
,t100.CODE_MO as 'MO_SV'
------1
,(select top 1
	 1 as 'OT_NAIM'
	,(
	
	SELECT PROFIL_MP,
	   SUM(R_KOL) 'R_KOL',
	   SUM(R_S_KOL) 'R_S_KOL',
	   SUM(R_KOL_M) 'R_KOL_M',
	   SUM(R_S_KOL_M) 'R_S_KOL_M' FROM (
	   SELECT 
			 t1.PROFIL as 'PROFIL_MP'
			,cast(round(sum(case when t1.[type]='oms' then case when t1.PROFIL in (85,86,87,88,89) then t1.kol_usl else 1 end else 0 end), 0) as int) as 'R_KOL'

			,(case when t1.CODE_MO ='400001' and t1.PROFIL not in (85,86,87,88,89) and t1.PROFIL in (select PROFIL from #TEMP_1P group by PROFIL  ) 
				then (select [sum] from #TEMP_1P  where t1.PROFIL = PROFIL)  + sum(case when t1.[type]='oms' and podush = 0 then t1.SUMPS else 0 end)
		----OLDWAY
			else sum(case when t1.[type]='oms' then t1.SUMPS else 0 end) end ) as 'R_S_KOL'
			,sum(case when t1.[type]='mtr' then 1 else 0 end) as 'R_KOL_M'
			,sum(case when t1.[type]='mtr' then t1.SUMPS else 0 end) as 'R_S_KOL_M'
	  from #Sluchs t1
	  where t1.CODE_MO=t100.CODE_MO and t1.USL_OK=3 and
		(exists(select * from ies.T_SCHET_USL su
			cross apply(select top 1 ut.ID as UTYPE from IES.R_NSI_USL_V001 spr
						inner JOIN IES.T_SPR_USL_TYPE_NAME ut ON ut.DictionaryBaseID = spr.USLTYPE  where spr.CODE_USL=su.CODE_USL) r
			where su.SchetSluch=t1.SchetSluchID and (r.UTYPE in (3,4,5, 11, 14, 17, 22, 24, 28,30,33,36) or su.SUMV_USL<>0 and r.UTYPE in (1)))
			)
	  group by t1.PROFIL,t1.CODE_MO
UNION ALL
      select
			 t1.PROFIL as 'PROFIL_MP'
			,0 as 'R_KOL'
			--NEWWAY
		--	,(case when t1.CODE_MO ='400001' and t1.PROFIL not in (85,86,87,88,89) then (select [sum] from #TEMP_1P  where t1.PROFIL = PROFIL)  
		----OLDWAY
		--	else sum(case when t1.[type]='oms' then t1.SUMPS else 0 end) end ) as 'R_S_KOL'
			,sum(case when t1.[type]='oms' then t1.SUMPS else 0 end) as 'R_S_KOL'
			,0 as 'R_KOL_M'
			,sum(case when t1.[type]='mtr' then t1.SUMPS else 0 end) as 'R_S_KOL_M'
	  from #Sluchs t1
	  where t1.CODE_MO=t100.CODE_MO and t1.USL_OK=3 and
		 t1.CODE_MO IN ('400109','400004', '400001') and exists(select * from ies.T_SCHET_USL su
			cross apply(select top 1 ut.ID as UTYPE from IES.R_NSI_USL_V001 spr
						inner JOIN IES.T_SPR_USL_TYPE_NAME ut ON ut.DictionaryBaseID = spr.USLTYPE  where spr.CODE_USL=su.CODE_USL) r
			where su.SchetSluch=t1.SchetSluchID and r.UTYPE in (7,8))
			
	  group by t1.PROFIL
	 
	  ) a GROUP BY PROFIL_MP
	   order by PROFIL_MP

	  for xml path('PR_SV'),type
	  ) 
from #Sluchs frst
where frst.CODE_MO=t100.CODE_MO and frst.USL_OK=3 and
(exists(select * from ies.T_SCHET_USL su
			cross apply(select top 1 ut.ID as UTYPE from IES.R_NSI_USL_V001 spr
						inner JOIN IES.T_SPR_USL_TYPE_NAME ut ON ut.DictionaryBaseID = spr.USLTYPE  where spr.CODE_USL=su.CODE_USL) r
			where su.SchetSluch=frst.SchetSluchID and (r.UTYPE in (3,4,5, 11, 14, 17, 22, 24, 28,30,33,36) or su.SUMV_USL<>0 and r.UTYPE in (1)))
			-- Львов 21-02-2019
			or frst.CODE_MO IN ('400109','400004', '400001') and exists(select * from ies.T_SCHET_USL su
			cross apply(select top 1 ut.ID as UTYPE from IES.R_NSI_USL_V001 spr
						inner JOIN IES.T_SPR_USL_TYPE_NAME ut ON ut.DictionaryBaseID = spr.USLTYPE  where spr.CODE_USL=su.CODE_USL) r
			where su.SchetSluch=frst.SchetSluchID and r.UTYPE in (7,8))
			)
for xml path('IT_SV'),type)
	  

------2
,(select top 1
	 2 as 'OT_NAIM'
	,(select
			 t1.PROFIL as 'PROFIL_MP'
			,sum(case when t1.[type]='oms' then 1 else 0 end) as 'R_KOL'
			,sum(case when t1.[type]='oms' then t1.SUMPS else 0 end) as 'R_S_KOL'
			,sum(case when t1.[type]='mtr' then 1 else 0 end) as 'R_KOL_M'
			,sum(case when t1.[type]='mtr' then t1.SUMPS else 0 end) as 'R_S_KOL_M'
	  from #Sluchs t1
	  where t1.CODE_MO=t100.CODE_MO and 
		(exists(select * from ies.T_SCHET_USL su
			cross apply(select top 1 ut.ID as UTYPE from IES.R_NSI_USL_V001 spr
						inner JOIN IES.T_SPR_USL_TYPE_NAME ut ON ut.DictionaryBaseID = spr.USLTYPE  where spr.CODE_USL=su.CODE_USL) r
			where su.SchetSluch=t1.SchetSluchID and r.UTYPE in (10,29))
			--or t1.CODE_MO='400001' and exists(select * from ies.T_SCHET_USL su
			--cross apply(select top 1 spr.UTYPE from ies.T_SPR_USL_TYPE spr where spr.UCODE=su.CODE_USL) r
			--where su.SchetSluch=t1.SchetSluchID and r.UTYPE in (7,8))
			-- Львов 21-02-2019 МРНЦ временно убираем неотложку
			--AND t1.CODE_MO <> '400109'
			)
	  group by t1.PROFIL
	  order by t1.PROFIL
	  for xml path('PR_SV'),type
	  ) 
from #Sluchs frst
where frst.CODE_MO=t100.CODE_MO and 
(exists(select * from ies.T_SCHET_USL su
			cross apply(select top 1 ut.ID as UTYPE from IES.R_NSI_USL_V001 spr
						inner JOIN IES.T_SPR_USL_TYPE_NAME ut ON ut.DictionaryBaseID = spr.USLTYPE  where spr.CODE_USL=su.CODE_USL) r
			where su.SchetSluch=frst.SchetSluchID and r.UTYPE in (10,29))
			--or frst.CODE_MO='400001' and exists(select * from ies.T_SCHET_USL su
			--cross apply(select top 1 spr.UTYPE from ies.T_SPR_USL_TYPE spr where spr.UCODE=su.CODE_USL) r
			--where su.SchetSluch=frst.SchetSluchID and r.UTYPE in (7,8))
			-- AND frst.CODE_MO <> '400109'
			)
for xml path('IT_SV'),type)
	  
--------3

,(select top 1
	  3 as 'OT_NAIM'
	 ,(select
			 t1.PROFIL as 'PROFIL_MP'
			 -- Спросить у Димы как считается количество
			--,(select count(*) from #omsCount3 c3 where c3.PROFIL=t1.PROFIL 
			--and not exists(select * from #omsCount3 c31 where c31.SchetSluchAccomplishedID=c3.SchetSluchAccomplishedID and c31.SchetSluchID>c3.SchetSluchID)) as 'R_KOL'
			,cast(round(sum(case when t1.[type]='oms' then case when t1.PROFIL in (85,86,87,88,89) then t1.kol_usl else 1 end else 0 end), 0) as int) as 'R_KOL'
			--,sum(case when t1.[type]='oms' then 1 else 0 end) as 'R_KOL'
			--,sum(case when t1.[type]='oms' then t1.SUMPS else 0 end) as 'R_S_KOL' OLDWAY2
			--NEWWAY 2
			,(case when t1.CODE_MO ='400001' and t1.PROFIL not in (85,86,87,88,89) and t1.PROFIL in (select PROFIL from #TEMP_3P group by PROFIL  ) 
				   then (select [sum] from #TEMP_3P  where t1.PROFIL = PROFIL)  +  
								sum(case when t1.[type]='oms' and podush = 0 then t1.SUMPS else 0 end)
		--OLDWAY2
			else sum(case when t1.[type]='oms' then t1.SUMPS else 0 end) end ) as 'R_S_KOL'
			--,(select count(*) from #mtrCount3 c3 where c3.PROFIL=t1.PROFIL) as 'R_KOL_M'
			,sum(case when t1.[type]='mtr' then 1 else 0 end) as 'R_KOL_M'
			,sum(case when t1.[type]='mtr' then t1.SUMPS else 0 end) as 'R_S_KOL_M'
	   from #Sluchs t1
	   where t1.CODE_MO=t100.CODE_MO and 
		(exists(select * from ies.T_SCHET_USL su
			cross apply(select top 1 ut.ID as UTYPE from IES.R_NSI_USL_V001 spr
						inner JOIN IES.T_SPR_USL_TYPE_NAME ut ON ut.DictionaryBaseID = spr.USLTYPE  where spr.CODE_USL=su.CODE_USL) r
			where su.SchetSluch=t1.SchetSluchID and r.UTYPE IN (26,27))
			--or t1.CODE_MO IN ('400001') and exists(select * from ies.T_SCHET_USL su
			--cross apply(select top 1 spr.UTYPE from ies.T_SPR_USL_TYPE spr where spr.UCODE=su.CODE_USL) r
			--where su.SchetSluch=t1.SchetSluchID and r.UTYPE in (7,8))
			)
	   group by t1.PROFIL,t1.CODE_MO
	   order by t1.PROFIL
	   for xml path('PR_SV'),type
	   ) 
from #Sluchs frst
	   where frst.CODE_MO=t100.CODE_MO and 
		(exists(select * from ies.T_SCHET_USL su
			cross apply(select top 1 ut.ID as UTYPE from IES.R_NSI_USL_V001 spr
						inner JOIN IES.T_SPR_USL_TYPE_NAME ut ON ut.DictionaryBaseID = spr.USLTYPE  where spr.CODE_USL=su.CODE_USL) r
			where su.SchetSluch=frst.SchetSluchID and r.UTYPE IN (26,27))
			--or frst.CODE_MO IN ('400001') and exists(select * from ies.T_SCHET_USL su
			--cross apply(select top 1 spr.UTYPE from ies.T_SPR_USL_TYPE spr where spr.UCODE=su.CODE_USL) r
			--where su.SchetSluch=frst.SchetSluchID and r.UTYPE in (7,8))
			)
for xml path('IT_SV'),type)


-------------4
,(select top 1
	  4 as 'OT_NAIM'
	 ,(select
			 t1.PROFIL as 'PROFIL_MP'
			,cast((case
				when exists(select * from #Sluchs ss where ss.OPLATA<>5 and [type]='oms' and ss.SUMPS>0 and ss.PROFIL=t1.PROFIL)
				then isnull((select sum(ss.ED_COL) from #Sluchs ss where ss.OPLATA<>5 and [type]='oms' and ss.SUMVS>0 and ss.PROFIL=t1.PROFIL and ss.USL_OK=2),0) else 0 end 
					+
				   case
				when  exists(select * from #Sluchs ss where ss.OPLATA<>5 and [type]='oms' and ss.SUMPS>0 and ss.PROFIL=t1.PROFIL)
				then isnull((select sum(su.ED_COL_R) from #Usls su where su.USL_OK=2 and su.type_ = 'oms' and su.PROFIL=t1.PROFIL),0) else 0 end 
					+
				   case
				when exists(select * from #Sluchs ss where ss.OPLATA=5 and [type]='oms' and ss.SUMPS>0 and ss.PROFIL=t1.PROFIL)
				then isnull((select sum(ss.KD_Z) from #Sluchs ss where ss.SchetSluchID=(select top 1 ss2.SchetSluchID from #Sluchs ss2 
																					where ss2.SchetSluchAccomplishedID=ss.SchetSluchAccomplishedID and ss2.PROFIL=t1.PROFIL and ss2.USL_OK=2)),0) else 0 end

				) as int) as 'R_KOL'
			--,sum(case when t1.[type]='oms' then t1.SUMPS else 0 end) as 'R_S_KOL'
			,0  as 'R_S_KOL'
			,cast((case
				when exists(select * from #Sluchs ss where ss.OPLATA<>5 and [type]='mtr' and ss.SUMPS>0 and ss.PROFIL=t1.PROFIL)
				then isnull((select sum(ss.ED_COL) from #Sluchs ss where ss.OPLATA<>5 and [type]='mtr' and ss.SUMVS>0 and ss.PROFIL=t1.PROFIL and ss.USL_OK=2),0) else 0 end 
					+
				   case
				when  exists(select * from #Sluchs ss where ss.OPLATA<>5 and [type]='mtr' and ss.SUMPS>0 and ss.PROFIL=t1.PROFIL)
				then isnull((select sum(su.ED_COL_R) from #Usls su where su.USL_OK=2 and su.type_ = 'mtr' and su.PROFIL=t1.PROFIL),0) else 0 end 
					+
				   case
				when exists(select * from #Sluchs ss where ss.OPLATA=5 and [type]='mtr' and ss.SUMPS>0 and ss.PROFIL=t1.PROFIL)
				then isnull((select sum(ss.KD_Z) from #Sluchs ss where ss.SchetSluchID=(select top 1 ss2.SchetSluchID from #Sluchs ss2 
																					where ss2.SchetSluchAccomplishedID=ss.SchetSluchAccomplishedID and ss2.PROFIL=t1.PROFIL and ss2.USL_OK=2)),0) else 0 end

				) as int) as 'R_KOL_M'
			--,sum(case when t1.[type]='mtr' then t1.SUMPS else 0 end) as 'R_S_KOL_M'
			,0 as 'R_S_KOL_M'
	   from #Sluchs t1
	   where t1.CODE_MO=t100.CODE_MO and 
		t1.USL_OK=2
	   group by t1.PROFIL
	   order by t1.PROFIL
	   for xml path('PR_SV'),type
	   ) 
from #Sluchs frst
	   where frst.CODE_MO=t100.CODE_MO and 
		USL_OK=2
for xml path('IT_SV'),type)


-------------------------5
,(select top 1
	  5 as 'OT_NAIM'
	 ,(select
			 t1.PROFIL as 'PROFIL_MP'
			,sum(case when t1.[type]='oms' then 1 else 0 end) as 'R_KOL'
			,sum(case when t1.[type]='oms' then t1.SUMPS else 0 end) as 'R_S_KOL'
			,sum(case when t1.[type]='mtr' then 1 else 0 end) as 'R_KOL_M'
			,sum(case when t1.[type]='mtr' then t1.SUMPS else 0 end) as 'R_S_KOL_M'
	   from #Sluchs t1
	   where t1.CODE_MO=t100.CODE_MO and 
		t1.USL_OK=2
	   group by t1.PROFIL
	   order by t1.PROFIL
	   for xml path('PR_SV'),type
	   ) 
from #Sluchs frst
	   where frst.CODE_MO=t100.CODE_MO and 
		frst.USL_OK=2
for xml path('IT_SV'),type)


--------------------------8
,(select top 1
	  8 as 'OT_NAIM'
	 ,(select
			 t1.PROFIL as 'PROFIL_MP'
			,cast(sum(case when t1.[type]='oms' then t1.KD_Z else 0 end) as int) as 'R_KOL'
			--,sum(case when t1.[type]='oms' then t1.SUMPS else 0 end) as 'R_S_KOL'
			,0 as 'R_S_KOL'
			,cast(sum(case when t1.[type]='mtr' then t1.KD_Z else 0 end) as int) as 'R_KOL_M'
			--,sum(case when t1.[type]='mtr' then t1.SUMPS else 0 end) as 'R_S_KOL_M'
			,0 as 'R_S_KOL_M'
	   from #Sluchs t1
	   where t1.CODE_MO=t100.CODE_MO and 
		t1.USL_OK=1
	   group by t1.PROFIL
	   order by t1.PROFIL
	   for xml path('PR_SV'),type
	   ) 
from #Sluchs frst
	   where frst.CODE_MO=t100.CODE_MO and 
		frst.USL_OK=1
for xml path('IT_SV'),type)

--------------------------9
,(select top 1
	  9 as 'OT_NAIM'
	 ,(select
			 t1.PROFIL as 'PROFIL_MP'
			,sum(case when t1.[type]='oms' then 1 else 0 end) as 'R_KOL'
			,sum(case when t1.[type]='oms' then t1.SUMPS else 0 end) as 'R_S_KOL'
			,sum(case when t1.[type]='mtr' then 1 else 0 end) as 'R_KOL_M'
			,sum(case when t1.[type]='mtr' then t1.SUMPS else 0 end) as 'R_S_KOL_M'
	   from #Sluchs t1
	   where t1.CODE_MO=t100.CODE_MO and 
		t1.USL_OK=1
	   group by t1.PROFIL
	   order by t1.PROFIL
	   for xml path('PR_SV'),type
	   ) 
from #Sluchs frst
	   where frst.CODE_MO=t100.CODE_MO and 
		frst.USL_OK=1
for xml path('IT_SV'),type)


--------------------------10
,(select top 1
	  10 as 'OT_NAIM'
	 ,(select
			 t1.PROFIL as 'PROFIL_MP'
			,cast(sum(case when t1.[type]='oms' then t1.KD_Z else 0 end) as int) as 'R_KOL'
			--,sum(case when t1.[type]='oms' then t1.SUMPS else 0 end) as 'R_S_KOL'
			,0 as 'R_S_KOL'
			,cast(sum(case when t1.[type]='mtr' then t1.KD_Z else 0 end) as int) as 'R_KOL_M'
			--,sum(case when t1.[type]='mtr' then t1.SUMPS else 0 end) as 'R_S_KOL_M'
			,0 as 'R_S_KOL_M'
	   from #Sluchs t1
	   where t1.CODE_MO=t100.CODE_MO and 
		t1.VIDPOM=32
	   group by t1.PROFIL
	   order by t1.PROFIL
	   for xml path('PR_SV'),type
	   ) 
from #Sluchs frst
	   where frst.CODE_MO=t100.CODE_MO and 
		frst.VIDPOM=32
for xml path('IT_SV'),type)

--------------------------11
,(select top 1
	  11 as 'OT_NAIM'
	 ,(select
			 t1.PROFIL as 'PROFIL_MP'
			,sum(case when t1.[type]='oms' then 1 else 0 end) as 'R_KOL'
			,sum(case when t1.[type]='oms' then t1.SUMPS else 0 end) as 'R_S_KOL'
			,sum(case when t1.[type]='mtr' then 1 else 0 end) as 'R_KOL_M'
			,sum(case when t1.[type]='mtr' then t1.SUMPS else 0 end) as 'R_S_KOL_M'
	   from #Sluchs t1
	   where t1.CODE_MO=t100.CODE_MO and 
		t1.VIDPOM=32
	   group by t1.PROFIL
	   order by t1.PROFIL
	   for xml path('PR_SV'),type
	   ) 
from #Sluchs frst
	   where frst.CODE_MO=t100.CODE_MO and 
		frst.VIDPOM=32
for xml path('IT_SV'),type)

--------------------------12
,(select top 1
	  12 as 'OT_NAIM'
	 ,(select
			 t1.PROFIL as 'PROFIL_MP'
			 ,cast(round(sum(case when t1.[type]='oms' then case when t1.PROFIL in (85,86,87,88,89) then t1.kol_usl else 1 end else 0 end), 0) as int) as 'R_KOL'
			--,sum(case when t1.[type]='oms' then 1 else 0 end) as 'R_KOL'
			,(case when t1.CODE_MO ='400001' and t1.PROFIL not in (85,86,87,88,89) and t1.PROFIL in (select PROFIL from #TEMP_12P group by PROFIL  ) 
			       then (select [sum] from #TEMP_12P  where t1.PROFIL = PROFIL)  +  
				              sum(case when t1.[type]='oms' and podush = 0 then t1.SUMPS else 0 end)
		--OLDWAY2
			else sum(case when t1.[type]='oms' then t1.SUMPS else 0 end) end ) as 'R_S_KOL'
			,sum(case when t1.[type]='mtr' then 1 else 0 end) as 'R_KOL_M'
			,sum(case when t1.[type]='mtr' then t1.SUMPS else 0 end) as 'R_S_KOL_M'
	   from #Sluchs t1
	   where t1.CODE_MO=t100.CODE_MO and 
		t1.USL_OK=4
		and exists(select * from ies.T_SCHET_USL su
			cross apply(select top 1 ut.ID as UTYPE from IES.R_NSI_USL_V001 spr
						inner JOIN IES.T_SPR_USL_TYPE_NAME ut ON ut.DictionaryBaseID = spr.USLTYPE  where spr.CODE_USL=su.CODE_USL) r
			where su.SchetSluch=frst.SchetSluchID and r.UTYPE in (9))
		and t1.VIDPOM<>13
	   group by t1.PROFIL, t1.CODE_MO
	   order by t1.PROFIL
	   for xml path('PR_SV'),type
	   ) 
from #Sluchs frst
	   where frst.CODE_MO=t100.CODE_MO and 
		frst.USL_OK=4

		and exists(select * from ies.T_SCHET_USL su
			cross apply(select top 1 ut.ID as UTYPE from IES.R_NSI_USL_V001 spr
						inner JOIN IES.T_SPR_USL_TYPE_NAME ut ON ut.DictionaryBaseID = spr.USLTYPE  where spr.CODE_USL=su.CODE_USL) r
			where su.SchetSluch=frst.SchetSluchID and r.UTYPE in (9))
		and frst.VIDPOM<>13
for xml path('IT_SV'),type)

from #Sluchs t100 where MoNumber=1
for xml path('OB_SV'),type)

------------------------------ZAP------------------------------------------------------

----oms
,(select
	 row_number() over(order by s.FAM, s.IM, s.OT, s.DR) as 'N_ZAP'
	--,isnull(s.TF_OKATO, (select top 1 ia.TfomsCode from ies.T_INSURANCE_AFFILATIION ia where ia.SchetZap=s.SchetZapID order by BeginDate desc)) as 'PACIENT/SMO_OK'
	,case when len(s.TF_OKATO)>1 then s.TF_OKATO else (select top 1 ia.TfomsCode from ies.T_INSURANCE_AFFILATIION ia where ia.SchetZap=s.SchetZapID order by BeginDate desc) end as 'PACIENT/SMO_OK'
	,w as 'PACIENT/W'
	,DATEDIFF(year, DR, DATE_1) as 'PACIENT/VZST'
	,(select
			 s.IDCASE as 'IDCASE'
			,s.USL_OK as 'USL_OK'
			,CASE WHEN (s.USL_OK = 3 AND s.VIDPOM = 31) THEN 13
			      WHEN (s.USL_OK = 3 AND s.VIDPOM = 21) THEN 12
			 ELSE s.VIDPOM end as 'VIDPOM'
			,s.FOR_POM as 'FOR_POM'
			,case when s.COMENTSL like '11%' then 1 when s.COMENTSL like '2%' then 2 else 0 end as 'PCEL'
			,s.VID_HMP as 'VID_HMP'
			,(select IDHM from ies.T_V019_VMP_METHOD v19 where s.METOD_HMP = v19.V019VmpMethodID)  as 'METOD_HMP'
			,s.LPU as 'LPU'
			,s.PROFIL as 'PROFIL'
			,isnull(cast(((case when s.USL_OK<>3 and s.OPLATA=5 then s.KD_Z else 0 end) + (case when s.USL_OK<>3 and s.OPLATA<>5 then s.ED_COL else 0 end) + 
			(case when s.USL_OK=3 then (select count(*) from #Sluchs t1 where t1.SchetSluchAccomplishedID=s.SchetSluchAccomplishedID) else 0 end)) as int),0) as 'DATE_I'
			,SUMP as 'SUM'
	  for xml path('SLUCH'),type)
  from #Sluchs s
where s.[type] = 'oms' and s.Number=1
for xml path('ZAP'),type)

----mtr
,(select
	 row_number() over(order by s.FAM, s.IM, s.OT, s.DR) + @omsCount as 'N_ZAP'
	,isnull((case when len(s.TF_OKATO)>1 then s.TF_OKATO else (select top 1 ia.TfomsCode from ies.T_INSURANCE_AFFILATIION ia where ia.SchetZap=s.SchetZapID order by BeginDate desc) end),'29000') as 'PACIENT/SMO_OK'
	,w as 'PACIENT/W'
	,DATEDIFF(year, DR, DATE_1) as 'PACIENT/VZST'
	,(select
			 s.IDCASE as 'IDCASE'
			 --,s.SchetSluchID as 'SchetSluchID'
			,s.USL_OK as 'USL_OK'
			,CASE WHEN (s.USL_OK = 3 AND s.VIDPOM = 31) THEN 13
			      WHEN (s.USL_OK = 3 AND s.VIDPOM = 21) THEN 12
			 ELSE s.VIDPOM end as 'VIDPOM'
			,s.FOR_POM as 'FOR_POM'
			,case when s.COMENTSL like '11%' then 1 when s.COMENTSL like '2%' then 2 else 0 end as 'PCEL'
			,s.VID_HMP as 'VID_HMP'
			,(select IDHM from ies.T_V019_VMP_METHOD v19 where s.METOD_HMP = v19.V019VmpMethodID) as 'METOD_HMP'
			,s.LPU as 'LPU'
			,s.PROFIL as 'PROFIL'
			,isnull(cast(((case when s.USL_OK<>3 and s.OPLATA=5 then s.KD_Z else 0 end) + (case when s.USL_OK<>3 and s.OPLATA<>5 then s.ED_COL else 0 end) + 
			(case when s.USL_OK=3 then (select count(*) from #Sluchs t1 where t1.SchetSluchAccomplishedID=s.SchetSluchAccomplishedID) else 0 end)) as int),0) as 'DATE_I'
			,SUMP as 'SUM'
	  for xml path('SLUCH'),type)
  from #Sluchs s
where s.[type] = 'mtr' and s.Number=1
for xml path('ZAP'),type)


for xml path(''),ROOT ('ISP_OB'))

--drop table #FinalTabled
drop table #Sluchs
drop table #Usls
drop table #omsCount3
drop table #mtrCount3
drop table #TEMP_1P
drop table #TEMP_3P
drop table #TEMP_12P
END