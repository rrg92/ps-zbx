#Contém diversas funções usadas pelos agentes para obter informações e configurações.

#Obtém as configurações read_only
Function GetReadOnlyConfig(){
	$ReadOnlyConfigFile = (GetBaseDir) + "\core\agents\readonly.config.ps1";
	
	if(![System.IO.File]::Exists($ReadOnlyConfigFile)){
		throw "DEFAULT_CONFIG_FILE_NOT_FOUND: $ReadOnlyConfigFile"
	}
	
	return (& $ReadOnlyConfigFile);
}

#Obtém as configurações padroes
Function GetDefaultConfig(){
	$DefaultConfigFile = (GetBaseDir) + "\core\agents\.config.ps1";
	
	if(![System.IO.File]::Exists($DefaultConfigFile)){
		throw "DEFAULT_CONFIG_FILE_NOT_FOUND: $DefaultConfigFile"
	}
	
	return (& $DefaultConfigFile);
}


#Retorna o caminho para o arquivo de configuração do agente, definido pelo usuário.
Function GetUserConfigFile{

	$ConfigDir 	= GetConfigDir
	$AgentName	= GetAgentBaseName
	$ConfigFile = $ConfigDir +"\agents\"+ $AgentName + ".config.ps1";
		
	return $ConfigFile;
}

#obtém o caminho para o log do agente!
Function GetAgentDefaultLogDir {
	param($BaseDir = $null)
	
	if(!$BaseDir){
		$BaseDir = (GetBaseDir)
	}
	
	$LogDir = $BaseDir + '\log\psagents';
	
	if(![IO.Directory]::Exists($LogDir)){
		$Dir = New-Item -ItemType Directory -Path $LogDir -force;
	}
	
	return $LogDir;
}

#Obtém um arquivo de log do agente!
Function GetAgentLogFile($LogFileName, [switch]$Default = $false, $BaseDir = $null){

	if($Default){
		if($BaseDir){
			$LogFile = (GetAgentDefaultLogDir $BaseDir)+'\'+$LogFileName;
		} else {
			throw 'DEFAULT_LOG_FILE_ERROR: BASE_DIR_DONT_VALID'
		}
	} else {
		$LogFile = (GetLogDir) + "\psagents\" + $LogFileName
	}
	

	return  $LogFile  
}


#Importa os módulos necessários para o agente
Function ImportAgentPsModules(){
	ImportPowershellModules "XLogging","CustomMSSQL","CacheManager"
}
