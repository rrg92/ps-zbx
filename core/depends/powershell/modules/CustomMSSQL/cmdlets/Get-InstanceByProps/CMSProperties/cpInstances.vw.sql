IF OBJECT_ID('cmsprops.cpInstances') IS NULL
	EXEC('CREATE VIEW [cmsprops].[cpInstances] AS SELECT 1 AS StubVersion');
GO

ALTER VIEW
	[cmsprops].[cpInstances]
AS
	SELECT
		S.server_id		AS serverId
		,S.name			AS displayName
		,S.server_name	AS connectionName
		,S.description	AS instanceDescription
	FROM
		msdb..sysmanagement_shared_registered_servers S
		
	UNION ALL 
	
	SELECT
		-1
		,@@SERVERNAME
		,@@SERVERNAME
		,'CMS'
GO


EXEC sp_refreshsqlmodule 'cmsprops.cpInstances';