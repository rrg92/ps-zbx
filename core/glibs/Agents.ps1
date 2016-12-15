#Cont�m diversas fun��es usadas pelos agentes para obter informa��es e configura��es.

#Obt�m as configura��es read_only
Function GetReadOnlyConfig(){
	$ReadOnlyConfigFile = (GetBaseDir) + "\core\agents\readonly.config.ps1";
	
	if(![System.IO.File]::Exists($ReadOnlyConfigFile)){
		throw "DEFAULT_CONFIG_FILE_NOT_FOUND: $ReadOnlyConfigFile"
	}
	
	return (& $ReadOnlyConfigFile);
}

#Obt�m as configura��es padroes
Function GetDefaultConfig(){
	$DefaultConfigFile = (GetBaseDir) + "\core\agents\.config.ps1";
	
	if(![System.IO.File]::Exists($DefaultConfigFile)){
		throw "DEFAULT_CONFIG_FILE_NOT_FOUND: $DefaultConfigFile"
	}
	
	return (& $DefaultConfigFile);
}


#Retorna o caminho para o arquivo de configura��o do agente, definido pelo usu�rio.
Function GetUserConfigFile{

	$ConfigDir 	= GetConfigDir
	$AgentName	= GetAgentBaseName
	$ConfigFile = $ConfigDir +"\agents\"+ $AgentName + ".config.ps1";
		
	return $ConfigFile;
}


#Obt�m um arquivo de log do agente!
Function GetAgentLogFile($LogFileName, [switch]$Default = $false, $BaseDir = $null){

	if($Default){
		if($BaseDir){
			$LogFile = $BaseDir + '\log\psagents\' + $LogFileName;
		} else {
			throw 'DEFAULT_LOG_FILE_ERROR: BASE_DIR_DONT_VALID'
		}
	} else {
		$LogFile = (GetLogDir) + "\psagents\" + $LogFileName
	}
	

	return  $LogFile  
}


#Importa os m�dulos necess�rios para o agente
Function ImportAgentPsModules(){
	ImportPowershellModules "XLogging","CustomMSSQL","CacheManager"
}
