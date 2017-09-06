param(

	
	[parameter(Mandatory=$true)]
	#The SQL Server instance to connect to, when running SQL Scripts	
		$Instance
	
	,[parameter(Mandatory=$true)]
	#The keysgroup name. the keysgroup must be defined in the configuration file.	
		$KeysGroup
		
	,#Specify if you the agents runs in debug mode.
	 #In debug mode, some additional keys can be used, and more logging are generated.
	 #This must be used if you know internals of pszbx and wants debug something.
		[switch]
		$DebugMode = $false
	
	,#Indicates that agent will return a operating exit code.
	 #0 is for sucessfully execution. 1 is error
		[switch]
		$ReturnExitCode = $false
		
	,#The pooling time to be passed to Send-SQL2ZABBIX cmdlet
	 #You can check more about pooling time in the Send-SQL2Zabbix documentation.
	 #Basically, this tells to it how much time it will run before re-execute scripts and send results to zabbix again. 0 means, no loops, and ends execution after first loop.
		$PoolingTime = 0
		
	,#This is another parameter to be passed to Send-SQL2Zabbix cmdlet.
	 #You can check more about pooling time in the Send-SQL2Zabbix documentation.
	 #Basically, this tells to cmdlet the frequency, in seconds, that it will reload key definitions files.
		$ReloadTime = 120
		
	,#The hostname to be passed to Send-SQL2ZABBIX
	 #You can check more about pooling time in the Send-SQL2Zabbix documentation.
	 #Basically, this is the host in the zabbix, for which the collected data will be send.
		$HostName = $null
	
	,#If in debug mode, just use debug keys.
		[switch]
		$JustDebugKeys=$false
		
	,#Specify keysdef.ps1 files to be added to the keys definitions passed to Send-SQL2ZABBIX.
	 #If this specified, the KEYSGROUPS respective keys definitions files will be passed and this also.
		$KeysGroupFile = $null
		
	,#Specfy a extension for the logging files. Default is ".log"
		$LogFileNameExt = $null
		
		
	,#The log level of agent
		$LogLevel = "DETAILED"
		
	,#Specify if agent must derive the HostName parameter from a custom scriptblock in the configuration file.
	 #The option in configuraton file where your define script block is DYNAMIC_HOSTNAME_SCRIPT
	 #This script will recevei a parameter containing a hashtable with following properties:
	 #	
	 #	Instance = The -Instance parameter
	 #
	 #
	 #
	 # The script block must return a string. This result will be the value of -HostName parameter.
		[switch]
		$DynamicHostName = $false
		
	,#Specify a alternative configuration file.
	 #You can specifyu any valid powershell file.
	 #The configuration file must return a hashtable. Check the default cofniguration file for all possible options.
	 #If this parameter is used, then it overrides any other configuration file used.
	 #This will be cached, if is remote.
		$ConfigurationFile		  = $null
)

$ErrorActionPreference = "stop";

try {
	#Determinando o diretorio base atual para carregar as dependencias
	#O diretório base está a dois níveis acima.
		$CurrentFile		= $MyInvocation.MyCommand.Definition
		$CurrentFileBase	= [System.Io.Path]::GetFileNameWithoutExtension($CurrentFile)
		$CurrentDir 		= [System.Io.Path]::GetDirectoryName($CurrentFile)
		$BaseDir 			= [System.Io.Path]::GetDirectoryName([System.Io.Path]::GetDirectoryName($CurrentDir))
		$LibsDir			= $BaseDir + "\core\glibs"

		if(![System.IO.Directory]::Exists($LibsDir)){
			throw "LIB_DIR_NOT_FOUND: $LibsDir"
		}

	#Carregando as funções das bibliotecas!
	
		#Monta uma string que identifica o agente. Essa string representa uma identificação unica do agente baseado nos parametros fornecidos.
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
		
		#Configura as variáveis globais do PSZBX
		SetPsZbxVar 'BASE_DIR' $BaseDir
		SetPsZbxVar 'LIB_DIR' $LibsDir
		SetPsZbxVar 'AGENT_BASENAME' $CurrentFileBase
		
		#importando módulos dependentes
		ImportAgentPsModules
		
		#Configurando o mecanismo de log básico do agente!
		$InstanceName = PrepareServerInstanceString $Instance 
		$LogFileBaseName= $AgentID+".base.log";
		$LogFileName = GetAgentLogFile $LogFileBaseName -BaseDir $BaseDir -Default;
		$Log = New-LogObject
		$Log.LogTo = "#",$LogFileName;
		$Log.LogLevel = $LogLevel; 
		$Log.UseDLD = $false
		
		$Log | Invoke-Log "PSZBX started. Agent $CurrentFileBase. Keysgroup: $KeysGroup"
		$Log | Invoke-Log "Agent is logging messages to $LogFileName"
		
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
		
		#Configura a variável CONFIG!
		SetPsZbxVar 'AGENT_CONFIG' $CONFIG

	#Ajustando as constantes que possuem caminhos!
	ExpandDirs $CONFIG 
		



#Aqui começa o processamento do script. ALterar somente mediante orientação de alguém que conheça

	#Trata o nome da instância apropriadamente.
	$InstanceName = PrepareServerInstanceString $Instance 
	$Log | Invoke-Log "Instance Name is: $InstanceName" 
	
	
	#Escolhe o key group! Se o key group escolhido foi inválido, então avisa.
	#O keys groups é o conjunto de keys a ser usados. Ele é identificado por um nome pré-determinado neste script.
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
				#Se não termina com .keys.ps1
				$FileAtual = $File;
				
				if($FileAtual -NotLike "*.keys.ps1"){
					$FileAtual = $FileAtual+".keys.ps1";
				}
				
				$Keys += "$($CONFIG.KEYSDEF_DIR)\"+$FileAtual;
			}
		}
		
	#Verifica se o debug mode está ativo e adicionar as keys de debug.
		
		if($DebugMode){
			if($JustDebugKeys){
				$Keys = @();
			}
			$Keys += @($CONFIG._KEYS_GROUP.DEBUG);
			
		}


	#Se não há keys definitions, então força o erro.
		if(!$Keys){
			throw "NO_KEY_DEFINITION"
		}

	#If for pra determinar o hostname de modo dinâmico...
	if(!$HostName -and $DynamicHostName){
		$HostName = & $CONFIG.DYNAMIC_HOSTNAME_SCRIPT @{Instance=$Instance};
	}


	#Determina o nome do arquivo de log baseado no nome da instância informado.
		$LogFileNameBaseExtension = $LogFileNameExt;
		
		if(!$LogFileNameBaseExtension){
			$LogFileNameBaseExtension  = $KeysGroup.toLower()  + '.log';
		}
		
		$LogFileBaseName=$InstanceName.replace("\","$")+"."+$LogFileNameBaseExtension;
		$LogFileName = GetAgentLogFile $LogFileBaseName;
		
		
		$Send2ZabbixExecId = $AgentID;
		

	#Prepara os parâmetros a serem enviados usando Send-SQL2Zabbix!
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
			StorageArea		= $CONFIG.STORAGEAREA_DIR
		}
		
		if($CONFIG.SQL_APP_NAME){
			$Params.add("SQLAppName",$CONFIG.SQL_APP_NAME)
		}

		if($DebugMode){
			$Params.LogLevel = "VERBOSE"
		}

	#Chamando o cmdlet Send-SQL2Zabbix. Este cmdlet está definido no módulo CustomMSSQL.
	#Ele contém toda a lógica necessária para executar os scripts definidos na keys e enviar para o zabbix.
	#As atualizações podem ser baixadas do site github.com/rrg92/CustomMSSQL
		Send-SQL2Zabbix @Params
		$ExitCode = 0; #Marca como exit sucesso!
} catch {
	#Aqui é apenas um tratamento de erro.
		$ex = $_;
	
	#loga o erro no arquivo de log, se falhar, manda pro stdout!
		try {
			$msg = "ORIGINAL ERROR: $ex"
			
			if( [System.IO.File]::Exists($LogFileName) ){
				Out-File -InputObject "ERROR:" -FilePath $LogFileName -Append
				Out-File -InputObject $_ -FilePath $LogFileName -Append
			} else {
				throw "CANNOT CREATE_LOG_FILENAME: $LogFileName";
			}

		} catch {
			write-host "ORIGINAL ERROR: $ex";
			write-host "ERROR LOGGING ERROR: $_";
		}
	
	#Se for para finalizar sem retorna o exit code, então força um throw;
		if(!$ReturnExitCode){
			throw;
		}
	
		$ExitCode = 1
} finally {
	if($ReturnExitCode){
		exit $ExitCode;
	}
}


<#
	.SYNOPSIS 
		This is the DEFAULT agent of pszbx.
		
	.DESCRIPTION
		The DEFAULT main objective is prepare environment to calls Send-SQL2Zabbix, cmdlet that is part of CustomMSSQL module, responsbile to execute - scripts and map to zabbix keys, and send it to zabbix server.
		
		The main work is:
		
			- Setup logging
			- Check and handle parameters and configurations (like resolve directories paths, dynamic hostname, etc.)
			- Handle erros and correct reporting to calling application
			- Create the concept of "KEYSGROUP" and get all keus associated with a "KEYSGROUP"
		
		
		The agent define the concepts of "KEYSGROUPS", tht simply are a group of key definitions that will be send to Send-SQL2Zabbix cmdlet.
		
		CONFIGURATION
			The default configuration file of agent is ".config.ps1" located on same folder as the AGENT.
			You can specify a alternate configuraton file using -ConfigurationFile parameter.
			You also can place a configuraton file called "default.config.ps1" under /config/agent directory
		
		
		THE RELATION WITH SEND-SQL2ZABBIX
		
			The DEFAULT agent itself dont make many useful things in respect to zabbix and scripts to run.
			The magic is maded by "Send-SQL2Zabbix" of "CustomMSSQL".
			The work of agent is prepare the environment for the cmdlet runs.
			
			The DEFAULT agent presents a configuration with many options to the user and handles all things that Send-SQL2Zabbix will not handle.
			

		KEYSGROUP
			
			Keysgroup are a concept created by DEFAULT agent and dont exists in Send-SQL2Zabbix.
			The idea is allow a user maps a set os keys definitions to a name, and then, use this name in command line to reference this key.
			
			This allow user runs this AGENT with different groups os keuys.
			For example, you can define a KEYGROUP called "DEFAULT" and assing some keys definitions to it, and then, specify a instance of this agent to run this keygroup each 5 minutes.
			
			Then, you can define another keygroup, called "DISCOVERY", assign another group os keys specially for Low Level Discovery, and put it to run every 15 minutes.
			
			Note that with same agent, but differrent running instances, you can create interesting model of monitoring of you envinroment.
			
		THE AGENT CACHE
		
			This agent have a caching mechanism.
			Some files, can be located in remote shares.
			When this occurs, the agent will detect it, and stores it locally, in the cache folder.
			It will use the cached file whenever remote file is unavaliable.
			Check de description of parameters and configurations to determine which will be cached.
			
			The Send-SQL2ZABBIX also provides a caching mechanism. It will caches remote files specified in keys definitions.  This agent will setup de cache folder to it.
			
			In summary, this agent will cache this type files
			
						
			- File specified in -ConfigurationFile
			- Keys definitions files KEYSGROUP
			- Script files specified in keys definitions
			
			The "cache" directory in root, is used to store the cache of the AGENT.
			To more details and internals about cache, check doc/DEFAULTAGENT_CACHE.md
						
		
	.EXAMPLE

		C:\Zabbix\pszbx\core\agents\DEFAULT.ps1 -Instance "SQL1" -HostName "SQL1" -KeysGroup "MYKEYGROUPNAME"
		
		In This example you specify the agent with run connecting on SQL Instance SQL1, the hostname to be used in Zabbix is SQL1 and the keygroups is MYKEYGROUPNAME
		
	.NOTES
		

#>
