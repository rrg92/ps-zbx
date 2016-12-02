#Arquivo contendo funções diversas para auxiliar os scripts.

#Local centralizado de variáveis deste script.


#Retorna o valor do diretorio base.
Function GetBaseDir(){
	return GetPsZbxVar 'BASE_DIR'
}

#Retorna o caminho para o diretório de configuração, baseado no diretorio base.
Function GetConfigDir(){
	return (GetBaseDir) + "\config";
}

#Retorna o caminho para o diretório de log, baseado no diretorio base.
Function GetLogDir(){
	$Config = GetPsZbxVar 'AGENT_CONFIG';
	return $Config.LOGBASE_DIR;
}

#Retorna o caminho para o diretório de log default, que é entregue junto com a solução!
Function GetDefaultLogDir(){
	$BaseDir = GetBaseDir;
	return $BaseDir + '\log'
}

#Retorna o caminho para o diretorio de módulos
Function GetModulesDir {
	return (GetBaseDir) + '\core\depends\powershell\modules'
}


#Retorna o nome base do agente. Que é o nome do arquivo, sem a extensão .ps1
Function GetAgentBaseName(){
	if(CheckGlobalVars PSZBX_AGENT_BASENAME){
		return Get-Variable -Scope Global -Name 'PSZBX_AGENT_BASENAME' -ValueOnly
	} else {
		throw "GLOBAL_VAR_NOT_DEFINED: PSZBX_AGENT_BASENAME"
	}
}

#Ajusta as configurações baseadas no valor padrão e no valor determinado pelo usuário!
Function DefineConfiguratons($USERCONFIG) {
	$NewConfig = GetDefaultConfig;
	
	#Iterando sobre a lista de keys para alterar aquelas que foram defindias pelo usuário!
	$NewConfig = MergeHashTables -Dest $NewConfig -Src $USERCONFIG
	
	#Adiciona as configurações readonly
	$NewConfig += (GetReadOnlyConfig)

	return $NewConfig;
}


#Esta função verifica se um dado item da configuração deve ser expandido (é um path)
#O $ItemName indica o nome do item. É um path completo. Se estiver dentro de uma hashtable deve incluir o nome da mesma.
#Se for  a hashtable pai, então um '\' basta.
Function IsPathItem($ItemName, $ItemValue) {
	#Lista de padrões de nome que podem ser paths.
	$Wilds = "*_DIR","*_PATH","KEYS_GROUP\*","_KEYS_GROUP\*"
	
	if($ItemValue -is [hashtable]){
		$ItemName += "\"
	}
	
	if( $Wilds | ? {$ItemName -like '\'+$_} ){
		return $true;
	}
	
	return $false;
}

#Função para realizar a expansão de diretorio.
#A expansão de diretório é um processo para transformar os caminhos relativos em abosolutos.
#Ex.: Os items com configuração \x\y vão virar C:\x\y (por exemplo).
#A função já trata toda a expansão. Se houver items cujo o valor é outra hashtable, a função irá tratar adequadamente.
#A função também trata adequadamente as expansões de item cujo o valor é um array de string... expandindo cada valor se necessário...

Function ExpandDirs($Table, $HashPath = $null){
	
	#O hash path é um apenas um meio de indicar a função quem são os pais do item.
	#POr exemplo, considere:
	#	@{ A = 1; B = @{ B1 = 'b1'; B2 = 'b2' } }
	#
	# Neste caso, ao expandir B1, que é filho de B, a função irá passar um hash path '\B', indicando que B é a hashpai.
	#Desse modo, fica muito simples especificar na função IsPathItem, os filtros dos items que devem ser expandidos.
	#Por exemplo, se todos os items de b2 são items que podem ser expandidos, então o filtro ficaria B1*
	
	#para cada key da hash...
	$BaseDir = GetBaseDir;
	
	@($Table.Keys) |  %{
		$CurrentItem 	= $_;
		$CurrentValue 	= $Table[$CurrentItem];

		if(!(IsPathItem "$HashPath\$_" $CurrentValue)){
			return; #Proximo!
		}
		
		
		#se o valor atual é um hashtable, monta o path e chama a recursividade...
		if($CurrentValue -is [hashtable]){
			
			ExpandDirs -Table $CurrentValue -HashPath "$HashPath\$CurrentItem"
			return; #Vai pra próxima key...
		}
		
		
		
		$ExpandedValue	= @($CurrentValue); #Array temporário. Para os casos onde o valor é um array de string!
		$i 				= $ExpandedValue.count
		
		
		if($CurrentValue){
			#Para cada item do array temporário, expande-o e guarda novamente na mesma posição.
			while($i--){
				
				if($ExpandedValue[$i] -match '^\\[^\\].*'){
					$ExpandedValue[$i] = $BaseDir  + $ExpandedValue[$i]
				}
			}
		}
		
		
		#Se o valor original for um array, então atribui o array temporário, senão, atribui o primeiro elemento somente.
		if($CurrentValue -is [object[]]){
			$Table[$CurrentItem] = $ExpandedValue;
		} else {
			$Table[$CurrentItem] = $ExpandedValue[0];
		}
	}
}
	

#Importa os módulos do powershell que estão no diretorio de módulos
Function ImportPowershellModules($ModuleList = $null){
	$ModuleDir = GetModulesDir

	#Obtém a lista de diretórios 
	gci $ModuleDir | ? {$_.PsIsContainer} | ?{ $ModuleList -Contains $_.Name -or !$ModuleList } | %{
		import-module $_.FullName -DisableNameChecking -force;
	}
}


#Cria um nome de arquivo para log!
#Log virá com um timestamp!
Function GetLogFileName($Prefix, $Dir = $null){
	$ts = (Get-Date).toString("yyyyMMdd_HHmmSS")
	$LogFileName = "$ts.log";
	
	if($Prefix){
		$LogFileName = $Prefix +'.'+ $LogFileName; 
	}
	
	if($dir){
		$LogFileName = $Dir +'\'+ $LogFileName 
	}

	return $LogFileName;
}


#Obtem o caminho para um diretorio de backup!
#Cria o diretório se não existe!
Function GetUpgradeBackupDir {
	param($BaseDir = $null)
	
	if(!$BaseDir){
		$BaseDir = GetBaseDir
	}
	
	$ts = (Get-Date).toString("yyyyMMdd_HHmmss");
	$BackupDir = $BaseDir + "\upgrade\$ts"
	
	if(![System.IO.Directory]::Exists){
		$CreatedDir = mkdir $BackupDir -force;
	}

	return $BackupDir;
}