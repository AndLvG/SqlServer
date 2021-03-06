USE [IESDB]
GO
/****** Object:  StoredProcedure [dbo].[sp_Get260Decree]    Script Date: 20.01.2020 8:22:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[sp_Get260Decree](@month [int], @year [int],@isVmp bit,@filename varchar(2000), @FileNameout varchar(max) out, @ret varchar(max) out, @ret1 varchar(max) out )
as
begin

-----------------------param
declare @type varchar(6)
if (@isVmp=1)
begin
set @type='T%'
end
else 
begin
set @type='C%'
end

------------check unload
if (exists(select * from ies.T_SCHET s
	join ies.R_NSI_LIST_OF_ORDERS l on (s.Order260Id=l.DictionaryBaseId)
	where s.Order260Id is not null and l.OrderMonth=@month and l.OrderYear=@year and 
(case when @isVmp=1 then 'T файлы' else 'C файлы' end) = l.RComment
) and @year>2018)
begin
	raiserror('За этот месяц приказ уже выгружен, удалите старую запись!',18,1) return
end

-----------------------select
select
ss.SchetSluchID,ss.VID_HMP,ss.METOD_HMP,ss.lpu_1,ss.PODR,ss.PROFIL,ss.PROFIL_K,ss.DET,ss.TAL_D,ss.TAL_NUM,ss.TAL_P,ss.NHISTORY,ss.DATE_1,ss.DATE_2,ss.DS0,ss.DS1,ss.C_ZAB,ss.DS_ONK,
ss.CODE_MES1,ss.CODE_MES2,ss.PRVS,ss.VERS_SPEC,ss.IDDOKT,ss.ED_COL,ss.TARIF,ss.SUMV,ss.sump,ss.COMENTSL,s.SchetID,ss.SANK_MEK,ss.SANK_MEE,ss.SANK_EKMP,ss.SchetSluchAccomplished,sz.SchetZapID
into #sluchs
from [IES].T_SCHET_SLUCH ss 
	join ies.T_SCHET_ZAP sz on (sz.SchetZapID = ss.SchetZap)
	join ies.T_SCHET s on (s.SchetID=sz.Schet)
	join ies.T_SCHET_SLUCH_ACCOMPLISHED ssa on (ss.SchetSluchAccomplished=ssa.SchetSluchAccomplishedID)
--	join ies.T_REESTR_CLOSE_INFO rci on (s.SchetID=rci.Schet)--закрытые
	where s.YEAR=@year and s.type_ in (693,554) and (ss.DS1 like 'D0%' or ss.DS1 like 'C%') and s.FILENAME like @type
	and ss.SUMP>0 and isnull(ss.SANK_IT,0)=0 and  isnull(ssa.SANK_IT,0)=0
--	and (s.MONTH=@month or (s.month < @month and s.MONTH>=(case when @month<4 then 1 else @month-3 end) and s.Order260Id is null))
--    and month(ssa.DATE_Z_2)=@month and year(ssa.DATE_Z_2)=@year
--    and s.Order260Id is null
	and not exists (select 1 from [my_base].[dbo].[LOADED_260] a 
	                where a.CODE=s.CODE
					  and a.CODE_MO = s.CODE_MO
					  and a.DSCHET = s.DSCHET
					  and a.NSCHET = s.NSCHET
					  and a.IDCASE = ssa.IDCASE
					  and a.SL_ID = ss.SL_ID)
	
	and ssa.USL_OK in (1,2,3) and ss.DATE_2>='20190101' and s.[Status] =1

-----------------------------------Заполение таблички с выгруженными приказами
if ((select count(*) from #sluchs)>0)
begin
insert into ies.R_NSI_LIST_OF_ORDERS ([OrderType],[OrderDate],[DictionaryBaseId],[RComment],[OrderMonth],[OrderYear])
select '260',getdate(),newid(),case when @isVmp=1 then 'T файлы' else 'C файлы' end, @month, @year

insert into IES.T_DICTIONARY_BASE([DictionaryBaseID],[type_]) 
select top 1 [DictionaryBaseID],9030
from ies.R_NSI_LIST_OF_ORDERS where [OrderType]='260'
order by [OrderDate] desc

---------------------------------апдейт Order260Id на счете
update ies.T_SCHET set Order260Id=(select top 1 [DictionaryBaseID] from ies.R_NSI_LIST_OF_ORDERS where [OrderType]='260' order by [OrderDate] desc)
where SchetID in (select distinct s.SchetID from #sluchs s)

end
-----счетчик
update ies.[R_NSI_GLOBAL_SETTINGS] set order260num = order260num + 1
declare @num int = (select top 1 order260num from ies.[R_NSI_GLOBAL_SETTINGS])

---------------------------------генерация FILENAME //added 02.12.2019
--declare @filename varchar(2000)
select @filename = 
case 
	when len(@filename) > 0	
	then @filename
	else ((case when @isVmp=1 then 'TT' else 'CT' end)+(select top 1 c.Tfoms from ies.T_COMPANY c join ies.T_COMPANY_SETTINGS cs on (c.CompanyID=cs.Company))
	  +'_'+substring(cast(@year as varchar(4)),3,2)+format(@month,'00')+cast(@num as varchar(5)))--(case when @isVmp=1 then '3' else '4' end))
end 

-----------------------ret1
select @ret = (select 

--ZGLV
'3.1' AS 'ZGLV/VERSION' 
, CONVERT(VARCHAR(10), GETDATE(), 126) AS 'ZGLV/DATA'
/*
, (case when @isVmp=1 then 'TT' else 'CT' end)+(select top 1 c.Tfoms from ies.T_COMPANY c join ies.T_COMPANY_SETTINGS cs on (c.CompanyID=cs.Company))
	+'_'+substring(cast(@year as varchar(4)),3,2)+format(@month,'00')+(case when @isVmp=1 then '1' else '2' end) AS 'ZGLV/FILENAME'
	*/
,@filename AS 'ZGLV/FILENAME'
/*
, (select COUNT(*) 
	from [IES].T_SCHET_ZAP sz
	join [IES].T_SCHET_SLUCH ss on (sz.SchetZapID = ss.SchetZap)
	join ies.T_SCHET s on (s.SchetID=sz.Schet)
	join ies.T_SCHET_SLUCH_ACCOMPLISHED ssa on (ss.SchetSluchAccomplished=ssa.SchetSluchAccomplishedID)
	where s.YEAR=@year and s.MONTH=@month and s.type_ in (693,554) and (ss.DS1 like 'D0%' or ss.DS1 like 'C%') and s.FILENAME like @type)
	AS 'ZGLV/SD_Z'
*/
, (select COUNT(*) 
	from  (select distinct SchetZapID from #sluchs) a) AS 'ZGLV/SD_Z'

,(select
--SCHET
t1.CODE AS 'CODE'
,t1.CODE_MO AS 'CODE_MO'
,t1.[YEAR] AS 'YEAR'
--,t1.[MONTH] AS 'MONTH'
, @month AS 'MONTH'
,t1.NSCHET AS 'NSCHET'
,CONVERT(VARCHAR(10), t1.DSCHET, 126) AS 'DSCHET'
,t1.PLAT AS 'PLAT'
--,t1.SUMV 'SUMMAV'
,(select sum(ss.SUMP) from #sluchs ss where ss.SchetID=t1.SchetID)  AS 'SUMMAV'
,t1.COMENTS  AS 'COMENTS'
--,t1.SUMP AS 'SUMMAP'
,(select sum(ss.SUMP) from #sluchs ss where ss.SchetID=t1.SchetID)  AS 'SUMMAP'
--,t1.SANK_MEK AS 'SANK_MEK'
--,t1.SANK_MEE  AS 'SANK_MEE'
--,t1.SANK_EKMP  AS 'SANK_EKMP'
,(select sum(ss.SANK_MEK) from #sluchs ss where ss.SchetID=t1.SchetID)  AS 'SANK_MEK'
,(select sum(ss.SANK_MEE) from #sluchs ss where ss.SchetID=t1.SchetID)  AS 'SANK_MEE'
,(select sum(ss.SANK_EKMP) from #sluchs ss where ss.SchetID=t1.SchetID)  AS 'SANK_EKMP'

--ZAP
,( 
	SELECT 
	    t2.N_ZAP	AS 'N_ZAP'
		,t2.PR_NOV	AS 'PR_NOV'    
	   
	   -- PACIENT
	    ,t2.SchetZapID AS 'PACIENT/ID_PAC'
	    ,t2.VPOLIS AS 'PACIENT/VPOLIS'
	    ,t2.SPOLIS AS 'PACIENT/SPOLIS'
	    ,t2.NPOLIS AS 'PACIENT/NPOLIS'
	    --,t2.ST_OKATO AS 'PACIENT/ST_OKATO'
	    ,t2.SMO_OK AS 'PACIENT/ST_OKATO'
--	    ,t2.SMO AS 'PACIENT/SMO'
		,t1.PLAT AS 'PACIENT/SMO'
		,t2.SMO_OGRN AS 'PACIENT/SMO_OGRN'
		,t2.SMO_OK AS 'PACIENT/SMO_OK'
		,t2.SMO_NAM AS 'PACIENT/SMO_NAM'
		,case when @isVmp=1 then null else t2.INV end AS 'PACIENT/INV'
		,t2.MSE as 'PACIENT/MSE'
--		,t2.NOVOR AS 'PACIENT/NOVOR'
		,0 AS 'PACIENT/NOVOR'
--		,case when t2.NOVOR=0 then null else t2.VNOV_D end AS 'PACIENT/VNOV_D'
	   
	   --Z_SLUCH
	   ,(
			SELECT
				ssa.IDCASE as 'IDCASE'
				,ssa.USL_OK AS 'USL_OK'
				,ssa.VIDPOM AS 'VIDPOM'
				,ssa.FOR_POM AS 'FOR_POM'
				,case when ssa.NPR_MO=ssa.LPU then case when ssa.LPU='400003' then '400006' else '400003' end else ssa.NPR_MO end AS 'NPR_MO'
--				,case when ssa.NPR_MO != ssa.LPU or @type='T%' then CONVERT(VARCHAR(10),ssa.NPR_DATE,126) else null end AS 'NPR_DATE'
--				,ssa.NPR_MO AS 'NPR_MO'
				,case when ssa.NPR_MO is not null then CONVERT(VARCHAR(10),ssa.NPR_DATE,126) else null end AS 'NPR_DATE'
				,ssa.LPU AS 'LPU'
				,CONVERT(VARCHAR(10),ssa.DATE_Z_1,126) AS 'DATE_Z_1'
				,CONVERT(VARCHAR(10),ssa.DATE_Z_2,126) AS 'DATE_Z_2'
				,ssa.KD_Z AS 'KD_Z'
				,ssa.VNOV_M as 'VNOV_M'
				,ssa.RSLT AS 'RSLT'
				,ssa.ISHOD AS 'ISHOD'
				,case when ssa.OS_SLUCH='' then null else ssa.OS_SLUCH end AS 'OS_SLUCH'
				,(case when @isVmp = 1 then null else ssa.VB_P end) AS 'VB_P'
			   ,(
					SELECT 
						t3.SL_ID as 'SL_ID'
						,(case when @isVmp=1 then t3.VID_HMP else null end) as 'VID_HMP'
						,(case when @isVmp=1 then t3.METOD_HMP else null end) as 'METOD_HMP'
						--,t3.LPU_1 AS 'LPU_1'
						,t3.PODR AS 'PODR'
						,t3.PROFIL AS 'PROFIL'
						,(select top 1 v020.IDK_PR from ies.T_V020_BED_PROFILE v020 where v020.V020BedProfileID=t3.PROFIL_K) AS 'PROFIL_K'
						,t3.DET AS 'DET'
						,(case when @isVmp=1 then CONVERT(VARCHAR(10),t3.TAL_D,126) else null end) as 'TAL_D'
						,(case when @isVmp=1 then t3.TAL_NUM else null end) as 'TAL_NUM'
						,(case when @isVmp=1 then CONVERT(VARCHAR(10),t3.TAL_P,126) else null end) as 'TAL_P'
						,(case when @isVmp=1 then null else (select top 1 v025.IDPC from ies.T_V025_KPC v025 where v025.V025KpcID=t3.P_CEL) end) AS 'P_CEL'
						,t3.NHISTORY AS 'NHISTORY'
						,(case when @isVmp=1 then null else t3.P_PER end) AS 'P_PER'
						,CONVERT(VARCHAR(10),t3.DATE_1,126) AS 'DATE_1'
						,CONVERT(VARCHAR(10),t3.DATE_2,126) AS 'DATE_2'
						,(case when @isVmp=1 then null else t3.KD end) AS 'KD'
						,t3.DS0 AS 'DS0'
						,t3.DS1 AS 'DS1'
						,case when (t1.DISP is null) then t3.DS2 else null end AS 'DS2'
						,t3.PR_D_N AS 'PR_D_N'
						,(case when (t1.DISP is null) then(
							SELECT t4.MKB	AS 'DS2'
							FROM [IES].T_SCHET_SLUCH_DS t4
							WHERE t4.SchetSluch = t3.SchetSluchID and t4.MKBType = 0
							FOR
							XML PATH(''),
							TYPE
						)
						else 
						( 
							SELECT t4.MKB AS 'DS2'
							, t4.DS2_PR as 'DS2_PR'
							, t4.PR_DS2_N as 'PR_DS2_N'
							FROM [IES].T_SCHET_SLUCH_DS t4
							WHERE t4.SchetSluch = t3.SchetSluchID and t4.MKBType = 0
							FOR
							XML PATH('DS2_N'),
							TYPE
						) 
						end)
						,( 
							SELECT t4.MKB	AS 'DS3'
							FROM [IES].T_SCHET_SLUCH_DS t4
							WHERE t4.SchetSluch = t3.SchetSluchID and t4.MKBType = 1
							FOR
							XML PATH(''),
							TYPE
						)
						,(select top 1 v027.IDCZ from ies.T_V027_C_ZAB v027 where v027.V027CZabID=t3.C_ZAB) as 'C_ZAB'
						,t3.DS_ONK as 'DS_ONK'
						,t3.DN as 'DN'
						,t3.CODE_MES1 AS 'CODE_MES1'
						,t3.CODE_MES2 AS 'CODE_MES2'
						----------------------------------------------------260new
						,(
							SELECT
								CONVERT(VARCHAR(10), napr.NAPR_DATE, 126) as 'NAPR_DATE'
								,napr.NAPR_MO as 'NAPR_MO'
								,napr.NAPR_V as 'NAPR_V'
								,napr.MET_ISSL as 'MET_ISSL'
								,napr.NAPR_USL as 'NAPR_USL'
							FROM [IES].[T_SCHET_USL_NAPR] napr
							WHERE napr.SchetSluch = t3.SchetSluchID and napr.NAPR_MO != t3.LPU

							FOR
							XML PATH('NAPR'),
							TYPE
						)
						,(
							SELECT
								(select top 1 ID_CONS from ies.T_N019_ONK_CONS n019 where n019.N019OnkConsID = cons.N019OnkCons) as 'PR_CONS'
								--,CONVERT(VARCHAR(10), cons.DT_CONS, 126) as 'DT_CONS'
								,(case when (select top 1 ID_CONS from ies.T_N019_ONK_CONS n019 where n019.N019OnkConsID = cons.N019OnkCons) = 0
										then null
										else 
										  case when cons.DT_CONS < ss.DATE_1 then  CONVERT(VARCHAR(10), ss.DATE_1, 126)
										       when cons.DT_CONS > ss.DATE_2 then  CONVERT(VARCHAR(10), ss.DATE_2, 126)
											                                  else CONVERT(VARCHAR(10), cons.DT_CONS, 126) end 
							             end) as 'DT_CONS'
							FROM [IES].[T_SCHET_SLUCH_CONS] cons
							WHERE cons.SchetSluch = t3.SchetSluchID -- and cons.DT_CONS>=t3.DATE_1

							FOR
							XML PATH('CONS'),
							TYPE
						)
						,(
							SELECT 
							(select top 1 ID_REAS  from [IES].[T_N018_ONK_REAS]  where onk.DS1_T = [N018OnkReasID]  ) as 'DS1_T',
							(select top 1 ID_st  from [IES].[T_N002_STADIUM]  where onk.STAD = [N002StadiumID]  ) as 'STAD',
							(select top 1 ID_T  from [IES].[T_N003_TUMOR]  where onk.ONK_T = [N003TumorID]  ) as 'ONK_T',
							(select top 1 ID_N from [IES].[T_N004_NODUS]  where onk.ONK_N = [N004NodusID] ) as 'ONK_N',
							(select top 1 ID_M  from [IES].[T_N005_METASTASIS]  where onk.ONK_M = [N005MetastasisID] ) as 'ONK_M',
							onk.MTSTZ as 'MTSTZ'
							,onk.SOD as 'SOD'
							,onk.K_FR as 'K_FR'
							,onk.WEI as 'WEI'
							,onk.HEI as 'HEI'
							,onk.BSA as 'BSA'
							
							
								--B_DIAG
								,(
									SELECT
										 CONVERT(VARCHAR(10),onkDiagSL.DIAG_DATE,126) as 'DIAG_DATE'
										,onkDiagSL.DIAG_TIP as 'DIAG_TIP'
										,onkDiagSL.DIAG_CODE as 'DIAG_CODE'
										,onkDiagSL.DIAG_RSLT as 'DIAG_RSLT'
										,onkDiagSL.REC_RSLT as 'REC_RSLT'
									FROM [IES].T_SCHET_SLUCH_ONK_DIAG onkDiagSL
									where onkDiagSL.SchetSluchOnk = onk.SchetSluchOnkID

									FOR
									XML PATH('B_DIAG'),
									TYPE
								)
								,(--B_PROT
									SELECT
										(select top 1 n001.ID_PrOt from ies.T_N001_PrOt n001 where n001.N001PrOtID = onkProtSL.PROT) as 'PROT'
										,CONVERT(VARCHAR(10),onkProtSL.D_PROT,126) as 'D_PROT'
									FROM [IES].T_SCHET_SLUCH_ONK_PROT onkProtSL
									where onkProtSL.SchetSluchOnk = onk.SchetSluchOnkID

									FOR
									XML PATH('B_PROT'),
									TYPE
								)
								,(  
									SELECT 
									--suo.PR_CONS as 'PR_CONS',
									(select top 1 ID_TLech  from [IES].[T_N013_TREAT_TYPE]  where suo.USL_TIP = [N013TreatTypeID]  ) as 'USL_TIP',
									(select top 1 [ID_THir]  from [IES].[T_N014_SURG_TREAT]  where suo.HIR_TIP = [N014SurgTreatID]  ) as 'HIR_TIP',
									(select top 1 ID_TLek_L  from [IES].[T_N015_DRUG_THERAPY_LINES]  where suo.LEK_TIP_L = [N015DrugTherapyLinesID]  ) as 'LEK_TIP_L',
									(select top 1 ID_TLek_V from [IES].[T_N016_DRUG_THERAPY_CYCLES]  where suo.LEK_TIP_V = [N016DrugTherapyCyclesID]  ) as 'LEK_TIP_V',
									(
										SELECT 
										(select top 1 n020.ID_LEKP from ies.T_N020_ONK_LEKP n020 where n020.N020OnkLekpID=lek.REGNUM) as 'REGNUM'
										,(select top 1 v024.IDDKK from ies.T_V024_DOP_KR v024 where lek.V024DopKr=v024.V024DopKrID) as 'CODE_SH'
										,(
											select distinct case  when lekd.DATE_INJ > ss.DATE_2 then convert(varchar(10), ss.DATE_2,126) 
											          else convert(varchar(10), lekd.DATE_INJ,126) end as 'DATE_INJ'
											from ies.T_SCHET_USL_ONK_LEK_PR_DATE	lekd	
											where lekd.SchetUslOnkLekPr=lek.SchetUslOnkLekPrID		
											FOR
											XML PATH(''),
											TYPE
										) 
										FROM ies.T_SCHET_USL_ONK_LEK_PR lek
										where lek.SchetUslOnk = suo.SchetUslOnkID and lek.REGNUM is not null
										FOR
										XML PATH('LEK_PR'),
										TYPE
									)
									,(select top 1 n017.ID_TLuch from [IES].[T_N017_RADIATION_THERAPY_TYPES] n017  where suo.LUCH_TIP = n017.[N017RadiationTherapyTypesID]  ) as 'LUCH_TIP'
									FROM [IES].[T_SCHET_USL_ONK] suo with(nolock) 		
									WHERE onk.SchetSluchOnkID = suo.SchetSluchOnk 
									FOR
									XML PATH('ONK_USL'),
									TYPE
								)
								 
							FROM IES.T_SCHET_SLUCH_ONK onk
							where onk.SchetSluch = t3.SchetSluchID
							FOR
							XML PATH('ONK_SL'),
							TYPE
						)	
						,(
							SELECT
								 N_KSG as 'N_KSG'
								,'2019' as 'VER_KSG'
								,ksg.KSG_PG as 'KSG_PG'
								,(select top 1 K_KPG from [IES].T_V026_KPG where V026KpgID = ksg.N_KPG) as 'N_KPG'
								,ksg.KOEF_Z as 'KOEF_Z'
								,ksg.KOEF_UP as 'KOEF_UP'
								,ksg.BZTSZ as 'BZTSZ'
								,ksg.KOEF_D as 'KOEF_D'
								,ksg.KOEF_U as 'KOEF_U'
								,(select top 1 IDDKK from [IES].T_KSG_CRIT c 
								 join [IES].T_V024_DOP_KR dk on c.V024DopKr=dk.V024DopKrID where c.Ksg=ksg.KsgID) as 'CRIT'
								--,(select top 1 IDDKK from [IES].T_V024_DOP_KR where V024DopKrID = ksg.DKK1) as 'DKK1'
								--,(select top 1 IDDKK from [IES].T_V024_DOP_KR where V024DopKrID = ksg.DKK2) as 'DKK2'
								,ksg.SL_K as 'SL_K'
								,ksg.IT_SL as 'IT_SL'
								,(
									SELECT kslp.KOEF_TYPE as 'IDSL'
										,kslp.KOEF as 'Z_SL'
									FROM [IES].T_KSLP kslp
									WHERE kslp.Ksg = ksg.KsgID 
									FOR
									XML PATH('SL_KOEF'),
									TYPE
								)
							FROM [IES].T_KSG ksg 
							WHERE ksg.SchetSluch = t3.SchetSluchID and @isVmp=0
							FOR
							XML PATH('KSG_KPG'),
							TYPE
						)
						,(case when @isVmp=1 then null else t3.REAB end) as 'REAB'
						,isnull(t3.PRVS3, t3.PRVS2) AS 'PRVS'
						,case when t3.PRVS3 is not null then 'V021' else null end AS 'VERS_SPEC'
						,t3.IDDOKT AS 'IDDOKT'
						,t3.ED_COL AS 'ED_COL'
						,t3.TARIF AS 'TARIF'
						,t3.SUMV as 'SUM_M'
						
						,(  	SELECT 
									 t4.IDSERV AS 'IDSERV'
									,t4.LPU AS 'LPU'
									--,t4.LPU_1 AS 'LPU_1'
									,t4.PODR AS 'PODR'
									,t4.PROFIL AS 'PROFIL'
									--,cast(t4.VID_VME as varchar(14)) AS 'VID_VME'
									-- 12.12.2019 VID_VME по новому 173 приказу по ВМП
									,case
										when @month>10 and @year>=2019 and t3.METOD_HMP is not null  then 
											convert(varchar,t3.METOD_HMP)
										ELSE
											cast(t4.VID_VME as varchar(14))
										end AS 'VID_VME'
									,t4.DET AS 'DET'
									,CONVERT(VARCHAR(10),t4.DATE_IN,126) AS 'DATE_IN'
									,CONVERT(VARCHAR(10),t4.DATE_OUT,126) AS 'DATE_OUT'
									,t4.P_OTK AS 'P_OTK'
									,t4.DS AS 'DS'
									,t4.CODE_USL AS 'CODE_USL'
									,t4.KOL_USL AS 'KOL_USL'

									,t4.TARIF AS 'TARIF'
									,t4.SUMV_USL AS 'SUMV_USL'
									,isnull(t4.PRVS3, t4.PRVS2) AS 'PRVS'
									,CODE_MD AS 'CODE_MD'
									,COMENTU AS 'COMENTU'

								FROM [IES].T_SCHET_USL t4 with(nolock) 		
								WHERE t4.SchetSluch = t3.SchetSluchID
								ORDER BY t4.IDSERV
			
								FOR
								XML PATH('USL'),
								TYPE
							)
						,case when t1.type_ = 562 then t3.COMENTSL else [dbo].[fn_GetErrorsText](t3.SchetSluchID)end AS 'COMENTSL'
			   
					FROM [IES].T_SCHET_SLUCH t3		
					WHERE ssa.SchetSluchAccomplishedID = t3.SchetSluchAccomplished and t3.SchetSluchID in (select distinct t13.SchetSluchID from #sluchs t13)
					ORDER BY t3.DATE_1, DATE_2
			
					FOR
					XML PATH('SL'),
					TYPE
				)

				---Если идти от кодов услуг, то можно попробовать так: для CODE_USL начинающийся на B01 или B04 - IDSP = 29, для CODE_USL начинающийся на Z01 - IDSP = 30, CODE_USL начинающийся на B03 или A - IDSP = 28
				,case when ssa.IDSP = 25 and (su.CODE_USL like 'B01%' or su.CODE_USL like 'B04%') then 29
					when ssa.IDSP = 25 and su.CODE_USL like 'Z01%' then 30
					when ssa.IDSP = 25 and (su.CODE_USL like 'B03%' or su.CODE_USL like 'A%') then 28
					else
				ssa.IDSP end AS 'IDSP'
				--,ssa.IDSP AS 'IDSP'
				,(select sum(ss2.SUMV) from #sluchs ss2 where ss2.SchetSluchAccomplished=ssa.SchetSluchAccomplishedID) AS 'SUMV'----------------------------
				,ssa.OPLATA AS 'OPLATA'
				,(select sum(ss2.SUMP) from #sluchs ss2 where ss2.SchetSluchAccomplished=ssa.SchetSluchAccomplishedID) AS 'SUMP'
				------------new sank---------
				,(  	SELECT
							 t6.ExpertiseErrorID AS 'S_CODE'
							,t8.SANK_MEK AS 'S_SUM'
							,1 AS 'S_TIP'
							,t7.Kod AS 'S_OSN'
							,CONVERT(VARCHAR(10), getdate(), 126) AS 'DATE_ACT'
							,1 AS 'NUM_ACT'
							,t6.Code AS 'CODE_EXP'
							,t6.Name AS 'S_COM'
							,1 AS 'S_IST'

							FROM [IES].T_ACT_ITEM_ERROR t4
							JOIN [IES].T_SCHET_ACT_ITEM t5 ON t5.SchetActItemID = t4.SchetActItem	
							JOIN [IES].T_EXPERTISE_ERROR t6 ON t6.ExpertiseErrorID = t4.ExpertiseError
							LEFT JOIN [IES].T_F014_DENY_REASON t7 on (t7.F014DenyReasonID = t6.F014DenyReason)
							join ies.T_SCHET_SLUCH t8 on t8.SchetSluchID = ssa.SchetSluchAccomplishedID

							WHERE t5.SchetSluch = t8.SchetSluchID AND t5.IsAddToAct = 1 
							ORDER BY t6.FOMScode
							FOR
							XML PATH('SANK'),
							TYPE
						)
						
				,case when ssa.SANK_IT > 0 then ssa.SANK_IT else null end as 'SANK_IT'

			FROM [IES].[T_SCHET_SLUCH_ACCOMPLISHED] ssa
			--Вакханалия для IDSP
			 join #sluchs ss on ss.SchetSluchAccomplished = ssa.SchetSluchAccomplishedID
			left join ies.T_SCHET_USL su with(nolock) on su.SchetSluch = ss.SchetSluchID and su.SUMV_USL > 0 and su.CODE_USL not in ('A18.05.002', 'A18.05.002.001', 'A18.05.002.002', 'A18.05.002.003', 'A18.05.002.005', 'A18.05.003', 'A18.05.003.002', 
 'A18.05.004', 'A18.05.004.001','A18.05.011','A18.05.011.001','A18.05.011.002','A18.30.001','A18.30.001.001','A18.30.001.002','A18.30.001.003','A18.05.001.001')
--			left join [IESDB].[IES].[R_NSI_SOUL_ALL] r  with(nolock) on su.usl = r.code_usl
			where ssa.SchetSluchAccomplishedID=(select top 1 t12.SchetSluchAccomplished from #sluchs t12 where t12.SchetZapID=t2.SchetZapID)
			FOR
			XML PATH('Z_SL'),
			TYPE
		)
	
	FROM [IES].T_SCHET_ZAP t2 
	WHERE t2.Schet=t1.SchetID and t2.SchetZapID in (select distinct t112.SchetZapID from #sluchs t112 where t112.SchetID=t1.SchetID)--year(t112.date_2)=t1.year and month(t112.DATE_2)=t1.MONTH)
	
	FOR
	XML PATH('ZAP'),
	TYPE
)
--FROM (select t1.CODE ,t1.CODE_MO, year(s.[DATE_2]) as year, month(s.DATE_2) as [MONTH],t1.NSCHET,t1.DSCHET,t1.PLAT, t1.COMENTS, t1.SchetID,
 --sum(s.SUMV) sumv, sum(s.SUMP) sump, sum(s.SANK_MEK) sank_mek, sum(s.SANK_MEE) SANK_MEE, sum(s.SANK_EKMP) SANK_EKMP, t1.DISP, t1.type_ 
 --from [IES].T_SCHET t1
--  join #sluchs s on t1.SchetID=s.SchetID
--  group by t1.CODE ,t1.CODE_MO,t1.NSCHET,t1.DSCHET,t1.PLAT,t1.COMENTS, year(s.[DATE_2]), month(s.DATE_2), t1.SchetID, t1.DISP, t1.type_ ) t1
FROM [IES].T_SCHET t1
WHERE t1.SChetID IN (select distinct s.SchetID 
	from #sluchs s)
	
	FOR
	XML PATH('SCHET'),
	TYPE)

FOR XML PATH(''),
ROOT('ZL_LIST')
)

--------------------------------ret2

select @ret1 = 
(select top 1

--ZGLV
'3.1' AS 'ZGLV/VERSION' 
, CONVERT(VARCHAR(10), t1.DATA, 126) AS 'ZGLV/DATA'
,'L' + @filename AS 'ZGLV/FILENAME'
,@filename 'ZGLV/FILENAME1'
--PERS
,( 
	SELECT 
	    t2.SchetZapID AS 'ID_PAC'
	    
	    --,t2.FAM AS 'FAM'
	    --,t2.IM AS 'IM'
		--,t2.OT AS 'OT'
		,t2.W AS 'W'
		,CONVERT(VARCHAR(10), t2.DR	,126) AS 'DR'
		,( 
					SELECT Split AS 'DOST'				   
					FROM [dbo].fn_Split(t2.DOST,',')					
					FOR
					XML PATH(''),
					TYPE
				) 
		
		,t2.TEL AS 'TEL'
		--,t2.FAM_P AS 'FAM_P'
		--,t2.IM_P AS 'IM_P'
		--,t2.OT_P AS 'OT_P'
		,case when t2.NOVOR=1 then t2.W_P else null end AS 'W_P'
		,case when t2.NOVOR=1 then CONVERT(VARCHAR(10),t2.DR_P, 126)  else null end AS 'DR_P'
		,case when t2.NOVOR=1 then ( 
						SELECT Split AS 'DOST_P'				   
						FROM [dbo].fn_Split(t2.DOST_P,',')					
						FOR
						XML PATH(''),
						TYPE
			)  else null end 
		,t2.MR AS 'MR'
		--,t2.DOCTYPE AS 'DOCTYPE'
		--,t2.DOCSER AS 'DOCSER'
		--,t2.DOCNUM AS 'DOCNUM'
		--,t2.SNILS AS 'SNILS'
		--,t2.OKATOG AS 'OKATOG'
		--,t2.OKATOP AS 'OKATOP'
		,t2.COMENTP AS 'COMENTP'  	
	FROM [IES].T_SCHET_ZAP t2 
	WHERE t2.SchetZapID in (select distinct s.SchetZapID from #sluchs s)
	
	FOR
	XML PATH('PERS'),
	TYPE
)

FROM [IES].T_SCHET t1
WHERE t1.SChetID in (select distinct s.SchetID from #sluchs s)
FOR XML PATH(''),
ROOT('PERS_LIST')
)

select @FileNameout = @filename + '.xml'

end