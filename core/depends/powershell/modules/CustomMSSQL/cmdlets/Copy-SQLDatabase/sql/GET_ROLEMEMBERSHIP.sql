SELECT
	 USER_NAME(rm.role_principal_id)		as roleName
	,USER_NAME(RM.member_principal_id)		as memberName
FROM
	sys.database_role_members RM
WHERE	
	USER_NAME(RM.member_principal_id) NOT IN ('dbo','guest','sys','INFORMATION_SCHEMA','public')