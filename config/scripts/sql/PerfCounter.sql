-- Retorna diversos contadores

SELECT
	REPLACE(RTRIM(LTRIM(PC.counter_name)),' ','_')		as CounterName		
	,REPLACE(RTRIM(LTRIM(PC.instance_name)),' ','_')	as CounterInstanceName
	,PC.cntr_value										as CntrValue
FROM
	sys.dm_os_performance_counters PC
WHERE
	CONVERT(varchar(300),PC.counter_name) = 'Lock waits'
	OR
	(
		CONVERT(varchar(300),PC.counter_name) like '%Page Life Expectancy%'
		AND
		PC.object_name like '%:Buffer Node%'
	)