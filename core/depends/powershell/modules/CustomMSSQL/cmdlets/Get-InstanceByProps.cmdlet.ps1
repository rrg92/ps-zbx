Function Get-InstancesByProps {
	[CmdletBinding()]
	param(
		[string]$CMSInstance = $null
		,$Expression = $null
		,[switch]$ListProperties = $false
	)

	#Syntax: 
	$ErrorActionPreference = "Stop";
	
	if(!$CMSInstance){
		#Get from repository
		$CMSPropsRepo = (Get-CMSPropsRepository)
		$CMSInstance = $CMSPropsRepo.ServerInstance+":"+$CMSPropsRepo.Database
	}
	
	#Determining instance and database.
	$ConnectionParts = @($CMSInstance -split ":")
	$InstanceName = $ConnectionParts[0]
	
	if($ConnectionParts[1]){
		$DBName = $ConnectionParts[1]
	} else {
		$DBName = ""
	}
	
	if($ListProperties){
		try {
			$TSQL = "SELECT * FROM cmsprops.CMSProperties"
			$props = Invoke-NewQuery -ServerInstance $InstanceName -Database $DBName -Query $TSQL
			return $props;
		} catch {
			throw "DATABASE_ERROR: $_"
		}
	}
	
	if($Expression -is [hashtable]){
		$TmpExpression = @()
		
		$Expression.GetEnumerator() | %{
			$TmpExpression += "$($_.Key) = ''$($_.Value)''"
		}
		
		$CMSPropExpression = $TmpExpression -join " AND "
	}
	
	elseif($Expression -is [string]) {
		$CMSPropExpression = $Expression;
	}
	
	if($CMSPropExpression){
		$FilterExpressionParam = "@FilterExpression = '$CMSPropExpression'"
	} else {
		$FilterExpressionParam = ""
	}

	$TSQL = "EXEC cmsprops.prcGetInstance $FilterExpressionParam"
	
	write-verbose "TSQL: $TSQL"
	
	try {
		$returnedServers = Invoke-NewQuery -ServerInstance $InstanceName -Database $DBName -Query $TSQL
		return $returnedServers;
	} catch {
		throw "DATABASE_ERROR: $_"
	}
}
