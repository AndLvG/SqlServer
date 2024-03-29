USE [IESDB]
GO
/****** Object:  StoredProcedure [dbo].[sp_prikaz_23_spr_SPR_KSG]    Script Date: 11.03.2021 15:21:21 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER  PROCEDURE [dbo].[sp_prikaz_23_spr_SPR_KSG]
@RETURN nvarchar(max) output,@FILENAME varchar(max) output, @NUMBER INT
AS 

BEGIN 

SELECT distinct CAST(IDUMP AS INT) idump, 
                   k_ksg, 
                   CAST(koef_z AS DECIMAL(15, 2)) koef_z, 
                   CAST(koef_u AS INT) koef_u, 
                   datebeg, 
                   dateend 
				   
				   into #tt FROM OPENQUERY
(ORACLE, 'SELECT idump, k_ksg, koef_z, koef_u, n_pgr, rpgr, koefpgr, k_datebeg, k_dateend, datebeg, dateend  FROM BUDJET.B_V_FFOMS_SPR_KSG WHERE n_pgr IS null order by 1,2,5')


select CAST(IDUMP AS INT) idump, 
                   k_ksg, 
                   CAST(koef_z AS DECIMAL(15, 2)) koef_z, 
                   CAST(koef_u AS INT) koef_u, 
                   n_pgr, 
                   rpgr, 
                   CAST(koefpgr AS DECIMAL(15, 2)) koefpgr, 
                   k_datebeg, 
                   k_dateend, 
                   datebeg, 
                   dateend into #tt2
FROM   OPENQUERY(ORACLE,
            'SELECT idump, k_ksg, koef_z, koef_u, n_pgr, rpgr, koefpgr, k_datebeg, k_dateend, datebeg, dateend  FROM  BUDJET.B_V_FFOMS_SPR_KSG where n_pgr is not null order by 1,2,5')

alter table #tt alter column koef_u int 
alter table #tt alter column koef_z decimal(15,2) 
--alter table #tt alter column koefpgr decimal(15,2) 
alter table #tt alter column IDUMP int 



alter table #tt2 alter column koef_u int 
alter table #tt2 alter column koef_z decimal(15,2) 
alter table #tt2 alter column koefpgr decimal(15,2) 
alter table #tt2 alter column IDUMP int 


--select * from #tt
Declare @type_ varchar(255) = 'sp_prikaz_23_spr_SPR_KSG'
if not exists(select * from INFORMATION_SCHEMA.TABLES where table_schema = 'IES' and table_name = 'R_NSI_UI_COMMAND_HIST')
	Create table IES.R_NSI_UI_COMMAND_HIST(type_ varchar(255),value varchar(255))

If not exists
	(select *
		from [IES].R_NSI_UI_COMMAND_HIST t1 
		join vclib.T_EXTRA_UI_COMMAND t2 on t2.Instruction = t1.type_ 
		where t2.Instruction like @type_)
Insert into [IES].R_NSI_UI_COMMAND_HIST 
	select @type_,11

Set @NUMBER =
	(select MAX(value)
		from [IES].R_NSI_UI_COMMAND_HIST t1 
		join vclib.T_EXTRA_UI_COMMAND t2 on t2.Instruction = t1.type_ 
		where t2.Instruction like @type_)

Update t1 set value = @NUMBER+1
	from [IES].R_NSI_UI_COMMAND_HIST t1 
	join vclib.T_EXTRA_UI_COMMAND t2 on t2.Instruction = t1.type_ 
	where t2.Instruction like @type_

select @FILENAME = 'TSUKOEFS400'
+ (select RIGHT('000'+cast(@NUMBER as varchar(9)),3) )


--UPDATE t2 set t2.ParamValue = 
--'<lx:ConstOperand type="Int32" xmlns:lx="lexem">'
--+CAST(CAST(REPLACE(REPLACE(ParamValue,'<lx:ConstOperand type="Int32" xmlns:lx="lexem">',''), '</lx:ConstOperand>','') as INT)+1 as varchar(9))
--+'</lx:ConstOperand>'
--From vclib.T_EXTRA_UI_COMMAND t1
--join vclib.T_EXTRA_UI_ACTION_PARAMS t2 on t2.ExtraUiCommand = t1.ExtraUiCommandID
--where t1.Instruction like '%sp_prikaz_23_spr_SPR_KSG%' and t2.[Name] = 'NUMBER'

--declare @return as varchar(max)
--select @RETURN = N'<?xml version="1.0" encoding="UTF-8"?>'+ 
--(select 'ZUPR'as type, '2.0' as version, CAST(GETDATE()AS DATE) as date  for xml path('zglv')) + 
--	(select
--	[IDUMP]    as [IDUMP]
--	,[k_ksg] as [K_KSG]
--	,[koef_z] as [KOEF_Z]
--	,[koef_u] as [KOEF_U]
--	,CAST(DATEBEG AS DATE) as [DATEBEG]
--	,CAST(DAtEEND AS DATE) as [DATEEND]
          
--	from #tt 
--	for xml path ('zap') , --type
--	root ('packet'))
	--select cast (@RETURN as xml)


	--declare @return as varchar(max)
	SELECT 
@RETURN = N'<?xml version="1.0" encoding="WINDOWS-1251"?>'+
(SELECT TOP 1 
'ZUPR'as 'zglv/type',
 '2.0' AS 'zglv/version'
,convert(varchar(10),cast(getdate() as date)) AS 'zglv/date'
,(select
	[IDUMP]    as [IDUMP]
	,[k_ksg] as [K_KSG]
	,[koef_z] as [KOEF_Z]
	,[koef_u] as [KOEF_U]
	 ,(SELECT n_pgr AS 'N_PGR', 
			  rpgr AS 'RPGR', 
              koefpgr AS 'KOEFPGR', 
              CAST(k_datebeg AS DATE) AS 'K_DATEBEG', 
              CAST(k_dateend AS DATE) AS 'K_DATEEND'
       FROM          #tt2
            WHERE       #tt2.k_ksg = #tt.k_ksg AND #tt2.datebeg = #tt.datebeg  FOR XML PATH('PGR'), TYPE) 
	--,case when n_pgr IS NOT NULL then n_pgr end as 'PGR/N_PGR'
	--,case when n_pgr IS NOT NULL then rpgr end as 'PGR/RPGR'
	--,case when n_pgr IS NOT NULL then koefpgr end as 'PGR/KOEFPGR'
	--,case when n_pgr IS NOT NULL then CAST(k_datebeg AS DATE) end as 'PGR/K_DATEBEG'
	--,case when n_pgr IS NOT NULL then CAST(k_dateend AS DATE) end as 'PGR/K_DATEEND'
	,CAST(DATEBEG AS DATE) as [DATEBEG]
	,CAST(DAtEEND AS DATE) as [DATEEND]
          
	from #tt 
	for xml path ('zap'), type) 
	

for xml path(''), ROOT ('packet')
)

--select cast (@RETURN as xml)
	 
	DROP TABLE #tt
	DROP TABLE #tt2
 END