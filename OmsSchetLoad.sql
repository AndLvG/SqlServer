USE [IESDB]
GO
/****** Object:  StoredProcedure [dbo].[sp_OmsSchetLoadAllBulk_3_12_kaluga]    Script Date: 19.05.2021 9:01:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[sp_OmsSchetLoadAllBulk_3_12_kaluga]

  @SchetID uniqueidentifier
 ,@type int
 ,@Worker uniqueidentifier 
AS 
BEGIN 
set nocount on;
-- ФЛК второго уровня, проверка зависимостей невозможная с помощью XSD
declare @ActualDate datetime
,@NSCHET varchar(15)
,@year int
,@month int
,@plat VARCHAR(10)
,@lpu VARCHAR(10)
,@schet_coments VARCHAR(255)

select 
@ActualDate = [DSCHET]
,@NSCHET = NSCHET
,@year = year
,@month = month
,@plat = plat
,@lpu = code_mo
,@schet_coments = isnull(coments, 'Нет') 
/** 
ДЛЯ ПРОПУСКА ПРОВЕРОК ОБЪЁМA '<COMENTS>По решению комисии + объём</COMENTS>'                  ( if @schet_coments not like '%По решению комисии%' and @schet_coments not like '%+ объём%' )
ДЛЯ  ПРОПУСКА ВСЕХ ПРОВЕРОК КРОМЕ ОБЪЁМОВ '<COMENTS>По решению комисии + проверки</COMENTS>'                         ( and (@schet_coments not like '%По решению комисии%' and @schet_coments not like '%+ проверки%') )
ДЛЯ пропуска всего '<COMENTS>По решению комисии + объём + проверки</COMENTS>'
**/
from tempdb..TEMP_SCHET

declare @isMoToSmo bit = case when (select top 1 substring([FILENAME], 9, 1) from tempdb..TEMP_ZGLV where [FILENAME] not like 'D%') = 'S' then 1 
when (select top 1 substring([FILENAME], 10, 1) from tempdb..TEMP_ZGLV where [FILENAME] like 'D%') = 'S' then 1 else 0 end
create table #Errors
(
	IM_POL varchar(10),
	ZN_POL	varchar(100),	
	BASE_EL varchar(10),
	BAS_EL varchar(10),
	NSCHET varchar(15),
	N_ZAP int,	
	ID_PAC varchar(36),
	IDCASE varchar(11),
	SL_ID varchar(36),
	IDSERV varchar(36),
	OSHIB varchar(20),
	COMMENT varchar(250)
)

--=========================================================================
-- -=НАЧАЛО= Блок проверок по МТР от ЛПУ и Счетов от СМО.
--=========================================================================
if @type = 693 --in (693,554,562) 
BEGIN

--============ Контроль объёмов 5.3.2 Включение в реестр МП сверх терр. программы ОМС ============
-- Приоритеты
--1 - Социально значимые диагнозы. случаи с диагнозами, являющимися основной причиной смерти 
-- (I20.0; I21; I22;I23;I24; I60-I64; U07.1;);
--2 - Экстренная помощь (for_pom = 1)
--3 - Неотложная помощь (for_pom = 2)
--4 - Плановая помощь (всё остальное)
DECLARE @f_gosp INT = 0;
DECLARE @pl_gosp INT = 0;
DECLARE @f_sum DECIMAL(15,2) = 0;
DECLARE @pl_sum DECIMAL(15,2) = 0;
--
--if @schet_coments != 'По решению комисии + объём'
if (@schet_coments not like '% + объём%')
BEGIN -- Если счёт принимается не по решению комисии (с контролем объёмов)
--=================================================
--===== Контроль объёмов по дорогостоящим КСГ =====
--=================================================
DECLARE @ksg_table TABLE(ksg VARCHAR(50) NOT NULL); -- Дорогостоящие КСГ
INSERT INTO           @ksg_table(ksg)
VALUES ('st12.015.2'), ('st12.016'), ('st12.016.2'), ('st12.017'), ('st12.017.1'), ('st12.017.2'), ('st12.018'), ('st12.018.1'), ('st12.018.2');

DECLARE @ksg VARCHAR(50)
DECLARE c CURSOR FOR
	SELECT ksg from @ksg_table
OPEN c

FETCH NEXT FROM c INTO @ksg

WHILE @@FETCH_STATUS = 0
BEGIN
IF OBJECT_ID('tempdb..#reestr_ksg') IS NOT NULL
    DROP TABLE #reestr_ksg;

SELECT z.n_zap, zs.idcase, date_z_2, ss.sum_m sumv, k.n_ksg
		INTO #reestr_ksg
		from tempdb..TEMP_Z_SLUCH zs
		inner join tempdb..TEMP_SLUCH ss on zs.IDCASE=ss.IDCASE
		inner join tempdb..TEMP_ZAP z on zs.N_ZAP=z.N_ZAP
		inner join tempdb..TEMP_ZGLV zg on zg.FILENAME not like ('%T40_%') and SUBSTRING(zg.FILENAME,1,1) in ('H','C','T')  -- добавлено Т для общего контроля с ВМП
		inner join tempdb..TEMP_KSG_KPG k on k.IDCASE=ss.IDCASE and k.SL_ID=ss.SL_ID
	    where k.n_ksg = @ksg;

-- Количество госп факт
SET @f_gosp =
    (SELECT sum(cc)
     FROM (
		select count(*) cc -- количество госп в текущем счёте
		from #reestr_ksg
		union all
		SELECT count(*) cc  -- плюс все госп которые уже загружены с начала года и оплачены
		FROM IES.T_SCHET AS s WITH(NOLOCK)
			INNER JOIN IES.T_SCHET_ZAP AS sz WITH(NOLOCK) ON sz.Schet = s.SchetID
			INNER JOIN IES.T_SCHET_SLUCH_ACCOMPLISHED AS ssa WITH(NOLOCK) ON sz.SchetZapID = ssa.SchetZap
			INNER JOIN IES.T_SCHET_SLUCH AS ss WITH(NOLOCK) ON ssa.SchetSluchAccomplishedID = ss.SchetSluchAccomplished
			INNER JOIN IES.T_KSG AS ksg WITH (nolock) ON ksg.SchetSluch = ss.SchetSluchID
			LEFT JOIN tempdb..TEMP_SCHET schet on s.NSCHET = schet.NSCHET and s.CODE = schet.code and s.CODE_MO = schet.CODE_MO and s.PLAT=schet.PLAT and s.YEAR=schet.YEAR
		WHERE s.year = @year and s.month between 1 and @month
				AND s.type_ = @type and 
				ksg.n_ksg = @ksg
      		and s.code_mo = @lpu --and plat = @plat -- если включить plat то будет проверяться в пределах страховых
			and ss.sump > 0 and s.isdelete = 0
			and schet.NSCHET is null -- на случай если счет уже загружен, но не закрыт и посылают на изменение его
		) a
	 );

-- Запланировано госп
SET @pl_gosp = isnull(
    (SELECT -- Если включить то будет проверяться в пределах СМО
			--CASE @plat WHEN '40002' THEN CEILING(SUM(SMO_MAKS_GOSP)) WHEN '40004' THEN CEILING(SUM(SMO_SOGAZ_GOSP)) END gosp 
			 CEILING(SUM(gg_gosp)) gosp
     FROM [IESDB].[IES].[R_BUDJET_PLAN_STAC_VMP]
     WHERE lpu = @lpu and ksg_code = @ksg
           AND year = @year
           AND month BETWEEN 1 AND @month
     ), 0);

if @f_gosp > @pl_gosp -- если факт больше плана
BEGIN
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
SELECT 'ZAP', 'N_ZAP', N_ZAP, IDCASE, null, 
'5.3.2', 'Включение в реестр МП сверх терр. программы ОМС. КСГ ' + @ksg + ' план ' + cast(@pl_gosp as varchar) + ' факт ' + cast(@f_gosp as varchar)
FROM
     (
	 SELECT n_zap, idcase, date_z_2,
             ROW_NUMBER() OVER(ORDER BY date_z_2 ASC) AS Row#
      FROM #reestr_ksg) a
where Row# > (select count(*) cc from #reestr_ksg) - (@f_gosp - @pl_gosp) 
end;

	FETCH NEXT FROM c INTO @ksg
END;
CLOSE c;
DEALLOCATE c;
IF OBJECT_ID('tempdb..#reestr_ksg') IS NOT NULL
    DROP TABLE #reestr_ksg;
SET @f_gosp = 0;
SET @pl_gosp = 0;
SET @f_sum = 0;
SET @pl_sum = 0;
-- Конец контроля по дорогостящм КСГ
--=================================================================================
-- Далее контроль по всей остальной медицинской помощи
--=================================================================================
-- КС
--insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
--SELECT 'KS1', 'KS', null, null, null, 'Test',
--'@f_gosp = ' + cast(@f_gosp as varchar) + ' @pl_gosp = ' + cast(@pl_gosp as varchar) + ' @f_sum = ' + cast(@f_sum as varchar) + ' @pl_sum = ' + cast(@pl_sum as varchar)

IF OBJECT_ID('tempdb..#reestr_ks') IS NOT NULL
    DROP TABLE #reestr_ks;
SELECT z.n_zap, zs.idcase, date_z_2, ss.sum_m sumv,
				CASE WHEN ds1 BETWEEN 'I20' AND 'I24.99'
                       OR ds1 BETWEEN 'I60' AND 'I64.99'
                       OR ds1 IN('U07.1') THEN 1
					 WHEN zs.for_pom = 1 THEN 2 
					 WHEN zs.for_pom = 2 THEN 3  
					 ELSE 4 END prioritet
		INTO #reestr_ks
		from tempdb..TEMP_Z_SLUCH zs
		inner join tempdb..TEMP_SLUCH ss on zs.IDCASE=ss.IDCASE
		inner join tempdb..TEMP_ZAP z on zs.N_ZAP=z.N_ZAP
		inner join tempdb..TEMP_ZGLV zg on zg.FILENAME not like ('%T40_%') and SUBSTRING(zg.FILENAME,1,1) in ('H','C','T')  -- добавлено Т для общего контроля с ВМП
		where zs.usl_ok = 1;

-- Количество госп факт
SET @f_gosp =
    (SELECT sum(cc)
     FROM (
		select count(*) cc -- количество госп в текущем счёте
		from #reestr_ks
		union all
		SELECT count(*) cc  -- плюс все госп которые уже загружены с начала года и оплачены
		FROM IES.T_SCHET AS s WITH(NOLOCK)
			INNER JOIN IES.T_SCHET_ZAP AS sz WITH(NOLOCK) ON sz.Schet = s.SchetID
			INNER JOIN IES.T_SCHET_SLUCH_ACCOMPLISHED AS ssa WITH(NOLOCK) ON sz.SchetZapID = ssa.SchetZap
			INNER JOIN IES.T_SCHET_SLUCH AS ss WITH(NOLOCK) ON ssa.SchetSluchAccomplishedID = ss.SchetSluchAccomplished
			LEFT JOIN tempdb..TEMP_SCHET schet on s.NSCHET = schet.NSCHET and s.CODE = schet.code and s.CODE_MO = schet.CODE_MO and s.PLAT=schet.PLAT and s.YEAR=schet.YEAR
		WHERE s.year = @year and s.month between 1 and @month
				AND s.type_ = @type and ssa.usl_ok = 1
      		and s.code_mo = @lpu --and plat = @plat -- если включить plat то будет проверяться в пределах страховых
			and ss.sump > 0 and s.isdelete = 0
		--	and metod_hmp is null -- считаем вместе ВМП для общего контроля по КС
			and schet.NSCHET is null -- на случай если счет уже загружен, но не закрыт и посылают на изменение его
		) a
	 );
-- Сумма факт
SET @f_sum =
    (SELECT sum(cc)
     FROM (
		select sum(sumv) cc -- сумма в текущем счёте
		from #reestr_ks
		union all
		SELECT sum(ss.sumv) cc  -- плюс вся сумма которая уже загружена с начала года и оплачена
		FROM IES.T_SCHET AS s WITH(NOLOCK)
			INNER JOIN IES.T_SCHET_ZAP AS sz WITH(NOLOCK) ON sz.Schet = s.SchetID
			INNER JOIN IES.T_SCHET_SLUCH_ACCOMPLISHED AS ssa WITH(NOLOCK) ON sz.SchetZapID = ssa.SchetZap
			INNER JOIN IES.T_SCHET_SLUCH AS ss WITH(NOLOCK) ON ssa.SchetSluchAccomplishedID = ss.SchetSluchAccomplished
			LEFT JOIN tempdb..TEMP_SCHET schet on s.NSCHET = schet.NSCHET and s.CODE = schet.code and s.CODE_MO = schet.CODE_MO and s.PLAT=schet.PLAT and s.YEAR=schet.YEAR
		WHERE s.year = @year and s.month between 1 and @month
				AND s.type_ = @type and ssa.usl_ok = 1
      		and s.code_mo = @lpu --and plat = @plat -- если включить plat то будет проверяться в пределах страховых
			and ss.sump > 0 and s.isdelete = 0
		--	and metod_hmp is null -- считаем вместе ВМП для общего контроля по КС
			and schet.NSCHET is null -- на случай если счет уже загружен, но не закрыт и посылают на изменение его
		) a
	 );

-- Запланировано госп
SET @pl_gosp = isnull(
    (SELECT -- Если включить то будет проверяться в пределах СМО
			--CASE @plat WHEN '40002' THEN CEILING(SUM(SMO_MAKS_GOSP)) WHEN '40004' THEN CEILING(SUM(SMO_SOGAZ_GOSP)) END gosp 
			 CEILING(SUM(gg_gosp)) gosp
     FROM [IESDB].[IES].[R_BUDJET_PLAN_STAC_VMP]
     WHERE lpu = @lpu
           AND year = @year
           AND usl_ok in (1, 5) -- 5 - чтобы брался план и по ВМП для общего контроля по КС
           AND month BETWEEN 1 AND @month
     ), 0);
-- Запланировано сумма
SET @pl_sum = isnull(
    (SELECT -- Если включить то будет проверяться в пределах СМО
			--CASE @plat WHEN '40002' THEN CEILING(SUM(SMO_MAKS_GOSP)) WHEN '40004' THEN CEILING(SUM(SMO_SOGAZ_GOSP)) END gosp 
			 CEILING(SUM(gg_sum)) pl_sum
     FROM [IESDB].[IES].[R_BUDJET_PLAN_STAC_VMP]
     WHERE lpu = @lpu
           AND year = @year
           AND usl_ok in (1, 5) -- 5 - чтобы брался план и по ВМП для общего контроля по КС
           AND month BETWEEN 1 AND @month
     ), 0);
--
--insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
--SELECT 'KS2', 'N_ZAP', null, null, null, 'Test',
--'@f_gosp = ' + cast(@f_gosp as varchar) + ' @pl_gosp = ' + cast(@pl_gosp as varchar) + ' @f_sum = ' + cast(@f_sum as varchar) + ' @pl_sum = ' + cast(@pl_sum as varchar)

if @f_gosp > @pl_gosp or @f_sum > @pl_sum -- если факт больше плана
BEGIN
--insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
--SELECT 'KS3', 'N_ZAP', null, null, null, 'Test',
--'Entered control ' + cast((select sum(sumv) cc from #reestr_ks) as varchar) + ' ' + cast((@f_sum - @pl_sum) as varchar)
--
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
SELECT 'ZAP', 'N_ZAP', N_ZAP, IDCASE, null, 
'5.3.2', 'Включение в реестр МП сверх терр. программы ОМС. КС + ВМП случаев план ' + cast(@pl_gosp as varchar) + ' факт ' + cast(@f_gosp as varchar) +
	'. КС + ВМП сумма план ' + FORMAT(@pl_sum, 'C') + ' факт ' + FORMAT(@f_sum, 'C')
FROM
     (
	 SELECT n_zap, idcase, date_z_2, prioritet,
             ROW_NUMBER() OVER(ORDER BY prioritet, date_z_2 ASC) AS Row#,
			 SUM(sumv) OVER(ORDER BY prioritet, date_z_2, n_zap ASC) Raising_sum
      FROM #reestr_ks) a
where (Row# > (select count(*) cc from #reestr_ks) - (@f_gosp - @pl_gosp) or
		Raising_sum > (select sum(sumv) cc from #reestr_ks) - (@f_sum - @pl_sum))
	--and prioritet != 1  -- не снимаются объёмы по социально значимым диагнозам
end;
IF OBJECT_ID('tempdb..#reestr_ks') IS NOT NULL
    DROP TABLE #reestr_ks;
SET @f_gosp = 0;
SET @pl_gosp = 0;
SET @f_sum = 0;
SET @pl_sum = 0;
-- Конец контроля по КС
--=================================================================================
-- ДС
IF OBJECT_ID('tempdb..#reestr_ds') IS NOT NULL
    DROP TABLE #reestr_ds;
SELECT z.n_zap, zs.idcase, date_z_2, ss.sum_m sumv,
				CASE WHEN ds1 BETWEEN 'I20' AND 'I24.99'
                       OR ds1 BETWEEN 'I60' AND 'I64.99'
                       OR ds1 IN('U07.1') THEN 1
					 WHEN zs.for_pom = 1 THEN 2 
					 WHEN zs.for_pom = 2 THEN 3  ELSE 4 END prioritet
		INTO #reestr_ds
		from tempdb..TEMP_Z_SLUCH zs
		inner join tempdb..TEMP_SLUCH ss on zs.IDCASE=ss.IDCASE
		inner join tempdb..TEMP_ZAP z on zs.N_ZAP=z.N_ZAP
		inner join tempdb..TEMP_ZGLV zg on zg.FILENAME not like ('%T40_%') and SUBSTRING(zg.FILENAME,1,1) in ('H','C')
		where zs.usl_ok = 2;

-- Количество госп факт
SET @f_gosp =
    (SELECT sum(cc)
     FROM (
		select count(*) cc -- количество госп в текущем счёте
		from #reestr_ds
		union all
		SELECT count(*) cc  -- плюс все госп которые уже загружены с начала года и оплачены
		FROM IES.T_SCHET AS s WITH(NOLOCK)
			INNER JOIN IES.T_SCHET_ZAP AS sz WITH(NOLOCK) ON sz.Schet = s.SchetID
			INNER JOIN IES.T_SCHET_SLUCH_ACCOMPLISHED AS ssa WITH(NOLOCK) ON sz.SchetZapID = ssa.SchetZap
			INNER JOIN IES.T_SCHET_SLUCH AS ss WITH(NOLOCK) ON ssa.SchetSluchAccomplishedID = ss.SchetSluchAccomplished
			LEFT JOIN tempdb..TEMP_SCHET schet on s.NSCHET = schet.NSCHET and s.CODE = schet.code and s.CODE_MO = schet.CODE_MO and s.PLAT=schet.PLAT and s.YEAR=schet.YEAR
		WHERE s.year = @year and s.month between 1 and @month
				AND s.type_ = @type and ssa.usl_ok = 2
      		and s.code_mo = @lpu --and plat = @plat -- если включить plat то будет проверяться в пределах страховых
			and ss.sump > 0 and s.isdelete = 0
			and metod_hmp is null 
			and schet.NSCHET is null -- на случай если счет уже загружен, но не закрыт и посылают на изменение его
		) a
	 );
-- Сумма ДС факт
SET @f_sum =
    (SELECT sum(cc)
     FROM (
		select sum(sumv) cc -- сумма в текущем счёте
		from #reestr_ds
		union all
		SELECT sum(ss.sump) cc  -- плюс все сумма которые уже загружены с начала года и оплачены
		FROM IES.T_SCHET AS s WITH(NOLOCK)
			INNER JOIN IES.T_SCHET_ZAP AS sz WITH(NOLOCK) ON sz.Schet = s.SchetID
			INNER JOIN IES.T_SCHET_SLUCH_ACCOMPLISHED AS ssa WITH(NOLOCK) ON sz.SchetZapID = ssa.SchetZap
			INNER JOIN IES.T_SCHET_SLUCH AS ss WITH(NOLOCK) ON ssa.SchetSluchAccomplishedID = ss.SchetSluchAccomplished
			LEFT JOIN tempdb..TEMP_SCHET schet on s.NSCHET = schet.NSCHET and s.CODE = schet.code and s.CODE_MO = schet.CODE_MO and s.PLAT=schet.PLAT and s.YEAR=schet.YEAR
		WHERE s.year = @year and s.month between 1 and @month
				AND s.type_ = @type and ssa.usl_ok = 2
      		and s.code_mo = @lpu --and plat = @plat -- если включить plat то будет проверяться в пределах страховых
			and ss.sump > 0 and s.isdelete = 0
			and metod_hmp is null 
			and schet.NSCHET is null -- на случай если счет уже загружен, но не закрыт и посылают на изменение его
		) a
	 );
--
-- Запланировано госп
SET @pl_gosp = isnull(
    (SELECT -- Если включить то будет проверяться в пределах СМО
			--CASE @plat WHEN '40002' THEN CEILING(SUM(SMO_MAKS_GOSP)) WHEN '40004' THEN CEILING(SUM(SMO_SOGAZ_GOSP)) END gosp 
			 CEILING(SUM(gg_gosp)) gosp
     FROM [IESDB].[IES].[R_BUDJET_PLAN_STAC_VMP]
     WHERE lpu = @lpu
           AND year = @year
           AND usl_ok = 2
           AND month BETWEEN 1 AND @month
     ), 0);
-- Запланировано сумма
SET @pl_sum = isnull(
    (SELECT -- Если включить то будет проверяться в пределах СМО
			--CASE @plat WHEN '40002' THEN CEILING(SUM(SMO_MAKS_GOSP)) WHEN '40004' THEN CEILING(SUM(SMO_SOGAZ_GOSP)) END gosp 
			 CEILING(SUM(gg_sum)) pl_sum
     FROM [IESDB].[IES].[R_BUDJET_PLAN_STAC_VMP]
     WHERE lpu = @lpu
           AND year = @year
           AND usl_ok = 2
           AND month BETWEEN 1 AND @month
     ), 0);
--
if @f_gosp > @pl_gosp or @f_sum > @pl_sum -- если факт больше плана
BEGIN
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
SELECT 'ZAP', 'N_ZAP', N_ZAP, IDCASE, null, 
'5.3.2', 'Включение в реестр МП сверх терр. программы ОМС. ДС случаев план ' + cast(@pl_gosp as varchar) + ' факт ' + cast(@f_gosp as varchar) +
	'. ДС сумма план ' + FORMAT(@pl_sum, 'C') + ' факт ' + FORMAT(@f_sum, 'C')
FROM
     (
	 SELECT n_zap, idcase, date_z_2, prioritet,
             ROW_NUMBER() OVER(ORDER BY prioritet, date_z_2 ASC) AS Row#,
			 SUM(sumv) OVER(ORDER BY prioritet, date_z_2, n_zap ASC) Raising_sum
      FROM #reestr_ds) a
where (Row# > (select count(*) cc from #reestr_ds) - (@f_gosp - @pl_gosp) or
 Raising_sum > (select sum(sumv) cc from #reestr_ds) - (@f_sum - @pl_sum))
	--and prioritet != 1  -- не снимаются объёмы по социально значимым диагнозам
end;
IF OBJECT_ID('tempdb..#reestr_ds') IS NOT NULL
    DROP TABLE #reestr_ds;
SET @f_gosp = 0;
SET @pl_gosp = 0;
SET @f_sum = 0;
SET @pl_sum = 0;
-- Конец контроля по ДС
--=====================
-- ВМП
-- Перенесено в общий контроль по КС
--IF OBJECT_ID('tempdb..#reestr_vmp') IS NOT NULL
--    DROP TABLE #reestr_vmp;
--SELECT z.n_zap, zs.idcase, date_z_2, ss.sum_m sumv,
--				CASE WHEN ds1 BETWEEN 'I20' AND 'I24.99'
--                       OR ds1 BETWEEN 'I60' AND 'I64.99'
--                       OR ds1 IN('U07.1') THEN 1
--					 WHEN zs.for_pom = 1 THEN 2 
--					 WHEN zs.for_pom = 2 THEN 3  ELSE 4 END prioritet
--		INTO #reestr_vmp
--		from tempdb..TEMP_Z_SLUCH zs
--		inner join tempdb..TEMP_SLUCH ss on zs.IDCASE=ss.IDCASE
--		inner join tempdb..TEMP_ZAP z on zs.N_ZAP=z.N_ZAP
--		inner join tempdb..TEMP_ZGLV zg on zg.FILENAME not like ('%T40_%') and SUBSTRING(zg.FILENAME,1,1) in ('T')
--		where zs.usl_ok = 1;

---- Количество госп факт
--SET @f_gosp =
--    (SELECT sum(cc)
--     FROM (
--		select count(*) cc -- количество госп в текущем счёте
--		from #reestr_vmp
--		union all
--		SELECT count(*) cc  -- плюс все госп которые уже загружены с начала года и оплачены
--		FROM IES.T_SCHET AS s WITH(NOLOCK)
--			INNER JOIN IES.T_SCHET_ZAP AS sz WITH(NOLOCK) ON sz.Schet = s.SchetID
--			INNER JOIN IES.T_SCHET_SLUCH_ACCOMPLISHED AS ssa WITH(NOLOCK) ON sz.SchetZapID = ssa.SchetZap
--			INNER JOIN IES.T_SCHET_SLUCH AS ss WITH(NOLOCK) ON ssa.SchetSluchAccomplishedID = ss.SchetSluchAccomplished
--			LEFT JOIN tempdb..TEMP_SCHET schet on s.NSCHET = schet.NSCHET and s.CODE = schet.code and s.CODE_MO = schet.CODE_MO and s.PLAT=schet.PLAT and s.YEAR=schet.YEAR
--		WHERE s.year = @year and s.month between 1 and @month
--				AND s.type_ = @type and ssa.usl_ok = 1
--      		and s.code_mo = @lpu --and plat = @plat -- если включить plat то будет проверяться в пределах страховых
--			and ss.sump > 0 and s.isdelete = 0
--			and metod_hmp is not null 
--			and schet.NSCHET is null -- на случай если счет уже загружен, но не закрыт и посылают на изменение его
--		) a
--	 );
---- Сумма ВМП факт
--SET @f_sum =
--    (SELECT sum(cc)
--     FROM (
--		select sum(sumv) cc -- количество госп в текущем счёте
--		from #reestr_vmp
--		union all
--		SELECT sum(ss.sump) cc  -- плюс все сумм которые уже загружены с начала года и оплачены
--		FROM IES.T_SCHET AS s WITH(NOLOCK)
--			INNER JOIN IES.T_SCHET_ZAP AS sz WITH(NOLOCK) ON sz.Schet = s.SchetID
--			INNER JOIN IES.T_SCHET_SLUCH_ACCOMPLISHED AS ssa WITH(NOLOCK) ON sz.SchetZapID = ssa.SchetZap
--			INNER JOIN IES.T_SCHET_SLUCH AS ss WITH(NOLOCK) ON ssa.SchetSluchAccomplishedID = ss.SchetSluchAccomplished
--			LEFT JOIN tempdb..TEMP_SCHET schet on s.NSCHET = schet.NSCHET and s.CODE = schet.code and s.CODE_MO = schet.CODE_MO and s.PLAT=schet.PLAT and s.YEAR=schet.YEAR
--		WHERE s.year = @year and s.month between 1 and @month
--				AND s.type_ = @type and ssa.usl_ok = 1
--      		and s.code_mo = @lpu --and plat = @plat -- если включить plat то будет проверяться в пределах страховых
--			and ss.sump > 0 and s.isdelete = 0
--			and metod_hmp is not null 
--			and schet.NSCHET is null -- на случай если счет уже загружен, но не закрыт и посылают на изменение его
--		) a
--	 );
---- Запланировано госп
--SET @pl_gosp = isnull(
--    (SELECT -- Если включить то будет проверяться в пределах СМО
--			--CASE @plat WHEN '40002' THEN CEILING(SUM(SMO_MAKS_GOSP)) WHEN '40004' THEN CEILING(SUM(SMO_SOGAZ_GOSP)) END gosp 
--			 CEILING(SUM(gg_gosp)) gosp
--     FROM [IESDB].[IES].[R_BUDJET_PLAN_STAC_VMP]
--     WHERE lpu = @lpu
--           AND year = @year
--           AND usl_ok = 5
--           AND month BETWEEN 1 AND @month
--     ), 0);
---- Запланировано сумма
--SET @pl_sum = isnull(
--    (SELECT -- Если включить то будет проверяться в пределах СМО
--			--CASE @plat WHEN '40002' THEN CEILING(SUM(SMO_MAKS_GOSP)) WHEN '40004' THEN CEILING(SUM(SMO_SOGAZ_GOSP)) END gosp 
--			 CEILING(SUM(gg_sum)) pl_sum
--     FROM [IESDB].[IES].[R_BUDJET_PLAN_STAC_VMP]
--     WHERE lpu = @lpu
--           AND year = @year
--           AND usl_ok = 5
--           AND month BETWEEN 1 AND @month
--     ), 0);
--
--if @f_gosp > @pl_gosp or @f_sump > @pl_sum -- если факт больше плана
--BEGIN
--insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
--SELECT 'ZAP', 'N_ZAP', N_ZAP, IDCASE, null, 
--'5.3.2', 'Включение в реестр МП сверх терр. программы ОМС. ВМП случаев план ' + cast(@pl_gosp as varchar) + ' факт ' + cast(@f_gosp as varchar) +
--	'. ВМП сумма план ' + cast(@pl_sum as varchar) + ' факт ' + cast(@f_sum as varchar)
--FROM
--     (
--	 SELECT n_zap, idcase, date_z_2, prioritet,
--             ROW_NUMBER() OVER(ORDER BY prioritet, date_z_2 ASC) AS Row#,
-- 			 SUM(sumv) OVER(ORDER BY prioritet, date_z_2, n_zap ASC) Raising_sum
--      FROM #reestr_vmp) a
--where (Row# > (select count(*) cc from #reestr_vmp) - (@f_gosp - @pl_gosp) or
--Raising_sum > (select sum(sumv) cc from #reestr_vmp) - (@f_sum - @pl_sum))
--	and prioritet != 1  -- не снимаются объёмы по социально значимым диагнозам
--end;
--IF OBJECT_ID('tempdb..#reestr_vmp') IS NOT NULL
--    DROP TABLE #reestr_vmp;
--SET @f_gosp = 0;
--SET @pl_gosp = 0;
--SET @f_sum = 0;
--SET @pl_sum = 0;
-- Конец контроля по ВМП
--=====================
-- Поликлиника
IF OBJECT_ID('tempdb..#reestr_amb') IS NOT NULL
    DROP TABLE #reestr_amb;
SELECT z.n_zap, zs.idcase, date_z_2, u.kol_usl, ss.sum_m sumv, ss.profil
		INTO #reestr_amb
		from tempdb..TEMP_Z_SLUCH zs
		inner join tempdb..TEMP_SLUCH ss on zs.IDCASE=ss.IDCASE
		inner join tempdb..TEMP_ZAP z on zs.N_ZAP=z.N_ZAP
		inner join tempdb..TEMP_ZGLV zg on zg.FILENAME not like ('%T40_%') and SUBSTRING(zg.FILENAME,1,1) in ('H','C')
		inner join tempdb..TEMP_USL u on ss.IDCASE=u.IDCASE and ss.SL_ID=u.SL_ID
		where zs.usl_ok in (3,4) 
			and u.code_usl in (select distinct usl_code from IESDB.IES.R_BUDJET_PLAN_USL 
			    where YEAR = @year AND MONTH = @month and podush = 0)
			and  u.sumv_usl > 0;

-- Количество услуг факт
SET @f_gosp =
    (SELECT sum(cc)
     FROM (
		select sum(kol_usl) cc -- количество услуг в текущем счёте
		from #reestr_amb
		union all
		SELECT sum(kol_usl) cc  -- плюс все услуги которые уже загружены с начала года и оплачены
		FROM IES.T_SCHET AS s WITH(NOLOCK)
			INNER JOIN IES.T_SCHET_ZAP AS sz WITH(NOLOCK) ON sz.Schet = s.SchetID
			INNER JOIN IES.T_SCHET_SLUCH_ACCOMPLISHED AS ssa WITH(NOLOCK) ON sz.SchetZapID = ssa.SchetZap
			INNER JOIN IES.T_SCHET_SLUCH AS ss WITH(NOLOCK) ON ssa.SchetSluchAccomplishedID = ss.SchetSluchAccomplished
			CROSS APPLY
         (SELECT usl.code_usl, sum(kol_usl) kol_usl, max(date_out) DATE_OUT
          FROM   IES.T_SCHET_USL usl WITH (nolock)
          WHERE  ss.SchetSluchID = usl.SchetSluch
                 AND usl.sumv_usl > 0
		   group by usl.code_usl
			) u
			LEFT JOIN tempdb..TEMP_SCHET schet on s.NSCHET = schet.NSCHET and s.CODE = schet.code and s.CODE_MO = schet.CODE_MO and s.PLAT=schet.PLAT and s.YEAR=schet.YEAR
			LEFT JOIN [my_base].[dbo].[USL_CODE_CONVERT] uc ON uc.FAKT_CODE = u.CODE_USL AND u.DATE_OUT BETWEEN uc.DATE_B AND uc.DATE_E
		WHERE s.year = @year and s.month between 1 and @month
				AND s.type_ = @type and ssa.usl_ok in (3,4)
      		and s.code_mo = @lpu --and plat = @plat -- если включить plat то будет проверяться в пределах страховых
			and ss.sump > 0 and s.isdelete = 0
			and schet.NSCHET is null -- на случай если счет уже загружен, но не закрыт и посылают на изменение его
			and isnull(uc.PLAN_CODE, u.CODE_USL) in (select distinct usl_code from IESDB.IES.R_BUDJET_PLAN_USL where YEAR = @year AND MONTH between 1 and @month and podush = 0)
		) a
	 );
-- Сумма услуг факт
SET @f_sum =
    (SELECT sum(cc)
     FROM (
		select sum(sumv) cc -- количество услуг в текущем счёте
		from #reestr_amb
		union all
		SELECT sum(ss.sump) cc  -- плюс все услуги которые уже загружены с начала года и оплачены
		FROM IES.T_SCHET AS s WITH(NOLOCK)
			INNER JOIN IES.T_SCHET_ZAP AS sz WITH(NOLOCK) ON sz.Schet = s.SchetID
			INNER JOIN IES.T_SCHET_SLUCH_ACCOMPLISHED AS ssa WITH(NOLOCK) ON sz.SchetZapID = ssa.SchetZap
			INNER JOIN IES.T_SCHET_SLUCH AS ss WITH(NOLOCK) ON ssa.SchetSluchAccomplishedID = ss.SchetSluchAccomplished
			CROSS APPLY
         (SELECT usl.code_usl, sum(kol_usl) kol_usl, max(date_out) DATE_OUT
          FROM   IES.T_SCHET_USL usl WITH (nolock)
          WHERE  ss.SchetSluchID = usl.SchetSluch
                 AND usl.sumv_usl > 0
		   group by usl.code_usl
			) u
			LEFT JOIN tempdb..TEMP_SCHET schet on s.NSCHET = schet.NSCHET and s.CODE = schet.code and s.CODE_MO = schet.CODE_MO and s.PLAT=schet.PLAT and s.YEAR=schet.YEAR
			LEFT JOIN [my_base].[dbo].[USL_CODE_CONVERT] uc ON uc.FAKT_CODE = u.CODE_USL AND u.DATE_OUT BETWEEN uc.DATE_B AND uc.DATE_E
		WHERE s.year = @year and s.month between 1 and @month
				AND s.type_ = @type and ssa.usl_ok in (3,4)
      		and s.code_mo = @lpu --and plat = @plat -- если включить plat то будет проверяться в пределах страховых
			and ss.sump > 0 and s.isdelete = 0
			and schet.NSCHET is null -- на случай если счет уже загружен, но не закрыт и посылают на изменение его
			and isnull(uc.PLAN_CODE, u.CODE_USL) in (select distinct usl_code from IESDB.IES.R_BUDJET_PLAN_USL where YEAR = @year AND MONTH between 1 and @month and podush = 0)
		) a
	 );
-- Запланировано услуг
SET @pl_gosp = isnull(
    (SELECT -- Если включить то будет проверяться в пределах СМО
			--CASE @plat WHEN '40002' THEN CEILING(SUM(SMO_MAKS_GOSP)) WHEN '40004' THEN CEILING(SUM(SMO_SOGAZ_GOSP)) END gosp 
			 CEILING(SUM(usl_val)) gosp
     FROM  IESDB.IES.R_BUDJET_PLAN_USL
     WHERE lpu = @lpu
           AND year = @year AND month BETWEEN 1 AND @month
		    and podush = 0
     ), 0);
-- Запланировано сумма
SET @pl_sum = isnull(
    (SELECT -- Если включить то будет проверяться в пределах СМО
			--CASE @plat WHEN '40002' THEN CEILING(SUM(SMO_MAKS_GOSP)) WHEN '40004' THEN CEILING(SUM(SMO_SOGAZ_GOSP)) END gosp 
			 CEILING(SUM(dohod)) pl_sum
     FROM  IESDB.IES.R_BUDJET_PLAN_USL
     WHERE lpu = @lpu
           AND year = @year AND month BETWEEN 1 AND @month
		    and podush = 0
     ), 0);
-- Стоматологические клиники контролируем только по стоимости
if (@f_gosp > @pl_gosp and @lpu not in ('400056', '400014', '400054')) or @f_sum > @pl_sum -- если факт больше плана
BEGIN
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
SELECT 'ZAP', 'N_ZAP', N_ZAP, IDCASE, null, 
'5.3.2', 'Включение в реестр МП сверх терр. программы ОМС. Амб. случаев план ' + cast(@pl_gosp as varchar) + ' факт ' + cast(@f_gosp as varchar) +
	'. Амб. сумма план ' + FORMAT(@pl_sum, 'C') + ' факт ' + FORMAT(@f_sum, 'C')
FROM
     (
	 SELECT n_zap, idcase, date_z_2, 
             ROW_NUMBER() OVER(ORDER BY date_z_2 ASC) AS Row#,
			 SUM(sumv) OVER(ORDER BY date_z_2, n_zap ASC) Raising_sum
      FROM #reestr_amb) a
where (Row# > (select count(*) cc from #reestr_amb) - (@f_gosp - @pl_gosp) or
 Raising_sum > (select sum(sumv) cc from #reestr_amb) - (@f_sum - @pl_sum))
end;
IF OBJECT_ID('tempdb..#reestr_amb') IS NOT NULL
    DROP TABLE #reestr_amb;
SET @f_gosp = 0;
SET @pl_gosp = 0;
SET @f_sum = 0;
SET @pl_sum = 0;
-- Конец контроля по поликлинике
--=====================
--=====================
--
END; -- Окончание условия "По решению комиссии"
--
--============ Конец процедуры контроля объёмов ==================================
--


--Проверка №198
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'SMO', 'PACIENT', t.n_zap, z.idcase, null, '904',  'Значение SMO="'+isnull(cast(t.SMO as varchar),'')+'" не соответствует коду СМО на счете '+isnull(cast(s.plat as varchar),'')
       from tempdb..TEMP_Z_SLUCH z
	    join tempdb..TEMP_PACIENT t on z.N_ZAP=t.N_ZAP
        join tempdb..TEMP_SCHET s on s.PLAT is not null
      where t.SMO!=s.PLAT
		and @type in (693)
-- Проверка №197
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDSL', 'SL_KOEF', zs.N_ZAP, zs.IDCASE, null, '904', 'КСЛП B01.069.096.02 может применяться с МКБ U07.1,u07.2'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE)
  join tempdb..TEMP_DS2 ds2 on (ds2.IDCASE=s.IDCASE)
  join tempdb..TEMP_DS3 ds3 on (ds3.IDCASE=s.IDCASE)
  join tempdb..TEMP_SL_KOEF sl on sl.IDCASE=s.IDCASE and sl.SL_ID=s.SL_ID
  left join [IES].[R_NSI_KSLP] t on t.IDSL=sl.IDSL and t.ZKOEF=sl.Z_SL and s.DATE_2 between t.DATE_BEGIN and t.DATE_END
where 
	t.UslCode = 'B01.069.096.02'
	and (s.DS1 in ('U07.1','U07.2') or ds2.DS2 in ('U07.1','U07.2') or ds3.DS3 in ('U07.1','U07.2'))

-- Проверка №196
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDSL', 'SL_KOEF', zs.N_ZAP, zs.IDCASE, null, '904', 'Несоответствие КСЛП диагнозу / форме помощи / услуге' 
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE)
  join tempdb..TEMP_DS2 ds2 on (ds2.IDCASE=s.IDCASE)
  join tempdb..TEMP_DS3 ds3 on (ds3.IDCASE=s.IDCASE)
  join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID)  
  join tempdb..TEMP_SL_KOEF sl on sl.IDCASE=s.IDCASE and sl.SL_ID=s.SL_ID
  left join [IES].[R_NSI_KSLP] t on t.IDSL=sl.IDSL and t.ZKOEF=sl.Z_SL and s.DATE_2 between t.DATE_BEGIN and t.DATE_END
  inner join IESDB.IES.R_NSI_KSLP_FLK t3 on t3.kslp = t.CODE_USL
 where t3.kslp is not null
	and (
	    ((t3.ds1_begin is not null or t3.ds1_group is not null) and (s.DS1 not between t3.ds1_begin and t3.ds1_end or s.ds1 not like '%'+t3.ds1_group+'%') and (isnull(t3.for_pom,zs.FOR_POM) != zs.FOR_POM))
	 or ((t3.ds2_begin is not null or t3.ds2_group is not null) and (ds2.DS2 not between t3.ds2_begin and t3.ds2_end or ds2.ds2 not like '%'+t3.ds2_group+'%') and (isnull(t3.for_pom,zs.FOR_POM) != zs.FOR_POM))
	 or	((t3.ds2_begin is not null or t3.ds2_group is not null) and (ds3.DS3 not between t3.ds2_begin and t3.ds2_end or ds3.ds3 not like '%'+t3.ds2_group+'%') and (isnull(t3.for_pom,zs.FOR_POM) != zs.FOR_POM))
	 or (u.CODE_USL != isnull(t3.uls,u.code_usl) and s.COMENTSL != isnull(t3.comentsl,s.COMENTSL))
		)

-- Проверка №195
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'N_KSG', 'KSG_ KPG', zs.N_ZAP, zs.IDCASE, null, '904','Несоответствие лекарственного препарата выбранному КСГ'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join tempdb..TEMP_SCHET t2 on t2.code is not null
 where 
	k.n_ksg in ('st12.015.2', 'st12.016.2', 'st12.017.2', 'st12.018.2')
	and zs.USL_OK = 1
	and (s.DS1 = 'U07.1' or s.DS1 = 'U07.2')
	and s.comentsl not in ('Тоцилизумаб','Сарилумаб','Канакинумаб','Левилимаб','Нетакимаб','Олокизумаб')

-- Проверка №194
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'N_KSG', 'KSG_ KPG', zs.N_ZAP, zs.IDCASE, null, '904','Несоответствие кода МКБ, профиля выбранному КСГ'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join tempdb..TEMP_SCHET t2 on t2.code is not null
 where 
	k.n_ksg = 'ds25.003'
	and zs.USL_OK = 2
	and ((s.PROFIL=60) or (s.DS1 between 'C00' and 'C99.99') or (s.DS1 between 'D00' and 'D09.99'))

-- Проверка №193
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'MONTH', 'SCHET', t0.MONTH, null, null, '904',  'Название файла '+t1.FILENAME+' не соответствует отчетному году '+cast(t0.YEAR as varchar)+' и отчетному месяцу '+cast(t0.MONTH as varchar)+'.' 
 from  tempdb..TEMP_SCHET t0
	join tempdb..TEMP_ZGLV t1 on t1.FILENAME like ('%400%')
	where t1.FILENAME not like '%_'+substring(cast(t0.YEAR as varchar),3,2)+(case when len(t0.MONTH)=1 then '0'+cast(t0.MONTH as varchar) else cast(t0.MONTH as varchar) end)+'%'
	and @type = 693

-- Проверка №192
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'ZAP', 'N_ZAP', z.N_ZAP, null, null, '904',  'Период сдачи территориальных счетов за отчетный период закончен\не начат, можно отправлять только исправленные записи' 
 from  tempdb..TEMP_ZAP z 
	   join tempdb..TEMP_SCHET s on s.PLAT in ('40001','40002', '40004')
	   join tempdb..TEMP_ZGLV zg on zg.FILENAME not like ('%T40_%')
      where 
		z.PR_NOV = 0
		and datepart(day,GETDATE()) not between 1 and 8
		and s.year >= 2021
		and @type = 693
		and (@schet_coments not like '% + проверки%')
		--and @schet_coments != 'По решению комисии'

-- Проверка №192.1
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'ZAP', 'N_ZAP', z.N_ZAP, null, null, '904',  'Период сдачи исправленных записей за отчетный период закончен\не начат' 
 from  tempdb..TEMP_ZAP z 
	   join tempdb..TEMP_SCHET s on s.PLAT in ('40001','40002', '40004')
	   join tempdb..TEMP_ZGLV zg on zg.FILENAME not like ('%T40_%')
      where 
		z.PR_NOV = 1
		and datepart(day,GETDATE()) not between 10 and 18 
		and s.year >= 2021
		and @type = 693
		and (@schet_coments not like '% + проверки%')

-- Проверка №191
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_Z_2', 'Z_SL', zs.n_zap, zs.idcase, null, '904',  'Законченый случай с датой окончания лечения '+cast(zs.DATE_Z_2 as varchar(20))+' должен быть выставлен в СМО' 
 from tempdb..TEMP_Z_SLUCH zs
	   join tempdb..TEMP_ZAP z on z.N_ZAP=zs.N_ZAP
	   join tempdb..TEMP_SCHET s on s.PLAT in ('40001','40002', '40004')
	   join tempdb..TEMP_ZGLV zg on zg.FILENAME not like ('%T40_%')
      where 
		(s.year >= 2021)
		and zs.DATE_Z_2<'01.01.2021'
		and @type = 693

-- Проверка №191.1
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_Z_2', 'Z_SL', zs.n_zap, zs.idcase, null, '904',  'Законченый случай с датой окончания лечения '+cast(zs.DATE_Z_2 as varchar(20))+' не может быть выставлен СМО'  
 from tempdb..TEMP_Z_SLUCH zs
	   join tempdb..TEMP_ZAP z on z.N_ZAP=zs.N_ZAP
	   join tempdb..TEMP_SCHET s on s.PLAT in ('40001','40002', '40004')
	   join tempdb..TEMP_ZGLV zg on zg.FILENAME like ('%T40_%')
      where 
		(s.year >= 2021)
		and zs.DATE_Z_2>='01.01.2021'
		and @type = 693

 insert into #Errors (IM_POL, BASE_EL, NSCHET, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'YEAR', 'SCHET', s.NSCHET, s.CODE, null, '904', 'Отсутствует номер счета'
 from tempdb..TEMP_SCHET s
	where s.NSCHET is null


---- Проверка №178
-- insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
-- select 'DATE_Z_2', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'В одном счете не могут находиться случаи разных годов'
-- from tempdb..TEMP_Z_SLUCH zs
-- where (select count(distinct(DATEPART(YEAR, DATE_Z_2))) from tempdb..TEMP_Z_SLUCH)>1
-- and @type = 693

-- Проверка №177
 insert into #Errors (IM_POL, BASE_EL, NSCHET, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'YEAR', 'SCHET', s.NSCHET, s.CODE, null, '904', 'Отчетный год не соответствует текущему году'
 from tempdb..TEMP_SCHET s
	where ((s.year <> datepart(year,Getdate()) and datepart(MONTH, GETDATE())>1)
	   or (s.year <> datepart(year,(DATEADD ( year ,-1, GETDATE()))) and datepart(MONTH, GETDATE())=1))
	and @type = 693 --and @isMoToSmo = 0

-- Проверка №177.1
 insert into #Errors (IM_POL, BASE_EL, NSCHET, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'MONTH', 'SCHET', s.NSCHET, s.CODE, null, '904', 'Отчетный месяц не соответствует текущему отчетному периоду'
 from tempdb..TEMP_ZAP z
	join tempdb..TEMP_SCHET s on s.PLAT in ('40001','40002', '40004')
	where ((s.year = datepart(year,Getdate()) and s.month<>datepart(MONTH, (DATEADD ( MONTH ,-1, GETDATE()))))
	   or (s.year = datepart(year,(DATEADD ( year ,-1, GETDATE()))) and s.month<>12))
	and @type = 693
	and z.PR_NOV = 0
	 --and @isMoToSmo = 0
	----23.04.2020
-- Проверка №177.2
 insert into #Errors (IM_POL, BASE_EL, NSCHET, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'MONTH', 'SCHET', s.NSCHET, s.CODE, null, '904', 'Отчетный месяц не соответствует текущему отчетному периоду'
 from tempdb..TEMP_ZAP z
	join tempdb..TEMP_SCHET s on s.PLAT in ('40001','40002', '40004')
	where ((s.year = datepart(year,Getdate()) and s.month<>datepart(MONTH, GETDATE()))
	   or (s.year = datepart(year,(DATEADD ( year ,-1, GETDATE()))) and s.month<>12))
	and @type = 693
	and z.PR_NOV = 1
	--and (@schet_coments not like '% + проверки%')
	 --and @isMoToSmo = 0
	----23.04.2020
	

 -- 147 Проверка правильности заполнения PR_NOV=0
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
  select 'PR_NOV', 'ZAP', zs.N_ZAP, zs.IDCASE, null, '904', 'Для основной записи PR_NOV="0" в базе уже есть запись переданная ранее (IDCASE="'+cast(zs.IDCASE as varchar)
 +'" LPU="'+isnull(zs.lpu,'')+'" USL_OK="'+isnull(cast(zs.USL_OK as varchar),'')+'" DATE_Z_1="'+format(zs.DATE_Z_1, 'dd.MM.yyyy')+'" DATE_Z_2="'+format(zs.DATE_Z_2, 'dd.MM.yyyy')
 +' переданная в счете CODE="'+cast(t2.CODE as varchar)+ '" NSCHET="'+t2.NSCHET+'" DSCHET="'+format(t2.DSCHET, 'dd.MM.yyyy')+'"'
  from tempdb..TEMP_Z_SLUCH zs
  inner join tempdb..TEMP_PACIENT p on zs.N_ZAP=p.N_ZAP
  inner join tempdb..TEMP_ZAP z on zs.N_ZAP=z.N_ZAP
  inner join tempdb..TEMP_SCHET s on s.PLAT in ('40001','40002', '40004')
  inner join (select sc.year, sc.code_mo, sc.CODE, sc.NSCHET, sc.DSCHET, sc.plat, bzs.IDCASE, bzs.lpu, bzs.USL_OK, bzs.DATE_Z_1, bzs.DATE_Z_2 from [IES].[T_SCHET_SLUCH_ACCOMPLISHED] bzs
  inner join [IES].[T_SCHET_ZAP] bz on  bzs.SchetZap=bz.SchetZapID
  inner join [IES].[T_SCHET] sc on bz.Schet=sc.SchetID  and sc.IsDelete=0  and sc.type_ = @type) t2
   on s.plat=t2.plat and zs.IDCASE=t2.IDCASE and zs.lpu=t2.lpu and zs.USL_OK=t2.USL_OK and zs.DATE_Z_1=t2.DATE_Z_1 and zs.DATE_Z_2=t2.DATE_Z_2 
 where z.PR_NOV = 0 --and zs.OPLATA = 1
 -- критерии определения того же счета в Витакоре
 and (t2.year <> s.year or t2.plat <> s.plat or t2.code <> s.code or t2.code_mo <> s.code_mo or t2.nschet <> s.nschet)

 -- 148 Проверка правильности заполнения PR_NOV=1
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PR_NOV', 'ZAP', zs.N_ZAP, zs.IDCASE, null, '904', 'Для исправленной записи PR_NOV="1" в базе нет отказанной первичной записи (IDCASE="'+cast(zs.IDCASE as varchar)
 +'" LPU="'+isnull(zs.lpu,'')+'" USL_OK="'+isnull(cast(zs.USL_OK as varchar),'')+'" DATE_Z_1="'+format(zs.DATE_Z_1, 'dd.MM.yyyy')+'" DATE_Z_2="'+format(zs.DATE_Z_2, 'dd.MM.yyyy')+'")'
 from tempdb..TEMP_Z_SLUCH zs
  inner join tempdb..TEMP_PACIENT p on zs.N_ZAP=p.N_ZAP
  inner join tempdb..TEMP_ZAP z on zs.N_ZAP=z.N_ZAP
  inner join tempdb..TEMP_SCHET s on s.PLAT in ('40001','40002', '40004')
where not exists(select top 1 bzs.IDCASE from [IES].[T_SCHET_SLUCH_ACCOMPLISHED] bzs
  inner join [IES].[T_SCHET_ZAP] bz on  bzs.SchetZap=bz.SchetZapID
  inner join [IES].[T_SCHET] sc on bz.Schet=sc.SchetID  and sc.IsDelete=0  and sc.type_ in (693,554) 
   where bzs.SUMP=0 and 
   s.plat=sc.plat and zs.IDCASE=bzs.IDCASE and zs.lpu=bzs.lpu and zs.USL_OK=bzs.USL_OK and zs.DATE_Z_1=bzs.DATE_Z_1 and zs.DATE_Z_2=bzs.DATE_Z_2)
 and z.PR_NOV = 1

 -- 148.1 Проверка правильности заполнения PR_NOV=1 в связке с SUMP>0
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PR_NOV', 'ZAP', zs.N_ZAP, zs.IDCASE, null, '904', 'Нельзя выставить отказаную неисправленную запись на первичную отказанную запись.'
 from tempdb..TEMP_Z_SLUCH zs
  inner join tempdb..TEMP_PACIENT p on zs.N_ZAP=p.N_ZAP
  inner join tempdb..TEMP_ZAP z on zs.N_ZAP=z.N_ZAP
  inner join tempdb..TEMP_SCHET s on s.PLAT in ('40001','40002', '40004')
where  z.PR_NOV = 1 and zs.SUMP=0
--and exists(select top 1 bzs.IDCASE from [IES].[T_SCHET_SLUCH_ACCOMPLISHED] bzs
--  inner join [IES].[T_SCHET_ZAP] bz on  bzs.SchetZap=bz.SchetZapID
--  inner join [IES].[T_SCHET] sc on bz.Schet=sc.SchetID  and sc.IsDelete=0  and sc.type_ in (693,554) 
--   where bzs.SUMP=0 and bz.PR_NOV=0 and
--   s.plat=sc.plat and zs.IDCASE=bzs.IDCASE and zs.lpu=bzs.lpu and zs.USL_OK=bzs.USL_OK and zs.DATE_Z_1=bzs.DATE_Z_1 and zs.DATE_Z_2=bzs.DATE_Z_2)



 -- 148.2 Проверка повторных исправленных записей
  insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PR_NOV', 'ZAP', zs.N_ZAP, zs.IDCASE, null, '904', 'Нельзя выставить исправленную запись, исправленная запись уже была загружена ранее.'
 from tempdb..TEMP_Z_SLUCH zs
  inner join tempdb..TEMP_PACIENT p on zs.N_ZAP=p.N_ZAP
  inner join tempdb..TEMP_ZAP z on zs.N_ZAP=z.N_ZAP
  inner join tempdb..TEMP_SCHET s on s.PLAT in ('40001','40002', '40004')
  inner join tempdb..TEMP_ZGLV sg on sg.FILENAME like '%T40_%'
where exists(select top 1 bzs.IDCASE from [IES].[T_SCHET_SLUCH_ACCOMPLISHED] bzs
  inner join [IES].[T_SCHET_ZAP] bz on  bzs.SchetZap=bz.SchetZapID
  inner join [IES].[T_SCHET] sc on bz.Schet=sc.SchetID  
   where bzs.SUMP>0 and bz.PR_NOV=1 and sc.IsDelete=0  and sc.type_ in (693,554)  and
   s.plat=sc.plat and zs.IDCASE=bzs.IDCASE and zs.lpu=bzs.lpu and zs.USL_OK=bzs.USL_OK and zs.DATE_Z_1=bzs.DATE_Z_1 and zs.DATE_Z_2=bzs.DATE_Z_2
   and (sc.year <> s.year or sc.plat <> s.plat or sc.code <> s.code or sc.code_mo <> s.code_mo or sc.nschet <> s.nschet)) --- для замены счета
 and z.PR_NOV = 1 and zs.SUMP>0
 and @schet_coments not like '%+ проверки%'
union 
--  insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PR_NOV', 'ZAP', zs.N_ZAP, zs.IDCASE, null, '904', 'Нельзя выставить исправленную запись, исправленная запись уже была загружена ранее.'
 from tempdb..TEMP_Z_SLUCH zs
  inner join tempdb..TEMP_PACIENT p on zs.N_ZAP=p.N_ZAP
  inner join tempdb..TEMP_ZAP z on zs.N_ZAP=z.N_ZAP
  inner join tempdb..TEMP_SCHET s on s.PLAT in ('40001','40002', '40004')
  inner join (select sc.year, sc.code_mo, sc.CODE, sc.NSCHET, sc.DSCHET, sc.plat, bzs.IDCASE, bzs.lpu, bzs.USL_OK, bzs.DATE_Z_1, bzs.DATE_Z_2 from [IES].[T_SCHET_SLUCH_ACCOMPLISHED] bzs
  inner join [IES].[T_SCHET_ZAP] bz on  bzs.SchetZap=bz.SchetZapID
  inner join [IES].[T_SCHET] sc on bz.Schet=sc.SchetID  and sc.IsDelete=0  and sc.type_ = @type
  where bz.PR_NOV=1) t2
   on s.plat=t2.plat and zs.IDCASE=t2.IDCASE and zs.lpu=t2.lpu and zs.USL_OK=t2.USL_OK and zs.DATE_Z_1=t2.DATE_Z_1 and zs.DATE_Z_2=t2.DATE_Z_2 
where 
  z.PR_NOV = 1 --and zs.SUMP>0
 and (t2.year <> s.year or t2.plat <> s.plat or t2.code <> s.code or t2.code_mo <> s.code_mo or t2.nschet <> s.nschet)
 and @schet_coments not like '%+ проверки%'

  -- 172 Проверка повторной загрузки записей в базу
--insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
-- select 'Z_SL', 'ZAP', zs.N_ZAP, zs.IDCASE, null, '904', 'Запись для данного пациента с одинаковыми периодами лечения была загружена ранее'
-- from tempdb..TEMP_Z_SLUCH zs
--  inner join tempdb..TEMP_SLUCH ss on zs.IDCASE=ss.IDCASE
--  inner join tempdb..TEMP_PACIENT p on zs.N_ZAP=p.N_ZAP
--  inner join tempdb..TEMP_PERS pp on cast(p.ID_PAC as varchar)=cast(pp.ID_PAC as varchar)
--  inner join tempdb..TEMP_ZAP z on zs.N_ZAP=z.N_ZAP
--  inner join tempdb..TEMP_SCHET s on s.PLAT in ('40001','40002')
--  inner join tempdb..TEMP_ZGLV zglv on zglv.FILENAME like '%S4000%'
--  inner join [IES].[T_SCHET] bsc on bsc.PLAT = s.plat and substring(bsc.FILENAME,1,3)= substring(zglv.FILENAME,1,3) and bsc.IsDelete=0 and bsc.type_ in (693) and bsc.MONTH between month(dateadd(mm,-3,getdate())) and month(getdate())
--  inner join [IES].[T_SCHET_ZAP] bz on bz.Schet=bsc.SchetID and pp.FAM=bz.FAM and pp.IM=bz.im and ISNULL(pp.OT, '')=ISNULL(bz.OT, '') and CONVERT(VARCHAR, pp.DR, 112)=CONVERT(VARCHAR, bz.DR, 112) and z.PR_NOV=bz.PR_NOV
--  inner join [IES].[T_SCHET_SLUCH_ACCOMPLISHED] bzs on bzs.SchetZap=bz.SchetZapID and zs.lpu=bzs.lpu and zs.USL_OK=bzs.USL_OK and zs.DATE_Z_1=bzs.DATE_Z_1 and zs.DATE_Z_2=bzs.DATE_Z_2
--  inner join [IES].[T_SCHET_SLUCH] bs on bs.SchetSluchAccomplished=bzs.SchetSluchAccomplishedID and bs.DS1=ss.DS1 and bs.PRVS=ss.PRVS
--where bs.DS1 is not null

--insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
-- select 'Z_SL', 'ZAP', zs.N_ZAP, zs.IDCASE, null, '904', 'Запись для данного пациента с одинаковыми периодами лечения была загружена ранее'
-- from tempdb..TEMP_Z_SLUCH zs
--  inner join tempdb..TEMP_SLUCH ss on zs.IDCASE=ss.IDCASE
--  inner join tempdb..TEMP_PACIENT p on zs.N_ZAP=p.N_ZAP
--  inner join tempdb..TEMP_PERS pp on cast(p.ID_PAC as varchar)=cast(pp.ID_PAC as varchar)
--  inner join tempdb..TEMP_ZAP z on zs.N_ZAP=z.N_ZAP
--  inner join tempdb..TEMP_SCHET s on s.PLAT in ('40001','40002')
--where exists(select top 1 bzs.IDCASE from [IES].[T_SCHET_SLUCH_ACCOMPLISHED] bzs
--  inner join [IES].[T_SCHET_SLUCH] bss on bzs.IDCASE=bss.IDCASE
--  inner join [IES].[T_SCHET_ZAP] bz on  bzs.SchetZap=bz.SchetZapID
--  inner join [IES].[T_SCHET] bsc on bsc.PLAT in ('40001','40002') and bsc.IsDelete=0 and bsc.type_ in (693,554) and bsc.MONTH between month(dateadd(mm,-3,getdate())) and month(getdate())
--   where 
--   s.plat=bsc.plat and zs.lpu=bzs.lpu and zs.USL_OK=bzs.USL_OK and zs.DATE_Z_1=bzs.DATE_Z_1 and zs.DATE_Z_2=bzs.DATE_Z_2 
--   and UPPER(pp.FAM + pp.IM + ISNULL(pp.OT, ''))=UPPER(bz.FAM + bz.IM + ISNULL(bz.OT, '')) 
--   and CONVERT(VARCHAR, pp.DR, 112)=CONVERT(VARCHAR, bz.DR, 112)
--   and ss.DS1=bss.ds1 and z.PR_NOV=bz.PR_NOV)

 -- 172.1 Проверка повторных записей внутри одного счета
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'Z_SL', 'ZAP', zs.N_ZAP, zs.IDCASE, null, '904', 'Повторная запись для одного пациента с одинаковыми периодами лечения в одном счете'
 from tempdb..TEMP_Z_SLUCH zs
  inner join tempdb..TEMP_SLUCH ss on zs.IDCASE=ss.IDCASE
  inner join tempdb..TEMP_PACIENT p on zs.N_ZAP=p.N_ZAP
  inner join tempdb..TEMP_PERS pp on cast(p.ID_PAC as varchar)=cast(pp.ID_PAC as varchar)
  inner join tempdb..TEMP_ZAP z on zs.N_ZAP=z.N_ZAP
  inner join tempdb..TEMP_SCHET s on s.PLAT in ('40001','40002', '40004')
   where 
   zs.IDCASE!=zs.IDCASE 
   and s.plat=s.plat and zs.lpu=zs.lpu and zs.USL_OK=zs.USL_OK and zs.DATE_Z_1=zs.DATE_Z_1 and zs.DATE_Z_2=zs.DATE_Z_2 
   and UPPER(pp.FAM + pp.IM + ISNULL(pp.OT, ''))=UPPER(pp.FAM + pp.IM + ISNULL(pp.OT, '')) 
   and CONVERT(VARCHAR, pp.DR, 112)=CONVERT(VARCHAR, pp.DR, 112)
   and ss.DS1=ss.ds1
END

--=========================================================================
-- -=КОНЕЦ= Блок проверок по МТР от ЛПУ и Счетов от СМО.
--=========================================================================


--=========================================================================
-- -=НАЧАЛО= Блок проверок по МТР от ЛПУ добавленных сотрудниками КОФОМС.
--=========================================================================
if @type in (693,554,562) 
BEGIN
-- Проверка №193
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL', 'CODE_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Услуга '+u.CODE_USL+' должна оказываться при диагнозе (основном, сопутствующем или осложнения) U07.2' 
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE)
  join tempdb..TEMP_DS2 ds2 on (ds2.IDCASE=s.IDCASE)
  join tempdb..TEMP_DS3 ds3 on (ds3.IDCASE=s.IDCASE)
  join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID)  
  where u.CODE_USL in ('A26.05.076','A26.31.011','A26.31.012')
  and (s.DS1 != 'U07.2' or ds2.DS2 != 'U07.2' or ds3.DS3 != 'U07.2')
---- Проверка №192
-- insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
-- select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Длительность лечения ="'+isnull(cast((DATEDIFF(day,s.DATE_1,s.DATE_2)+1) as varchar),'')+'" не может быть меньше меньше количества дней введения препарата ('+isnull(cast(a1.DLIT as varchar),'')+')'
-- from tempdb..TEMP_Z_SLUCH zs
--  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
--  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
--  left join tempdb..TEMP_CRIT c on k.IDCASE=c.IDCASE and k.SL_ID=c.SL_ID
--  left join tempdb..TEMP_USL u on s.IDCASE=u.IDCASE and s.SL_ID=u.SL_ID
--  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
--  join iesdb.[IES].[T_GR_CRIT_DLIT] a1 on (k.N_KSG=a1.ksg OR A1.KSG IS NULL)
--											and c.CRIT = a1.sh 
--											and a1.YEAR = k.VER_KSG
--											AND ZS.USL_OK =A1.USL_OK
-- where
--	(DATEDIFF(day,s.DATE_1,s.DATE_2)+1) < a1.DLIT
--	AND C.CRIT LIKE 'SH%'
--	AND  @type = 693  

-- Проверка №191
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'N_KSG', 'KSG_ KPG', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Диагноз не соответствует услуге B01.069.096.02'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  where
	(u.code_usl = 'B01.069.096.02')
	and (s.DS1 not in ('I50.1','I44.2','I44.1','I48.0','G35','C91.1','Z94.0','Z94.1','Z94.4','Z94.8','G80','Z20.6') 
			OR s.DS1 between 'E10.00' and 'E14.99'
			OR S.DS1 between 'K74.3' and 'K74.6'
			OR S.DS1 between 'B20.00' and 'B24.99')

-- Проверка №190
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CODE_SH', CODE_SH as ZN_POL ,@NSCHET, 'LEK_PR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV,'904', 'В схеме лекарственной терапии: sh9001 или sh9002, лекарственный препарат «Золедроновая кислота» , «Деносумаб» не применяются.
не применяется.0'
from tempdb..TEMP_LEK_PR_DATE_INJ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
	t0.CODE_SH in ('sh9001', 'sh9002')
	and t0.regnum in ('000764','000895')

-- Проверка №189
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'N_KSG', 'KSG_ KPG', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Услуги к КСГ (КСЛП) B01.070.080-B01.070.439, B01.070.449-B01.070.454 применяются только при длительности лечения 70 дней и более'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  where
	((u.code_usl between 'B01.070.080' and 'B01.070.439') or (u.code_usl between 'B01.070.449' and 'B01.070.454'))
	and datediff(day,s.date_1,s.date_2) < 70


-- Проверка №188
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'N_KSG', 'KSG_ KPG', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'При расчете тарифа к КСГ "'+isnull(k.n_ksg,'')+'" не применяются доп. услуги "'+isnull(u.CODE_USL,'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  where
	((k.n_ksg between 'st19.075' and 'st19.089') or (k.n_ksg between 'ds19.050' and 'ds19.062'))
	and ((u.code_usl between 'B01.070.080' and 'B01.070.439') or (u.code_usl between 'B01.070.449' and 'B01.070.454'))

-- Проверка №187
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'N_KSG', 'KSG_ KPG', zs.N_ZAP, zs.IDCASE, null, '904','Форма помощи по данному КСГ только неотложная или экстренная'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join tempdb..TEMP_SCHET t2 on t2.code is not null
 where 
	k.n_ksg in ('st12.015', 'st12.016', 'st12.017', 'st12.018')
	and zs.for_pom not in (1,2)


-- Проверка №186
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'NPR_MO', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Код МО, направившей на плановую госпитализацию не соответствует региону страхования' 
       from tempdb..TEMP_Z_SLUCH t
	   join tempdb..TEMP_SLUCH s on (s.IDCASE=t.IDCASE) 
       left join IESDB.[IES].[T_F003_MO] f on t.NPR_MO=f.mcod and t.NPR_DATE between f.D_BEGIN and isnull(f.D_END,t.NPR_DATE)
	   join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C','T')
      where t.npr_mo is not null
		and @type = 554
		and f.TF_OKATO = 29000
		and t.FOR_POM = 3
		and t.USL_OK in (1,2)
		and s.COMENTSL is null

-- Проверка №185
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'N_KSG', 'KSG_ KPG', zs.N_ZAP, zs.IDCASE, null, '904','Запрещена госпитализация пациентов с легкой формой коронавирусной инфекции с 12.12.2020 в соответствии с приказом МЗ КО №1504'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join tempdb..TEMP_SCHET t2 on t2.code is not null
 where 
	t2.code_mo = '400006'
	and k.n_ksg = 'st12.013.4'
	and zs.date_z_1 >='12.12.2020'
-- Проверка №184
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL_OK', 'Z_SL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Код услуги "'+isnull(u.CODE_USL,'')+'" не соответствует условиям оказания "'+isnull(cast(zs.usl_ok as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  left join [IES].[T_CHER_USL_TARIF] t on isnull(t.LPU, u.LPU) = u.LPU and t.USL_CODE=u.code_usl and u.date_out between t.DATE_B and t.DATE_E and t.k_tarif = u.TARIF and zs.usl_ok = t.usl_ok
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C','D')
 where 
	t.usl_code is null
	and k.n_ksg is null
-- Проверка №183
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDSL', 'SL_KOEF', zs.N_ZAP, zs.IDCASE, null, '904', 'Для КСГ '+k.n_ksg+' нельзя использовать группу 10 КСЛП (Сверхдлительные сроки госпитализации)'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_SL_KOEF sl on sl.IDCASE=s.IDCASE and sl.SL_ID=s.SL_ID
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
  left join [IES].[R_NSI_KSLP] t on t.IDSL=sl.IDSL and t.ZKOEF=sl.Z_SL and s.DATE_2 between t.DATE_BEGIN and t.DATE_END
  left join IES.R_NSI_KSLP_GROUPS t1 ON t1.DictionaryBaseID = t.NPR
 where (k.n_ksg between 'st19.039' and 'st19.055' or k.n_ksg between 'ds19.001' and 'ds19.015')
		and t1.NPR_ID =10

-- Проверка №182
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'SL', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'КСГ № '+t.N_KSG+' с услугой A16.12.063 не может сочетаться с кодами МКБ  С00-С99, D00-D09 и профилем "онкология"'
from tempdb..TEMP_SLUCH s
  join tempdb..TEMP_Z_SLUCH zs on zs.IDCASE=s.IDCASE
  join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  join tempdb..TEMP_KSG_KPG t on (s.IDCASE=t.IDCASE and s.SL_ID=t.SL_ID)
WHERE
	s.DATE_2>='01.11.2020'
	and ((t.N_KSG='ds25.003' or t.N_KSG='st25.009') and u.CODE_USL='A16.12.063') 
	and ((s.ds1 between 'C00' and 'C99' or s.ds1 between 'D00' and 'D09') and s.profil=60)

-- Проверка 181
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'KSG_PG', 'KSG_KPG', t1.N_ZAP, t1.IDCASE, null, '904', 'Для N_KSG="'+isnull(cast(t0.N_KSG as varchar),'')+'" KSG_PG должен быть равен 1'
from tempdb..TEMP_KSG_KPG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
len(t0.N_KSG) > 8
and t0.KSG_PG != 1 
and getdate()>='15.06.2020'

-- Проверка №180
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL_TIP', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Для N_KSG="'+isnull(cast(t1.N_KSG as varchar),'')+'" нельзя применять USL_TIP="'+isnull(cast(t2.USL_TIP as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL t on (t.IDCASE=zs.IDCASE)
  join tempdb..TEMP_ONK_USL t2 on (t.IDCASE=t2.IDCASE and t.SL_ID=t2.SL_ID)  
  join tempdb..TEMP_KSG_KPG t1 on (t.IDCASE=t1.IDCASE and t.SL_ID=t1.SL_ID) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C')
  join [IESDB].[IES].[KSG_N013] b on b.KSG=t1.N_KSG
 where t1.N_KSG in (select KSG from [IESDB].[IES].[KSG_N013])
   and t1.N_KSG not in (select KSG from [IESDB].[IES].[KSG_N013] where t2.USL_TIP=b.N013 and t1.N_KSG = b.KSG)
   and getdate()>='15.06.2020'

-- Проверка №179
 insert into #Errors (IM_POL, BASE_EL, NSCHET, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'MONTH', 'SCHET', s.NSCHET, s.CODE, null, '904', 'Отчётный период ещё не закончен'
 from tempdb..TEMP_SCHET s
	where --(s.month >= datepart(month,Getdate()))
	      ((s.year = datepart(year,Getdate()) and (s.month >= datepart(month,Getdate())))
	      or (s.year < datepart(year,Getdate()) and s.month>12))
	and @type = 554

-- Проверка №176
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'VBR', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Услуга CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не соответствует признаку мобильной  бригады VBR="'+isnull(cast(zs.VBR as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on s.IDCASE=zs.IDCASE
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
  join  tempdb..TEMP_USL t1 on s.IDCASE=t1.IDCASE and s.SL_ID=t1.SL_ID
  join [IES].[R_NSI_USL_V001] t3 on t1.CODE_USL=t3.CODE_USL and t3.USL_OK in (3,4)
 where t3.F_AKTUAL = 1  and zs.USL_OK in (3,4)
 AND ((zs.VBR = 1 AND t3.name_usl not like '%мобильн%')
   OR (zs.VBR = 0 AND t3.name_usl like '%мобильн%'))

-- Проверка №175
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_R', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Не заполнено Вид назначения [1..6] для групп здровья кроме I и II'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
  inner join tempdb..TEMP_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
 where zs.rslt_d not in (1,2) and isnull(n.NAZ_R,0) not in (1,2,3,4,5,6)
 
-- Проверка №174 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'OS_SLUCH', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При отсутствии отчества в документе, удостоверяющем личность пациента /родителя поле OS_SLUCH = 2'
  from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_PACIENT t on t.N_ZAP=zs.N_ZAP 
  join tempdb..TEMP_PERS ps on cast(t.ID_PAC as varchar)=cast(ps.ID_PAC as varchar) 
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','T','C','D')
 where (zs.os_sluch != 2 and ps.ot is null and t.NOVOR = 0)
	--or (zs.os_sluch != 2 and ps.OT_P is null) 
	or (zs.os_sluch = 2 and ps.ot is not null)
	--or (zs.os_sluch = 2 and ps.OT_P is not null)
	and @type = 554


-- Проверка №173 соответствие Code_sh - Regnum
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_SH', 'LEK_PR', zs.N_ZAP, zs.IDCASE, null, '904', 'Схема лекарственной терапии "'+isnull(cast(t2.CODE_SH as varchar),'')+'" не соответствует идентификатору лекарственного препарата"'+isnull(cast(t2.REGNUM as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL t1 on t1.IDCASE=zs.IDCASE
  join tempdb..TEMP_ONK_USL uo on uo.idcase=t1.idcase and uo.SL_ID=t1.SL_ID
  join tempdb..TEMP_LEK_PR_DATE_INJ t2 on uo.idcase=t2.idcase and uo.SL_ID=t2.SL_ID --and uo.IDSERV=t2.IDSERV
  left join [IES].T_N020_ONK_LEKP t4 on t2.REGNUM=t4.ID_LEKP and zs.DATE_Z_2 between t4.DATEBEG and isnull(t4.DATEEND,zs.DATE_Z_2)
  left join [IES].T_N021_ONK_LPSH t3 on t2.CODE_SH=t3.CODE_SH and t4.N020OnkLekpID=t3.ID_LEKP and zs.DATE_Z_2 between t3.DATEBEG and isnull(t3.DATEEND,zs.DATE_Z_2)
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where t3.CODE_SH is not null and t3.ID_LEKP is null
-- Проверка №171 соответствия DIAG_CODE диагнозу
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DIAG_CODE', 'B_DIAG', z.n_zap, t.idcase, null, '904',  'Значение Кода диагностического показателя (DIAG_CODE) "'+ isnull(cast(t.DIAG_CODE as varchar),'')+'" не найдено в справочнике N009 для кода диагноза (DS1) "'+ isnull(cast(z.DS1 as varchar),'')+'"'
 from tempdb..TEMP_B_DIAG t
  join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
  left join [IES].[T_N007_MRF] t2 on t2.ID_Mrf=t.DIAG_CODE
  left join [IES].[T_N009_MRT_DS] t1 on t1.N007Mrf=t2.N007MrfID and t.DIAG_DATE between t1.DATEBEG and isnull(t1.DATEEND,t.DIAG_DATE)
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where (t1.ID_M_D is null)
  and (t.DIAG_RSLT is not null or t.DIAG_CODE is not null)
  and ((substring(z.DS1,1,3)=t1.DS_Mrf and t1.N007Mrf=t2.N007MrfID) or (substring(z.DS1,1,3) not in (select t2.DS_Mrf from [IES].[T_N009_MRT_DS] t2)))
-- Проверка №170 признака внутрибольничного перевода
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'VB_P', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Признак внутрибольничного перевода может быть равен только "1"'
 from tempdb..TEMP_Z_SLUCH zs
 where zs.VB_P is not null 
		and zs.VB_P !=1
-- Проверка №169 пересечения случаев по датам
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SL', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Законченный случай не может содержать случаи с пересекающимися датами лечения'
 from tempdb..TEMP_SLUCH s
  join tempdb..TEMP_Z_SLUCH zs on zs.IDCASE=s.IDCASE
  join tempdb..TEMP_KSG_KPG t on (s.IDCASE=t.IDCASE and s.SL_ID=t.SL_ID)
  join tempdb..TEMP_SLUCH s1 on s.IDCASE=s1.IDCASE and s.SL_ID!=s1.SL_ID
  join tempdb..TEMP_KSG_KPG t1 on (s.IDCASE=t1.IDCASE and s.SL_ID=t1.SL_ID) 
WHERE
((s1.DATE_1<s.DATE_2 and s1.DATE_1>=s.DATE_1) and (s1.DATE_2!=s.DATE_1)) 
and (t.N_KSG=t1.N_KSG or t.N_KSG!=t1.N_KSG )

-- Проверка №168.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'Z_SL', 'VNOV_M', ss.N_ZAP, ss.IDCASE,  null,  '905', 'Элемент VNOV_M="'+isnull(cast(ss.VNOV_M as varchar),'')+'" имеет не допустимое значение'
 from tempdb..TEMP_PACIENT z
  join tempdb..TEMP_Z_SLUCH ss on ss.n_zap = z.n_zap
 where ss.VNOV_M < 300 or ss.VNOV_M > 2500

-- Проверка №168 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'Z_SL', 'VNOV_M', ss.N_ZAP, ss.IDCASE,  null,  '905', 'Элемент VNOV_M должен отсутствовать при наличии элемента VNOV_D'
 from tempdb..TEMP_PACIENT z
  join tempdb..TEMP_Z_SLUCH ss on ss.n_zap = z.n_zap
 where ss.VNOV_M is not null and z.VNOV_D is not null

-- Проверка №167.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'Z_SL', 'VNOV_D', ss.N_ZAP, ss.IDCASE,  null,  '905', 'Элемент VNOV_D="'+isnull(cast(z.VNOV_D as varchar),'')+'" имеет не допустимое значение'
 from tempdb..TEMP_PACIENT z
  join tempdb..TEMP_Z_SLUCH ss on ss.n_zap = z.n_zap
 where z.VNOV_D < 300 or z.VNOV_D > 2500

-- Проверка №167 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'Z_SL', 'VNOV_D', ss.N_ZAP, ss.IDCASE,  null,  '905', 'Элемент VNOV_D должен отсутствовать при NOVOR=0 или при наличии элемента VNOV_M'
 from tempdb..TEMP_PACIENT z
  join tempdb..TEMP_Z_SLUCH ss on ss.n_zap = z.n_zap
 where (z.NOVOR=0 or ss.VNOV_M is not null) and z.VNOV_D is not null


-- Проверка №164 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SANK_IT', 'Z_SL', z.N_ZAP, z.IDCASE, null, '905', 'Сумма санкций SANK_IT не равна SUMV-SUMP'
 from tempdb..TEMP_Z_SLUCH z
 where isnull(SANK_IT,0) <> SUMV-isnull(SUMP,0)
   and @type in (693) and @isMoToSmo = 0

-- Проверка №163 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_Z_2', 'Z_SL', ss.N_ZAP, ss.IDCASE, null, '905', 'Случаи лечения ранее 01.01.2019 не могут передаваться в данном формате'
 from tempdb..TEMP_Z_SLUCH ss
 where ss.DATE_Z_2 < '01.01.2019'
   and @type in (693,554,562)

-- Проверка №163 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DR', 'PERS', zs.N_ZAP, zs.IDCASE, null, '904', 'Дата рождения DR больше даты оказания услуги.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_PACIENT t on t.N_ZAP=zs.N_ZAP 
  join tempdb..TEMP_PERS s on cast(t.ID_PAC as varchar)=cast(s.ID_PAC as varchar) 
 where  s.DR > zs.DATE_Z_1
  

-- Проверка №160.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SCHET', 'S_OSN', ss.N_ZAP, ss.IDCASE,  null,  '905', 'Обязательно к заполнению в соответствии с F014 (Классификатор причин отказа в оплате медицинской помощи, Приложение А), если S_SUM не равна 0'
 from tempdb..TEMP_SANK s
  join tempdb..TEMP_Z_SLUCH ss on ss.IDCASE = s.IDCASE 
 where s.S_OSN is null and s.S_SUM <> 0

-- Проверка №160 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'S_TIP', 'SANK', z.N_ZAP, z.IDCASE, null, '905', 'Значение S_OSN="'+isnull(cast(s.S_OSN as varchar),'')+'" не соответствует допустимому значению  в справочнике F014'
 from tempdb..TEMP_Z_SLUCH z
  join tempdb..TEMP_SANK s on z.IDCASE=s.IDCASE
  LEFT JOIN [IES].T_F014_DENY_REASON f014 on f014.Kod = s.[S_OSN] and  z.DATE_Z_2 between DATEBEG and isnull(DATEEND,z.DATE_Z_2)
 where f014.F014DenyReasonID is null

-- Проверка №159 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'S_TIP', 'SANK', z.N_ZAP, z.IDCASE, null, '905', 'Значение S_TIP="'+isnull(cast(s.S_TIP as varchar),'')+'" не соответствует допустимому значению  в справочнике F006'
 from tempdb..TEMP_Z_SLUCH z
  join tempdb..TEMP_SANK s on z.IDCASE=s.IDCASE
  LEFT JOIN [IES].[T_F006_CONTROL_TYPE] f006 on f006.S_TIP = s.[S_TIP] and  z.DATE_Z_2 between DATEBEG and isnull(DATEEND,z.DATE_Z_2)
 where f006.S_TIP is null

 -- Проверка №158 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'SPOLIS', 'PACIENT', t.n_zap, z.idcase, null, '904',  'Серия полиса должна быть пустой при VPOLIS="3"' 
       from tempdb..TEMP_Z_SLUCH z
	    join tempdb..TEMP_PACIENT t on z.N_ZAP=t.N_ZAP
      where t.VPOLIS=3 and t.SPOLIS is not null

-- Проверка №157.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'REC_RSLT', 'B_DIAG', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректное значение признака получения результата диагностики REC_RSLT="'+isnull(cast(t2.REC_RSLT as varchar),'')+'".'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_B_DIAG t2 on (t.IDCASE=t2.IDCASE and t.SL_ID=t2.SL_ID ) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where isnull(t2.REC_RSLT,1) != 1

-- Проверка №157 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'REC_RSLT', 'B_DIAG', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан признак получения результата диагностики (REC_RSLT).'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_B_DIAG t2 on (t.IDCASE=t2.IDCASE and t.SL_ID=t2.SL_ID ) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where isnull(t2.REC_RSLT,0) != 1 and t2.DIAG_RSLT is not null
 
-- Проверка №153.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'K_FR', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Для USL_OK="'+isnull(cast(t1.USL_TIP as varchar),'')+'" количество фракций проведенной лучевой терапии (K_FR) должно быть пустым.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ONK_USL t1 on (t.IDCASE=t1.IDCASE and t.SL_ID=t1.SL_ID) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where t1.USL_TIP not in (3,4) and t.K_FR is not null
 
 
-- Проверка №156.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'BSA', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Площадь тела имеет недопустимое значение BSA="'+isnull(cast(t.BSA as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
   and (t.BSA > 6) 

-- Проверка №156 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'BSA', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указана площадь поверхности тела  (BSA).'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG t1 on (t.IDCASE=t1.IDCASE and t.SL_ID=t1.SL_ID) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where t1.N_KSG in ('st19.027','st19.028','st19.029','st19.030','st19.031','st19.032','st19.033','st19.034','st19.035','st19.036',
                    'st19.039','st19.040','st19.041','st19.042','st19.043','st19.044','st19.045','st19.046','st19.047','st19.048',
					'st19.049','st19.050','st19.051','st19.052','st19.053','st19.054','st19.055',
					'ds19.001','ds19.002','ds19.003','ds19.004','ds19.005','ds19.006','ds19.007','ds19.008','ds19.009','ds19.010',
					'ds19.011','ds19.012','ds19.013','ds19.014','ds19.015','ds19.018','ds19.019','ds19.020','ds19.021','ds19.022',
					'ds19.023','ds19.024','ds19.025','ds19.026','ds19.027')
   and (t.BSA is null or t.BSA = 0) 
   and exists (select 1 from tempdb..TEMP_ONK_USL q1 where (t.IDCASE=q1.IDCASE and t.SL_ID=q1.SL_ID and q1.USL_TIP in (2,4)) )

-- Проверка №155.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'HEI', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Рост тела имеет недопустимое значение HEI="'+isnull(cast(t.HEI as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
   and (t.HEI < 50 or t.HEI > 260) 

-- Проверка №155 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'HEI', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан рост (HEI).'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG t1 on (t.IDCASE=t1.IDCASE and t.SL_ID=t1.SL_ID) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where t1.N_KSG in ('st19.027','st19.028','st19.029','st19.030','st19.031','st19.032','st19.033','st19.034','st19.035','st19.036',
                    'st19.039','st19.040','st19.041','st19.042','st19.043','st19.044','st19.045','st19.046','st19.047','st19.048',
					'st19.049','st19.050','st19.051','st19.052','st19.053','st19.054','st19.055',
					'ds19.001','ds19.002','ds19.003','ds19.004','ds19.005','ds19.006','ds19.007','ds19.008','ds19.009','ds19.010',
					'ds19.011','ds19.012','ds19.013','ds19.014','ds19.015','ds19.018','ds19.019','ds19.020','ds19.021','ds19.022',
					'ds19.023','ds19.024','ds19.025','ds19.026','ds19.027')
   and (t.HEI is null or t.HEI = 0) 
   and exists (select 1 from tempdb..TEMP_ONK_USL q1 where (t.IDCASE=q1.IDCASE and t.SL_ID=q1.SL_ID and q1.USL_TIP in (2,4)) )

-- Проверка №154.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'WEI', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Масса тела имеет недопустимое значение WEI="'+isnull(cast(t.WEI as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
   and (t.WEI < 5 or t.WEI > 600) 
 


-- Проверка №154 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'WEI', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указана масса тела (WEI).'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG t1 on (t.IDCASE=t1.IDCASE and t.SL_ID=t1.SL_ID) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where t1.N_KSG in ('st19.027','st19.028','st19.029','st19.030','st19.031','st19.032','st19.033','st19.034','st19.035','st19.036',
                    'st19.039','st19.040','st19.041','st19.042','st19.043','st19.044','st19.045','st19.046','st19.047','st19.048',
					'st19.049','st19.050','st19.051','st19.052','st19.053','st19.054','st19.055',
					'ds19.001','ds19.002','ds19.003','ds19.004','ds19.005','ds19.006','ds19.007','ds19.008','ds19.009','ds19.010',
					'ds19.011','ds19.012','ds19.013','ds19.014','ds19.015','ds19.018','ds19.019','ds19.020','ds19.021','ds19.022',
					'ds19.023','ds19.024','ds19.025','ds19.026','ds19.027')
   and (t.WEI is null or t.WEI = 0) 
   and exists (select 1 from tempdb..TEMP_ONK_USL q1 where (t.IDCASE=q1.IDCASE and t.SL_ID=q1.SL_ID and q1.USL_TIP in (2,4)) )


---- Проверка №153 по базе в ОРАКЛЕ 
-- insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
-- select 'TARIF', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указано количество фракций проведенной лучевой терапии (K_FR).'
-- from tempdb..TEMP_Z_SLUCH zs
--  join tempdb..TEMP_ONK_SL t on (t.IDCASE=zs.IDCASE) 
--  join tempdb..TEMP_ONK_USL t1 on (t.IDCASE=t1.IDCASE and t.SL_ID=t1.SL_ID) 
--  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
-- where t1.USL_TIP in (3,4) and t.K_FR is null
 

-- Проверка №152 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'TARIF', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан тариф по случаю.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where (t.tarif is null or t.tarif=0) and 
  (substring(t.ds1,1,1) = 'C' or t.ds1 between 'D00' and 'D09.99' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS2 from tempdb..TEMP_DS2 ds where (ds.DS2 between 'C00' and 'C80.9' or  ds.ds2 between 'C97' and 'C97.9')))) 
  

-- Проверка №151.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CONS', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Блок CONS должен быть пустым.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  left join tempdb..TEMP_CONS t1 on t.IDCASE=t1.IDCASE and t.SL_ID=t1.SL_ID
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where t1.PR_CONS is not null and not (
  (substring(t.ds1,1,1) = 'C' or t.ds1 between 'D00' and 'D09.99' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS2 from tempdb..TEMP_DS2 ds where (ds.DS2 between 'C00' and 'C80.9' or  ds.ds2 between 'C97' and 'C97.9')))) 
  or (t.ds_onk = 1 and SUBSTRING(z.FILENAME,1,1)='T')
  )

-- Проверка №151 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CONS', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не заполнен блок CONS'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  left join tempdb..TEMP_CONS t1 on t.IDCASE=t1.IDCASE and t.SL_ID=t1.SL_ID
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where t1.PR_CONS is null and (
  (substring(t.ds1,1,1) = 'C' or t.ds1 between 'D00' and 'D09.99' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS2 from tempdb..TEMP_DS2 ds where (ds.DS2 between 'C00' and 'C80.9' or  ds.ds2 between 'C97' and 'C97.9')))) 
  or (t.ds_onk = 1 and SUBSTRING(z.FILENAME,1,1)='T')
  )

 -- Проверка №150.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'KOL_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Значение KOL_USL не может быть пустым или равным 0'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
 where isnull(u.KOL_USL,0)=0

 -- Проверка №150 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'KOL_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Значение KOL_USL не может быть больше 1 при значениие PROFIL="'+isnull(cast(s.PROFIL as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
 where u.KOL_USL > 1 and s.profil not in (15,34,38,85,86,87,88,89,90,63,171,140)

-- Проверка №149.4 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS_ONK', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Для записи с диагнозом DS1="Z03.1" должен быть указан признак подозрения на ЗНО (DS_ONK=1)'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H')
 where t.DS1='Z03.1'
   and (@type != 693 or getdate() > '01.05.2019') 

-- Проверка №149.3 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS_ONK', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При DS_ONK="1" и посещении врача онколога должно быть направление на диагностику или на госпитальзацию'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
  left join tempdb..TEMP_NAPR n on t.IDCASE=n.IDCASE and t.SL_ID=n.SL_ID
 where t.ds_onk = 1 
   and not (isnull(n.NAPR_V,0) in (2,3,4) or zs.RSLT in (305,306,308,309))
   and t.PRVS in (9,19,41)
   and (@type != 693 or getdate() > '01.05.2019') 
	  
-- Проверка №149.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS_ONK', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При DS_ONK="1" и посещении не врача онколога должно быть направление к онкологу или на дополнительные диагностические исследования.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
  left join tempdb..TEMP_NAPR n on t.IDCASE=n.IDCASE and t.SL_ID=n.SL_ID
 where t.ds_onk = 1 
   and isnull(n.NAPR_V,0) not in (1,3)
   and t.PRVS not in (9,19,41)
   and t.PROFIL not in (78,34,38,111,106,76,123) -- исключаем профили по диагностическим мероприятиям
   and (@type != 693 or getdate() > '01.05.2019') 
	  

-- Проверка №149.1 по базе в ОРАКЛЕ для С-файлов
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS_ONK', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректное начение DS_ONK="'+isnull(cast(DS_ONK as varchar),'')+'" для DS1="'+isnull(cast(DS1 as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) and (substring(t.ds1,1,1) in ('C','D'))
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C')
 where (t.ds_onk = 0 and not (substring(t.ds1,1,1) = 'C' or t.ds1 between 'D00' and 'D09.99' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS2 from tempdb..TEMP_DS2 ds where (ds.DS2 between 'C00' and 'C80.9' or  ds.ds2 between 'C97' and 'C97.9')))) )
    or (t.ds_onk = 1 and zs.USL_OK=3 and(t.ds1 between 'D00' and 'D09.99' or t.ds1 between 'C00' and 'C80.99' or t.ds1 between 'C97' and 'C97.99') 
       and (@type != 693 or getdate() > '01.05.2019')
	  )

-- Проверка №149.1 по базе в ОРАКЛЕ для Т-файлов
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, SL_ID, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS_ONK', 'SL', zs.N_ZAP, zs.IDCASE, t.SL_ID, null, '904', 'Не корректное значение DS_ONK="'+isnull(cast(DS_ONK as varchar),'')+'" для DS1="'+isnull(cast(DS1 as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('T')
 where (t.ds_onk = 1 and (substring(t.ds1,1,1) = 'C' or t.ds1 between 'D00' and 'D09.99' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS2 from tempdb..TEMP_DS2 ds where (ds.DS2 between 'C00' and 'C80.9' or  ds.ds2 between 'C97' and 'C97.9')))) )
--   or (t.ds_onk = 1 and zs.USL_OK=3 and (t.ds1 between 'D00' and 'D09.99' or t.ds1 between 'C00' and 'C80.99' or t.ds1 between 'C97' and 'C97.99') 
       and (@type != 693 or getdate() > '01.05.2019') 
--	  )

-- Проверка №149 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS_ONK', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение DS_ONK="'+isnull(cast(DS_ONK as varchar),'')+'" не соответствует допустимому значению  в справочнике'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C','T')
 where t.ds_onk not in (0,1)

 /*
 -- Проверка №146 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Код профиля ' + cast(u.profil as varchar) + ' не соответствует виду помощи ' +cast(vidpom as varchar)+' и условию оказания '+cast(usl_ok as varchar)
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  where (usl_ok = 3 and vidpom = 12 and not u.profil in (57,58,68,97))
	or (usl_ok = 3 and vidpom = 11 and not u.profil = 42)
	or (usl_ok = 3 and not vidpom = 11 and  u.profil = 42)
	or (usl_ok = 3 and not vidpom = 12 and u.profil in (57,58,68,97))
*/
 -- Проверка №145 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'FOR_POM', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение FOR_POM="'+cast(zs.for_pom as varchar)+'" не соответствует коду услуги "'+cast(t1.CODE_USL as varchar)+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join  tempdb..TEMP_USL t1 on zs.IDCASE=t1.IDCASE
  where ((zs.USL_OK=3 and zs.FOR_POM = 2  and t1.CODE_USL not in ('B01.047.007', 'B01.050.006', 'B01.069.012', 'B01.069.090', 'B01.080.07', 'B03.059.01', 'B01.064.005', 
  'B01.064.007', 'B01.064.006', 'B01.026.070.01', 'B01.004.074.01', 'B01.001.075.01', 'B01.001.070.01', 'B01.008.074.01', 'B01.014.070.01', 'B01.014.075.01', 'B01.015.070.01', 
  'B01.023.070.01', 'B01.023.075.01', 'B01.027.072.01', 'B01.028.075.01', 'B01.029.075.01', 'B01.031.071.01', 'B01.047.071.01', 'B01.050.074.01', 'B01.053.072.01', 
  'B01.010.070.01', 'B01.057.071.01',  'B01.058.074.01', 'B01.028.070.01', 'B01.029.070.01', 'B01.044.070.01', 'B01.069.009','B03.059.03','B01.065.03','B01.070.07'))
  or (zs.USL_OK=3 and zs.FOR_POM != 2  and t1.CODE_USL in ('B01.047.007', 'B01.050.006', 'B01.069.012', 'B01.069.090', 'B01.080.07', 'B03.059.01', 'B01.064.005', 
  'B01.064.006','B01.064.007', 'B01.026.070.01', 'B01.004.074.01', 'B01.001.075.01', 'B01.001.070.01', 'B01.008.074.01', 'B01.014.070.01', 'B01.014.075.01', 'B01.015.070.01', 
  'B01.023.070.01', 'B01.023.075.01', 'B01.027.072.01', 'B01.028.075.01', 'B01.029.075.01', 'B01.031.071.01', 'B01.047.071.01', 'B01.050.074.01', 'B01.053.072.01', 
  'B01.010.070.01', 'B01.057.071.01',  'B01.058.074.01', 'B01.028.070.01', 'B01.029.070.01', 'B01.044.070.01', 'B01.069.009','B03.059.03','B01.065.03','B01.070.07'))
  ) and (@type != 693 or getdate() >= '01.03.2019')  


 -- Проверка №144 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'ID_PAC', 'PACIENT', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение ID_PAC="'+cast(t.ID_PAC as varchar(36))+'" не найдено в файле персональных данных'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_PACIENT t on zs.N_ZAP=t.N_ZAP
  where not exists (select 1 from tempdb..TEMP_PERS t1 where cast(t1.ID_PAC as varchar(36))=cast(t.ID_PAC as varchar(36))) 

-- Проверка №143.10 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Услуга CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не может оказываться в LPU="'+isnull(cast(zs.lpu as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join  tempdb..TEMP_USL t1 on s.IDCASE=t1.IDCASE and s.SL_ID=t1.SL_ID
 where t1.CODE_USL in ('A09.30.090','A09.30.091','A09.30.092','A09.30.093','A12.31.002','A12.31.004','A12.31.007','A12.31.008') and zs.LPU not in ('400003','400109','400001')
   or t1.CODE_USL in ('A06.20.004.092','A06.20.004.093','A06.20.006.06.07','A07.03.001','A07.14.002','A07.22.002','A07.28.004') and zs.LPU not in ('400003','400109')
   or t1.CODE_USL in ('A08.20.004.002') and zs.LPU not in ('400003')

-- Проверка №143.9 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Услуга CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не может оказываться пациентам c W="'+isnull(cast(s1.W as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_PACIENT t on t.N_ZAP=zs.N_ZAP 
  join tempdb..TEMP_PERS s1 on cast(t.ID_PAC as varchar)=cast(s1.ID_PAC as varchar) 
  join  tempdb..TEMP_USL t1 on s.IDCASE=t1.IDCASE and s.SL_ID=t1.SL_ID
  join [IES].[R_NSI_USL_V001] t3 on t1.CODE_USL=t3.CODE_USL and t3.USL_OK in (3,4)
 where t3.F_AKTUAL = 1 and t3.W is not null
   and s1.W != t3.W
   and zs.USL_OK in (3,4)

-- Проверка №143.8 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Услуга CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не может оказываться пациентам в возрасте "'+isnull(cast(DATEDIFF(DAY,DR,DATE_2)/365.2425 as varchar),'')+'" лет'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_PACIENT t on t.N_ZAP=zs.N_ZAP 
  join tempdb..TEMP_PERS s1 on cast(t.ID_PAC as varchar)=cast(s1.ID_PAC as varchar) 
  join  tempdb..TEMP_USL t1 on s.IDCASE=t1.IDCASE and s.SL_ID=t1.SL_ID
  join [IES].[R_NSI_USL_V001] t3 on t1.CODE_USL=t3.CODE_USL and t3.USL_OK in (3,4)
 where t3.F_AKTUAL = 1 
   and DATEDIFF(DAY,DR,DATE_1)/365.2425 not between t3.VOZ_MIN and t3.VOZ_MAX
   and zs.USL_OK in (3,4)
    AND (zs.OPLATA <> 2 OR zs.oplata IS null)

-- Проверка №143.7 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Услуга CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не может оказываться при P_CEL="'+isnull(cast(s.P_CEL as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join  tempdb..TEMP_USL t1 on s.IDCASE=t1.IDCASE and s.SL_ID=t1.SL_ID
  join [IES].[R_NSI_USL_V001] t3 on t1.CODE_USL=t3.CODE_USL and t3.USL_OK in (3,4)
  LEFT JOIN IES.T_V025_KPC t9 ON t9.V025KpcID = t3.P_CEL
 where t3.F_AKTUAL = 1 
   and (isnull(cast(t9.IDPC as varchar(50)),t3.P_CEL_T) not like '%'+s.P_CEL+'%')
   and (t3.P_CEL is not null or t3.P_CEL_T is not null)
   and zs.USL_OK in (3,4)
    AND (zs.OPLATA <> 2 OR zs.oplata IS null)

-- Проверка №143.6 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Услуга CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не может оказываться при IDSP="'+isnull(cast(zs.IDSP as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join  tempdb..TEMP_USL t1 on s.IDCASE=t1.IDCASE and s.SL_ID=t1.SL_ID
  join [IES].[R_NSI_USL_V001] t3 on t1.CODE_USL=t3.CODE_USL and t3.USL_OK in (3,4)
  LEFT JOIN IES.T_V010_PAY t8 ON t8.V010PayID = t3.V010Pay
 where t3.F_AKTUAL = 1 
   and (case when t3.IDSP_T  is null then cast(t8.IDSP as varchar) end not like '%'+cast(zs.IDSP as varchar)+'%')
   and (t3.V010Pay is not null or t3.IDSP_T is not null)
   and zs.USL_OK in (3,4)
    AND (zs.OPLATA <> 2 OR zs.oplata IS null)

-- Проверка №143.5 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Услуга CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не может оказываться при PRVS="'+isnull(cast(s.PRVS as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join  tempdb..TEMP_USL t1 on s.IDCASE=t1.IDCASE and s.SL_ID=t1.SL_ID
  join [IES].[R_NSI_USL_V001] t3 on t1.CODE_USL=t3.CODE_USL and t3.USL_OK in (3,4)
  join [IES].[T_V021_MED_SPEC] sp on t3.PRVS=sp.IDSPEC
 where t3.F_AKTUAL = 1 
   and (case when sp.CODE_SPEC is null then t3.PRVS_T else cast(sp.CODE_SPEC as varchar) end not like '%'+cast(s.PRVS as varchar)+'%')
   and (sp.CODE_SPEC is not null or t3.PRVS_T is not null)
   and zs.USL_OK in (3,4)
    AND (zs.OPLATA <> 2 OR zs.oplata IS null)

-- Проверка №143.4 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Услуга CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не может оказываться при PROFIL="'+isnull(cast(s.PROFIL as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join  tempdb..TEMP_USL t1 on s.IDCASE=t1.IDCASE and s.SL_ID=t1.SL_ID
  join [IES].[R_NSI_USL_V001] t3 on t1.CODE_USL=t3.CODE_USL and t3.USL_OK in (3,4)
 where t3.F_AKTUAL = 1 
   and (case when t3.PROFIL_V002 is null then t3.PROFIL_T else cast(t3.PROFIL_V002 as varchar) end not like '%'+cast(s.PROFIL as varchar)+'%')
   and (t3.PROFIL_V002 is not null or t3.PROFIL_T is not null)
   and zs.USL_OK in (3,4)
    AND (zs.OPLATA <> 2 OR zs.oplata IS null)

-- Проверка №143.3 по базе в ОРАКЛЕ
-- -- убрать костыль на 11 Vidpom 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 SELECT 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, NULL, '904', 'Услуга CODE_USL="' + ISNULL(CAST(t1.CODE_USL AS VARCHAR), '') + '" не может оказываться при VIDPOM="' + ISNULL(CAST(zs.VIDPOM AS VARCHAR), '') + '"'
       FROM   tempdb..TEMP_Z_SLUCH zs
       JOIN tempdb..TEMP_USL t1 ON zs.IDCASE = t1.IDCASE
       JOIN [IES].[R_NSI_USL_V001] t3 ON t1.CODE_USL = t3.CODE_USL AND t3.USL_OK IN(3, 4)
       WHERE  t3.F_AKTUAL = 1
              AND t3.VIDPOM != CASE WHEN zs.VIDPOM = 11 AND (t1.CODE_USL LIKE 'D%' OR  t1.CODE_USL LIKE 'P%') THEN 12 ELSE zs.VIDPOM end
              AND t3.VIDPOM IS NOT NULL
              AND zs.USL_OK IN(3, 4)
			  AND  (zs.OPLATA <> 2 OR zs.oplata IS null)
 --select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Услуга CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не может оказываться при VIDPOM="'+isnull(cast(zs.VIDPOM as varchar),'')+'"'
 --from tempdb..TEMP_Z_SLUCH zs
 -- join  tempdb..TEMP_USL t1 on zs.IDCASE=t1.IDCASE
 -- join [IES].[R_NSI_USL_V001] t3 on t1.CODE_USL=t3.CODE_USL and t3.USL_OK in (3,4)
 --where t3.F_AKTUAL = 1 and t3.VIDPOM != zs.VIDPOM and t3.VIDPOM is not null
 --  and zs.USL_OK in (3,4)

-- Проверка №143.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Услуга CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не может оказываться в USL_OK="'+isnull(cast(zs.USL_OK as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join  tempdb..TEMP_USL t1 on zs.IDCASE=t1.IDCASE
  join [IES].[R_NSI_USL_V001] t3 on t1.CODE_USL=t3.CODE_USL and t3.USL_OK in (3,4)
 where t3.F_AKTUAL = 1
   and t3.USL_OK != zs.USL_OK
   and zs.USL_OK in (3,4)
    AND (zs.OPLATA <> 2 OR zs.oplata IS null)

-- Проверка №143.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не актуально в справочнике услуг ФЛК'
 from tempdb..TEMP_Z_SLUCH zs
  join  tempdb..TEMP_USL t1 on zs.IDCASE=t1.IDCASE
  join [IES].[R_NSI_USL_V001] t3 on t1.CODE_USL=t3.CODE_USL
 where t3.F_AKTUAL = 0
 AND (zs.OPLATA <> 2 OR zs.oplata IS null)

-- Проверка №143 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" не соответствует допустимому значению  в справочнике V001'
 from tempdb..TEMP_Z_SLUCH zs
  join  tempdb..TEMP_USL t1 on zs.IDCASE=t1.IDCASE
  left join [IES].[R_NSI_USL_V001] t3 on t1.CODE_USL=t3.CODE_USL
 where t3.CODE_USL is NULL
 AND (zs.OPLATA <> 2 OR zs.oplata IS null)

-- Проверка №142.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT) 
 select 'DS0', 'SL', zs.N_ZAP, zs.IDCASE, null, '905', 'Значение DS0="'+cast(s.ds0 as varchar)+'" в блоке SL не соответствует допустимому.' 
 from  tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  LEFT JOIN  ies.R_MKB_10 mkb on mkb.MKB10CODE = s.DS0 and mkb.priznak = 1
 where mkb.MKB10CODE is null and s.DS0 is not null

-- Проверка №142 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT) 
 select 'DS1', 'SL', zs.N_ZAP, zs.IDCASE, null, '905', 'Значение DS1="'+cast(s.ds1 as varchar)+'" в блоке SL не соответствует допустимому.' 
 from  tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  LEFT JOIN  ies.R_MKB_10 mkb on mkb.MKB10CODE = s.DS1 and mkb.priznak = 1
 where mkb.MKB10CODE is null and s.DS1 is not null

-- Проверка №141 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT) 
 select 'DS', 'USL', zs.N_ZAP, zs.IDCASE, null, '905', 'Значение DS="'+cast(s.ds as varchar)+'" в блоке USL не соответствует допустимому.' 
 from  tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_USL s on (s.IDCASE=zs.IDCASE) 
  LEFT JOIN  ies.R_MKB_10 mkb on mkb.MKB10CODE = s.DS and mkb.priznak = 1
 where mkb.MKB10CODE is null and s.DS is not null

-- Проверка №140 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'TARIF', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Не указан тариф для услуги.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  where u.TARIF is null

 -- Проверка №139 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'ED_COL', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не заполнено поле ED_COL для лабораторных исследований'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  where s.ed_col is null
        and s.profil in (34,38) 

 -- Проверка №138 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'ED_COL', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение в поле ED_COL больше 1 только для лабораторных исследований'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  where s.ed_col > 1 
        and s.profil not in (34,38) 

 -- Проверка №137 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'KD', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение поля KD не соответствует периоду лечения.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C','T')
  where (CASE s.date_2-s.date_1 WHEN 0 THEN 1 ELSE s.date_2-s.date_1 END <> s.kd and zs.usl_ok = 1)
   or ( s.date_2-s.date_1+1 != s.kd and zs.usl_ok = 2)

 -- Проверка №136.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение PROFIL="'+cast(s.PROFIL as varchar)+'"  не соответствует значению N_KSG="'+cast(t1.n_ksg as varchar)
  +'" при USL_OK="'+cast(zs.USL_OK as varchar)+'".'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG t1 on (t1.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H')
  where (s.profil = 137 and t1.n_ksg not in ('ds02.005','ds02.008','ds02.010','ds02.011','ds02.009')) 
     or (s.profil != 137 and t1.n_ksg in ('ds02.005','ds02.008','ds02.010','ds02.011','ds02.009'))  

 -- Проверка №136 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение PROFIL="'+cast(s.PROFIL as varchar)+'"  не соответствует значению VIDPOM="'+cast(zs.vidpom as varchar)
  +'" при USL_OK="'+cast(zs.USL_OK as varchar)+'".'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
  where ((s.profil in (68,97,57,58) and zs.usl_ok = 3 and (zs.vidpom not in (12, 14)) and zs.lpu !=400003) 
         or (s.profil not in (68,97,57,58) and zs.usl_ok = 3 and (zs.vidpom in (12, 14)) and zs.lpu !=400003) 
         or (s.profil in (42,3,82,85,15) and zs.usl_ok = 3 and zs.vidpom != 11)          
         or (s.profil not in (42,3,82,85,15) and zs.usl_ok = 3 and zs.vidpom = 11)    
         or (s.profil = 84 and zs.usl_ok = 4 and zs.vidpom != 21)          
         or (s.profil != 84 and zs.usl_ok = 4 and zs.vidpom = 21 AND zs.lpu <> '400043') -- исключения для областной больницы
			) 
		 AND  (zs.OPLATA <> 2 OR zs.oplata IS null)



-- Проверка №135.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DISP', 'SCHET', zs.N_ZAP, zs.IDCASE, null, '905', 'При значении DISP="'+isnull(cast(t.disp as varchar),'')+'" нельзя использовать значение RSLT_D="'+isnull(cast(zs.rslt_d as varchar),'')+'".'
 from tempdb..TEMP_Z_SLUCH zs 
  join tempdb..TEMP_SCHET t on t.DISP is not null
 where (not exists (select 1 from [IESDB].[IES].[T_SPR_RSLT_D_TO_RSLT] t7 where t.DISP=t7.DISP and zs.RSLT_D=t7.RSLT_D and zs.DATE_Z_2<='31.05.2019'
					union
					select 1 from [IESDB].[IES].[T_SPR_RSLT_D_TO_RSLT_NEW] t8 where t.DISP=t8.DISP and zs.RSLT_D=t8.RSLT_D and zs.DATE_Z_2>='01.06.2019')) -- Новые соответствия с 01.06.2019
   and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693 and GETDATE() > '15.03.2019')) 


-- Проверка №135 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DISP', 'SCHET', null, null, null, '905', 'Значение DISP="'+isnull(cast(t.disp as varchar),'')+'" не соответствует имени файла "'+z.filename+'".'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ZAP c on c.N_ZAP=zs.N_ZAP
  join tempdb..TEMP_SCHET t on t.ID=c.SchetZapID
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('D')
 where substring(z.filename,1,1) = 'D' 
        and ( (substring(z.filename,2,1) = 'P' and t.disp not in ('ДВ1','ДВ3') and zs.date_z_2<='31.05.2019')
			 or (substring(z.filename,2,1) = 'P' and t.disp not in ('ДВ4') and zs.date_z_2>='01.06.2019')
             or (substring(z.filename,2,1) = 'V' and t.disp not in ('ДВ2'))
             or (substring(z.filename,2,1) = 'O' and t.disp not in ('ОПВ'))
             or (substring(z.filename,2,1) = 'S' and t.disp not in ('ДС1','ДС3'))
             or (substring(z.filename,2,1) = 'U' and t.disp not in ('ДС2','ДС4'))
             or (substring(z.filename,2,1) = 'F' and t.disp not in ('ПН1','ПН2'))
            ) 

 -- Проверка №134.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMP', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Сумма принятая не может быть меньше 0'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  where zs.SUMP < 0


 -- Проверка №134 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUM_M', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Сумма случая не может равняться 0.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  where s.sum_m = 0

 -- Проверка №133 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'VIDPOM', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Некорректное заполнение поля VIDPOM="'+cast(zs.VIDPOM as varchar)+'" в связке с именем файла "'+SUBSTRING(z.FILENAME,1,1)+'".'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C','T','D')
  where (SUBSTRING(z.FILENAME,1,1) in ('H','C') and zs.vidpom not in (11,12,13,31,21,14))
     or (SUBSTRING(z.FILENAME,1,1) = 'T' and zs.vidpom != 32)
     or (SUBSTRING(z.FILENAME,1,1) = 'D' and zs.vidpom not in (11,12,13))

 /*
 -- Проверка №132.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', t.N_ZAP, t.IDCASE, u.IDSERV, '904', 'Вы не можете использовать услугу B01.069.098'  
 from tempdb..TEMP_Z_SLUCH s
  join tempdb..TEMP_SLUCH t on (s.IDCASE=t.IDCASE) 
  join tempdb..TEMP_USL u on (t.IDCASE=u.IDCASE and t.SL_ID=u.SL_ID) 
  where u.CODE_USL = 'B01.069.098' and s.LPU != '400064'
*/

 -- Проверка №132.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL', 'SL', t.N_ZAP, t.IDCASE, null, '904', 'Отсутствуют услуги для ВМП при ЗНО'  
 from tempdb..TEMP_Z_SLUCH s
  join tempdb..TEMP_SLUCH t on (s.IDCASE=t.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('T')
  where not exists (select 1 from tempdb..TEMP_USL t1 where t1.IDCASE=s.IDCASE)
    and (substring(t.ds1,1,1) = 'C' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS2 from tempdb..TEMP_DS2 ds where (ds.DS2 between 'C00' and 'C80.9' or  ds.ds2 between 'C97' and 'C97.9'))))


 -- Проверка №132 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL', 'SL', N_ZAP, IDCASE, null, '904', 'Отсутствуют услуги для  амбулаторно-поликлинической и скорой помощи (USL_OK={3,4})'  
 from tempdb..TEMP_Z_SLUCH s
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
  where s.USL_OK in (3,4) and (select count(*) from tempdb..TEMP_USL t1 where t1.IDCASE=s.IDCASE) = 0

 -- Проверка №131 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL', 'SL', N_ZAP, IDCASE, null, '904', 'Больше одной услуги с SUMV_USL больше 0 внутри одного случая при амбулаторно-поликлинической помощи (USL_OK=3)'  
 from tempdb..TEMP_Z_SLUCH s
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
  where s.USL_OK=3 and (select count(*) from tempdb..TEMP_USL t1 where t1.IDCASE=s.IDCASE and t1.SUMV_USL > 0) > 1

 -- Проверка №130 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'VIDPOM', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NPOLIS "'+p.npolis+'" не соответствует VPOLIS "'+cast(p.VPOLIS as varchar)+'"'
 from tempdb..TEMP_Z_SLUCH zs
 join tempdb..TEMP_ZAP z on z.N_ZAP=zs.N_ZAP
 join tempdb..TEMP_PACIENT p on p.N_ZAP=z.N_ZAP
  where p.VPOLIS = 3 and len(p.NPOLIS) <> 16

 -- Проверка №129.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMV', 'Z_SL', N_ZAP, IDCASE, null, '904', 'Сумма законченного случая не равна сумме случаев лечения в нем'  
 from tempdb..TEMP_Z_SLUCH s
  where s.SUMV != (select sum(SUM_M) from tempdb..TEMP_SLUCH t where t.IDCASE=s.IDCASE)

 -- Проверка №129 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMMAV', 'SCHET', null, null, null, '904', 'Сумма счета не равна сумме в случаях лечения'  
 from tempdb..TEMP_SCHET s
  where s.SUMMAV != (select sum(SUM_M) from tempdb..TEMP_SLUCH t)

-- Проверка №128.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'P_CEL', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'P_CEL=2.5 не может применяться для пациентов старше 2 месяцев'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_PACIENT a1 on zs.N_ZAP=a1.N_ZAP
  join tempdb..TEMP_PERS c on a1.ID_PAC= cast(c.ID_PAC as varchar)
  where s.P_CEL = '2.5'
    and DATEADD(month,2,c.dr) < s.DATE_2

-- Проверка №128 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'P_CEL', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Некорректное заполнение поля P_CEL="'+isnull(cast(s.P_CEL as varchar),'')+'" при указании IDSP="'
  +isnull(cast(zs.IDSP as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  where usl_ok = 3 and not ( 
        (s.p_cel in ('1.0','1.1','1.2','1.3','2.1','2.2','2.3','2.5','2.6') and zs.idsp = 29)
        or (s.p_cel in ('1.0','1.1','1.2','1.3','2.1','2.2','2.3','2.5','2.6','3.0') and zs.idsp = 25)
        or (s.p_cel in ('2.1','2.2','3.0') and zs.idsp = 30)
        or (s.p_cel = '2.6' and zs.idsp = 28)
		)
		
-- Проверка №127 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_Z_1', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Даты законченного случая не соответствуют отчетному периоду DATE_Z_1="'+cast(format(zs.DATE_Z_1,'dd.MM.yyyy') as varchar)
  +'" DATE_Z_2="'+cast(format(zs.DATE_Z_2,'dd.MM.yyyy') as varchar)+'" DSCHET="'+cast(format(t1.DSCHET,'dd.MM.yyyy') as varchar)+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SCHET t1 on (--zs.date_z_1 < t1.DSCHET-360 or 
									zs.date_z_1 > t1.DSCHET or zs.date_z_2 < getdate()-90 --t1.DSCHET-90 
															or zs.date_z_2 > t1.DSCHET) 
  join tempdb..TEMP_ZAP z on zs.N_ZAP=z.N_ZAP and z.PR_NOV=0
  WHERE    (zs.OPLATA <> 2 OR zs.oplata IS null)
			and (@schet_coments not like '% + проверки%')
			--and @schet_coments != 'По решению комисии'


-- Проверка №126.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_IN', 'USL', zs.N_ZAP, zs.IDCASE, s.IDSERV, '904', 'Даты услуги не соответствуют датам случая или законченного случая DATE_IN="'+cast(format(s.DATE_IN,'dd.MM.yyyy') as varchar)
  +'" DATE_OUT="'+cast(format(s.DATE_OUT,'dd.MM.yyyy') as varchar)+'" DATE_1="'+cast(format(sl.DATE_1,'dd.MM.yyyy') as varchar)+'"'
  +' DATE_2="'+cast(format(sl.DATE_2,'dd.MM.yyyy') as varchar)+'"'
  +' DATE_Z_1="'+cast(format(zs.DATE_Z_1,'dd.MM.yyyy') as varchar)+'"'
  +' DATE_Z_2="'+cast(format(zs.DATE_Z_2,'dd.MM.yyyy') as varchar)+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH sl on sl.IDCASE=zs.IDCASE 
  join tempdb..TEMP_USL s on s.IDCASE=zs.IDCASE 
  join tempdb..TEMP_ZAP z on zs.N_ZAP=z.N_ZAP
where zs.USL_OK in (3,4)
  and @type = 554
  and (s.DATE_IN < zs.DATE_Z_1 
       or s.DATE_IN < sl.DATE_1
	   or s.DATE_OUT > zs.DATE_Z_2
	   or s.DATE_OUT > sl.DATE_2
	  )

-- Проверка №126 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_IN', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Даты услуги не соответствуют отчетному периоду DATE_IN="'+cast(format(s.DATE_IN,'dd.MM.yyyy') as varchar)
  +'" DATE_OUT="'+cast(format(s.DATE_OUT,'dd.MM.yyyy') as varchar)+'" DSCHET="'+cast(format(t1.DSCHET,'dd.MM.yyyy') as varchar)+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_USL s on s.IDCASE=zs.IDCASE 
  join tempdb..TEMP_SCHET t1 on (s.date_in < t1.DSCHET-360 or s.date_in > t1.DSCHET or s.date_out < t1.DSCHET-360 or s.date_out > t1.DSCHET) 
  join tempdb..TEMP_ZAP z on zs.N_ZAP=z.N_ZAP and z.PR_NOV=0

-- Проверка №125 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_1', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Даты случая лечения не соответствуют отчетному периоду DATE_1="'+cast(format(s.DATE_1,'dd.MM.yyyy') as varchar)
  +'" DATE_2="'+cast(format(s.DATE_2,'dd.MM.yyyy') as varchar)+'" DSCHET="'+cast(format(t1.DSCHET,'dd.MM.yyyy') as varchar)+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on s.IDCASE=zs.IDCASE 
  join tempdb..TEMP_SCHET t1 on (--s.date_1 < t1.DSCHET-360 or 
									s.date_1 > t1.DSCHET or s.date_2 < t1.DSCHET-180 or s.date_2 > t1.DSCHET) 
  join tempdb..TEMP_ZAP z on zs.N_ZAP=z.N_ZAP and z.PR_NOV=0

-- Проверка №124 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DOC_SER', 'PERS', zs.N_ZAP, zs.IDCASE, null, '904', 'Серия и номер документа указаны не корректно (DOCTYPE="'+isnull(cast(s.DOCTYPE as varchar),'')
 +'" DOCSER="'+isnull(cast(s.DOCSER as varchar),'')+'" DOCNUM="'+isnull(cast(s.DOCNUM as varchar),'')+'").'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_PACIENT t on t.N_ZAP=zs.N_ZAP 
  join tempdb..TEMP_PERS s on cast(t.ID_PAC as varchar)=cast(s.ID_PAC as varchar) 
 where  dbo.fn_ChDocMask(s.DOCTYPE,s.DOCSER,s.DOCNUM) = 1
  --and len(t.npolis) != 16

-- Проверка №123.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Код профиля МП в случае "'+cast(s.PROFIL as varchar)+'" не соответствует коду профиля МП в услуге "'+cast(u.PROFIL as varchar)+'".' +
	'Либо Код специальности в случае "'+cast(s.PRVS as varchar)+'" не соответствует коду специальности в услуге "'+cast(u.PRVS as varchar)+'".'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL u on (s.IDCASE=u.IDCASE and s.SL_ID=u.SL_ID) 
  where (zs.USL_OK in (3,4) and (s.PROFIL != u.PROFIL or s.PRVS != u.PRVS) and u.CODE_USL not in ('D04.069.299','D04.069.298'))
     or (zs.USL_OK in (1,2) and u.SUMV_USL = 0 and (s.PROFIL != u.PROFIL or s.PRVS != u.PRVS))

-- Проверка №123.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Код профиля МП "'+cast(s.PROFIL as varchar)+'" не соответствует коду специальности "'+cast(s.PRVS as varchar)+'".'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_USL s on (s.IDCASE=zs.IDCASE) 
  left join [IES].T_CHER_PROFIL_PRVS p ON s.profil = p.profil
  left join IES.T_V021_MED_SPEC v ON s.prvs=v.IDSPEC and s.prvs=v.CODE_SPEC
  where v.CODE_SPEC is null

-- Проверка №123 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Код профиля МП "'+cast(s.PROFIL as varchar)+'" не соответствует коду специальности "'+cast(s.PRVS as varchar)+'".'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  left join [IES].T_CHER_PROFIL_PRVS p ON s.profil = p.profil
  left join IES.T_V021_MED_SPEC v ON s.prvs=v.IDSPEC and s.prvs=v.CODE_SPEC
  where v.CODE_SPEC is null

-- Проверка №122 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'FAM_P', 'PERS', zs.N_ZAP, zs.IDCASE, null, '904', 'Некорректно указаные данные представителя пациента.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_PACIENT t on t.N_ZAP=zs.N_ZAP 
  join tempdb..TEMP_PERS s on cast(t.ID_PAC as varchar)=cast(s.ID_PAC as varchar) 
 where (s.fam_p is not null and (s.im_p is null or s.dr_p is null or s.w_p is null))
  or (s.fam_p is null and s.im_p is null and  (s.ot_p is not null or s.dr_p is not null or s.w_p is not null))

-- Проверка №121 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'FAM_P', 'PERS', zs.N_ZAP, zs.IDCASE, null, '904', 'Отсутствуют данные представителя у новорожденного.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_PACIENT t on t.N_ZAP=zs.N_ZAP 
  join tempdb..TEMP_PERS s on cast(t.ID_PAC as varchar)=cast(s.ID_PAC as varchar) 
 where ((s.fam is null) or (s.im is null)) 
   and ((s.fam_p is null) or (s.im_p is null) or (s.dr_p is null))   
   and not exists (select 1 from tempdb..TEMP_DOST d where cast(d.ID_PAC as varchar) =cast(s.ID_PAC as varchar) and d.DOST in (1,2,3))  

-- Проверка №120.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL_OK', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Код условия оказания МП "'+cast(zs.USL_OK as varchar)+'" не соответствует виду оказания МП "'+cast(zs.VIDPOM as varchar)+'".'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where (zs.USL_OK=1 and zs.VIDPOM != 31)
    or (zs.USL_OK=2 and zs.VIDPOM not in (13,31,12))
    or (zs.USL_OK=3 and zs.VIDPOM not in (11,12,13,14))
    or (zs.USL_OK=4 and zs.VIDPOM !=21)

-- Проверка №120 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL_OK', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Код условия оказания МП "'+cast(zs.USL_OK as varchar)+'" не соответствует форме оказания МП "'+cast(zs.FOR_POM as varchar)+'".'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  left join [IES].T_CHER_USLOK_FORPOM  p ON zs.usl_ok = p.usl_ok and zs.for_pom=p.for_pom
 where p.usl_ok is null

-- Проверка №119 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IM', 'PERS', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректное имя.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_PACIENT t on t.N_ZAP=zs.N_ZAP 
  join tempdb..TEMP_PERS s on cast(t.ID_PAC as varchar)=cast(s.ID_PAC as varchar) 
 where s.IM  IN ('НЕТ', 'Нет','Н','-','Х','X','H','A','B','А','В')           
   or  s.IM_P IN ('НЕТ', 'Нет','Н','-','Х','X','H','A','B','А','В')           

-- Проверка №118 по базе в ОРАКЛЕ 
/* insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Код услуги "'+u.CODE_USL+'" не сответствует коду типу помощи "'+cast(zs.USL_OK as varchar)+'".'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
  where u.code_usl IN ('B01.044.001.001', 'B01.044.005')
      AND zs.usl_ok != 4
*/

-- Проверка №119 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IM', 'PERS', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректное отчество.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_PACIENT t on t.N_ZAP=zs.N_ZAP 
  join tempdb..TEMP_PERS s on cast(t.ID_PAC as varchar)=cast(s.ID_PAC as varchar) 
 where (s.OT  IN ('НЕТ', 'Нет','Н','-','Х','X','H','A','B','А','В')           
   or  s.OT_P IN ('НЕТ', 'Нет','Н','-','Х','X','H','A','B','А','В'))
   and (t.NPOLIS != '4056840823000264' or t.ENP !='4056840823000264') --уникальный человек         

-- Проверка №116 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS2', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Основной код диагноза указан без подрубрики.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_DS3 t1 on (s.IDCASE=t1.IDCASE and s.SL_ID=t1.SL_ID) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C','T')
 where len(t1.DS3) = 3
       AND t1.DS3 NOT IN
       ('A33', 'A34', 'A38', 'A46', 'A55', 'A57', 'A58', 'A64', 'A65', 'A70', 'A78', 'A89', 'A90', 'A91', 'A94', 'A99', 'B03', 'B04', 'B07', 'B09',
            'B54', 'B59', 'B64', 'B72', 'B73', 'B75', 'B79', 'B80', 'B86', 'B89', 'B91', 'B92', 'B99', 'C01', 'C07', 'C12', 'C20', 'C23', 'C33', 'C37',
            'C52', 'C55', 'C56', 'C58', 'C61', 'C64', 'C65', 'C66', 'C73', 'C97', 'D27', 'D34', 'D45', 'D65', 'D66', 'D67', 'D70', 'D71', 'D77', 'E02',
            'E15', 'E40', 'E41', 'E42', 'E43', 'E45', 'E46', 'E52', 'E54', 'E58', 'E59', 'E60', 'E65', 'E68', 'E86', 'E90', 'G07', 'G08', 'G09', 'G10',
            'G20', 'G26', 'G35', 'H55', 'H71', 'H82', 'I00', 'I10', 'I38', 'I81', 'I99', 'J00', 'J13', 'J14', 'J22', 'J36', 'J40', 'J46', 'J47', 'J60',
            'J61', 'J64', 'J65', 'J80', 'J81', 'J82', 'J90', 'J91', 'K20', 'K36', 'K37', 'L00', 'L14', 'L26', 'L42', 'L52', 'L80', 'L82', 'L83', 'L84',
            'L86', 'L88', 'L97', 'M45', 'N12', 'N19', 'N23', 'N26', 'N40', 'N44', 'N46', 'N47', 'N61', 'N62', 'N63', 'N72', 'N86', 'N96', 'O11', 'O13',
            'O16', 'O25', 'O40', 'O48', 'O85', 'O95', 'O96', 'O97', 'P38', 'P53', 'P60', 'P75', 'P77', 'P90', 'P93', 'P95', 'Q02', 'R05', 'R11', 'R12',
            'R13', 'R14', 'R15', 'R17', 'R18', 'R21', 'R31', 'R32', 'R33', 'R34', 'R35', 'R36', 'R42', 'R53', 'R55', 'R72', 'R51', 'R69', 'S16', 'S18',
            'T07', 'T16', 'T55', 'T58', 'T64', 'T66', 'T68', 'T97', 'Z21', 'B24', 'B49', 'C19', 'D24', 'D62', 'G01', 'G22', 'G92', 'G98', 'J42', 'K20',
            'K30', 'L22', 'L45', 'N10', 'R02', 'S47', 'Z33', 'T71', 'A35', 'A86', 'F03', 'F04', 'F09', 'F21', 'F24', 'F28', 'F29', 'F39', 'F54', 'F55',
            'F59', 'F61', 'F69', 'F82', 'F83', 'F88', 'F89', 'F99', 'G14', 'G64', 'H46', 'J09', 'O94', 'R54', 'R58', 'R64', 'R71', 'R75', 'R80', 'R81',
            'R91', 'R92', 'R95', 'R98', 'R99', 'T96', 'I64')
      AND zs.usl_ok != 4

-- Проверка №115 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS2', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Код диагноза указан без подрубрики.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_DS2 t1 on (s.IDCASE=t1.IDCASE and s.SL_ID=t1.SL_ID) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C','T')
 where len(t1.DS2) = 3
       AND t1.DS2 NOT IN
       ('A33', 'A34', 'A38', 'A46', 'A55', 'A57', 'A58', 'A64', 'A65', 'A70', 'A78', 'A89', 'A90', 'A91', 'A94', 'A99', 'B03', 'B04', 'B07', 'B09',
            'B54', 'B59', 'B64', 'B72', 'B73', 'B75', 'B79', 'B80', 'B86', 'B89', 'B91', 'B92', 'B99', 'C01', 'C07', 'C12', 'C20', 'C23', 'C33', 'C37',
            'C52', 'C55', 'C56', 'C58', 'C61', 'C64', 'C65', 'C66', 'C73', 'C97', 'D27', 'D34', 'D45', 'D65', 'D66', 'D67', 'D70', 'D71', 'D77', 'E02',
            'E15', 'E40', 'E41', 'E42', 'E43', 'E45', 'E46', 'E52', 'E54', 'E58', 'E59', 'E60', 'E65', 'E68', 'E86', 'E90', 'G07', 'G08', 'G09', 'G10',
            'G20', 'G26', 'G35', 'H55', 'H71', 'H82', 'I00', 'I10', 'I38', 'I81', 'I99', 'J00', 'J13', 'J14', 'J22', 'J36', 'J40', 'J46', 'J47', 'J60',
            'J61', 'J64', 'J65', 'J80', 'J81', 'J82', 'J90', 'J91', 'K20', 'K36', 'K37', 'L00', 'L14', 'L26', 'L42', 'L52', 'L80', 'L82', 'L83', 'L84',
            'L86', 'L88', 'L97', 'M45', 'N12', 'N19', 'N23', 'N26', 'N40', 'N44', 'N46', 'N47', 'N61', 'N62', 'N63', 'N72', 'N86', 'N96', 'O11', 'O13',
            'O16', 'O25', 'O40', 'O48', 'O85', 'O95', 'O96', 'O97', 'P38', 'P53', 'P60', 'P75', 'P77', 'P90', 'P93', 'P95', 'Q02', 'R05', 'R11', 'R12',
            'R13', 'R14', 'R15', 'R17', 'R18', 'R21', 'R31', 'R32', 'R33', 'R34', 'R35', 'R36', 'R42', 'R53', 'R55', 'R72', 'R51', 'R69', 'S16', 'S18',
            'T07', 'T16', 'T55', 'T58', 'T64', 'T66', 'T68', 'T97', 'Z21', 'B24', 'B49', 'C19', 'D24', 'D62', 'G01', 'G22', 'G92', 'G98', 'J42', 'K20',
            'K30', 'L22', 'L45', 'N10', 'R02', 'S47', 'Z33', 'T71', 'A35', 'A86', 'F03', 'F04', 'F09', 'F21', 'F24', 'F28', 'F29', 'F39', 'F54', 'F55',
            'F59', 'F61', 'F69', 'F82', 'F83', 'F88', 'F89', 'F99', 'G14', 'G64', 'H46', 'J09', 'O94', 'R54', 'R58', 'R64', 'R71', 'R75', 'R80', 'R81',
            'R91', 'R92', 'R95', 'R98', 'R99', 'T96', 'I64')
      AND zs.usl_ok != 4

-- Проверка №114.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS1', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Указанный код основного диагноза не может быть передан в файле C'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C')
 where not ( t.ds_onk=1 or
  (substring(t.ds1,1,1) = 'C' or t.DS1 between 'D00' and 'D09.99' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS2 from tempdb..TEMP_DS2 ds where (ds.DS2 between 'C00' and 'C80.9' or  ds.ds2 between 'C97' and 'C97.9')))) 
  )

-- Проверка №114.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS1', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Указанный код основного диагноза не может быть передан в файле Н'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H')
 where (substring(t.ds1,1,1) = 'C' or t.DS1 between 'D00' and 'D09.99' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS2 from tempdb..TEMP_DS2 ds where (ds.DS2 between 'C00' and 'C80.9' or  ds.ds2 between 'C97' and 'C97.9')))) 

-- Проверка №114 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS1', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Основной код диагноза указан без подрубрики.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C','T')
 where len(s.DS1) = 3
       AND s.ds1 NOT IN
       ('A33', 'A34', 'A38', 'A46', 'A55', 'A57', 'A58', 'A64', 'A65', 'A70', 'A78', 'A89', 'A90', 'A91', 'A94', 'A99', 'B03', 'B04', 'B07', 'B09',
            'B54', 'B59', 'B64', 'B72', 'B73', 'B75', 'B79', 'B80', 'B86', 'B89', 'B91', 'B92', 'B99', 'C01', 'C07', 'C12', 'C20', 'C23', 'C33', 'C37',
            'C52', 'C55', 'C56', 'C58', 'C61', 'C64', 'C65', 'C66', 'C73', 'C97', 'D27', 'D34', 'D45', 'D65', 'D66', 'D67', 'D70', 'D71', 'D77', 'E02',
            'E15', 'E40', 'E41', 'E42', 'E43', 'E45', 'E46', 'E52', 'E54', 'E58', 'E59', 'E60', 'E65', 'E68', 'E86', 'E90', 'G07', 'G08', 'G09', 'G10',
            'G20', 'G26', 'G35', 'H55', 'H71', 'H82', 'I00', 'I10', 'I38', 'I81', 'I99', 'J00', 'J13', 'J14', 'J22', 'J36', 'J40', 'J46', 'J47', 'J60',
            'J61', 'J64', 'J65', 'J80', 'J81', 'J82', 'J90', 'J91', 'K20', 'K36', 'K37', 'L00', 'L14', 'L26', 'L42', 'L52', 'L80', 'L82', 'L83', 'L84',
            'L86', 'L88', 'L97', 'M45', 'N12', 'N19', 'N23', 'N26', 'N40', 'N44', 'N46', 'N47', 'N61', 'N62', 'N63', 'N72', 'N86', 'N96', 'O11', 'O13',
            'O16', 'O25', 'O40', 'O48', 'O85', 'O95', 'O96', 'O97', 'P38', 'P53', 'P60', 'P75', 'P77', 'P90', 'P93', 'P95', 'Q02', 'R05', 'R11', 'R12',
            'R13', 'R14', 'R15', 'R17', 'R18', 'R21', 'R31', 'R32', 'R33', 'R34', 'R35', 'R36', 'R42', 'R53', 'R55', 'R72', 'R51', 'R69', 'S16', 'S18',
            'T07', 'T16', 'T55', 'T58', 'T64', 'T66', 'T68', 'T97', 'Z21', 'B24', 'B49', 'C19', 'D24', 'D62', 'G01', 'G22', 'G92', 'G98', 'J42', 'K20',
            'K30', 'L22', 'L45', 'N10', 'R02', 'S47', 'Z33', 'T71', 'A35', 'A86', 'F03', 'F04', 'F09', 'F21', 'F24', 'F28', 'F29', 'F39', 'F54', 'F55',
            'F59', 'F61', 'F69', 'F82', 'F83', 'F88', 'F89', 'F99', 'G14', 'G64', 'H46', 'J09', 'O94', 'R54', 'R58', 'R64', 'R71', 'R75', 'R80', 'R81',
            'R91', 'R92', 'R95', 'R98', 'R99', 'T96', 'I64')
      AND zs.usl_ok != 4

-- Проверка №113 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS0', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Первичный код диагноза указан без подрубрики.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C','T')
 where len(s.DS0) = 3
       AND s.ds0 NOT IN
       ('A33', 'A34', 'A38', 'A46', 'A55', 'A57', 'A58', 'A64', 'A65', 'A70', 'A78', 'A89', 'A90', 'A91', 'A94', 'A99', 'B03', 'B04', 'B07', 'B09',
            'B54', 'B59', 'B64', 'B72', 'B73', 'B75', 'B79', 'B80', 'B86', 'B89', 'B91', 'B92', 'B99', 'C01', 'C07', 'C12', 'C20', 'C23', 'C33', 'C37',
            'C52', 'C55', 'C56', 'C58', 'C61', 'C64', 'C65', 'C66', 'C73', 'C97', 'D27', 'D34', 'D45', 'D65', 'D66', 'D67', 'D70', 'D71', 'D77', 'E02',
            'E15', 'E40', 'E41', 'E42', 'E43', 'E45', 'E46', 'E52', 'E54', 'E58', 'E59', 'E60', 'E65', 'E68', 'E86', 'E90', 'G07', 'G08', 'G09', 'G10',
            'G20', 'G26', 'G35', 'H55', 'H71', 'H82', 'I00', 'I10', 'I38', 'I81', 'I99', 'J00', 'J13', 'J14', 'J22', 'J36', 'J40', 'J46', 'J47', 'J60',
            'J61', 'J64', 'J65', 'J80', 'J81', 'J82', 'J90', 'J91', 'K20', 'K36', 'K37', 'L00', 'L14', 'L26', 'L42', 'L52', 'L80', 'L82', 'L83', 'L84',
            'L86', 'L88', 'L97', 'M45', 'N12', 'N19', 'N23', 'N26', 'N40', 'N44', 'N46', 'N47', 'N61', 'N62', 'N63', 'N72', 'N86', 'N96', 'O11', 'O13',
            'O16', 'O25', 'O40', 'O48', 'O85', 'O95', 'O96', 'O97', 'P38', 'P53', 'P60', 'P75', 'P77', 'P90', 'P93', 'P95', 'Q02', 'R05', 'R11', 'R12',
            'R13', 'R14', 'R15', 'R17', 'R18', 'R21', 'R31', 'R32', 'R33', 'R34', 'R35', 'R36', 'R42', 'R53', 'R55', 'R72', 'R51', 'R69', 'S16', 'S18',
            'T07', 'T16', 'T55', 'T58', 'T64', 'T66', 'T68', 'T97', 'Z21', 'B24', 'B49', 'C19', 'D24', 'D62', 'G01', 'G22', 'G92', 'G98', 'J42', 'K20',
            'K30', 'L22', 'L45', 'N10', 'R02', 'S47', 'Z33', 'T71', 'A35', 'A86', 'F03', 'F04', 'F09', 'F21', 'F24', 'F28', 'F29', 'F39', 'F54', 'F55',
            'F59', 'F61', 'F69', 'F82', 'F83', 'F88', 'F89', 'F99', 'G14', 'G64', 'H46', 'J09', 'O94', 'R54', 'R58', 'R64', 'R71', 'R75', 'R80', 'R81',
            'R91', 'R92', 'R95', 'R98', 'R99', 'T96', 'I64')
      AND zs.usl_ok != 4

-- Проверка №112 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Код диагноза в блоке сведений об услуге указан без подрубрики.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C','T')
 where len(u.DS) = 3
       AND u.ds NOT IN
       ('A33', 'A34', 'A38', 'A46', 'A55', 'A57', 'A58', 'A64', 'A65', 'A70', 'A78', 'A89', 'A90', 'A91', 'A94', 'A99', 'B03', 'B04', 'B07', 'B09',
            'B54', 'B59', 'B64', 'B72', 'B73', 'B75', 'B79', 'B80', 'B86', 'B89', 'B91', 'B92', 'B99', 'C01', 'C07', 'C12', 'C20', 'C23', 'C33', 'C37',
            'C52', 'C55', 'C56', 'C58', 'C61', 'C64', 'C65', 'C66', 'C73', 'C97', 'D27', 'D34', 'D45', 'D65', 'D66', 'D67', 'D70', 'D71', 'D77', 'E02',
            'E15', 'E40', 'E41', 'E42', 'E43', 'E45', 'E46', 'E52', 'E54', 'E58', 'E59', 'E60', 'E65', 'E68', 'E86', 'E90', 'G07', 'G08', 'G09', 'G10',
            'G20', 'G26', 'G35', 'H55', 'H71', 'H82', 'I00', 'I10', 'I38', 'I81', 'I99', 'J00', 'J13', 'J14', 'J22', 'J36', 'J40', 'J46', 'J47', 'J60',
            'J61', 'J64', 'J65', 'J80', 'J81', 'J82', 'J90', 'J91', 'K20', 'K36', 'K37', 'L00', 'L14', 'L26', 'L42', 'L52', 'L80', 'L82', 'L83', 'L84',
            'L86', 'L88', 'L97', 'M45', 'N12', 'N19', 'N23', 'N26', 'N40', 'N44', 'N46', 'N47', 'N61', 'N62', 'N63', 'N72', 'N86', 'N96', 'O11', 'O13',
            'O16', 'O25', 'O40', 'O48', 'O85', 'O95', 'O96', 'O97', 'P38', 'P53', 'P60', 'P75', 'P77', 'P90', 'P93', 'P95', 'Q02', 'R05', 'R11', 'R12',
            'R13', 'R14', 'R15', 'R17', 'R18', 'R21', 'R31', 'R32', 'R33', 'R34', 'R35', 'R36', 'R42', 'R53', 'R55', 'R72', 'R51', 'R69', 'S16', 'S18',
            'T07', 'T16', 'T55', 'T58', 'T64', 'T66', 'T68', 'T97', 'Z21', 'B24', 'B49', 'C19', 'D24', 'D62', 'G01', 'G22', 'G92', 'G98', 'J42', 'K20',
            'K30', 'L22', 'L45', 'N10', 'R02', 'S47', 'Z33', 'T71', 'A35', 'A86', 'F03', 'F04', 'F09', 'F21', 'F24', 'F28', 'F29', 'F39', 'F54', 'F55',
            'F59', 'F61', 'F69', 'F82', 'F83', 'F88', 'F89', 'F99', 'G14', 'G64', 'H46', 'J09', 'O94', 'R54', 'R58', 'R64', 'R71', 'R75', 'R80', 'R81',
            'R91', 'R92', 'R95', 'R98', 'R99', 'T96', 'I64')
      AND zs.usl_ok != 4

/*
-- Проверка №111 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Коду услуги "'+u.CODE_USL+'" не сответствует код цели посещения "'+s.p_cel+'".'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C','D')
 where (s.p_cel in ('1.1','3.0', '2.3','2.2','2.1') )
       and (
        (u.code_usl IN ('B01.047.007', 'B01.050.006', 'B01.069.012', 'B01.069.090', 'B01.080.07', 'B03.059.01', 'B03.059.02', 'B03.059.03', 'B01.064.005', 'B01.064.006', 'B01.064.007', 'B01.026.070.01', 
		'B01.004.074.01', 'B01.001.075.01', 'B01.001.070.01', 'B01.008.074.01', 'B01.014.070.01', 'B01.014.075.01', 'B01.015.070.01', 'B01.023.070.01', 'B01.023.075.01', 
		'B01.027.072.01', 'B01.028.075.01', 'B01.029.075.01', 'B01.031.071.01', 'B01.047.071.01', 'B01.050.074.01', 'B01.053.072.01', 'B01.010.070.01', 'B01.057.071.01', 
		'B01.058.074.01','B01.069.009', 'B01.028.070.01', 'B01.029.070.01', 'B01.044.070.01','B03.059.03','B01.065.03') AND s.p_cel != '1.1') 
        or  (u.code_usl not IN ('B01.047.007', 'B01.050.006', 'B01.069.012', 'B01.069.090', 'B01.080.07', 'B03.059.01', 'B03.059.02', 'B03.059.03', 'B01.064.005', 'B01.064.006',
		 'B01.064.007', 'B01.026.070.01', 
		'B01.004.074.01', 'B01.001.075.01', 'B01.001.070.01', 'B01.008.074.01', 'B01.014.070.01', 'B01.014.075.01', 'B01.015.070.01', 'B01.023.070.01', 'B01.023.075.01', 
		'B01.027.072.01', 'B01.028.075.01', 'B01.029.075.01', 'B01.031.071.01', 'B01.047.071.01', 'B01.050.074.01', 'B01.053.072.01', 'B01.010.070.01', 'B01.057.071.01', 
		'B01.058.074.01','B01.069.009', 'B01.028.070.01', 'B01.029.070.01', 'B01.044.070.01','B03.059.03','B01.065.03') AND s.p_cel = '1.1') 
        or (u.code_usl IN ('B04.066.01', 'B04.069.090', 'B03.029.001.090', 'B03.029.001.091','B01.007.080') AND s.p_cel != '2.3')
        or (u.code_usl not IN ('B04.066.01', 'B04.069.090', 'B03.029.001.090', 'B03.029.001.091','B01.007.080') AND s.p_cel = '2.3')
        or
        ((u.code_usl IN ('Z01.001.000', 'Z01.001.001', 'Z01.002.000', 'Z01.002.001', 'Z01.004.000', 'Z01.004.001', 'Z01.008.000', 'Z01.008.001', 'Z01.010.000', 'Z01.010.002',
               'Z01.014.000', 'Z01.014.001', 'Z01.014.002', 'Z01.015.000', 'Z01.015.001', 'Z01.015.002', 'Z01.016.000', 'Z01.016.001', 'Z01.018.000', 'Z01.023.000', 'Z01.023.001', 'Z01.025.000',
               'Z01.025.001', 'Z01.026.000', 'Z01.027.000', 'Z01.028.000', 'Z01.028.001', 'Z01.028.002', 'Z01.029.000', 'Z01.029.001', 'Z01.029.002',  'Z01.031.000', 'Z01.037.000', 'Z01.037.001',
               'Z01.040.000', 'Z01.043.000', 'Z01.046.000', 'Z01.046.001', 'Z01.047.000', 'Z01.050.000', 'Z01.050.001', 'Z01.050.002', 'Z01.053.000', 'Z01.053.001', 'Z01.057.000', 'Z01.058.000', 'Z01.058.001',
               'Z01.068.000', 'Z01.068.001', 'Z01.069.000', 'Z01.071.000','Z01.067.000') or u.sumv_usl = 0) AND s.p_cel != '3.0') 
        or
                (u.code_usl like 'D%' AND s.p_cel not in ('2.2')) 
        or
                (u.code_usl like 'P%' AND s.p_cel not in ('2.1')) )
*/
                     


-- Проверка №109 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUM_M', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректная сумма  случая ВМП (VID_HMP="'+isnull(cast(s.VID_HMP as varchar),'')+'" PROFIL="'+isnull(cast(s.PROFIL as varchar),'')
 +'" TARIF="'+isnull(cast(s.SUM_M as varchar),'')+'" K_TARIF="'+isnull(cast(t.K_TARIF as varchar),'')+'")'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('T')
  left join [IES].[R_NSI_VMP_TARIFFS] t on t.LPU=zs.LPU and t.ID_PR=s.PROFIL 
                                and cast(t.f_vmp as varchar) = 
	case
		when @year = 2021 then (select top 1 hgr from ies.R_NSI_HGR_TARIF t100 where s.SUM_M = t100.tarif and t100.datebegin >= '01.01.2021')
		else substring(s.vid_hmp,dbo.instr(s.vid_hmp,'.',1,2)+1,case dbo.instr(s.vid_hmp,'.',1,3)-dbo.instr(s.vid_hmp,'.',1,2)-1 when -1 then 0 else dbo.instr(s.vid_hmp,'.',1,3)-dbo.instr(s.vid_hmp,'.',1,2)-1 end)
	end
	and s.date_2 between t.date_b and t.date_e
    where s.sum_m != isnull(t.K_TARIF,0)


-- Проверка №108.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, s.IDSERV, '904', 'Код услуги "'+isnull(s.CODE_USL,'')+'" нельзя использовать в случаях передаваемых файле '+SUBSTRING(z.FILENAME,1,1)
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_USL s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','T','C')
 where substring(s.CODE_USL,1,1) in ('D','P')

-- Проверка №108 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, s.IDSERV, '904', 'Код услуги "'+isnull(s.CODE_USL,'')+'" нельзя использовать в случаях передаваемых файле D'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_USL s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('D')
 where substring(s.CODE_USL,1,1) not in ('D','P')

-- Проверка №107 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUM_M', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Cумма случая не равна сумме переданных к нему услуг'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  left join (select sum(u.sumv_usl) sumv_usl, u.idcase, u.sl_id from tempdb..TEMP_USL u group by u.idcase, u.sl_id) u on s.idcase=u.idcase and s.sl_id=u.sl_id        
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C','D')
 where isnull(u.sumv_usl,0) <> s.sum_m
   and zs.usl_ok in (3,4)

-- Проверка №106.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMV_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Не корректная сумма услуги. (Код услуги "'+isnull(u.CODE_USL,'')+'"TARIF="'+isnull(cast(u.TARIF as varchar),'')+'" KOL_USL="'
  +isnull(cast(u.KOL_USL as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C','D')
 where u.sumv_usl != round(isnull(u.tarif,0)*isnull(u.kol_usl,0),2)
 -- Исключения для стоматологии
and not
(u.profil in (85,86,87,88,89,90,63,171,140)
and (u.code_usl in ('Z01.063.001','Z01.064.000','Z01.064.001','Z01.067.000')) 
AND zs.DATE_Z_2 < '01.01.2020' 
)	
         

  -- Проверка №106 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMV_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Не корректная сумма услуги или отсутствует тариф на услугу. (Код услуги "'+isnull(u.CODE_USL,'')+'"TARIF="'+isnull(cast(u.TARIF as varchar),'')+'" K_TARIF="'
  +isnull(cast(t.k_tarif as varchar),'')+'" SUM_USL="'+isnull(cast(u.SUMV_USL as varchar),'')+'" K_SUM_USL="'+isnull(cast(round(isnull(t.k_tarif,0)*isnull(u.kol_usl,0),2) as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  left join [IES].[T_CHER_USL_TARIF] t on isnull(t.LPU, u.LPU) = u.LPU 
  and t.USL_CODE=u.code_usl and u.date_out between t.DATE_B and t.DATE_E 
   and t.k_tarif = u.TARIF
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C','D')
 where (u.sumv_usl != round(isnull(t.k_tarif,0)*isnull(u.kol_usl,0),2)
       and zs.usl_ok in (3,4)
	   and zs.DATE_Z_2 >= '01.01.2019')
-- Исключения для стоматологии
       and not
(u.profil in (85,86,87,88,89,90,63,171,140)
and (u.code_usl in ('Z01.063.001','Z01.064.000','Z01.064.001','Z01.067.000')) 
AND zs.DATE_Z_2 < '01.01.2020' 
)	  
     AND (zs.OPLATA <> 2 OR zs.oplata IS null)       
	   -- Ограничение для  МРНЦ по услугам только ДЛЯ МТР (без объёмов по ТЕРСЧЕТАМ)
	   OR (u.LPU = '400109' AND u.code_usl IN ('B03.002.01','B03.002.03','B03.002.05','B03.002.06') and @type = 693 )


 -- Чисто по стоматологии
-- Проверка №110 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMV_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Не корректная сумма стоматологической услуги.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  left join [IES].[T_CHER_USL_TARIF] t on isnull(t.LPU,u.LPU)=u.LPU and t.USL_CODE=u.code_usl and u.date_out between t.DATE_B and t.DATE_E
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where u.sumv_usl != round(isnull(t.k_tarif,0)*isnull(u.kol_usl,0)/2.4,2)
        and zs.usl_ok in (3,4)
        and u.profil in (85,86,87,88,89,90,63,171,140) 
        and u.code_usl in ('Z01.063.001','Z01.064.000','Z01.064.001','Z01.067.000') AND zs.DATE_Z_2 < '01.01.2020'

-- Проверка №106 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMV_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Не корректная сумма услуги или отсутствует тариф на услугу. (Код услуги "'+isnull(u.CODE_USL,'')+'"TARIF="'+isnull(cast(u.TARIF as varchar),'')+'" K_TARIF="'
  +isnull(cast(t.k_tarif as varchar),'')+'" SUM_USL="'+isnull(cast(u.SUMV_USL as varchar),'')+'" K_SUM_USL="'+isnull(cast(round(isnull(t.k_tarif,0)*isnull(u.kol_usl,0),2) as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  left join [IES].[T_CHER_USL_TARIF_2018] t on  isnull(t.LPU,u.LPU)=u.LPU  and t.USL_CODE=u.code_usl and u.date_out between t.DATE_B and t.DATE_E 
   and t.k_tarif > 0
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C','D')
 where u.sumv_usl != round(isnull(t.k_tarif,0)*isnull(u.kol_usl,0),2)
       and zs.usl_ok in (3,4)
	   and zs.DATE_Z_2 < '01.01.2019'

           

-- Проверка №105 (КС-2019) по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Диагноз DS1="'+isnull(cast(s.DS1 as varchar),'')+'" + диагноз DS2="'+isnull(cast(d.DS2 as varchar),'')+'"  + код услуги CODE_USL="'+isnull(cast(u.CODE_USL as varchar),'')+'" не может применяться в указанном КСГ N_KSG="'+isnull(cast(k.N_KSG as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  left join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID and u.SUMV_USL = 0) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
  left join tempdb..TEMP_DS2 d on d.IDCASE=s.IDCASE and d.SL_ID=s.SL_ID
 where ((u.CODE_USL is not null
		 and k.N_KSG not in  (SELECT a.[KSG]  FROM [IESDB].[IES].[T_GR_KSG_KS_2020] a
							  where (usl_code=u.CODE_USL or usl_code is null) 
									and (s.DS1 between mkb and mkb_e or mkb is null)
									and (d.DS2 between mkb2 and mkb2_e or mkb2 is null)
									and a.ksg != 'st29.007'
									and a.YEAR = k.VER_KSG
							 )
		)
    or  (u.CODE_USL is null
	    and k.N_KSG not in (SELECT  a.[KSG]  FROM [IESDB].[IES].[T_GR_KSG_KS_2020] a                      
							where a.usl_code is null
								  and (s.DS1 between mkb and mkb_e or mkb is null)
								  and (d.DS2 between mkb2 and mkb2_e or mkb2 is null)
								  and a.ksg != 'st29.007'
								  and a.YEAR = k.VER_KSG
						   )
	    )
	   )
     and zs.USL_OK = 1
	 and k.n_ksg != 'st29.007'
     and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693  and GETDATE() > '15.03.2019')) 
     AND (zs.OPLATA <> 2 OR zs.oplata IS null)
union 
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Диагноз DS1="'+isnull(cast(s.DS1 as varchar),'')+'" + диагноз DS2="'+isnull(cast(d.DS2 as varchar),'')+'"  + код услуги CODE_USL="'+isnull(cast(u.CODE_USL as varchar),'')+'" не может применяться в указанном КСГ N_KSG="'+isnull(cast(k.N_KSG as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  left join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID and u.SUMV_USL = 0) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
  left join tempdb..TEMP_DS2 d on d.IDCASE=s.IDCASE and d.SL_ID=s.SL_ID
 where ((u.CODE_USL is not null
		 and k.N_KSG not in  (SELECT a.[KSG]  FROM [IESDB].[IES].[T_GR_KSG_DS_2020] a
							  where (usl_code=u.CODE_USL or usl_code is null) 
									and (s.DS1 between mkb and mkb_e or mkb is null)
									and (d.DS2 between mkb2 and mkb2_e or mkb2 is null)
									and a.ksg != 'ds19.033'
									and a.YEAR = k.VER_KSG
							  )
		)
	or (u.CODE_USL is null 
		and k.N_KSG not in (SELECT  a.[KSG]  FROM [IESDB].[IES].[T_GR_KSG_DS_2020] a                      
							where a.usl_code is null 
								  and (s.DS1 between mkb and mkb_e or mkb is null)
								  and (d.DS2 between mkb2 and mkb2_e or mkb2 is null)
								  and a.ksg != 'ds19.033' 
								  and a.YEAR = k.VER_KSG
							)
	    )
	   )
   and zs.USL_OK = 2
   and k.n_ksg != 'ds19.033'
   and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693  and GETDATE() > '15.03.2019')) 
   AND (zs.OPLATA <> 2 OR zs.oplata IS null)
 union
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Диагноз DS1="'+isnull(cast(s.DS1 as varchar),'')+'"  + код услуги CODE_USL="'+isnull(cast(u.CODE_USL as varchar),'')+'" не может применяться в указанном КСГ N_KSG="'+isnull(cast(k.N_KSG as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  left join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID and u.SUMV_USL = 0) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where ((u.CODE_USL is null
		 and k.N_KSG in ('st01.010','st01.011','st14.001','st14.002','st21.001','st34.002','st30.006','st09.001','st31.002'))
     or (u.CODE_USL is not null 
		 and k.N_KSG in ('st02.008','st02.009','st04.002','st21.007','st34.001','st26.001','st30.003','st30.005','st31.017'))
		)
	 and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693  and GETDATE() > '15.03.2019')) 
	 AND (zs.OPLATA <> 2 OR zs.oplata IS null)


-- Проверка №104 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Отсутствует обязательная услуга для указанного КСГ'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  left join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join (select usl_ok, vers, n_ksg from [IES].[T_CHER_KSG_USL] group by usl_ok, vers, n_ksg) t on zs.usl_ok=t.usl_ok and k.n_ksg=t.n_ksg and k.ver_ksg=t.vers
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where u.idserv is null 
 AND (zs.OPLATA <> 2 OR zs.oplata IS null)
 and z.FILENAME not like '%T40%'

 -- Проверка №103.3  (W) 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'N_KSG', 'KSG_KPG', zs.N_ZAP, zs.IDCASE, null, '904', 'Для указанного пола: "'+isnull(cast(c.W as varchar),'')+'"  не может применяться указанный КСГ N_KSG="'+isnull(cast(k.N_KSG as varchar),'')+'" при DS1="'+
 isnull(cast(s.DS1 as varchar),'')+'" и CODE_USL="'+isnull(cast(u.CODE_USL as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join tempdb..TEMP_PACIENT a1 on zs.N_ZAP=a1.N_ZAP
  join tempdb..TEMP_PERS c on a1.ID_PAC= cast(c.ID_PAC as varchar)
  left join tempdb..TEMP_USL u on s.IDCASE=u.IDCASE and s.SL_ID=u.SL_ID
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where exists (select 1 from [IES].[T_GR_KSG_KS_2020] a1 where k.N_KSG=a1.ksg and s.DS1=a1.MKB and a1.W is not null and a1.YEAR = k.VER_KSG)
   and not exists (select top 1 voz from [IES].[T_GR_KSG_KS_2020] a1 where k.N_KSG=a1.ksg and s.DS1=a1.MKB and a1.w=c.W and a1.YEAR = k.VER_KSG)
   and zs.USL_OK = 1
   and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693  and GETDATE() > '15.03.2019')) 
   union
 select 'N_KSG', 'KSG_KPG', zs.N_ZAP, zs.IDCASE, null, '904', 'Для указанного пола: "'+isnull(cast(c.W as varchar),'')+'"  не может применяться указанный КСГ N_KSG="'+isnull(cast(k.N_KSG as varchar),'')+'" при DS1="'+
 isnull(cast(s.DS1 as varchar),'')+'" и CODE_USL="'+isnull(cast(u.CODE_USL as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join tempdb..TEMP_PACIENT a1 on zs.N_ZAP=a1.N_ZAP
  join tempdb..TEMP_PERS c on a1.ID_PAC= cast(c.ID_PAC as varchar)
  left join tempdb..TEMP_USL u on s.IDCASE=u.IDCASE and s.SL_ID=u.SL_ID
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where exists (select 1 from [IES].[T_GR_KSG_DS_2020] a1 where k.N_KSG=a1.ksg and s.DS1=a1.MKB and a1.W is not null and a1.YEAR = k.VER_KSG)
   and not exists (select top 1 voz from [IES].[T_GR_KSG_DS_2020] a1 where k.N_KSG=a1.ksg and s.DS1=a1.MKB and a1.w=c.W and a1.YEAR = k.VER_KSG)
   and zs.USL_OK = 2 
   and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693  and GETDATE() > '15.03.2019')) 

-- Проверка №103.2  (VOZ) 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'N_KSG', 'KSG_KPG', zs.N_ZAP, zs.IDCASE, null, '904', 'Для указанного возраста: "'+isnull(cast(DATEDIFF(DAY,DR,DATE_2)/365.2425 as varchar),'')+'"  не может применяться указанный КСГ N_KSG="'+isnull(cast(k.N_KSG as varchar),'')+'" при DS1="'+
 isnull(cast(s.DS1 as varchar),'')+'" и CODE_USL="'+isnull(cast(u.CODE_USL as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join tempdb..TEMP_PACIENT a1 on zs.N_ZAP=a1.N_ZAP
  join tempdb..TEMP_PERS c on a1.ID_PAC= cast(c.ID_PAC as varchar)
  left join tempdb..TEMP_USL u on s.IDCASE=u.IDCASE and s.SL_ID=u.SL_ID
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where exists (select 1 from [IES].[T_GR_KSG_KS_2020] a1 where k.N_KSG=a1.ksg and a1.voz is not null and a1.YEAR = k.VER_KSG and (s.DS1 between mkb and mkb_e 
								  or (mkb is null and not exists (select 1 from [IES].[T_GR_KSG_KS_2020] a1 where k.n_KSG=a1.ksg and a1.YEAR = k.ver_ksg and s.ds1 between mkb and mkb_e))))
   and case when DATEDIFF(DAY,DR,DATE_1) between 0 and 28 then 1
			when DATEDIFF(DAY,DR,DATE_1) between 29 and 90 then 2
			when DATEDIFF(DAY,DR,DATE_1) between 91 and 366 then 3
			when DATEDIFF(DAY,DR,DATE_1)/365.2425 between 0 and 2 then 4
            when DATEDIFF(DAY,DR,DATE_1)/365.2425 between 0 and 18 then 5
            when DATEDIFF(DAY,DR,DATE_1)/365.2425 between 18 and 200 then 6
			else 7
       end >
    (select top 1 voz from [IES].[T_GR_KSG_KS_2020] a1 where k.N_KSG=a1.ksg and a1.voz is not null and a1.YEAR = k.VER_KSG
 		                     and (a1.usl_code=u.CODE_USL or a1.usl_code is null) 
                             and (s.DS1 between mkb and mkb_e 
								  or (mkb is null and not exists (select 1 from [IES].[T_GR_KSG_KS_2020] a1 where k.n_KSG=a1.ksg and a1.YEAR = k.ver_ksg and s.ds1 between mkb and mkb_e))))
   and zs.USL_OK = 1
   and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693  and GETDATE() > '15.03.2019')) 
   union
 select 'N_KSG', 'KSG_KPG', zs.N_ZAP, zs.IDCASE, null, '904', 'Для указанного возраста: "'+isnull(cast(DATEDIFF(DAY,DR,DATE_2)/365.2425 as varchar),'')+'"  не может применяться указанный КСГ N_KSG="'+isnull(cast(k.N_KSG as varchar),'')+'" при DS1="'+
 isnull(cast(s.DS1 as varchar),'')+'" и CODE_USL="'+isnull(cast(u.CODE_USL as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join tempdb..TEMP_PACIENT a1 on zs.N_ZAP=a1.N_ZAP
  join tempdb..TEMP_PERS c on a1.ID_PAC= cast(c.ID_PAC as varchar)
  left join tempdb..TEMP_USL u on s.IDCASE=u.IDCASE and s.SL_ID=u.SL_ID
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where exists (select 1 from [IES].[T_GR_KSG_DS_2020] a1 where k.N_KSG=a1.ksg and a1.voz is not null and a1.YEAR = k.VER_KSG and (s.DS1 between mkb and mkb_e 
								  or (mkb is null and not exists (select 1 from [IES].[T_GR_KSG_DS_2020] a1 where k.n_KSG=a1.ksg and a1.YEAR = k.ver_ksg and s.ds1 between mkb and mkb_e))))
   and case when DATEDIFF(DAY,DR,DATE_1) between 0 and 28 then 1
			when DATEDIFF(DAY,DR,DATE_1) between 29 and 90 then 2
			when DATEDIFF(DAY,DR,DATE_1) between 91 and 366 then 3
			when DATEDIFF(DAY,DR,DATE_1)/365.2425 between 0 and 2 then 4
            when DATEDIFF(DAY,DR,DATE_1)/365.2425 between 0 and 18 then 5
            when DATEDIFF(DAY,DR,DATE_1)/365.2425 between 18 and 200 then 6
			else 7
       end >
	(select top 1 voz from [IES].[T_GR_KSG_DS_2020] a1 where k.N_KSG=a1.ksg and a1.voz is not null and a1.YEAR = k.VER_KSG
 		                     and (a1.usl_code=u.CODE_USL or a1.usl_code is null) 
                             and (s.DS1 between mkb and mkb_e 
								  or (mkb is null and not exists (select 1 from [IES].[T_GR_KSG_DS_2020] a1 where k.n_KSG=a1.ksg and a1.YEAR = k.ver_ksg and s.ds1 between mkb and mkb_e))))
   and zs.USL_OK = 2
   and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693  and GETDATE() > '15.03.2019')) 

 -- Проверка №103.1  (CRIT) 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Классификационный критерий CRIT="'+isnull(cast(c.CRIT as varchar),'')+'"  не может применяться в указанном КСГ N_KSG="'+isnull(cast(k.N_KSG as varchar),'')+'" при DS1="'+
 isnull(cast(s.DS1 as varchar),'')+'" и CODE_USL="'+isnull(cast(u.CODE_USL as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  left join tempdb..TEMP_CRIT c on k.IDCASE=c.IDCASE and k.SL_ID=c.SL_ID
  left join tempdb..TEMP_USL u on s.IDCASE=u.IDCASE and s.SL_ID=u.SL_ID
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where ((
         exists (select 1 from [IES].[T_GR_KSG_KS_2020] a1 where k.N_KSG=a1.ksg and a1.crit is not null and a1.YEAR = k.VER_KSG
 		                        and (a1.usl_code=u.CODE_USL or a1.usl_code is null) 
                               and (s.DS1 between mkb and mkb_e or mkb is null  or s.DS1 between mkb2 and mkb2_e)
                )
        and (c.CRIT is null 
             or c.CRIT not in (select a1.crit from [IES].[T_GR_KSG_KS_2020] a1 where k.N_KSG=a1.ksg and a1.crit is not null and a1.YEAR = k.VER_KSG)
         )
		) 
		or
   (
      c.CRIT not in (select a1.CRIT from [IES].[T_GR_KSG_KS_2020] a1 where k.N_KSG=a1.ksg and a1.crit is not null and a1.YEAR = k.VER_KSG
 		                        and (a1.usl_code=u.CODE_USL or a1.usl_code is null) 
                               and (s.DS1 between mkb and mkb_e or mkb is null  or s.DS1 between mkb2 and mkb2_e)
                )
      and c.CRIT is not null 
	))
   and zs.USL_OK = 1
   and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693  and GETDATE() > '15.03.2019')) 
   AND (zs.OPLATA <> 2 OR zs.oplata IS null)
   union
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Классификационный критерий CRIT="'+isnull(cast(c.CRIT as varchar),'')+'"  не может применяться в указанном КСГ N_KSG="'+isnull(cast(k.N_KSG as varchar),'')+'" при DS1="'+
 isnull(cast(s.DS1 as varchar),'')+'" и CODE_USL="'+isnull(cast(u.CODE_USL as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  left join tempdb..TEMP_CRIT c on k.IDCASE=c.IDCASE and k.SL_ID=c.SL_ID
  left join tempdb..TEMP_USL u on s.IDCASE=u.IDCASE and s.SL_ID=u.SL_ID
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where ((
         exists (select 1 from [IES].[T_GR_KSG_DS_2020] a1 where k.N_KSG=a1.ksg and a1.crit is not null and a1.YEAR = k.VER_KSG
 		                        and (a1.usl_code=u.CODE_USL or a1.usl_code is null) 
                               and (s.DS1 between mkb and mkb_e or mkb is null  or s.DS1 between mkb2 and mkb2_e)
                )
        and (c.CRIT is null 
             or c.CRIT not in (select a1.crit from [IES].[T_GR_KSG_DS_2020] a1 where k.N_KSG=a1.ksg and a1.crit is not null and a1.YEAR = k.VER_KSG)
         )
		and c.CRIT not in (select 1 from [IES].[T_GR_KSG_DS_2020] a1 where k.N_KSG=a1.ksg and a1.crit is null and a1.YEAR = k.VER_KSG
 		                        and (a1.usl_code=u.CODE_USL) 
                               and (s.DS1 between mkb and mkb_e or mkb is null  or s.DS1 between mkb2 and mkb2_e))
		) 
		or
   (
      c.CRIT not in (select a1.CRIT from [IES].[T_GR_KSG_DS_2020] a1 where k.N_KSG=a1.ksg and a1.crit is not null and a1.YEAR = k.VER_KSG
 		                        and (a1.usl_code=u.CODE_USL or a1.usl_code is null) 
                               and (s.DS1 between mkb and mkb_e or mkb is null  or s.DS1 between mkb2 and mkb2_e)
                )
        and c.CRIT is not null 
	))
   and zs.USL_OK = 2
   and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693  and GETDATE() > '15.03.2019')) 
   AND (zs.OPLATA <> 2 OR zs.oplata IS null)
   /*
   -- Проверка №103 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Некорректный код услуги в рамках КСГ'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  inner join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where exists (select 1 from [IES].[T_CHER_KSG_USL] t where zs.usl_ok=t.usl_ok and k.n_ksg=t.n_ksg and k.ver_ksg=t.vers)
   and not exists (select 1 from [IES].[T_CHER_KSG_USL] t where zs.usl_ok=t.usl_ok and k.n_ksg=t.n_ksg and k.ver_ksg=t.vers and u.CODE_USL=t.usl_code)
   and u.code_usl like 'A%'
   and u.code_usl not in (select t.usl_code from [IES].T_CHER_KSG_KSLP t)
*/

-- Проверка №102.1 по базе в ОРАКЛЕ
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMV_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'При ВМП стоимость услуги не должна быть больше 0'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL u on u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('T')
 where u.sumv_usl > 0 and u.CODE_USL not in ('A18.05.002', 'A18.05.002.001', 'A18.05.002.002', 'A18.05.002.003', 'A18.05.002.005', 'A18.05.003', 'A18.05.003.002', 
 'A18.05.004', 'A18.05.004.001','A18.05.011','A18.05.011.001','A18.05.011.002','A18.30.001','A18.30.001.001','A18.30.001.002','A18.30.001.003','A18.05.001.001','A18.05.001.004')

-- Проверка №102 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUMV_USL', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'При использовании КСГ стоимость услуги не должна быть больше 0'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL u on u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where u.sumv_usl > 0 and u.CODE_USL not in ('A18.05.002', 'A18.05.002.001', 'A18.05.002.002', 'A18.05.002.003', 'A18.05.002.005', 'A18.05.003', 'A18.05.003.002', 
 'A18.05.004', 'A18.05.004.001','A18.05.011','A18.05.011.001','A18.05.011.002','A18.30.001','A18.30.001.001','A18.30.001.002','A18.30.001.003','A18.05.001.001','A18.05.001.004')
 
-- Проверка №101 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PLAT', 'SCHET', null, null, null, '904', 'Для счетов по МТР поле PLAT должно быть пустым.'
 from tempdb..TEMP_SCHET t
 where t.PLAT is not null and @type=554

-- Проверка №100 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PLAT', 'SCHET', null, null, null, '904', 'Не указан прательщик.'
 from tempdb..TEMP_SCHET t
 where t.PLAT is null and @type=693

-- Проверка №99 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PLAT', 'SCHET', null, null, null, '904', 'Значение PLAT="'+isnull(cast(t.PLAT as varchar),'')+'" не соответствует допустимому значению  в справочнике F002'
 from tempdb..TEMP_SCHET t
  left join [IES].[T_F002_SMO] t3 on t.plat=t3.SMOCOD and t.DSCHET between t3.D_BEGIN and isnull(t3.D_END,t.DSCHET)
 where t3.SMOCOD is null and @type=693

-- Проверка №98.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAPR_USL', 'NAPR', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан код медицинской услуги (NAPR_USL) при заполненном методе диагностического исследования'
 from tempdb..TEMP_Z_SLUCH zs
  join  tempdb..TEMP_SLUCH t1 on zs.IDCASE=t1.IDCASE
  join tempdb..TEMP_NAPR t on (t.IDCASE=t1.IDCASE and t.SL_ID=t1.SL_ID) 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('T','C')
 where t.MET_ISSL is not null and t.NAPR_USL is null

-- Проверка №98 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAPR_USL', 'NAPR', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAPR_USL="'+isnull(cast(t.NAPR_USL as varchar),'')+'" не соответствует допустимому значению  в справочнике V001'
 from tempdb..TEMP_Z_SLUCH zs
  join  tempdb..TEMP_SLUCH t1 on zs.IDCASE=t1.IDCASE
  join tempdb..TEMP_NAPR t on (t.IDCASE=t1.IDCASE and t.SL_ID=t1.SL_ID) 
  left join [IES].[T_V001_NOMENCLATURE] t3 on t.NAPR_USL=t3.Code --and t1.DATE_1 between t3.DATEBEG and isnull(t3.DATEEND,t1.DATE_1)
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('T','C')
 where t3.Code is null and t.NAPR_USL is not null

 -- Проверка №97.3 по базе в ОРАКЛЕ 
 --insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 --select 'VID_VME', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Указанный код ВМВ VID_VME="'+isnull(cast(s.VID_VME as varchar),'')+'" не может применяться для кода вида ВМП="'+
 -- isnull(cast(t.VID_HMP as varchar),'')+'"'
 --from tempdb..TEMP_Z_SLUCH zs
 -- join  tempdb..TEMP_SLUCH t on zs.IDCASE=t.IDCASE
 -- join tempdb..TEMP_USL s on s.IDCASE=t.IDCASE and s.SL_ID=t.SL_ID 
 -- join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('T')
 -- left join iesdb.IES.T_V019_VMP_METHOD t14 on cast(s.VID_VME as varchar(15))=cast(t14.IDHM as varchar(15)) and t.VID_HMP=t14.HVID
 --where s.VID_VME is not null 
 --  and cast(s.VID_VME as varchar(15)) != cast(t14.IDHM as varchar(15))
 --  and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693 and GETDATE() > '15.03.2019'))

 -- Проверка №97.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'VID_VME', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Указанный код ВМВ VID_VME="'+isnull(cast(s.VID_VME as varchar),'')+'" не может применяться для услуги CODE_USL="'+
  isnull(cast(s.CODE_USL as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join  tempdb..TEMP_SLUCH t on zs.IDCASE=t.IDCASE
  join tempdb..TEMP_USL s on s.IDCASE=t.IDCASE and s.SL_ID=t.SL_ID 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('C')
  join iesdb.IES.R_NSI_USL_V001 t0 on s.CODE_USL=t0.CODE_USL
  left join iesdb.IES.T_V001_NOMENCLATURE t14 on t0.Nomenclature=t14.NomenclatureID
 where s.VID_VME is not null 
   and cast(s.VID_VME as varchar(15)) != cast(t14.Code as varchar(15))
   and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693 and GETDATE() > '15.03.2019'))

-- Проверка №97.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'VID_VME', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан код ВМВ при установленном диагнозе ЗНО'
 from tempdb..TEMP_Z_SLUCH zs
  join  tempdb..TEMP_SLUCH t on zs.IDCASE=t.IDCASE
  join tempdb..TEMP_USL s on s.IDCASE=t.IDCASE and s.SL_ID=t.SL_ID 
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('T','C')
 where s.VID_VME is null 
   and (substring(t.ds1,1,1) = 'C' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS2 from tempdb..TEMP_DS2 ds where (ds.DS2 between 'C00' and 'C80.9' or  ds.ds2 between 'C97' and 'C97.9'))))

-- Проверка №97.1.1 по базе в ОРАКЛЕ 
 --insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 --select 'VID_VME', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение VID_VME="'+isnull(cast(s.VID_VME as varchar),'')+'" не соответствует допустимому значению  в справочнике V019'
 --from tempdb..TEMP_Z_SLUCH zs
 -- join tempdb..TEMP_USL s on (s.IDCASE=zs.IDCASE)
 -- join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('T') 
 -- left join [IES].[T_V019_VMP_METHOD_PREV] v019 on cast(s.VID_VME as varchar(15))=cast(v019.V019VmpMethod as varchar(15)) and zs.DATE_Z_2 between v019.DATEBEG and isnull(v019.DATEEND,zs.DATE_Z_2)
 --where v019.V019VmpMethod is null and s.VID_VME is not null and zs.DATE_Z_2>'30.12.2019'

-- Проверка №97 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'VID_VME', 'USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение VID_VME="'+isnull(cast(s.VID_VME as varchar),'')+'" не соответствует допустимому значению  в справочнике V001'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_USL s on (s.IDCASE=zs.IDCASE) 
  left join [IES].[T_V001_NOMENCLATURE] t3 on s.VID_VME=t3.Code and zs.DATE_Z_2 between t3.DATEBEG and isnull(t3.DATEEND,zs.DATE_Z_2)
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where t3.Code is null and s.VID_VME is not null

-- Проверка №95.3 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDSL', 'SL_KOEF', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение поля IT_SL не соответствует сумме переданных коэфециентов в блоке SL_KOEF'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
--  join tempdb..TEMP_SL_KOEF sl on sl.IDCASE=s.IDCASE and sl.SL_ID=s.SL_ID
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID and k.SL_K=1
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where  k.IT_SL != (SELECT sum(sl.Z_SL-1)+1 FROM tempdb..TEMP_SL_KOEF sl where sl.IDCASE=s.IDCASE and sl.SL_ID=s.SL_ID) 
	and z.FILENAME not like '%T40%'

-- Проверка №95.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDSL', 'SL_KOEF', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректный КСЛП либо коэффециенты к нему'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_SL_KOEF sl on sl.IDCASE=s.IDCASE and sl.SL_ID=s.SL_ID
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where not exists(SELECT top 1 t.DictionaryBaseID FROM [IES].[R_NSI_KSLP] t WHERE t.IDSL=sl.IDSL and t.ZKOEF=sl.Z_SL and s.DATE_2 between t.DATE_BEGIN and t.DATE_END)
	and z.FILENAME not like '%T40%'
 
-- Проверка №95.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'N_KSG', 'KSG_KPG', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение CRIT="'+isnull(cast(k.CRIT as varchar),'')+'" не соответствует допустимому значению  в справочнике'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_CRIT k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  left join [IES].[T_V024_DOP_KR] t3 on k.CRIT=t3.IDDKK and zs.DATE_Z_2 between t3.DATEBEG and isnull(t3.DATEEND,zs.DATE_Z_2)
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where t3.IDDKK is null and k.CRIT is not null

-- Проверка №95 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'N_KSG', 'KSG_KPG', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректный КСГ либо коэффециенты к нему'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where (not exists(SELECT top 1 t.DictionaryBaseID FROM [IES].[T_SPR_KSG_TARIF] t WHERE t.LPU=zs.lpu and t.USL_OK=zs.usl_ok and t.F_KSG_CODE=k.n_ksg and t.VERS=k.ver_ksg
  and t.K_BAZA=k.bztsz and t.K_ZATR=k.koef_z and t.K_UPR=k.koef_up and t.K_UR=k.koef_u and t.IDPR = s.PROFIL and (s.DATE_2 between t.DATE_B and t.DATE_E))
  and zs.lpu not in (select r.MCOD_After from IESDB.IES.R_NSI_MO_MERGER r))
  AND (zs.OPLATA <> 2 OR zs.oplata IS null)
  or k.KOEF_D <> 1 

-- Проверка №95.0 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'N_KSG', 'KSG_KPG', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректный КСГ либо коэффециенты к нему'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
 where s.DATE_2<'01.01.2020' and
 ((not exists(SELECT top 1 t.DictionaryBaseID FROM [IES].[T_SPR_KSG_TARIF] t WHERE t.LPU=zs.lpu and t.LPU_1=s.LPU_1 and t.USL_OK=zs.usl_ok and t.F_KSG_CODE=k.n_ksg and t.VERS=k.ver_ksg
  and t.K_BAZA=k.bztsz and t.K_ZATR=k.koef_z and t.K_UPR=k.koef_up and t.K_UR=k.koef_u and t.IDPR = s.PROFIL and (s.DATE_2 between t.DATE_B and t.DATE_E))
  and zs.lpu in (select r.MCOD_After from IESDB.IES.R_NSI_MO_MERGER r))
    AND (zs.OPLATA <> 2 OR zs.oplata IS null)
  or k.KOEF_D <> 1) 


  -- Проверка №94 (расчет на 2021 год) 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUM_M', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректный расчет стоимости по КСГ '+cast(k.N_KSG as varchar)+' SUM_M="'+cast(s.sum_m as varchar)+'" SUM_M_R="'+cast(
  round(k.koef_z * k.koef_up * case k.koef_d when 0 then 1 else k.koef_d end * k.koef_u * k.bztsz * case k.SL_K when 1 then k.IT_SL else 1 end * 
	   isnull(convert(decimal(15,2),      (case
												when (DATEDIFF(day,s.DATE_1,s.DATE_2)+1) >= isnull(a1.DLIT,999) 
													then l.koef
												when (DATEDIFF(day,s.DATE_1,s.DATE_2)+1) < isnull(a1.DLIT,999) 
													and s.kd > 3 
													then 0.5
												  when (DATEDIFF(day,s.DATE_1,s.DATE_2)+1) < isnull(a1.DLIT,999) 
													and s.kd in (1,2,3) 
													then 0.2
												end
												))
												, case 
												---КСГ исключения
												  when zs.RSLT not in (107,207,102,202,105,205,110)
													and k.n_ksg in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089') 
													then 1 
												  when zs.RSLT in (107,207,102,202,105,205,110)
													and k.n_ksg in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089') 
													and s.kd in (1,2,3) 
													then 0.8
												  when zs.RSLT in (107,207,102,202,105,205,110)
													and k.n_ksg in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089') 
													and s.kd > 3 
													then 0.9
												---Остальные КСГ без услуги без прерывания
												  when zs.RSLT not in (107,207,102,202,105,205,110)
													and k.n_ksg not in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089') 
													and s.kd in (1,2,3)
													and (su.code_usl is not null) 
													then 0.8
												  when zs.RSLT not in (107,207,102,202,105,205,110)
													and k.n_ksg not in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089') 
													and s.kd > 3 
													and (su.code_usl is not null) 
													then 1
												---Остальные КСГ с услугой	без прерывания
												  when zs.RSLT not in (107,207,102,202,105,205,110)
													and k.n_ksg not in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089')  
													and s.kd in (1,2,3)
													and (su.code_usl is null) 													
													then 0.2
												  when zs.RSLT not in (107,207,102,202,105,205,110)
												  	and k.n_ksg not in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089')  												  
													and s.kd > 3 
													and (su.code_usl is null)													
													then 1
												---Остальные КСГ с услугой	с прерыванием	
												  when zs.RSLT in (107,207,102,202,105,205,110)
												  	and k.n_ksg not in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089')  
													and s.kd in (1,2,3)  
													and (su.code_usl is not null) 
													then 0.8
												  when zs.RSLT in (107,207,102,202,105,205,110)
												  	and k.n_ksg not in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089')  
													and s.kd > 3
													and (su.code_usl is not null)
													then 0.9
												---Остальные КСГ без услуги с прерыванием	
												  when zs.RSLT in (107,207,102,202,105,205,110)
												  	and k.n_ksg not in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089')  
													and s.kd in (1,2,3)
													and (su.code_usl is null) 
													then 0.2
												  when zs.RSLT in (107,207,102,202,105,205,110)
													and k.n_ksg not in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089')  
													and s.kd > 3
													and (su.code_usl is null) 
													then 0.5
												  end) 
												  * convert(decimal(20,10),kf.KOEFF) --новый коэффициент
												   ,2) + (select isnull(sum(u.sumv_usl),0) from tempdb..TEMP_USL u where u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) as varchar)+
	   '"' 
 --select 'SUM_M', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', ' КСГ '+cast(k.N_KSG as varchar)+' SUM_M="'+cast(s.sum_m as varchar)+'" SUM_M_R="'+
 --cast(k.koef_z as varchar)+char(10)+cast( k.koef_up as varchar)+char(10)+cast( (case k.koef_d when 0 then 1 else k.koef_d end) as varchar)+char(10)+cast(  k.koef_u as varchar)+
 -- char(10)+cast( k.bztsz as varchar)+char(10)+cast((case k.SL_K when 1 then k.IT_SL else 1 end) as varchar)+
 -- char(10)+cast(isnull(convert(decimal(15,2),l.koef), case when s.kd in (1,2,3) then 0.25 else 1 end) as varchar) + char(10)+cast(s.kd as varchar)+
 -- char(10)+cast((select isnull(sum(u.sumv_usl),0) from tempdb..TEMP_USL u where u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) as varchar)+
 -- +char(10)+cast(
 --round(k.koef_z * k.koef_up * case k.koef_d when 0 then 1 else k.koef_d end * k.koef_u * k.bztsz * case k.SL_K when 1 then k.IT_SL else 1 end * 
	--   isnull(convert(decimal(15,2),l.koef), case when s.kd in (1,2,3) then 0.25 else 1 end) ,2) + (select isnull(sum(u.sumv_usl),0) from tempdb..TEMP_USL u where u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) as varchar)+
	--   '"' 

 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  left join tempdb..TEMP_CRIT c on k.IDCASE=c.IDCASE and k.SL_ID=c.SL_ID
  left join tempdb..TEMP_USL su on su.IDCASE=s.IDCASE and su.SL_ID=s.SL_ID 
  left join [IES].[T_CHER_KSG_KDP] l on cast(l.N_KSG as varchar)=k.n_ksg
                                         and s.date_2 between l.date_b and l.date_e 
                                         and s.kd between l.kdp_b and l.kdp_e 
                                         and zs.usl_ok=l.usl_ok
  left join [IES].[T_CHER_KOEFF_K_KSG] kf on cast(kf.KSG as varchar)=k.n_ksg
                                         and s.date_2 between kf.dbeg and kf.dend 
                                         and zs.LPU=kf.lpu
  join iesdb.[IES].[T_GR_CRIT_DLIT] a1 on (k.N_KSG=a1.ksg OR A1.KSG IS NULL)
											and c.CRIT = a1.sh 
											and a1.YEAR = k.VER_KSG
											AND ZS.USL_OK =A1.USL_OK
  --left join (SELECT v.idcase, v.sl_id, 1 + SUM (v.idsl - 1) kslp_koef from  tempdb..TEMP_SL_KOEF v group by v.idcase, v.sl_id) v on s.idcase=v.idcase and s.sl_id=v.sl_id
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
      where s.sum_m != round(k.koef_z * k.koef_up * case k.koef_d when 0 then 1 else k.koef_d end * k.koef_u * k.bztsz * case k.SL_K when 1 then k.IT_SL else 1 end *--isnull(v.kslp_koef,1) * 
	   isnull(convert(decimal(15,2),      (case
												when (DATEDIFF(day,s.DATE_1,s.DATE_2)+1) >= isnull(a1.DLIT,999) 
													then l.koef
												when (DATEDIFF(day,s.DATE_1,s.DATE_2)+1) < isnull(a1.DLIT,999) 
													and s.kd > 3 
													then 0.5
												  when (DATEDIFF(day,s.DATE_1,s.DATE_2)+1) < isnull(a1.DLIT,999) 
													and s.kd in (1,2,3) 
													then 0.2
												end
												)), case 
												---КСГ исключения
												  when zs.RSLT not in (107,207,102,202,105,205,110)
													and k.n_ksg in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089') 
													then 1 
												  when zs.RSLT in (107,207,102,202,105,205,110)
													and k.n_ksg in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089') 
													and s.kd in (1,2,3) 
													then 0.8
												  when zs.RSLT in (107,207,102,202,105,205,110)
													and k.n_ksg in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089') 
													and s.kd > 3 
													then 0.9
												---Остальные КСГ без услуги без прерывания
												  when zs.RSLT not in (107,207,102,202,105,205,110)
													and k.n_ksg not in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089') 
													and s.kd in (1,2,3)
													and (su.code_usl is not null) 
													then 0.8
												  when zs.RSLT not in (107,207,102,202,105,205,110)
													and k.n_ksg not in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089') 
													and s.kd > 3 
													and (su.code_usl is not null) 
													then 1
												---Остальные КСГ с услугой	без прерывания
												  when zs.RSLT not in (107,207,102,202,105,205,110)
													and k.n_ksg not in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089')  
													and s.kd in (1,2,3)
													and (su.code_usl is null) 													
													then 0.2
												  when zs.RSLT not in (107,207,102,202,105,205,110)
												  	and k.n_ksg not in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089')  												  
													and s.kd > 3 
													and (su.code_usl is null)													
													then 1
												---Остальные КСГ с услугой	с прерыванием	
												  when zs.RSLT in (107,207,102,202,105,205,110)
												  	and k.n_ksg not in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089')  
													and s.kd in (1,2,3)  
													and (su.code_usl is not null) 
													then 0.8
												  when zs.RSLT in (107,207,102,202,105,205,110)
												  	and k.n_ksg not in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089')  
													and s.kd > 3
													and (su.code_usl is not null)
													then 0.9
												---Остальные КСГ без услуги с прерыванием	
												  when zs.RSLT in (107,207,102,202,105,205,110)
												  	and k.n_ksg not in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089')  
													and s.kd in (1,2,3)
													and (su.code_usl is null) 
													then 0.2
												  when zs.RSLT in (107,207,102,202,105,205,110)
													and k.n_ksg not in ('Ds02.008','Ds02.009','Ds02.010','Ds02.011','Ds19.053','Ds19.054','Ds19.057','Ds19.058','St19.078','St19.082','St19.088','St19.089')  
													and s.kd > 3
													and (su.code_usl is null) 
													then 0.5
												  end)
												  * convert(decimal(20,10),kf.KOEFF) --новый коэффициент 
												  ,2) + (select isnull(sum(u.sumv_usl),0) from tempdb..TEMP_USL u where u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID)
		and zs.DATE_Z_2 >= '01.01.2021'
		AND (zs.OPLATA <> 2 OR zs.oplata IS null)

  -- Проверка №94 (расчет на 2020 год) 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUM_M', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректный расчет стоимости по КСГ '+cast(k.N_KSG as varchar)+' SUM_M="'+cast(s.sum_m as varchar)+'" SUM_M_R="'+cast(
  round(k.koef_z * k.koef_up * case k.koef_d when 0 then 1 else k.koef_d end * k.koef_u * k.bztsz * case k.SL_K when 1 then k.IT_SL else 1 end * 
	   isnull(convert(decimal(15,2),l.koef), case when s.kd in (1,2,3) then 0.25 else 1 end) ,2) + (select isnull(sum(u.sumv_usl),0) from tempdb..TEMP_USL u where u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) as varchar)+
	   '"' 
 --select 'SUM_M', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', ' КСГ '+cast(k.N_KSG as varchar)+' SUM_M="'+cast(s.sum_m as varchar)+'" SUM_M_R="'+
 --cast(k.koef_z as varchar)+char(10)+cast( k.koef_up as varchar)+char(10)+cast( (case k.koef_d when 0 then 1 else k.koef_d end) as varchar)+char(10)+cast(  k.koef_u as varchar)+
 -- char(10)+cast( k.bztsz as varchar)+char(10)+cast((case k.SL_K when 1 then k.IT_SL else 1 end) as varchar)+
 -- char(10)+cast(isnull(convert(decimal(15,2),l.koef), case when s.kd in (1,2,3) then 0.25 else 1 end) as varchar) + char(10)+cast(s.kd as varchar)+
 -- char(10)+cast((select isnull(sum(u.sumv_usl),0) from tempdb..TEMP_USL u where u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) as varchar)+
 -- +char(10)+cast(
 --round(k.koef_z * k.koef_up * case k.koef_d when 0 then 1 else k.koef_d end * k.koef_u * k.bztsz * case k.SL_K when 1 then k.IT_SL else 1 end * 
	--   isnull(convert(decimal(15,2),l.koef), case when s.kd in (1,2,3) then 0.25 else 1 end) ,2) + (select isnull(sum(u.sumv_usl),0) from tempdb..TEMP_USL u where u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) as varchar)+
	--   '"' 

 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  left join [IES].[T_CHER_KSG_KDP] l on cast(l.N_KSG as varchar)=k.n_ksg 
                                         and s.date_2 between l.date_b and l.date_e 
                                         and s.kd between l.kdp_b and l.kdp_e 
                                         and zs.usl_ok=l.usl_ok
  --left join (SELECT v.idcase, v.sl_id, 1 + SUM (v.idsl - 1) kslp_koef from  tempdb..TEMP_SL_KOEF v group by v.idcase, v.sl_id) v on s.idcase=v.idcase and s.sl_id=v.sl_id
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
      where s.sum_m != round(k.koef_z * k.koef_up * case k.koef_d when 0 then 1 else k.koef_d end * k.koef_u * k.bztsz * case k.SL_K when 1 then k.IT_SL else 1 end *--isnull(v.kslp_koef,1) * 
	   isnull(convert(decimal(15,2),l.koef), case when s.kd in (1,2,3) then 0.25 else 1 end) ,2) + (select isnull(sum(u.sumv_usl),0) from tempdb..TEMP_USL u where u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID)
		and zs.DATE_Z_2 >= '01.01.2020'
		AND (zs.OPLATA <> 2 OR zs.oplata IS null)
		and zs.DATE_Z_2 < '01.01.2021'

  -- Проверка №94 (расчет на 2019 год) 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUM_M', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректный расчет стоимости по КСГ '+cast(k.N_KSG as varchar)+' SUM_M="'+cast(s.sum_m as varchar)+'" SUM_M_R="'+cast(
  round(k.koef_z * k.koef_up * case k.koef_d when 0 then 1 else k.koef_d end * k.koef_u * k.bztsz * case k.SL_K when 1 then k.IT_SL else 1 end * 
	   isnull(l.koef, case when s.kd in (1,2,3) then 0.5 else 1 end) ,2) + (select isnull(sum(u.sumv_usl),0) from tempdb..TEMP_USL u where u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) as varchar)+
	   '"' 
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  left join [IES].[T_CHER_KSG_KDP] l on cast(l.N_KSG as varchar)=k.n_ksg 
                                         and s.date_2 between l.date_b and l.date_e 
                                         and s.kd between l.kdp_b and l.kdp_e 
                                         and zs.usl_ok=l.usl_ok
  --left join (SELECT v.idcase, v.sl_id, 1 + SUM (v.idsl - 1) kslp_koef from  tempdb..TEMP_SL_KOEF v group by v.idcase, v.sl_id) v on s.idcase=v.idcase and s.sl_id=v.sl_id
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
      where s.sum_m != round(k.koef_z * k.koef_up * case k.koef_d when 0 then 1 else k.koef_d end * k.koef_u * k.bztsz * case k.SL_K when 1 then k.IT_SL else 1 end *--isnull(v.kslp_koef,1) * 
	   isnull(l.koef, case when s.kd in (1,2,3) then 0.5 else 1 end) ,2) + (select isnull(sum(u.sumv_usl),0) from tempdb..TEMP_USL u where u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID)
		and zs.DATE_Z_2 >= '01.01.2019'
        and ((@type = 693 and GETDATE() > '01.04.2019') or (@type != 693)) 
		AND (zs.OPLATA <> 2 OR zs.oplata IS null)
		and zs.DATE_Z_2 < '01.01.2020'

  -- Проверка №94 (расчет на 2018 год) 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SUM_M', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не корректный расчет стоимости по КСГ'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_KSG_KPG k on k.IDCASE=s.IDCASE and k.SL_ID=s.SL_ID
  left join [IES].[T_CHER_KSG_KDP] l on cast(l.ksg as varchar)=k.n_ksg 
                                         and s.date_2 between l.date_b and l.date_e 
                                         and s.kd between l.kdp_b and l.kdp_e 
                                         and zs.usl_ok=l.usl_ok
  left join (SELECT v.idcase, v.sl_id, 1 + SUM (v.idsl - 1) kslp_koef from  tempdb..TEMP_SL_KOEF v group by v.idcase, v.sl_id) v on s.idcase=v.idcase and s.sl_id=v.sl_id
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('H','C')
      where s.sum_m != round(k.koef_z * k.koef_up * case k.koef_d when 0 then 1 end * k.koef_u * k.bztsz * isnull(v.kslp_koef,1) * 
	   isnull(l.koef, case zs.usl_ok when 1 then case s.kd when 1 then 0.2 when 2 then 0.3 when 3 then 0.4 else 1 end
	                                 when 2 then case s.kd when 1 then 0.5 when 2 then 0.5 when 3 then 0.5 else 1 end 
					  end) ,2)
		and zs.DATE_Z_2 < '01.01.2019'



-- Проверка №93.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_PK', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан код профиля койки (NAZ_PK) при направлении на реабилитацию'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
  inner join tempdb..TEMP_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
 where n.naz_r = 6 and n.naz_pk is null

-- Проверка №93 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_PK', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAZ_PK="'+isnull(cast(n.NAZ_PK as varchar),'')+'" не соответствует допустимому значению  в справочнике'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
  inner join tempdb..TEMP_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
  left join [IES].[T_V020_BED_PROFILE] v on n.naz_pk = v.idk_pr
 where v.idk_pr is null and n.naz_pk is not null
   

-- Проверка №92.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_PMP', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан код профиля медицинской помощи (NAZ_PMP) при направлении на госпитализацию'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
  inner join tempdb..TEMP_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
 where n.naz_r in (4,5) and n.naz_pmp is null
   

-- Проверка №92 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_PMP', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAZ_PMP="'+isnull(cast(n.NAZ_PMP as varchar),'')+'>" не соответствует допустимому значению  в справочнике V002'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
  inner join tempdb..TEMP_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
  left join [IES].[T_V002_PROFILE] v on n.naz_pmp = v.idpr
 where n.naz_pmp is not null and v.idpr is null
   

-- Проверка №91.6 по базе в ОРАКЛЕ 
-- insert into #Errors (IM_POL, BAS_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
-- select 'NAPR_DATE', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Дата направления (NAPR_DATE) выходит за пределы случая лечения (DATE_1-DATE_2).'
-- from #TEMP_Z_SLUCH zs
--  join #TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
--  join #SCHET z on substring(z.FILENAME,1,1) in ('D')
--  inner join #TEMP_SL_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
-- where n.NAPR_DATE < s.DATE_1 and n.NAPR_DATE > s.DATE_2

---- Проверка №91.6 по базе в ОРАКЛЕ 
-- insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
-- select 'NAPR_MO', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAPR_MO="'+isnull(cast(n.NAPR_MO as varchar),'')+'" не соответствует допустимому значению  в справочнике F003'
-- from tempdb..TEMP_Z_SLUCH zs
--  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
--  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
--  inner join tempdb..TEMP_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
--  left join [IES].[T_F003_MO] t1 on n.NAPR_MO=t1.MCOD and s.DATE_1 between t1.D_BEGIN and isnull(t1.D_END,s.DATE_1)
-- where t1.MCOD is null and n.napr_mo is not null

-- Проверка №91.5 по базе в ОРАКЛЕ 
 --insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 --select 'NAPR_MO', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан код МО (NAPR_MO) в которое отправили на консультацию при подозрении на ЗНО'
 --from tempdb..TEMP_Z_SLUCH zs
 -- join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
 -- join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
 -- inner join tempdb..TEMP_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
 --where n.NAZ_R in (2,3) and s.ds_onk=1 and n.napr_mo is null

---- Проверка №91.4 по базе в ОРАКЛЕ 
-- insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
-- select 'NAPR_DATE', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указана дата направления (NAPR_DATE) на консультацию в другое МО при подозрении на ЗНО'
-- from tempdb..TEMP_Z_SLUCH zs
--  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
--  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
--  inner join tempdb..TEMP_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
-- where n.NAZ_R in (2,3) and s.ds_onk=1 and n.napr_date is null

---- Проверка №91.3 по базе в ОРАКЛЕ 
-- insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
-- select 'NAZ_USL', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан код медицинской услуги (NAZ_USL) при направлении на обследование при подозрении на ЗНО'
-- from tempdb..TEMP_Z_SLUCH zs
--  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
--  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
--  inner join tempdb..TEMP_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
-- where n.NAZ_R=3 and s.ds_onk=1 and n.naz_usl is null

---- Проверка №91.2 по базе в ОРАКЛЕ 
-- insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
-- select 'NAZ_USL', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAZ_USL="'+isnull(cast(n.NAZ_USL as varchar),'')+'" не соответствует допустимому значению  в справочнике V001'
-- from tempdb..TEMP_Z_SLUCH zs
--  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
--  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
--  inner join tempdb..TEMP_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
--   left join [IES].[T_V001_NOMENCLATURE] t3 on n.NAZ_USL=t3.Code --and s.DATE_1 between t3.DATEBEG and isnull(t3.DATEEND,s.DATE_1)
-- where t3.Code is null and n.NAZ_USL is not null

-- Проверка №91.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_V', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан метод диагностического исследования (NAZ_V) при направлении на обследование'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
  inner join tempdb..TEMP_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
 where n.NAZ_R=3 and n.naz_v is null

-- Проверка №91 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_V', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAZ_V="'+isnull(cast(n.NAZ_V as varchar),'')+'" не соответствует допустимому значению  в справочнике'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
  inner join tempdb..TEMP_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
  left join [IES].[T_V029_MET_ISSL] v on n.naz_v = v.IDMET and zs.DATE_Z_1 between v.DATEBEG and isnull(v.DATEEND,zs.DATE_Z_1)
 where v.IDMET is null and n.naz_v is not null

-- Проверка №90.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_SP', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указана специальность врача (NAZ_SP) при направлении на консультацию'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
  join tempdb..TEMP_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
 where n.naz_r in (1,2) and n.NAZ_SP is null

-- Проверка №90 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_SP', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAZ_SP="'+isnull(cast(n.naz_sp as varchar),'')+'" не соответствует допустимому значению  в справочнике'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
  inner join tempdb..TEMP_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
  left join [IES].[T_V021_MED_SPEC] v on n.naz_sp = v.CODE_SPEC and s.DATE_1 between v.DATEBEG and isnull(v.DATEEND,s.DATE_1)
 where v.CODE_SPEC is null and n.naz_sp is not null
 
-- Проверка №89.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Блок NAZ должен быть заполнен при присвоении группы здоровья кроме I или II.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
 where zs.rslt_d in (3,4,5,14,15,17,18,19,31,32) and not exists(select 1 from tempdb..TEMP_NAZ n where s.idcase=n.idcase and s.sl_id=n.sl_id)

-- Проверка №89.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Блок NAZ должен быть пустым при присвоении группы здоровья I или II.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
 where zs.rslt_d in (1,2,11,12) and exists(select 1 from tempdb..TEMP_NAZ n where s.idcase=n.idcase and s.sl_id=n.sl_id)

-- Проверка №89 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAZ_R', 'NAZ', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAZ_R="'+isnull(cast(n.naz_r as varchar),'')+'" не соответствует допустимому (1,2,3,4,5,6).'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
  inner join tempdb..TEMP_NAZ n on s.idcase=n.idcase and s.sl_id=n.sl_id
 where n.naz_r not in (1,2,3,4,5,6) or n.naz_r is null

-- Проверка №88.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS2', 'DS2_N', zs.N_ZAP, zs.IDCASE, null, '904', 'Код DS2 в блоке DS2_N указан без подрубрики.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
  inner join tempdb..TEMP_DS2_N n on s.idcase=n.idcase and s.sl_id=n.sl_id
  LEFT JOIN  ies.R_MKB_10 mkb on mkb.MKB10CODE = n.DS2 and mkb.priznak = 1
 where len(n.DS2) = 3
       AND n.DS2 NOT IN
       ('A33', 'A34', 'A38', 'A46', 'A55', 'A57', 'A58', 'A64', 'A65', 'A70', 'A78', 'A89', 'A90', 'A91', 'A94', 'A99', 'B03', 'B04', 'B07', 'B09',
            'B54', 'B59', 'B64', 'B72', 'B73', 'B75', 'B79', 'B80', 'B86', 'B89', 'B91', 'B92', 'B99', 'C01', 'C07', 'C12', 'C20', 'C23', 'C33', 'C37',
            'C52', 'C55', 'C56', 'C58', 'C61', 'C64', 'C65', 'C66', 'C73', 'C97', 'D27', 'D34', 'D45', 'D65', 'D66', 'D67', 'D70', 'D71', 'D77', 'E02',
            'E15', 'E40', 'E41', 'E42', 'E43', 'E45', 'E46', 'E52', 'E54', 'E58', 'E59', 'E60', 'E65', 'E68', 'E86', 'E90', 'G07', 'G08', 'G09', 'G10',
            'G20', 'G26', 'G35', 'H55', 'H71', 'H82', 'I00', 'I10', 'I38', 'I81', 'I99', 'J00', 'J13', 'J14', 'J22', 'J36', 'J40', 'J46', 'J47', 'J60',
            'J61', 'J64', 'J65', 'J80', 'J81', 'J82', 'J90', 'J91', 'K20', 'K36', 'K37', 'L00', 'L14', 'L26', 'L42', 'L52', 'L80', 'L82', 'L83', 'L84',
            'L86', 'L88', 'L97', 'M45', 'N12', 'N19', 'N23', 'N26', 'N40', 'N44', 'N46', 'N47', 'N61', 'N62', 'N63', 'N72', 'N86', 'N96', 'O11', 'O13',
            'O16', 'O25', 'O40', 'O48', 'O85', 'O95', 'O96', 'O97', 'P38', 'P53', 'P60', 'P75', 'P77', 'P90', 'P93', 'P95', 'Q02', 'R05', 'R11', 'R12',
            'R13', 'R14', 'R15', 'R17', 'R18', 'R21', 'R31', 'R32', 'R33', 'R34', 'R35', 'R36', 'R42', 'R53', 'R55', 'R72', 'R51', 'R69', 'S16', 'S18',
            'T07', 'T16', 'T55', 'T58', 'T64', 'T66', 'T68', 'T97', 'Z21', 'B24', 'B49', 'C19', 'D24', 'D62', 'G01', 'G22', 'G92', 'G98', 'J42', 'K20',
            'K30', 'L22', 'L45', 'N10', 'R02', 'S47', 'Z33', 'T71', 'A35', 'A86', 'F03', 'F04', 'F09', 'F21', 'F24', 'F28', 'F29', 'F39', 'F54', 'F55',
            'F59', 'F61', 'F69', 'F82', 'F83', 'F88', 'F89', 'F99', 'G14', 'G64', 'H46', 'J09', 'O94', 'R54', 'R58', 'R64', 'R71', 'R75', 'R80', 'R81',
            'R91', 'R92', 'R95', 'R98', 'R99', 'T96', 'I64')

-- Проверка №88.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS2', 'DS2_N', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение DS2="'+isnull(cast(n.DS2 as varchar),'')+'" не соответствует допустимому.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
  inner join tempdb..TEMP_DS2_N n on s.idcase=n.idcase and s.sl_id=n.sl_id
  LEFT JOIN  ies.R_MKB_10 mkb on mkb.MKB10CODE = n.DS2 and mkb.priznak = 1
 where mkb.MKB10CODE is null and n.DS2 is not null

-- Проверка №88 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS2', 'DS2_N', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение PR_DS2_N="'+isnull(cast(n.pr_ds2_n as varchar),'')+'" не соответствует допустимому.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
  inner join tempdb..TEMP_DS2_N n on s.idcase=n.idcase and s.sl_id=n.sl_id
 where n.pr_ds2_n not in (1,2,3) or n.pr_ds2_n is null
 
-- Проверка №87 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PR_D_N', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение PR_D_N="'+isnull(cast(s.pr_d_n as varchar),'')+'" не соответствует допустимому.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
 where s.pr_d_n not in (1,2,3)

-- Проверка №86 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'P_OTK', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение P_OTK="'+isnull(cast(zs.P_OTK as varchar),'')+'" не соответствует допустимому.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
 where zs.p_otk not in (0,1) or zs.p_otk is null

-- Проверка №85 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'VBR', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение VBR="'+isnull(cast(zs.VBR as varchar),'')+'" не соответствует допустимому.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('D')
 where zs.vbr not in (0,1) or zs.vbr is null

-- Проверка №84 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'TAL_P', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Дата выдачи талона на ВМП (TAL_P) больше даты госпитализации при плановой помощи'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('T')
 where s.tal_p > s.date_1 and zs.FOR_POM = 3

-- Проверка №83 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'TAL_D', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Дата выдачи талона на ВМП (TAL_D) больше даты госпитализации при плановой помощи'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV z on substring(z.FILENAME,1,1) in ('T')
 where s.tal_d > s.date_1 and zs.FOR_POM = 3

---- Проверка №82.6 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_INJ', 'LEK_PR', zs.N_ZAP, zs.IDCASE, null, '904', 'Дата введения лекарственного препарата (DATE_INJ) выходит за пределы случая лечения (DATE_1-DATE_2).'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL t1 on t1.IDCASE=zs.IDCASE
  join tempdb..TEMP_ONK_USL uo on uo.idcase=t1.idcase and uo.SL_ID=t1.SL_ID
  --join tempdb..TEMP_LEK_PR t2 on uo.idcase=t2.idcase and uo.SL_ID=t2.SL_ID
  join tempdb..TEMP_LEK_PR_DATE_INJ t4 on t4.idcase=uo.idcase and t4.SL_ID=uo.SL_ID
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where t4.DATE_INJ < zs.DATE_Z_1 or t4.DATE_INJ > zs.DATE_Z_2

 -- Проверка №82.5 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_SH', 'LEK_PR', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указана дата введения лекарственного препарата (DATE_INJ)'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL t1 on t1.IDCASE=zs.IDCASE
  join tempdb..TEMP_ONK_USL uo on uo.idcase=t1.idcase and uo.SL_ID=t1.SL_ID
  --join tempdb..TEMP_LEK_PR t2 on uo.idcase=t2.idcase and uo.SL_ID=t2.SL_ID
  left join tempdb..TEMP_LEK_PR_DATE_INJ t4 on t4.idcase=uo.idcase and t4.SL_ID=uo.SL_ID
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where t4.DATE_INJ is null and t4.REGNUM is not null

 -- Проверка №82.4 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'CODE_SH', 'LEK_PR', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение CODE_SH="'+isnull(cast(t2.CODE_SH as varchar),'')+'" не соответствует допустимому значению  в справочнике V024'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL t1 on t1.IDCASE=zs.IDCASE
  join tempdb..TEMP_ONK_USL uo on uo.idcase=t1.idcase and uo.SL_ID=t1.SL_ID
  join tempdb..TEMP_LEK_PR_DATE_INJ t2 on uo.idcase=t2.idcase and uo.SL_ID=t2.SL_ID --and uo.IDSERV=t2.IDSERV
  left join [IES].[T_V024_DOP_KR] t3 on t2.CODE_SH=t3.IDDKK and zs.DATE_Z_2 between t3.DATEBEG and isnull(t3.DATEEND,zs.DATE_Z_2)
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where t3.IDDKK is null

 -- Проверка №82.3 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'REGNUM', 'LEK_PR', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение REGNUM="'+isnull(cast(t2.REGNUM as varchar),'')+'" не соответствует допустимому значению  в справочнике N020'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL t1 on t1.IDCASE=zs.IDCASE
  join tempdb..TEMP_ONK_USL uo on uo.idcase=t1.idcase and uo.SL_ID=t1.SL_ID
  join tempdb..TEMP_LEK_PR_DATE_INJ t2 on uo.idcase=t2.idcase and uo.SL_ID=t2.SL_ID --and uo.IDSERV=t2.IDSERV
  left join [IES].[T_N020_ONK_LEKP] t3 on t2.REGNUM=t3.ID_LEKP and zs.DATE_Z_2 between t3.DATEBEG and isnull(t3.DATEEND,zs.DATE_Z_2)
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where t3.ID_LEKP is null

 -- Проверка №82.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'LEK_PR', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указаны сведения о введенном противоопухолевом лекарственном препарате (LEK_PR)'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL t1 on t1.IDCASE=zs.IDCASE
  join tempdb..TEMP_ONK_USL uo on uo.idcase=t1.idcase and uo.SL_ID=t1.SL_ID
  left join tempdb..TEMP_LEK_PR_DATE_INJ t2 on uo.idcase=t2.idcase and uo.SL_ID=t2.SL_ID --and uo.IDSERV=t2.IDSERV
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where t2.REGNUM is null and uo.usl_tip in (2,4)
 
 -- Проверка №82.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'LUCH_TIP', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'При USL_TIP="'+isnull(cast(uo.USL_TIP as varchar),'')+'" поле LUCH_TIP должно быть пустым.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_USL uo on uo.idcase=zs.idcase
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
  where (uo.LUCH_TIP is not null and uo.usl_tip not in (3,4))
 
 -- Проверка №82 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'LUCH_TIP', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение LUCH_TIP="'+isnull(cast(uo.LUCH_TIP as varchar),'')+'" не соответствует допустимому значению  в справочнике'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_USL uo on uo.idcase=zs.idcase
  left join [IES].[T_N017_RADIATION_THERAPY_TYPES] n on uo.luch_tip=n.id_tluch
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
      where n.id_tluch is null and uo.usl_tip in (3,4)

---- Проверка №81.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PPTR', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение PPTR="'+isnull(cast(uo.PPTR as varchar),'')+'" не соответствует допустимому.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_USL uo on uo.idcase=zs.idcase
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
     where uo.PPTR is not null and uo.PPTR != 1

-- Проверка №81.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'LEK_TIP_V', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'При USL_TIP не равном 2 поле LEK_TIP_V должно быть пустым.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_USL uo on uo.idcase=zs.idcase
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
     where uo.LEK_TIP_V is not null and uo.USL_TIP != 2

-- Проверка №81 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'LEK_TIP_V', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение LEK_TIP_V="'+isnull(cast(uo.lek_tip_v as varchar),'')+'" не соответствует допустимому значению  в справочнике N016'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_USL uo on uo.idcase=zs.idcase
  left join [IES].[T_N016_DRUG_THERAPY_CYCLES] n on uo.lek_tip_v=n.id_tlek_v
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
      where n.id_tlek_v is null and uo.USL_TIP = 2

-- Проверка №80.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'LEK_TIP_L', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'При USL_TIP не равном 2 поле LEK_TIP_L должно быть пустым.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_USL uo on uo.idcase=zs.idcase
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
     where uo.LEK_TIP_L is not null and uo.USL_TIP != 2

-- Проверка №80 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'LEK_TIP_L', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение LEK_TIP_L="'+isnull(cast(uo.lek_tip_l as varchar),'')+'" не соответствует допустимому значению  в справочнике N015'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_USL uo on uo.idcase=zs.idcase
  left join [IES].[T_N015_DRUG_THERAPY_LINES] n on uo.lek_tip_l=n.id_tlek_l and zs.DATE_Z_1 between n.DATEBEG and isnull(n.DATEEND,zs.DATE_Z_1)
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
     where n.id_tlek_l is null and uo.USL_TIP = 2

-- Проверка №79.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'HIR_TIP', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'При значение USL_TIP не равном 1, поле HIR_TIP должно быть пустым'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_USL uo on uo.idcase=zs.idcase
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
     where uo.HIR_TIP is not null and uo.usl_tip != 1

-- Проверка №79 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'HIR_TIP', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение USL_TIP="'+isnull(cast(uo.USL_TIP as varchar),'')+'" не соответствует допустимому значению  в справочнике N014'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_USL uo on uo.idcase=zs.idcase
  left join [IES].[T_N014_SURG_TREAT] n on uo.hir_tip=n.id_thir and zs.DATE_Z_1 between n.DATEBEG and isnull(n.DATEEND,zs.DATE_Z_1)
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
     where (n.id_thir is null and uo.usl_tip = 1)
--         or (n.id_thir is not null and uo.usl_tip != 1)

-- Проверка №78.6 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS1_T', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение DS1_T="'+isnull(cast(uo.DS1_T as varchar),'')+'" не соответствует примененному коду услуги CODE_USL="'+isnull(cast(u.CODE_USL as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH sl on sl.idcase=zs.idcase
  join tempdb..TEMP_USL u on u.idcase=sl.idcase and u.SL_ID=sl.SL_ID
  join iesdb.ies.R_NSI_USL_V001 v001 on u.CODE_USL=v001.CODE_USL and v001.usltype = '2c0c3297-8235-4e38-9bd1-d5357a9265df'
  left join tempdb..TEMP_ONK_SL uo on uo.idcase=zs.idcase and uo.SL_ID=sl.SL_ID
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('C','T')
 where (zs.usl_ok=3 and ds_onk=0 and isnull(uo.DS1_T,6) != 6)

-- Проверка №78.5 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS1_T', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение DS1_T="'+isnull(cast(uo.DS1_T as varchar),'')+'" не соответствует примененному условию оказания МП USL_OK="'+isnull(cast(zs.USL_OK as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH sl on sl.idcase=zs.idcase
  left join tempdb..TEMP_ONK_SL uo on uo.idcase=zs.idcase and uo.SL_ID=sl.SL_ID
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('C')
 where ((zs.usl_ok in (1,2) and ds_onk=0 and isnull(uo.DS1_T,3) in (3,4))
    or (zs.usl_ok=3 and ds_onk=0 and isnull(uo.DS1_T,3) in (0,1,2))
	or (zs.usl_ok=3 and ds_onk=0 and isnull(uo.DS1_T,5) = 5 and sl.PROFIL not in(78,34,38,111,106, 15)))
	AND  (zs.OPLATA <> 2 OR zs.oplata IS null)

-- Проверка №78.4 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS1_T', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение DS1_T="'+isnull(cast(uo.DS1_T as varchar),'')+'" не соответствует примененному коду КСГ N_KSG="'+isnull(cast(q.N_KSG as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH sl on sl.idcase=zs.idcase
  left join tempdb..TEMP_ONK_SL uo on uo.idcase=zs.idcase and uo.SL_ID=sl.SL_ID
  join tempdb..TEMP_KSG_KPG q on zs.idcase=q.idcase and sl.SL_ID=q.SL_ID
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('C')
 where (q.N_KSG in ('st05.007','st05.011','st08.001','st19.027','st19.028','st19.029','st19.030','st19.031','st19.032','st19.033','st19.034','st19.035','st19.036',
  'st19.038','st02.008','st20.001','st23.003','st27.002','st30.003','st31.011','st31.017','st35.006','st19.039','st19.040','st19.041','st19.042','st19.043','st19.044',
  'st19.045','st19.046','st19.047','st19.048','st19.001','st19.002','st19.003','st19.004','st19.005','st19.006','st19.007','st19.008','st19.009','st19.010','st19.011',
  'st19.013','st19.014','st19.015','st19.012','st19.016','st19.017','st19.018','st19.019','st19.020','st19.021','st19.022','st19.023','st19.024','st19.025','st19.026',
  'st19.049','st19.050','st19.051','st19.052','st19.053','st19.054','st19.055') and isnull(uo.DS1_T,10) not in (0,1,2))
  or (q.N_KSG ='st36.012' and isnull(uo.DS1_T,10) not in (0,1,2,6))

-- Проверка №78.3 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL_TIP', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение USL_TIP="'+isnull(cast(uo.USL_TIP as varchar),'')+'" не соответствует примененному виду ВМП VID_HMP="'+isnull(cast(sl.vid_hmp as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH sl on sl.idcase=zs.idcase
  join tempdb..TEMP_ONK_USL uo on uo.idcase=zs.idcase and uo.SL_ID=sl.SL_ID
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T')
where (sl.VID_HMP ='09.00.22.005' and uo.USL_TIP != 2)
   or (sl.VID_HMP ='09.00.21.004' and uo.USL_TIP != 3)

-- Проверка №78.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL_TIP', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение USL_TIP="'+isnull(cast(uo.USL_TIP as varchar),'')+'" не соответствует примененному виду ВМП VID_VMP="'+isnull(cast(sl.vid_hmp as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH sl on sl.idcase=zs.idcase
  join tempdb..TEMP_ONK_USL uo on uo.idcase=zs.idcase and uo.SL_ID=sl.SL_ID
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T')
 where (substring(sl.vid_hmp,dbo.instr(sl.vid_hmp,'.',1,2)+1,case dbo.instr(sl.vid_hmp,'.',1,3)-dbo.instr(sl.vid_hmp,'.',1,2)-1 when -1 then 0 else dbo.instr(sl.vid_hmp,'.',1,3)-dbo.instr(sl.vid_hmp,'.',1,2)-1 end) = '22'
    and uo.USL_TIP != 2)
  or  (substring(sl.vid_hmp,dbo.instr(sl.vid_hmp,'.',1,2)+1,case dbo.instr(sl.vid_hmp,'.',1,3)-dbo.instr(sl.vid_hmp,'.',1,2)-1 when -1 then 0 else dbo.instr(sl.vid_hmp,'.',1,3)-dbo.instr(sl.vid_hmp,'.',1,2)-1 end) = '21'
    and uo.USL_TIP != 3)

-- Проверка №78.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL_TIP', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение USL_TIP="'+isnull(cast(uo.USL_TIP as varchar),'')+'" не соответствует примененному коду КСГ N_KSG="'+isnull(cast(q.N_KSG as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH sl on sl.idcase=zs.idcase
  join tempdb..TEMP_ONK_USL uo on uo.idcase=zs.idcase and uo.SL_ID=sl.SL_ID
  join tempdb..TEMP_KSG_KPG q on zs.idcase=q.idcase and sl.SL_ID=q.SL_ID
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('C')
 where (q.N_KSG in ('ds19.018','ds19.019','ds19.020','ds19.021','ds19.022','ds19.023','ds19.024','ds19.025','ds19.026','ds19.027',
                   'st19.027','st19.028','st19.029','st19.030','st19.031','st19.032','st19.033','st19.034','st19.035','st19.036') and uo.USL_TIP != 2 and datepart(year,zs.date_z_2)=2019)
	or (q.N_KSG in ('ds19.018','ds19.019','ds19.020','ds19.021','ds19.022','ds19.023','ds19.024','ds19.025','ds19.026','ds19.027','ds19.030','ds19.031','ds19.032',
                   'st19.027','st19.028','st19.029','st19.030','st19.031','st19.032','st19.033','st19.034','st19.035','st19.036','st19.056','st19.057','st19.058') and uo.USL_TIP != 2 and datepart(year,zs.date_z_2)=2020)
    or (q.N_KSG in ('ds19.001','ds19.002','ds19.003','ds19.004','ds19.006','ds19.007','ds19.008','ds19.009','ds19.010','st19.039','st19.040','st19.041',
					'st19.042','st19.043','st19.044','st19.045','st19.046','st19.047','st19.048') and uo.USL_TIP != 3)
    or (q.N_KSG in ('ds19.011','ds19.012','ds19.013','ds19.014','ds19.015','st19.049','st19.050','st19.051','st19.052','st19.053','st19.054','st19.055') and uo.USL_TIP != 4)
    or (q.N_KSG in ('st19.038','ds19.028') and uo.USL_TIP != 5)

-- Проверка №78 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL_TIP', 'ONK_USL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение USL_TIP="'+isnull(cast(uo.USL_TIP as varchar),'')+'" не соответствует допустимому значению  в справочнике N013'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_USL uo on uo.idcase=zs.idcase
  left join [IES].[T_N013_TREAT_TYPE] t1 on uo.usl_tip=t1.id_tlech and zs.DATE_Z_1 between t1.DATEBEG and isnull(t1.DATEEND,zs.DATE_Z_1)
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
     where t1.id_tlech is null

-- Проверка №77.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PR_CONS', 'CONS', zs.N_ZAP, zs.IDCASE, null, '904', 'Дата проведения консилиума (DT_CONS) выходит за пределы случая лечения (DATE_1-DATE_2).'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL o on o.idcase=zs.idcase
  join tempdb..TEMP_CONS u on u.idcase=o.idcase and u.sl_id=o.sl_id
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
where u.DT_CONS < zs.DATE_Z_1 and u.DT_CONS > zs.DATE_Z_2 

-- Проверка №77.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PR_CONS', 'CONS', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указана дата проведения консилиума (DT_CONS)'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL o on o.idcase=zs.idcase
  join tempdb..TEMP_CONS u on u.idcase=o.idcase and u.sl_id=o.sl_id
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
where u.DT_CONS is null and u.PR_CONS in (1,2,3)

-- Проверка №77 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PR_CONS', 'CONS', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение PR_CONS="'+isnull(cast(u.PR_CONS as varchar),'')+'" не соответствует допустимому значению  в справочнике N019'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL o on o.idcase=zs.idcase
  join tempdb..TEMP_CONS u on u.idcase=o.idcase and u.sl_id=o.sl_id
  left join [IES].[T_N019_ONK_CONS] t1 on u.PR_CONS=t1.ID_CONS and zs.DATE_Z_1 between t1.DATEBEG and isnull(t1.DATEEND,zs.DATE_Z_1)
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
where t1.ID_CONS is null

-- Проверка №76.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'MET_ISSL', 'NAPR', zs.N_ZAP, zs.IDCASE, null, '904', 'При значении NAPR_V не равном "3", поле MET_ISSL должно быть пустым'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_NAPR n on n.idcase=zs.idcase
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
where n.MET_ISSL is not null and n.napr_v != 3

-- Проверка №76 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'MET_ISSL', 'NAPR', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение MET_ISSL="'+isnull(cast(n.MET_ISSL as varchar),'')+'" не соответствует допустимому значению  в справочнике V029'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_NAPR n on n.idcase=zs.idcase
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
  left join [IES].[T_V029_MET_ISSL] t1 on n.MET_ISSL=t1.IDMET and zs.DATE_Z_1 between t1.DATEBEG and isnull(t1.DATEEND,zs.DATE_Z_1)
where (t1.IDMET is null and n.napr_v = 3)

-- Проверка №75.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAPR_DATE', 'NAPR', zs.N_ZAP, zs.IDCASE, null, '904', 'Дата направления (NAPR_DATE) выходит за пределы случая лечения (DATE_1-DATE_2).'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_NAPR n on n.idcase=s.idcase and n.sl_id=s.sl_id
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('T','C')
 where n.NAPR_DATE < s.DATE_1 or n.NAPR_DATE > s.DATE_2


 -- проверить 02-02-2020 конфликтует с 015
-- Проверка №75.1 по базе в ОРАКЛЕ 
 --insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 --select 'NAPR_MO', 'NAPR', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAPR_MO="'+isnull(cast(n.NAPR_MO as varchar),'')+'" не соответствует допустимому значению  в справочнике F003'
 --from tempdb..TEMP_Z_SLUCH zs
 -- join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
 -- join tempdb..TEMP_NAPR n on n.idcase=s.idcase and n.sl_id=s.sl_id
 -- left join [IES].[T_F003_MO] t1 on n.NAPR_MO=t1.MCOD and n.NAPR_DATE between t1.D_BEGIN and isnull(t1.D_END,n.NAPR_DATE)
 -- join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('T','C')
 --where t1.MCOD is null

-- Проверка №75 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAPR_V', 'NAPR', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение NAPR_V="'+isnull(cast(n.NAPR_V as varchar),'')+'" не соответствует допустимому значению  в справочнике V028'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_NAPR n on n.idcase=s.idcase and n.sl_id=s.sl_id
  left join [IES].[T_V028_NAPR_V] t1 on n.NAPR_V=t1.IDVN and s.DATE_1 between t1.DATEBEG and isnull(t1.DATEEND,s.DATE_1)
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('T','C')
 where t1.IDVN is null

-- Проверка №74 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NAPR_V', 'NAPR', zs.N_ZAP, zs.IDCASE, null, '904', 'Отсутствует направление на лечение'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  left join tempdb..TEMP_NAPR n on n.idcase=t.idcase and n.sl_id=t.sl_id
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('T','C')
 where n.napr_v is null 
   and (t.ds_onk = 1 
--         or (substring(t.ds1,1,1) = 'C' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS2 from tempdb..TEMP_DS2 ds where (ds.DS2 between 'C00' and 'C80.9' or  ds.ds2 between 'C97' and 'C97.9')))) 
	   )
	   and t.PROFIL not in (78,34,38,111,106,76,123) -- исключаем профили по диагностическим мероприятиям

-- Проверка №73 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'ONK_USL', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Отсутствует онкоуслуга для онкослучя'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL o on o.idcase=zs.idcase
  left join tempdb..TEMP_ONK_USL u on u.idcase=o.idcase and u.sl_id=o.sl_id
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
where u.usl_tip is null      
        and zs.usl_ok in (1,2)
        and o.DS1_T in (0,1,2)

-- Проверка №72 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'KSG_KPG', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не заполнен блок КСГ'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  left join tempdb..TEMP_KSG_KPG k on s.idcase=k.idcase and s.sl_id=k.sl_id
  join tempdb..TEMP_ZGLV t on SUBSTRING(t.FILENAME,1,1) in ('H','C')
  where k.n_ksg is null and zs.usl_ok in (1,2)        


-- Проверка №71.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DIAG_DATE', 'B_DIAG', zs.N_ZAP, zs.IDCASE, null, '904', 'Дата взятия материала (DIAG_DATE) выходит за пределы случая лечения (DATE_1-DATE_2).'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_B_DIAG d on d.idcase=s.idcase and d.sl_id=s.sl_id
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('T','C')
 where d.DIAG_DATE < s.DATE_1 or d.DIAG_DATE > s.DATE_2

-- Проверка №71 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DIAG_TIP', 'B_DIAG', zs.N_ZAP, zs.IDCASE, null, '904', 'Некорректное заполнение поля DIAG_TIP="'+isnull(cast(d.DIAG_TIP as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_B_DIAG d on d.idcase=s.idcase and d.sl_id=s.sl_id
  join tempdb..TEMP_ZGLV z on SUBSTRING(z.FILENAME,1,1) in ('T','C')
 where d.diag_tip not in (1,2) and d.diag_date is null        

-- Проверка №70 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'SOD', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Некорректное заполнение поля SOD'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL o on o.idcase=zs.idcase
  left join tempdb..TEMP_ONK_USL u on u.idcase=o.idcase and u.sl_id=o.sl_id
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where (o.sod is not null and u.usl_tip is null)
    or (o.sod is null and u.usl_tip in (3,4))

-- Проверка №69 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'MTSTZ', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Некорректное заполнение поля MTSTZ'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL o on o.idcase=zs.idcase
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where isnull(o.mtstz,1) != 1 and o.ds1_t in (1,2)
   or isnull(o.mtstz,0) = 1 and o.ds1_t not in (1,2)
 
-- Проверка №68 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DS1_T', 'ONK_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение DS1_T="'+isnull(cast(o.DS1_T as varchar),'')+'" не соответствует допустимому значению  в справочнике N018'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ONK_SL o on o.idcase=zs.idcase
  left join [IES].[T_N018_ONK_REAS] t1 on o.DS1_T=t1.ID_REAS
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where t1.ID_REAS is null        
        
-- Проверка №66.3 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDSP', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Для CODE_USL="'+isnull(cast(t1.CODE_USL as varchar),'')+'" значение поля IDSP не должно равняться "'
 +isnull(cast(zs.IDSP as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL t1 on (t1.IDCASE=t.IDCASE and t1.SL_ID=t.SL_ID) 
      where (
	      (zs.idsp != 28 and t1.CODE_USL like 'A%' and zs.USL_OK=3 and @type=554)
	       or (zs.idsp  not in (25,28) and t1.CODE_USL like 'A%' and zs.USL_OK=3 and @type in (693,562))
			 )
        and t1.CODE_USL not in ('A18.05.012.082','A18.05.012.081','A11.12.003.080','A18.05.012.080','A11.12.003.001')


-- Проверка №66.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDSP', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При значении поля IDSP = 29, DATE_Z_1 должно равняться DATE_Z_2'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
      where (zs.idsp = 29 and zs.date_z_1 != zs.date_z_2)

-- Проверка №66.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDSP', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При значении поля IDSP = 30, DATE_Z_1 не может равняться DATE_Z_2'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
      where (zs.idsp = 30 and zs.date_z_1 = zs.date_z_2)
        

-- Проверка №66 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDSP', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При значении поля IDSP="'+isnull(cast(zs.IDSP as varchar),'')+'"  значение поля USL_OK не может равняться "'
  +isnull(cast(zs.USL_OK as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C','H','D')
      where (zs.usl_ok in (1,2) and zs.idsp != 33 and SUBSTRING(s.FILENAME,1,1) in ('C','H'))
		 or (zs.usl_ok in (1) and zs.idsp != 32 and SUBSTRING(s.FILENAME,1,1) in ('T'))
         or (zs.usl_ok =4 and zs.idsp != 24) and @type=554
         or (zs.usl_ok =4 and zs.idsp not in (24,36)) and @type in (693,562)
         or (zs.usl_ok =3 and zs.idsp not in (28,29,30) and @type=554)
		 or (zs.usl_ok =3 and zs.idsp not in (25,28,29,30) and @type in (693,562) and SUBSTRING(s.FILENAME,1,1) in ('C','H','D'))

-- Проверка №65 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'VERS_SPEC', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение поля VERS_SPEC должно быть равно значению "V021"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','T','C')
 where t.vers_spec != 'V021' or t.vers_spec is null

 -- Проверка №64.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'REAB', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При значении поля FOR_POM 1,2 поле REAB не подлежит заполнению'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','T','C')
 where (t.reab = 1 and zs.for_pom != 3)

-- Проверка №64 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'REAB', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При значении поля REAB =  "'+isnull(cast(t.REAB as varchar),'')+'" значение поля PROFIL не может равняться "'
 +isnull(cast(t.PROFIL as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','T','C')
 where (t.reab != 1 and t.profil = 158)
         or (t.reab = 1 and t.profil != 158)
         or (isnull(t.reab,1) != 1)	  

-- Проверка №63 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DN', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При значении поля DN = "'+isnull(cast(t.DN as varchar),'')+'" значение поля P_CEL не может равняться "'
 +isnull(cast(t.P_CEL as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','C')
 where (t.dn is null and t.p_cel = '1.3')

-- Проверка №62 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'KD', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При значении поля KD = "'+isnull(cast(t.KD as varchar),'')+'" значение поля USL_OK не может равняться "'
 +isnull(cast(zs.USL_OK as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','C')
      where (t.kd is null and zs.usl_ok in (1,2))
           or (t.kd is not null and zs.usl_ok in (3,4))

-- Проверка №61 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'P_CEL', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При значении поля P_CEL = "'+isnull(cast(t.P_CEL as varchar),'')+'" значение поля USL_OK не может равняться "'
 +isnull(cast(zs.USL_OK as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
      where (t.p_cel is null and zs.usl_ok = 3)
           or (t.p_cel is not null and zs.usl_ok != 3)

-- Проверка №60 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DET', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'При значении поля DET = "'+isnull(cast(t.DET as varchar),'')+'" значение поля PROFIL не может равняться "'
 +isnull(cast(t.PROFIL as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','T','C')
     where (t.det = 0 and t.profil in (17,18,19,20,21,68,86,55))
           or (t.det = 1 and t.profil not in (17,18,19,20,21,68,86,55))
 

-- Проверка №59 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'C_ZAB', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не указан характер осносного заболевания (C_ZAB)'
 from tempdb..TEMP_SLUCH t
  join tempdb..TEMP_Z_SLUCH zs on zs.IDCASE=t.IDCASE 
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','T','C')
 where t.c_zab is null 
   and (
        (SUBSTRING(s.FILENAME,1,1) in ('T','C') and USL_OK in (1,2,3) and (substring(t.ds1,1,1) = 'C' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS2 from tempdb..TEMP_DS2 ds where (ds.DS2 between 'C00' and 'C80.9' or  ds.ds2 between 'C97' and 'C97.9')))) )
        or 
		(SUBSTRING(s.FILENAME,1,1)='H' and zs.USL_OK = 3 and substring(t.ds1,1,1) != 'Z') 
	)

-- Проверка №58 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'C_ZAB', 'SL', N_ZAP, IDCASE, null, '904', 'Значение C_ZAB="'+isnull(cast(C_ZAB as varchar),'')+'" не соответствует допустимому значению  в справочнике'
 from tempdb..TEMP_SLUCH t1
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','T','C')
  left join [IES].[T_V027_C_ZAB] t2 on c_zab=t2.IDCZ and DATE_1 between t2.DATEBEG and isnull(t2.DATEEND,DATE_1) 
 where t2.IDCZ is null and t1.c_zab is not null


-- Проверка №57 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_Z_1', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Дата DATE_Z_1 не может быть больше дата DATE_Z_2'
 from tempdb..TEMP_Z_SLUCH zs
 where zs.date_z_1 > zs.date_z_2

-- Проверка №56 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_IN', 'USL', zs.N_ZAP, zs.IDCASE, u.IDSERV, '904', 'Даты услуги выходят за пределы случая.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_USL u on (u.IDCASE=s.IDCASE and u.SL_ID=s.SL_ID) 
  where u.DATE_IN < s.DATE_1 or u.DATE_OUT > s.DATE_2 or u.DATE_IN > u.DATE_OUT


-- Проверка №55 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_1', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Даты случая выходят за пределы законченного случая.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH s on (s.IDCASE=zs.IDCASE) 
  where s.DATE_1 <zs.DATE_Z_1 or s.DATE_2 >zs.DATE_Z_2 or s.DATE_1 > s.DATE_2

-- Проверка №54.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'KD', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Поле KD обязательно для заполенния для USL_OK = 1 и 2.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on zs.idcase=t.idcase
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','C')
  where zs.usl_ok in (1,2)
    and isnull(t.kd,0)=0 

-- Проверка №54 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'KD_Z', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Поле KD_Z обязательно для заполенния для USL_OK = 1 и 2.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','T','C')
  where zs.usl_ok in (1,2)
    and isnull(zs.kd_z,0)=0 

-- Проверка №53 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'ONK_SL', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Заполнен блок онкослучая при не соблюдении условий.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join tempdb..TEMP_ONK_SL o on o.idcase=t.idcase
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where not(
        (substring(t.ds1,1,1) = 'C' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS2 from tempdb..TEMP_DS2 ds where (ds.DS2 between 'C00' and 'C80.9' or  ds.ds2 between 'C97' and 'C97.9')))) 
        or 
		(SUBSTRING(s.FILENAME,1,1)='C' and zs.USL_OK != 4 and t.REAB != 1 and t.ds_onk != 1) 
		)
		 

-- Проверка №52 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'ONK_SL', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Не заполнен блок онкослучая.'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  left join tempdb..TEMP_ONK_SL o on o.idcase=t.idcase
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
 where o.IDCASE is null 
   and (
        (substring(t.ds1,1,1) = 'C' or (substring(t.ds1,1,3) = 'D70' and exists (select top 1 ds.DS2 from tempdb..TEMP_DS2 ds where (ds.DS2 between 'C00' and 'C80.9' or  ds.ds2 between 'C97' and 'C97.9'))))
        and zs.USL_OK != 4 and isnull(t.REAB,0) != 1 and t.ds_onk != 1 
		)


-- Проверка №51.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'LPU_1', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение LPU_1="'+isnull(t.LPU_1,'')+'" не соответствует допустимому значению коду LPU="'+isnull(zs.LPU,'')+'"'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  join [IES].[T_CHER_MO_PODR]  p on t.lpu_1=p.id
  where zs.lpu != p.lpu

-- Проверка №51 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'LPU_1', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение "'+isnull(t.LPU_1,'')+'" не соответствует допустимому значению кода МО'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
  left join tempdb..TEMP_ONK_SL o on o.idcase=t.idcase
  left join [IES].[T_CHER_MO_PODR]  p on t.lpu_1=p.id and zs.lpu=p.lpu
  where p.id is null
       and zs.lpu in (select lpu from [IES].[T_CHER_MO_PODR])		  

-- Проверка №50 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'USL_OK', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение USL_OK="'+isnull(cast(zs.USL_OK as varchar),'')+'" не может передаваться в данном типе файла "'+
 SUBSTRING(s.FILENAME,1,1)+'".'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','T','C','D')
   where  (zs.usl_ok not in (1,2,3,4) and SUBSTRING(s.FILENAME,1,1) in ('H'))
		  or (zs.usl_ok not in (1,2,3) and SUBSTRING(s.FILENAME,1,1) in ('C'))	
          or (zs.usl_ok != 1 and SUBSTRING(s.FILENAME,1,1) in ('T') and zs.LPU != 400109)
          or (zs.usl_ok != 3 and SUBSTRING(s.FILENAME,1,1) in ('D'))
		  or (zs.usl_ok not in (1,2) and SUBSTRING(s.FILENAME,1,1) in ('T') and zs.LPU = 400109)


-- Проверка №49 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'ISHOD', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение ISHOD="'+isnull(cast(zs.ishod as varchar),'')+'" не соответствует допустимому значению USL_OK="'
 +isnull(cast(zs.USL_OK as varchar),'')+'"'
 from tempdb..TEMP_Z_SLUCH zs 
 where substring(cast(zs.ishod as varchar),1,1) != cast(zs.usl_ok as varchar)
		
-- Проверка №48 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'RSLT_D', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Значение RSLT_D="'+isnull(cast(zs.ishod as varchar),'')+'" не соответствует допустимому значению в справочнике V017'
 from tempdb..TEMP_Z_SLUCH zs 
  left join [IES].[T_V017_DISP_RESULT] f on zs.RSLT_D=f.iddr  and zs.DATE_Z_1 between f.DATEBEG and isnull(f.DATEEND,zs.DATE_Z_1) 
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('D')
 where f.iddr is null
 
-- Проверка №47 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'RSLT', 'Z_SL', t.N_ZAP, t.IDCASE, null, '904', 'Значение RSLT="'+isnull(cast(t.RSLT as varchar),'')+'" не соответствует допустимому значению USL_OK="'
  +isnull(cast(t.USL_OK as varchar),'')+'"'
 from  tempdb..TEMP_Z_SLUCH t 
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','T','C')
 where substring(cast(t.RSLT as varchar),1,1) != cast(t.usl_ok as varchar)
		
 
-- Проверка №46 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'NPR_DATE', 'Z_SL', t.N_ZAP, t.IDCASE, null, '904', 'Дата направления больше даты начала лечения'
 from tempdb..TEMP_Z_SLUCH t
 where t.npr_date > t.date_z_1
   and t.npr_date is not null


 -- Проверка №45 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDSERV', 'USL', t2.N_ZAP, t1.IDCASE, t1.IDSERV, '905', 'Дублирующий идентификатор IDSERV="'+isnull(cast(IDSERV as varchar),'')+'" в пределах одного случая SL_ID="' +
  isnull(cast(SL_ID as varchar),'')+'"'
  from tempdb..TEMP_USL t1
   join tempdb..TEMP_Z_SLUCH t2 on t1.IDCASE=t2.IDCASE
 group by t2.N_ZAP, t1.IDCASE, t1.SL_ID, t1.IDSERV
 having count(*)>1

 -- Проверка №44 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDSERV', 'SL', max(t2.N_ZAP), t1.IDCASE, null, '905', 'Дублирующий идентификатор SL_ID="'+isnull(cast(t1.SL_ID as varchar),'')+'" в пределах одного закончкнного случая IDСASE="' +
  isnull(cast(t1.IDCASE as varchar),'')+'"'
  from tempdb..TEMP_SLUCH t1
   join tempdb..TEMP_Z_SLUCH t2 on t1.IDCASE=t2.IDCASE
 group by t1.IDCASE, t1.SL_ID
 having count(*)>1

 -- Проверка №43 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'IDCASE', 'ZSL', max(N_ZAP), IDCASE, null, '905', 'Дублирующий идентификатор IDCASE="'+isnull(cast(IDCASE as varchar),'')+'"'
  from tempdb..TEMP_Z_SLUCH
 group by IDCASE
 having count(*)>1

 -- Проверка №42 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'N_ZAP', 'ZAP', N_ZAP, null, null, '905', 'Дублирующий идентификатор N_ZAP="'+isnull(cast(N_ZAP as varchar),'')+'"'
  from tempdb..TEMP_ZAP
 group by N_ZAP
 having count(*)>1

 -- Проверка №41 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PERS', 'ID_PAC', null, null, null, '905', 'Дублирующий идентификатор ID_PAC="'+isnull(cast(ID_PAC as varchar),'')+'"'
  from tempdb..TEMP_PERS
 group by cast(ID_PAC as varchar)
 having count(*)>1

-- Проверка №40 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DATE_Z_2', 'Z_SL', t.N_ZAP, t.IDCASE, null, '904', 'Случай лечения с DATE_Z_2="'+format(t.DATE_Z_2, 'dd.MM.yyyy')+'" не может быть выставлен в реестре счета за YEAR="'
 +isnull(cast(s.YEAR as varchar),'')+'" и MONTH="'+isnull(cast(s.MONTH as varchar),'')+'"'
 from  tempdb..TEMP_Z_SLUCH t 
  join tempdb..TEMP_SCHET s on @type=554
 where (not (YEAR(t.DATE_Z_2)=s.YEAR and MONTH(t.DATE_Z_2)=s.MONTH) and @type=554)
   or (YEAR(t.DATE_Z_2)=s.YEAR and MONTH(t.DATE_Z_2)>s.MONTH and @type in (693,562))
 

 -- Проверка №39 по базе в ОРАКЛЕ (заменена проверкой 001F.00.0580 и 005F.00.0090)
 --insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 --     select 'N_KSG', 'KSG_KPG', z.n_zap, t.idcase, null, '904',  'Значение N_KSG="'+isnull(t.N_KSG,'')+'" не соответствует допустимому в справочнике V023' 
 --      from tempdb..TEMP_KSG_KPG t
	--   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
 --      left join [IES].[T_V023_KSG] f on t.N_KSG=f.k_ksg and z.DATE_2 between f.DATEBEG and isnull(f.DATEEND,z.DATE_2) 
 --     where f.k_ksg is null 
 --       and t.n_kpg is null
 

-- Проверка №38 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'PROT', 'B_PROT', z.n_zap, t.idcase, null, '904',  'Значение PROT="'+isnull(cast(t.PROT as varchar),'')+'" не соответствует допустимому в справочнике N001' 
       from tempdb..TEMP_B_PROT t
	   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_N001_PrOt] f on t.PROT=f.id_prot and z.DATE_2 between f.DATEBEG and isnull(f.DATEEND,z.DATE_2) 
       join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
      where f.id_prot is null 

-- Проверка №37.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DIAG_RSLT', 'B_DIAG', z.n_zap, t.idcase, null, '904',  'Значение Кода результата диагностики  (DIAG_RSLT) "'+ isnull(cast(t.DIAG_RSLT as varchar),'')+'" не найдено в справочнике N011 для кода диагностического показателя (DIAG_CODE) "'+ isnull(cast(t.DIAG_CODE as varchar),'')+'" из справочника N010.' 
       from tempdb..TEMP_B_DIAG t
	   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_N010_MARK] t1 on t1.ID_Igh=t.DIAG_CODE and t.DIAG_DATE between t1.DATEBEG and isnull(t1.DATEEND,t.DIAG_DATE) 
       left join [IES].[T_N011_MARK_VALUE] f on t.DIAG_RSLT=f.id_r_i and t.DIAG_DATE between f.DATEBEG and isnull(f.DATEEND,t.DIAG_DATE) and t1.N010MarkID=f.N010Mark
       join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
      where (f.id_r_i is null or t1.ID_Igh is null)
	    and (t.DIAG_RSLT is not null or t.DIAG_CODE is not null)
        and t.diag_tip = 2 
		and t.REC_RSLT = 1   

-- Проверка №37 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DIAG_RSLT', 'B_DIAG', z.n_zap, t.idcase, null, '904',  'Значение DIAG_RSLT="'+ isnull(cast(t.DIAG_RSLT as varchar),'')+'" не соответствует допустимому в справочнике N011' 
       from tempdb..TEMP_B_DIAG t
	   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_N011_MARK_VALUE] f on t.DIAG_RSLT=f.id_r_i and z.DATE_2 between f.DATEBEG and isnull(f.DATEEND,z.DATE_2) 
       join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
      where f.id_r_i is null 
        and t.diag_tip = 2    
		and t.REC_RSLT = 1   


-- Проверка №36.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DIAG_RSLT', 'B_DIAG', z.n_zap, t.idcase, null, '904',  'Значение Кода результата диагностики  (DIAG_RSLT) "'+ isnull(cast(t.DIAG_RSLT as varchar),'')+'" не найдено в справочнике N008 для кода диагностического показателя (DIAG_CODE) "'+ isnull(cast(t.DIAG_CODE as varchar),'')+'" из справочника N007.' 
       from tempdb..TEMP_B_DIAG t
	   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_N007_MRF] t1 on t1.ID_Mrf=t.DIAG_CODE and t.DIAG_DATE between t1.DATEBEG and isnull(t1.DATEEND,t.DIAG_DATE) 
       left join [IES].[T_N008_MRF_RT] f on t.DIAG_RSLT=f.ID_R_M and t.DIAG_DATE between f.DATEBEG and isnull(f.DATEEND,t.DIAG_DATE) and t1.N007MrfID=f.N007Mrf
       join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
      where (f.ID_R_M is null or t1.ID_Mrf is null)
	    and (t.DIAG_RSLT is not null or t.DIAG_CODE is not null)
		and t.diag_tip = 1  
		and t.REC_RSLT = 1   

-- Проверка №36 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DIAG_RSLT', 'B_DIAG', z.n_zap, t.idcase, null, '904',  'Значение DIAG_RSLT="'+isnull(cast(t.DIAG_RSLT as varchar),'')+'" не соответствует допустимому в справочнике N008' 
       from tempdb..TEMP_B_DIAG t
	   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_N008_MRF_RT] f on t.DIAG_RSLT=f.id_r_m and z.DATE_2 between f.DATEBEG and isnull(f.DATEEND,z.DATE_2)
       join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
      where f.id_r_m is null
        and t.diag_tip = 1 
		and t.REC_RSLT = 1   

-- Проверка №35 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DIAG_CODE', 'B_DIAG', z.n_zap, t.idcase, null, '904',  'Значение DIAG_CODE="'+isnull(cast(t.DIAG_CODE as varchar),'')+'" не соответствует допустимому в справочнике N007' 
       from tempdb..TEMP_B_DIAG t
	   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
       left join [IES].[T_N007_MRF] f on t.DIAG_CODE=f.id_mrf 
      where f.id_mrf is null
        and t.diag_tip = 1 

-- Проверка №34 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DIAG_CODE', 'B_DIAG', z.n_zap, t.idcase, null, '904',  'Значение DIAG_CODE="'+isnull(cast(t.DIAG_CODE as varchar),'')+'" не соответствует допустимому в справочнике N010' 
       from tempdb..TEMP_B_DIAG t
	   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
       left join [IES].[T_N010_MARK] f on t.DIAG_CODE=f.id_igh and z.DATE_2 between f.DATEBEG and isnull(f.DATEEND,z.DATE_2)        
      where f.id_igh is null 
        and t.diag_tip = 2 

-- Проверка №33.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'ONK_M', 'ONK_SL', z.n_zap, t.idcase, null, '904',  'Не указано значение Metastasis (ONK_M)' 
       from tempdb..TEMP_ONK_SL t
	   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
	   join tempdb..TEMP_Z_SLUCH t2 on t2.IDCASE=z.IDCASE
	   join tempdb..TEMP_PACIENT t1 on t1.N_ZAP=t2.N_ZAP
	   join tempdb..TEMP_PERS t3 on cast(t3.ID_PAC as varchar)=cast(t1.ID_PAC as varchar)
      WHERE -- DATEADD(YEAR,18,t3.DR) <= z.DATE_1 
	  -- Львов 16.12.2019
	  FLOOR(CONVERT(INT, z.DATE_1 - t3.DR) / 365.25) > 18
	  --
	  and t.ONK_M is null and t.DS1_T=0
      
-- Проверка №33 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'ONK_M', 'ONK_SL', z.n_zap, t.idcase, null, '904',  'Значение ONK_M="'+isnull(cast(t.ONK_M as varchar),'')+'" не соответствует допустимому в справочнике N005' 
       from tempdb..TEMP_ONK_SL t
       join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
	   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_N005_METASTASIS] f on t.ONK_M=f.id_m and z.DATE_2 between f.DATEBEG and isnull(f.DATEEND,z.DATE_2) 
      where f.id_m is null and t.ONK_M is not null
	   and ((substring(z.DS1,1,3)=f.DS_M and t.ONK_M=f.id_m) or (substring(z.DS1,1,3)=''))

-- Проверка №32.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'ONK_N', 'ONK_SL', z.n_zap, t.idcase, null, '904',  'Не указано значение Nodus (ONK_N)' 
       from tempdb..TEMP_ONK_SL t
	   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
	   join tempdb..TEMP_Z_SLUCH t2 on t2.IDCASE=z.IDCASE
	   join tempdb..TEMP_PACIENT t1 on t1.N_ZAP=t2.N_ZAP
	   join tempdb..TEMP_PERS t3 on cast(t3.ID_PAC as varchar)=cast(t1.ID_PAC as varchar)
      where --DATEADD(YEAR,18,t3.DR) <= z.DATE_1 
	  -- Львов 16.12.2019
	  FLOOR(CONVERT(INT, z.DATE_1 - t3.DR) / 365.25) > 18
	  --
	  and t.ONK_N is null and t.DS1_T=0
      
-- Проверка №32 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'ONK_N', 'ONK_SL', z.n_zap, t.idcase, null, '904',  'Значение ONK_N="'+isnull(cast(t.ONK_N as varchar),'')+'" не соответствует допустимому в справочнике N004' 
       from tempdb..TEMP_ONK_SL t
       join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
	   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_N004_NODUS] f on t.ONK_N=f.id_n and z.DATE_1 between f.DATEBEG and isnull(f.DATEEND,z.DATE_1)
      where f.id_n is null and t.ONK_N is not null 
      
-- Проверка №31.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'ONK_T', 'ONK_SL', z.n_zap, t.idcase, null, '904',  'Не указано значение Tumor (ONK_T)' 
       from tempdb..TEMP_ONK_SL t
	   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
	   join tempdb..TEMP_Z_SLUCH t2 on t2.IDCASE=z.IDCASE
	   join tempdb..TEMP_PACIENT t1 on t1.N_ZAP=t2.N_ZAP
	   join tempdb..TEMP_PERS t3 on cast(t3.ID_PAC as varchar)=cast(t1.ID_PAC as varchar)
      where --DATEADD(YEAR,18,t3.DR) <= z.DATE_1 
	  -- Львов 16.12.2019
	  FLOOR(CONVERT(INT, z.DATE_1 - t3.DR) / 365.25) > 18
	  --
	  and t.ONK_T is null and t.DS1_T=0
      
-- Проверка №31 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'ONK_T', 'ONK_SL', z.n_zap, t.idcase, null, '904',  'Значение ONK_T="'+isnull(cast(t.ONK_T as varchar),'')+'" не соответствует допустимому в справочнике N003' 
       from tempdb..TEMP_ONK_SL t
	   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
       left join [IES].[T_N003_TUMOR] f on t.ONK_T=f.id_t and z.DATE_1 between f.DATEBEG and isnull(f.DATEEND,z.DATE_1) and (substring(z.DS1,1,3)=f.DS_T or z.DS1=f.DS_T or f.DS_T='')
      where f.id_t is null and t.ONK_T is not null
		and ((substring(z.DS1,1,3)=f.DS_T and t.ONK_M=f.id_t) or (substring(z.DS1,1,3)=''))
      
-- Проверка №30.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'STAD', 'ONK_SL', z.n_zap, t.idcase, null, '904',  'Значение STAD="'+isnull(cast(t.STAD as varchar),'')+'" не соответствует указанному коду основного диагноза DS1="'
	  +isnull(cast(z.DS1 as varchar),'')+'"' 
       from tempdb..TEMP_ONK_SL t
       join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
	   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       join [IES].[T_N002_STADIUM] f on t.STAD=f.id_st and z.DATE_1 between f.DATEBEG and isnull(f.DATEEND,z.DATE_1)
      where (len(isnull(f.DS_St,'')) in (0,5) and z.DS1 != case f.DS_St when '' then z.DS1 when null then z.DS1 else f.DS_St end)
	    or (len(isnull(f.DS_St,'')) in (0,3) and substring(z.DS1,1,3) != case f.DS_St when '' then substring(z.DS1,1,3) when null then substring(z.DS1,1,3) else f.DS_St end)

-- Проверка №30.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'STAD', 'ONK_SL', z.n_zap, t.idcase, null, '904',  'Не указана стадия заболевания (STAD)' 
       from tempdb..TEMP_ONK_SL t
       join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
	   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
      where t.DS1_T in (0,1,2,3,4) and t.stad is null

-- Проверка №30 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'STAD', 'ONK_SL', z.n_zap, t.idcase, null, '904',  'Значение STAD="'+isnull(cast(t.STAD as varchar),'')+'" не соответствует допустимому в справочнике N002' 
       from tempdb..TEMP_ONK_SL t
       join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T','C')
	   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_N002_STADIUM] f on t.STAD=f.id_st and z.DATE_1 between f.DATEBEG and isnull(f.DATEEND,z.DATE_1)
      where f.id_st is null and t.STAD is not null 

-- Проверка №29 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'PRVS', 'USL', z.n_zap, t.idcase, t.IDSERV, '904',  'Значение PRVS="'+isnull(cast(t.PRVS as varchar),'')+'" не соответствует допустимому в справочнике V021' 
       from tempdb..TEMP_USL t
	   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_V021_MED_SPEC] f on t.PRVS=f.CODE_SPEC and z.DATE_1 between f.DATEBEG and isnull(f.DATEEND,z.DATE_1)
      where f.idspec is null 

-- Проверка №28 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'PRVS', 'SL', t.n_zap, t.idcase, null, '904',  'Значение PRVS="'+isnull(cast(t.PRVS as varchar),'')+'" не соответствует допустимому в справочнике V021' 
       from tempdb..TEMP_SLUCH t
       left join [IES].[T_V021_MED_SPEC] f on t.PRVS=f.CODE_SPEC and t.DATE_1 between f.DATEBEG and isnull(f.DATEEND,t.DATE_1)
      where f.idspec is null 

-- Проверка №27 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DN', 'SL', t.n_zap, t.idcase, null, '904',  'Значение DN="'+isnull(cast(t.DN as varchar),'')+'" не соответствует допустимому значению (1,2,4,6)' 
       from tempdb..TEMP_SLUCH t
		join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','C','D')
  where t.DN not in (1,2,4,6)

-- Проверка №26.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'P_PER', 'SL', zs.N_ZAP, zs.IDCASE, null, '904', 'Некорректное заполнение поля P_PER'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','C')
  join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
      where ((t.p_per = 4 and zs.date_z_1 = t.date_1)
         or (t.p_per is null and zs.usl_ok in (1,2))
         or (t.p_per is not null and zs.usl_ok in (3,4))
         or (t.p_per = 2 and zs.for_pom = 3))
		  AND (zs.OPLATA <> 2 OR zs.oplata IS null)

-- Проверка №26 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'P_PER', 'SL', t.n_zap, t.idcase, null, '904',  'Значение P_PER="'+isnull(cast(t.P_PER as varchar),'')+'" не соответствует допустимому значению (1,2,3,4)' 
       from tempdb..TEMP_SLUCH t
	   join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','C')
 where t.P_PER not in (1,2,3,4)

-- Проверка №25 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'P_CEL', 'SL', t.n_zap, t.idcase, null, '904',  'Значение P_CEL="'+isnull(cast(t.P_CEL as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from tempdb..TEMP_SLUCH t
	    join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','C','D')
        left join [IES].[T_V025_KPC] f on t.P_CEL=f.idpc and t.DATE_1 between f.DATEBEG and isnull(f.DATEEND,t.DATE_1)
      where f.idpc is null 
        and t.p_cel is not null

-- Проверка №24 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'DET', 'SL', t.n_zap, t.idcase, null, '904',  'Значение DET="'+isnull(cast(t.DET as varchar),'')+'" не соответствует допустимому значению (0,1)' 
       from tempdb..TEMP_SLUCH t
	   join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','C','T')
      where t.det not in (0,1)


-- Проверка №23.5 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL', 'SL', ss.N_ZAP, ss.IDCASE, null, '904', 'На профиль PROFIL="'+isnull(cast(ss.profil as varchar),'')+'" нет утвержденных объемов'
  from tempdb..TEMP_SLUCH ss 
  JOIN tempdb..TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
	   join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','C')
 where not exists (SELECT 1 FROM IES.T_CHER_PROFIL_PROFIL_K t0 
                   JOIN IES.T_DICTIONARY_BASE t1 ON t1.DictionaryBaseID = t0.DictionaryBaseID
                   LEFT JOIN IES.T_V020_BED_PROFILE t2 ON t2.V020BedProfileID = t0.V020BedProfile
				   where t0.PROFIL=ss.PROFIL 
				     --and year(ss.DATE_2) between t1.YearBegin and t1.YearEnd 
				     --and month(ss.DATE_2) between t1.MonthBegin and t1.MonthEnd 
				  )
   and ssa.USL_OK in (1,2)
   and (@type != 693 or getdate() >= '01.03.2019')
    AND (ssa.OPLATA <> 2 OR ssa.oplata IS null)  

-- Проверка №23.4 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL_K', 'SL', ss.N_ZAP, ss.IDCASE, null, '904', 'Значение поля PROFIL_K="'+isnull(cast(ss.profil_k as varchar),'')+'"  не соответствует значению полю  PROFIL="'+isnull(cast(ss.profil as varchar),'')+'"'
  from tempdb..TEMP_SLUCH ss 
  JOIN tempdb..TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
	   join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','C','T')
 where not exists (SELECT 1 FROM IES.T_CHER_PROFIL_PROFIL_K t0 
                   JOIN IES.T_DICTIONARY_BASE t1 ON t1.DictionaryBaseID = t0.DictionaryBaseID
                   LEFT JOIN IES.T_V020_BED_PROFILE t2 ON t2.V020BedProfileID = t0.V020BedProfile
				   where t2.IDK_PR=ss.PROFIL_K and t0.PROFIL=ss.PROFIL 
				  )
   and ssa.USL_OK in (1,2)
   and (@type != 693 or getdate() >= '01.03.2019')  
             

-- Проверка №23.3 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL_K', 'SL', ss.N_ZAP, ss.IDCASE, null, '904', 'Значение поля PROFIL_K="'+isnull(cast(ss.profil_k as varchar),'')+'"  не соответствует значению полю  PROFIL="'+isnull(cast(ss.profil as varchar),'')+'" для медицинской реабилитации'
  from tempdb..TEMP_SLUCH ss 
  JOIN tempdb..TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
	   join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','C','T')
 where (ss.PROFIL != 158 and ss.PROFIL_K in (30,31,32))


-- Проверка №23.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL_K', 'SL', ss.N_ZAP, ss.IDCASE, null, '904', 'Заполнено поле PROFIL_K для USL_OK="'+isnull(cast(ssa.USL_OK as varchar),'')+'"'
 from tempdb..TEMP_SLUCH ss 
  JOIN tempdb..TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
	   join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','C','T')
 where ssa.USL_OK in (3,4) and ss.PROFIL_K is not null

-- Проверка №23.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'PROFIL_K', 'SL', ss.N_ZAP, ss.IDCASE, null, '904', 'Не заполнено поле PROFIL_K для USL_OK="'+isnull(cast(ssa.USL_OK as varchar),'')+'"'
 from tempdb..TEMP_SLUCH ss 
  JOIN tempdb..TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
	   join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','C','T')
 where ssa.USL_OK in (1,2) and ss.PROFIL_K is null

-- Проверка №23 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'PROFIL_K', 'SL', t.n_zap, t.idcase, null, '904',  'Значение PROFIL_K="'+isnull(cast(t.PROFIL_K as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from tempdb..TEMP_SLUCH t
	   join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','C','T')
       left join [IES].[T_V020_BED_PROFILE] f on t.PROFIL_K=f.idk_pr and t.DATE_1 between f.DATEBEG and isnull(f.DATEEND,t.DATE_1)
      where f.idk_pr is null 
        and t.profil_k is not null

-- Проверка №22 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'PROFIL', 'USL', z.n_zap, t.idcase, t.IDSERV, '904',  'Значение PROFIL="'+isnull(cast(t.PROFIL as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from tempdb..TEMP_USL t
	   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_V002_PROFILE] f on t.PROFIL=f.idpr and t.DATE_IN between f.DATEBEG and isnull(f.DATEEND,t.DATE_IN)
      where f.idpr is null 

-- Проверка №21 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'PROFIL', 'SL', t.n_zap, t.idcase, null, '904',  'Значение PROFIL="'+isnull(cast(t.PROFIL as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from tempdb..TEMP_SLUCH t
       left join [IES].[T_V002_PROFILE] f on t.PROFIL=f.idpr and t.DATE_2 between f.DATEBEG and isnull(f.DATEEND,t.DATE_2)
      where f.idpr is null 

---- Проверка №20 по базе в ОРАКЛЕ 
-- insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
--      select 'METOD_HMP', 'SL', t.n_zap, t.idcase, null, '904',  'Значение METOD_HMP="'+cast(t.METOD_HMP as varchar)+'" не соответствует допустимому в справочнике' 
--       from tempdb..TEMP_SLUCH t
--	   join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T')
--       left join [IES].[T_V019_VMP_METHOD] f on t.METOD_HMP=f.idhm and t.DATE_2 between f.DATEBEG and isnull(f.DATEEND,t.DATE_2)
--	   left join [IES].[T_V019_VMP_METHOD_PREV] f2 on t.METOD_HMP=f2.V019VmpMethod and t.DATE_2 between f2.DATEBEG and isnull(f2.DATEEND,t.DATE_2)
--      where f.idhm is null and f2.V019VmpMethod is null

-- Проверка №20.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'METOD_HMP', 'SL', t.n_zap, t.idcase, null, '904',  'Значение METOD_HMP="'+cast(t.METOD_HMP as varchar)+'" не соответствует указанному коду МКБ DS1="'
	   +cast(t.DS1 as varchar)+'"' 
       from tempdb..TEMP_SLUCH t
	   join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T')
       left join [IES].[T_V019_VMP_METHOD] f on t.METOD_HMP=f.idhm and t.DATE_2 between f.DATEBEG and isnull(f.DATEEND,t.DATE_2)
	   	    and  
			--1
			(f.DIAG = SUBSTRING(t.DS1,1,3)
			or f.DIAG like '%'+SUBSTRING(t.DS1,1,3)
			or f.DIAG like '%'+SUBSTRING(t.DS1,1,3)+';%'
			or f.DIAG like '%'+t.DS1+';%'
			or f.DIAG = t.DS1
			or f.DIAG like '%'+t.DS1
			) 
			--
      where f.V019VmpMethodID is null

-- Проверка №19.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'VID_HMP', 'SL', t.n_zap, t.idcase, null, '904',  'Значение VID_HMP="'+cast(t.VID_HMP as varchar)+'" не соответствует допустимому профилю МП PROFIL="'+cast(t.PROFIL as varchar)+'"' 
	  --select 'METOD_HMP', 'SL', t.n_zap, t.idcase, null, '904',  'Значение группы ВМП="'+cast(v019.HGR as varchar)+'" не соответствует допустимому профилю МП PROFIL="'+cast(t.PROFIL as varchar)+'"' 
       from tempdb..TEMP_SLUCH t
	   join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T')
	  -- LEFT OUTER JOIN IES.T_V019_VMP_METHOD_PREV AS v019 ON t.METOD_HMP = v019.V019VmpMethod AND t.DATE_2 BETWEEN v019.DATEBEG AND ISNULL(v019.DATEEND, t.DATE_2)
       left join [IES].[T_CHER_GR_VMP_PROFIL_NEW] f on --f.gr_vmp = cast(v019.HGR as varchar)
	   cast(f.gr_vmp as varchar) =
		case
			when @year = 2021 then (select top 1 hgr from ies.R_NSI_HGR_TARIF t100 where t.SUM_M = t100.tarif and t100.datebegin >= '01.01.2021')
			else substring(t.vid_hmp,dbo.instr(t.vid_hmp,'.',1,2)+1,case dbo.instr(t.vid_hmp,'.',1,3)-dbo.instr(t.vid_hmp,'.',1,2)-1 when -1 then 0 else dbo.instr(t.vid_hmp,'.',1,3)-dbo.instr(t.vid_hmp,'.',1,2)-1 end)
		end	    
		and f.profil=t.PROFIL
		and f.year=year(t.DATE_2)  
      where f.profil is null
        and (@type != 693 or getdate() >= '01.03.2019')  

-- Проверка №19 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'VID_HMP', 'SL', t.n_zap, t.idcase, null, '904',  'Значение VID_HMP="'+cast(t.VID_HMP as varchar)+'" не соответствует допустимому в справочнике' 
       from tempdb..TEMP_SLUCH t
	   join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('T')
       left join [IES].[T_V018_VMP_TYPE] f on t.VID_HMP=f.idhvid and t.DATE_2 between f.DATEBEG and isnull(f.DATEEND,t.DATE_2)
	   left join IES.T_V018_VMP_TYPE_PREV f2 on t.VID_HMP=f2.V018VmpType and t.DATE_2 between f2.DATEBEG and isnull(f2.DATEEND,t.DATE_2)
      where f.idhvid is null and f2.V018VmpType is null

-- Проверка №18 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'IDSP', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Значение IDSP="'+isnull(cast(t.IDSP as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from tempdb..TEMP_Z_SLUCH t
       left join [IES].[T_V010_PAY] f on t.IDSP=f.idsp and t.DATE_Z_1 between f.DATEBEG and isnull(f.DATEEND,t.DATE_Z_1)
      where f.idsp is null 


-- Проверка №17 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'ISHOD', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Значение ISHOD="'+isnull(cast(t.ISHOD as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from tempdb..TEMP_Z_SLUCH t
       left join [IES].[T_V012_OUTCOME] f on t.ISHOD=f.idiz and t.DATE_Z_1 between f.DATEBEG and isnull(f.DATEEND,t.DATE_Z_1)
      where f.idiz is null 

-- Проверка №16 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'RSLT', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Значение RSLT="'+isnull(cast(t.RSLT as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from tempdb..TEMP_Z_SLUCH t
	   join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','C','T')
       left join [IES].[T_V009_RESULT] f on t.RSLT=f.idrmp and t.DATE_Z_1 between f.DATEBEG and isnull(f.DATEEND,t.DATE_Z_1)
      where f.idrmp is null 


-- Проверка №15 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'LPU', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Значение LPU="'+isnull(cast(t.LPU as varchar),'')+'" в блоке Z_SL не соответствует допустимому значению в справочнике' 
       from tempdb..TEMP_Z_SLUCH t
       left join [IES].[T_F003_MO] f on t.LPU=f.mcod and t.DATE_Z_2 between f.D_BEGIN and isnull(f.D_END,t.DATE_Z_2)
      where f.mcod is null


-- Проверка №14.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'LPU', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Значение LPU="'+isnull(cast(t.LPU as varchar),'')+'" в блоке Z_SL не соответствует значению поля CODE_MO="'+isnull(cast(t.LPU as varchar),'')+'" в заголовке счета.' 
       from tempdb..TEMP_Z_SLUCH t
	   join tempdb..TEMP_SCHET s on t.LPU != s.CODE_MO
 where  (@type != 693 or getdate() >= '01.03.2019')  

-- Проверка №14 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'LPU', 'USL', z.n_zap, t.idcase, t.IDSERV, '904',  'Значение LPU="'+isnull(cast(t.LPU as varchar),'')+'" в блоке USL не соответствует допустимому значению в справочнике' 
       from tempdb..TEMP_USL t
	   join tempdb..TEMP_SLUCH z on z.IDCASE=t.IDCASE and z.SL_ID=t.SL_ID
       left join [IES].[T_F003_MO] f on t.LPU=f.mcod and z.DATE_2 between f.D_BEGIN and isnull(f.D_END,z.DATE_2)
      where f.mcod is null


-- Проверка №13 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'NPR_DATE', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Не заполнено обязательное поле NPR_DATE' 
       from tempdb..TEMP_Z_SLUCH t
        inner join tempdb..TEMP_SLUCH s on t.idcase=s.idcase
      where (
	   (t.FOR_POM=3 and t.USL_OK = 1) 
	or (t.USL_OK=2) 
--	or (s.DS1 like 'C%') 
--  or (s.DS1 between 'D00.00' and 'D09.99') 
--	or (s.DS1 between 'D70.00' and 'D70.99' and  exists(select 1 from tempdb..TEMP_DS2 t3  where t3.idcase=s.idcase and t3.sl_id=s.sl_id and (t3.ds2 between 'C00.00' and 'C80.99' or t3.ds2 between 'C97.00' and 'C97.99')))
	) and isnull(t.NPR_DATE,'')='' 

-- Проверка №12 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'NPR_MO', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Не заполнено обязательное поле NPR_MO' 
       from tempdb..TEMP_Z_SLUCH t
        inner join tempdb..TEMP_SLUCH s on t.idcase=s.idcase
      where (
	   (t.FOR_POM=3 and t.USL_OK = 1) 
	or (t.USL_OK=2) 
--	or (s.DS1 like 'C%') 
--  or (s.DS1 between 'D00.00' and 'D09.99') 
--	or (s.DS1 between 'D70.00' and 'D70.99' and  exists(select 1 from tempdb..TEMP_DS2 t3  where t3.idcase=s.idcase and t3.sl_id=s.sl_id and (t3.ds2 between 'C00.00' and 'C80.99' or t3.ds2 between 'C97.00' and 'C97.99')))
	) and isnull(t.NPR_MO,'')='' 

-- Проверка №11 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'NPR_MO', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Значение NPR_MO="'+isnull(cast(t.NPR_MO as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from tempdb..TEMP_Z_SLUCH t
       left join [IES].[T_F003_MO] f on t.NPR_MO=f.mcod and t.NPR_DATE between f.D_BEGIN and isnull(f.D_END,t.NPR_DATE)
      where f.mcod is null 
        and t.npr_mo is not null


-- Проверка №10 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'FOR_POM', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Значение FOR_POM="'+isnull(cast(t.FOR_POM as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from tempdb..TEMP_Z_SLUCH t
       left join [IES].[T_V014_MEDICAL_FORM] f on t.for_pom=f.idfrmmp and t.DATE_Z_2 between f.DATEBEG and isnull(f.DATEEND,t.DATE_Z_2)
      where f.idfrmmp is null

-- Проверка №9 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'VID_POM', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Значение VID_POM="'+isnull(cast(t.VIDPOM as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from tempdb..TEMP_Z_SLUCH t
       left join [IES].[T_V008_MEDICAL_TYPE] f on t.vidpom=f.idvmp and t.DATE_Z_2 between f.DATEBEG and isnull(f.DATEEND,t.DATE_Z_2)
      where f.idvmp is null 

-- Проверка №8 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'USL_OK', 'Z_SL', t.n_zap, t.idcase, null, '904',  'Значение USL_OK="'+isnull(cast(t.USL_OK as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from tempdb..TEMP_Z_SLUCH t
       left join [IES].[T_V006_MEDICAL_TERMS] f on t.usl_ok=f.idump and t.DATE_Z_2 between f.DATEBEG and isnull(f.DATEEND,t.DATE_Z_2)
      where f.idump is null

-- Проверка №7 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'INV', 'PACIENT', t.n_zap, t.idcase, null, '904',  'Значение INV="'+isnull(cast(z.INV as varchar),'')+'" не соответствует допустимому (0,1,2,3,4)' 
       from tempdb..TEMP_Z_SLUCH t
	    join tempdb..TEMP_PACIENT z on z.N_ZAP=t.N_ZAP
		join tempdb..TEMP_ZGLV s on SUBSTRING(s.FILENAME,1,1) in ('H','C')
      where z.INV not in (0,1,2,3,4) 

-- Проверка №6.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'ST_OKATO', 'PACIENT', t.n_zap, z.idcase, null, '904',  'Значение ST_OKATO не соответсвует справочнику' 
       from tempdb..TEMP_Z_SLUCH z
	    join tempdb..TEMP_PACIENT t on z.N_ZAP=t.N_ZAP
        left join [IES].[T_F002_SMO] f on t.ST_OKATO=f.TF_OKATO and z.DATE_Z_2 between f.D_BEGIN and isnull(f.D_END, z.DATE_Z_2)
      where t.ST_OKATO is not null
        and f.SMOCOD is null

-- Проверка №6.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'SMO_OK', 'PACIENT', t.n_zap, z.idcase, null, '904',  'Значение SMO_OK не соотвертсвует справочнику' 
       from tempdb..TEMP_Z_SLUCH z
	    join tempdb..TEMP_PACIENT t on z.N_ZAP=t.N_ZAP
        left join [IES].[T_F002_SMO] f on t.SMO_OK=f.TF_OKATO and z.DATE_Z_2 between f.D_BEGIN and isnull(f.D_END, z.DATE_Z_2)
      where t.SMO_OK is not null
        and f.SMOCOD is null

-- Проверка №6 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'SMO_OK', 'PACIENT', t.n_zap, z.idcase, null, '904',  'Не заполнено обязательное поле SMO_OK' 
       from tempdb..TEMP_Z_SLUCH z
	    join tempdb..TEMP_PACIENT t on z.N_ZAP=t.N_ZAP
      where t.smo_ok is null 
        and t.smo is null
        --and t.SMO_OGRN is null
		and @type in (554,693)

-- Проверка №5 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'SMO_OGRN', 'PACIENT', t.n_zap, z.idcase, null, '904',  'Не заполнено обязательное поле SMO_OGRN' 
       from tempdb..TEMP_Z_SLUCH z
	    join tempdb..TEMP_PACIENT t on z.N_ZAP=t.N_ZAP
      where t.smo_ogrn is null 
        and t.smo is null
        and t.smo_nam is null

-- Проверка №4.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'SMO', 'PACIENT', t.n_zap, z.idcase, null, '904',  'Значение SMO="'+isnull(cast(t.SMO as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from tempdb..TEMP_Z_SLUCH z
	    join tempdb..TEMP_PACIENT t on z.N_ZAP=t.N_ZAP
        left join [IES].[T_F002_SMO] f on t.smo=f.smocod
      where f.smocod is null 
        and t.smo is not null
		and @type= 562

-- Проверка №4 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'SMO', 'PACIENT', t.n_zap, z.idcase, null, '904',  'Значение SMO="'+isnull(cast(t.SMO as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from tempdb..TEMP_Z_SLUCH z
	    join tempdb..TEMP_PACIENT t on z.N_ZAP=t.N_ZAP
        left join [IES].[T_F002_SMO] f on t.smo=f.smocod and z.DATE_Z_1 between f.D_BEGIN and isnull(f.D_END,z.DATE_Z_1)
      where f.smocod is null 
        and t.smo is not null
		and @type in (693,554)

-- Проверка №3 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'VPOLIS', 'PACIENT', t.n_zap, z.idcase, null, '904',  'Значение VPOLIS="'+isnull(cast(t.VPOLIS as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from tempdb..TEMP_Z_SLUCH z
	    join tempdb..TEMP_PACIENT t on z.N_ZAP=t.N_ZAP
       left join [IES].[T_F008_OMS_TYPE] f on t.vpolis=f.iddoc and z.DATE_Z_1 between f.DATEBEG and isnull(f.DATEEND,z.DATE_Z_1)
      where f.iddoc is null

-- Проверка №3.1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'SPOLIS', 'PACIENT', t.n_zap, z.idcase, null, '904',  'При значение VPOLIS="'+isnull(cast(t.VPOLIS as varchar),'')+'" SPOLIS должен отсутствовать' 
       from tempdb..TEMP_Z_SLUCH z
	    join tempdb..TEMP_PACIENT t on z.N_ZAP=t.N_ZAP
      where t.VPOLIS in (2,3) and t.SPOLIS is not null

-- Проверка №3.2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'NPOLIS', 'PACIENT', t.n_zap, z.idcase, null, '904',  'При значение VPOLIS="'+isnull(cast(t.VPOLIS as varchar),'')+'" NPOLIS не равен 9 знакам' 
       from tempdb..TEMP_Z_SLUCH z
	    join tempdb..TEMP_PACIENT t on z.N_ZAP=t.N_ZAP
      where t.VPOLIS = 2 and len(t.NPOLIS) != 9

-- Проверка №3.3 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'NPOLIS', 'PACIENT', t.n_zap, z.idcase, null, '904',  'При значение VPOLIS="'+isnull(cast(t.VPOLIS as varchar),'')+'" NPOLIS не равен 16 знакам' 
       from tempdb..TEMP_Z_SLUCH z
	    join tempdb..TEMP_PACIENT t on z.N_ZAP=t.N_ZAP
      where t.VPOLIS = 3 and len(t.NPOLIS) != 16

-- Проверка №2 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'PR_NOV', 'ZAP', t.n_zap, z.idcase, null, '904',  'Значение PR_NOV="'+isnull(cast(t.PR_NOV as varchar),'')+'" не соответствует допустимому значению (0,1)' 
       from tempdb..TEMP_Z_SLUCH z
	    join tempdb..TEMP_ZAP t on z.N_ZAP=t.N_ZAP
      where t.pr_nov not in (0,1) 	   

-- Проверка №1 по базе в ОРАКЛЕ 
 insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
      select 'CODE_MO', 'SCHET', null, null, null, '904',  'Значение CODE_MO="'+isnull(cast(t.CODE_MO as varchar),'')+'" не соответствует допустимому значению в справочнике' 
       from tempdb..TEMP_SCHET t
       left join [IES].[T_F003_MO] f on t.code_mo=f.mcod and t.DSCHET between f.D_BEGIN and ISNULL(f.D_END,t.dschet)
      where f.mcod is null 
END
      
--=========================================================================
-- -=КОНЕЦ=  Блок проверок по МТР от ЛПУ добавленных сотрудниками КОФОМС.
--=========================================================================

--DOCDATE и DOCORG
 insert into #Errors (IM_POL,ZN_POL,BASE_EL, N_ZAP,ID_PAC, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DOCDATE',isnull(cast(s.DOCDATE as varchar) ,'не заполнено') ,'PERS', zs.N_ZAP,t.ID_PAC, zs.IDCASE, null, '904', 'Не заполнена дата выдачи документа при отсуствии ЕНП'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_PACIENT t on t.N_ZAP=zs.N_ZAP 
  join tempdb..TEMP_PERS s on cast(t.ID_PAC as varchar)=cast(s.ID_PAC as varchar) 
 where 
 zs.DATE_Z_2 >= '01.11.2019'
 and @type = 554
 and len(isnull(t.NPOLIS,''))<16
 and (s.DOCDATE is null) 


 --DOCDATE и DOCORG
 insert into #Errors (IM_POL,ZN_POL,BASE_EL, N_ZAP,ID_PAC, IDCASE, IDSERV, OSHIB, COMMENT)
 select 'DOCORG',isnull(s.DOCORG,'не заполнено') ,'PERS', zs.N_ZAP,t.ID_PAC, zs.IDCASE, null, '904', 'Не заполнен орган выдавший документ при отсуствии ЕНП (менее 5 символов)'
 from tempdb..TEMP_Z_SLUCH zs
  join tempdb..TEMP_PACIENT t on t.N_ZAP=zs.N_ZAP 
  join tempdb..TEMP_PERS s on cast(t.ID_PAC as varchar)=cast(s.ID_PAC as varchar) 
 where 
 zs.DATE_Z_2 >= '01.11.2019'
 and @type = 554
 and len(isnull(t.NPOLIS,''))<16
 and (len(isnull(s.DOCORG,''))<5) 



-- Уникальность счёта
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'CODE', 'SCHET', null, null,null, '905', 
	'Счет с таким CODE=' + schet.code + ' и CODE_MO=' + schet.CODE_MO + ' уже загружен, со следующими полями NSCHET=' + schet.NSCHET + 
	',PLAT=' + isnull(schet.PLAT, '') + ',YEAR=' + cast(schet.[YEAR] as varchar(10)) + ',MONTH=' + cast(schet.[MONTH] as varchar(10)) + 
	',DSCHET=' + cast(schet.DSCHET as varchar(10)) + ',FILENAME=' + s1.[FILENAME] + '' 
from tempdb..TEMP_SCHET schet
join tempdb..TEMP_ZGLV s1 on SUBSTRING(s1.FILENAME,1,1) in ('H','C')
join ies.T_SCHET s on s.CODE = schet.code and s.CODE_MO = schet.CODE_MO and s.PLAT=schet.PLAT and s.YEAR=schet.YEAR
where (s.NSCHET <> schet.NSCHET or isnull(s.PLAT, 0) <> isnull(schet.PLAT, 0) 
	or s.[FILENAME] <> s1.[FILENAME] or s.[YEAR] <> schet.[YEAR] or s.[MONTH] <> schet.[MONTH] or s.DSCHET <> schet.DSCHET) 
	and s.type_ <> '562' and @type <> '562' and s.type_ = @type and s.IsDelete = 0
	and (schet.year <> s.year or schet.plat <> s.plat or schet.code <> s.code or schet.code_mo <> s.code_mo or schet.nschet <> s.nschet and @type = 693) --- для перезагрузки не закрытого


insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'N_ZAP', 'ZAP', null, null, null, '905', 'Версия должна быть 3.12' from tempdb..TEMP_ZGLV s
where s.[VERSION] <> '3.12'

/*--проверки уникальности идентификаторов перенесены в блок проверок ТФОМС
-- Проверка №42 по базе в ОРАКЛЕ 
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'N_ZAP', 'ZAP', N_ZAP, null, null, '905', 'Дублирующий идентификатор N_ZAP' from tempdb..TEMP_ZAP
group by N_ZAP
having count(*)>1

-- Проверка №43 по базе в ОРАКЛЕ 
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'IDCASE', 'SLUCH', null, IDCASE, null, '905', 'Дублирующий идентификатор IDCASE ('+ltrim(cast(count(*) as varchar(6)))+')' from tempdb..TEMP_Z_SLUCH
where IDCASE is not null
group by IDCASE
having count(*)>1

-- Проверка №45 по базе в ОРАКЛЕ 
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'IDSERV', 'USL', null, IDCASE, IDSERV, '905', 'Дублирующий идентификатор IDSERV в пределах одного случая' from tempdb..TEMP_USL
group by IDCASE, IDSERV
having count(*)>1

-- Проверка №41 по базе в ОРАКЛЕ 
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'PERS', 'ID_PAC', null, null, null, '905', 'Дублирующий идентификатор ID_PAC = ' + cast(ID_PAC as varchar(36)) from tempdb..TEMP_PERS
group by cast(ID_PAC as varchar(36))
having count(*)>1
*/
/*
-- ГКЕ: Вставлено по заявке Федорова Е.Ю.
-- Перенесена в блок проверок ТФОМС по номером 139
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'ED_COL', 'SLUCH', zs.N_ZAP, NULL, NULL, '905', 'Количество единиц оплаты медпомощи (ED_COL) должно быть равно 1 ('+cast(ss.ED_COL as varchar(200))+')'
from tempdb..TEMP_Z_SLUCH zs join tempdb..TEMP_SLUCH ss on zs.IDCASE=ss.IDCASE
where zs.IDSP <> 9 and zs.USL_OK in (3,4) and ss.ED_COL>1

-- ГКЕ [25.06.2018]: Вставлено по заявке Федорова Е.Ю.
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
  select 'P_CEL', 'SLUCH', NULL, us.IDCASE, NULL, '905', 'В обращении должно быть не менее двух посещений'
    from tempdb..TEMP_SLUCH s join tempdb..TEMP_USL us on s.IDCASE=us.IDCASE
    where s.P_CEL = '3.0'
	      and (
		       (s.PODR>='10001' and s.PODR<'10018') 
			or (s.PODR>='10019' and s.PODR<='10048')
		    or (s.PODR>='40001' and s.PODR<'40018') 
			or (s.PODR>='40019' and s.PODR<='40048')
			or (s.PODR in ('10018','40018') and s.PODR=us.PODR)
			)
	group by us.IDCASE
	having count(*)<2
*/
/* 27/08/2018 - отключено
-- ГКЕ [13.08.2018]: Вставлено по заявке Федорова Е.Ю.
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
  select 'P_CEL', 'SLUCH', s.N_ZAP, s.IDCASE, NULL, '905', 'Недопустимый профиль в неотложной помощи'
    from tempdb..TEMP_SLUCH s --join tempdb..TEMP_USL us on s.IDCASE=us.IDCASE
    where s.P_CEL = '1.1' and s.PROFIL=85 and s.PODR in ('10033','40033')
*/
-- ГКЕ [16.08.2018]: Вставлено по заявке Матвеева А.Н.: для МТР-счетов (параметр @Type=554) обязательно должен быть заполнен KD (KD_Z для законченного случая) для КС/ДС
/*
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
  select 'KD', 'SLUCH', s.N_ZAP, NULL, NULL, '905', 'Не указана длительность лечения (KD/KD_Z)'
    from tempdb..TEMP_SLUCH s
	     join tempdb..TEMP_Z_SLUCH sa on s.N_ZAP=sa.N_ZAP
    where @type in (554) and (s.KD is NULL or sa.KD_Z is NULL) and sa.USL_OK in (1,2,21,22,23)
*/
/* -- Перенесена в блок проверок ТФОМС по номером 54
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'KD_Z', 'SLUCH', zs.N_ZAP, null, NULL,  '905', 'Не заполнено поле KD_Z'
from tempdb..TEMP_Z_SLUCH zs join tempdb..TEMP_SLUCH ss on zs.IDCASE=ss.IDCASE
where (zs.USL_OK = 1 or zs.USL_OK = 2) and zs.KD_Z is null
	
 -- Перенесена в блок проверок ТФОМС по номером 11
--[12.11.2018]
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'NPR_MO', 'SLUCH', ss.IDCASE, NULL, NULL, '905', 'NPR_MO не соответствует справочнику F003'
from tempdb..TEMP_SLUCH ss
     join tempdb..TEMP_Z_SLUCH zs on ss.N_ZAP=zs.N_ZAP
	 left join IESDB.ies.T_F003_MO f003 on (f003.MCOD = zs.NPR_MO)
  where zs.NPR_MO IS not null and f003.MCOD is null

-- ГКЕ [12.08.2018]: проверка на обязательность заполнения полей NPR_MO и NPR_Date при определенных условиях
 -- Перенесена в блок проверок ТФОМС по номером 12
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'NPR_MO', 'SLUCH', ss.IDCASE, NULL, NULL, '905', 'Отсутствуют обязательные к заполнению реквизиты NPR_MO и/или NPR_DATE'
from tempdb..TEMP_SLUCH ss
     join tempdb..TEMP_Z_SLUCH zs on ss.N_ZAP=zs.N_ZAP
  where (zs.NPR_MO IS NULL OR zs.NPR_DATE IS NULL) AND ((zs.FOR_POM=3 AND zs.USL_OK IN (1,2,21,22,23)) OR (zs.FOR_POM=2 AND zs.USL_OK=1) OR (ss.DS_ONK=1))
*/


  ---ААААААААААААААААААААААА
-- insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
--select 'DKK1', 'KSG', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Поле DKK1 не соответствует справочнику. (при USL_OK = 2 и DKK1 = ' + cast (ksg.DKK1 as varchar(50)) + ' и N_KSG= ' + cast (ksg.N_KSG as varchar(50)) + ')'
--from tempdb..TEMP_SLUCH ss
--join tempdb..TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
--join tempdb..TEMP_KSG_KPG ksg on (ksg.IDCASE = ss.IDCASE and ksg.SL_ID  = ss.SL_ID)
--left join [IES].[R_NSI_KSG_DS_KC] ds on ksg.N_KSG = ds.N_KSG
--where ssa.USL_OK = 2 and ISnull(ksg.DKK1,'') <> isnull(ds.DKK,'') and ksg.N_KSG is not null and ds.N_KSG is not null --and ksg.DKK1 is not null

--insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
--select 'DKK1', 'KSG', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Поле DKK1 не соответствует справочнику. (при USL_OK = 1 и DKK1 = ' + cast (ksg.DKK1 as varchar(50)) + ' и N_KSG= ' + cast (ksg.N_KSG as varchar(50)) + ')'
--from tempdb..TEMP_SLUCH ss
--join tempdb..TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
--join tempdb..TEMP_KSG_KPG ksg on (ksg.IDCASE = ss.IDCASE and ksg.SL_ID  = ss.SL_ID)
--left join [IES].[R_NSI_KSG_KC] ds on ksg.N_KSG = ds.N_KSG
--where ssa.USL_OK = 1 and ISnull(ksg.DKK1,'') <> isnull(ds.DKK,'') and ksg.N_KSG is not null and ds.N_KSG is not null --and ksg.DKK1 is not null

insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DKK1', 'KSG', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Поле DKK1 не соответствует справочнику. (при USL_OK = 2 и DKK1 = ' + cast (ksg.DKK1 as varchar(50)) + ' и N_KSG= ' + cast (ksg.N_KSG as varchar(50)) + ')'
from tempdb..TEMP_SLUCH ss
join tempdb..TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
join tempdb..TEMP_KSG_KPG ksg on (ksg.IDCASE = ss.IDCASE and ksg.SL_ID  = ss.SL_ID)
--left join [IES].[R_NSI_KSG_DS_KC] ds on ksg.N_KSG = ds.N_KSG
where ssa.USL_OK = 2 and ISnull(ksg.DKK1,'') <> (select top 1 isnull(ds.DKK,'') from [IES].[R_NSI_KSG_DS_KC] ds where ds.DKK = ksg.DKK1 and ksg.N_KSG = ds.N_KSG and ds.N_KSG is not null) and ksg.N_KSG is not null

insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DKK1', 'KSG', ss.N_ZAP, ss.IDCASE, ss.SL_ID, null, '905', 'Поле DKK1 не соответствует справочнику. (при USL_OK = 1 и DKK1 = ' + cast (ksg.DKK1 as varchar(50)) + ' и N_KSG= ' + cast (ksg.N_KSG as varchar(50)) + ')'
from tempdb..TEMP_SLUCH ss
join tempdb..TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
join tempdb..TEMP_KSG_KPG ksg on (ksg.IDCASE = ss.IDCASE and ksg.SL_ID  = ss.SL_ID)
--left join [IES].[R_NSI_KSG_KC] ds on  ksg.N_KSG = ds.N_KSG
where ssa.USL_OK = 1 and ISnull(ksg.DKK1,'') <> (select top 1 isnull(ds.DKK,'') from [IES].[R_NSI_KSG_KC] ds where ds.DKK = ksg.DKK1 and ksg.N_KSG = ds.N_KSG and ds.N_KSG is not null) and ksg.N_KSG is not null

insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'CODE_USL', 'USL', null, IDCASE,null, '905', 'Символ * в CODEUSL' 
from tempdb..TEMP_USL s
where s.CODE_USL like '%*%'

/*
-- Проверка перенесена в блок проверок ТФОМС по номером: №23.1 [28.01.2019]
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'PROFIL_K', 'SL', ss.N_ZAP, ss.IDCASE, null, '904', 'Значение поля PROFIL_K не подано для стационара и дневного стационара'
from tempdb..TEMP_SLUCH ss 
JOIN tempdb..TEMP_Z_SLUCH ssa on ssa.IDCASE = ss.IDCASE
where (ssa.USL_OK = 1 or ssa.USL_OK = 2) and ss.PROFIL_K is null and (select top 1 s.[FILENAME] from tempdb..TEMP_ZGLV s) not like 'T%'

-- Проверка перенесена в блок проверок ТФОМС по номером: №72 [28.01.2019]
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'KSG_KPG', 'SL', null, ssa.IDCASE,ss.SL_ID, null, '905', 'отсутствует КСГ при USL_OK = 1,2' 
from tempdb..TEMP_Z_SLUCH ssa
join tempdb..TEMP_SLUCH ss on ss.IDCASE = ssa.IDCASE
join tempdb..TEMP_KSG_KPG  ks on ss.IDCASE = ks.IDCASE and ss.SL_ID = ks.SL_ID
where (ssa.USL_OK = 1 or ssa.USL_OK = 2) and ks.VER_KSG is null 
*/

-- GKE [17.09.2018]: проверка обязательности заполнения полей DKK1, DKK2 для случаев с ЗАПОЛНЕННЫМ кодом КСГ
-- 27.09.2018 отключено
/*
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'DKK1', 'SLUCH', ss.IDCASE, NULL, NULL, '905', 'Для случая, оплачиваемого по КСГ, отсутствуют обязательные к заполнению реквизиты DKK1 и/или DKK2'
from tempdb..TEMP_SLUCH ss
     join tempdb..TEMP_KSG_KPG ksg on ss.IDCASE=ksg.IDCASE
  where (ksg.DKK1 IS NULL AND ksg.DKK2 IS NULL) AND (NOT ss.CODE_MES1 IS NULL)


-- 29.01.2019 перенесено в блок проверок ТФОМС
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'SUM_M', 'SL', ssa.N_ZAP, ssa.IDCASE, null, '904', 'Сумма высталенная к оплате на законченном случае SUMV не равна сумме выставленной на случаях SUM_M'
from tempdb..TEMP_Z_SLUCH ssa 
where ssa.SUMV <> (select sum(ss.SUM_M) from tempdb..TEMP_SLUCH ss where ssa.IDCASE = ss.IDCASE)
*/

insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'SUMMAP', 'SCHET', ssa.N_ZAP, ssa.IDCASE, null, '904', 'Сумма оплаты на законченном случае SUMP не равна сумме на шапке SUMMAP'
from tempdb..TEMP_Z_SLUCH ssa 
where (select SUMMAP from tempdb..TEMP_SCHET) <> (select sum(ssa.SUMP) from tempdb..TEMP_Z_SLUCH ssa)

insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'SUMP', 'Z_SL', ssa.N_ZAP, ssa.IDCASE, null, '904', 'SUMP, суммая принятая к оплате на законченоом случае должна быть больше 0 в не временных счетах'
from tempdb..TEMP_Z_SLUCH ssa 
where ssa.SUMP < 0 and @type <> '562'

insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'SUM_M', 'SL', ssa.N_ZAP, ssa.IDCASE, null, '904', 'SUM_M, Стоимость случая, выставленная к оплате на случае должна быть больше 0 в не временных счетах'
from tempdb..TEMP_SLUCH ss 
join tempdb..TEMP_Z_SLUCH ssa on ssa.idcase = ss.idcase
where ss.SUM_M < 0 and @type <> '562'

insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'SANK_IT', 'Z_SL', ssa.N_ZAP, ssa.IDCASE, null, '904', 'Сумма санкции SANK_IT не может быть больше суммы выставленной SANK_IT в не временном счете'
from tempdb..TEMP_Z_SLUCH ssa 
where ssa.SUMV < ssa.SANK_IT and @type <> '562'

--insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
--select 'SANK_IT', 'Z_SL', ssa.N_ZAP, ssa.IDCASE, null, '905', 'SANK_IT не равна сумме SANK.S_SUM' 
--from  tempdb..TEMP_Z_SLUCH ssa
----join #TEMP_SANK sank on sank.IDCASE = ssa.IDCASE
--where ssa.SANK_IT <> (select sank.S_SUM from tempdb..TEMP_SANK sank where sank.IDCASE = ssa.IDCASE)

--insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
--select 'SL_ID', 'SANK', ssa.N_ZAP, ssa.IDCASE, null, '905', 'Обязательно к заполнению, если S_SUM не равна 0' 
--from  tempdb..TEMP_Z_SLUCH ssa
--join tempdb..TEMP_SANK sank on sank.IDCASE = ssa.IDCASE
--where sank.S_SUM <> 0 and sank.SL_ID is null

--insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
--select 'SANK', 'SL_ID', z.N_ZAP, z.IDCASE, null, '905', 'Сумма санкции по SL_ID не равна сумме выставленной по случаю с такими SL_ID'
--from tempdb..TEMP_SANK s
--join tempdb..TEMP_Z_SLUCH z on z.IDCASE = s.IDCASE
--where  s.S_SUM <> (select sum(ss.SUM_M) from tempdb..TEMP_SLUCH ss where ss.IDCASE = s.IDCASE)

insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'SANK_IT', 'Z_SL', ssa.N_ZAP, ssa.IDCASE, null, '905', 'SANK_IT не равна сумме SANK.S_SUM' 
from  tempdb..TEMP_Z_SLUCH ssa
--join #TEMP_SANK sank on sank.IDCASE = ssa.IDCASE
where ssa.SANK_IT <> (select sum(sank.S_SUM)  from tempdb..TEMP_SANK sank where sank.IDCASE = ssa.IDCASE)

insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'SL_ID', 'SANK', ssa.N_ZAP, ssa.IDCASE, null, '905', 'Обязательно к заполнению, если S_SUM не равна 0' 
from  tempdb..TEMP_Z_SLUCH ssa
join  tempdb..TEMP_SANK sank on sank.IDCASE = ssa.IDCASE
where sank.S_SUM <> 0 and sank.SL_ID is null

--insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
--select 'SL_ID', 'SANK', z.N_ZAP, z.IDCASE, null, '905', 'Сумма санкции по SL_ID не равна сумме выставленной по случаю с такими SL_ID' 
--from  tempdb..TEMP_SANK_SL_ID a  
--join tempdb..TEMP_Z_SLUCH z on z.IDCASE = a.IDCASE
--where (select sum(ss.SUM_M) from tempdb..TEMP_SLUCH ss where a.IDCASE = ss.IDCASE and ss.SL_ID = a.SL_ID)<> a.S_SUM

--q015 begin
--q015 preamb begin
--declare @month int
declare @yearmonth int
declare @filename varchar(60) 
declare @q019type varchar(1)
declare @dschet date


select top 1 
@filename = [filename]
from tempdb..TEMP_ZGLV

select top 1 
@month = [month]
,@yearmonth = [year] * 100 + [month]
,@NSCHET = NSCHET
,@dschet = dschet
from tempdb..TEMP_SCHET

declare @CurrMonthYear int
set @CurrMonthYear = year(getdate()) * 100 + (month(getdate())-1)

if @type = 693
	begin
		set @q019type = (
		case
			when @filename like 'H%' then 'H'
			when @filename like 'T%' then 'T'
			when @filename like 'D%' then 'X'
			when @filename like 'C%' then 'C'
			else null
		end	
		)
	end
else if @type = 554
	begin
		set @q019type = (
		case
			when @filename like 'H%' then 'H'
			when @filename like 'T%' then 'T'
			when @filename like 'D%' then 'X'
			when @filename like 'C%' then 'C'
			else null
		end	
		)
	end
else 
begin
		set @q019type = (
		case
			when @filename like 'H%' then 'H'
			when @filename like 'T%' then 'T'
			when @filename like 'D%' then 'X'
			when @filename like 'C%' then 'C'
			else null
		end	
		)
	end
--q015 preamb end
--q015 rules begin
--000F.00.0001 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'N_ZAP', convert(varchar(36),t1.N_ZAP) as ZN_POL ,@NSCHET, 'ZAP', t1.N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '000F.00.0001'
, 'Дубль N_ZAP'
from tempdb..TEMP_ZAP t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.N_ZAP = t1.N_ZAP
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
group by t1.N_ZAP
having count(*)>1
--000F.00.0001 end

--000F.00.0002 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'IDCASE', convert(varchar(36),t0.IDCASE) as ZN_POL ,@NSCHET, 'Z_SL', null as N_ZAP, null as ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '000F.00.0002'
, 'Дубль IDCASE'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
group by IDCASE
having count(*)>1
--000F.00.0002 end

--000F.00.0003 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SL_ID', SL_ID as ZN_POL ,@NSCHET, 'SL', null as N_ZAP, null as ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '000F.00.0003'
, 'Дубль SL_ID в пределах законченного случая'
from tempdb..TEMP_SLUCH t0 with(nolock)
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
group by IDCASE, SL_ID
having count(*)>1
--000F.00.0003 end

--000F.00.0004 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'IDSERV', IDSERV as ZN_POL ,@NSCHET, 'USL', null as N_ZAP, null as ID_PAC, t1.IDCASE, t0.SL_ID, t0.IDSERV as IDSERV, '000F.00.0004'
, 'Дубль IDSERV'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
group by t1.IDCASE, t0.SL_ID, t0.IDSERV
having count(*)>1
--000F.00.0004 end

--000F.00.0005 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'S_CODE', null as ZN_POL ,'@NSCHET', 'SANK', t1.N_ZAP, null as ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV, '000F.00.0005'
, 'Дубль S_CODE в пределах законченного случая'
from tempdb..TEMP_SANK t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where @q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
group by t0.S_CODE, t0.idcase, t1.n_zap
having count(*) > 1
--000F.00.0005 end

--001F.00.0030 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CODE_MO', CODE_MO as ZN_POL ,@NSCHET, 'SCHET', null as N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '001F.00.0030', 'Значение не найдено в справочнике F003'
from tempdb..TEMP_SCHET t0 with(nolock)
left join ies.T_F003_MO t2 with(nolock) on t2.mcod = t0.CODE_MO
and t2.D_BEGIN<=@dschet and (t2.D_END is null or t2.D_END>=@dschet)
where
@q019type in ('C', 'H', 'T', 'X')
and t0.CODE_MO is not null
and t2.mcod is null
and @dschet >= convert(date,'01.11.2019',104)
--001F.00.0030 end

--001F.00.0040 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PLAT', PLAT as ZN_POL ,@NSCHET, 'SCHET', null as N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '001F.00.0040', 'Значение не найдено в справочнике F002'
from tempdb..TEMP_SCHET t0 with(nolock)
left join ies.T_F002_SMO t2 with(nolock) on t2.smocod = t0.PLAT  
where
@q019type in ('C', 'H', 'T', 'X')
and t0.PLAT is not null
and t2.smocod is null
and @dschet >= convert(date,'01.11.2019',104)
--001F.00.0040 end

--001F.00.0050 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DISP', DISP as ZN_POL ,@NSCHET, 'SCHET', null as N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '001F.00.0050'
, 'Значение не найдено в справочнике V016'
from tempdb..TEMP_SCHET t0 with(nolock)
left join ies.T_V016_DISPT t2 with(nolock) on t2.IDDT = t0.DISP
where
@q019type in ('X')
and t0.DISP is not null
and t2.IDDT is null
and @dschet >= convert(date,'01.11.2019',104)
--001F.00.0050 end

--001F.00.0060 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VPOLIS', convert(varchar(1), t0.VPOLIS) as ZN_POL ,@NSCHET, 'PACIENT', t0.N_ZAP, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '001F.00.0060', 'Значение не найдено в справочнике F008'
from tempdb..TEMP_PACIENT t0 with(nolock)
join tempdb..TEMP_ZAP t1 with(nolock) on t0.N_ZAP= t1.N_ZAP
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t0.N_ZAP
left join ies.T_F008_OMS_TYPE t2 with(nolock) on t2.IDDoc = t0.VPOLIS
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2) 
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
and t0.VPOLIS is not null
and t2.IDDoc is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0060 end

--001F.00.0070 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ST_OKATO', ST_OKATO as ZN_POL ,@NSCHET, 'PACIENT', t1.N_ZAP, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '001F.00.0070', 'Значение не найдено в справочнике F010'
from tempdb..TEMP_PACIENT t0 with(nolock)
join tempdb..TEMP_ZAP t1 with(nolock) on t0.N_ZAP= t1.N_ZAP
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t0.N_ZAP
left join ies.T_F010_SUBJECT t2 with(nolock) on t2.KOD_OKATO = t0.ST_OKATO and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and t0.ST_OKATO is not null
and t2.KOD_OKATO is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0070 end

--001F.00.0080 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SMO', SMO as ZN_POL ,@NSCHET, 'PACIENT', t0.N_ZAP, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '001F.00.0080', 'Значение не найдено в справочнике F002'
from tempdb..TEMP_PACIENT t0 with(nolock)
join tempdb..TEMP_ZAP t1 with(nolock) on t0.N_ZAP= t1.N_ZAP
left join ies.T_F002_SMO t2 with(nolock) on t2.smocod = t0.SMO 
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t0.n_zap = t3.n_zap
where
@q019type in ('C', 'H', 'T', 'X')
and t0.SMO is not null
and t2.smocod is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0080 end

--001F.00.0090 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SMO_OGRN', SMO_OGRN as ZN_POL ,@NSCHET, 'PACIENT', t0.N_ZAP, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '001F.00.0090', 'Значение не найдено в справочнике F002'
from tempdb..TEMP_PACIENT t0 with(nolock)
join tempdb..TEMP_ZAP t1 with(nolock) on t0.N_ZAP= t1.N_ZAP
left join ies.T_F002_SMO t2 with(nolock) on t2.Ogrn = t0.SMO_OGRN
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t0.n_zap = t3.n_zap
where
@q019type in ('C', 'H', 'T', 'X')
and t0.SMO_OGRN is not null
and t2.Ogrn is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0090 end

--001F.00.0100 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SMO_OK', SMO_OK as ZN_POL ,@NSCHET, 'PACIENT', t0.N_ZAP, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '001F.00.0100'
, 'Значение не найдено в справочнике F010'
from tempdb..TEMP_PACIENT t0 with(nolock)
join tempdb..TEMP_ZAP t1 with(nolock) on t0.N_ZAP= t1.N_ZAP
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t1.n_zap
left join ies.T_F010_SUBJECT t2 with(nolock) on t2.KOD_OKATO = t0.SMO_OK
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'H', 'T', 'X')
and t0.SMO_OK is not null
and t2.KOD_OKATO is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0100 end

--001F.00.0170 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VIDPOM', convert(varchar(4), t0.VIDPOM) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '001F.00.0170'
, 'Значение не найдено в справочнике V008'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
left join ies.T_V008_MEDICAL_TYPE t2 with(nolock) on t2.IDVMP = t0.VIDPOM
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and t0.VIDPOM is not null
and t2.IDVMP is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0170 end

--001F.00.0180 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'FOR_POM', convert(varchar(1), t0.FOR_POM) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '001F.00.0180'
, 'Значение не найдено в справочнике V014'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
left join ies.T_V014_MEDICAL_FORM t2 with(nolock) on t2.IDFRMMP = t0.FOR_POM
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.FOR_POM is not null
and t2.IDFRMMP is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0180 end

--001F.00.0190 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NPR_MO', NPR_MO as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '001F.00.0190', 'Значение не найдено в справочнике F003'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
left join ies.T_F003_MO t2 with(nolock) on t2.mcod = t0.NPR_MO
and t2.D_BEGIN<=t0.DATE_Z_2 and (t2.D_END is null or t2.D_END>=t0.DATE_Z_2)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.NPR_MO is not null
and t2.mcod is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0190 end

--001F.00.0200 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'LPU', LPU as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '001F.00.0200', 'Значение не найдено в справочнике F003'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
left join ies.T_F003_MO t2 with(nolock) on t2.mcod = t0.LPU
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and t0.LPU is not null
and t2.mcod is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0200 end

--001F.00.0210 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'RSLT', convert(varchar(3), t0.RSLT) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '001F.00.0210'
, 'Значение не найдено в справочнике V009'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
left join ies.T_V009_RESULT t2 with(nolock) on t2.IDRMP = t0.RSLT
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.RSLT is not null
and t2.IDRMP is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0210 end

--001F.00.0220 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ISHOD', convert(varchar(3), t0.ISHOD) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '001F.00.0220'
, 'Значение не найдено в справочнике V012'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
left join ies.T_V012_OUTCOME t2 with(nolock) on t2.IDIZ = t0.ISHOD
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.ISHOD is not null
and t2.IDIZ is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0220 end

--001F.00.0230 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'IDSP', convert(varchar(2), t0.IDSP) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '001F.00.0230'
, 'Значение не найдено в справочнике V010'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
left join ies.T_V010_PAY t2 with(nolock) on t2.IDSP = t0.IDSP
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
and t0.IDSP is not null
and t2.IDSP is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0230 end

--001F.00.0240 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'RSLT_D', convert(varchar(2), t0.RSLT_D) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '001F.00.0240'
, 'Значение не найдено в справочнике V017'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
left join ies.T_V017_DISP_RESULT t2 with(nolock) on t2.IDDR = t0.RSLT_D
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('X')
and t0.RSLT_D is not null
and t2.IDDR is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0240 end

--001F.00.0250 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VID_HMP', VID_HMP as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0250', 'Значение не найдено в справочнике V018'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.idcase
left join ies.T_V018_VMP_TYPE t2 with(nolock) on t2.IDHVID = t0.VID_HMP
and t2.DATEBEG<=DATE_Z_2 and (t2.DATEEND is null or t2.DATEEND>=DATE_Z_2)
left join ies.T_V018_VMP_TYPE_PREV t3 with(nolock) on t3.V018VmpType= t0.VID_HMP
and t3.DATEBEG<=DATE_Z_2 and (t3.DATEEND is null or t3.DATEEND>=DATE_Z_2)
where
@q019type in ('D', 'R', 'T')
and t0.VID_HMP is not null
and t2.IDHVID is null
and t3.V018VmpType is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0250 end

--001F.00.0260 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'METOD_HMP', convert(varchar(3), t0.METOD_HMP) as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0260', 'Значение не найдено в справочнике V019. С 2021 вычисляется на основе VID_HMP, SUM_M, METOD_HMP'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.idcase = t1.idcase
outer apply (
select top 1 t100.V019VmpMethodID
from ies.T_V019_VMP_METHOD t100
left join ies.R_NSI_HGR_TARIF t101 on t101.tarif = t0.sum_m
where t100.IDHM = t0.METOD_HMP
and t100.DATEBEG<=DATE_Z_2 and (t100.DATEEND is null or t100.DATEEND>=DATE_Z_2)
and (
	t1.DATE_Z_2 < convert(date,'01.01.2021',104)
	or
	(
		t0.vid_hmp = t100.HVID
		and isnull(t101.hgr,-1) = isnull(t100.HGR,-2)
	)
)
)t2
where
@q019type in ('D', 'R', 'T')
and t0.METOD_HMP is not null
and t2.V019VmpMethodID is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0260 end

--001F.00.0270 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PROFIL', convert(varchar(3), t0.PROFIL) as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0270', 'Значение не найдено в справочнике V002'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.idcase = t1.idcase
left join ies.T_V002_PROFILE t2 with(nolock) on t2.IDPR = t0.PROFIL
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.PROFIL is not null
and t2.IDPR is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0270 end

--001F.00.0280 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PROFIL_K', convert(varchar(3), t0.PROFIL_K) as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0280', 'Значение не найдено в справочнике V020'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.idcase = t1.idcase
left join ies.T_V020_BED_PROFILE t2 with(nolock) on t2.IDK_PR = t0.PROFIL_K
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.PROFIL_K is not null
and t2.IDK_PR is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0280 end

--001F.00.0290 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'P_CEL', P_CEL as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0290', 'Значение не найдено в справочнике V025'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.idcase = t1.idcase
left join ies.T_V025_KPC t2 with(nolock) on t2.IDPC = t0.P_CEL
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'H', 'R')
and t0.P_CEL is not null
and t2.IDPC is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0290 end

--001F.00.0300 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'C_ZAB', convert(varchar(1), t0.C_ZAB) as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0300', 'Значение не найдено в справочнике V027'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.idcase = t1.idcase
left join ies.T_V027_C_ZAB t2 with(nolock) on t2.IDCZ = t0.C_ZAB
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.C_ZAB is not null
and t2.IDCZ is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0300 end

--001F.00.0310 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PRVS', convert(varchar(4), t0.PRVS) as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0310', 'Значение не найдено в справочнике V021'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.idcase = t1.idcase
left join ies.T_V021_MED_SPEC t2 with(nolock) on t2.CODE_SPEC = t0.PRVS
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.PRVS is not null
and t2.CODE_SPEC is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0310 end

--001F.00.0320 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAZ_SP', convert(varchar(4), t0.NAZ_SP) as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0320'
, 'Значение не найдено в справочнике V021'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_V021_MED_SPEC t2 with(nolock) on t2.CODE_SPEC = t0.NAZ_SP
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('X')
and t0.NAZ_SP is not null
and t2.CODE_SPEC is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0320 end

--001F.00.0330 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAZ_PMP', convert(varchar(3), t0.NAZ_PMP) as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0330'
, 'Значение не найдено в справочнике V002'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_V002_PROFILE t2 with(nolock) on t2.IDPR = t0.NAZ_PMP
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('X')
and t0.NAZ_PMP is not null
and t2.IDPR is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0330 end

--001F.00.0340 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAZ_PK', convert(varchar(3), t0.NAZ_PK) as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0340'
, 'Значение не найдено в справочнике V020'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_V020_BED_PROFILE t2 with(nolock) on t2.IDK_PR = t0.NAZ_PK
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('X')
and t0.NAZ_PK is not null
and t2.IDK_PR is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0340 end

--001F.00.0350 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAZ_V', convert(varchar(1), t0.NAZ_V) as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0350'
, 'Значение не найдено в справочнике V029'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_V029_MET_ISSL t2 with(nolock) on t2.IDMET = t0.NAZ_V
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('X')
and t0.NAZ_V is not null
and t2.IDMET is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0350 end

--001F.00.0360 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAPR_MO', NAPR_MO as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0360', 'Значение не найдено в справочнике F003'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE

left join ies.T_F003_MO t2 with(nolock) on t2.mcod = t0.NAPR_MO
where
@q019type in ('X')
and t0.NAPR_MO is not null
and t2.mcod is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0360 end

--001F.00.0370 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAPR_MO', NAPR_MO as ZN_POL ,@NSCHET, 'NAPR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0370', 'Значение не найдено в справочнике F003'
from tempdb..TEMP_NAPR t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_F003_MO t2 with(nolock) on t2.mcod = t0.NAPR_MO 
and t2.D_BEGIN<=t1.DATE_Z_2 and (t2.D_END is null or t2.D_END>=t1.DATE_Z_2)
where
@q019type in ('C', 'D', 'R', 'T')
and t0.NAPR_MO is not null
and t2.mcod is null

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0370 end

--001F.00.0380 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAPR_V', convert(varchar(2), t0.NAPR_V) as ZN_POL ,@NSCHET, 'NAPR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0380'
, 'Значение не найдено в справочнике V028'
from tempdb..TEMP_NAPR t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_V028_NAPR_V t2 with(nolock) on t2.IDVN = t0.NAPR_V
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'R', 'T')
and t0.NAPR_V is not null
and t2.IDVN is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0380 end

--001F.00.0390 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'MET_ISSL', convert(varchar(2), t0.MET_ISSL) as ZN_POL ,@NSCHET, 'NAPR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0390'
, 'Значение не найдено в справочнике V029'
from tempdb..TEMP_NAPR t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_V029_MET_ISSL t2 with(nolock) on t2.IDMET = t0.MET_ISSL
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'R', 'T')
and t0.MET_ISSL is not null
and t2.IDMET is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0390 end

--001F.00.0400 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PR_CONS', convert(varchar(1), t0.PR_CONS) as ZN_POL ,@NSCHET, 'CONS', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0400'
, 'Значение не найдено в справочнике N019'
from tempdb..TEMP_CONS t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_N019_ONK_CONS t2 with(nolock) on t2.ID_CONS = t0.PR_CONS
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'R', 'T')
and t0.PR_CONS is not null
and t2.ID_CONS is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0400 end

--001F.00.0410 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DS1_T', convert(varchar(2), t0.DS1_T) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0410'
, 'Значение не найдено в справочнике N018'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_N018_ONK_REAS t2 with(nolock) on t2.ID_REAS = t0.DS1_T
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'R', 'T')
and t0.DS1_T is not null
and t2.ID_REAS is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0410 end

--001F.00.0420 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'STAD', convert(varchar(3), t0.STAD) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0420'
, 'Значение не найдено в справочнике N002'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_N002_STADIUM t2 with(nolock) on t2.ID_St = t0.STAD
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'R', 'T')
and t0.STAD is not null
and t2.ID_St is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0420 end

--001F.00.0430 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_T', convert(varchar(4), t0.ONK_T) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0430'
, 'Значение не найдено в справочнике N003'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_N003_TUMOR t2 with(nolock) on t2.ID_T = t0.ONK_T
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'R', 'T')
and t0.ONK_T is not null
and t2.ID_T is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0430 end

--001F.00.0440 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_N', convert(varchar(4), t0.ONK_N) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0440'
, 'Значение не найдено в справочнике N004'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_N004_NODUS t2 with(nolock) on t2.ID_N = t0.ONK_N
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'R', 'T')
and t0.ONK_N is not null
and t2.ID_N is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0440 end

--001F.00.0450 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_M', convert(varchar(4), t0.ONK_M) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0450'
, 'Значение не найдено в справочнике N005'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_N005_METASTASIS t2 with(nolock) on t2.ID_M = t0.ONK_M
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'R', 'T')
and t0.ONK_M is not null
and t2.ID_M is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0450 end

--001F.00.0460 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DIAG_CODE', convert(varchar(3), t0.DIAG_CODE) as ZN_POL ,@NSCHET, 'B_DIAG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0460'
, 'Значение не найдено в справочнике N007'
from tempdb..TEMP_B_DIAG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_N007_MRF t2 with(nolock) on t2.ID_Mrf = t0.DIAG_CODE
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'R', 'T')
and DIAG_TIP=1
and t2.ID_Mrf is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0460 end

--001F.00.0470 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DIAG_CODE', convert(varchar(3), t0.DIAG_CODE) as ZN_POL ,@NSCHET, 'B_DIAG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0470'
, 'Значение не найдено в справочнике N010'
from tempdb..TEMP_B_DIAG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_N010_MARK t2 with(nolock) on t2.ID_Igh = t0.DIAG_CODE
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'R', 'T')
and DIAG_TIP=2
and t2.ID_Igh is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0470 end

--001F.00.0480 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DIAG_RSLT', convert(varchar(3), t0.DIAG_RSLT) as ZN_POL ,@NSCHET, 'B_DIAG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0480', 'Значение не найдено в справочнике N008'
from tempdb..TEMP_B_DIAG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_N008_MRF_RT t2 with(nolock) on t2.ID_R_M = t0.DIAG_RSLT
and ((DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)) or t0.DIAG_DATE < '01.09.2018')
where
@q019type in ('C', 'D', 'R', 'T')
and DIAG_TIP=1
and t0.DIAG_RSLT is not null
and t2.ID_R_M is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0480 end

--001F.00.0490 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DIAG_RSLT', convert(varchar(3), t0.DIAG_RSLT) as ZN_POL ,@NSCHET, 'B_DIAG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0490', 'Значение не найдено в справочнике N011'
from tempdb..TEMP_B_DIAG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_N011_MARK_VALUE t2 with(nolock) on t2.ID_R_I = t0.DIAG_RSLT
and ((DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)) or t0.DIAG_DATE < '01.09.2018')
where
@q019type in ('C', 'D', 'R', 'T')
and DIAG_TIP=2
and t2.ID_R_I is null
and t0.DIAG_RSLT is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0490 end

--001F.00.0500 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PROT', convert(varchar(1), t0.PROT) as ZN_POL ,@NSCHET, 'B_PROT', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0500'
, 'Значение не найдено в справочнике N001'
from tempdb..TEMP_B_PROT t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_N001_PrOt t2 with(nolock) on t2.ID_PrOt = t0.PROT
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'R', 'T')
and t0.PROT is not null
and t2.ID_PrOt is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0500 end

--001F.00.0510 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'USL_TIP', convert(varchar(1), t0.USL_TIP) as ZN_POL ,@NSCHET, 'ONK_USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0510', 'Значение не найдено в справочнике N013'
from tempdb..TEMP_ONK_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_N013_TREAT_TYPE t2 with(nolock) on t2.ID_TLech = t0.USL_TIP
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2) 
where
@q019type in ('C', 'D', 'R', 'T')
and t0.USL_TIP is not null
and t2.ID_TLech is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0510 end

--001F.00.0520 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'HIR_TIP', convert(varchar(1), t0.HIR_TIP) as ZN_POL ,@NSCHET, 'ONK_USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0520'
, 'Значение не найдено в справочнике N014'
from tempdb..TEMP_ONK_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_N014_SURG_TREAT t2 with(nolock) on t2.ID_THir = t0.HIR_TIP
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'R', 'T')
and t0.HIR_TIP is not null
and t2.ID_THir is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0520 end

--001F.00.0530 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'LEK_TIP_L', convert(varchar(1), t0.LEK_TIP_L) as ZN_POL ,@NSCHET, 'ONK_USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0530'
, 'Значение не найдено в справочнике N015'
from tempdb..TEMP_ONK_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_N015_DRUG_THERAPY_LINES t2 with(nolock) on t2.ID_TLek_L = t0.LEK_TIP_L
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'R', 'T')
and t0.LEK_TIP_L is not null
and t2.ID_TLek_L is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0530 end

--001F.00.0540 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'LEK_TIP_V', convert(varchar(1), t0.LEK_TIP_V) as ZN_POL ,@NSCHET, 'ONK_USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0540'
, 'Значение не найдено в справочнике N016'
from tempdb..TEMP_ONK_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_N016_DRUG_THERAPY_CYCLES t2 with(nolock) on t2.ID_TLek_V = t0.LEK_TIP_V
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'R', 'T')
and t0.LEK_TIP_V is not null
and t2.ID_TLek_V is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0540 end

--001F.00.0550 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'LUCH_TIP', convert(varchar(1), t0.LUCH_TIP) as ZN_POL ,@NSCHET, 'ONK_USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0550'
, 'Значение не найдено в справочнике N017'
from tempdb..TEMP_ONK_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_N017_RADIATION_THERAPY_TYPES t2 with(nolock) on t2.ID_TLuch = t0.LUCH_TIP
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'R', 'T')
and t0.LUCH_TIP is not null
and t2.ID_TLuch is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0550 end

--001F.00.0560 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'REGNUM', REGNUM as ZN_POL ,@NSCHET, 'LEK_PR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0560'
, 'Значение не найдено в справочнике N020'
from tempdb..TEMP_LEK_PR_DATE_INJ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_N020_ONK_LEKP t2 with(nolock) on t2.ID_LEKP = t0.REGNUM
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'R', 'T')
and t0.REGNUM is not null
and t2.ID_LEKP is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0560 end

--001F.00.0570 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CODE_SH', CODE_SH as ZN_POL ,@NSCHET, 'LEK_PR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0570', 'Значение не найдено в справочнике V024'
from tempdb..TEMP_LEK_PR_DATE_INJ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_PERS t2 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t2.ID_PAC)
join tempdb..TEMP_SLUCH t3 with(nolock) on t3.sl_id = t0.sl_id and t3.idcase = t0.idcase
left join ies.T_V024_DOP_KR t4 with(nolock) on t4.IDDKK = t0.CODE_SH and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2) 
where
@q019type in ('C', 'D', 'R', 'T')
and t0.CODE_SH is not null
and dbo.DateTimeDiff('year',dr,date_z_2) >= 18
and ((t3.ds1 >= 'C00' and t3.ds1 < 'C81') or t3.ds1 like 'C97%' or t3.ds1 like 'D0%')
and t4.IDDKK is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--001F.00.0570 end

--001F.00.0571 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CODE_SH', CODE_SH as ZN_POL ,@NSCHET, 'LEK_PR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0571', 'Значение не найдено в справочнике V024'
from tempdb..TEMP_LEK_PR_DATE_INJ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_PERS t2 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t2.ID_PAC)
join tempdb..TEMP_SLUCH t3 with(nolock) on t3.sl_id = t0.sl_id and t3.idcase = t0.idcase
left join ies.T_V024_DOP_KR t4 with(nolock) on t4.IDDKK = t0.CODE_SH and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
left join tempdb..TEMP_ONK_USL t5 on t5.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and t0.CODE_SH is not null
and dbo.DateTimeDiff('year',dr,date_z_2) >= 18
and t4.IDDKK is null
and (
	(t3.ds1 >= 'C00' and t3.ds1 < 'C81')
	or (t3.ds1 >= 'C81' and t3.ds1 < 'C97' and t5.USL_TIP = 2) 
	or (t3.ds1 >= 'C96' and t3.ds1 < 'C99')
	or t3.ds1 like 'C97%' 
	or t3.ds1 like 'D0%'
	or (t3.ds1 >= 'D45' and t3.ds1 < 'D48' and t5.USL_TIP = 2) 
)
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--001F.00.0571 end

--001F.00.0580 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'N_KSG', t0.N_KSG as ZN_POL ,@NSCHET, 'KSG_KPG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0580'
, 'Значение не найдено в справочнике V023'
from tempdb..TEMP_KSG_KPG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_V023_KSG t2 with(nolock) on t2.K_KSG = t0.N_KSG
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'H', 'R')
and KSG_PG=0
and t0.N_KSG is not null
and t2.K_KSG is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0580 end

--001F.00.0590 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'N_KPG', t0.N_KPG as ZN_POL ,@NSCHET, 'KSG_KPG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0590'
, 'Значение не найдено в справочнике V026'
from tempdb..TEMP_KSG_KPG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_V026_KPG t2 with(nolock) on t2.K_KPG = t0.N_KPG
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'H', 'R')
and t0.N_KPG is not null
and t2.K_KPG is null

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0590 end

--001F.00.0600 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'KOEF_Z', convert(varchar, cast(t0.KOEF_Z as money)) as ZN_POL ,@NSCHET, 'KSG_KPG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0600'
, 'Значение KOEF_Z должно совпадать со значением V023.KOEF_Z записи, соответствующей номеру КСГ'
from tempdb..TEMP_KSG_KPG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_V023_KSG t2 with(nolock) on t2.KOEF_Z = t0.KOEF_Z and t0.n_ksg =t2.k_ksg
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'H', 'R')
and KSG_PG=0
and t2.v023ksgid is null
and t0.n_ksg is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0600 end

--001F.00.0610 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CRIT', CRIT as ZN_POL ,@NSCHET, 'KSG_KPG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0610'
, 'Значение не найдено в справочнике V024'
from tempdb..TEMP_CRIT t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_V024_DOP_KR t2 with(nolock) on t2.IDDKK = t0.CRIT
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2) 
join tempdb..TEMP_KSG_KPG t3 on t1.IDCASE = t3.IDCASE
where
@q019type in ('C', 'D', 'H', 'R')
and KSG_PG=0
and t0.CRIT is not null
and t2.IDDKK is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0610 end

--001F.00.0620 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'LPU', t0.LPU as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0620', 'Значение не найдено в справочнике F003'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE

left join ies.T_F003_MO t2 with(nolock) on t2.mcod = t0.LPU  
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and t0.LPU is not null
and t2.mcod is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0620 end

--001F.00.0630 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PROFIL', convert(varchar(3), t0.PROFIL) as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0630'
, 'Значение не найдено в справочнике V002'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_V002_PROFILE t2 with(nolock) on t2.IDPR = t0.PROFIL
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.PROFIL is not null
and t2.IDPR is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0630 end

--001F.00.0640 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VID_VME', VID_VME as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0640'
, 'Значение не найдено в справочнике V019'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_V019_VMP_METHOD t2 with(nolock) on convert(varchar,t2.IDHM) = t0.VID_VME
and t2.DATEBEG<=DATE_Z_2 and (t2.DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('T')
and t0.VID_VME is not null
and t2.V019VmpMethodId is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0640 end

--001F.00.0660 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PRVS', convert(varchar(4), t0.PRVS) as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0660'
, 'Значение не найдено в справочнике V021'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_V021_MED_SPEC t2 with(nolock) on t2.CODE_SPEC = t0.PRVS
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and t0.PRVS is not null
and t2.CODE_SPEC is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'31.03.2020',104)
--001F.00.0660 end

--001F.00.0661 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PRVS', convert(varchar(4), t0.PRVS) as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0661'
, 'Значение не найдено в справочнике V021'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_V021_MED_SPEC t2 with(nolock) on t2.CODE_SPEC = t0.PRVS
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and t0.PRVS is not null
and t2.CODE_SPEC is null
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--001F.00.0661 end

--001F.00.0662 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PRVS', convert(varchar(4), t0.PRVS) as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0662'
, 'Значение не найдено в справочнике V021'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_V021_MED_SPEC t2 with(nolock) on t2.CODE_SPEC = t0.PRVS
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('X')
and t0.PRVS is not null
and t2.CODE_SPEC is null
and t0.P_OTK=0

and DATE_Z_2 >= convert(date,'01.04.2020',104)
--001F.00.0662 end

--001F.00.0670 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'S_TIP', convert(varchar(2), t0.S_TIP) as ZN_POL ,@NSCHET, 'SANK', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0670'
, 'Значение не найдено в справочнике F006'
from tempdb..TEMP_SANK t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_F006_CONTROL_TYPE t2 with(nolock) on t2.IDVID = t0.S_TIP
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
and t0.S_TIP is not null
and t2.IDVID is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0670 end

--001F.00.0680 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'S_OSN', convert(varchar(3), t0.S_OSN) as ZN_POL ,@NSCHET, 'SANK', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0680'
, 'Значение не найдено в справочнике F014'
from tempdb..TEMP_SANK t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_F014_DENY_REASON t2 with(nolock) on t2.Kod = t0.S_OSN
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
and S_OSN is not null
and t2.Kod is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0680 end

--001F.00.0720 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DOCTYPE', DOCTYPE as ZN_POL ,@NSCHET, 'PERS', null, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '001F.00.0720'
, 'Значение не найдено в справочнике F011'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_PACIENT t1 with(nolock) on convert(varchar(36),t0.ID_PAC) = convert(varchar(36),t1.ID_PAC)
join tempdb..TEMP_ZAP t2 with(nolock) on t1.N_ZAP= t2.N_ZAP 
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t1.n_zap
left join ies.T_F011_DOCUMENT_TYPE t4 with(nolock) on t4.IDDoc = t0.DOCTYPE
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
t0.DOCTYPE is not null
and t4.IDDoc is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0720 end

--001F.00.0730 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'OKATOG', OKATOG as ZN_POL ,@NSCHET, 'PERS', null as N_ZAP, t0.ID_PAC as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '001F.00.0730', 'Значение не найдено в справочнике O002'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_PACIENT t1 with(nolock) on convert(varchar(36),t0.ID_PAC)= convert(varchar(36),t1.ID_PAC)
join tempdb..TEMP_ZAP t2 with(nolock) on t2.N_ZAP= t1.N_ZAP
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t1.n_zap
left join ies.T_O002_OKATO t4 with(nolock) on t4.CODE = t0.OKATOG  
where
t0.OKATOG is not null
and t4.CODE is null
--ВНИМАНИЕ ПРОВЕРЬ НАЛИЧИЕ индекса на T_002_OKATO.Code
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0730 end

--001F.00.0740 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'OKATOP', OKATOP as ZN_POL ,@NSCHET, 'PERS', null as N_ZAP, t0.ID_PAC as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '001F.00.0740', 'Значение не найдено в справочнике O002'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_PACIENT t1 with(nolock) on convert(varchar(36),t0.ID_PAC)= convert(varchar(36),t1.ID_PAC)
join tempdb..TEMP_ZAP t2 with(nolock) on t2.N_ZAP= t1.N_ZAP
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t1.n_zap
left join ies.T_O002_OKATO t4 with(nolock) on t4.CODE = t0.OKATOP
where
t0.OKATOP is not null
and t4.CODE is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--001F.00.0740 end

--002F.00.0080 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PR_NOV', convert(varchar(1), t0.PR_NOV) as ZN_POL ,@NSCHET, 'ZAP', t0.N_ZAP, t1.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '002F.00.0080'
, 'Поле PR_NOV имеет недопустимое значение'
from tempdb..TEMP_ZAP t0 with(nolock)
join tempdb..TEMP_PACIENT t1 with(nolock) on t0.N_ZAP= t1.N_ZAP
join tempdb..TEMP_Z_SLUCH t2 with(nolock) on t0.n_zap = t2.n_zap
where
@q019type in ('C', 'H', 'T', 'X')
and t0.PR_NOV not in (0, 1)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0080 end

--002F.00.0130 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NOVOR', t0.NOVOR as ZN_POL ,@NSCHET, 'PACIENT', t0.N_ZAP, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '002F.00.0130'
, 'Поле NOVOR имеет недопустимое значение'
from tempdb..TEMP_PACIENT t0 with(nolock)
join tempdb..TEMP_ZAP t1 with(nolock) on t0.N_ZAP= t1.N_ZAP
join tempdb..TEMP_Z_SLUCH t2 with(nolock) on t0.n_zap = t2.n_zap
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and t0.NOVOR != '0'
and [dbo].[RegExMatch](t0.NOVOR,'^[12](([012][0-9])|(3[01]))((1[0-2])|(0[1-9]))(1[89]|[23][0-9])((0{0,1}[1-9])|10)$') != 1
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0130 end

--002F.00.0140 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VNOV_D', convert(varchar(4), t0.VNOV_D) as ZN_POL ,@NSCHET, 'PACIENT', t0.N_ZAP, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '002F.00.0140'
, 'Поле VNOV_D имеет недопустимое значение (300<VNOV_D<2500)'
from tempdb..TEMP_PACIENT t0 with(nolock)
join tempdb..TEMP_ZAP t1 with(nolock) on t0.N_ZAP= t1.N_ZAP
join tempdb..TEMP_Z_SLUCH t2 with(nolock) on t0.n_zap = t2.n_zap
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and not (300<VNOV_D and VNOV_D<2500)
and VNOV_D is not null


and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0140 end

--002F.00.0150 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VNOV_M', convert(varchar(4), t0.VNOV_M) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '002F.00.0150'
, 'Поле VNOV_M имеет недопустимое значение (300<VNOV_M<2500)'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and not (300<VNOV_M and VNOV_M<2500)
and VNOV_M is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0150 end

--002F.00.0160 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'OS_SLUCH', convert(varchar(1), t0.OS_SLUCH) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '002F.00.0160'
, 'Поле OS_SLUCH имеет недопустимое значение'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and isnull(t0.OS_SLUCH,1) not in ('1','2')
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0160 end

--002F.00.0180 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'OPLATA', convert(varchar(1), t0.OPLATA) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '002F.00.0180'
, 'Поле OPLATA имеет недопустимое значение'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
and 
(
	(isnull(t0.OPLATA, -1) not in (0, 1, 2, 3) and @q019type in ('A'))
	or 
	(isnull(t0.OPLATA, 0) not in (0, 1, 2, 3) and @q019type in ('C', 'D', 'H', 'R', 'T', 'X'))
)

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0180 end

--002F.00.0190 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VBR', convert(varchar(1), t0.VBR) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '002F.00.0190'
, 'Поле VBR имеет недопустимое значение'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('X')
and not (t0.VBR in (0, 1))
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0190 end

--002F.00.0200 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'P_OTK', convert(varchar(1), t0.P_OTK) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '002F.00.0200'
, 'Поле P_OTK имеет недопустимое значение'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('X')
and not (t0.P_OTK in (0,1))
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0200 end

--002F.00.0220 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DET', convert(varchar(1), t0.DET) as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '002F.00.0220'
, 'Поле DET имеет недопустимое значение'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t1.n_zap = t0.n_zap
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and not (DET in (0,1))
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0220 end

--002F.00.0250 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DS_ONK', convert(varchar(1), t0.DS_ONK) as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '002F.00.0250'
, 'Поле DS_ONK имеет недопустимое значение'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t1.n_zap = t0.n_zap
where
@q019type in ('C', 'D', 'R', 'T', 'X')
and not ( t0.DS_ONK in (0,1) )
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0250 end

--002F.00.0260 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DS1', DS1 as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '002F.00.0260'
, 'Данный случай должен отсутствовать в этом типе реестров'
FROM tempdb..TEMP_SLUCH t0 WITH (NOLOCK)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t1.n_zap = t0.n_zap
WHERE @q019type IN ('H')
	AND (
		DS1 LIKE 'C%'
		OR DS1 LIKE 'D0%'
		OR (
			DS1 = 'D70'
			AND EXISTS (
							SELECT TOP 1 1
							FROM tempdb..TEMP_DS2 t1
							WHERE (
									(
										DS2 >= 'C00'
										AND DS2 < 'C81'
									)
									OR DS2 LIKE 'c97%'
								)
								AND t1.SL_ID = t0.SL_ID
								AND t1.IDCASE = t0.IDCASE
				)
			)
		)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0260 end

--002F.00.0310 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PR_D_N', convert(varchar(1), t0.PR_D_N) as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '002F.00.0310'
, 'Поле PR_D_N имеет недопустимое значение'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t1.n_zap = t0.n_zap
where
@q019type in ('X')
and not( isnull(PR_D_N,0) in(1, 2, 3) )
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0310 end

--002F.00.0320 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VERS_SPEC', VERS_SPEC as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '002F.00.0320'
, 'Текущий справочник мед. специальностей - V021'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t1.n_zap = t0.n_zap
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and VERS_SPEC != 'V021'
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0320 end

--002F.00.0330 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DS2_PR', convert(varchar(1), t0.DS2_PR) as ZN_POL ,@NSCHET, 'DS2_N', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '002F.00.0330'
, 'Поле DS2_PR имеет недопустимое значение'
from tempdb..TEMP_DS2_N t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('X')
and not (isnull(t0.DS2_PR,1) = 1)

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0330 end

--002F.00.0340 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PR_DS2_N', convert(varchar(1), t0.PR_DS2_N) as ZN_POL ,@NSCHET, 'DS2_N', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '002F.00.0340'
, 'Поле PR_DS2_N имеет недопустимое значение'
from tempdb..TEMP_DS2_N t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('X')
and not (isnull(t0.PR_DS2_N,0) in (1, 2, 3))
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0340 end

--002F.00.0350 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAZ_R', convert(varchar(2), t0.NAZ_R) as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '002F.00.0350'
, 'Поле NAZ_R имеет недопустимое значение'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('X')
and not
(
 isnull(t0.NAZ_R,0) in (1, 2, 3, 4, 5, 6)
)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0350 end

--002F.00.0360 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'MTSTZ', convert(varchar(1), t0.MTSTZ) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '002F.00.0360'
, 'Поле MTSTZ имеет недопустимое значение'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and MTSTZ is not null
and MTSTZ != 1
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0360 end

--002F.00.0370 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'WEI', convert(varchar, cast(t0.WEI as money)) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '002F.00.0370'
, 'Поле WEI имеет недопустимое значение'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and WEI is not null
and WEI >= 500

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0370 end

--002F.00.0380 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'HEI', convert(varchar(3), t0.HEI) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '002F.00.0380'
, 'Поле HEI имеет недопустимое значение'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and HEI is not null
and HEI >= 260

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0380 end

--002F.00.0390 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'BSA', convert(varchar, cast(t0.BSA as money)) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '002F.00.0390'
, 'Поле BSA имеет недопустимое значение'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and BSA is not null
and BSA >= 6

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0390 end

--002F.00.0400 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DIAG_TIP', convert(varchar(1), t0.DIAG_TIP) as ZN_POL ,@NSCHET, 'B_DIAG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '002F.00.0400'
, 'Поле DIAG_TIP имеет недопустимое значение'
from tempdb..TEMP_B_DIAG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and not (DIAG_TIP in (1,2))


and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0400 end

--002F.00.0410 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'REC_RSLT', convert(varchar(1), t0.REC_RSLT) as ZN_POL ,@NSCHET, 'B_DIAG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '002F.00.0410'
, 'Поле REC_RSLT имеет недопустимое значение'
from tempdb..TEMP_B_DIAG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and REC_RSLT is not null
and REC_RSLT != 1
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0410 end

--002F.00.0420 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PPTR', convert(varchar(1), t0.PPTR) as ZN_POL ,@NSCHET, 'ONK_USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '002F.00.0420'
, 'Поле PPTR имеет недопустимое значение'
from tempdb..TEMP_ONK_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and PPTR is not null
and PPTR != 1
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0420 end

--002F.00.0430 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CODE_SH', CODE_SH as ZN_POL ,@NSCHET, 'LEK_PR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '002F.00.0430'
, 'CODE_SH должно содержать значение НЕТ'
from tempdb..TEMP_LEK_PR_DATE_INJ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_PERS t2 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t2.ID_PAC)
join tempdb..TEMP_SLUCH t3 with(nolock) on t3.sl_id = t0.sl_id and t3.idcase = t0.idcase
where
@q019type in ('C', 'D', 'R', 'T')
and t0.CODE_SH != 'нет'
and (dbo.DateTimeDiff('year',dr,date_z_1) < 18 or  (t3.ds1 >= 'C81' and t3.ds1 < 'C97'))
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--002F.00.0430 end

--002F.00.0431 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CODE_SH', CODE_SH as ZN_POL ,@NSCHET, 'LEK_PR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0571'
, 'Пул значений: нет'
from tempdb..TEMP_LEK_PR_DATE_INJ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_PERS t2 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t2.ID_PAC)
join tempdb..TEMP_SLUCH t3 with(nolock) on t3.sl_id = t0.sl_id and t3.idcase = t0.idcase
left join tempdb..TEMP_ONK_USL t5 on t5.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and isnull(t0.CODE_SH,'') != 'нет'
and dbo.DateTimeDiff('year',dr,date_z_1) < 18
and t5.USL_TIP > 4
and (
	(t3.ds1 >= 'C81' and t3.ds1 < 'C97') 
	or (t3.ds1 >= 'D45' and t3.ds1 < 'D48') 	
)
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--002F.00.0431 end

--002F.00.0480 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'S_IST', convert(varchar(1), t0.S_IST) as ZN_POL ,@NSCHET, 'SANK', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '002F.00.0480'
, 'Поле S_IST имеет недопустимое значение'
from tempdb..TEMP_SANK t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE

where
@q019type in ('C', 'H', 'T', 'X')
and isnull(t0.S_IST,0) != 1
and @type = 693
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0480 end

--002F.00.0510 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DET', convert(varchar(1), t0.DET) as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '002F.00.0510'
, 'Поле DET имеет недопустимое значение'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and DET is not null
and not (DET in (0,1))
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0510 end

--002F.00.0530 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'P_OTK', convert(varchar(1), t0.P_OTK) as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '002F.00.0530'
, 'Поле P_OTK имеет недопустимое значение'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('X')
and not
(
 isnull(t0.P_OTK,-1) in (0, 1)
)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--002F.00.0530 end

--003F.00.0020 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SUMMAP', convert(varchar, cast(t0.SUMMAP as money)) as ZN_POL ,@NSCHET, 'SCHET', null as N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.0020'
, 'Не заполнено поле SUMMAP'
from tempdb..TEMP_SCHET t0 with(nolock)
where
@q019type in ('C', 'H', 'T', 'X')
and t0.SUMMAP is null
and @type = 693
and @isMoToSmo = 0
and @dschet >= convert(date,'01.11.2019',104)
--003F.00.0020 end

--003F.00.0030 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SANK_MEK', convert(varchar, cast(t0.SANK_MEK as money)) as ZN_POL ,@NSCHET, 'SCHET', null as N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.0030'
, 'Поле SANK_MEK заполнено при отсутствии санкций'
from tempdb..TEMP_SCHET t0 with(nolock)
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
and isnull(t0.SANK_MEK,0) <=0
and exists (select top 1 1 from tempdb..TEMP_SANK where S_TIP in (1, 10,11,12) and isnull(S_SUM,0)<>0 and S_IST=1)

and @dschet >= convert(date,'01.11.2019',104)
--003F.00.0030 end

--003F.00.0040 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SANK_MEE', convert(varchar, cast(t0.SANK_MEE as money)) as ZN_POL ,@NSCHET, 'SCHET', null as N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.0040'
, 'Поле SANK_MEE заполнено при отсутствии санкции МЭЭ'
from tempdb..TEMP_SCHET t0 with(nolock)
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
and isnull(t0.SANK_MEE,0) <=0
and exists (select top 1 1 from tempdb..TEMP_SANK where S_TIP>19 and S_TIP<30 and isnull(S_SUM,0)<>0 and S_IST=1)
and @dschet >= convert(date,'01.11.2019',104)
--003F.00.0040 end

--003F.00.0050 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SANK_EKMP', convert(varchar, cast(t0.SANK_EKMP as money)) as ZN_POL ,@NSCHET, 'SCHET', null as N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.0050'
, 'Поле SANK_EKMP заполнено при отсутствии санкций ЭКМП'
from tempdb..TEMP_SCHET t0 with(nolock)
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
and isnull(t0.SANK_EKMP,0) <=0
and exists (select top 1 1 from tempdb..TEMP_SANK where S_TIP>29 and S_TIP<49 and isnull(S_SUM,0)<>0 and S_IST=1)
and @dschet >= convert(date,'01.11.2019',104)
--003F.00.0050 end

--003F.00.0060 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'Z_SL', null as ZN_POL ,@NSCHET, 'ZAP', t0.N_ZAP, t0.ID_PAC, t0.idcase as IDCASE, null as SL_ID, null as IDSERV, '003F.00.0060'
, 'Зак. случай не может быть включен в этот тип реестров счетов'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C')
and not exists
(
	select top 1 1
	from tempdb..TEMP_SLUCH t1 with(nolock) 
	where t0.idcase = t1.idcase
	and
	(isnull(DS_ONK,0) = 1
	or DS1 like 'C%'  
	or DS1 like 'D0%'  
	or (
			DS1 = 'D70'
			and exists ( 
							select top 1 1 
							from tempdb..TEMP_DS2 t2
							where((DS2>='C00' and DS2<'C81') or DS2 like 'C97%')
							and t2.SL_ID = t1.SL_ID
							and t2.IDCASE= t1.IDCASE
						)
		)
	)
)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'31.03.2020',104)
--003F.00.0060 end

--003F.00.0061 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'Z_SL', null as ZN_POL ,@NSCHET, 'ZAP', t0.N_ZAP, t0.ID_PAC, t0.idcase as IDCASE, null as SL_ID, null as IDSERV, '003F.00.0061'
, 'Зак. случай не может быть включен в этот тип реестров счетов'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C')
and not exists 
(
	select top 1 1
	from tempdb..TEMP_SLUCH t1 with(nolock) 
	where t0.idcase = t1.idcase
	and
		(
			isnull(DS_ONK,0) = 1
			or DS1 like 'C%'  
			or DS1 like 'D0%'  
		)
)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--003F.00.0061 end

--003F.00.0062 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'Z_SL', null as ZN_POL ,@NSCHET, 'ZAP', t0.N_ZAP, t0.ID_PAC, t0.idcase as IDCASE, null as SL_ID, null as IDSERV, '003F.00.0062'
, 'Зак. случай не может быть включен в этот тип реестров счетов'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C')
and not exists 
(
	select top 1 1
	from tempdb..TEMP_SLUCH t1 with(nolock) 
	where t0.idcase = t1.idcase
	and
		(
			isnull(DS_ONK,0) = 1
			or DS1 like 'C%'  
			or DS1 like 'D0%'
			or (DS1 >= 'D45' and DS1 < 'D48')
		)
)
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--003F.00.0062 end

--003F.00.0080 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SPOLIS', t0.SPOLIS as ZN_POL ,@NSCHET, 'PACIENT', t0.N_ZAP, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.0080'
, 'Поле SPOLIS заполняется только для старых полисов'
from tempdb..TEMP_PACIENT t0 with(nolock)
join tempdb..TEMP_ZAP t1 with(nolock) on t0.N_ZAP= t1.N_ZAP
join tempdb..TEMP_Z_SLUCH t2 with(nolock) on t0.n_zap = t2.n_zap
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
and SPOLIS is not null
and VPOLIS<>1
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0080 end

--003F.00.0110 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ST_OKATO', t0.ST_OKATO as ZN_POL ,@NSCHET, 'PACIENT', t0.N_ZAP, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.0110'
, 'Поле ST_OKATO должно быть заполнено для старых полисов'
from tempdb..TEMP_PACIENT t0 with(nolock)
join tempdb..TEMP_ZAP t1 with(nolock) on t0.N_ZAP= t1.N_ZAP
join tempdb..TEMP_SCHET t2 with(nolock) on 1 = 1
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t0.n_zap = t3.n_zap
where
@q019type in ('C', 'H', 'T', 'X')
and PLAT is not null
and VPOLIS=1
and ST_OKATO is null
and @type = 693 --это строка выражает условие "ЕСЛИ PLAT не пусто в имени файла"
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0110 end

--003F.00.0120 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SMO', t0.SMO as ZN_POL ,@NSCHET, 'PACIENT', t0.N_ZAP, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.0120'
, 'Не указано СМО при наличии PLAT'
from tempdb..TEMP_PACIENT t0 with(nolock)
join tempdb..TEMP_ZAP t1 with(nolock) on t0.N_ZAP= t1.N_ZAP
join tempdb..TEMP_SCHET t2 with(nolock) on 1 = 1
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t1.n_zap
where
@q019type in ('C', 'H', 'T', 'X')
and t2.PLAT is not null
and t0.SMO is null
and @type = 693 --это строка выражает условие "ЕСЛИ PLAT не пусто в имени файла"
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0120 end

--003F.00.0130 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SMO_OGRN', t0.SMO_OGRN as ZN_POL ,@NSCHET, 'PACIENT', t0.N_ZAP, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.0130'
, 'Поле SMO_OGRN должно быть заполнено, если поле SMO не заполнено'
from tempdb..TEMP_PACIENT t0 with(nolock)
join tempdb..TEMP_ZAP t1 with(nolock) on t0.N_ZAP= t1.N_ZAP
join tempdb..TEMP_SCHET t2 with(nolock) on 1 = 1
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t0.n_zap = t3.n_zap
where
@q019type in ('C', 'H', 'T', 'X')
and t0.SMO is null
and t0.SMO_OGRN is null
and @type != 562 --рег особенность (не проверяется во временных счетах на идентификацию)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0130 end

--003F.00.0140 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SMO_OK', t0.SMO_OK as ZN_POL ,@NSCHET, 'PACIENT', t0.N_ZAP, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.0140'
, 'Поле SMO_OK должно быть заполнено при отсутствии SMO'
from tempdb..TEMP_PACIENT t0 with(nolock)
join tempdb..TEMP_ZAP t1 with(nolock) on t0.N_ZAP= t1.N_ZAP
join tempdb..TEMP_SCHET t2 with(nolock) on 1 = 1
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t0.n_zap = t3.n_zap
where
@q019type in ('C', 'H', 'T', 'X')
and t0.SMO is null
and t0.SMO_OK is null
and @type != 562 --рег особенность (не проверяется во временных счетах на идентификацию)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0140 end

--003F.00.0150 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SMO_NAM', t0.SMO_NAM as ZN_POL ,@NSCHET, 'PACIENT', t0.N_ZAP, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.0150'
, 'Поле SMO_NAM должно быть заполнено при отсутствии SMO, SMO_OGRN'
from tempdb..TEMP_PACIENT t0 with(nolock)
join tempdb..TEMP_ZAP t1 with(nolock) on t0.N_ZAP = t1.N_ZAP
join tempdb..TEMP_SCHET t2 with(nolock) on 1 = 1
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t0.n_zap = t3.n_zap
where
@q019type in ('C', 'H', 'T', 'X')
and t0.SMO is null
and t0.SMO_OGRN is null
and t0.SMO_NAM is null
and @type != 562 --рег особенность (не проверяется во временных счетах на идентификацию)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0150 end

--003F.00.0330 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DOCDATE', convert(varchar(10),t0.DOCDATE,104) as ZN_POL ,@NSCHET, 'PERS', null , t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.0330'
, 'Поле DOCDATE должно быть заполнено, если VPOLIS != 3'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_PACIENT t1 with(nolock) on convert(varchar(36),t0.ID_PAC) = convert(varchar(36),t1.ID_PAC)
join tempdb..TEMP_ZAP t2 with(nolock) on t1.N_ZAP= t2.N_ZAP
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t1.n_zap
where
t1.VPOLIS!=3
and t0.docdate is null
and @type = 554
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0330 end

--003F.00.0340 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DOCORG', t0.docorg as ZN_POL ,@NSCHET, 'PERS', null , t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.0340'
, 'Поле DOCORG должно быть заполнено, если VPOLIS != 3'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_PACIENT t1 with(nolock) on convert(varchar(36),t0.ID_PAC) = convert(varchar(36),t1.ID_PAC)
join tempdb..TEMP_ZAP t2 with(nolock) on t1.N_ZAP= t2.N_ZAP
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t1.n_zap
where
t1.VPOLIS!=3
and t0.docorg is null
and @type = 554
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0340 end

--003F.00.0390 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VNOV_D', convert(varchar(4), t0.VNOV_D) as ZN_POL ,@NSCHET, 'PACIENT', t0.N_ZAP, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.0390'
, 'VNOV_D и VNOV_M не могут быть заполнены одновременно'
from tempdb..TEMP_PACIENT t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.N_ZAP = t1.N_ZAP
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and VNOV_D is not null
and VNOV_M is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0390 end

--003F.00.0400 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NPR_MO', NPR_MO as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.0400'
, 'Поле NPR_MO должно быть заполнено при: (FOR_POM=3 и USL_OK=1) или USL_OK=2'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and ((FOR_POM=3 and USL_OK=1) or USL_OK=2)
and NPR_MO is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0400 end

--003F.00.0401 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NPR_MO', NPR_MO as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.0401'
, 'NPR_MO должно быть заполнено при заполнении NPR_DATE'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and NPR_MO is null
and NPR_DATE is not null
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--003F.00.0401 end

--003F.00.0402 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NPR_DATE', convert(varchar(10),t0.NPR_DATE,104) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.0402'
, 'Поле NPR_DATE должно быть заполнено при заполнении NPR_MO'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and NPR_DATE is null
and NPR_MO is not null

and DATE_Z_2 >= convert(date,'01.04.2020',104)
--003F.00.0402 end

--003F.00.0410 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NPR_DATE', convert(varchar(10),t0.NPR_DATE,104) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.0410'
, 'Поле NPR_DATE должно быть заполнено при: ((FOR_POM=3 and USL_OK=1) or USL_OK=2)'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and ((FOR_POM=3 and USL_OK=1) or USL_OK=2)
and NPR_DATE is null

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0410 end

--003F.00.0430 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'KD_Z', convert(varchar(3), t0.KD_Z) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.0430'
, 'Поле KD_Z должно быть заполнено при USL_OK = (1, 2)'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R')
and USL_OK in (1, 2)
and kd_z is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0430 end

--003F.00.0440 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'KD_Z', convert(varchar(3), t0.KD_Z) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.0440'
, 'Поле KD_Z должно отсутствовать при USL_OK in (1, 2)'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R')
and KD_Z is not null
and not (USL_OK in (1, 2))
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0440 end

--003F.00.0450 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VNOV_M', convert(varchar(4), t0.VNOV_M) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.0450'
, 'VNOV_D и VNOV_M не могут быть заполнены одновременно'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
join tempdb..TEMP_PACIENT t1 with(nolock) on t1.n_zap = t0.n_zap
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and VNOV_D is not null
and VNOV_M is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0450 end

--003F.00.0460 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'OS_SLUCH', convert(varchar(1), t0.OS_SLUCH) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.0460'
, 'Поле OS_SLUCH не заполнено в особом случае'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar,t0.ID_PAC) = convert(varchar,t1.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on  t2.n_zap = t0.n_zap
where
@q019type in ('C', 'H', 'T', 'X')
and t0.OS_SLUCH is null -- мб элемент обязателен
and ((isnull(t1.OT,'') = '' and NOVOR=0) or (isnull(t1.OT_P ,'') = '' and NOVOR!=0) or (NOVOR!=0 and right(novor,1) != '1'))
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0460 end

--003F.00.0470 begin
insert into #Errors (IM_POL, BASE_EL, N_ZAP, IDCASE, IDSERV, OSHIB, COMMENT)
select 'OS_SLUCH', 'Z_SL', zs.N_ZAP, zs.IDCASE, null, '904', 'OS_SLUCH обязательно для заполенеия при (PERS.OT отсутствует и NOVOR=0) или (PERS.OT_P отсутствует и NOVOR<>0) или (NOVOR<>0 и последний символ NOVOR не равен 1) '
from tempdb..TEMP_Z_SLUCH zs
join tempdb..TEMP_PACIENT pac on pac.N_ZAP=zs.N_ZAP
join tempdb..TEMP_PERS pers on cast(pac.ID_PAC as varchar(30))=cast(pers.ID_PAC as varchar(30))
where ((PERS.OT is null and pac.NOVOR=0) or (PERS.OT_P is null and pac.NOVOR<>0) or (pac.NOVOR<>0 and RIGHT(pac.NOVOR,1) <> 1))
		 and (zs.OS_SLUCH is null or zs.OS_SLUCH <> 2)
		 and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0470 end

--003F.00.0480 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'OS_SLUCH', convert(varchar(1), t0.OS_SLUCH) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.0480'
, 'Поле OS_SLUCH должно отсутствовать'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar,t0.ID_PAC) = convert(varchar,t1.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on  t2.n_zap = t0.n_zap
where
@q019type in ('C', 'H', 'T', 'X')
and t0.OS_SLUCH is not null -- элемент должен отсуствовать
and NOVOR=0 and isnull(t1.OT,'') != ''
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0480 end

--003F.00.0500 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VB_P', convert(varchar(1), t0.VB_P) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.0500'
, 'Не заполнено поле VB_P'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
join tempdb..TEMP_SLUCH t1 with(nolock) on t1.idcase = t0.idcase
where
@q019type in ('C', 'H')
and isnull (VB_P,1) != 1-- мб элемент обязателен
and IDSP=33 and P_PER=4
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0500 end

--003F.00.0510 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VB_P', convert(varchar(1), t0.VB_P) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.0510'
, 'Поле VB_P должно отсутствовать'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'H')
and t0.VB_P is not null -- элемент должен отсуствовать
and (IDSP != 33
or not exists (
	select top 1 1 from tempdb..TEMP_SLUCH t1 with(nolock)
	where t1.p_per = 4 and t1.idcase = t0.idcase
))
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0510 end

--003F.00.0530 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'OPLATA', convert(varchar(1), t0.OPLATA) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.0530'
, 'Поле OPLATA должно быть заполнено при наличии санкций МЭК'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'H', 'T', 'X')
and exists (select top 1 1 from tempdb..TEMP_SANK where S_IST=1)
and t0.OPLATA is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0530 end

--003F.00.0550 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'OPLATA', convert(varchar(1), t0.OPLATA) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.0550'
, 'Поле OPLATA должно отсутствовать если нет от ТФОМС/СМО'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'H', 'T', 'X')
and exists (select top 1 1 from tempdb..TEMP_SANK where S_IST!=1)
and t0.OPLATA is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0550 end

--003F.00.0570 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SUMP', convert(varchar, cast(t0.SUMP as money)) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.0570'
, 'Поле SUMP должно быть заполнено'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'H', 'T', 'X')
and SUMP is null
and @type = 693
and @isMoToSmo = 0

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0570 end

--003F.00.0580 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SANK',null  as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.0580'
, 'При наличии SANK_IT должен присутствовать хотя бы один элемент SANK'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
and t0.SANK_IT is not null
and not exists (select top 1 1 from tempdb..TEMP_SANK t1 where t1.IDCASE = t0.IDCASE)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0580 end

--003F.00.0590 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SANK_IT', convert(varchar, cast(t0.SANK_IT as money)) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.0590'
, 'Поле SANK_IT имеет недопустимое значение'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
and t0.SANK_IT is null
and exists (select top 1 1 from tempdb..TEMP_SANK t1 with(nolock) where t0.IDCASE = t1.IDCASE and isnull(s_sum,0) >0 )

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0590 end

--003F.00.0640 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PROFIL_K', convert(varchar(3), t0.PROFIL_K) as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0640'
, 'Поле PROFIL_K должно быть заполнено при USL_OK = (1, 2)'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'H', 'R')
and t0.PROFIL_K is null -- мб элемент обязателен
and isnull(USL_OK,0) in (1, 2)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0640 end

--003F.00.0650 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PROFIL_K', convert(varchar(3), t0.PROFIL_K) as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0650'
, 'Поле PROFIL_K должно отсутствовать '
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'H', 'R')
and t0.PROFIL_K is not null -- элемент должен отсуствовать
and isnull(USL_OK,0) not in (1, 2)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0650 end

--003F.00.0660 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'P_CEL', convert(varchar(3), t0.P_CEL) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID as SL_ID, null as IDSERV,  '003F.00.0660'
, 'Поле P_CEL должно быть заполнено для случаев с USL_OK = 3'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.idcase = t1.idcase
where
@q019type in ('C', 'D', 'H', 'R')
and (isnull(USL_OK,0) = 3)
and t0.P_CEL is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0660 end

--003F.00.0670 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'P_CEL', convert(varchar(3), t0.P_CEL) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID as SL_ID, null as IDSERV,  '003F.00.0670'
, 'Поле P_CEL должно отсутствовать при USL_OK != 3'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.idcase = t1.idcase
where
@q019type in ('C', 'D', 'H', 'R')
and (isnull(USL_OK, 0) != 3)
and t0.P_CEL is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0670 end

--003F.00.0700 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'P_PER', convert(varchar(1), t0.P_PER) as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0700'
, 'Поле P_PER обязательно для случаев с USL_OK = (1, 2)'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'H')
and t0.P_PER is null -- мб элемент обязателен
and isnull(USL_OK,0) in (1, 2)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0700 end

--003F.00.0710 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'P_PER', convert(varchar(1), t0.P_PER) as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0710'
, 'Поле P_PER должно отсутствовать если USL_OK != (1,2)'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'H')
and t0.P_PER is not null -- элемент должен отсуствовать
and isnull(USL_OK,0) not in (1, 2)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0710 end

--003F.00.0740 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'KD', convert(varchar(3), t0.KD) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.0740'
, 'Поле KD должно быть заполнено если USL_OK = (1,2)'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.idcase = t1.idcase
where
@q019type in ('C', 'D', 'H', 'R')
and KD is null
and (USL_OK in (1, 2))
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0740 end

--003F.00.0750 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'KD', convert(varchar(3), t0.KD) as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0750'
, 'Поле KD должно отсутствовать если USL_OK != (1,2) '
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.idcase
where
@q019type in ('C', 'D', 'H', 'R')
and t0.KD is not null -- элемент должен отсуствовать
and USL_OK not in (1, 2)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0750 end

--003F.00.0760 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'C_ZAB', convert(varchar(1), t0.C_ZAB) as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0760'
, 'Поле C_ZAB обязательно при USL_OK = 3 и DS1 != Z'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('H')
and t0.C_ZAB is null -- мб элемент обязателен
and USL_OK=3 
and DS1 not like 'Z%'
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0760 end

--003F.00.0770 begin
INSERT INTO #ERRORS ( IM_POL ,ZN_POL ,NSCHET ,BAS_EL ,N_ZAP ,ID_PAC ,IDCASE ,SL_ID ,IDSERV ,OSHIB ,COMMENT )
SELECT 'C_ZAB' ,CONVERT(VARCHAR(1), T0.C_ZAB) AS ZN_POL ,@NSCHET ,'SL' ,T0.N_ZAP ,T0.ID_PAC ,T0.IDCASE ,T0.SL_ID ,NULL AS IDSERV ,'003F.00.0770'
, 'Поле C_ZAB обязательно при ЗНО и нейтропении'
FROM TEMPDB..TEMP_SLUCH T0 WITH (NOLOCK)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.idcase = t1.idcase
WHERE @Q019TYPE IN ('T')
	AND (
		DS1 LIKE 'C%'
		OR DS1 LIKE 'D0%'
		OR (
			DS1 = 'D70'
			AND EXISTS (
				SELECT TOP 1 1
				FROM TEMPDB..TEMP_DS2 T1
				WHERE
					((DS2 >= 'C00' AND DS2 < 'C81') OR DS2 LIKE 'C97%')
					AND T1.SL_ID = T0.SL_ID
					AND T1.IDCASE = T0.IDCASE
				)
			)
		)
	AND C_ZAB IS NULL
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'31.03.2020',104)
--003F.00.0770 end

--003F.00.0771 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'C_ZAB', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0771'
, 'C_ZAB обязательно при этом диагнозе'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('T')
and t0.C_ZAB is null -- мб элемент обязателен
and (DS1 like 'C%' or DS1 like 'D0%')
and DATE_Z_2 >= convert(date,'01.04.2020',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--003F.00.0771 end

--003F.00.0772 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'C_ZAB', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0772'
, 'Поля обязательно для данного диагноза'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('T')
and t0.C_ZAB is null -- мб элемент обязателен
and (DS1 like 'C%' or DS1 like 'D0%' or (DS1 >= 'D45' and DS1 < 'D48'))
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--003F.00.0772 end

--003F.00.0780 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'C_ZAB', convert(varchar(1), t0.C_ZAB) as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0780'
, 'Поле C_ZAB обязательно при ЗНО и нейтропении'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.idcase
where
@q019type in ('C', 'D', 'R')
and t0.C_ZAB is null -- мб элемент обязателен
and (
DS1 like 'C%'
or DS1 like 'D0%'
or (
	DS1='D70' 
	and exists
		(
			select top 1 1
			from tempdb..TEMP_DS2 t2 
			where
			((DS2>='C00' and DS2<'C81') or DS2 like 'C97%') and t2.SL_ID = t0.SL_ID and t2.IDCASE= t0.IDCASE
		)
	)
)
and isnull(usl_ok,0) != 4
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'31.03.2020',104)
--003F.00.0780 end

--003F.00.0781 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'C_ZAB', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0781'
, 'C_ZAB обязательно при этом диагнозе'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R')
and t0.C_ZAB is null -- мб элемент обязателен
and (DS1 like 'C%' or DS1 like 'D0%')
and isnull(USL_OK,0) != 4
and DATE_Z_2 >= convert(date,'01.04.2020',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--003F.00.0781 end

--003F.00.0782 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'C_ZAB', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0782'
, 'Поля обязательно для данного диагноза'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R')
and t0.C_ZAB is null -- мб элемент обязателен
and (DS1 like 'C%' or DS1 like 'D0%' or (DS1 >= 'D45' and DS1 < 'D48')
)
and isnull(USL_OK,0) != 4
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--003F.00.0782 end

--003F.00.0790 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DN', convert(varchar(1), t0.DN) as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0790'
, 'Поле DN обязательно при цели посещения 1.3'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t1.n_zap = t0.n_zap
where
@q019type in ('C', 'D', 'H', 'R')
and t0.DN is null -- мб элемент обязателен
and isnull(P_CEL,'') = '1.3'
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0790 end

--003F.00.0800 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'KSG_KPG', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0800'
, 'Элемент KSG_KPG обязателен при IDSP=33'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'H', 'R')
and not exists (select top 1 1 from tempdb..TEMP_KSG_KPG t01 with(nolock) where t0.sl_id = t01.sl_id and t0.idcase = t01.idcase)
and t1.IDSP=33

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0800 end

--003F.00.0810 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'KSG_KPG', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0810'
, 'Элемент KSG_KPG должен отсутствовать если IDSP != 33'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.idcase
where
@q019type in ('C', 'D', 'H', 'R')
and exists (select top 1 1 from tempdb..TEMP_KSG_KPG t01 with(nolock) where t0.sl_id = t01.sl_id and t0.idcase = t01.idcase)
and IDSP!=33
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0810 end

--003F.00.0820 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'REAB', convert(varchar(1), t0.REAB) as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0820'
, 'REAB должно отсутствовать при FOR_POM != 3'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('D', 'H', 'R')
and t0.REAB is not null -- элемент должен отсуствовать
and FOR_POM!=3
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0820 end

--003F.00.0830 begin
INSERT INTO #Errors ( IM_POL ,ZN_POL ,NSCHET ,BAS_EL ,N_ZAP ,ID_PAC ,IDCASE ,SL_ID ,IDSERV ,OSHIB ,COMMENT )
SELECT 'CONS' ,NULL AS ZN_POL ,@NSCHET ,'SL' ,t0.N_ZAP ,t0.ID_PAC ,t0.IDCASE ,t0.SL_ID ,NULL AS IDSERV ,'003F.00.0830'
, 'Элемент CONS обязателен при подозрении на ЗНО, ЗНО или нейтропении.'
FROM tempdb..TEMP_SLUCH t0 WITH (NOLOCK)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t1.n_zap = t0.n_zap
WHERE @q019type IN ('D', 'R', 'T')
	AND NOT EXISTS (
		SELECT TOP 1 1
		FROM tempdb..TEMP_CONS t1
		WHERE t1.SL_ID = t0.SL_ID
			AND t1.IDCASE = t0.IDCASE
		)
	AND (
		DS_ONK = 1
		OR (
			DS1 LIKE 'C%'
			OR DS1 LIKE 'D0%'
			OR (
				DS1 = 'D70'
				AND EXISTS (
					SELECT TOP 1 1
					FROM tempdb..TEMP_DS2 t1
					WHERE (
								(
								DS2 >= 'C00'
								AND DS2 < 'C81'
								)
								OR DS2 LIKE 'C97%'
							)
						AND t1.SL_ID = t0.SL_ID
						AND t1.IDCASE = t0.IDCASE
					)
				)
			)
		)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'31.03.2020',104)
--003F.00.0830 end

--003F.00.0831 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CONS', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0831'
, 'Консилиум обязателен  если DS_ONK=1 или C00.0<=DS1<D10'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('T')
and not exists (select top 1 1 from tempdb..TEMP_CONS t01 where t01.sl_id = t0.sl_id and t01.idcase = t0.idcase)
and (DS_ONK=1 or DS1 like 'C%' or DS1 like 'D0%')
and DATE_Z_2 >= convert(date,'01.04.2020',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--003F.00.0831 end

--003F.00.0833 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CONS', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0833'
, 'Консилиум обязателен в данном случае'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('T')
and not exists (select top 1 1 from tempdb..TEMP_CONS t01 where t01.sl_id = t0.sl_id and t01.idcase = t0.idcase)
and (DS_ONK=1 or DS1 like 'C%' or DS1 like 'D0%' or (DS1 >= 'D45' and DS1 < 'D48'))
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--003F.00.0833 end

--003F.00.0840 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CONS', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0840'
, 'Элемент CONS обязателен при ЗНО или нейтропении.'
FROM tempdb..TEMP_SLUCH t0 WITH (NOLOCK)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t1.n_zap = t0.n_zap
WHERE @q019type IN ('D', 'R', 'T')
	AND NOT EXISTS (
		SELECT TOP 1 1
		FROM tempdb..TEMP_CONS t1
		WHERE t1.SL_ID = t0.SL_ID
			AND t1.IDCASE = t0.IDCASE
		)
	AND (	
		DS1 LIKE 'C%'
		OR DS1 LIKE 'D0%'
		OR (
			DS1 = 'D70'
			AND EXISTS (
				SELECT TOP 1 1
				FROM tempdb..TEMP_DS2 t1
				WHERE ((DS2 >= 'C00' AND DS2 < 'C81') or ds2 like 'C97%')
					AND t1.SL_ID = t0.SL_ID
					AND t1.IDCASE = t0.IDCASE
				)
			)
		)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'31.03.2020',104)
--003F.00.0840 end

--003F.00.0841 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CONS', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0841'
, 'Консилиум обязателен для данного диагноза'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C')
and not exists (select top 1 1 from tempdb..TEMP_CONS t01 where t01.sl_id = t0.sl_id and t01.idcase = t0.idcase)
and (DS1 like 'C%' or DS1 like 'D0%')
and DATE_Z_2 >= convert(date,'01.04.2020',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--003F.00.0841 end

--003F.00.0842 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CONS', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0842'
, 'Консилиум обязателен для данного диагноза'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C')
and not exists (select top 1 1 from tempdb..TEMP_CONS t01 where t01.sl_id = t0.sl_id and t01.idcase = t0.idcase)
and (DS1 like 'C%' or DS1 like 'D0%' or (DS1 >= 'D45' and DS1 < 'D48'))
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--003F.00.0842 end

--003F.00.0850 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
SELECT 'CONS', NULL AS ZN_POL, @NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, NULL AS IDSERV, '003F.00.0850'
, 'Элемент CONS должен отсутствовать при отсутствии подозрения на ЗНО, ЗНО или нейтропении'
FROM tempdb..TEMP_SLUCH t0 WITH (NOLOCK)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t1.n_zap = t0.n_zap
WHERE @q019type IN ('D', 'R', 'T')
	AND EXISTS (
		SELECT TOP 1 1
		FROM tempdb..TEMP_CONS t1
		WHERE t1.SL_ID = t0.SL_ID
			AND t1.IDCASE = t0.IDCASE
		)
	AND NOT (
		DS_ONK = 1
		OR (
			DS1 LIKE 'C%'
			OR DS1 LIKE 'D0%'
			OR (
				DS1 = 'D70'
				AND EXISTS (
					SELECT TOP 1 1
					FROM tempdb..TEMP_DS2 t1
					WHERE ((DS2 >= 'C00' AND DS2 < 'C81') or ds2 like 'C97%')
						AND t1.SL_ID = t0.SL_ID
						AND t1.IDCASE = t0.IDCASE
					)
				)
			)
		)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'31.03.2020',104)
--003F.00.0850 end

--003F.00.0851 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CONS', null as ZN_POL ,@NSCHET, 'SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0851'
, 'Консилиумы запрещены при DS_ONK=0 и (DS1<C00 или DS1>D09) '
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('T')
and exists (select top 1 1 from tempdb..TEMP_CONS t01 where t01.sl_id = t0.sl_id and t01.idcase = t0.idcase)
and not (DS_ONK=1 or DS1 like 'C%' or DS1 like 'D0%')
and DATE_Z_2 >= convert(date,'01.04.2020',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--003F.00.0851 end

--003F.00.0853 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CONS', null as ZN_POL ,@NSCHET, 'SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0853'
, 'Консилиум запрещён в данном случаев'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('T')
and exists (select top 1 1 from tempdb..TEMP_CONS t01 where t01.sl_id = t0.sl_id and t01.idcase = t0.idcase)
and not (DS_ONK=1 or DS1 like 'C%' or DS1 like 'D0%' or (DS1 >= 'D45' and DS1 < 'D48'))
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--003F.00.0853 end

--003F.00.0860 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CONS', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0860', 'Элемент CONS должен отсутствовать.'
FROM tempdb..TEMP_SLUCH t0 WITH (NOLOCK)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t1.n_zap = t0.n_zap
WHERE @q019type IN ('C')
AND EXISTS (SELECT TOP 1 1 FROM tempdb..TEMP_CONS t1 WHERE t1.SL_ID = t0.SL_ID AND t1.IDCASE = t0.IDCASE)
AND not 
(	
DS1 LIKE 'C%'
OR DS1 LIKE 'D0%'
OR (
	DS1 = 'D70'
	AND EXISTS 
	(
	SELECT TOP 1 1
	FROM tempdb..TEMP_DS2 t1
	WHERE ((DS2 >= 'C00' AND DS2 < 'C81') or ds2 like 'C97%')
	AND t1.SL_ID = t0.SL_ID
	AND t1.IDCASE = t0.IDCASE
	)
	)
)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'02.11.2019',104)
--003F.00.0860 end

--003F.00.0870 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_SL', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0870'
, 'Элемент ONK_SL должен быть заполнен при ЗНО и нейтропении'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t1.n_zap = t0.n_zap
where
@q019type in ('T')
and not exists (select top 1 1 from tempdb..TEMP_ONK_SL t10 with(nolock) where t10.sl_id = t0.sl_id and t10.idcase = t0.idcase )
and (
DS1 like 'C%'
or DS1 like 'D0%'
or (
	DS1='D70' 
	and exists
		(
			select top 1 1
			from tempdb..TEMP_DS2 t2 
			where
			((DS2>='C00' and DS2<'C81') or DS2 like 'C97%') and t2.SL_ID = t0.SL_ID and t2.IDCASE= t0.IDCASE
		)
	)
)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'31.03.2020',104)
--003F.00.0870 end

--003F.00.0871 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_SL', null as ZN_POL ,@NSCHET, 'SL', t2.N_ZAP, t2.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0871'
, 'Элемент обязателен при условии C00.0<=DS1<D10'
from tempdb..TEMP_ONK_SL t0
join tempdb..TEMP_SLUCH t1 with(nolock) on t0.SL_ID = t1.SL_ID and t0.IDCASE = t1.IDCASE
join tempdb..TEMP_Z_SLUCH t2 with(nolock) on t2.IDCASE = t1.IDCASE
where
@q019type in ('T')
and t0.DS1_T is null -- мб элемент обязателен
and (DS1 like 'C%' or DS1 like 'D0%')
and DATE_Z_2 >= convert(date,'01.04.2020',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--003F.00.0871 end

--003F.00.0872 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_SL', null as ZN_POL ,@NSCHET, 'SL', t2.N_ZAP, t2.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0872'
, 'Элемент обязателен для данного диагноза'
from tempdb..TEMP_ONK_SL t0
join tempdb..TEMP_SLUCH t1 with(nolock) on t0.SL_ID = t1.SL_ID and t0.IDCASE = t1.IDCASE
join tempdb..TEMP_Z_SLUCH t2 with(nolock) on t2.IDCASE = t1.IDCASE
where
@q019type in ('T')
and t0.DS1_T is null -- мб элемент обязателен
and (DS1 like 'C%' or DS1 like 'D0%' or (DS1 >= 'D45' and DS1 < 'D48'))
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--003F.00.0872 end

--003F.00.0880 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_SL', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0880'
, 'Элемент ONK_SL должен быть заполнен при ЗНО и нейтропении'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1  with(nolock) on t0.idcase = t1.idcase
left join tempdb..TEMP_ONK_SL t2 with(nolock) on t0.SL_ID = t2.SL_ID and t0.IDCASE = t2.IDCASE
where
@q019type in ('C')
and t2.DS1_T is null
and (
	(USL_OK != 4 and REAB != 1 and DS_ONK=0)
	and (
	DS1 like 'C%'
	or DS1 like 'D0%'
	or (
	         DS1 = 'D70'
	         and exists ( select top 1 1 from tempdb..TEMP_DS2 t3 where ((DS2>='C00' and DS2<'C81') or DS2 like 'C97%') and  t3.SL_ID = t0.SL_ID and t3.IDCASE = t0.IDCASE)
	    )
	
	)
)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'31.03.2020',104)
--003F.00.0880 end

--003F.00.0881 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_SL', null as ZN_POL ,@NSCHET, 'SL', t2.N_ZAP, t2.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0881'
, 'Элемент обязателен при условии C00.0<=DS1<D10 и USL_OK<>4 и REAB<>1 и DS_ONK=0'
from tempdb..TEMP_ONK_SL t0
join tempdb..TEMP_SLUCH t1 with(nolock) on t0.SL_ID = t1.SL_ID and t0.IDCASE = t1.IDCASE
join tempdb..TEMP_Z_SLUCH t2 with(nolock) on t2.IDCASE = t1.IDCASE
where
@q019type in ('C')
and t0.DS1_T is null -- мб элемент обязателен
and (DS1 like 'C%' or DS1 like 'D0%')
and USL_OK != 4
and REAB != 1
and DS_ONK = 0
and DATE_Z_2 >= convert(date,'01.04.2020',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--003F.00.0881 end

--003F.00.0882 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_SL', null as ZN_POL ,@NSCHET, 'SL', t2.N_ZAP, t2.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0881'
, 'Элемент ONK_SL обязателен в данном случае'
from tempdb..TEMP_ONK_SL t0
join tempdb..TEMP_SLUCH t1 with(nolock) on t0.SL_ID = t1.SL_ID and t0.IDCASE = t1.IDCASE
join tempdb..TEMP_Z_SLUCH t2 with(nolock) on t2.IDCASE = t1.IDCASE
where
@q019type in ('C')
and t0.DS1_T is null -- мб элемент обязателен
and (DS1 like 'C%' or DS1 like 'D0%' or (DS1 >= 'D45' and DS1 < 'D48'))
and USL_OK != 4
and REAB != 1
and DS_ONK = 0
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--003F.00.0882 end

--003F.00.0900 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_SL', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0900'
, 'Элемент ONK_SL должен отсутствовать при отсутствии ЗНО и нейтропении'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t1.n_zap = t0.n_zap
where
@q019type in ('T')
and exists (select top 1 1 from tempdb..TEMP_ONK_SL t10 with(nolock) where t10.sl_id = t0.sl_id and t10.idcase = t0.idcase )
and not (
DS1 like 'C%'
or DS1 like 'D0%'
or (
	DS1='D70' 
	and exists
		(
			select top 1 1
			from tempdb..TEMP_DS2 t2 
			where
			((DS2>='C00' and DS2<'C81') or DS2 like 'C97%') and t2.SL_ID = t0.SL_ID and t2.IDCASE= t0.IDCASE
		)
	)
)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'31.03.2020',104)
--003F.00.0900 end

--003F.00.0901 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_SL', null as ZN_POL ,@NSCHET, 'SL', t2.N_ZAP, t2.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0901'
, 'элемент должен отсутствовать при условии DS1<C00 или DS1>D09'
from tempdb..TEMP_ONK_SL t0
join tempdb..TEMP_SLUCH t1 with(nolock) on t0.SL_ID = t1.SL_ID and t0.IDCASE = t1.IDCASE
join tempdb..TEMP_Z_SLUCH t2 with(nolock) on t2.IDCASE = t1.IDCASE
where
@q019type in ('T')
and t0.DS1_T is not null -- элемент должен отсуствовать
and not (DS1 like 'C%' or DS1 like 'D0%')
and DATE_Z_2 >= convert(date,'01.04.2020',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--003F.00.0901 end

--003F.00.0902 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_SL', null as ZN_POL ,@NSCHET, 'SL', t2.N_ZAP, t2.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0902'
, 'элемент должен отсутствовать для данного диагноза'
from tempdb..TEMP_ONK_SL t0
join tempdb..TEMP_SLUCH t1 with(nolock) on t0.SL_ID = t1.SL_ID and t0.IDCASE = t1.IDCASE
join tempdb..TEMP_Z_SLUCH t2 with(nolock) on t2.IDCASE = t1.IDCASE
where
@q019type in ('T')
and t0.DS1_T is not null -- элемент должен отсуствовать
and not (DS1 like 'C%' or DS1 like 'D0%' or (DS1 >= 'D45' and DS1 < 'D48'))
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--003F.00.0902 end

--003F.00.0910 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_SL', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0910'
, 'Элемент ONK_SL должен отсутствовать при отсутствии ЗНО и нейтропении'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1  with(nolock) on t0.idcase = t1.idcase
join tempdb..TEMP_ONK_SL t2 with(nolock) on t0.SL_ID = t2.SL_ID and t0.IDCASE = t2.IDCASE
where
@q019type in ('C')
AND t2.ds1_t is not null
and not (
	(USL_OK != 4 and REAB != 1)
	and (
	DS1 like 'C%'
	or DS1 like 'D0%'
	or (
	         DS1 = 'D70'
	         and exists ( select top 1 1 from tempdb..TEMP_DS2 t3 where ((DS2>='C00' and DS2<'C81') or DS2 like 'C97%') and  t3.SL_ID = t0.SL_ID and t3.IDCASE = t0.IDCASE)
	    )
	
	)
)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'31.03.2020',104)
--003F.00.0910 end

--003F.00.0911 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_SL', null as ZN_POL ,@NSCHET, 'SL', t2.N_ZAP, t2.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0911'
, 'элемент должен отсутствовать при выполнении условия DS1<C00 или DS1>D09 или USL_OK=4 или REAB=1'
from tempdb..TEMP_ONK_SL t0
join tempdb..TEMP_SLUCH t1 with(nolock) on t0.SL_ID = t1.SL_ID and t0.IDCASE = t1.IDCASE
join tempdb..TEMP_Z_SLUCH t2 with(nolock) on t2.IDCASE = t1.IDCASE
where
@q019type in ('C')
and t0.DS1_T is not null -- элемент должен отсуствовать
and (
not (DS1 like 'C%' or DS1 like 'D0%')
or USL_OK = 4
or REAB = 1
)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--003F.00.0911 end

--003F.00.0912 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_SL', null as ZN_POL ,@NSCHET, 'SL', t2.N_ZAP, t2.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0912'
, 'Элемент должен отсутствовать при выполнении условия'
from tempdb..TEMP_ONK_SL t0
join tempdb..TEMP_SLUCH t1 with(nolock) on t0.SL_ID = t1.SL_ID and t0.IDCASE = t1.IDCASE
join tempdb..TEMP_Z_SLUCH t2 with(nolock) on t2.IDCASE = t1.IDCASE
where
@q019type in ('C')
and t0.DS1_T is not null -- элемент должен отсуствовать
and (
not (DS1 like 'C%' or DS1 like 'D0%' or (DS1 >= 'D45' and DS1 < 'D48'))
or USL_OK = 4
or REAB = 1
)
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--003F.00.0912 end

--003F.00.0930 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'TARIF', convert(varchar, cast(t0.TARIF as money)) as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0930'
, 'Поле TARIF не может быть пустым при ЗНО и нейтропении'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t1.n_zap = t0.n_zap
where
@q019type in ('C', 'T')
and t0.TARIF is null -- мб элемент обязателен
and (
DS1 like 'C%'
or DS1 like 'D0%'
or (
         DS1 = 'D70'
         and exists ( select top 1 1 from tempdb..TEMP_DS2 t3 where ((DS2>='C00' and DS2<'C81') or DS2 like 'C97%') and  t3.SL_ID = t0.SL_ID and t3.IDCASE = t0.IDCASE)
    )
)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'31.03.2020',104)
--003F.00.0930 end

--003F.00.0931 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'TARIF', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0931'
, 'Поле обязательно при условии C00.0<=DS1<D10'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'T')
and t0.TARIF is null -- мб элемент обязателен
and (DS1 like 'C%' or DS1 like 'D0%')
and DATE_Z_2 >= convert(date,'01.04.2020',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--003F.00.0931 end

--003F.00.0932 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'TARIF', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0931'
, 'Элемент обязателен согласно диагнозу'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'T')
and isnull(t0.TARIF,0) = 0 -- мб элемент обязателен
and (DS1 like 'C%' or DS1 like 'D0%' or (DS1 >= 'D45' and DS1 < 'D48'))
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--003F.00.0932 end

--003F.00.0940 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'USL', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0940'
, 'Элемент USL обязателен в данном случае'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1  with(nolock) on t0.idcase = t1.idcase
left join tempdb..TEMP_ONK_USL t2 with(nolock) on t0.SL_ID = t2.SL_ID and t0.IDCASE = t2.IDCASE
where
@q019type in ('T')
and (
DS1 like 'C%'
or DS1 like 'D0%'
or (
         DS1 = 'D70'
         and exists ( select top 1 1 from tempdb..TEMP_DS2 t3 where ((DS2>='C00' and DS2<'C81') or DS2 like 'C97%') and  t3.SL_ID = t0.SL_ID and t3.IDCASE = t0.IDCASE)
    )

)
and isnull(t2.USL_TIP,0) in (1,3,4)
and not exists (select top 1 1 from tempdb..TEMP_USL t4 where t4.sl_id = t0.sl_id and t4.idcase = t0.idcase)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'31.03.2020',104)
--003F.00.0940 end

--003F.00.0941 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'USL', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0941'
, 'Если C00.0<=DS1<D10 и USL_TIP={1, 3, 4}, то элемент обязателен'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1  with(nolock) on t0.idcase = t1.idcase
left join tempdb..TEMP_ONK_USL t2 with(nolock) on t0.SL_ID = t2.SL_ID and t0.IDCASE = t2.IDCASE
where
@q019type in ('T')
and (DS1 like 'C%' or DS1 like 'D0%')
and isnull(t2.USL_TIP,0) in (1,3,4)
and not exists (select top 1 1 from tempdb..TEMP_USL t4 with(nolock) where t4.IDCASE = t0.IDCASE and t4.SL_ID = t0.SL_ID)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--003F.00.0941 end

--003F.00.0942 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'USL', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0941'
, 'Элеент обязателен'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1  with(nolock) on t0.idcase = t1.idcase
left join tempdb..TEMP_ONK_USL t2 with(nolock) on t0.SL_ID = t2.SL_ID and t0.IDCASE = t2.IDCASE
where
@q019type in ('T')
and (DS1 like 'C%' or DS1 like 'D0%' or (DS1 >= 'D45' and DS1 < 'D48'))
and isnull(t2.USL_TIP,0) in (1,3,4)
and not exists (select top 1 1 from tempdb..TEMP_USL t4 with(nolock) where t4.IDCASE = t0.IDCASE and t4.SL_ID = t0.SL_ID)
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--003F.00.0942 end

--003F.00.0950 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'USL', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t1.SL_ID, null as IDSERV, '003F.00.0950'
, 'Услуги должны отсутствовать при наличии признака отказа'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
join tempdb..TEMP_SLUCH t1 with(nolock) on t0.idcase = t1.idcase
where
@q019type in ('X')
and isnull(t0.P_OTK,0) = 1
and exists 
(
select top 1 1 from tempdb..TEMP_USL t2
where t2.IDCASE = t0.IDCASE
)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0950 end

--003F.00.0960 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'USL', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0960'
, 'Элемент USL обязателен в этом случае'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1  with(nolock) on t0.idcase = t1.idcase
left join tempdb..TEMP_ONK_USL t2 with(nolock) on t0.SL_ID = t2.SL_ID and t0.IDCASE = t2.IDCASE
where
@q019type in ('C', 'D', 'R')
and (
DS1 like 'C%'
or DS1 like 'D0%'
or (
         DS1 = 'D70'
         and exists ( select top 1 1 from tempdb..TEMP_DS2 t3 where ((DS2>='C00' and DS2<'C81') or DS2 like 'C97%') and  t3.SL_ID = t0.SL_ID and t3.IDCASE = t0.IDCASE)
    )

)
and isnull(t2.USL_TIP,0) in (1,3,4,6)
and not exists (select top 1 1 from tempdb..TEMP_USL t4 where t4.sl_id = t0.sl_id and t4.idcase = t0.idcase)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'31.03.2020',104)
--003F.00.0960 end

--003F.00.0961 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'USL', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0961'
, 'Если C00.0<=DS1<D10 и USL_TIP={1, 3, 4, 6}, то поле обязательно'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1  with(nolock) on t0.idcase = t1.idcase
left join tempdb..TEMP_ONK_USL t2 with(nolock) on t0.SL_ID = t2.SL_ID and t0.IDCASE = t2.IDCASE
where
@q019type in ('C', 'D', 'R')
and (DS1 like 'C%' or DS1 like 'D0%')
and isnull(t2.USL_TIP,0) in (1,3,4,6)
and not exists (select top 1 1 from tempdb..TEMP_USL t4 with(nolock) where t4.IDCASE = t0.IDCASE and t4.SL_ID = t0.SL_ID)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--003F.00.0961 end

--003F.00.0962 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'USL', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0961'
, 'Элеент обязателен'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1  with(nolock) on t0.idcase = t1.idcase
left join tempdb..TEMP_ONK_USL t2 with(nolock) on t0.SL_ID = t2.SL_ID and t0.IDCASE = t2.IDCASE
where
@q019type in ('C', 'D', 'R')
and (DS1 like 'C%' or DS1 like 'D0%' or (DS1 >= 'D45' and DS1 < 'D48'))
and isnull(t2.USL_TIP,0) in (1,3,4,6)
and not exists (select top 1 1 from tempdb..TEMP_USL t4 with(nolock) where t4.IDCASE = t0.IDCASE and t4.SL_ID = t0.SL_ID)
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--003F.00.0962 end

--003F.00.0970 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'STAD', convert(varchar(3), t0.STAD) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0970'
, 'Поле STAD обязателен в данном случае'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('T')
and t0.STAD is null
and t0.ds1_t in (0,1,2)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0970 end

--003F.00.0980 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'STAD', convert(varchar(3), t0.STAD) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0980'
, 'Поле STAD обязателен в данном случае'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R')
and t0.STAD is null
and t0.ds1_t in (0,1,2,3,4)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0980 end

--003F.00.0990 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_T', convert(varchar(4), t0.ONK_T) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.0990', 'Обязателен при DS1_T=0 и возраст пациента на DATE_Z_1 больше или равен 18 лет'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_PERS t2  with(nolock) on convert(varchar,t2.ID_PAC) = convert(varchar,t1.ID_PAC)
join tempdb..TEMP_SLUCH t3  with(nolock) on t3.sl_id = t0.sl_id and t3.idcase = t0.idcase
where
@q019type in ('C', 'D', 'R', 'T')
and t0.ONK_T is null
and t0.ds1_t = 0
and dbo.DateTimeDiff('year',t2.dr,t3.date_1)>=18
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.0990 end

--003F.00.1000 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_N', convert(varchar(4), t0.ONK_T) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1000', 'Обязателен при DS1_T=0 и возраст пациента на DATE_Z_1 больше или равен 18 лет'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_PERS t2  with(nolock) on convert(varchar,t2.ID_PAC) = convert(varchar,t1.ID_PAC)
join tempdb..TEMP_SLUCH t3  with(nolock) on t3.sl_id = t0.sl_id and t3.idcase = t0.idcase
where
@q019type in ('C', 'D', 'R', 'T')
and t0.ONK_N is null
and t0.ds1_t = 0
and dbo.DateTimeDiff('year',t2.dr,t3.date_1)>=18
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1000 end

--003F.00.1010 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_M', convert(varchar(4), t0.ONK_T) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1010', 'Обязателен при DS1_T=0 и возраст пациента на DATE_Z_1 больше или равен 18 лет'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_PERS t2  with(nolock) on convert(varchar,t2.ID_PAC) = convert(varchar,t1.ID_PAC)
join tempdb..TEMP_SLUCH t3  with(nolock) on t3.sl_id = t0.sl_id and t3.idcase = t0.idcase
where
@q019type in ('C', 'D', 'R', 'T')
and t0.ONK_M is null
and t0.ds1_t = 0
and dbo.DateTimeDiff('year',t2.dr,t3.date_1)>=18
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1010 end

--003F.00.1020 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'MTSTZ', convert(varchar(1), t0.MTSTZ) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1020'
, 'Поле MTSTZ должно отсутствовать если DS1_T != (1,2)'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and t0.MTSTZ is not null
and not (t0.DS1_T in (1,2))

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1020 end

--003F.00.1030 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SOD', convert(varchar, cast(t0.SOD as money)) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1030'
, 'Поле SOD должно быть заполнено в данном случае'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE

join tempdb..TEMP_ONK_USL t2 with(nolock) on t2.SL_ID = t0.SL_ID and t2.IDCASE = t0.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and t0.SOD is null
and isnull(t2.USL_TIP,0) in (3,4)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1030 end

--003F.00.1040 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SOD', convert(varchar, cast(t0.SOD as money)) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1040'
, 'Поле SOD должно отсутствовать в данном случае'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and t0.SOD is not null
and not exists (select top 1 1 from tempdb..TEMP_ONK_USL t2 with(nolock) where t2.SL_ID = t0.SL_ID and t2.IDCASE = t0.IDCASE and isnull(t2.USL_TIP,0) in (3,4))
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1040 end

--003F.00.1050 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'K_FR', convert(varchar(2), t0.K_FR) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1050'
, 'Поле K_FR должно быть заполнено в данном случае'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_ONK_USL t2 with(nolock) on t2.SL_ID = t0.SL_ID and t2.IDCASE = t0.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and t0.K_FR is null
and isnull(t2.USL_TIP,0) in (3,4)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1050 end

--003F.00.1060 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'K_FR', convert(varchar(2), t0.K_FR) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1060'
, 'Поле K_FR должно отсутствовать в данном случае'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE

where
@q019type in ('C', 'D', 'R', 'T')
and t0.K_FR is not null
and not exists (select top 1 1 from tempdb..TEMP_ONK_USL t2 with(nolock) where t2.SL_ID = t0.SL_ID and t2.IDCASE = t0.IDCASE and isnull(t2.USL_TIP,0) in (3,4))

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1060 end

--003F.00.1070 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'WEI', convert(varchar, cast(t0.WEI as money)) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1070'
, 'Поле WEI должно быть заполнено, если заполнено BSA'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and BSA is not null
and WEI is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1070 end

--003F.00.1080 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'HEI', convert(varchar(3), t0.HEI) as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1080'
, 'Поле HEI должно быть заполнено, если заполнено поле BSA'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and BSA is not null
and HEI is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1080 end

--003F.00.1090 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_USL', null as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1090'
, 'Элемент ONK_USL обязателен в данном случае'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_PERS t2  with(nolock) on convert(varchar,t2.ID_PAC) = convert(varchar,t1.ID_PAC)
join tempdb..TEMP_SLUCH t3  with(nolock) on t3.sl_id = t0.sl_id and t3.idcase = t0.idcase
where
@q019type in ('C', 'D', 'R')
and not exists (select top 1 1 from tempdb..TEMP_ONK_USL t11 where t11.sl_id = t3.sl_id and t11.idcase = t3.idcase)
and USL_OK in (1, 2) 
and DS1_T in (0,1,2)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1090 end

--003F.00.1100 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'N_KSG', N_KSG as ZN_POL ,@NSCHET, 'KSG_KPG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1100'
, 'N_KSG или N_KPG должно быть заполнено'
from tempdb..TEMP_KSG_KPG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'H', 'R')
and t0.N_KSG is null -- мб элемент обязателен
and t0.N_KPG is null
and IDSP=33
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1100 end

--003F.00.1110 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'N_KSG', N_KSG as ZN_POL ,@NSCHET, 'KSG_KPG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1110'
, 'N_KSG или N_KPG должно быть заполнено'
from tempdb..TEMP_KSG_KPG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'H', 'R')
and t0.N_KSG is not null -- элемент должен отсуствовать
and t0.N_KPG is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1110 end

--003F.00.1130 begin
--повторяет 003F.00.1110
--003F.00.1130 end

--003F.00.1140 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'IT_SL', convert(varchar, cast(t0.IT_SL as money)) as ZN_POL ,@NSCHET, 'KSG_KPG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1140'
, 'Поле IT_SL обязательно при наличии SL_KOEF'
from tempdb..TEMP_KSG_KPG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.idcase = t2.idcase and t0.sl_id = t2.sl_id
where
@q019type in ('C', 'D', 'H', 'R')
and t0.IT_SL is null -- мб элемент обязателен
and exists (select top 1 1 from tempdb..TEMP_SL_KOEF t11 with(nolock) where t11.sl_id = t2.sl_id and t11.idcase = t2.idcase)

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1140 end

--003F.00.1150 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'IT_SL', convert(varchar, cast(t0.IT_SL as money)) as ZN_POL ,@NSCHET, 'KSG_KPG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1150'
, 'IT_SL должен отсуствовать при отсуствии SL_KOEF'
from tempdb..TEMP_KSG_KPG t0 with(nolock)
join tempdb..TEMP_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE and t0.SL_ID = t1.SL_ID
join tempdb..TEMP_Z_SLUCH t2 with(nolock) on t0.IDCASE = t2.IDCASE
where
@q019type in ('C', 'D', 'H', 'R')
and t0.IT_SL is not null -- элемент должен отсуствовать
and not exists (select top 1 1 from tempdb..TEMP_SL_KOEF t11 with(nolock) where t11.sl_id = t1.sl_id and t11.idcase = t1.idcase)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1150 end

--003F.00.1180 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAPR_MO', NAPR_MO as ZN_POL ,@NSCHET, 'NAPR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1180', 'Элемент NAPR_MO должен отсуствовать если он равен CODE_MO.'
from tempdb..TEMP_NAPR t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SCHET t2 on 1 = 1
where
@q019type in ('C', 'D', 'R', 'T')
and NAPR_MO=CODE_MO
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'02.11.2019',104)
--003F.00.1180 end

--003F.00.1190 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'MET_ISSL', convert(varchar(2), t0.MET_ISSL) as ZN_POL ,@NSCHET, 'NAPR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1190'
, 'Поле MET_ISSL обязательно при NAPR_V=3'
from tempdb..TEMP_NAPR t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and  MET_ISSL is null
and NAPR_V=3
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1190 end

--003F.00.1200 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'MET_ISSL', convert(varchar(2), t0.MET_ISSL) as ZN_POL ,@NSCHET, 'NAPR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1200'
, 'Поле MET_ISSL должно отсутствовать при NAPR_V != 3'
from tempdb..TEMP_NAPR t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and MET_ISSL is not null
and NAPR_V != 3
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1200 end

--003F.00.1210 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAPR_USL', NAPR_USL as ZN_POL ,@NSCHET, 'NAPR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1210'
, 'Поле NAPR_USL обязательно, если MET_ISSL присутствует'
from tempdb..TEMP_NAPR t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and NAPR_USL is null
and MET_ISSL is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1210 end

--003F.00.1220 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAPR_USL', NAPR_USL as ZN_POL ,@NSCHET, 'NAPR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1220'
, 'Поле NAPR_USL должно отсутствовать, если MET_ISSL отсутствует'
from tempdb..TEMP_NAPR t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and NAPR_USL is not null
and MET_ISSL is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1220 end

--003F.00.1230 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DT_CONS', convert(varchar(10),t0.DT_CONS,104) as ZN_POL ,@NSCHET, 'CONS', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1230'
, 'Поле DT_CONS обязательно при PR_CONS={1,2,3}'
from tempdb..TEMP_CONS t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and PR_CONS in (1,2,3)
and DT_CONS is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1230 end

--003F.00.1240 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DT_CONS', convert(varchar(10),t0.DT_CONS,104) as ZN_POL ,@NSCHET, 'CONS', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1240'
, 'Поле DT_CONS должно отсутствовать при PR_CONS<>{1,2,3}'
from tempdb..TEMP_CONS t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and not (PR_CONS in (1,2,3))
and DT_CONS is not null

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1240 end

--003F.00.1250 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DIAG_RSLT', convert(varchar(3), t0.DIAG_RSLT) as ZN_POL ,@NSCHET, 'B_DIAG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1250'
, 'Поле DIAG_RSLT обязательно при REC_RSLT =1'
from tempdb..TEMP_B_DIAG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and REC_RSLT =1
and DIAG_RSLT is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1250 end

--003F.00.1260 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'REC_RSLT', convert(varchar(1), t0.REC_RSLT) as ZN_POL ,@NSCHET, 'B_DIAG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1260'
, 'Поле REC_RSLT обязательно при наличии DIAG_RSLT'
from tempdb..TEMP_B_DIAG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and REC_RSLT is null
and DIAG_RSLT is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1260 end

--003F.00.1270 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAZ_SP', convert(varchar(4), t0.NAZ_SP) as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1270'
, 'Поле NAZ_SP обязательно  при NAZ_R={1, 2}'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('X')
and t0.NAZ_SP is null
and t0.NAZ_R in (1,2)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1270 end

--003F.00.1280 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAZ_SP', convert(varchar(4), t0.NAZ_SP) as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1280'
, 'Поле NAZ_SP должно отсутствовать'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('X')
and t0.NAZ_SP is not null
and not (isnull(t0.NAZ_R,0) in (1,2))
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1280 end

--003F.00.1290 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAZ_V', convert(varchar(1), t0.NAZ_V) as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1290'
, 'Поле NAZ_V обязательно при NAZ_R=3'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_V029_MET_ISSL t2 with(nolock) on t2.IDMET = t0.NAZ_V
where
@q019type in ('X')
and t0.NAZ_R=3
and 
(
    t0.NAZ_V is null
    or
    (
        t0.NAZ_V is not null
        and t2.IDMET is null
    )
)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1290 end

--003F.00.1300 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAZ_V', convert(varchar(1), t0.NAZ_V) as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1300'
, 'Поле NAZ_V должно отсутствовать NAZ_R<>3'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE

where
@q019type in ('X')
and isnull(t0.NAZ_R,0) !=3
and t0.NAZ_V is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1300 end

--003F.00.1310 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAZ_USL', NAZ_USL as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1310'
, 'Поле NAZ_USL обязательно при NAZ_R=3 и DS_ONK=1'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.sl_id = t2.sl_id and t0.idcase = t2.idcase
where
@q019type in ('X')
and isnull(NAZ_R,0) =3 
and isnull(DS_ONK,0) = 1
and t0.NAZ_USL is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1310 end

--003F.00.1320 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAZ_USL', NAZ_USL as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1320'
, 'Поле NAZ_USL должно отсутствовать если NAZ_R<>3 или DS_ONK=0'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.sl_id = t2.sl_id and t0.idcase = t2.idcase
where
@q019type in ('X')
and (
isnull(t0.naz_r,0) != 3
or DS_ONK = 0)
and NAZ_USL is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1320 end

--003F.00.1330 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAPR_DATE', convert(varchar(10),t0.NAPR_DATE,104) as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1330'
, 'Поле NAPR_DATE обязательно при NAZ_R={2,3} и DS_ONK=1'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.sl_id = t2.sl_id and t0.idcase = t2.idcase
where
@q019type in ('X')
and isnull(t0.NAZ_R,0) in (2,3)
and DS_ONK = 1
and NAPR_DATE is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1330 end

--003F.00.1340 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAPR_DATE', convert(varchar(10),t0.NAPR_DATE,104) as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1340'
, 'Поле NAPR_DATE должно отсутствовать если NAZ_R<>{2,3} или DS_ONK=0'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE

join tempdb..TEMP_SLUCH t2 with(nolock) on t0.sl_id = t2.sl_id and t0.idcase = t2.idcase
where
@q019type in ('X')
and t0.NAPR_DATE is not null
and (not (NAZ_R in (2,3))
or 
DS_ONK = 0 )
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1340 end

--003F.00.1350 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAPR_MO', NAPR_MO as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1350'
, 'Поле NAPR_MO обязательно при NAZ_R={2,3} и DS_ONK=1'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.sl_id = t2.sl_id and t0.idcase = t2.idcase
where
@q019type in ('X')
and isnull(t0.NAZ_R,0) in (2,3)
and DS_ONK = 1
and NAPR_MO is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1350 end

--003F.00.1360 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAPR_MO', NAPR_MO as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1360'
, 'Поле NAPR_MO должно отсутствовать если NAZ_R<>{2,3} или DS_ONK=0'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.sl_id = t2.sl_id and t0.idcase = t2.idcase
where
@q019type in ('X')
and t0.NAPR_MO is not null
and (not (NAZ_R in (2,3))
or 
DS_ONK = 0 )
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1360 end

--003F.00.1370 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAZ_PMP', convert(varchar(3), t0.NAZ_PMP) as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1370'
, 'Поле NAZ_PMP обязательно при NAZ_R={4, 5}'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE

join tempdb..TEMP_SLUCH t2 with(nolock) on t0.sl_id = t2.sl_id and t0.idcase = t2.idcase
where
@q019type in ('X')
and NAZ_PMP is null
and NAZ_R in (4, 5)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1370 end

--003F.00.1380 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAZ_PMP', convert(varchar(3), t0.NAZ_PMP) as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1380'
, 'Поле NAZ_PMP должно отсутствовать если NAZ_R<>{4, 5}'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.sl_id = t2.sl_id and t0.idcase = t2.idcase
where
@q019type in ('X')
and not (NAZ_R in (4, 5))
and NAZ_PMP is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1380 end

--003F.00.1390 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAZ_PK', convert(varchar(3), t0.NAZ_PK) as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1390'
, 'Поле NAZ_PK обязательно при NAZ_R=6'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.sl_id = t2.sl_id and t0.idcase = t2.idcase
where
@q019type in ('X')
and NAZ_R=6
and NAZ_PK is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1390 end

--003F.00.1400 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAZ_PK', convert(varchar(3), t0.NAZ_PK) as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1400'
, 'Поле NAZ_PK должен отсутствовать если NAZ_R<>6'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.sl_id = t2.sl_id and t0.idcase = t2.idcase
where
@q019type in ('X')
and NAZ_R<>6
and NAZ_PK is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1400 end

--003F.00.1410 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'HIR_TIP', convert(varchar(1), t0.HIR_TIP) as ZN_POL ,@NSCHET, 'ONK_USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1410'
, 'Поле HIR_TIP обязательно при USL_TIP=1'
from tempdb..TEMP_ONK_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and USL_TIP=1
and HIR_TIP is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1410 end

--003F.00.1420 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'HIR_TIP', convert(varchar(1), t0.HIR_TIP) as ZN_POL ,@NSCHET, 'ONK_USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1420'
, 'Поле HIR_TIP должно отсутствовать если USL_TIP<>1'
from tempdb..TEMP_ONK_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and USL_TIP != 1
and HIR_TIP is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1420 end

--003F.00.1430 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'LEK_TIP_L', convert(varchar(1), t0.LEK_TIP_L) as ZN_POL ,@NSCHET, 'ONK_USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1430'
, 'Поле LEK_TIP_L обязательно USL_TIP=2'
from tempdb..TEMP_ONK_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and USL_TIP=2
and LEK_TIP_L is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1430 end

--003F.00.1440 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'LEK_TIP_L', convert(varchar(1), t0.LEK_TIP_L) as ZN_POL ,@NSCHET, 'ONK_USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1440'
, 'Поле LEK_TIP_L должно отсутствовать если USL_TIP<>2'
from tempdb..TEMP_ONK_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and USL_TIP != 2
and LEK_TIP_L is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1440 end

--003F.00.1450 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'LEK_TIP_V', convert(varchar(1), t0.LEK_TIP_V) as ZN_POL ,@NSCHET, 'ONK_USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1450'
, 'Поле LEK_TIP_V обязательно если USL_TIP=2'
from tempdb..TEMP_ONK_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and USL_TIP=2
and LEK_TIP_V is null

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1450 end

--003F.00.1460 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'LEK_TIP_V', convert(varchar(1), t0.LEK_TIP_V) as ZN_POL ,@NSCHET, 'ONK_USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1460'
, 'Поле LEK_TIP_V должно отсутствовать если USL_TIP<>2'
from tempdb..TEMP_ONK_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and USL_TIP != 2
and LEK_TIP_V is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1460 end

--003F.00.1470 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'LUCH_TIP', convert(varchar(1), t0.LUCH_TIP) as ZN_POL ,@NSCHET, 'ONK_USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1470'
, 'Поле LUCH_TIP обязательно если USL_TIP={3, 4}'
from tempdb..TEMP_ONK_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and USL_TIP in (3, 4)
and LUCH_TIP is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1470 end

--003F.00.1480 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'LUCH_TIP', convert(varchar(1), t0.LUCH_TIP) as ZN_POL ,@NSCHET, 'ONK_USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1480'
, 'Поле LUCH_TIP должно отсутствовать если USL_TIP<>{3, 4}'
from tempdb..TEMP_ONK_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and not (USL_TIP in (3, 4))
and LUCH_TIP is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1480 end

--003F.00.1490 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'LEK_PR', null as ZN_POL ,@NSCHET, 'ONK_USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1490'
, 'Поле LEK_PR обязательно если USL_TIP={2, 4}'
from tempdb..TEMP_ONK_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and USL_TIP in (2, 4)
and not exists (select top 1 1 from tempdb..TEMP_LEK_PR_DATE_INJ t2 with(nolock) where t2.SL_ID = t0.SL_ID and t2.IDCASE = t0.IDCASE)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1490 end

--003F.00.1500 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'LEK_PR', null as ZN_POL ,@NSCHET, 'ONK_USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1500'
, 'Поле LEK_PR должно отсутствовать если USL_TIP<>{2, 4}'
from tempdb..TEMP_ONK_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and USL_TIP not in (2, 4)
and exists (
	select top 1 1 
	from tempdb..TEMP_LEK_PR_DATE_INJ t2 with(nolock) 
	where t2.SL_ID = t0.SL_ID
	and t2.IDCASE = t0.IDCASE
	)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1500 end

--003F.00.1510 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'USL', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1510'
, 'Поле VID_VME обязательно если (C00.0<=DS1<D10или (DS1=D70 и (C00.0<=DS2<C81 или DS2=C97))) и USL_TIP={1,3,4}'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1  with(nolock) on t0.idcase = t1.idcase
left join tempdb..TEMP_ONK_USL t2 with(nolock) on t0.SL_ID = t2.SL_ID and t0.IDCASE = t2.IDCASE
join tempdb..TEMP_USL t3 on t3.SL_ID = t0.SL_ID and t3.IDCASE = t0.IDCASE
where
@q019type in ('T')
and t3.VID_VME is null
and (
DS1 like 'C%'
or DS1 like 'D0%'
or (
         DS1 = 'D70'
         and exists (select top 1 1 from tempdb..TEMP_DS2 t3 where ((DS2>='C00' and DS2<'C81') or DS2 like 'C97%') and  t3.SL_ID = t0.SL_ID and t3.IDCASE = t0.IDCASE)
    )
)
and isnull(t2.USL_TIP,0) in (1,3,4)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'31.03.2020',104)
--003F.00.1510 end

--003F.00.1511 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VID_VME', null as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1511'
, 'Элемент обязателен, если C00.0<=DS1<D10 и USL_TIP={1,3,4}'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.IDCASE = t2.IDCASE and t0.SL_ID = t2.SL_ID
join tempdb..TEMP_ONK_USL t3 with(nolock) on t3.IDCASE = t2.IDCASE and t3.SL_ID = t2.SL_ID
where
@q019type in ('T')
and t0.VID_VME is null -- мб элемент обязателен
and (DS1 like 'C%' or DS1 like 'D0%')
and USL_TIP in (1,3,4)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--003F.00.1511 end

--003F.00.1512 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VID_VME', null as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1511'
, 'Элеент обязателен'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.IDCASE = t2.IDCASE and t0.SL_ID = t2.SL_ID
join tempdb..TEMP_ONK_USL t3 with(nolock) on t3.IDCASE = t2.IDCASE and t3.SL_ID = t2.SL_ID
where
@q019type in ('T')
and t0.VID_VME is null -- мб элемент обязателен
and (DS1 like 'C%' or DS1 like 'D0%' or (DS1 >= 'D45' and DS1 < 'D48'))
and USL_TIP in (1,3,4)
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--003F.00.1512 end

--003F.00.1520 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VID_VME', VID_VME as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1520'
, 'Поле VID_VME обязательно если (C00.0<=DS1<D10или (DS1=D70 и (C00.0<=DS2<C81 или DS2=C97))) и USL_TIP={1,3,4, 6}'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE and t0.sl_id = t1.sl_Id
left join tempdb..TEMP_ONK_USL t2 with(nolock) on t0.SL_ID = t2.SL_ID and t0.IDCASE = t2.IDCASE
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t1.n_zap = t3.n_zap
where
@q019type in ('C', 'D', 'R')
and t0.VID_VME is null -- мб элемент обязателен
and (
DS1 like 'C%'
or DS1 like 'D0%'
or (
	DS1='D70' 
	and exists
		(
			select top 1 1
			from tempdb..TEMP_DS2 t2 
			where
			((DS2>='C00' and DS2<'C81') or DS2 like 'C97%') and t2.SL_ID = t1.SL_ID and t2.IDCASE= t1.IDCASE
		)
	)
)
and isnull(t2.USL_TIP,0) in (1,3,4,6)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and DATE_Z_2 <= convert(date,'31.03.2020',104)
--003F.00.1520 end

--003F.00.1521 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VID_VME', null as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1521'
, 'Элемент обязателен, если C00.0<=DS1<D10 и USL_TIP={1,3,4, 6}'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.IDCASE = t2.IDCASE and t0.SL_ID = t2.SL_ID
join tempdb..TEMP_ONK_USL t3 with(nolock) on t3.IDCASE = t2.IDCASE and t3.SL_ID = t2.SL_ID
where
@q019type in ('C', 'D', 'R')
and t0.VID_VME is null -- мб элемент обязателен
and (DS1 like 'C%' or DS1 like 'D0%')
and USL_TIP in (1,3,4,6)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--003F.00.1521 end

--003F.00.1522 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VID_VME', null as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1521'
, 'Элемент обязателен'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.IDCASE = t2.IDCASE and t0.SL_ID = t2.SL_ID
join tempdb..TEMP_ONK_USL t3 with(nolock) on t3.IDCASE = t2.IDCASE and t3.SL_ID = t2.SL_ID
where
@q019type in ('C', 'D', 'R')
and t0.VID_VME is null -- мб элемент обязателен
and (DS1 like 'C%' or DS1 like 'D0%' or (DS1 >= 'D45' and DS1 < 'D48'))
and USL_TIP in (1,3,4,6)
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--003F.00.1522 end

--003F.00.1530 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'FAM', t0.FAM as ZN_POL ,@NSCHET, 'PERS', null, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.1530'
, 'Поле FAM обязательно если NOVOR=0 и DOST<>2'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_PACIENT t1 with(nolock) on convert(varchar(36),t0.ID_PAC)= convert(varchar(36),t1.ID_PAC)
join tempdb..TEMP_ZAP t2 with(nolock) on t2.N_ZAP= t1.N_ZAP
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t1.n_zap
where
t1.NOVOR=0 and not exists(select top 1 1 from tempdb..TEMP_DOST t3 where t3.dost = '2' and convert(varchar(36),t3.ID_PAC)= convert(varchar(36),t0.ID_PAC) )
and t0.fam is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1530 end

--003F.00.1540 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'FAM', t0.FAM as ZN_POL ,@NSCHET, 'PERS', null, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.1540'
, 'Поле FAM должно отсутствовать если NOVOR<>0 или DOST=2'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_PACIENT t1 with(nolock) on convert(varchar(36),t0.ID_PAC)= convert(varchar(36),t1.ID_PAC)
join tempdb..TEMP_ZAP t2 with(nolock) on t2.N_ZAP= t1.N_ZAP
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t1.n_zap
where
t0.fam is not null and
not (t1.NOVOR=0 and not exists(select top 1 1 from tempdb..TEMP_DOST t3 where t3.dost = '2' and convert(varchar(36),t3.ID_PAC)= convert(varchar(36),t0.ID_PAC) ))
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1540 end

--003F.00.1550 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'FAM_P', t0.FAM_P as ZN_POL ,@NSCHET, 'PERS', null, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.1550'
, 'Поле FAM_P обязательно если NOVOR<>0 и DOST_P<>2'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_PACIENT t1 with(nolock) on convert(varchar(36),t0.ID_PAC)= convert(varchar(36),t1.ID_PAC)
join tempdb..TEMP_ZAP t2 with(nolock) on t2.N_ZAP= t1.N_ZAP
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t1.n_zap
where
t1.NOVOR!=0 and not exists(select top 1 1 from tempdb..TEMP_DOST_P t3 where t3.dost_p = '2' and convert(varchar(36),t3.ID_PAC)= convert(varchar(36),t0.ID_PAC)  )
and t0.fam_p is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1550 end

--003F.00.1560 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'FAM_P', t0.FAM_P as ZN_POL ,@NSCHET, 'PERS', null, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.1560'
, 'Поле FAM_P должно отсутствовать если DOST_P=2 или NOVOR=0'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_PACIENT t1 with(nolock) on convert(varchar(36),t0.ID_PAC)= convert(varchar(36),t1.ID_PAC)
join tempdb..TEMP_ZAP t2 with(nolock) on t2.N_ZAP= t1.N_ZAP
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t1.n_zap
where
t0.fam_p is not null
and not (t1.NOVOR!=0 and not exists(select top 1 1 from tempdb..TEMP_DOST_P t3 where t3.dost_p = '2' and convert(varchar(36),t3.ID_PAC)= convert(varchar(36),t0.ID_PAC) ))
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1560 end

--003F.00.1570 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'IM', t0.IM as ZN_POL ,@NSCHET, 'PERS', null, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.1570'
, 'Поле IM обязательно если NOVOR=0 и DOST<>3'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_PACIENT t1 with(nolock) on convert(varchar(36),t0.ID_PAC)= convert(varchar(36),t1.ID_PAC)
join tempdb..TEMP_ZAP t2 with(nolock) on t2.N_ZAP= t1.N_ZAP
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t1.n_zap
where
t1.NOVOR=0 and not exists(select top 1 1 from tempdb..TEMP_DOST t3 where t3.dost = '3' and convert(varchar(36),t3.ID_PAC)= convert(varchar(36),t0.ID_PAC) )
and t0.im is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1570 end

--003F.00.1580 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'IM', t0.IM as ZN_POL ,@NSCHET, 'PERS', null, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.1580'
, 'Поле IM должно отсутствовать если NOVOR<>0 или DOST=3'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_PACIENT t1 with(nolock) on convert(varchar(36),t0.ID_PAC)= convert(varchar(36),t1.ID_PAC)
join tempdb..TEMP_ZAP t2 with(nolock) on t2.N_ZAP= t1.N_ZAP
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t1.n_zap
where
t0.im is not null
and not (t1.NOVOR=0 and not exists(select top 1 1 from tempdb..TEMP_DOST t3 where t3.dost = '3' and convert(varchar(36),t3.ID_PAC)= convert(varchar(36),t0.ID_PAC) ))
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1580 end

--003F.00.1590 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'IM_P', IM_P as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t0.ID_PAC, t0.IDCASE,null as SL_ID, null as IDSERV, '003F.00.1590'
, 'Поле IM_P обязательно если NOVOR<>0 и DOST_P<>3'
from tempdb..TEMP_Z_SLUCH t0
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t0.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on t2.n_zap = t0.n_zap
left join tempdb..TEMP_DOST_P t3 on convert(varchar(36),t3.ID_PAC)=convert(varchar(36),t0.ID_PAC)
where
IM_P is null -- мб элемент обязателен
and NOVOR!=0 and t3.DOST_P!='3'

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1590 end

--003F.00.1600 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'IM_P', IM_P as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV, '003F.00.1600'
, 'Поле IM_P должно отсутствовать если DOST_P=3 или NOVOR=0 '
from tempdb..TEMP_Z_SLUCH t0
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t0.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on t2.n_zap = t0.n_zap
where
IM_P is not null -- элемент должен отсуствовать
and (NOVOR=0 or 
exists(select top 1 1 from tempdb..TEMP_DOST_P t3 where t3.dost_p = '3' and convert(varchar(36),t3.ID_PAC)= convert(varchar(36),t0.ID_PAC) )
)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1600 end

--003F.00.1610 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'OT', OT as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t0.ID_PAC, t0.IDCASE,null as SL_ID, null as IDSERV, '003F.00.1610'
, 'Поле OT должно отсутствовать если NOVOR<>0 или DOST=1'
from tempdb..TEMP_Z_SLUCH t0
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t0.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on t2.n_zap = t0.n_zap
left join tempdb..TEMP_DOST t3 on convert(varchar(36),t3.ID_PAC)=convert(varchar(36),t0.ID_PAC)
where
OT is not null -- элемент должен отсуствовать
and (NOVOR!=0 or t3.DOST='1')
and DATE_Z_2 >= convert(date,'01.11.2019',104)
union all
select 'OT', OT as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t0.ID_PAC, t0.IDCASE,null as SL_ID, null as IDSERV, '003F.00.1610.1'
, ''
from tempdb..TEMP_Z_SLUCH t0
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t0.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on t2.n_zap = t0.n_zap
left join tempdb..TEMP_DOST t3 on convert(varchar(36),t3.ID_PAC)=convert(varchar(36),t0.ID_PAC)
where
OT is null -- элемент должен отсуствовать
and (NOVOR=0 and t3.DOST!='1')
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1610 end

--003F.00.1620 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'OT_P', OT_P as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV, '003F.00.1620'
, 'Поле OT_P должно отсутствовать если NOVOR=0 или DOST_P=1 '
from tempdb..TEMP_Z_SLUCH t0
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t0.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on t2.n_zap = t0.n_zap
left join tempdb..TEMP_DOST_P t3 on convert(varchar(36),t3.ID_PAC)=convert(varchar(36),t0.ID_PAC)
where
OT_P is not null -- элемент должен отсуствовать
and (--NOVOR=0 or 
t3.DOST_P='1')

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1620 end

--003F.00.1630 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DOST', convert(varchar(1), t3.DOST) as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t0.ID_PAC, t0.IDCASE,null as SL_ID, null as IDSERV, '003F.00.1630'
, 'Поле DOST обязательно если IM отсутствует и NOVOR=0'
from tempdb..TEMP_Z_SLUCH t0
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t0.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on t2.n_zap = t0.n_zap
left join tempdb..TEMP_DOST t3 on convert(varchar(36),t3.ID_PAC)=convert(varchar(36),t0.ID_PAC)
where
t3.DOST is null -- мб элемент обязателен
and IM is null and NOVOR=0
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1630 end

--003F.00.1640 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DOST', convert(varchar(1), t3.DOST) as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV, '003F.00.1640'
, 'Поле DOST обязательно если FAM отсутствует и NOVOR=0'
from tempdb..TEMP_Z_SLUCH t0
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t0.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on t2.n_zap = t0.n_zap
left join tempdb..TEMP_DOST t3 on convert(varchar(36),t3.ID_PAC)=convert(varchar(36),t0.ID_PAC)
where
t3.DOST is null -- мб элемент обязателен
and FAM is null and NOVOR=0
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1640 end

--003F.00.1650 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DOST_P', convert(varchar(1), t3.DOST_P) as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t0.ID_PAC, t0.IDCASE,null as SL_ID, null as IDSERV, '003F.00.1650'
, 'Поле DOST_P обязательно если IM_P отсутствует и NOVOR<>0'
from tempdb..TEMP_Z_SLUCH t0
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t0.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on t2.n_zap = t0.n_zap
left join tempdb..TEMP_DOST_P t3 on convert(varchar(36),t3.ID_PAC)=convert(varchar(36),t0.ID_PAC)
where
t3.DOST_P is null -- мб элемент обязателен
and IM_P is null and NOVOR!=0
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1650 end

--003F.00.1660 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DOST_P', convert(varchar(1), t3.DOST_P) as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t0.ID_PAC, t0.IDCASE,null as SL_ID, null as IDSERV, '003F.00.1660'
, 'Поле DOST_P обязательно если FAM_P отсутствует и NOVOR<>0'
from tempdb..TEMP_Z_SLUCH t0
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t0.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on t2.n_zap = t0.n_zap
left join tempdb..TEMP_DOST_P t3 on convert(varchar(36),t3.ID_PAC)=convert(varchar(36),t0.ID_PAC)
where
t3.DOST_P is null -- мб элемент обязателен
and FAM_P  is null and NOVOR!=0
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1660 end

--003F.00.1670 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'W_P', convert(varchar(1), W_P) as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV, '003F.00.1670'
, 'Поле W_P обязательно если NOVOR<>0'
from tempdb..TEMP_Z_SLUCH t0
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t0.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on t2.n_zap = t0.n_zap
where
W_P is null -- мб элемент обязателен
and NOVOR!=0
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1670 end

--003F.00.1680 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'W_P', convert(varchar(1), W_P) as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t0.ID_PAC, t0.IDCASE,null as SL_ID, null as IDSERV, '003F.00.1680'
, 'Поле W_P должно отсутствовать если NOVOR=0'
from tempdb..TEMP_Z_SLUCH t0
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t0.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on t2.n_zap = t0.n_zap
where
W_P is not null -- элемент должен отсуствовать
and NOVOR=0
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1680 end

--003F.00.1690 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DR_P', convert(varchar(10),DR_P,104) as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV, '003F.00.1690'
, 'Поле DR_P обязательно если NOVOR<>0'
from tempdb..TEMP_Z_SLUCH t0
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t0.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on t2.n_zap = t0.n_zap
where
DR_P is null -- мб элемент обязателен
and NOVOR!=0
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1690 end

--003F.00.1700 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DR_P', convert(varchar(10),DR_P,104) as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t0.ID_PAC, t0.IDCASE,null as SL_ID, null as IDSERV, '003F.00.1700'
, 'Поле DR_P должно отсутствовать если NOVOR=0'
from tempdb..TEMP_Z_SLUCH t0
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t0.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on t2.n_zap = t0.n_zap
where
DR_P is not null -- элемент должен отсуствовать
and NOVOR=0
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1700 end

--003F.00.1720 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DOCTYPE', DOCTYPE as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV, '003F.00.1720'
, 'Поле DOCTYPE обязательно если VPOLIS<>3'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar,t0.ID_PAC) = convert(varchar,t1.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on  t2.n_zap = t0.n_zap
where
DOCTYPE is null -- мб элемент обязателен
and VPOLIS!=3
--and @type = 554
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1720 end

--003F.00.1721 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DOCTYPE', convert(varchar(10),t0.DOCTYPE) as ZN_POL, @NSCHET, 'PERS', null , t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.1721'
, 'Поле обязательно, если DOCNUM присутствует'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_PACIENT t1 with(nolock) on convert(varchar(36),t0.ID_PAC) = convert(varchar(36),t1.ID_PAC)
join tempdb..TEMP_ZAP t2 with(nolock) on t1.N_ZAP= t2.N_ZAP
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t1.n_zap
where
t0.DOCTYPE is null -- мб элемент обязателен
and t0.DOCNUM is not null
--and @type = 554
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--003F.00.1721 end

--003F.00.1730 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DOCSER', DOCSER as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV, '003F.00.1730'
, 'Поле DOCSER обязательно если VPOLIS<>3'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar,t0.ID_PAC) = convert(varchar,t1.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on  t2.n_zap = t0.n_zap
where
DOCSER is null -- мб элемент обязателен
and VPOLIS!=3
--and @type = 554
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1730 end

--003F.00.1740 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DOCNUM', DOCNUM as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV, '003F.00.1740'
, 'Поле DOCNUM обязательно если VPOLIS<>3'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar,t0.ID_PAC) = convert(varchar,t1.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on  t2.n_zap = t0.n_zap
where
DOCNUM is null -- мб элемент обязателен
and VPOLIS!=3
--and @type = 554
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1740 end

--003F.00.1770 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SL_ID', SL_ID as ZN_POL ,@NSCHET, 'SANK', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1770'
, 'Поле SL_ID обязательно если S_SUM<>0'
from tempdb..TEMP_SANK t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
and isnull(t0.s_sum,0) != 0
and t0.sl_id is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1770 end

--003F.00.1780 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'S_OSN', convert(varchar(3), t0.S_OSN) as ZN_POL ,@NSCHET, 'SANK', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.1780'
, 'Поле S_OSN обязательно если S_SUM<>0'
from tempdb..TEMP_SANK t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
and isnull(t0.s_sum,0) != 0
and t0.S_OSN is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.1780 end

--003F.00.1811 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DOCDATE', convert(varchar(10),t0.DOCDATE,104) as ZN_POL ,@NSCHET, 'PERS', null , t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.1811'
, 'Поле обязательно, если DOCNUM присутствует'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_PACIENT t1 with(nolock) on convert(varchar(36),t0.ID_PAC) = convert(varchar(36),t1.ID_PAC)
join tempdb..TEMP_ZAP t2 with(nolock) on t1.N_ZAP= t2.N_ZAP
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t1.n_zap
where
t0.DOCDATE is null -- мб элемент обязателен
and t0.DOCNUM is not null
and @type = 554
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--003F.00.1811 end

--003F.00.1822 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DOCORG', t0.DOCORG as ZN_POL, @NSCHET, 'PERS', null , t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.1822'
, 'Поле обязательно, если DOCNUM присутствует'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_PACIENT t1 with(nolock) on convert(varchar(36),t0.ID_PAC) = convert(varchar(36),t1.ID_PAC)
join tempdb..TEMP_ZAP t2 with(nolock) on t1.N_ZAP= t2.N_ZAP
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t1.n_zap
where
t0.DOCORG is null -- мб элемент обязателен
and t0.DOCNUM is not null
and @type = 554
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--003F.00.1822 end

--003F.00.2170 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NPOLIS', NPOLIS as ZN_POL ,@NSCHET, 'PACIENT', t0.N_ZAP, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '003F.00.2170'
, 'Поле NPOLIS обязательно'
from tempdb..TEMP_PACIENT t0 with(nolock)
join tempdb..TEMP_ZAP t1 with(nolock) on t0.N_ZAP= t1.N_ZAP
join tempdb..TEMP_Z_SLUCH t2 with(nolock) on t0.n_zap = t2.n_zap
where
@q019type in ('C', 'H', 'T', 'X')
and t0.NPOLIS is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.2170 end

--003F.00.2350 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'KD_Z', convert(varchar(3), t0.KD_Z) as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.2350'
, 'Не заполнено количество койко-дней (KD_Z)'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('T')
and KD_Z is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.2350 end

--003F.00.2381 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'RSLT_D', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.2381'
, 'RSLT_D обязательно при P_OTK=0'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('X')
and t0.RSLT_D is null -- мб элемент обязателен
and P_OTK=0
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--003F.00.2381 end

--003F.00.2382 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'RSLT_D', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '003F.00.2382'
, 'При P_OTK=1 RSLT_D должен отсутствовать'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('X')
and t0.RSLT_D is not null -- элемент должен отсуствовать
and P_OTK=1
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--003F.00.2382 end

--003F.00.2452 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DS1', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.2452'
, 'DS1 обязателен если P_OTK=0'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('X')
and t0.DS1 is null -- мб элемент обязателен
and P_OTK=0
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--003F.00.2452 end

--003F.00.2571 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PR_D_N', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.2571'
, 'PR_D_N обязателен если P_OTK=0 или DS1 присутствует'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('X')
and t0.PR_D_N is null -- мб элемент обязателен
and (P_OTK=0 or DS1 is not null)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--003F.00.2571 end

--003F.00.2600 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ONK_USL', null as ZN_POL ,@NSCHET, 'ONK_SL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.2600'
, 'Элемент ONK_USL обязательно если тег ONK_SL присутствует'
from tempdb..TEMP_ONK_SL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('T')
and not exists (select top 1 1 from tempdb..TEMP_ONK_USL t10 with(nolock) where t10.sl_id = t0.sl_id and t10.idcase = t0.idcase)

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.2600 end

--003F.00.2800 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'S_SUM', convert(varchar, cast(t0.S_SUM as money)) as ZN_POL ,@NSCHET, 'SANK', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.2800'
, 'Поле S_SUM обязательно'
from tempdb..TEMP_SANK t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
and t0.S_SUM is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--003F.00.2800 end

--003F.00.2961 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PRVS', null as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.2961'
, 'Элемент обязателен'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.PRVS is null -- мб элемент обязателен
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--003F.00.2961 end

--003F.00.2962 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PRVS', null as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.2962'
, 'Элемент обязателен, если USL/P_OTK=0'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('X')
and t0.PRVS is null -- мб элемент обязателен
and t0.P_OTK=0
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--003F.00.2962 end

--003F.00.2963 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'PRVS', null as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, t0.IDSERV as IDSERV, '003F.00.2963'
, 'элемент должен отсутствовать, если P_OTK=1'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('X')
and t0.PRVS is not null -- элемент должен отсуствовать
and t0.P_OTK=1
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--003F.00.2963 end

--003F.00.2971 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CODE_MD', null as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.2971'
, 'Элемент обязателен'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'H', 'T')
and t0.CODE_MD is null -- мб элемент обязателен
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--003F.00.2971 end

--003F.00.2972 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CODE_MD', null as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.2972'
, 'Элемент обязателен, если Тег SL.USL присутствует и ZL_LIST/ZAP/Z_SL/SL/USL/P_OTK=0'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('X')
and t0.CODE_MD is null -- мб элемент обязателен
and t0.P_OTK=0
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--003F.00.2972 end

--003F.00.2973 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CODE_MD', null as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.2973'
, 'элемент должен отсутствовать, если ZL_LIST/ZAP/Z_SL/SL/USL/P_OTK=1'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('X')
and t0.CODE_MD is not null-- элемент должен отсуствовать
and t0.P_OTK=1


and DATE_Z_2 >= convert(date,'01.04.2020',104)
--003F.00.2973 end

--003F.00.3051 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAZ_R', null as ZN_POL ,@NSCHET, 'NAZ', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '003F.00.3051'
, 'NAZ_R обязателен при RSLT_D={3,4,5,31,32}'
from tempdb..TEMP_NAZ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('X')
and t0.NAZ_R is null -- мб элемент обязателен
and RSLT_D in (3,4,5,31,32)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--003F.00.3051 end

--004F.00.0230 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NPOLIS', NPOLIS as ZN_POL ,@NSCHET, 'PACIENT', t0.N_ZAP, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '004F.00.0230'
, 'NPOLIS должно соответствовать маске ХХХХХХХХХХХХХХХХХХХ9 для старых полисов'
from tempdb..TEMP_PACIENT t0 with(nolock)
join tempdb..TEMP_ZAP t1 with(nolock) on t0.N_ZAP= t1.N_ZAP
join tempdb..TEMP_Z_SLUCH t2 with(nolock) on t0.n_zap = t2.n_zap
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
and t0.VPOLIS=1
and [dbo].[RegExMatch](t0.NPOLIS,'^\d{1,20}$') != 1

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--004F.00.0230 end

--004F.00.0240 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NPOLIS', NPOLIS as ZN_POL ,@NSCHET, 'PACIENT', t0.N_ZAP, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '004F.00.0240'
, 'Поле NPOLIS должно соответствовать маске 999999999 для временных свидетельств'
from tempdb..TEMP_PACIENT t0 with(nolock)
join tempdb..TEMP_ZAP t1 with(nolock) on t0.N_ZAP= t1.N_ZAP
join tempdb..TEMP_Z_SLUCH t2 with(nolock) on t0.n_zap = t2.n_zap
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
and t0.VPOLIS=2
and [dbo].[RegExMatch](t0.NPOLIS,'^\d{9}$') != 1
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--004F.00.0240 end

--004F.00.0250 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NPOLIS', NPOLIS as ZN_POL ,@NSCHET, 'PACIENT', t0.N_ZAP, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '004F.00.0250'
, 'Обязательно если SMO отсуствует'
from tempdb..TEMP_PACIENT t0 with(nolock)
join tempdb..TEMP_ZAP t1 with(nolock) on t0.N_ZAP= t1.N_ZAP
join tempdb..TEMP_Z_SLUCH t2 with(nolock) on t0.n_zap = t2.n_zap
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
and t0.VPOLIS=3
and [dbo].[RegExMatch](t0.NPOLIS,'^\d{16}$') != 1
and t0.NPOLIS is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--004F.00.0250 end

--004F.00.0280 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SMO_OGRN', SMO_OGRN as ZN_POL ,@NSCHET, 'PACIENT', t0.N_ZAP, t0.ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '004F.00.0280', ''
from tempdb..TEMP_PACIENT t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.N_ZAP = t1.N_ZAP
where
@q019type in ('C', 'H', 'T', 'X')
and t0.SMO is null
and [dbo].[RegExMatch](t0.SMO_OGRN ,'^\d{13}$') != 1
and @type != 562 --рег особенность (не проверяется во временных счетах на идентификацию)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--004F.00.0280 end

--004F.00.0670 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SL_ID', SL_ID as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '004F.00.0670'
, 'Допустимы цифры, строчные и прописные буквы латинского алфавита, горизонтальные разделители'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
and not (dbo.RegExMatch(t0.SL_ID, '^[0-9A-Za-z\-]{1,36}$') = 1)


and DATE_Z_2 >= convert(date,'01.11.2019',104)
--004F.00.0670 end

--004F.00.0731 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'TAL_NUM', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '004F.00.0731'
, 'Не соответствует приказу Минздрава России от 30.01.2015 № 29н'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('T')
and [dbo].[RegExMatch](t0.TAL_NUM,'^\d{2}.\d{4}.\d{5}.\d{3}$') != 1
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--004F.00.0731 end

--004F.00.0750 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NHISTORY', NHISTORY as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '004F.00.0750'
, 'Допустимы цифры, буквы русского и латинского алфавита, пробел, точка, горизонтальные разделители, вертикальные и наклонные разделители'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('A', 'C', 'D', 'H', 'R', 'T', 'X')
and not (dbo.RegExMatch(t0.NHISTORY,'^[0-9А-Яа-яЁёA-Za-z \.\-\|\\\/_+]{1,50}$') = 1)
--Допустимы цифры, буквы русского и латинского алфавита, пробел, точка, горизонтальные разделители, вертикальные и наклонные разделители
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--004F.00.0750 end

--004F.00.1580 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'FAM', FAM as ZN_POL ,@NSCHET, 'PERS', t1.N_ZAP, t1.ID_PAC, t1.IDCASE, null as SL_ID, null as IDSERV, '004F.00.1580'
, 'Допустимы цифры, буквы русского алфавита, пробел, точка, горизонтальные разделители'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on convert(varchar,t0.ID_PAC) = t1.ID_PAC
where
not (dbo.RegExMatch(t0.FAM, '^[0-9А-Яа-яЁё \.\-]{1,40}$') = 1)
and t0.FAM is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--004F.00.1580 end

--004F.00.1590 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'IM', IM as ZN_POL ,@NSCHET, 'PERS', t1.N_ZAP, t1.ID_PAC, t1.IDCASE, null as SL_ID, null as IDSERV, '004F.00.1590'
, 'Допустимы цифры, буквы русского алфавита, пробел, точка, горизонтальные разделители'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on convert(varchar,t0.ID_PAC) = t1.ID_PAC
where
not (dbo.RegExMatch(t0.IM, '^[0-9А-Яа-яЁё \.\-]{1,40}$') = 1)
and t0.IM is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--004F.00.1590 end

--004F.00.1600 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'OT', OT as ZN_POL ,@NSCHET, 'PERS', t1.N_ZAP, t1.ID_PAC, t1.IDCASE, null as SL_ID, null as IDSERV, '004F.00.1600'
, 'Допустимы цифры, буквы русского алфавита, пробел, точка, горизонтальные разделители'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on convert(varchar,t0.ID_PAC) = t1.ID_PAC
where
not (dbo.RegExMatch(t0.OT, '^[0-9А-Яа-яЁё \.\-]{1,40}$') = 1)
and t0.OT is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--004F.00.1600 end

--004F.00.1640 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'FAM_P', FAM_P as ZN_POL ,@NSCHET, 'PERS', t1.N_ZAP, t1.ID_PAC, t1.IDCASE, null as SL_ID, null as IDSERV, '004F.00.1640'
, 'Допустимы цифры, буквы русского алфавита, пробел, точка, горизонтальные разделители'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on convert(varchar,t0.ID_PAC) = t1.ID_PAC
where
not (dbo.RegExMatch(t0.FAM_P, '^[0-9А-Яа-яЁё \.\-]{1,40}$') = 1)
and t0.FAM_P is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--004F.00.1640 end

--004F.00.1650 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'IM_P', IM_P as ZN_POL ,@NSCHET, 'PERS', t1.N_ZAP, t1.ID_PAC, t1.IDCASE, null as SL_ID, null as IDSERV, '004F.00.1650'
, 'Допустимы цифры, буквы русского алфавита, пробел, точка, горизонтальные разделители'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on convert(varchar,t0.ID_PAC) = t1.ID_PAC
where
not (dbo.RegExMatch(t0.IM_P, '^[0-9А-Яа-яЁё \.\-]{1,40}$') = 1)
and t0.IM_P is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--004F.00.1650 end

--004F.00.1660 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'OT_P', OT_P as ZN_POL ,@NSCHET, 'PERS', t1.N_ZAP, t1.ID_PAC, t1.IDCASE, null as SL_ID, null as IDSERV, '004F.00.1660'
, 'Допустимы цифры, буквы русского алфавита, пробел, точка, горизонтальные разделители'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on convert(varchar,t0.ID_PAC) = t1.ID_PAC
where
not (dbo.RegExMatch(t0.OT_P, '^[0-9А-Яа-яЁё \.\-]{1,40}$') = 1)
and t0.OT_P is not null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--004F.00.1660 end

--004F.00.1700 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DOCSER', t0.DOCSER as ZN_POL ,@NSCHET, 'PERS', t1.N_ZAP, t1.ID_PAC, t3.IDCASE,null as SL_ID, null as IDSERV, '004F.00.1700'
, 'Значение не соответствует маске в справочнике F011'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_PACIENT t1 with(nolock) on convert(varchar(36),t0.ID_PAC) = convert(varchar(36),t1.ID_PAC)
join tempdb..TEMP_ZAP t2 with(nolock) on t1.N_ZAP= t2.N_ZAP 
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t1.n_zap
left join ies.T_F011_DOCUMENT_TYPE t4 with(nolock) on t4.IDDoc = t0.DOCTYPE
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
t0.DOCTYPE is not null
and t4.IDDoc is not null
 and t0.docser is not null
and isnull(t4.docserregex,'') != ''
and not (dbo.RegExMatch(t0.docser,t4.docserregex) = 1)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--004F.00.1700 end

--004F.00.1710 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DOCNUM', t0.DOCNUM as ZN_POL ,@NSCHET, 'PERS', t1.N_ZAP, t1.ID_PAC, t3.IDCASE, null as SL_ID, null as IDSERV, '004F.00.1710', 'Не соответсвтует маске'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_PACIENT t1 with(nolock) on convert(varchar(36),t0.ID_PAC) = convert(varchar(36),t1.ID_PAC)
join tempdb..TEMP_ZAP t2 with(nolock) on t1.N_ZAP= t2.N_ZAP 
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t3.n_zap = t1.n_zap
left join ies.T_F011_DOCUMENT_TYPE t4 with(nolock) on t4.IDDoc = t0.DOCTYPE
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
t0.DOCTYPE is not null
and t4.IDDoc is not null
and isnull(t4.docnumregex,'') != ''
and not (dbo.RegExMatch(t0.docnum,t4.docnumregex) = 1)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--004F.00.1710 end

--004F.00.1720 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SNILS', SNILS as ZN_POL ,@NSCHET, 'PERS', t1.N_ZAP, t1.ID_PAC, t1.IDCASE, null as SL_ID, null as IDSERV, '004F.00.1720'
, 'СНИЛС не соответствует шаблону 999-999-999 99'
from tempdb..TEMP_PERS t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on convert(varchar(36),t0.ID_PAC) =  convert(varchar(36),t1.ID_PAC)
where
t0.SNILS is not null
and dbo.RegExMatch(t0.SNILS,'^\d{3}-\d{3}-\d{3} \d{2}$') != 1

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--004F.00.1720 end

--005F.00.0040 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DS1', DS1 as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '005F.00.0040', 'Значение не найдено в справочнике M001'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t1.n_zap = t0.n_zap
left join ies.T_MKB t2 with(nolock) on t2.MCBCode = t0.DS1
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and t0.DS1 is not null
and t2.MCBCode is null
and not exists (select 1 from ies.T_MKB t100 where t100.ParentID = t2.MkbID)

and DATE_Z_2 >= convert(date,'01.11.2019',104)
--005F.00.0040 end

--005F.00.0050 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DS2', DS2 as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '005F.00.0050', 'Значение не найдено в справочнике M001'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_DS2 t1 with(nolock) on t0.IDCASE = t1.IDCASE and t0.SL_ID = t1.SL_ID
left join ies.T_MKB t2 with(nolock) on t2.MCBCode = t1.DS2
join tempdb..TEMP_Z_SLUCH t3 with(nolock) on t0.IDCASE = t3.IDCASE
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t1.DS2 is not null
and t2.MCBCode is null
and not exists (select 1 from ies.T_MKB t100 where t100.ParentID = t2.MkbID)
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--005F.00.0050 end

--005F.00.0090 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'N_KSG', t0.N_KSG as ZN_POL ,@NSCHET, 'KSG_KPG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '001F.00.0580'
, 'Значение не найдено в региональном справочнике'
from tempdb..TEMP_KSG_KPG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'H', 'R')
and KSG_PG=1
and DATE_Z_2 >= convert(date,'01.11.2019',104)
and  (not exists (select 1 from [IESDB].[IES].[T_GR_KSG_KS_2020] t1 where t1.ksg=t0.N_KSG and t1.year=t0.VER_KSG)
	and not exists (select 1 from [IESDB].[IES].[T_GR_KSG_DS_2020] t1 where t1.ksg=t0.N_KSG and t1.year=t0.VER_KSG))
--005F.00.0090 end

--005F.00.0210 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VID_VME', VID_VME as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '005F.00.0210', 'Значение не найдено в справочнике V001'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
left join ies.T_V001_NOMENCLATURE t2 with(nolock) on t2.Code = t0.VID_VME
and isnull(DATEBEG,convert(date,'01.01.2010',104))<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
where
@q019type in ('C', 'H')
and t0.VID_VME is not null
and t2.Code is null
and DATE_Z_2 >= convert(date,'01.11.2019',104)
--005F.00.0210 end

--006F.00.0010 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DATA', null as ZN_POL ,@NSCHET, 'ZGLV', null as N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '006F.00.0010'
, 'Значение поля не должно быть больше текущей даты обработки файла.'
from tempdb..TEMP_ZGLV t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and DATA > getdate()

and @dschet >= convert(date,'01.04.2020',104)
--006F.00.0010 end

--006F.00.0110 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SD_Z', null as ZN_POL ,@NSCHET, 'ZGLV', null as N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '006F.00.0110'
, 'Значение поля должно быть равно количеству законченных случаев (Z_SL), включенных в реестр.'
from tempdb..TEMP_ZGLV t0 with(nolock)
where
@q019type in ('C', 'H', 'T', 'X')
and SD_Z != (select count(*) from tempdb..TEMP_Z_SLUCH)

and @dschet >= convert(date,'01.04.2020',104)
--006F.00.0110 end

--006F.00.0160 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'YEAR', null as ZN_POL ,@NSCHET, 'SCHET', null as N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '006F.00.0160'
, 'Год даты окончания зак. случая больше года реестра счетов'
from tempdb..TEMP_SCHET t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and exists (select top 1 1 from tempdb..TEMP_Z_SLUCH t1 where year(DATE_Z_2) > t0.YEAR)

and @dschet >= convert(date,'01.04.2020',104)
--006F.00.0160 end

--006F.00.0180 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'MONTH', null as ZN_POL ,@NSCHET, 'SCHET', null as N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '006F.00.0180'
, 'Месяц случая больше месяца реестра счетов'
from tempdb..TEMP_SCHET t0 with(nolock)
join tempdb..TEMP_Z_SLUCH with(nolock) on 1 = 1
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and year(date_z_2) = t0.year
and t0.month < month(DATE_Z_2)

and @dschet >= convert(date,'01.04.2020',104)
--006F.00.0180 end

--006F.00.0200 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DSCHET', null as ZN_POL ,@NSCHET, 'SCHET', null as N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '006F.00.0200'
, 'Значение поля не должно быть больше DATA'
from tempdb..TEMP_SCHET t0 with(nolock)
join tempdb..TEMP_ZGLV t1 with(nolock) on 1 = 1
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and t0.DSCHET > t1.DATA
and @dschet >= convert(date,'01.04.2020',104)
--006F.00.0200 end

--006F.00.0310 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NPR_DATE', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.0310'
, 'Дата направления не может быть больше даты начала случая'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and NPR_DATE > DATE_Z_1

and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0310 end

--006F.00.0311 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NPR_DATE', null as ZN_POL ,@NSCHET, 'Z_SL', t1.N_ZAP, t1.ID_PAC, t1.IDCASE, t3.sl_id as SL_ID, null as IDSERV,  '006F.00.0311'
, 'Дата направления должна быть больше или равна дате рождения'
from tempdb..TEMP_Z_SLUCH t1 with(nolock)
join tempdb..TEMP_PERS t2 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t2.ID_PAC)
join tempdb..TEMP_SLUCH t3 with(nolock) on t3.idcase = t1.idcase
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and NPR_DATE < DR
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0311 end

--006F.00.0312 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'TAL_D', null as ZN_POL ,@NSCHET, 'SL', t1.N_ZAP, t2.ID_PAC, t1.IDCASE, t3.SL_ID, null as IDSERV, '006F.00.0312'
, 'Значение поля не должно быть меньше DR'
from tempdb..TEMP_Z_SLUCH t1 with(nolock)
join tempdb..TEMP_PERS t2 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t2.ID_PAC)
join tempdb..TEMP_SLUCH t3 with(nolock) on t3.idcase = t1.idcase
where
@q019type in ('D', 'R', 'T')
and TAL_D < t2.DR
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0312 end

--006F.00.0313 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'TAL_D', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0313'
, 'Значение поля не должно быть больше DATE_2'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('D', 'R', 'T')
and TAL_D > DATE_2
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0313 end

--006F.00.0314 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'TAL_P', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0314'
, 'Значение поля не должно быть меньшеTAL_D'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('T')
and TAL_P<TAL_D
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0314 end

--006F.00.0315 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'TAL_P', null as ZN_POL ,@NSCHET, 'SL', t1.N_ZAP, t2.ID_PAC, t1.IDCASE, t3.SL_ID, null as IDSERV, '006F.00.0315'
, 'Значение поля не должно быть меньше DR'
from tempdb..TEMP_Z_SLUCH t1 with(nolock)
join tempdb..TEMP_PERS t2 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t2.ID_PAC)
join tempdb..TEMP_SLUCH t3 with(nolock) on t3.idcase = t1.idcase
where
@q019type in ('T')
and TAL_P < t2.DR
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0315 end

--006F.00.0330 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DATE_Z_1', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.0330'
, 'Значение поля не должно быть больше DATE_Z_2'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and DATE_Z_1 > DATE_Z_2
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0330 end

--006F.00.0340 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DATE_Z_2', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.0340'
, 'Значение поля не должно быть больше DSCHET'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
join tempdb..TEMP_SCHET t1 with(nolock) on 1 = 1
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and t1.dschet < date_z_2

and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0340 end

--006F.00.0350 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'RSLT_D', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.0350'
, 'При DS_ONK=1 должно выполняться RSLT_D <>1'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
join tempdb..TEMP_SLUCH t1 with(nolock) on t0.idcase = t1.idcase
where
@q019type in ('X')
and t0.RSLT_D = 1
and DS_ONK=1
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0350 end

--006F.00.0360 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'RSLT', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.0360'
, 'При DS_ONK=1 запрещён этот результат обращений'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
join tempdb..TEMP_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('D', 'R', 'C', 'H', 'T', 'X')
and DS_ONK=1
and RSLT in (317, 321, 332, 343, 347)
and @type = 554
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0360 end

--006F.00.0370 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SUMV', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.0370'
, 'Значение поля должно быть равно сумме значений SUM_M вложенных элементов SL'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and sumv != (select sum(sum_m) from tempdb..TEMP_SLUCH t1 where t1.IDCASE = t0.IDCASE)

and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0370 end

--006F.00.0390 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'REAB', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0390'
, 'Указывается при NOVOR=0'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_PACIENT t2 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t2.ID_PAC)
where
@q019type in ('C', 'D', 'H', 'R')
and NOVOR!=0
and REAB is not null
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0390 end

--006F.00.0395 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DET', DET as ZN_POL ,@NSCHET, 'SL', t1.N_ZAP, t1.ID_PAC, t1.IDCASE, t3.SL_ID, null as IDSERV, '006F.00.0395'
, 'Возраст должен быть меньше 18 лет на дату начала случая'
from tempdb..TEMP_Z_SLUCH t1 with(nolock)
join tempdb..TEMP_PERS t2 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t2.ID_PAC)
join tempdb..TEMP_SLUCH t3 with(nolock) on t3.idcase = t1.idcase
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and dbo.DateTimeDiff('year',dr,date_z_1) >= 18
and DET = 1
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0395 end

--006F.00.0400 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DATE_1', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0400'
, 'Значение поля не должно быть меньше DATE_Z_1'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.idcase = t1.idcase
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and DATE_1 < DATE_Z_1

and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0400 end

--006F.00.0410 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DATE_1', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0410'
, 'Значение поля не должно больше DATE_2'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and date_1 > date_2
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0410 end

--006F.00.0420 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DATE_2', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0420'
, 'Значение поля не должно быть больше DATE_Z_2'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.idcase = t1.idcase
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and date_2 > date_z_2

and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0420 end

--006F.00.0430 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DS1', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0430'
, 'Значение поля не должно быть равным значению поля DS2 или DS3'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and (
exists (select top 1 1 from tempdb..TEMP_DS2 t01 with(nolock) where DS2 = DS1 and t0.sl_id = t01.sl_id and t0.idcase = t01.idcase)
or 
exists (select top 1 1 from tempdb..TEMP_DS3 t02 with(nolock) where DS3 = DS1 and t0.sl_id = t02.sl_id and t0.idcase = t02.idcase)
)

and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0430 end

--006F.00.0440 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DS2', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0440'
, 'Значение поля не должно быть равным значению поля DS3'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_DS2 t1 with(nolock) on t0.SL_ID = t1.SL_ID and t0.IDCASE = t1.IDCASE
join tempdb..TEMP_Z_SLUCH t2 with(nolock) on t0.IDCASE = t2.IDCASE
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and exists (select top 1 1 from tempdb..TEMP_DS3 t01 with(nolock)
where t0.SL_ID = t01.SL_ID and t0.IDCASE = t01.IDCASE and t1.DS2 = t01.DS3)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0440 end

--006F.00.0450 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CODE_MES1', null as ZN_POL ,@NSCHET, 'SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0450'
, 'Значение поля не должно быть равным значению поля CODE_MES2'
from tempdb..TEMP_SLUCH t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and CODE_MES1 = CODE_MES2
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0450 end

--006F.00.0470 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DIAG_CODE', null as ZN_POL ,@NSCHET, 'B_DIAG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0470'
, 'Данный тип исследования запрещён для данного диагноза'
from tempdb..TEMP_B_DIAG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.SL_ID = t2.SL_ID and t0.IDCASE = t2.IDCASE
left join ies.T_N007_MRF n007 with(nolock) on n007.ID_Mrf = t0.DIAG_CODE
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2) 
left join ies.T_N009_MRT_DS n009 with(nolock) on n009.N007Mrf = n007.N007MrfID and DS1 like DS_Mrf+'%'
where
@q019type in ('C', 'D', 'R', 'T')
and DIAG_TIP=1
and N009MrtDsID is null
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0470 end

--006F.00.0480 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DIAG_RSLT', null as ZN_POL ,@NSCHET, 'B_DIAG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0480'
, 'Неверный результат для данного исследования'
from tempdb..TEMP_B_DIAG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.SL_ID = t2.SL_ID and t0.IDCASE = t2.IDCASE
join ies.T_N007_MRF n007 with(nolock) on ID_Mrf = t0.DIAG_CODE
left join ies.T_N008_MRF_RT n008 with(nolock) on N007MrfId = N007Mrf and ID_R_M = DIAG_RSLT
where
@q019type in ('C', 'D', 'R', 'T')
and DIAG_TIP=1
and N008MrfRtID is null
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0480 end

--006F.00.0490 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DIAG_CODE', null as ZN_POL ,@NSCHET, 'B_DIAG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0490'
, 'Данный тип исследования запрещён для данного диагноза'
from tempdb..TEMP_B_DIAG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.SL_ID = t2.SL_ID and t0.IDCASE = t2.IDCASE
left join ies.T_N010_MARK n010 with(nolock) on n010.ID_Igh = t0.DIAG_CODE
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
left join ies.T_N012_MARK_DIAG n012 with(nolock) on n012.N010Mark = n010.N010MarkID and DS1 like DS_Igh+'%'
where
@q019type in ('C', 'D', 'R', 'T')
and DIAG_TIP=2
and N012MarkDiagID is null
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0490 end

--006F.00.0500 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DIAG_RSLT', null as ZN_POL ,@NSCHET, 'B_DIAG', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0500'
, 'Неверный результат для данного исследования'
from tempdb..TEMP_B_DIAG t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.SL_ID = t2.SL_ID and t0.IDCASE = t2.IDCASE
join ies.T_N010_MARK n010 with(nolock) on n010.ID_Igh = t0.DIAG_CODE
left join ies.T_N011_MARK_VALUE n011 with(nolock) on N010MarkID = N010Mark and ID_R_I = DIAG_RSLT
where
@q019type in ('C', 'D', 'R', 'T')
and DIAG_TIP=2
and N011MarkValueID is null
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0500 end

--006F.00.0510 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'D_PROT', null as ZN_POL ,@NSCHET, 'B_PROT', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0510'
, 'Значение поля должно быть не больше DATE_2'
from tempdb..TEMP_B_PROT t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.SL_ID = t2.SL_ID and t0.IDCASE = t2.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and D_PROT>DATE_2
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0510 end

--006F.00.0520 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DET', null as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t3.IDCASE, t3.SL_ID, t4.idserv as IDSERV, '006F.00.0520'
, 'При DET=1 Возраст должен быть меньше 18 лет на дату начала случая'
from tempdb..TEMP_Z_SLUCH t1 with(nolock)
join tempdb..TEMP_PERS t2 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t2.ID_PAC)
join tempdb..TEMP_SLUCH t3 with(nolock) on t3.idcase = t1.idcase
join tempdb..TEMP_USL t4 with(nolock) on t4.sl_id = t3.sl_id and t4.idcase = t3.idcase
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and dbo.DateTimeDiff('year',t2.dr,date_1) >= 18
and t4.det = 1
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0520 end

--006F.00.0530 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DATE_IN', null as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0530'
, 'Значение поля не должно быть меньше DATE_1'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.IDCASE = t2.IDCASE and t0.SL_ID = t2.SL_ID
where
@q019type in ('C', 'H', 'T')
and DATE_IN < DATE_1
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0530 end

--006F.00.0550 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DATE_IN', null as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0550'
, 'Значение поля не должно быть больше DATE_OUT'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.IDCASE = t2.IDCASE and t0.SL_ID = t2.SL_ID
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and DATE_IN > DATE_OUT
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0550 end

--006F.00.0560 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DATE_OUT', null as ZN_POL ,@NSCHET, 'USL', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0560'
, 'Значение поля не должно быть больше DATE_2'
from tempdb..TEMP_USL t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.IDCASE = t2.IDCASE and t0.SL_ID = t2.SL_ID
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and DATE_OUT > DATE_2
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0560 end

--006F.00.0580 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAPR_DATE', null as ZN_POL ,@NSCHET, 'NAPR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0580'
, 'Значение поля не должно быть больше DATE_2'
from tempdb..TEMP_NAPR t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t2.IDCASE = t0.IDCASE and t2.SL_ID = t0.SL_ID
where
@q019type in ('C', 'D', 'R', 'T')
and NAPR_DATE>DATE_2

and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0580 end

--006F.00.0590 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'NAPR_DATE', null as ZN_POL ,@NSCHET, 'NAPR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0590'
, 'Значение поля не должно быть меньше DATE_1'
from tempdb..TEMP_NAPR t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.IDCASE = t2.IDCASE and t0.SL_ID = t2.SL_ID
where
@q019type in ('C', 'D', 'R', 'T')
and NAPR_DATE<DATE_1

and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0590 end

--006F.00.0600 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DT_CONS', null as ZN_POL ,@NSCHET, 'CONS', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0600'
, 'Значение поля должно быть не больше DATE_2'
from tempdb..TEMP_CONS t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.IDCASE = t2.IDCASE and t0.SL_ID = t2.SL_ID
where
@q019type in ('C', 'D', 'R', 'T')
and DT_CONS > DATE_2

and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0600 end

--006F.00.0610 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DATE_INJ', convert(varchar(10),DATE_INJ,104) as ZN_POL,@NSCHET, 'LEK_PR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0610'
, 'Значение поля должно быть не меньше DATE_1'
from tempdb..TEMP_LEK_PR_DATE_INJ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.SL_ID = t2.SL_ID and t0.IDCASE = t2.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and DATE_INJ<DATE_1
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0610 end

--006F.00.0620 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DATE_INJ', null as ZN_POL ,@NSCHET, 'LEK_PR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0620'
, 'Значение поля должно быть не больше DATE_2'
from tempdb..TEMP_LEK_PR_DATE_INJ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_SLUCH t2 with(nolock) on t0.SL_ID = t2.SL_ID and t0.IDCASE = t2.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and DATE_INJ>DATE_2
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0620 end

--006F.00.0630 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CODE_SH', CODE_SH as ZN_POL ,@NSCHET, 'LEK_PR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0630'
, 'CODE_SH должно содержать значение НЕТ'
from tempdb..TEMP_LEK_PR_DATE_INJ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_PERS t2 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t2.ID_PAC)
join tempdb..TEMP_SLUCH t3 with(nolock) on t3.sl_id = t0.sl_id and t3.idcase = t0.idcase
left join ies.T_V024_DOP_KR t4 with(nolock) on t4.IDDKK = t0.CODE_SH
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2) 
where
@q019type in ('C', 'D', 'R', 'T')
and t0.CODE_SH != 'нет'
and DS1 >= 'C81' and DS1 < 'C97'
and DATE_Z_2 >= convert(date,'01.04.2020',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--006F.00.0630 end

--006F.00.0631 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CODE_SH', CODE_SH as ZN_POL ,@NSCHET, 'LEK_PR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0631'
, 'Пул значений: нет'
from tempdb..TEMP_LEK_PR_DATE_INJ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_PERS t2 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t2.ID_PAC)
join tempdb..TEMP_SLUCH t3 with(nolock) on t3.sl_id = t0.sl_id and t3.idcase = t0.idcase
left join ies.T_V024_DOP_KR t4 with(nolock) on t4.IDDKK = t0.CODE_SH
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
left join tempdb..TEMP_ONK_USL t5 on t5.IDCASE = t1.IDCASE 
where
@q019type in ('C', 'D', 'R', 'T')
and t0.CODE_SH != 'нет'
and (
	(DS1 >= 'C81' and DS1 < 'C97')
	or (DS1 >= 'D45' and DS1 < 'D48')
)
and t5.USL_TIP > 4

and DATE_Z_2 >= convert(date,'01.01.2021',104)
--006F.00.0631 end

--006F.00.0640 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CODE_SH', CODE_SH as ZN_POL ,@NSCHET, 'LEK_PR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0640'
, 'CODE_SH должно содержать значение НЕТ'
from tempdb..TEMP_LEK_PR_DATE_INJ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_PERS t2 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t2.ID_PAC)
join tempdb..TEMP_SLUCH t3 with(nolock) on t3.sl_id = t0.sl_id and t3.idcase = t0.idcase
left join ies.T_V024_DOP_KR t4 with(nolock) on t4.IDDKK = t0.CODE_SH and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2) 
where
@q019type in ('C', 'D', 'R', 'T')
and t0.CODE_SH != 'нет'
and dbo.DateTimeDiff('year',dr,date_z_1) < 18
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0640 end

--006F.00.0650 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CODE_SH', CODE_SH as ZN_POL ,@NSCHET, 'LEK_PR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0650'
, 'Значение не входит в пул sh001<=CODE_SH<=sh904'
from tempdb..TEMP_LEK_PR_DATE_INJ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_PERS t2 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t2.ID_PAC)
join tempdb..TEMP_SLUCH t3 with(nolock) on t3.sl_id = t0.sl_id and t3.idcase = t0.idcase
left join ies.T_V024_DOP_KR t4 with(nolock) on t4.IDDKK = t0.CODE_SH
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
left join tempdb..TEMP_ONK_USL t5 on t5.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and dbo.DateTimeDiff('year',dr,date_z_1) >= 18
and ((t3.ds1 >= 'C00' and t3.ds1 < 'C81') or (t3.ds1 like 'C97%') or t3.ds1 like 'D0%')
and t5.USL_TIP = 2
and isnull(IDDKK,'') not like 'sh%'
and DATE_Z_2 >= convert(date,'01.04.2020',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--006F.00.0650 end

--006F.00.0651 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CODE_SH', CODE_SH as ZN_POL ,@NSCHET, 'LEK_PR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0650'
, 'Пул значений: sh0001<=CODE_SH<=sh9002 или gemop1<=CODE_SH<=gemop24 или CODE_SH=gem'
from tempdb..TEMP_LEK_PR_DATE_INJ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_PERS t2 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t2.ID_PAC)
join tempdb..TEMP_SLUCH t3 with(nolock) on t3.sl_id = t0.sl_id and t3.idcase = t0.idcase
left join ies.T_V024_DOP_KR t4 with(nolock) on t4.IDDKK = t0.CODE_SH
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
left join tempdb..TEMP_ONK_USL t5 on t5.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and dbo.DateTimeDiff('year',dr,date_z_1) >= 18
and ((t3.ds1 >= 'C00' and t3.ds1 < 'C81') or (t3.ds1 like 'C97%') or t3.ds1 like 'D0%')
and t5.USL_TIP = 2
and not (
		isnull(IDDKK,'') like 'sh%'
	)
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--006F.00.0651 end

--006F.00.0652 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CODE_SH', CODE_SH as ZN_POL ,@NSCHET, 'LEK_PR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0652'
, 'Пул значений: gemop1<=CODE_SH<=gemop24 или CODE_SH=gem'
from tempdb..TEMP_LEK_PR_DATE_INJ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_PERS t2 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t2.ID_PAC)
join tempdb..TEMP_SLUCH t3 with(nolock) on t3.sl_id = t0.sl_id and t3.idcase = t0.idcase
left join ies.T_V024_DOP_KR t4 with(nolock) on t4.IDDKK = t0.CODE_SH
and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
left join tempdb..TEMP_ONK_USL t5 on t5.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and dbo.DateTimeDiff('year',dr,date_z_1) >= 18
and ((t3.ds1 >= 'С81' and t3.ds1 < 'С97') or (t3.ds1 >= 'D45' and t3.ds1 < 'D48'))
and t5.USL_TIP = 2
and not (
		isnull(IDDKK,'') like 'gemop%'
		or
		isnull(IDDKK,'') = 'gem'
	)
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--006F.00.0652 end

--006F.00.0660 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CODE_SH', CODE_SH as ZN_POL ,@NSCHET, 'LEK_PR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0660', 'Значение не найдено в справочнике V024'
from tempdb..TEMP_LEK_PR_DATE_INJ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_PERS t2 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t2.ID_PAC)
join tempdb..TEMP_SLUCH t3 with(nolock) on t3.sl_id = t0.sl_id and t3.idcase = t0.idcase
left join ies.T_V024_DOP_KR t4 with(nolock) on t4.IDDKK = t0.CODE_SH and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
left join tempdb..TEMP_ONK_USL t5 on t5.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and dbo.DateTimeDiff('year',dr,date_z_1) >= 18
and (
	(DS1 >= 'C00' and DS1 < 'C81')
	or
	DS1 like 'D%'
)
and t5.USL_TIP = 4
and isnull(IDDKK,'') not like 'sh%'
and isnull(IDDKK,'') not like 'mt%'
and DATE_Z_2 >= convert(date,'01.04.2020',104)
and DATE_Z_2 <= convert(date,'31.12.2020',104)
--006F.00.0660 end

--006F.00.0661 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'CODE_SH', CODE_SH as ZN_POL ,@NSCHET, 'LEK_PR', t1.N_ZAP, t1.ID_PAC, t0.IDCASE, t0.SL_ID, null as IDSERV, '006F.00.0661', 'Значение не найдено в справочнике V024'
from tempdb..TEMP_LEK_PR_DATE_INJ t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on t0.IDCASE = t1.IDCASE
join tempdb..TEMP_PERS t2 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t2.ID_PAC)
join tempdb..TEMP_SLUCH t3 with(nolock) on t3.sl_id = t0.sl_id and t3.idcase = t0.idcase
left join ies.T_V024_DOP_KR t4 with(nolock) on t4.IDDKK = t0.CODE_SH and DATEBEG<=DATE_Z_2 and (DATEEND is null or DATEEND>=DATE_Z_2)
left join tempdb..TEMP_ONK_USL t5 on t5.IDCASE = t1.IDCASE
where
@q019type in ('C', 'D', 'R', 'T')
and dbo.DateTimeDiff('year',dr,date_z_1) >= 18
and (
	(DS1 >= 'C00' and DS1 < 'C81')
	or DS1 like 'D0%'
	or DS1 like 'C97%'
)
and t5.USL_TIP = 4
and isnull(IDDKK,'') not like 'sh%'
and isnull(IDDKK,'') not like 'mt%'
and DATE_Z_2 >= convert(date,'01.01.2021',104)
--006F.00.0661 end

--006F.00.0670 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DR', null as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t1.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV, '006F.00.0670'
, 'DR должно быть <= ZGLV.DATA'
from tempdb..TEMP_Z_SLUCH t0
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t0.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on t2.n_zap = t0.n_zap
join tempdb..TEMP_ZGLV t3 with(nolock) on 1 = 1
where
t1.DR > t3.DATA
and t1.DR is not null

and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0670 end

--006F.00.0680 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DR', null as ZN_POL ,@NSCHET, 'PERS', t2.N_ZAP, t1.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV, '006F.00.0680'
, 'Дата рождения должна быть меньше или равна DATA_Z_1'
from tempdb..TEMP_Z_SLUCH t0
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t0.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on t2.n_zap = t0.n_zap
where
t1.DR > DATE_Z_1
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0680 end

--006F.00.0690 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DR_P', null as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV, '006F.00.0690'
, 'Значение поля должно быть меньше DR не менее, чем на 14 лет'
from tempdb..TEMP_Z_SLUCH t0
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t0.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on t2.n_zap = t0.n_zap
where
year(t1.DR)-year(t1.DR_P)<=14
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.0690 end

--006F.00.1010 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DR', null as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t1.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV, '006F.00.1010'
, 'Разность между годом рождения пациента и годом прохождения диспансеризации должна быть 18 лет и более'
from tempdb..TEMP_Z_SLUCH t0
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t0.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on t2.n_zap = t0.n_zap
join tempdb..TEMP_SCHET t3 with(nolock) on 1 = 1
where
@q019type in ('X')
and year(DATE_Z_2)-year(dr)<18
and disp in ('ДВ4', 'ДВ2', 'ОПВ')
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1010 end

--006F.00.1020 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'DR', null as ZN_POL ,@NSCHET, 'PERS', t0.N_ZAP, t1.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV, '006F.00.1020'
, 'Разность между годом рождения пациента и годом прохождения диспансеризации должна быть менее 18 лет'
from tempdb..TEMP_Z_SLUCH t0
join tempdb..TEMP_PERS t1 with(nolock) on convert(varchar(36),t1.ID_PAC) = convert(varchar(36),t0.ID_PAC)
join tempdb..TEMP_PACIENT t2 with(nolock) on t2.n_zap = t0.n_zap
join tempdb..TEMP_SCHET t3 on 1 = 1
where
@q019type in ('X')
and year(DATE_Z_2)-year(dr)>=18
and disp in ('ДС1', 'ДС2', 'ДС3', 'ДС4', 'ПН1', 'ПН2')
and @type not in (693,562)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1020 end

--006F.00.1030 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SUMMAP', null as ZN_POL ,@NSCHET, 'SCHET', null as N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '006F.00.1030'
, 'SUMMAP должна быть равна SUMMAV-( SANK_MEK+ SANK_MEE+ SANK_EKMP)'
from tempdb..TEMP_SCHET t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and isnull(SUMMAP,0) != SUMMAV-(isnull(SANK_MEK,0) + isnull(SANK_MEE,0) + isnull(SANK_EKMP,0))
and @type = 693
and @isMoToSmo = 0
and @dschet >= convert(date,'01.04.2020',104)
--006F.00.1030 end

--006F.00.1040 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SUMMAV', null as ZN_POL ,@NSCHET, 'SCHET', null as N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '006F.00.1040'
, 'SUMMAV должна быть равна сумме значений SUMV всех законченных случаев, включенных в счет'
from tempdb..TEMP_SCHET t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and SUMMAV != (select sum(isnull(sumv,0)) from tempdb..TEMP_Z_SLUCH)

and @dschet >= convert(date,'01.04.2020',104)
--006F.00.1040 end

--006F.00.1050 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SUMMAP', null as ZN_POL ,@NSCHET, 'SCHET', null as N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '006F.00.1050'
, 'SUMMAP должна быть равна сумме значений SUMP всех законченных случаев, включенных в счет'
from tempdb..TEMP_SCHET t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and SUMMAP != (select sum(isnull(sump,0)) from tempdb..TEMP_Z_SLUCH)

and @dschet >= convert(date,'01.04.2020',104)
--006F.00.1050 end

--006F.00.1060 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SANK_MEK', null as ZN_POL ,@NSCHET, 'SCHET', null as N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '006F.00.1060'
, 'SANK_MEK не равна сумме санкций МЭК по законченным случаям'
from tempdb..TEMP_SCHET t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and isnull(t0.SANK_MEK,0) != isnull((select sum(isnull(s_sum,0)) from tempdb..TEMP_SANK where S_TIP in (1, 10, 11, 12) ),0)

and @dschet >= convert(date,'01.04.2020',104)
--006F.00.1060 end

--006F.00.1070 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SANK_MEE', null as ZN_POL ,@NSCHET, 'SCHET', null as N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '006F.00.1070'
, 'SANK_MEE не равна сумме санкций МЭЭ по законченным случаям'
from tempdb..TEMP_SCHET t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and isnull(t0.SANK_MEE,0) != isnull((select sum(isnull(s_sum,0)) from tempdb..TEMP_SANK where S_TIP>=20 and S_TIP<30),0)
and @dschet >= convert(date,'01.04.2020',104)
--006F.00.1070 end

--006F.00.1080 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SANK_EKMP', convert(varchar, cast(t0.SANK_EKMP as money)) as ZN_POL ,@NSCHET, 'SCHET', null as N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '006F.00.1080'
, 'SANK_EKMP не равна сумме санкций ЭКМП на законченных случаях'
from tempdb..TEMP_SCHET t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and isnull(t0.SANK_EKMP,0) != isnull((select sum(isnull(s_sum,0)) from tempdb..TEMP_SANK where S_TIP>=30 and S_TIP<50),0)
and @dschet >= convert(date,'01.04.2020',104)
--006F.00.1080 end

--006F.00.1090 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select top 1 'SANK_IT', null as ZN_POL ,@NSCHET, 'Z_SL', null as N_ZAP, null as ID_PAC, null as IDCASE, null as SL_ID, null as IDSERV, '006F.00.1090'
, 'Сумма SANK_IT <> SANK_MEK + SANK_MEE + SANK_EKMP'
from tempdb..TEMP_SCHET t0 with(nolock)
join tempdb..TEMP_Z_SLUCH t1 with(nolock) on 1 = 1
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and isnull(t0.SANK_MEK,0)+isnull(t0.SANK_MEE,0)+isnull(t0.SANK_EKMP,0) != isnull((select sum(isnull(SANK_IT,0)) from tempdb..TEMP_Z_SLUCH),0)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1090 end

--006F.00.1100 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'RSLT', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1100'
, 'Результат обращения не соответствует исходу'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('D', 'R', 'C', 'H', 'T', 'X')
and t0.RSLT not in (305, 308, 314, 315, 317, 318, 321, 322, 323, 324, 325, 332, 333, 334, 335, 336, 343, 344, 347, 348, 349, 350, 351, 353, 355, 356, 357, 358, 361, 362, 363, 364, 365, 366, 367, 368, 369, 370, 371, 372, 373, 374)
and ISHOD=306
and @type = 554
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1100 end

--006F.00.1110 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'RSLT', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1110'
, 'При ISHOD=306, разрешены RSLT = {305, 308, 314, 315, 301}'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'H')
and t0.RSLT not in (305, 308, 314, 315, 301)  -- мб элемент обязателен
and ISHOD=306
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1110 end

--006F.00.1120 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ISHOD', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1120'
, 'Для данного результата обращения ISHOD = 402'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.ISHOD != 402
and RSLT in (407, 408, 409, 410, 411, 412, 413, 414, 417)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1120 end

--006F.00.1130 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ISHOD', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1130'
, 'ISHOD = 101 запрещён для данных результатов обращений'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and t0.ISHOD = 101 
and RSLT in (102, 103, 104, 105, 106, 109, 107, 108, 110)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1130 end

--006F.00.1140 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ISHOD', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1140'
, 'Исход 201 запрещён для данного результата обращения'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and t0.ISHOD = 201
and RSLT in (202, 203, 204, 205, 206, 207, 208)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1140 end

--006F.00.1150 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'IDSP', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1150'
, 'Разрешены только IDSP = {25, 28, 29, 30, 31, 44}'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('X')
and t0.IDSP not in (25, 28, 29, 30, 31, 44)

and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1150 end

--006F.00.1160 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SUMP', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1160'
, 'SUMP != SUMV-SANK_IT'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and SUMP!=SUMV-SANK_IT

and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1160 end

--006F.00.1170 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SUMP', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1170'
, 'Если OPLATA=3, то SUMP=SUMV-SANK_IT'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and OPLATA=3
and SUMP!=SUMV-SANK_IT
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1170 end

--006F.00.1171 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SANK_IT', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1171'
, 'Если OPLATA=3, то 0<SANK_IT<SUMV'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and not (0<SANK_IT and SANK_IT<SUMV)
and OPLATA=3
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1171 end

--006F.00.1180 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SUMP', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1180'
, 'Если OPLATA=2, то SUMP=0'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and SUMP!=0
and OPLATA=2
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1180 end

--006F.00.1181 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SANK_IT', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1181'
, 'SANK_IT=SUMV если OPLATA=2'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and t0.SANK_IT != sumv -- мб элемент обязателен
and OPLATA=2
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1181 end

--006F.00.1190 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SUMP', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1190'
, 'Если OPLATA=1, то SUMP=SUMV'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and SUMP != SUMV
and OPLATA=1
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1190 end

--006F.00.1191 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'SANK_IT', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1191'
, 'SANK_IT=0 если OPLATA=1'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T', 'X')
and t0.SANK_IT != 0 -- мб элемент обязателен
and OPLATA=1
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1191 end

--006F.00.1200 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VIDPOM', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1200'
, 'Если USL_OK=4, то VIDPOM = {2, 21, 22, 23}'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.VIDPOM not in (2, 21, 22, 23)
and USL_OK=4
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1200 end

--006F.00.1210 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VIDPOM', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1210'
, 'Если USL_OK=3, то VIDPOM = {1, 2, 11, 12, 13, 4, 14}'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.VIDPOM not in (1, 2, 11, 12, 13, 4, 14)
and USL_OK=3
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1210 end

--006F.00.1220 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VIDPOM', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1220'
, 'Если USL_OK=2, то VIDPOM = {12, 13, 14, 31, 32, 33}'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.VIDPOM not in (12, 13, 14, 31, 32, 33)
and USL_OK=2
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1220 end

--006F.00.1230 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'VIDPOM', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1230'
, 'Если USL_OK=1, то VIDPOM = {3, 21, 31, 32, 33}'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.VIDPOM not in (3, 21, 31, 32, 33)
and USL_OK=1
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1230 end

--006F.00.1240 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ISHOD', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1240'
, 'При RSLT={105, 106} допустим только ISHOD=104'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.ISHOD != 104
and RSLT in (105, 106)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1240 end

--006F.00.1250 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ISHOD', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1250'
, 'При RSLT={205, 206} допустимо только ISHOD=204'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and ISHOD!=204
and RSLT in (205, 206)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1250 end

--006F.00.1260 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ISHOD', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1260'
, 'При RSLT={313} допустимо только ISHOD=305'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.ISHOD != 305
and RSLT=313
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1260 end

--006F.00.1270 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'ISHOD', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1270'
, 'При RSLT={405, 406} допустимо только ISHOD=403'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and ISHOD != 403
and RSLT in (405, 406)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1270 end

--006F.00.1280 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'FOR_POM', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1280'
, 'При USL_OK=2 FOR_POM={2, 3}'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.FOR_POM not in (2,3) -- мб элемент обязателен
and isnull(USL_OK,0)=2
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1280 end

--006F.00.1290 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'FOR_POM', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1290'
, 'При USL_OK=3 FOR_POM={2, 3}'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.FOR_POM not in (2,3) -- мб элемент обязателен
and isnull(USL_OK,0)=3
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1290 end

--006F.00.1300 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'FOR_POM', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1300'
, ''
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and t0.FOR_POM not in (1,2) -- мб элемент обязателен
and isnull(USL_OK,0)=4
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1300 end

--006F.00.1310 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'RSLT', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1310'
, 'Неверный результат обращения для данного условия оказания МП'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and isnull(USL_OK,0)=1
and not (RSLT>100 and RSLT<200)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1310 end

--006F.00.1320 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'RSLT', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1320'
, 'Неверный результат обращения для данного условия оказания МП'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and isnull(USL_OK,0)=2
and not (RSLT>200 and RSLT<300)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1320 end

--006F.00.1330 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'RSLT', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1330'
, 'Неверный результат обращения для данного условия оказания МП'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and isnull(USL_OK,0)=3
and not (RSLT>300 and RSLT<400)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1330 end

--006F.00.1340 begin
insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'RSLT', null as ZN_POL ,@NSCHET, 'Z_SL', t0.N_ZAP, t0.ID_PAC, t0.IDCASE, null as SL_ID, null as IDSERV,  '006F.00.1340'
, 'Неверный результат обращения для данного условия оказания МП'
from tempdb..TEMP_Z_SLUCH t0 with(nolock)
where
@q019type in ('C', 'D', 'H', 'R', 'T')
and isnull(USL_OK,0)=4
and not (RSLT>400 and RSLT<500)
and DATE_Z_2 >= convert(date,'01.04.2020',104)
--006F.00.1340 end


--q015 rules end
--q015 end

insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'FILENAME', t0.[FILENAME] as ZN_POL ,@NSCHET, 'FILENAME', null, null, null, null, null, '902'
, 'FILENAME не соответствует шаблону *М400***S40***'
from tempdb..TEMP_ZGLV t0 with(nolock)
where t0.[FILENAME] is not null
and t0.[FILENAME] like 'HM%'
and substring(t0.[FILENAME],9,1) = 'S'
and dbo.RegExMatch(t0.[FILENAME],'^HM400\w{3}S40\w{3}_\d{5,}$') != 1
and @type = 693

insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'FILENAME', t0.[FILENAME] as ZN_POL ,@NSCHET, 'FILENAME', null, null, null, null, null, '902'
, 'FILENAME не соответствует шаблону *S400***T40***'
from tempdb..TEMP_ZGLV t0 with(nolock)
where t0.[FILENAME] is not null
and t0.[FILENAME] like 'HS%'
and substring(t0.[FILENAME],9,1) = 'T'
and dbo.RegExMatch(t0.[FILENAME],'^HS400\w{3}T40\w{3}_\d{5,}$') != 1
and @type = 693

insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'FILENAME', t0.[FILENAME] as ZN_POL ,@NSCHET, 'FILENAME', null, null, null, null, null, '902'
, 'FILENAME не соответствует шаблону *М400***S40***'
from tempdb..TEMP_ZGLV t0 with(nolock)
where t0.[FILENAME] is not null
and t0.[FILENAME] like 'TM%'
and substring(t0.[FILENAME],9,1) = 'S'
and dbo.RegExMatch(t0.[FILENAME],'^TM400\w{3}S40\w{3}_\d{5,}$') != 1
and @type = 693

insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'FILENAME', t0.[FILENAME] as ZN_POL ,@NSCHET, 'FILENAME', null, null, null, null, null, '902'
, 'FILENAME не соответствует шаблону *S400***T40***'
from tempdb..TEMP_ZGLV t0 with(nolock)
where t0.[FILENAME] is not null
and t0.[FILENAME] like 'TS%'
and substring(t0.[FILENAME],9,1) = 'T'
and dbo.RegExMatch(t0.[FILENAME],'^TS400\w{3}T40\w{3}_\d{5,}$') != 1
and @type = 693

insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'FILENAME', t0.[FILENAME] as ZN_POL ,@NSCHET, 'FILENAME', null, null, null, null, null, '902'
, 'FILENAME не соответствует шаблону *М400***S40***'
from tempdb..TEMP_ZGLV t0 with(nolock)
where t0.[FILENAME] is not null
and t0.[FILENAME] like 'CM%'
and substring(t0.[FILENAME],9,1) = 'S'
and dbo.RegExMatch(t0.[FILENAME],'^CM400\w{3}S40\w{3}_\d{5,}$') != 1
and @type = 693

insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'FILENAME', t0.[FILENAME] as ZN_POL ,@NSCHET, 'FILENAME', null, null, null, null, null, '902'
, 'FILENAME не соответствует шаблону *S400***T40***'
from tempdb..TEMP_ZGLV t0 with(nolock)
where t0.[FILENAME] is not null
and t0.[FILENAME] like 'CS%'
and substring(t0.[FILENAME],9,1) = 'T'
and dbo.RegExMatch(t0.[FILENAME],'^CS400\w{3}S40\w{3}_\d{5,}$') != 1
and @type = 693

insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'FILENAME', t0.[FILENAME] as ZN_POL ,@NSCHET, 'FILENAME', null, null, null, null, null, '902'
, 'FILENAME не соответствует шаблону *М400***S40***'
from tempdb..TEMP_ZGLV t0 with(nolock)
where t0.[FILENAME] is not null
and t0.[FILENAME] like 'D[A-Z]M%'
and substring(t0.[FILENAME],10,1) = 'S'
and dbo.RegExMatch(t0.[FILENAME],'^D[A-Z]M400\w{3}S40\w{3}_\d{5,}$') != 1
and @type = 693

insert into #Errors (IM_POL, ZN_POL, NSCHET, BAS_EL, N_ZAP, ID_PAC, IDCASE, SL_ID, IDSERV, OSHIB, COMMENT)
select 'FILENAME', t0.[FILENAME] as ZN_POL ,@NSCHET, 'FILENAME', null, null, null, null, null, '902'
, 'FILENAME не соответствует шаблону *S400***T40***'
from tempdb..TEMP_ZGLV t0 with(nolock)
where t0.[FILENAME] is not null
and t0.[FILENAME] like 'D[A-Z]S%'
and substring(t0.[FILENAME],10,1) = 'T'
and dbo.RegExMatch(t0.[FILENAME],'^D[A-Z]S400\w{3}T40\w{3}_\d{5,}$') != 1
and @type = 693

--================================================================================
--============ Сохранение сведений о случаях по отказам контроля объёмов =========
--================================================================================
--if (Select COUNT(*) from #Errors where OSHIB = '5.3.2')> 0
--BEGIN

--SELECT '[IES].[T_INF_CONTROL_5_3_2_SLUCH]' as tableName, 'Случаи ошибок ФЛК' as operationName, (select 1) as tableCount

--SELECT  t2.[YEAR] as [YEAR],t2.[MONTH] as [MONTH],t2.[CODE] as [CODE],t2.[NSCHET] as [NSCHET],p.[NPOLIS] as [NPOLIS],
--		cast(p.ID_PAC as varchar(36)) as [ID_PAC], 
--		pp.fam as [FAM], pp.im as [IM], pp.ot as [OT], pp.dr as [DR], 
--		t2.CODE_MO as [CODE_MO], z.n_zap as [N_ZAP], zs.idcase as [IDCASE], zs.date_z_2 as [DATE_Z_2], 
--		zs.USL_OK as [USL_OK],case when er.COMMENT like '%КСГ%' then 1 else 0 end as [KSG], ss.sum_m as [SUM_M]
--	from tempdb..TEMP_Z_SLUCH zs
--		inner join tempdb..TEMP_SLUCH ss on zs.IDCASE=ss.IDCASE
--		inner join tempdb..TEMP_ZAP z on zs.N_ZAP=z.N_ZAP
--		inner join tempdb..TEMP_PACIENT p on zs.N_ZAP=p.N_ZAP
--		inner join tempdb..TEMP_PERS pp on cast(p.ID_PAC as varchar)=cast(pp.ID_PAC as varchar)
--		inner join tempdb..TEMP_ZGLV zg on zg.FILENAME not like ('%T40_%') and SUBSTRING(zg.FILENAME,1,1) in ('H','C','T')
--		inner join tempdb..TEMP_SCHET t2 on t2.CODE_MO is not null 
--		inner join #Errors er on er.n_zap = z.N_ZAP and er.idcase=zs.IDCASE and er.OSHIB = '5.3.2'
--		left join IESDB.ies.T_INF_CONTROL_5_3_2_SLUCH inf on  t2.CODE_MO = inf.code_mo
--														and zs.date_z_2 = inf.date_z_2
--														and zs.USL_OK = inf.usl_ok
--														and cast(p.ID_PAC as varchar) = inf.ID_PAC
--		-- условие что других ошибок по этой записи нет кроме превышения объёмов
--		left join #Errors er2 on er2.n_zap = z.N_ZAP and er2.idcase=zs.IDCASE and er2.OSHIB != '5.3.2'

--		where inf.code_mo is null and er2.n_zap is null
--			and (case when er.COMMENT not like '%КСГ%' and 
--					not exists (select 1 from #Errors e1 where er.n_zap = e1.n_zap and er.idcase = e1.idcase and er.COMMENT like '%КСГ%') 
--					then 1 else 0 end) = 1

--delete from #Errors where OSHIB = '5.3.2'

--end

--================================================================================
--============ Конец Сохранение сведений о случаях по отказам контроля объёмов ===
--================================================================================

if (Select COUNT(*) from #Errors)> 0
BEGIN
--================================================================================
--============ Сохранение сведений по отказам контроля объёмов ===================
--================================================================================
if (Select COUNT(*) from #Errors where OSHIB = '5.3.2')> 0 --and datepart(day,GETDATE()) between 1 and 18
BEGIN

SELECT '[IES].[T_INF_CONTROL_5_3_2]' as tableName, 'Ошибки ФЛК' as operationName, (select 1) as tableCount
--select 'id_pac' as [ID_PAC], 'fam' as [FAM], 'im' as [IM], 'ot' as [OT], '20210331' as [DR],
--	 'test1' as [CODE_MO], cast(N_ZAP as varchar(20)) as [N_ZAP], cast(IDCASE as varchar(20)) as [IDCASE], 
--	'20210331' as [DATE_Z_2],'1' as [USL_OK],'1' as [KSG],'1' as [SUM_M]
--FROM #Errors

SELECT cast(p.ID_PAC as varchar(36)) as [ID_PAC], 
		pp.fam as [FAM], pp.im as [IM], pp.ot as [OT], pp.dr as [DR], 
		t2.CODE_MO as [CODE_MO], t2.PLAT as [PLAT], z.n_zap as [N_ZAP], zs.idcase as [IDCASE], zs.date_z_2 as [DATE_Z_2], 
		zs.USL_OK as [USL_OK], ss.PROFIL as [PROFIL], case when er.COMMENT like '%КСГ%' then 1 else 0 end as [KSG], 
		ss.DS1 as [DS1], mkb.DS2 as [DS2], 
		CASE WHEN ss.METOD_HMP IS NOT NULL THEN CAST(v019.HGR AS VARCHAR) ELSE k.N_KSG END as [N_KSG], 
		zs.KD_Z as [KD_Z], ss.PROFIL_K as [PROFIL_K], ss.LPU_1 as [LPU_1], ss.METOD_HMP as [METOD_HMP], ss.sum_m as [SUM_M],
		usl.CODE_USL as [CODE_USL], usl.KOL_USL as [KOL_USL], getdate() as [DATE_CHANGE], NEWID() as [DICTIONARYBASEID]
	from tempdb..TEMP_Z_SLUCH zs
		inner join tempdb..TEMP_SLUCH ss on zs.IDCASE=ss.IDCASE
		inner join tempdb..TEMP_ZAP z on zs.N_ZAP=z.N_ZAP
		inner join tempdb..TEMP_PACIENT p on zs.N_ZAP=p.N_ZAP
		inner join tempdb..TEMP_PERS pp on cast(p.ID_PAC as varchar)=cast(pp.ID_PAC as varchar)
		inner join tempdb..TEMP_ZGLV zg on zg.FILENAME not like ('%T40_%') and SUBSTRING(zg.FILENAME,1,1) in ('H','C','T')
		inner join tempdb..TEMP_SCHET t2 on t2.CODE_MO is not null 
		OUTER APPLY (SELECT TOP 1 ds2.DS2 FROM tempdb..TEMP_DS2 ds2 
				where ss.IDCASE=ds2.IDCASE and ss.SL_ID=ds2.SL_ID order by replace(ds2.DS2,'U','A') ) mkb
		LEFT OUTER JOIN tempdb..TEMP_KSG_KPG k on k.IDCASE=ss.IDCASE and k.SL_ID=ss.SL_ID
		OUTER APPLY (SELECT TOP 1 HGR from [IES].[T_V019_VMP_METHOD] v19 
				where ss.METOD_HMP=v19.idhm and ss.DATE_2 between v19.DATEBEG and isnull(v19.DATEEND,ss.DATE_2)) v019
		OUTER APPLY (SELECT min(code_usl) as code_usl, sum(kol_usl) kol_usl FROM tempdb..TEMP_USL u 
				where ss.IDCASE=u.IDCASE and ss.SL_ID=u.SL_ID and u.SUMV_USL > 0) usl
		inner join #Errors er on er.n_zap = z.N_ZAP and er.idcase=zs.IDCASE and er.OSHIB = '5.3.2'
		left join IESDB.ies.T_INF_CONTROL_5_3_2 inf on  t2.CODE_MO = inf.code_mo
														and zs.date_z_2 = inf.date_z_2
														and zs.USL_OK = inf.usl_ok
														and cast(p.ID_PAC as varchar) = inf.ID_PAC
		-- условие что других ошибок по этой записи нет кроме превышения объёмов
		left join #Errors er2 on er2.n_zap = z.N_ZAP and er2.idcase=zs.IDCASE and er2.OSHIB != '5.3.2'

		where inf.code_mo is null and er2.n_zap is null
			and (case when er.COMMENT not like '%КСГ%' and 
					not exists (select 1 from #Errors e1 where er.n_zap = e1.n_zap and er.idcase = e1.idcase and er.COMMENT like '%КСГ%') 
					then 1 else 0 end) = 1

end
--================================================================================
--============ Конец Сохранение сведений по отказам контроля объёмов =============
--================================================================================

select 
'<?xml version="1.0" encoding="Windows-1251"?>
' + (
select 
	OSHIB AS 'OSHIB',
	IM_POL AS 'IM_POL',
	ZN_POL as 'ZN_POL',
	@NSCHET as 'NSCHET',
	BASE_EL AS 'BAS_EL',
	N_ZAP AS 'N_ZAP',
	ID_PAC as 'ID_PAC',
	IDCASE AS 'IDCASE',
	SL_ID AS 'SL_ID',
	IDSERV AS 'IDSERV',
	COMMENT AS 'COMMENT'
FROM #Errors
order by OSHIB
FOR XML PATH('PR'),
ROOT('FLK_P')
)
END


ELSE
BEGIN
--проверка, что суммы сходятся
declare @sumsluch decimal
select @sumsluch =  Sum([SUM_M]) from tempdb..TEMP_SLUCH
declare @sumSanks decimal
select @sumSanks =  Sum([SANK_IT]) from tempdb..TEMP_Z_SLUCH
declare @sumschet decimal
select @sumschet = SUM([SUMMAV]) from tempdb..TEMP_SCHET
if (@sumsluch <> @sumschet)
begin
	raiserror('ОШИБКА В ФАЙЛЕ СЧЕТ-РЕЕСТРА: Сумма на случаях не равна сумме на счете', 18,1)
end

update tempdb..TEMP_ZGLV set ID = '1'
update tempdb..TEMP_SCHET set ID = '1'
update tempdb..TEMP_ZAP set SchetZapID = newid()
update tempdb..TEMP_Z_SLUCH set [SchetSluchAccomplishedID] = newid()
update tempdb..TEMP_SANK set [SchetSluchSankID] = newid()
update tempdb..TEMP_SANK_SL_ID set [SchetSluchSankSLID] = newid() 
update tempdb..TEMP_SLUCH set [SchetSluchID] = newid()
update tempdb..TEMP_ONK_SL set SchetSluchOnkID = newid()
update tempdb..TEMP_ONK_USL set [SchetOnkUslID] = newid() 
update tempdb..TEMP_SANK set [SchetSluchSankID] = newid() 
update tempdb..TEMP_KSG_KPG set [KsgID] = newid() 
update tempdb..TEMP_USL set [SchetUslID] = newid()



--INSERT INTO [IES].[T_SCHET]
--           ([VERSION],[DATA],[CODE],[YEAR],[MONTH],[NSCHET],[DSCHET],[SUMMAV],[COMENTS],[SUMMAP],[SANK_MEK],[SANK_MEE],[SANK_EKMP],[ReceivedDate],[ReceivedTime],[FILENAME],[CODE_MO],[PLAT],[Worker],[SchetID],[type_], [Status], SchetKind, DISP)
     
	 SELECT '[IES].[T_SCHET]' as tableName, 'счета' as operationName, (select count(*) from tempdb..TEMP_SCHET) as tableCount
	 
	 SELECT [VERSION],[DATA],[CODE],[YEAR],[MONTH],[NSCHET],[DSCHET],[SUMMAV],[COMENTS],[SUMMAP],[SANK_MEK] as SANK_MEK_R, [SANK_MEE] AS SANK_MEE_R, [SANK_EKMP] AS SANK_EKMP_R, CAST(CAST(CAST(GETDATE() as float) as INT) as datetime) as [ReceivedDate],GETDATE() as [ReceivedTime],[FILENAME],[CODE_MO],[PLAT]
	 ,@Worker as [Worker], @SchetID as [SchetID], @type as [type_], 0 as [Status],0 as [SchetKind], (SELECT V016ID from IES.T_V016_DISPT where IDDT = DISP and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate)) AS DISP, SD_Z
     --,COMENTS as [COMENTS]
	 FROM tempdb..TEMP_SCHET t1  
	 JOIN tempdb..TEMP_ZGLV t2 on t2.ID = t1.ID


-----------------[IES].T_SCHET_ZAP
--CREATE NONCLUSTERED INDEX [IX_TEMP_ZAP_N_ZAP] ON tempdb..TEMP_ZAP
--(
--	[N_ZAP] ASC
--)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

--CREATE NONCLUSTERED INDEX [IX_IESDB_TEMP_TEMP_SLUCH_VERS_SPEC]
--ON [IESDB_TEMP].[dbo].[TEMP_SLUCH] ([VERS_SPEC])
--INCLUDE ([N_ZAP],[IDCASE],[PRVS])

--CREATE NONCLUSTERED INDEX [IX_IESDB_TEMP_TEMP_USL_IDCASE]
--ON [IESDB_TEMP].[dbo].[TEMP_USL] ([IDCASE])
--INCLUDE ([IDSERV],[PRVS])

--CREATE NONCLUSTERED INDEX [IX_IESDB_TEMP_TEMP_SLUCH_IDCASE_VERS_SPEC]
--ON [IESDB_TEMP].[dbo].[TEMP_SLUCH] ([IDCASE],[VERS_SPEC])
--INCLUDE ([N_ZAP])

--INSERT INTO [IES].[T_SCHET_ZAP]
--           ([SchetZapID],[SPOLIS],[NPOLIS],[NOVOR],[N_ZAP]
--		   ,[VPOLIS]
--		   ,[ID_PAC],[SMO],[SMO_OGRN],[SMO_OK],[SMO_NAM],[PR_NOV],[Schet],[type_],ST_OKATO, VNOV_D
--		   ,[FAM],[IM],[OT],[W],[DR],[FAM_P],[IM_P],[OT_P],[W_P],[DR_P],[MR],[DOCTYPE],[DOCSER],[DOCNUM],[SNILS],[OKATOG] ,[OKATOP],[COMENTP],[AttachmentMo],[AttachDate])

SELECT '[IES].[T_SCHET_ZAP]' as tableName, ' информации о людях' as operationName, (select count(*) from tempdb..TEMP_ZAP) as tableCount

select t0.ID_PAC, Left(t0.rezult,Len(t0.rezult)-1) As rezult into #temp_dost
	From
    (
        Select distinct cast(ID_PAC as varchar(36)) as ID_PAC, 
            (
                Select cast(t1.DOST as varchar(1)) + ',' AS [text()]
                From tempdb..TEMP_DOST t1
                Where cast(t1.ID_PAC as varchar(36)) = cast(ST2.ID_PAC as varchar(36))
                ORDER BY cast(t1.ID_PAC as varchar(36))
                For XML PATH ('')
            ) rezult
        From tempdb..TEMP_DOST ST2
    ) t0 

select t0.ID_PAC, Left(t0.rezult,Len(t0.rezult)-1) As rezult into #temp_dost_p
	From
    (
        Select distinct cast(ID_PAC as varchar(36)) as ID_PAC, 
            (
                Select cast(t1.DOST_P as varchar(1)) + ',' AS [text()]
                From tempdb..TEMP_DOST_P t1
                Where cast(t1.ID_PAC as varchar(36)) = cast(ST2.ID_PAC as varchar(36))
                ORDER BY cast(t1.ID_PAC as varchar(36))
                For XML PATH ('')
            ) rezult
        From tempdb..TEMP_DOST_P ST2
    ) t0 	



 SELECT [SchetZapID],[SPOLIS],[NPOLIS],[NOVOR],zap.[N_ZAP]
 , (SELECT TOP 1 f008.IDDOC FROM [IES].T_F008_OMS_TYPE f008 WHERE f008.IDDOC = [VPOLIS]) as [VPOLIS]
 ,cast(pac.ID_PAC as varchar(36)) as [ID_PAC],(SELECT TOP 1 mo.SMOCOD FROM [IES].T_F002_SMO mo WHERE mo.SMOCOD = pac.[SMO]) as [SMO],[SMO_OGRN],[SMO_OK],[SMO_NAM],[PR_NOV]
,@SchetID as [Schet]
 , 698 as [type_],ST_OKATO, VNOV_D
 ,[FAM],[IM],[OT],[W],[DR],[FAM_P],[IM_P],[OT_P],[W_P],[DR_P],[MR],[DOCTYPE],[DOCSER],[DOCNUM]
 ,DOCDATE,DOCORG
 ,[SNILS],[OKATOG] ,[OKATOP],[COMENTP],[MO] as [AttachmentMo]--,[MODATE] as [AttachDate]
 , dost.rezult as DOST
 , dost_p.rezult as DOST_P
  , INV, pac.MSE, MO_SK as [MO_SK], TEL as [TEL]
  ,case
	when @type in (693, 554) and enp is null and len(isnull(rtrim(npolis),'')) = 16 then npolis
	else enp
  end as ENP
 FROM tempdb..TEMP_ZAP zap
 join tempdb..TEMP_PACIENT pac on pac.N_ZAP = zap.N_ZAP
 left join tempdb..TEMP_PERS pers on cast(pers.ID_PAC as varchar(36)) = cast(pac.ID_PAC as varchar(36))

 left join #temp_dost   dost   on (CAST(dost.ID_PAC as varchar(36)) = cast(pac.ID_PAC as varchar(36)))
 left join #temp_dost_p dost_p on (CAST(dost_p.ID_PAC as varchar(36)) = cast(pac.ID_PAC as varchar(36)))

 drop table #temp_dost   
 drop table #temp_dost_p

 ---- Заполняет значение результата для диспансеризации
 --declare @rstl int 
 --set @rstl = (SELECT top 1 t7.RSLT
 -- FROM  tempdb..TEMP_Z_SLUCH zs
 -- join tempdb..TEMP_SLUCH t on (t.IDCASE=zs.IDCASE) 
 -- join tempdb..TEMP_SCHET t1 on t1.DISP is not null
 -- join [IESDB].[IES].[T_SPR_RSLT_D_TO_RSLT] t7 on t1.DISP=t7.DISP and zs.RSLT_D=t7.RSLT_D)

 ----------------T_SCHET_SLUCH_ACCOMPLISHED
--INSERT INTO [IES].[T_SCHET_SLUCH_ACCOMPLISHED]
--			(SchetSluchAccomplishedID, IDCASE, USL_OK, VIDPOM, FOR_POM, NPR_MO, NPR_DATE, LPU, DATE_Z_1, DATE_Z_2, KD_Z, VNOV_M, RSLT, ISHOD, OS_SLUCH, VB_P, IDSP, SUMV, OPLATA, SUMP, SANK_IT, SchetZap, VBR, P_OTK, RSLT_D, P_DISP2, OO_R)
  
  SELECT '[IES].[T_SCHET_SLUCH_ACCOMPLISHED]' as tableName, ' информации о законченных случаях лечения' as operationName, (select count(*) from tempdb..TEMP_Z_SLUCH) as tableCount
  
  SELECT SchetSluchAccomplishedID, IDCASE, USL_OK, VIDPOM, FOR_POM, NPR_MO, NPR_DATE, LPU, DATE_Z_1, DATE_Z_2, KD_Z, VNOV_M, RSLT --isnull(RSLT,@rstl)
  , ISHOD, OS_SLUCH, VB_P, IDSP, SUMV, OPLATA, SUMP, SANK_IT, t2.[SchetZapID] as [SchetZap], VBR, P_OTK, RSLT_D/*, P_DISP2*/
  FROM tempdb..TEMP_Z_SLUCH t1 
  JOIN tempdb..TEMP_ZAP t2 on t2.N_ZAP = t1.N_ZAP
    
-----------------[IES].T_SCHET_SLUCH
--INSERT INTO [IES].[T_SCHET_SLUCH]  
--      ([SchetSluchID], [SL_ID],[NHISTORY],[DATE_1],[DATE_2],[DS0],[DS1],[CODE_MES1],[CODE_MES2],[ED_COL],[TARIF],[SUMV],[SUMP]
   --   ,[COMENTSL],[PROFIL]
	  --,[PROFIL_K]
	  --,[PRVS]	  ,[PRVS2]	  ,[PRVS3]
	  --,[DET],[PODR],[LPU_1],[IDDOKT],[type_],[SchetZap], [P_CEL]
   --   ,[VID_HMP],[METOD_HMP], [KD]
	  --, P_PER, TAL_D, TAL_NUM, TAL_P, DS1_PR, DN, REAB, PR_D_N, [SchetSluchAccomplished], RSLT_D)

  SELECT '[IES].[T_SCHET_SLUCH]' as tableName, ' информации о случаях лечения' as operationName, (select count(*) from tempdb..TEMP_SLUCH) as tableCount

  SELECT t1.[SchetSluchID], t1.[SL_ID],t1.[NHISTORY],t1.[DATE_1],t1.[DATE_2],t1.[DS0],t1.[DS1],t1.[CODE_MES1],t1.[CODE_MES2],t1.[ED_COL],t1.[TARIF] ,t1.SUM_M as [SUMV] ,t1.SUM_M as [SUMP]
	  ,t1.[COMENTSL],t1.[PROFIL]
	  ,(select V020BedProfileId from IES.T_V020_BED_PROFILE where  t1.[PROFIL_K] = IDK_PR and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate) ) as [PROFIL_K]
	  ,(select V027CZabID from ies.T_V027_C_ZAB zab where IDCZ=t1.C_ZAB and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate)) as [C_ZAB]
	  ,case when [VERS_SPEC] = 'V004' THEN [PRVS] ELSE null END as [PRVS]
	  ,case when [VERS_SPEC] = 'V015' THEN [PRVS] ELSE null END as [PRVS2]
	  ,case when [VERS_SPEC] = 'V021' or [VERS_SPEC] is null  THEN [PRVS] ELSE null END as [PRVS3]
	  ,t1.[DET],[PODR],[LPU_1],[IDDOKT], 700 as [type_], t2.[SchetZapID] as [SchetZap]
	  ,( select V025KpcID from IES.T_V025_KPC where IDPC = [P_CEL] and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate) ) as [P_CEL]
	  ,t1.[VID_HMP]
	  --,(select top 1 v019.V019VmpMethodID from IES.T_V019_VMP_METHOD v019 where t1.METOD_HMP = v019.IDHM and v019.DATEBEG<=t3.DATE_Z_2 and (v019.DATEEND is null or v019.DATEEND>=t3.DATE_Z_2))as [METOD_HMP]
	  ,(		  
			select top 1 t101.V019VmpMethodID
			from ies.R_NSI_HGR_TARIF t100 
			left join ies.T_V019_VMP_METHOD t101 on
			t1.metod_hmp = t101.IDHM
			and isnull(t100.hgr,-1) = isnull(t101.HGR,-2)
			and t1.VID_HMP = t101.HVID
			and t101.DATEBEG<=DATE_Z_2 and (t101.DATEEND is null or t101.DATEEND>=DATE_Z_2)
			where
			t1.sum_m = t100.tarif
			order by t101.V022Modpac asc
	  ) as METOD_HMP
	  ,[KD]
	  , P_PER, TAL_D, TAL_NUM, TAL_P, DS1_PR, DN, REAB, PR_D_N, t3.[SchetSluchAccomplishedID] as [SchetSluchAccomplished], RSLT_D
	  --,(CASE WHEN exists (select * 
			--	from tempdb..TEMP_USL t10 WITH(NOLOCK)
			--	join [IES].[T_V001_NOMENCLATURE] t20 WITH(NOLOCK) on t20.Code = t10.CODE_USL AND t20.DATEEND IS NULL
			--	where				 
			--	t10.IDCASE = t1.IDCASE AND t1.SL_ID = t10.SL_ID
			--	and t20.IsOperation = 1)
			--	 THEN 'Операция' ELSE NULL END) As [IsOperation]
, t1.DS_ONK
  FROM tempdb..TEMP_SLUCH t1    
  JOIN tempdb..TEMP_ZAP t2 on t2.N_ZAP = t1.N_ZAP
  JOIN tempdb..TEMP_Z_SLUCH t3 on t1.IDCASE = t3.IDCASE
  outer apply (
	select top 1 t100.V019VmpMethodID
	from ies.T_V019_VMP_METHOD t100
	left join ies.R_NSI_HGR_TARIF t101 on t101.tarif = t1.sum_m
	where t100.IDHM = t1.METOD_HMP
	and t100.DATEBEG<=DATE_Z_2 and (t100.DATEEND is null or t100.DATEEND>=DATE_Z_2)
	and (
		t3.DATE_Z_2 < convert(date,'01.01.2021',104)
		or
		(
			t1.vid_hmp = t100.HVID
			and isnull(t101.hgr,-1) = isnull(t100.HGR,-2)
		)
	)
)v019

-----------------T_SCHET_SLUCH_NAZ
--INSERT INTO [IES].[T_SCHET_SLUCH_NAZ]
--			(SchetSluchNazID, NAZ_N, NAZR, NAZ_SP, NAZ_PMP, NAZ_V, NAZ_PK, SchetSluch)

SELECT '[IES].[T_SCHET_SLUCH_NAZ]' as tableName, ' информации о назначениях' as operationName, (select count(*) from tempdb..TEMP_NAZ) as tableCount

SELECT  newid() as [SchetSluchNazID]
, tn.NAZ_N
, tn.NAZ_R as [NAZR]
, (select top 1 IDSPEC from IES.T_V021_MED_SPEC where IDSPEC = tn.NAZ_SP) as [NAZ_SP]
, tn.NAZ_PMP
, (select top 1 V029MetIsslID from IES.T_V029_MET_ISSL where IDMET = tn.NAZ_V) as [NAZ_V]
, (select top 1 V020BedProfileID from IES.T_V020_BED_PROFILE where IDK_PR = tn.NAZ_PK) as [NAZ_PK]
, ts.SchetSluchID as [SchetSluch]
, tn.NAPR_DATE
, tn.NAPR_MO
, tn.NAZ_USL 
FROM tempdb..TEMP_NAZ tn  
JOIN tempdb..TEMP_SLUCH  ts on ts.[SL_ID] = tn.[SL_ID] and tn.IDCASE = ts.IDCASE

---------------------T_KSG
--INSERT INTO [IES].[T_KSG]
--			(KsgID, KSG_PG, SL_K, IT_SL, SchetSluch, N_KPG
--			, N_KSG, DKK2, DKK1, VER_KSG, KOEF_Z, KOEF_UP, BZTSZ, KOEF_D, KOEF_U)

SELECT '[IES].[T_KSG]' as tableName, ' информации о КСГ в случаях' as operationName, (select count(*) from tempdb..TEMP_KSG_KPG) as tableCount

SELECT [KsgID], KSG_PG, SL_K, IT_SL, ts.SchetSluchID as [SchetSluch]
	, (select top 1 V026KpgID from IES.T_V026_KPG where K_KPG = t1.N_KPG) as [N_KPG]
	,  t1.N_KSG as [N_KSG]
	, (select top 1 V024DopKrID from IES.T_V024_DOP_KR where IDDKK = t1.DKK2) as [DKK2]
	, (select top 1 V024DopKrID from IES.T_V024_DOP_KR where IDDKK = t1.DKK1) as [DKK1]
	, VER_KSG, KOEF_Z, KOEF_UP, BZTSZ, KOEF_D, KOEF_U
FROM tempdb..TEMP_KSG_KPG t1 
JOIN tempdb..TEMP_SLUCH ts on ts.[SL_ID] = t1.[SL_ID] and t1.IDCASE = ts.IDCASE
 join tempdb..TEMP_Z_SLUCH t3 on (t3.IDCASE = ts.IDCASE)

SELECT '[IES].[T_KSG_CRIT]' as tableName, ' Классификационный критерий (V024)' as operationName, (select count(*) from tempdb..TEMP_CRIT) as tableCount

SELECT [KsgID] as [Ksg], newid() as [KsgCritID]
	, (select top 1 V024DopKrID from IES.T_V024_DOP_KR where IDDKK = t1.CRIT) as [V024DopKr]
FROM tempdb..TEMP_CRIT t1
join tempdb..TEMP_KSG_KPG t2 on t2.[SL_ID] = t1.[SL_ID] and t1.IDCASE = t2.IDCASE 
JOIN tempdb..TEMP_SLUCH ts on ts.[SL_ID] = t2.[SL_ID] and t2.IDCASE = ts.IDCASE

--INSERT INTO [IES].[T_KSLP]
--			(KslpID, KOEF, OmsSchetSluch, KOEF_TYPE, Ksg)

SELECT '[IES].[T_KSLP]' as tableName, ' информации о КСЛП в случаях' as operationName, (select count(*) from tempdb..TEMP_SL_KOEF) as tableCount

SELECT newid() as [KslpID], t1.Z_SL as [KOEF], t2.[SchetSluchID] as [OmsSchetSluch], t1.IDSL as [KOEF_TYPE], t3.KsgID as [Ksg] 
FROM tempdb..TEMP_SL_KOEF t1
JOIN tempdb..TEMP_SLUCH t2 on t2.[SL_ID] = t1.[SL_ID] and t1.IDCASE = t2.IDCASE
JOIN tempdb..TEMP_KSG_KPG t3 on t2.[SL_ID] = t3.[SL_ID] and t2.IDCASE = t3.IDCASE 

-----------------[IES].T_SCHET_USL
--INSERT INTO [IES].[T_SCHET_USL] 
--           (t1.[SchetUslID],t1.[IDSERV],t1.[LPU],t1.[DATE_IN],t1.[DATE_OUT],t1.[DS],t1.[KOL_USL],t1.[TARIF],t1.[SUMV_USL],t1.[COMENTU],t1.[PROFIL]
           --,t1.[PRVS]
		   --,t1.[DET],t1.[LPU_1],t1.[PODR],t1.[CODE_USL],t1.[CODE_MD],t1.[SchetSluch],t1.[USL],t1.[type_], [VID_VME], PRVS2)
 
 SELECT '[IES].[T_SCHET_USL]' as tableName, ' информации об услугах' as operationName, (select count(*) from tempdb..TEMP_USL) as tableCount

 SELECT  t1.[SchetUslID],t1.[IDSERV],t1.[LPU],t1.[DATE_IN],t1.[DATE_OUT],t1.[DS],cast (t1.[KOL_USL] as decimal(6,2)) as [KOL_USL],cast(t1.[TARIF] as decimal(15,2)) as [TARIF], cast(t1.[SUMV_USL] as decimal(10,2)) as [SUMV_USL]
 ,case when t1.[CODE_USL] in ('Z01.063.001','Z01.064.000','Z01.064.001','Z01.067.000')  then isnull(t1.[COMENTU],' ') + ' Формула расчета стоимости стоматологической услуги TARIF*KOL_USL/2.4' else t1.[COMENTU] end as [COMENTU]
 ,t1.[PROFIL]
 ,case when t2.[VERS_SPEC] = 'V004' /*OR t2.RSLT_D IS NOT NULL*/ THEN t1.[PRVS] else null END as [PRVS]
 ,t1.[DET],t1.[LPU_1],t1.[PODR],t1.[CODE_USL],t1.[CODE_MD],t2.[SchetSluchID] as SchetSluch, (select b.code_usl from ies.R_NSI_USL_V001 b where t1.CODE_USL=b.CODE_USL) as USL , 710 as [type_], [VID_VME]
 ,case when t2.[VERS_SPEC] = 'V015' /*OR t2.RSLT_D IS NOT NULL*/ THEN (select top 1 RECID from [IES].T_V015_MEDSPEC where CODE = t1.[PRVS]) ELSE NULL END as PRVS2
 ,case when t2.[VERS_SPEC] = 'V021' or t2.VERS_SPEC is null THEN t1.PRVS ELSE NULL END as PRVS3
 , NPL
 FROM tempdb..TEMP_USL t1
 JOIN tempdb..TEMP_SLUCH t2 on t2.SL_ID = t1.SL_ID and t2.IDCASE = t1.IDCASE
 JOIN tempdb..TEMP_Z_SLUCH t3 on t2.IDCASE = t3.IDCASE
   
-----------------[IES].T_SCHET_SLUCH_DS
--INSERT INTO [IES].[T_SCHET_SLUCH_DS]
--           ([SchetSluchDsID]
--           ,[MKB]
--           ,[SchetSluch]
--           ,[MKBType])

--declare @cnt int

--select @cnt = count(*)
--from
--(
--	SELECT NEWID() as [SchetSluchDsID], t1.[DS2] as [MKB], t2.[SchetSluchID] as [SchetSluch],0 as [MKBType]
--	FROM 
--	tempdb..TEMP_DS2 t1
--	JOIN tempdb..TEMP_SLUCH t2 on t2.[IDCASE] = t1.[IDCASE]
--	WHERE t1.DS2 is not null
--	union
--	SELECT NEWID() as [SchetSluchDsID], t1.[DS3] as [MKB], t2.[SchetSluchID] as [SchetSluch],1 as [MKBType]
--	FROM 
--	tempdb..TEMP_DS3 t1
--	JOIN tempdb..TEMP_SLUCH t2 on t2.[IDCASE] = t1.[IDCASE]
--	WHERE t1.DS3 is not null
--)aa

--SELECT '[IES].[T_SCHET_SLUCH_DS]' as tableName, ' информации об диагнозах' as operationName, @cnt as tableCount


--SELECT NEWID() as [SchetSluchDsID], t1.[DS2] as [MKB], t2.[SchetSluchID] as [SchetSluch],0 as [MKBType]
--FROM 
--tempdb..TEMP_DS2 t1
--JOIN tempdb..TEMP_SLUCH t2 on t2.[IDCASE] = t1.[IDCASE]
--union
--SELECT NEWID() as [SchetSluchDsID], t1.[DS3] as [MKB], t2.[SchetSluchID] as [SchetSluch],1 as [MKBType]
--FROM 
--tempdb..TEMP_DS3 t1
--JOIN tempdb..TEMP_SLUCH t2 on t2.[IDCASE] = t1.[IDCASE]

declare @cnt int

select @cnt = count(*)
from
(
	SELECT NEWID() as [SchetSluchDsID], t1.[DS2] as [MKB], t2.[SchetSluchID] as [SchetSluch],0 as [MKBType]
	FROM 
	tempdb..TEMP_DS2 t1
	JOIN tempdb..TEMP_SLUCH t2 on t2.[IDCASE] = t1.[IDCASE]
	union
	SELECT NEWID() as [SchetSluchDsID], t1.[DS3] as [MKB], t2.[SchetSluchID] as [SchetSluch],1 as [MKBType]
	FROM 
	tempdb..TEMP_DS3 t1
	JOIN tempdb..TEMP_SLUCH t2 on t2.[IDCASE] = t1.[IDCASE]
)aa

SELECT '[IES].[T_SCHET_SLUCH_DS]' as tableName, ' информации об диагнозах' as operationName, @cnt as tableCount


SELECT NEWID() as [SchetSluchDsID], t1.[DS2] as [MKB], t2.[SchetSluchID] as [SchetSluch],0 as [MKBType], null as DS2_PR, null as  PR_DS2_N
FROM 
tempdb..TEMP_DS2 t1
JOIN tempdb..TEMP_SLUCH t2 on t2.[IDCASE] = t1.[IDCASE] and t1.SL_ID = t2.SL_ID
union
SELECT NEWID() as [SchetSluchDsID], t1.[DS3] as [MKB], t2.[SchetSluchID] as [SchetSluch],1 as [MKBType], null as DS2_PR, null as PR_DS2_N
FROM 
tempdb..TEMP_DS3 t1
JOIN tempdb..TEMP_SLUCH t2 on t2.[IDCASE] = t1.[IDCASE] and t1.SL_ID = t2.SL_ID
union
SELECT NEWID() as [SchetSluchDsID], t1.[DS2] as [MKB], t2.[SchetSluchID] as [SchetSluch],0 as [MKBType], DS2_PR as [DS2_PR], PR_DS2_N as [PR_DS2_N]
FROM 
tempdb..TEMP_DS2_N t1
JOIN tempdb..TEMP_SLUCH t2 on t2.[IDCASE] = t1.[IDCASE] and t1.SL_ID = t2.SL_ID


-----------------[IES].T_SCHET_SLUCH_SANK
--INSERT INTO [IES].[T_SCHET_SLUCH_SANK] 
--(SchetSluchSankID, [SchetSluch], [S_CODE],[S_SUM], [S_TIP], [S_OSN], [S_COM], [S_IST])

--SELECT '[IES].[T_SCHET_SLUCH_SANK]' as tableName, ' информации об удержаниях' as operationName, (select count(*) from tempdb..TEMP_SANK) as tableCount

--SELECT NEWID() as SchetSluchSankID, t2.[SchetSluchID] as SchetSluch, t1.[S_CODE], t1.[S_SUM], t1.[S_TIP], t1.[S_OSN], t1.[S_COM], t1.[S_IST]
--from tempdb..TEMP_SANK t1
--JOIN tempdb..TEMP_SLUCH t2 on (t2.[IDCASE] = t1.[IDCASE] and t1.SL_ID = t2.SL_ID)

SELECT '[IES].[T_SCHET_SLUCH_SANK]' as tableName, ' информации об удержаниях' as operationName, (select count(*) from tempdb..TEMP_SANK) as tableCount

SELECT t1.SchetSluchSankSLID as [SchetSluchSankID], t2.[SchetSluchAccomplishedID] as SchetSluchAccomplished, t1.[S_CODE], t3.[S_SUM], t3.[S_TIP]
,(select f014.F014DenyReasonID from [IES].T_F014_DENY_REASON f014 where f014.kod = t3.[S_OSN] and DATEBEG<=@ActualDate and (DATEEND is null or DATEEND>=@ActualDate)) AS [S_OSN]
, t3.[S_COM], t3.[S_IST], t3.DATE_ACT, t3.NUM_ACT,
(select [SchetSluchID] from tempdb..TEMP_SLUCH s where s.SL_ID = t1.SL_ID and s.IDCASE = t1.IDCASE) as [SchetSluch]
from tempdb..TEMP_SANK_SL_ID t1
join tempdb..TEMP_SANK t3 on (t1.S_CODE = t3.S_CODE and t1.IDCASE = t3.IDCASE)
JOIN tempdb..TEMP_Z_SLUCH t2 on (t1.IDCASE = t2.IDCASE)

select '[IES].[T_SCHET_SLUCH_SANK_EXP]' as tableName, ' информации об удержаниях' as operationName, (select count(*) from tempdb..TEMP_CODE_EXP ) as tableCount

SELECT NEWID() as SchetSluchSankExpID, s.SchetSluchSankID as SchetSluchSank, t1.[CODE_EXP] as [F004Expert]
from tempdb..TEMP_CODE_EXP t1  
JOIN tempdb..TEMP_SANK s on s.IDCASE = t1.IDCASE and s.S_CODE = t1.S_CODE

--SELECT '[IES].[T_SCHET_USL_NAPR]' as tableName, ' направления ' as operationName, (select count(*) from tempdb..TEMP_NAPR) as tableCount

--SELECT newid() as [SchetUslNaprID], t2.SchetSluchID as [SchetSluch], NAPR_DATE, NAPR_V, MET_ISSL, NAPR_USL, NAPR_MO
--from tempdb..TEMP_NAPR t1 
--JOIN tempdb..TEMP_SLUCH t2 on (t1.IDCASE = t2.IDCASE and t1.SL_ID = t2.SL_ID)

--SELECT '[IES].[T_SCHET_SLUCH_CONS]' as tableName, ' Сведения о проведении консилиума ' as operationName, (select count(*) from tempdb..TEMP_CONS) as tableCount

--SELECT newid() as [SchetSluchConsID], t2.SchetSluchID as [SchetSluch],(select N019OnkConsID from ies.T_N019_ONK_CONS n019 where n019.ID_CONS = t1.PR_CONS) as PR_CONS, DT_CONS
--from tempdb..TEMP_CONS t1 
--JOIN tempdb..TEMP_SLUCH t2 on (t1.IDCASE = t2.IDCASE and t1.SL_ID = t2.SL_ID)

SELECT '[IES].[T_SCHET_SLUCH_ONK]' as tableName, ' онкологические заболевания ' as operationName, (select count(*) from tempdb..TEMP_ONK_SL) as tableCount

SELECT SchetSluchOnkID, t2.SchetSluchID as [SchetSluch]
, (select top 1 N018.N018OnkReasID from [IES].[T_N018_ONK_REAS] N018 where n018.ID_REAS = t1.DS1_T) as [DS1_T]
, (select top 1 N002.N002StadiumID from [IES].[T_N002_STADIUM] N002 where N002.ID_St = t1.STAD) as [STAD]
, (select top 1 N003.N003TumorID from [IES].[T_N003_TUMOR] N003 where N003.ID_T = t1.ONK_T) as [ONK_T]
, (select top 1 N004.N004NodusID from [IES].[T_N004_NODUS] N004 where N004.ID_N = t1.ONK_N) as [ONK_N]
, (select top 1 N005.N005MetastasisID from [IES].[T_N005_METASTASIS] N005 where N005.ID_M = t1.ONK_M) as [ONK_M]
, MTSTZ, SOD, K_FR, WEI, HEI, BSA
from tempdb..TEMP_ONK_SL t1   
JOIN tempdb..TEMP_SLUCH t2 on (t2.[IDCASE] = t1.[IDCASE] and t2.SL_ID = t1.SL_ID)


SELECT '[IES].[T_SCHET_SLUCH_ONK_DIAG]' as tableName, ' диагностический блок ' as operationName, (select count(*) from tempdb..TEMP_B_DIAG) as tableCount

SELECT newid() as [SchetSluchOnkDiagID], t2.SchetSluchOnkID as [SchetSluchOnk], DIAG_TIP, DIAG_CODE, DIAG_RSLT, REC_RSLT, DIAG_DATE
from tempdb..TEMP_B_DIAG t1 
JOIN tempdb..TEMP_ONK_SL t2 on (t1.IDCASE = t2.IDCASE and t1.SL_ID = t2.SL_ID)

SELECT '[IES].[T_SCHET_SLUCH_ONK_PROT]' as tableName, ' сведения об имеющихся противопоказаниях ' as operationName, (select count(*) from tempdb..TEMP_B_PROT) as tableCount

SELECT newid() as [SchetSluchOnkProtID], t2.SchetSluchOnkID as [SchetSluchOnk], D_PROT
,(select top 1 N001.N001PrOtID from [IES].[T_N001_PrOt] N001 where N001.ID_PrOt = t1.PROT) as [PROT]
from tempdb..TEMP_B_PROT t1
JOIN tempdb..TEMP_ONK_SL t2 on (t1.IDCASE = t2.IDCASE and t1.SL_ID = t2.SL_ID)


SELECT '[IES].[T_SCHET_USL_NAPR]' as tableName, ' направления ' as operationName, (select count(*) from tempdb..TEMP_NAPR) as tableCount

SELECT newid() as [SchetUslNaprID], t2.SchetSluchID as [SchetSluch], NAPR_DATE, NAPR_V, MET_ISSL, NAPR_USL,  
(case when NAPR_MO = t3.LPU and NAPR_MO is not null then null 
else NAPR_MO
end) as NAPR_MO
from tempdb..TEMP_NAPR t1 
JOIN tempdb..TEMP_SLUCH t2 on (t1.IDCASE = t2.IDCASE and t1.SL_ID = t2.SL_ID) 
JOIN tempdb..TEMP_Z_SLUCH t3 on (t2.IDCASE = t3.IDCASE)

SELECT '[IES].[T_SCHET_SLUCH_CONS]' as tableName, ' Сведения о проведении консилиума ' as operationName, (select count(*) from tempdb..TEMP_CONS) as tableCount

SELECT newid() as [SchetSluchConsID], t2.SchetSluchID as [SchetSluch]
	,(select top 1 n019.N019OnkConsID from [IES].[T_N019_ONK_CONS] N019 where N019.ID_CONS = PR_CONS) as N019OnkCons, DT_CONS
from tempdb..TEMP_CONS t1 
JOIN tempdb..TEMP_SLUCH t2 on (t1.IDCASE = t2.IDCASE and t1.SL_ID = t2.SL_ID)

SELECT '[IES].[T_SCHET_USL_ONK]' as tableName, ' сведения об услуге при лечении онкологического заболевания ' as operationName, (select count(*) from tempdb..TEMP_ONK_USL) as tableCount

SELECT t1.SchetOnkUslID as [SchetUslOnkID], t2.SchetSluchOnkID as [SchetSluchOnk]
, (select top 1 N013.N013TreatTypeID from [IES].[T_N013_TREAT_TYPE] N013 where N013.ID_TLech = USL_TIP) as [USL_TIP]
, (select top 1 N014.N014SurgTreatID from [IES].[T_N014_SURG_TREAT] N014 where N014.ID_THir = HIR_TIP) as [HIR_TIP]
, (select top 1 N015.N015DrugTherapyLinesID from [IES].[T_N015_DRUG_THERAPY_LINES] N015 where N015.ID_TLek_L = LEK_TIP_L) as [LEK_TIP_L]
, (select top 1 N016.N016DrugTherapyCyclesID from [IES].[T_N016_DRUG_THERAPY_CYCLES] N016 where N016.ID_TLek_V = LEK_TIP_V) as [LEK_TIP_V]
, (select top 1 N017.N017RadiationTherapyTypesID from [IES].[T_N017_RADIATION_THERAPY_TYPES] N017 where N017.ID_TLuch = LUCH_TIP) as [LUCH_TIP]
, PPTR
from tempdb..TEMP_ONK_USL t1
JOIN tempdb..TEMP_ONK_SL t2 on (t1.IDCASE = t2.IDCASE and t1.SL_ID = t2.SL_ID)

select newid() as ID, t0.IDCASE, t0.SL_ID, t0.REGNUM, t0.CODE_SH, Left(t0.rezult,Len(t0.rezult)-1) As rezult into #temp_lek_pr
	From
    (
        Select distinct cast(t2.IDCASE as varchar(36)) as IDCASE, cast(t2.SL_ID as varchar(36)) as SL_ID, cast(t2.REGNUM as varchar(6)) as REGNUM, cast(t2.CODE_SH as varchar(10)) as CODE_SH,
            (
                Select cast(t1.DATE_INJ as varchar(40)) + ',' AS [text()]
                From tempdb..TEMP_LEK_PR_DATE_INJ t1
                Where (t1.IDCASE = t2.IDCASE and t1.SL_ID = t2.SL_ID and t1.REGNUM = t2.REGNUM and t1.CODE_SH = t2.CODE_SH)
                ORDER BY t1.REGNUM, t1.CODE_SH
                For XML PATH ('')
            ) rezult
        From tempdb..TEMP_LEK_PR_DATE_INJ t2
    ) t0 	
	
SELECT '[IES].[T_SCHET_USL_ONK_LEK_PR]' as tableName, ' сведения о лекарственных средствах' as operationName, (select count(*) from tempdb..TEMP_LEK_PR_DATE_INJ) as tableCount

SELECT ID as [SchetUslOnkLekPrID], t1.rezult as [DATE_INJ], (select top 1 t2.N020OnkLekpID from IES.T_N020_ONK_LEKP t2 where t1.REGNUM = t2.ID_LEKP) as REGNUM
	,(select top 1 v024.V024DopKrID from ies.T_V024_DOP_KR v024 where t1.CODE_SH = v024.IDDKK) as [V024DopKr], aa.SchetOnkUslID as [SchetUslOnk], t1.REGNUM as N020_R
from #temp_lek_pr t1
cross apply (select top 1 * from tempdb..TEMP_ONK_USL t2 where t1.IDCASE = t2.IDCASE and t1.SL_ID = t2.SL_ID and (t2.USL_TIP = 2 or t2.USL_TIP = 4)) aa

SELECT '[IES].[T_SCHET_USL_ONK_LEK_PR_DATE]' as tableName, ' сведения о датах лекарственных средств' as operationName, (select count(*) from tempdb..TEMP_LEK_PR_DATE_INJ) as tableCount

select newid() as [SchetUslOnkLekPrDateID], t2.ID as [SchetUslOnkLekPr], dateLek.DATE_INJ as [DATE_INJ]
from tempdb..TEMP_LEK_PR_DATE_INJ dateLek
join #temp_lek_pr t2 on (dateLek.IDCASE = t2.IDCASE and dateLek.SL_ID = t2.SL_ID and dateLek.REGNUM = t2.REGNUM and dateLek.CODE_SH = t2.CODE_SH)

--DROP TABLE #temp_dost   
--DROP TABLE #temp_dost_p
DROP TABLE #temp_lek_pr
DROP TABLE tempdb..TEMP_SCHET
DROP TABLE tempdb..TEMP_ZAP
DROP TABLE tempdb..TEMP_Z_SLUCH
DROP TABLE tempdb..TEMP_SLUCH
DROP TABLE tempdb..TEMP_USL
DROP TABLE tempdb..TEMP_SANK
DROP TABLE tempdb..TEMP_SANK_SL_ID
DROP TABLE tempdb..TEMP_CODE_EXP
DROP TABLE tempdb..TEMP_KSG_KPG
DROP TABLE tempdb..TEMP_CRIT
DROP TABLE tempdb..TEMP_SL_KOEF
DROP TABLE tempdb..TEMP_DS2_N
DROP TABLE tempdb..TEMP_DS2
DROP TABLE tempdb..TEMP_DS3
DROP TABLE tempdb..TEMP_CONS
DROP TABLE tempdb..TEMP_NAPR
DROP TABLE tempdb..TEMP_ONK_SL
DROP TABLE tempdb..TEMP_B_DIAG
DROP TABLE tempdb..TEMP_B_PROT
DROP TABLE tempdb..TEMP_ONK_USL
DROP TABLE tempdb..TEMP_LEK_PR_DATE_INJ

END

DROP TABLE #Errors
--DROP TABLE tempdb..TEMP_SCHET
--DROP TABLE tempdb..TEMP_ZAP
--DROP TABLE tempdb..TEMP_SLUCH
--DROP TABLE tempdb..TEMP_USL
--DROP TABLE tempdb..TEMP_REFREASON
--DROP TABLE tempdb..TEMP_DS2
--DROP TABLE tempdb..TEMP_DS3
--DROP TABLE tempdb..TEMP_SANK

END


