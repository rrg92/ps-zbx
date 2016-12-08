#Contém funções relacionadas a regras e interações com o SQL Server!


#Trata o nome da instância adequadamente para se adequar a certos valores que possam ser informados
#Por funções que capturam o nome da mesma 
Function PrepareServerInstanceString($ServerInstance){
	
	#Se a instância é nomeada e contém "MSSQLSERVER" como nome, então considera como instância default.
	if($Instance -like "*\MSSQLSERVER"){ 
		$InstanceName	= @($Instance -split "\\")[0]
	} else {
		#Se a instância contém "\" no nome, então troca a barra por "$"
		$InstanceName	= $Instance.replace("$","\"); 
	}
	
	return $InstanceName;
}


#Substitui variáveis do powershell em um script sql
Function ReplaceSQLPsZbxVar {
	param($SQLScript, [hashtable]$Vars)

	if($SQLScript -isnot [string[]]){
		$SQLScript = $SQLScript -split '`r`n';
	}
	
	$NewScript = @();
	
	$_DebugMatacheds = @()
	$VarRegex = [regex]'(?i)\$PSZBX_([a-z0-9]+)';
	$MatchEval = {
		param($M)
		$VarName = $M.Groups[1].Value;
		
		if($Vars.Contains($VarName)){
			$VarValue = $Vars[$VarName];
			
			if($VarValue.count -ge 1){
				return ($VarValue -join ",")
			} else {
				return [string]$VarValue;
			}
		
			
		} else {
			return $M.Value;
		}
	}
	
	$SQLScript | %{
		$NewScript += $VarRegex.Replace($_, $MatchEval);
	}
	
	
	
	return $NewScript;
	
}


Function FormatSQLErrors {
	param([System.Exception]$Exception, $SQLErrorPrefix = "MSSQL_ERROR:")
	
	if(!$Exception){
		throw "INVALID_EXCEPTION_FOR_FORMATTING"
	}
	
	$ALLErrors = @();
	$bex = $Exception.GetBaseException();
	
	if($bex.Errors)
	{
		$Exception.GetBaseException().Errors | %{
			$ALLErrors += "$SQLErrorPrefix [Linha: $($_.LineNumber)]"+$_.Message
		}
	} else {
		$ALLErrors = $bex.Message;
	}
	
	
	return ($ALLErrors -join "`r`n`r`n")
	
	<#
		Returns a object containing formated sql errors messages
	#>
}