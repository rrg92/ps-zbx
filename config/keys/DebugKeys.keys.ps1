#Keys para debug somente

@{
	<#
	"mssql.mondebug[?result]" 	= { @(1..10 | %{New-Object PSObject -Prop @{result=$_;value=$_}}) }
	"LLD:mssql.psresult"	= {
							param($Data)
							
							return "Return just this now!"
						}
	#>
	
	"mssql.instance[ping]" = {1}
	
}