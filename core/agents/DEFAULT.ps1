param(

	[parameter(Mandatory=$true)]
		$Instance
	
	,[parameter(Mandatory=$true)]
		$KeysGroup
		
	,[switch]$DebugMode = $false
	,[switch]$ReturnExitCode = $false
	,$PoolingTime = 0
	,$ReloadTime = 120
	,$HostName = $null
	,[switch]$JustDebugKeys=$false
	,$KeysGroupFile = $null
	,$LogFileNameExt = $null
	,$LogLevel = "DETAILED"
	,[switch]$DynamicHostName = $false
	,$ConfigurationFile		  = $null
)

$ErrorActionPreference = "stop";

try {
	#Determinando o diretorio base atual para carregar as dependencias
	#O diret�rio base est� a dois n�veis acima.
		$CurrentFile		= $MyInvocation.MyCommand.Definition
		$CurrentFileBase	= [System.Io.Path]::GetFileNameWithoutExtension($CurrentFile)
		$CurrentDir 		= [System.Io.Path]::GetDirectoryName($CurrentFile)
		$BaseDir 			= [System.Io.Path]::GetDirectoryName([System.Io.Path]::GetDirectoryName($CurrentDir))
		$LibsDir			= $BaseDir + "\core\glibs"

		if(![System.IO.Directory]::Exists($LibsDir)){
			throw "LIB_DIR_NOT_FOUND: $LibsDir"
		}

	#Carregando as fun��es das bibliotecas!
	
		#Monta uma string que identifica o agente. Essa string representa uma identifica��o unica do agente baseado nos parametros fornecidos.
		$AgentID = $Instance.replace('\','$');
		
		if($KeysGroup){
			$AgentID += ".$KeysGroup"
		}
		
		if($DebugMode){
			$AgentID += '.DEBUG'
		}
		

	
		$OriginalDebugMode = $DebugMode;
		try {
			$LoadLib = $LibsDir + '\LoadLibs.ps1';
			. $LoadLib $BaseDir;
		} catch {
			throw "LIBS_LOAD_FAILED: $_"
		}
		$DebugMode = $OriginalDebugMode;
		
		#Configura as vari�veis globais do PSZBX
		SetPsZbxVar 'BASE_DIR' $BaseDir
		SetPsZbxVar 'LIB_DIR' $LibsDir
		SetPsZbxVar 'AGENT_BASENAME' $CurrentFileBase
		
		#importando m�dulos dependentes
		ImportAgentPsModules
		
		#Configurando o mecanismo de log b�sico do agente!
		$InstanceName = PrepareServerInstanceString $Instance 
		$LogFileBaseName= $AgentID+".base.log";
		$LogFileName = GetAgentLogFile $LogFileBaseName -BaseDir $BaseDir -Default;
		$Log = New-LogObject
		$Log.LogTo = "#",$LogFileName;
		$Log.LogLevel = $LogLevel; 
		$Log.UseDLD = $false
		
		$Log | Invoke-Log "PSZBX started. Agent $CurrentFileBase. Keysgroup: $KeysGroup"
		
		#Configurando o cache manager!
		$AgentCache = New-CacheManager;
		$AgentCache.logLevel = $Log.LogLevel;
		$AgentCache.logTo = {
			param($lp)
			
			$Log | Invoke-Log -Message $lp.message -Level $lp.level;
		}
		$AgentCache.cacheDirectory = "$BaseDir\cache\agentcache\"+$AgentID 
		$AgentCache.init();
		SetPsZbxVar 'CACHE_MANAGER' $AgentCache
		
		if($ConfigurationFile){
			$ConfigFileName	 = $AgentCache.getFile($ConfigurationFile);
			$Log | Invoke-Log "Using a supplied configuration file: $ConfigFileName"
		} else{
			$ConfigFileName		= GetUserConfigFile 
		}

		$USER_CONFIG = @{};
		if([System.IO.File]::Exists($ConfigFileName)){
			try {
				$USER_CONFIG = & $ConfigFileName;
			} catch {
				throw "ERR_LOADING_USER_CONFIG_FILE: $_"
			} 
		} else {
			$Log | Invoke-Log "Configuration file not found: $ConfigFileName"
		}
		
		$CONFIG = DefineConfiguratons $USER_CONFIG;
		
		#Configura a vari�vel CONFIG!
		SetPsZbxVar 'AGENT_CONFIG' $CONFIG

	#Ajustando as constantes que possuem caminhos!
	ExpandDirs $CONFIG 
		



#Aqui come�a o processamento do script. ALterar somente mediante orienta��o de algu�m que conhe�a

	#Trata o nome da inst�ncia apropriadamente.
	$InstanceName = PrepareServerInstanceString $Instance 
	$Log | Invoke-Log "Instance Name is: $InstanceName" 
	
	
	#Escolhe o key group! Se o key group escolhido foi inv�lido, ent�o avisa.
	#O keys groups � o conjunto de keys a ser usados. Ele � identificado por um nome pr�-determinado neste script.
	#Isto permite reaproveitar este script para monitorar diferentes items.
		$Keys = @()
	
		if(!$KeysGroup){
			throw 'INVALID_KEYS_GROUP: IS EMPTY'
		}
	
		if($KeysGroup){
			$KeysGroup = $KeysGroup.toUpper();
			
			if(!$CONFIG.KEYS_GROUP.Contains($KeysGroup)){
				throw "INVALID_KEYS_GROUP: $KeysGroup";
			}

			$Keys = @($CONFIG.KEYS_GROUP.$KeysGroup)
		}
		
	#Carrega os keys, caso seja especificado ....
		if($KeysGroupFile){
			foreach($File in $KeysGroupFile){
				#Se n�o termina com .keys.ps1
				$FileAtual = $File;
				
				if($FileAtual -NotLike "*.keys.ps1"){
					$FileAtual = $FileAtual+".keys.ps1";
				}
				
				$Keys += "$($CONFIG.KEYSDEF_DIR)\"+$FileAtual;
			}
		}
		
	#Verifica se o debug mode est� ativo e adicionar as keys de debug.
		
		if($DebugMode){
			if($JustDebugKeys){
				$Keys = @();
			}
			$Keys += @($CONFIG._KEYS_GROUP.DEBUG);
			
		}


	#Se n�o h� keys definitions, ent�o for�a o erro.
		if(!$Keys){
			throw "NO_KEY_DEFINITION"
		}

	#If for pra determinar o hostname de modo din�mico...
	if(!$HostName -and $DynamicHostName){
		$HostName = & $CONFIG.DYNAMIC_HOSTNAME_SCRIPT @{Instance=$Instance};
	}


	#Determina o nome do arquivo de log baseado no nome da inst�ncia informado.
		$LogFileNameBaseExtension = $LogFileNameExt;
		
		if(!$LogFileNameBaseExtension){
			$LogFileNameBaseExtension  = $KeysGroup.toLower()  + '.log';
		}
		
		$LogFileBaseName=$InstanceName.replace("\","$")+"."+$LogFileNameBaseExtension;
		$LogFileName = GetAgentLogFile $LogFileBaseName;
		
		
		$Send2ZabbixExecId = $AgentID;
		

	#Prepara os par�metros a serem enviados usando Send-SQL2Zabbix!
		$Params = @{
			Instance		= $InstanceName
			HostName		= $hostname
			KeysDefinitions	= $Keys
			ZabbixServer	= $CONFIG.ZABBIX_SERVERPORT
			ZabbixSender	= $CONFIG.ZABBIXSENDER_PATH
			DirScripts 		= $CONFIG.SCRIPTS_DIR 
			PoolingTime		= $PoolingTime
			LogLevel		= $LogLevel
			LogTo			= "#",$LogFileName
			ReloadTime		= $ReloadTime
			UserCustomData 	= @{
								SQLPINGLOGDIR = "$($CONFIG.LOGBASE_DIR)\sqlping"
							}
			CacheFolder		= ($CONFIG.CACHE_DIR+'\send2zabbix')
			ExecutionID		= $Send2ZabbixExecId
		}
		
		if($CONFIG.SQL_APP_NAME){
			$Params.add("SQLAppName",$CONFIG.SQL_APP_NAME)
		}

		if($DebugMode){
			$Params.LogLevel = "VERBOSE"
		}

	#Chamando o cmdlet Send-SQL2Zabbix. Este cmdlet est� definido no m�dulo CustomMSSQL.
	#Ele cont�m toda a l�gica necess�ria para executar os scripts definidos na keys e enviar para o zabbix.
	#As atualiza��es podem ser baixadas do site scriptstore.thesqltimes.com/docs/custommssql
		Send-SQL2Zabbix @Params
		$ExitCode = 0; #Marca como exit sucesso!
} catch {
	#Aqui � apenas um tratamento de erro.
		$ex = $_;
	
	#loga o erro no arquivo de log, se falhar, manda pro stdout!
		try {
			$msg = "ORIGINAL ERROR: $ex"
			
			if( [System.IO.File]::Exists($LogFileName) ){
				Out-File -InputObject "ERROR:" -FilePath $LogFileName -Append
				Out-File -InputObject $_ -FilePath $LogFileName -Append
			}

		} catch {
			write-host "ORIGINAL ERROR: $ex";
			write-host "ERROR LOGGING ERROR: $_";
		}
	
	#Se for para finalizar sem retorna o exit code, ent�o for�a um throw;
		if(!$ReturnExitCode){
			throw;
		}
	
		$ExitCode = 1
} finally {
	if($ReturnExitCode){
		exit $ExitCode;
	}
}