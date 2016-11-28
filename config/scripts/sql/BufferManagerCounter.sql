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
				object_name like '%:Buffer%Manager%'
		) CNT
	WHERE
		CNT.CounterName IN (
			'Database_Pages','Page_reads/sec','Page_writes/sec','Page_life_expectancy','Readahead_pages/sec'
		)