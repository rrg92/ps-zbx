param($CopyPaths, [switch]$CopyConfig)


#Diretórios que não devem ser copidos (contém dados do usuário)
$ErrorActionPreference="Stop";


$CurrentFile = $MyInvocation.MyCommand.Definition
$CurrentDir  = [System.Io.Path]::GetDirectoryName($CurrentFile)
$BaseDir	 = [System.Io.Path]::GetDirectoryName($CurrentDir);


#Determina os diretorios para copia
$Dirs = gci $BaseDir | ? {$_.PsIscontainer} | ? { $_.Name -ne 'config' -or $CopyConfig }



$CopyPaths | %{
	write-host "Atuando em $_";
	$CurrentPath = $_;

	#Se o diretorio de install não existe, cria-o.
	if(![System.IO.Directory]::Exists($CurrentPath)){
		mkdir $CurrentPath | out-Null
	}
	
	$Dirs  | %{
		copy $_.FullName $CurrentPath -verbose -recurse -force
	}
}
