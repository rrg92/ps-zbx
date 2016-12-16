USE [msdb];

DECLARE
	@JobName nvarchar(128)
	,@BaseDir 	nvarchar(200)
	,@AgentName	nvarchar(200)
	,@KeysGroup nvarchar(1000)
	,@ConfigurationFile nvarchar(1000)
	,@PoolingTime	int
	,@JobFreqMin	int
	
-- ATENÇÃO: MUDAR O VALOR DAS VARIÁVEIS SE FOR EXECUTAR MANUALMENTE!
SET @JobName = '<JobName,,DBA: MON ZABBIX>'
SET @BaseDir = '<BaseDir,,C:\Zabbix\pszbx>'
SET @AgentName = '<AgentName,,DEFAULT>';
SET @KeysGroup = '<KeysGroup,,>';
SET @ConfigurationFile = <ConfigurationFile,,NULL>;
SET @PoolingTime = <PoolingTime,,>
SET @JobFreqMin = <JobFreqMin,,NULL>

-- ATENÇÃO: A PARTIR DAQUI, NADA PRECISA SER ALTERADO!
DECLARE	
	@jobcommand nvarchar(max)
	,@AgentPath nvarchar(max)
;

-- PS.: Colocando a barra usando char(92) por conta da exibição do arquivo no notepad++... :(
SET @AgentPath = @BaseDir + '\core\agents' +CHAR(92)+ @AgentName
SET @jobcommand = N'powershell -ExecutionPolicy ByPass -Command & '''+@AgentPath+''' -Instance "$(ESCAPE_NONE(MACH))\$(ESCAPE_NONE(INST))" -KeysGroup '+@KeysGroup+' -ReturnExitCode -PoolingTime '+CONVERT(nvarchar(15),@PoolingTime)+' -DynamicHostName'

IF @ConfigurationFile IS NOT NULL
	SET @jobcommand += ' -ConfigurationFile '+QUOTENAME(@ConfigurationFile,'"');

BEGIN TRANSACTION

	DECLARE @ReturnCode INT
	SELECT @ReturnCode = 0
	IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
	BEGIN
	EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

	END

	DECLARE @jobId BINARY(16)
	EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=@JobName, 
			@enabled=1, 
			@notify_level_eventlog=0, 
			@notify_level_email=2, 
			@notify_level_netsend=0, 
			@notify_level_page=0, 
			@delete_level=0, 
			@description=N'Executa os scripts para monitorar o ambiente', 
			@category_name=N'[Uncategorized (Local)]', 
			@owner_login_name=N'sa' 
			,@job_id = @jobId OUTPUT
			
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) 
		GOTO QuitWithRollback
	
	
	EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'EXEC_POWERSHELL_SCRIPT', 
			@step_id=1, 
			@cmdexec_success_code=0, 
			@on_success_action=1, 
			@on_success_step_id=0, 
			@on_fail_action=2, 
			@on_fail_step_id=0, 
			@retry_attempts=0, 
			@retry_interval=0, 
			@os_run_priority=0, @subsystem=N'CmdExec', 
			@command=@jobcommand, 
			@flags=32
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) 
		GOTO QuitWithRollback
		
	EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
	
	
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) 
		GOTO QuitWithRollback
		
	-- WHEN AGENT STARTS!
		EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=@JobName, 
				@enabled=1, 
				@freq_type=64
			
		IF (@@ERROR <> 0 OR @ReturnCode <> 0) 
			GOTO QuitWithRollback

	-- Each @Poolingtime seconds!
		DECLARE @PoolingTimeMinutes int;


		IF @JobFreqMin IS NULL
		BEGIN
			SET @PoolingTimeMinutes = (@PoolingTime/1000/60)*2  -- The schedule will be two times pooling time minutes, with monimum of 1 minute!
		END ELSE 
			SET @PoolingTimeMinutes = @JobFreqMin

		IF @PoolingTimeMinutes < 1
			SET @PoolingTimeMinutes = 1;

		EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=@JobName, 
				 @enabled=1
				,@freq_type=4								-- daily
				,@freq_interval=1							-- every 1 day;
				,@freq_subday_type=4						-- minutes
				,@freq_subday_interval=@PoolingTimeMinutes	-- every @PoolingTimeMinutes (minutes) @freq_sub)day

			
		IF (@@ERROR <> 0 OR @ReturnCode <> 0) 
			GOTO QuitWithRollback
		
	EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
	
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) 
		GOTO QuitWithRollback
COMMIT TRANSACTION

GOTO EndSave;

QuitWithRollback:
	IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
	
EndSave:

