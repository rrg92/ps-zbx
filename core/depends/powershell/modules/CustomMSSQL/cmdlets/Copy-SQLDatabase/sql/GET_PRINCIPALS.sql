SELECT
	 DP.name as principalName
	,SUSER_SNAME(DP.sid) as serverPrincipal
	,DP.type_desc
FROM
	sys.database_principals DP
WHERE
	DP.is_fixed_role = 0
	AND
	DP.name NOT IN ('dbo','guest','sys','INFORMATION_SCHEMA','public')
	AND  
	DP.name NOT LIKE '##%'

