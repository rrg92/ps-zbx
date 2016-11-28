-- Retorna o nome dos perfcounters específicos da instância SQL.
--> Utilize o filtro para determinar o conjunto de perfcounters a ser retornado!


IF OBJECT_ID('tempdb..#Rules') IS NOT NULL
	DROP TABLE #Rules;

CREATE TABLE #Rules (
	ID bigint NOT NULL IDENTITY PRIMARY KEY
	,InstanceName nvarchar(2000)
	,ObjectName nvarchar(1000)
	,CounterName nvarchar(1000)
	,CounterInstance nvarchar(1000)
	,ManualPriority bigint DEFAULT 0
);



	INSERT INTO #Rules(InstanceName,ObjectName,CounterName,CounterInstance) VALUES (NULL,'%:Wait Statistics','Lock Waits','Waits in progress')
	INSERT INTO #Rules(InstanceName,ObjectName,CounterName,CounterInstance) VALUES (NULL,'%:Wait Statistics','Page IO latch waits','Waits in progress')
	INSERT INTO #Rules(InstanceName,ObjectName,CounterName,CounterInstance) VALUES (NULL,'%:Wait Statistics','Wait for the worker','Waits in progress')
	INSERT INTO #Rules(InstanceName,ObjectName,CounterName,CounterInstance) VALUES (NULL,'%:Wait Statistics','Memory grant queue waits','Waits in progress')
	INSERT INTO #Rules(InstanceName,ObjectName,CounterName,CounterInstance) VALUES (NULL,'%:Locks','Number of Deadlocks/sec','_Total')



---------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#CountersRules') IS NOT NULL
	DROP TABLE #CountersRules;

IF OBJECT_ID('tempdb..#Counters') IS NOT NULL
	DROP TABLE #Counters;

SELECT
	'\'+C.ObjectName+ISNULL('('+C.CounterInstance+')','')+'\'+C.CounterName as CounterPath
	,C.*
	,CASE
		WHEN C.ObjectName LIKE '%:%' THEN RIGHT(C.ObjectName,LEN(C.ObjectName)-CHARINDEX(':',C.ObjectName)) 
		ELSE C.ObjectName
	END					as ObjectNameOnly
	,R.ID				as RuleID
	,R.ObjectName		as RObjectName
	,R.CounterName		as RCounterName
	,R.CounterInstance	as RCounterInstance
	,R.ManualPriority	as RManualPriority
	,ROW_NUMBER() OVER(  
			PARTITION BY
				C.ObjectName,C.CounterName,C.CounterInstance
			ORDER BY
				 R.ManualPriority DESC
				 ,CASE WHEN R.ObjectName IS NULL THEN 2 ELSE 1 END
				 ,CASE WHEN R.CounterName IS NULL THEN 2 ELSE 1 END
				 ,CASE WHEN R.CounterInstance IS NULL THEN 2 ELSE 1 END
		) as PriorityNum
INTO
	#CountersRules
FROM
	(
		SELECT
			 RTRIM(LTRIM(object_name))					as ObjectName
			,RTRIM(LTRIM(counter_name))					as CounterName
			,NULLIF(RTRIM(LTRIM(instance_name)),'')		as CounterInstance
		FROM
			sys.dm_os_performance_counters PC
	) C
	JOIN
	#Rules R
		ON	@@SERVERNAME LIKE  ISNULL(R.InstanceName,'%') ESCAPE '\'
		AND C.ObjectName	LIKE ISNULL(R.ObjectName,'%')	COLLATE Latin1_General_CI_AI ESCAPE '\'
		AND C.CounterName	LIKE ISNULL(R.CounterName,'%')	COLLATE Latin1_General_CI_AI ESCAPE '\'
		AND ISNULL(C.CounterInstance,'')	LIKE ISNULL(R.CounterInstance,'%')	COLLATE Latin1_General_CI_AI ESCAPE '\'



SELECT
	*
INTO
	#Counters
FROM
	#CountersRules CR
WHERE
	CR.PriorityNum = 1


--> Se for a conta do Zabbix que estiver executando o script, então retorna somente o nome do contadore e encerra!
IF SUSER_NAME() LIKE '%ZabbixService%'
BEGIN
	SELECT ObjectNameOnly,CounterName,CounterInstance,CounterPath FROM #Counters;
	RETURN;
END


SELECT * FROM #Counters