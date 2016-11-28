"
DECLARE @DBFilter nvarchar(4000),@tsql nvarchar(4000); 
IF OBJECT_ID('tempdb..#DatabaseSessions') IS NOT NULL DROP TABLE #DatabaseSessions
CREATE TABLE #DatabaseSessions(session_id bigint, db_id bigint);

IF OBJECT_ID('master..sysprocesses') IS NOT NULL
	SET @tsql = N'INSERT INTO #DatabaseSessions SELECT S.spid ,S.dbid FROM master..sysprocesses S WHERE DB_NAME(S.dbid) = ''$DestinationDatabase'';'
	
ELSE IF OBJECT_ID('sys.dm_tran_locks') IS NOT NULL
	SET @tsql = N'INSERT INTO #DatabaseSessions	SELECT TL.request_session_id ,TL.request_database_id FROM master.sys.dm_tran_locks TL WHERE DB_NAME(TL.request_database_id) = ''$DestinationDatabase'';'

INSERT INTO #DatabaseSessions EXEC sp_executesql @tsql;
SET @tsql = NULL;

DECLARE  curDatabaseSessions CURSOR LOCAL FAST_FORWARD FOR SELECT DISTINCT 'KILL '+CONVERT(nvarchar(100),S.session_id) FROM  #DatabaseSessions S

OPEN curDatabaseSessions; FETCH NEXT FROM curDatabaseSessions INTO @tsql;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC(@tsql); FETCH NEXT FROM curDatabaseSessions INTO @tsql;
	END

IF DB_ID('$DestinationDatabase') IS NOT NULL
BEGIN
	EXEC('ALTER DATABASE [$DestinationDatabase] SET OFFLINE WITH ROLLBACK IMMEDIATE');
	EXEC('ALTER DATABASE [$DestinationDatabase] SET ONLINE');
END
"