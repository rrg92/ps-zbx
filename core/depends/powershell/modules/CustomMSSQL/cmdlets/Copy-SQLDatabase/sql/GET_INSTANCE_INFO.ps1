param($VALUES)

return "

SELECT 
	 CONVERT(varchar(200),@@Version) 										as VersionText
	,CONVERT(varchar(200),SERVERPROPERTY('ProductVersion')) 				as ProductVersion
	,CONVERT(varchar(200),@@SERVERNAME) 									as ServerInstance
	,CONVERT(varchar(200),SERVERPROPERTY('MachineName')) 					as ResponseName
	,CONVERT(varchar(200),SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) 	as ComputerName
	,ISNULL((SELECT 1 WHERE DB_ID('$($VALUES.PARAMS.DestinationDatabase)') IS NOT NULL),0)		as DestinationDatabaseExists
"