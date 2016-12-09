#Arquivo contendo fun��es diversas para auxiliar os scripts.

#Local centralizado de vari�veis deste script.


#Retorna o valor do diretorio base.
Function GetBaseDir(){
	return GetPsZbxVar 'BASE_DIR'
}

#Retorna o caminho para o diret�rio de configura��o, baseado no diretorio base.
Function GetConfigDir(){
	return (GetBaseDir) + "\config";
}

#Retorna o caminho para o diret�rio de log, baseado no diretorio base.
Function GetLogDir(){
	$Config = GetPsZbxVar 'AGENT_CONFIG';
	return $Config.LOGBASE_DIR;
}

#Retorna o caminho para o diret�rio de log default, que � entregue junto com a solu��o!
Function GetDefaultLogDir(){
	$BaseDir = GetBaseDir;
	return $BaseDir + '\log'
}

#Retorna o caminho para o diretorio de m�dulos
Function GetModulesDir {
	return (GetBaseDir) + '\core\depends\powershell\modules'
}

#Retorna o caminho para o diretorio de install
Function GetInstallDir {
	return (GetBaseDir) + '\install'
}



#Retorna o nome base do agente. Que � o nome do arquivo, sem a extens�o .ps1
Function GetAgentBaseName(){
	if(CheckGlobalVars PSZBX_AGENT_BASENAME){
		return Get-Variable -Scope Global -Name 'PSZBX_AGENT_BASENAME' -ValueOnly
	} else {
		throw "GLOBAL_VAR_NOT_DEFINED: PSZBX_AGENT_BASENAME"
	}
}

#Ajusta as configura��es baseadas no valor padr�o e no valor determinado pelo usu�rio!
Function DefineConfiguratons($USERCONFIG) {
	$NewConfig = GetDefaultConfig;
	
	#Iterando sobre a lista de keys para alterar aquelas que foram defindias pelo usu�rio!
	$NewConfig = MergeHashTables -Dest $NewConfig -Src $USERCONFIG
	
	#Adiciona as configura��es readonly
	$NewConfig += (GetReadOnlyConfig)

	return $NewConfig;
}


#Esta fun��o verifica se um dado item da configura��o deve ser expandido (� um path)
#O $ItemName indica o nome do item. � um path completo. Se estiver dentro de uma hashtable deve incluir o nome da mesma.
#Se for  a hashtable pai, ent�o um '\' basta.
Function IsPathItem($ItemName, $ItemValue) {
	#Lista de padr�es de nome que podem ser paths.
	$Wilds = "*_DIR","*_PATH","KEYS_GROUP\*","_KEYS_GROUP\*"
	
	if($ItemValue -is [hashtable]){
		$ItemName += "\"
	}
	
	if( $Wilds | ? {$ItemName -like '\'+$_} ){
		return $true;
	}
	
	return $false;
}

#Fun��o para realizar a expans�o de diretorio.
#A expans�o de diret�rio � um processo para transformar os caminhos relativos em abosolutos.
#Ex.: Os items com configura��o \x\y v�o virar C:\x\y (por exemplo).
#A fun��o j� trata toda a expans�o. Se houver items cujo o valor � outra hashtable, a fun��o ir� tratar adequadamente.
#A fun��o tamb�m trata adequadamente as expans�es de item cujo o valor � um array de string... expandindo cada valor se necess�rio...

Function ExpandDirs($Table, $HashPath = $null){
	
	#O hash path � um apenas um meio de indicar a fun��o quem s�o os pais do item.
	#POr exemplo, considere:
	#	@{ A = 1; B = @{ B1 = 'b1'; B2 = 'b2' } }
	#
	# Neste caso, ao expandir B1, que � filho de B, a fun��o ir� passar um hash path '\B', indicando que B � a hashpai.
	#Desse modo, fica muito simples especificar na fun��o IsPathItem, os filtros dos items que devem ser expandidos.
	#Por exemplo, se todos os items de b2 s�o items que podem ser expandidos, ent�o o filtro ficaria B1*
	
	#para cada key da hash...
	$BaseDir = GetBaseDir;
	
	@($Table.Keys) |  %{
		$CurrentItem 	= $_;
		$CurrentValue 	= $Table[$CurrentItem];

		if(!(IsPathItem "$HashPath\$_" $CurrentValue)){
			return; #Proximo!
		}
		
		
		#se o valor atual � um hashtable, monta o path e chama a recursividade...
		if($CurrentValue -is [hashtable]){
			
			ExpandDirs -Table $CurrentValue -HashPath "$HashPath\$CurrentItem"
			return; #Vai pra pr�xima key...
		}
		
		
		
		$ExpandedValue	= @($CurrentValue); #Array tempor�rio. Para os casos onde o valor � um array de string!
		$i 				= $ExpandedValue.count
		
		
		if($CurrentValue){
			#Para cada item do array tempor�rio, expande-o e guarda novamente na mesma posi��o.
			while($i--){
				
				if($ExpandedValue[$i] -match '^\\[^\\].*'){
					$ExpandedValue[$i] = $BaseDir  + $ExpandedValue[$i]
				}
			}
		}
		
		
		#Se o valor original for um array, ent�o atribui o array tempor�rio, sen�o, atribui o primeiro elemento somente.
		if($CurrentValue -is [object[]]){
			$Table[$CurrentItem] = $ExpandedValue;
		} else {
			$Table[$CurrentItem] = $ExpandedValue[0];
		}
	}
}
	

#Importa os m�dulos do powershell que est�o no diretorio de m�dulos
Function ImportPowershellModules($ModuleList = $null){
	$ModuleDir = GetModulesDir

	#Obt�m a lista de diret�rios 
	gci $ModuleDir | ? {$_.PsIsContainer} | ?{ $ModuleList -Contains $_.Name -or !$ModuleList } | %{
		import-module $_.FullName -DisableNameChecking -force;
	}
}


#Cria um nome de arquivo para log!
#Log vir� com um timestamp!
Function GetLogFileName($Prefix = $null, $Dir = $null, [switch]$AsDir = $false){
	$ts = (Get-Date).toString("yyyyMMdd_HHmmss")
	
	if($AsDir){
		$LogFileName = "$ts";
	} else {
		$LogFileName = "$ts.log";
	}
	
	
	if($Prefix){
		$LogFileName = $Prefix +'.'+ $LogFileName; 
	}
	
	if($dir){
		$LogFileName = $Dir +'\'+ $LogFileName 
	}
	
	if($AsDir) {
		try {
			mkdir $LogFileName -force | Out-Null;
		} catch {
			throw 'CANNOT_CREATE_LOG: $_'
		}
	}

	return $LogFileName;
}



#Obtem o caminho para um diretorio de backup!
#Cria o diret�rio se n�o existe!
Function GetUpgradeBackupDir {
	param($BaseDir = $null)
	
	if(!$BaseDir){
		$BaseDir = GetBaseDir
	}
	
	$ts = (Get-Date).toString("yyyyMMdd_HHmmss");
	$BackupDir = $BaseDir + "\upgrade\$ts"
	
	if(![System.IO.Directory]::Exists($BackupDir)){
		$CreatedDir = mkdir $BackupDir -force;
	}

	return $BackupDir;
}