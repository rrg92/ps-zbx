SELECT
	*
FROM
	(
		SELECT 
			REPLACE(REPLACE(RTRIM(counter_name),' (KB)',''),' ','_') as CounterName 
			,CONVERT(bigint,cntr_value)	as CounterValue
		FROM 
			sys.dm_os_performance_counters
		WHERE
			object_name like '%memory%'
	) CNT
WHERE
	CNT.CounterName IN (
		'Total_Server_Memory','Target_Server_Memory','Lock_Memory','Connection_Memory'
	)