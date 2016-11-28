SELECT
	RTRIM(LTRIM(CONVERT(varchar(5),instance_name))) as NumaNode
FROM 
	sys.dm_os_performance_counters PC
WHERE
	PC.counter_name like '%Page Life Expectancy%'
	and
	PC.object_name like '%:Buffer Node%'