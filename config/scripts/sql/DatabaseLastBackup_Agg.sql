SET NOCOUNT ON;


IF OBJECT_ID('tempdb..#BackupTolerancyRules') IS NOT NULL
	DROP TABLE #BackupTolerancyRules;

CREATE TABLE #BackupTolerancyRules(
	ID bigint NOT NULL IDENTITY PRIMARY KEY
	,InstanceName nvarchar(100)
	,DatabaseName nvarchar(100)
	,BackupType varchar(5)
	,TimeTolerance bigint 
	,ManualPriority bigint DEFAULT 0
	,[Description] nvarchar(1000) NOT NULL DEFAULT 'General rule'
);

-- REGRAS PADRÃO PARA TODAS AS BASES
	INSERT INTO #BackupTolerancyRules (InstanceName,DatabaseName,BackupType,TimeTolerance) VALUES(NULL,NULL,NULL,NULL)


--------------------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#CalculatedTolerancy') IS NOT NULL
	DROP TABLE #CalculatedTolerancy;

SELECT  
	 @@SERVERNAME as CurrentInstance
	,D.name	AS DatabaseName
	,BKt.BackupType
	,CASE
		WHEN D.name = 'tempdb' THEN NULL
		WHEN DATABASEPROPERTYEX(D.name,'Recovery') = 'SIMPLE' AND BKt.BackupType = 'L' THEN NULL
		ELSE BT.TimeTolerance
	END as TimeTolerance
	,BT.InstanceName as RuleInstance
	,BT.DatabaseName as RuleDatabase
	,BT.BackupType		as RuleBackupType
	,BT.ManualPriority	as RuleManualPriority
	,BT.ID				as RuleID
	,ROW_NUMBER() OVER(
			PARTITION BY
				D.name
				,BKT.BackupType
				,CASE WHEN BT.DatabaseName = '$:EXTRATOLERANCE' THEN 1 ELSE NULL END
			ORDER BY
				 BT.ManualPriority DESC
				,CASE WHEN BT.DatabaseName LIKE '$:%' THEN 1 ELSE 2 END
			    ,CASE WHEN BT.InstanceName IS NOT NULL THEN 1 ELSE 2 END 
				,CASE WHEN BT.DatabaseName IS NOT NULL THEN 1 ELSE 2 END
				,CASE WHEN BT.BackupType IS NOT NULL THEN 1 ELSE 2 END
		) as TolerancePriority
INTO
	#CalculatedTolerancy
FROM 
	sys.databases D 
	CROSS APPLY
	(
		SELECT CONVERT(varchar(5),'D') as BackupType
		UNION ALL
		SELECT CONVERT(varchar(5),'I') as BackupType
		UNION ALL
		SELECT CONVERT(varchar(5),'L') as BackupType
	) BKT
	LEFT JOIN
	#BackupTolerancyRules BT
		ON	BKT.BackupType like ISNULL(BT.BackupType,'%')
		AND ( 
				D.name LIKE  ISNULL(BT.DatabaseName,'%') ESCAPE '\' 
				OR
				BT.DatabaseName = '$:SYSDB' AND D.database_id <= 4
				OR
				BT.DatabaseName = '$:EXTRATOLERANCE'
			)
		AND @@SERVERNAME LIKE  ISNULL(BT.InstanceName,'%') ESCAPE '\'
		
-- Pivot the variables (can contains extra values per database!)
IF OBJECT_ID('tempdb..#ExtraOptions') IS NOT NULL
	DROP TABLE #ExtraOptions
	
SELECT
	EO.DatabaseName
	,EO.BackupType
	,ExtraTolerance = EO.[$:EXTRATOLERANCE]
INTO
	#ExtraOptions
FROM
	(
		SELECT
			*
			,OptionName = UPPER(CT.RuleDatabase)
		FROM
			#CalculatedTolerancy CT
		WHERE
			CT.RuleDatabase LIKE '$:%'
	) D
	PIVOT
	(
		MAX(D.TimeTolerance) FOR D.OptionName IN ([$:EXTRATOLERANCE]) 
	) EO
	
		
		
IF OBJECT_ID('tempdb..#LastBackups') IS NOT NULL
	DROP TABLE #LastBackups;

SELECT
	BS.database_name		as DatabaseName
	,BS.type					as BackupType
	,MAX(BS.backup_finish_date)	as TimeLastBackup
	,CONVERT(bigint,DATEDIFF(SS,MAX(BS.backup_finish_date),CURRENT_TIMESTAMP)) as TimeNoBackup
INTO
	#LastBackups
FROM
	msdb..backupset BS
WHERE
	BS.is_copy_only = 0
GROUP BY
	BS.database_name
	,BS.type
	
	
	
IF OBJECT_ID('tempdb..#BackupTimes') IS NOT NULL
	DROP TABLE #BackupTimes;


SELECT
	*
	,CONVERT(bigint,CONVERT(bit,ISNULL(BT.TimeNoBackup/NULLIF(BT.Tolerance,0),0))) as BackupTimedOut
INTO
	#BackupTimes
FROM
(
	SELECT
		TL.DatabaseName
		,TL.RuleID
		,CASE TL.BackupType
			WHEN 'D' THEN 'FULL'
			WHEN 'I' THEN 'DIFF'
			WHEN 'L' THEN 'LOG'
		END							as BackupType
		,ISNULL(LB.TimeNoBackup,TL.InfiniteTime)	TimeNoBackup
		,CASE -- Determinando a tolerância. Dependendo da base do dia e dos backups anteriores, a tolerância informada pelo usuário pode ser ignorada.
			WHEN TL.TimeTolerance IS NULL THEN 0 
			WHEN TL.DatabaseName = 'tempdb' THEN 0
			WHEN TL.BackupType = 'I' AND TL.DatabaseName = 'master' THEN 0
			WHEN TL.BackupType = 'I' AND (LB.TimeNoFull < TL.TimeTolerance ) THEN TL.InfiniteTime -- Se o backup FULL tiver sido dentro da tolerância do DIFF, então desconsidera 
			ELSE TL.TimeTolerance + ISNULL(TL.ExtraTolerance,0)
		END Tolerance
		,TL.ExtraTolerance
	FROM
	(
		SELECT
			CT.*
			,CONVERT(bigint,DATEDIFF(MI,'19700101',CURRENT_TIMESTAMP))*60 as InfiniteTime
			,EO.ExtraTolerance
		FROM
			#CalculatedTolerancy CT
			LEFT JOIN
			#ExtraOptions EO
				ON EO.DatabaseName = CT.DatabaseName
				AND EO.BackupType = CT.BackupType
		WHERE
			CT.TolerancePriority = 1
			AND
			--Exclude variables!
			(
				CT.RuleDatabase NOT LIKE '$:%'
			)
	) TL
	LEFT JOIN
	(
		SELECT
			LB.*
			,LF.TimeNoBackup as TimeNoFull
		FROM
			#LastBackups LB
			OUTER APPLY
			(
				SELECT
					*
				FROM
					#LastBackups LBF
				WHERE
					LBF.BackupType = 'D'
					AND
					LBF.DatabaseName = LB.DatabaseName
			) LF
	) LB
		ON Tl.DatabaseName = LB.DatabaseName
		AND TL.BackupType = LB.BackupType
) BT


-- Se for o Zabbix que estiver executando...
IF PROGRAM_NAME() LIKE '%SQL2ZABBIX%'
BEGIN
	SELECT
		BT.BackupType
		,COUNT(CASE WHEN BT.BackupTimedOut = 1 THEN 1 END) as QtdTimedOut
	FROM
		#BackupTimes BT
	GROUP BY
		BT.BackupType	

	RETURN;
END
;

	
select * from #BackupTolerancyRules

SELECT 
	@@SERVERNAME as ServerInstance
	,BT.*
	,BTL.InstanceName		as RuleInstance
	,BTL.DatabaseName		as RuleDatabase
	,BTL.BackupType			as RuleBackup
	,BTL.ManualPriority		as RuleManualPriority
	,BTL.ID					as RuleID
	,TLR.TolerancePeriod	as TimeNoBackupH
	,TLR2.TolerancePeriod	as ToleranceH
FROM 
	#BackupTimes BT
	JOIN
	#BackupTolerancyRules BTL
		ON BTL.ID = BT.RuleID
	CROSS APPLY
	(

		SELECT
			ISNULL(NULLIF(t.Y+'y','0y'),'')
			+ISNULL(NULLIF(t.Mo+'mo','0mo'),'')
			+ISNULL(NULLIF(t.D+'d','0d'),'')
			+ISNULL(NULLIF(t.H+'h','0h'),'')
			+ISNULL(NULLIF(t.M+'m','0m'),'')
			+ISNULL(NULLIF(t.S+'s','0s'),'') as TolerancePeriod
		FROM
		(
			SELECT	
				 CONVERT(varchar(10),(BT.TimeNoBackup%60))			as S
				,CONVERT(varchar(10),(BT.TimeNoBackup/60)%60)		as M
				,CONVERT(varchar(10),(BT.TimeNoBackup/3600)%24)	as H
				,CONVERT(varchar(10),(BT.TimeNoBackup/86400)%30)	as D
				,CONVERT(varchar(10),(BT.TimeNoBackup/2592000)%12)	as Mo
				,CONVERT(varchar(10),(BT.TimeNoBackup/31104000))	as Y
		) T
	) TLR
	CROSS APPLY
	(

		SELECT
			ISNULL(NULLIF(t.Y+'y','0y'),'')
			+ISNULL(NULLIF(t.Mo+'mo','0mo'),'')
			+ISNULL(NULLIF(t.D+'d','0d'),'')
			+ISNULL(NULLIF(t.H+'h','0h'),'')
			+ISNULL(NULLIF(t.M+'m','0m'),'')
			+ISNULL(NULLIF(t.S+'s','0s'),'') as TolerancePeriod
		FROM
		(
			SELECT	
				 CONVERT(varchar(10),(BT.Tolerance%60))			as S
				,CONVERT(varchar(10),(BT.Tolerance/60)%60)		as M
				,CONVERT(varchar(10),(BT.Tolerance/3600)%24)		as H
				,CONVERT(varchar(10),(BT.Tolerance/86400)%30)	as D
				,CONVERT(varchar(10),(BT.Tolerance/2592000)%12)	as Mo
				,CONVERT(varchar(10),(BT.Tolerance/31104000))	as Y
		) T
	) TLR2
--WHERE
--	BackupTimedOut = 1
--	AND
--	BT.BackupType = 'LOG'
ORDER BY
	 BackupTimedOut DESC
	,ServerInstance
	,DatabaseName
	,BackupType