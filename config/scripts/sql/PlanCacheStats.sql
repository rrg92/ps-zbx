SELECT
	REPLACE(RTRIM(LTRIM(PC.counter_name)),' ','_')			as CounterName		
	,REPLACE(RTRIM(LTRIM(PC.instance_name)),' ','_')		as CounterInstanceName
	,CONVERT(bigint,PC.cntr_value*8)						as CntrValue
FROM
	sys.dm_os_performance_counters PC
WHERE
	CONVERT(varchar(300),PC.counter_name) = 'Cache Pages'
	AND
	CONVERT(varchar(300),PC.object_name) like '%:Plan Cache'
	AND
	PC.instance_name IN (
		'Object Plans','SQL Plans','Bound_Tress','_Total'
	)                