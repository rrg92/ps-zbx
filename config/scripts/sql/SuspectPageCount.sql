SELECT
	 COUNT(P.page_id) PageCount
FROM
	sys.databases D
	LEFT JOIN
	msdb.dbo.suspect_pages P
		on D.database_id = P.database_id