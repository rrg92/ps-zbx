Function ConvertTo-ZabbixLLD {
	[CmdLetBinding()]
	param(
		#The input objects to be converted. All Note Properties will be converted.
		$Objects
	)
	
	
	$AllProps = @($Objects | gm -Type Noteproperty | select name | sort -Unique | %{$_.name});
	
	$jsonObjects = @();
	
	foreach($Object in $Objects) {
		
		$jsonProps = @()
		$Object | gm -Type Noteproperty | %{
			$PropName 	= $_.Name;
			$PropValue	= $Object.$PropName;
			#Escaping special characters.
			$PropValue	= $PropValue.replace("\","\\").replace('"','\"');
			$jsonProps += """{#$($PropName.toUpper())}"""+":"+"""$PropValue"""
		}
	
		$jsonObjects += "{"+($jsonProps -join ",")+"}" 

	}
	
	$finalJSON = "{""data"":["+($jsonObjects -join ",")+"]}"
	
	return $finalJSON;
	
	<#
		.SYNOPSIS
			Converts a input objects into a format accepted by JSON Low Level Discovery rules.
			
		.DESCRIPTION
		
			The ConvertTo-ZabbixLLD takes a input of array object and converts to a Zabbix LLD JSON string.
			The property name is converted to UPPER CASE.
			The cmdlet dont checks for different properties of objects. So, Object[0] can be 3 properties and Object[1] can be 2 and the cmdlet will generate according.
			For more information, check: https://www.zabbix.com/documentation/2.4/manual/discovery/low_level_discovery
			
		.NOTES
		
			This scripts was developed by Rodrigo Ribeiro Gomes.
			This scripts is free and always will be.
			http://scriptstore.thesqltimes.com/docs/custommssql/custommssql-cmdlets/converto-zabbixlld/
	
	#>
}