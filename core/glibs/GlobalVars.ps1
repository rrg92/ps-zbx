#Global variables handling!

#Verifica se as vari�veis obrigat�rias foram definidas!
Function CheckGlobalVars($VarName = $null) {
	$EXPECTED_VARS = 'PSZBX_BASE_DIR','PSZBX_LIBS_DIR','PSZBX_AGENT_BASENAME'
	
	$Errors = @()
	$EXPECTED_VARS | ? { $_ -eq $VarName -or $VarName -eq $null } | %{
		$VarValue = Get-Variable -Scope Global -Name $_ -ValueOnly -ErrorAction SilentlyContinue;
		if(!$VarValue){
			$Errors += $_
		}
	}
	
	if($Errors){
		return $false
	} else {
		return $true
	}
}


#Obt�m o valor de uma vari�vel do PSZBX!
Function GetPsZbxVar($Name){
	$Name = 'PSZBX_'+$Name;
	
	if(CheckGlobalVars $Name){
		return Get-Variable -Scope Global -Name $Name  -ValueOnly
	} else {
		throw "GLOBAL_VAR_NOT_DEFINED: $Name"
	}
}


#Seta ou cria o valor de uma vari�vel do PSZBX.
Function SetPsZbxVar($Name,$value){
	$Name = 'PSZBX_'+$Name;

	Set-Variable -Name $Name -Scope Global -Value $Value;
}

#Se foi definida uma vari�vel com o nome BASE_DIR, adiciona ela!
if($BASE_DIR){
	SetPsZbxVar 'BASE_DIR' $BASE_DIR
} else {
	throw 'BASE_DIR_NOT_DEFINED'
}




