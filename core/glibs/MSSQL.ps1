#Cont�m fun��es relacionadas a regras e intera��es com o SQL Server!


#Trata o nome da inst�ncia adequadamente para se adequar a certos valores que possam ser informados
#Por fun��es que capturam o nome da mesma 
Function PrepareServerInstanceString($ServerInstance){
	
	#Se a inst�ncia � nomeada e cont�m "MSSQLSERVER" como nome, ent�o considera como inst�ncia default.
	if($Instance -like "*\MSSQLSERVER"){ 
		$InstanceName	= @($Instance -split "\\")[0]
	} else {
		#Se a inst�ncia cont�m "\" no nome, ent�o troca a barra por "$"
		$InstanceName	= $Instance.replace("$","\"); 
	}
	
	return $InstanceName;
}


#Substitui vari�veis no fomrato de template parameters em scripts sql.
#O par�metro $Force faz com que um erro retornado caso n�o seja encontrado uma vari�vel para um template parameter sem um defaut.
Function ReplaceSQLTemplateParameters {
	param($SQLScript, [hashtable]$Vars, [switch]$Force = $false)

	if($SQLScript -isnot [string[]]){
		$SQLScript = $SQLScript -split '`r`n';
	}
	
	$NewScript = @();
	
	$_DebugMatacheds = @()
	$VarRegex = [regex]'(?i)<([a-z-9]+),,([^>]*)>';
	

	$MatchEval = {
		param($M)
		$VarName 		= $M.Groups[1].Value;
		$DefaultValue 	= $M.Groups[2].Value;
		
		if(!$Vars){
			$Vars = @{};
		}
		
		
		if($Vars.Contains($VarName)){
			$VarValue = $Vars[$VarName];
			
			if($VarValue -ne $null){
				if($VarValue.count -ge 1){
					return ($VarValue -join ",")
				} else {
					return [string]$VarValue;
				}
			}

			#If execution arrives here, means the variable is null...
		}
		
		if($DefaultValue){
			return $DefaultValue
		} else {
			if($Force){
				throw "NOT_FOUND_VALUE_FOR: $VarName"
			}
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