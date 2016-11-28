SELECT
	DATEDIFF(MINUTE,D.create_date,CURRENT_TIMESTAMP) as UpTime
FROM	
	sys.databases D
WHERE	
	D.name = 'tempdb'