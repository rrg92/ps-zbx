SELECT -- This query will retrive permissions for all principals.
	 CONVERT(varchar(50),'PERMISSION') as ScriptType
	,DP.name as principalName
	,P.permission_name
	,P.state_desc as PermissionState
	,P.class_desc
	,P.major_id
	,P.minor_id
	,SC.SecurableClass
	,SC.SecurableName
	,SC.SecurableMinorName
FROM
	sys.database_principals DP
	INNER JOIN
	sys.database_permissions P
		ON P.grantee_principal_id = DP.principal_id
	OUTER APPLY
	(
		SELECT
			-- Here will lets convert class_desc column from sys.database_principals into a securale_class, in order to build correct DCL command.
			CASE 
				WHEN P.class_desc = 'OBJECT_OR_COLUMN'		THEN 'OBJECT'
				WHEN P.class_desc = 'DATABASE_PRINCIPAL'	THEN (SELECT -- The DATABASE_PRINCIPAL is mapped to APPLICATION ROLE, ROLE or USER securable classes.
																		CASE
																			WHEN DP.type_desc like '%ROLE%' THEN REPLACE(DP.type_desc,'_','')
																			ELSE 'USER'
																		END
																	FROM 
																		sys.database_principals DP2 
																	WHERE
																		DP2.principal_id = P.major_id
																)

				-- Most of another class have a unique row on securable_classes. If it apply, then we get them.
				WHEN 1 = (SELECT count(*) FROM sys.securable_classes SC WHERE SC.class = P.class)  THEN (select SC.class_desc FROM sys.securable_classes SC WHERE SC.class  = P.class)
				
				-- If we dont can found a correct securable, it will be NULL. Script must handle this we building DCL.
			END as SecurableClass

			-- Here we'll get the securable name according class_desc.
			,CASE P.class_desc
				WHEN 'OBJECT_OR_COLUMN'			THEN (SELECT QUOTENAME(SCHEMA_NAME(O.schema_id))+'.'+QUOTENAME(O.name)  FROM sys.all_objects O WHERE O.object_id = P.major_id) COLLATE Latin1_General_CI_AI
				WHEN 'SCHEMA'					THEN (SELECT QUOTENAME(S.name) FROM sys.schemas S WHERE S.schema_id = P.major_id) 
				WHEN 'DATABASE_PRINCIPAL'		THEN (SELECT QUOTENAME(DBP.name) FROM sys.database_principals DBP WHERE DBP.principal_id = P.major_id)
				WHEN 'ASSEMBLY'					THEN (SELECT QUOTENAME(A.name) FROM sys.assemblies A WHERE A.assembly_id = P.major_id)
				WHEN 'TYPE'						THEN (SELECT QUOTENAME(T.name) FROM sys.types T WHERE T.user_type_id = P.major_id)
				WHEN 'XML_SCHEMA_COLLECTION'	THEN (SELECT QUOTENAME(X.name) FROM sys.xml_schema_collections X WHERE X.xml_collection_id = P.major_id)
				WHEN 'MESSAGE_TYPE'				THEN (SELECT QUOTENAME(SMT.name) FROM sys.service_message_types SMT  WHERE SMT.message_type_id = P.major_id)
				WHEN 'SERVICE_CONTRACT'			THEN (SELECT QUOTENAME(SC.name) FROM sys.service_contracts SC WHERE SC.service_contract_id = P.major_id)
				WHEN 'SERVICE'					THEN (SELECT QUOTENAME(S.name) FROM sys.services S WHERE S.service_id = P.major_id)
				WHEN 'REMOTE_SERVICE_BINDING'	THEN (SELECT QUOTENAME(RSB.name) FROM sys.remote_service_bindings RSB WHERE RSB.remote_service_binding_id = P.major_id)
				WHEN 'ROUTE'					THEN (SELECT QUOTENAME(R.name) FROM sys.routes R WHERE R.route_id = P.major_id)
				WHEN 'FULLTEXT_CATALOG'			THEN (SELECT QUOTENAME(FC.name) FROM sys.fulltext_catalogs FC WHERE FC.fulltext_catalog_id = P.major_id)
				WHEN 'SYMMETRIC_KEYS'			THEN (SELECT QUOTENAME(SMK.name) FROM sys.symmetric_keys SMK WHERE SMK.symmetric_key_id = P.major_id)
				WHEN 'CERTIFICATE'				THEN (SELECT QUOTENAME(C.name) FROM sys.certificates C WHERE C.certificate_id = P.major_id)
				WHEN 'ASYMMETRIC_KEY'			THEN (SELECT QUOTENAME(AMK.name) FROM sys.all_objects AMK WHERE AMK.object_id = P.major_id)
				WHEN 'DATABASE'					THEN QUOTENAME(DB_NAME())
			END as SecurableName

			-- Here, we'll get the minor name, if do.
			,CASE P.class_desc
				WHEN 'OBJECT_OR_COLUMN' THEN (SELECT C.name FROM sys.all_columns C where C.object_id = P.major_id AND C.column_id = P.minor_id) COLLATE Latin1_General_CI_AI
			END as SecurableMinorName
		) SC
WHERE
	DP.is_fixed_role = 0
	AND
	DP.name NOT IN ('dbo','guest','sys','INFORMATION_SCHEMA','public')
	AND  
	DP.name NOT LIKE '##%'

