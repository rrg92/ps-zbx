import-module CustomThreadPool -force

#First, we import all required assemblies.

$LoadSMO = {
	$assemblylist = @(
		"Microsoft.SqlServer.Management.Common"
		"Microsoft.SqlServer.Smo"
		"Microsoft.SqlServer.Dmf"
		"Microsoft.SqlServer.DmfSqlClrWrapper"
		"Microsoft.SqlServer.Dmf.Adapters"
		"Microsoft.SqlServer.Instapi"
		"Microsoft.SqlServer.SqlWmiManagement"
		"Microsoft.SqlServer.ConnectionInfo"
		"Microsoft.SqlServer.SmoExtended"
		"Microsoft.SqlServer.SqlTDiagM"
		"Microsoft.SqlServer.SString"
		"Microsoft.SqlServer.Management.RegisteredServers"
		"Microsoft.SqlServer.Management.Sdk.Sfc"
		"Microsoft.SqlServer.SqlEnum"
		"Microsoft.SqlServer.RegSvrEnum"
		"Microsoft.SqlServer.WmiEnum"
		"Microsoft.SqlServer.ServiceBrokerEnum"
		"Microsoft.SqlServer.ConnectionInfoExtended"
		"Microsoft.SqlServer.Management.Collector"
		"Microsoft.SqlServer.Management.CollectorEnum"
		"Microsoft.SqlServer.Management.Dac"
		"Microsoft.SqlServer.Management.DacEnum"
		"Microsoft.SqlServer.Management.Utility"
	)
	
	$PossibleVersions = 120,110,100
	$BaseFolder = "C:\Program Files\Microsoft SQL Server\{0}\SDK\Assemblies\"
	
	#Determine alternate folder version!
	$LastQtd = 0
	$ElegibleFolder = ""
	$PossibleVersions | %{
		$CurrentFolder = $BaseFolder -f  $_
		$qtdAvailable = @(gci -EA "SilentlyContinue" @($assemblylist|%{"$CurrentFolder\*$_*"})).count
		if($qtdAvailable -gt $LastQtd){
			$ElegibleFolder = $CurrentFolder
		}
	}
	
	$assemblies = gci ($ElegibleFolder+"\*.dll")
	foreach ($asm in $assemblies)
	{
			$fullPath = $asm.FullName
			try{
				[Reflection.Assembly]::LoadFrom($fullPath)  | out-Null
			} catch {
				if($assemblylist -contains $asm){
					throw
				}
			}
	}

}

#loading the SMO..
. $LoadSMO


#This is our servers where validate some policies from store...
$servers = @("SQLH111","SQLH108","SQLH109","SQLH110")

## For evaluation a policy in specific server, we need generate SqlStoreConnection...
$targetServers = @(
	$servers | %{
		$targetConex = New-Object System.Data.SqlClient.SqlConnection
		$targetConex.ConnectionString = "Server=$_;Database=master;Integrated Security=True;App=PS-CPE"
		return New-Object Microsoft.SqlServer.Management.Sdk.Sfc.SqlStoreConnection($targetConex)
	}
)

#For each target server, we call the Evaluation each policy...

$tres = Invoke-ThreadedScript $targetServers {
	param($t)
	
	$serverName = $_.ServerInstance
	$sqlStoreConn = $_
	$t.Name = $serverName
	
	#This will create a connection with the server.
	#We need provie just the instance full name.
	$SQLInstanceName = ".\RRG"

	$t.log("Creating a connection for the policy store...")
	#Just create e SqlConnection object for pass to policyStore object.
	$NewConex = New-Object System.Data.SqlClient.SqlConnection
	$NewConex.ConnectionString = "Server=$SQLInstanceName;Database=master;Integrated Security=True;App=PS-CPE"
	
	$t.log("Creating sqlStoreConnection ...")
	#The PolicyStore accept a SqlStoreConnection object only... And this, aceept a SqlConnection :D
	$SqlStoreConnection = New-Object Microsoft.SqlServer.Management.Sdk.Sfc.SqlStoreConnection($NewConex)

	$t.log("Connecting to policy store...")
	#Finnaly, lets create the connection with the policystore \o/
	$policyStore = New-Object Microsoft.SqlServer.Management.Dmf.PolicyStore($SqlStoreConnection)

	$t.log("Getting the elegible policies...")
	$elegiblePolicies = $policyStore.Policies | WHERE {$_.PolicyCategory -like "SICOOB*" }
	
	$t.log("Elegible policicies for server $($serverName): "+$elegiblePolicies.count)
	
	$elegiblePolicies  | % {
		$policyName = $_.Name
		$EventIdentifier = "$serverName-$policyName-"+([Guid]::NewGuid()).Guid
		
		$t.log("	Preapring for evaluate the policy $policyName by thread of server $serverName. The event identifier is: $EventIdentifier")
		
		$t.log("	Subscribing to the internal event for get evaluation results...")
		#Register the event for get the policy results.
		Register-ObjectEvent -InputObject $_ -EventName PolicyEvaluationFinished -SourceIdentifier $EventIdentifier
		
		$t.log("	[$serverName]Invoking the evaluation...")
		#Invoke the evaluation
		try {
			$evresult = $_.evaluate("Check",$sqlStoreConn)
		} catch {
			$t.log("Failure on evaluation of the policy: "+$policyName)
			throw $t.pool.genException($_,"EVALUATE_ERROR")
		}
		
		$t.log("	Wait for the internal event for getting the results...")
		#Waiting for evaluation complete...
		$Results = Wait-Event -SourceIdentifier $EventIdentifier
		
		$t.log("	Cleanup the internal events registrations...")
		#Removing the events...
		$Results | Remove-Event 
		Unregister-Event -SourceIdentifier  $EventIdentifier
		
		$t.log("	Getting the results histories...")
		#Getting the results histories...
		$GlobalResult = $Results.SourceEventArgs.Result
		$details = @($Results.SourceEventArgs.EvaluationHistory.ConnectionEvaluationHistories[1].EvaluationDetails.GetEnumerator())
		
		#Display the results...
		$t.log("	Evaluation of the policy $policyName at the server $serverName finished. Displaying the results")
		
		$t.log("	General results of this evaliation: $GlobalResult")
	}

} -PassThreadObject -LogTo @({param($m) write-host $msg})
















