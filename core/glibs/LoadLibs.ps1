#Carrega todos os arquivos do diretorio atual 
param(
	#Load libs espera o diretorio base para que seja configurado a vari�vel!!!
	$BASE_DIR
	,[switch]$DebugMode
)

$ErrorActionPreference	= "Stop";
$CurrentFileName		= [System.Io.Path]::GetFileName($MyInvocation.MyCommand.Definition)


push-location
try {
	Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Definition)
	gci *.ps1 -Exclude $CurrentFileName | %{
		if($DebugMode){
			write-host "Carregando $($_.Name)..."
		}
		
		. $_.FullName;
	}
} finally{
	pop-location
}



