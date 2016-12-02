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
Function GetUserConfigFile(){
	$ConfigDir 	= GetConfigDir
	$AgentName	= GetAgentBaseName
	return $ConfigDir +"\agents\"+ $AgentName + ".config.ps1";
}


#Obtém um arquivo de log do agente!
Function GetAgentLogFile($LogFileName){
	return (GetLogDir) + "\psagents\" + $LogFileName
}


#Importa os módulos necessários para o agente
Function ImportAgentPsModules(){
	ImportPowershellModules "XLogging","CustomMSSQL"
}
