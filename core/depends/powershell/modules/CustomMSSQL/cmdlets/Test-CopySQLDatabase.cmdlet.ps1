Function Test-CopySQLDatabase {
	param([switch]$SQLAgentErrorMode = $false,$ScriptID=$null, $CustomMSSQL = "CustomMSSQL", $ExitWithCode = $false, $Logdir=$null,$LogLevel="DETAILED")

	#Aqui vamos configurar configurar  o powershell para forçar um exceção em qualquer erro, mesmo estes que normalmente não causariam uma exceção.
	$ErrorActionPreference = "Stop";

	#Vamos pegar o nome deste arquivo. Isso vai nos ajudar a montar de forma dinâmica o nome do log. Assim base colocar adequadamente no nome do arquivo.
	$ThisName = "Test-CopySQLDatabase.cmdlet.ps1"
	if(Test-Path $MyInvocation.MyCommand.Definition){
		$ThisName = $MyInvocation.MyCommand.Definition
	}
	
	$ScriptBaseName	= $ThisName;

	#Essa é a variável que vai guardar o nome do arquivo de log. Por padrão todos, o diretório do arquivo de log será na <logstore>\COPIAR_BASE
	$LogFileBaseName=$ScriptBaseName

	#Se você informar o parâmetro ScriptID, então vamos usar ele para também compor o arquivo de log. Note que não fazemos tratamentos para eliminar caracteres inválidos.
	#Portanto, escolha um nome adequado que seja aceito em nomes de arquivo.
	if($ScriptID){
		$LogFileBaseName += "-$ScriptID"
	}
	
	if(!$Logdir){
		$Logdir = [System.IO.Path]::GetTempFileName()+"\"
	}

	$LogFileName = "$Logdir\$LogFileBaseName.log"


	#Script usado apenas para testar a execução remota.

	try {
		# Verifque o KB sobre CustomMSSQL para mais detalhes.
		import-module $CustomMSSQL -force


		$Params = @{
			SourceServerInstance= "localhost\SQL16" 
			SourceDatabase = "SourceCopy" 
			DestinationServerInstance = "localhost\SQL16" 
			DestinationDatabase = "DestCopy"
			Replace=$true
			ForceSimple=$true
			RestoreFolder="MSSQL\DEFAULT"
			BackupFolder="T:\MSSQL"
			LogLevel=$LogLevel
			UseLimitedUser=$true
			SQLAgentErrorMode=$SQLAgentErrorMode
			LogTo = ($LogFileName,"#")
			VolumesAllowed="T:\"
		}

		Copy-SQLDatabase @Params 
		$ScriptExitCode = 0;
		$ExitWithCode = $false; #TODO: Transform in a parameter...
	} catch {
		if($SQLAgentErrorMode){
			$ScriptExitCode = 1;
			$ExitWithCode = $true;
			write-output "ERROR: $_"
		}

		throw;
	} finally {
		if($ScriptExitCode -and $ExitWithCode){
			exit $ScriptExitCode;
		}
	}

}