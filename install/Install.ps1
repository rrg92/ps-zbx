param($CopyPaths = $null)


#Diret�rios que n�o devem ser copiados (cont�m dados do usu�rio)
$ErrorActionPreference="Stop";


$CurrentFile = $MyInvocation.MyCommand.Definition
$CurrentDir  = [System.Io.Path]::GetDirectoryName($CurrentFile)
$BaseDir	 = [System.Io.Path]::GetDirectoryName($CurrentDir);

#Libs do componente de install. Note que estas libs s�o diferentes.
	$LibsDir = $BaseDir + "\core\glibs"

#Se n�o consegue encontrar o diretorio de libs...
	if(![System.IO.Directory]::Exists($LibsDir)){
		throw "LIB_DIR_NOT_FOUND: $LibsDir"
	}

#Carrega as libs 
	$OriginalDebugMode = $DebugMode;
	try {
		$LoadLib = $LibsDir + '\LoadLibs.ps1';
		. $LoadLib $BaseDir 
	} catch {
		throw "LIBS_LOAD_FAILED: $_"
	}
	$DebugMode = $OriginalDebugMode;
	
	
$CopyPaths | %{
	#Verifica se no diretorio de destino existe uma estrutura com o diretorio core!
	$CorePath = $_ + '\core'
	
	if([System.IO.Directory]::Exists($CorePath)){
		write-host "Realizando upgrade..."
		Upgrade -DestBaseDir $_ -SourceBaseDir $BaseDir
	} else {
		write-host "Instalando novo..."
		InstallSolution -DestinationBase $_ -SourceBaseDir $BaseDir
	}

}

