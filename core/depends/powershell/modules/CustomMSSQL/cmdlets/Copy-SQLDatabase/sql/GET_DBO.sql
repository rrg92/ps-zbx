SELECT
	SUSER_SNAME(DP.sid) as Owner
FROM
	sys.database_principals DP
WHERE
	DP.name = 'dbo'