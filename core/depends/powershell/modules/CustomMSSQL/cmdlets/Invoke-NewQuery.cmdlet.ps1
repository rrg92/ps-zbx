Function New-MSSQLSession
{
	[CmdLetBinding()]
	param($serverInstance = $null,$database = "master",$logon=@{AuthType="Windows";User="";Password=""},$appName="CUSTOM_MSSQL_POWERSHELL", $exString = "", [switch]$Pooling = $false)
	
	$Session = New-Object -Type PsObject @{ServerInstance = $serverInstance
											database = $database
											logon = $logon
											appName = $appName
											exString = $exString
											pooling=$Pooling
										}
	
	
	#This method allow you load all assemblies need for SMO.
	#This method make all checking need for loading the SMO dependencies.
	#Just call it.
	$LoadSMO = [scriptblock]::create({
	
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
		
		#This contains possible versions of SQL Server folders with SMO libraries.
		$PossibleVersions = 120,110,100
		$BaseFolder = "C:\Program Files\Microsoft SQL Server\{0}\SDK\Assemblies\"
		
		#The script will try select the folder with the major quantity of dll files.
		$LastQtd = 0
		$ElegibleFolder = ""
		$PossibleVersions | %{
			$CurrentFolder = $BaseFolder -f  $_
			$qtdAvailable = @(gci -EA "SilentlyContinue" @($assemblylist|%{"$CurrentFolder\*$_*.dll"})).count
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
	
	})
	

	#This method open a connection with the server...
	$newSession = [scriptblock]::create({
						param($serverInstance = $null,$database = "master",$logon=@{AuthType="Windows";User="";Password=""}, $exString="")
						
						write-verbose "Attemping create the new session."
						
						#Check if already some session for this object...
						$currentSession = $this._session
						
						if($currentSession)
						{
							write-verbose "The current session objects already a value."
							throw "SESSION_ALREADY_CREATED"
						}

						if($serverInstance) {
							$this.serverInstance = $ServerInstance
						}
						write-verbose "The server instance will be: $($this.serverInstance)"
						
						if($database){
							$this.database = $database
						}
						write-verbose "The database will be: $($this.database)"
						
						if($logon){
							$this.logon = $logon
						}
						write-verbose "The logon auth type will be: $($this.logon.AuthType)"
						
						
						$authentication = "Integrated Security=True"
						$appName = $this.appName
						
						if($this.logon.AuthType -eq "SQL") {
							write-verbose "The logon user will be: $($this.logon.User)"
							write-verbose "The logon pass will be: $($this.logon.Password)"
						
							$authentication = "User=$($this.logon.User);Password=$($this.logon.Password)"
						}
						
						if(!$appName){
							$appName = "CUSTOM_MSSQL_POWERSHELL"
						}
						
						write-verbose "The app name will be: $appName"
						
						$ConnectionString = @(
							"Server=$($this.ServerInstance)"
							"Database=$($this.database)"
							$authentication
							"APP=$appName"
						)
						
						if(!$this.Pooling){
							$ConnectionString += "Pooling=false"
						}
						
						$connectionString += ($exString -split ";");
						
						#RRG_EDIT: Changed connection string direct to Join form...
						# "Server=$ServerInstance;Database=$Database;Integrated Security=True;App=$App"
						$NewConex = New-Object System.Data.SqlClient.SqlConnection
						$NewConex.ConnectionString = $ConnectionString -Join ";" 
						
						
						
						write-verbose "The final connection string is: $($NewConex.ConnectionString ) "
						
						try {
							write-verbose "Attempting open tthe connection object"
							$NewConex.Open()
							
							write-verbose "Storing connection object on the session property"
							$this._session = $NewConex
						} catch {
							write-verbose "Some error while connect to server..."
							if($NewConex){
								$NewConex.Dispose()
							}
							throw ($_.Exception.GetBaseException())
						}
					})
					
	#This command ends a connections with server
	$endSession = [scriptblock]::create({
						param($Conex)
						
						if($this._session)
						{
							write-verbose "The  connection object will be disposed."
							$this._session.Dispose()
							
							write-verbose "The  session property will be null"
							$this._session = $null	
						} else {
							write-verbose "No connection on session object available to ending."
						}
	
					})
			
	
	#Get Current Session state, based on SQL Server States.
	#possibles are: SLEEPING;RUNNING
	$getState = [scriptblock]::create({
					$currentState = "SLEEPING"
					$con = $this._session
					
					write-verbose "Attempt get the state."
					
					if($con)
					{
						write-verbose "The current connection state is: $($con.State) "
						
						switch($con.State)
						{
							"Broken" {$currentState="DISCONECTTED"}
							"Closed" {$currentState="DISCONECTTED"}
							"Connecting" {$currentState="RUNNING"}
							"Executing" {$currentState="RUNNING"}
							"Fetching" {$currentState="RUNNING"}
							"Open" {$currentState="SLEEPING"}
						}
					} else {
						$currentState = "DISCONECTTED"
					}
					
					return @{state=$currentState}
				})
	
	#This method execute a batch on the session.
	$execute =  [scriptblock]::create({
					param($TSQL,$ServerInstance = $null,$Database = $null,$Logon = $null,$QueryTimeout = $null,$Close = $false, $ExString = "")
		
					try {
						
						if(!$this._Session)
						{
							write-verbose "No session opended for this objects."
							$Close = $true
							
							write-verbose "Creating session objects..."
							$this.newSession($ServerInstance,$Database,$Logon,$ExString)
						}
			
						$sessionState = $this.getState().state
						
						write-verbose "Current session state is: $sessionState"
						if($sessionState -ne "SLEEPING")
						{
							write-verbose "Session is not sleeping! A erro will trhowed"
							throw "SESSION_BUSY[$sessionState]"
						}
						
						write-verbose "Creating the command object..."
						$commandTSQL = $this._session.CreateCommand()
						
						write-verbose "Setting the SQL script to: $TSQL"
						$commandTSQL.CommandText = $TSQL
						
						write-verbose "Setting the query timeout for : $QueryTimeout"
						$commandTSQL.CommandTimeout = $QueryTimeout
						
						write-verbose "Creating reader parser..."
						#This is a workaround to use SqlData reader in powershell V2...
						#A behavior in powershell cause it call the enumerator of some parameters that are passed.
						#With SqlDataReader, if this happens, the result returned are lost...
						#Thus, using this object, we can "protect" the sqldata reader in some property of objct and pass object between calls...
						$ReaderParser = NewDataReaderParser
			
						
						try{
							$result = $null;
							write-verbose "Executing the command on the connection..."
							$ReaderParser.reader = $commandTSQL.ExecuteReader()
						} catch {
							write-verbose "Some error ocurred while execute the command"
							throw ($_.Exception.GetBaseException())
						}
				
						try {
							write-verbose "Attempting get the results"
							$resultset = $ReaderParser.GetNextResultSet();
							write-verbose ("Resultset count: "+(@($resultset).count))
						} catch {
							$bex = $_.Exception.GetBaseException()
							$Error = "EXECUTE_READING_ERROR:"+$bex.Message
							throw New-Object -Type System.Exception -ArgumentList "$Error",$bex
						}
						
					} catch {
						throw
					} finally {
						if($ReaderParser.reader)
						{
							write-verbose "Disposing SqlDataReader object..."
							$ReaderParser.reader.Dispose()
						}
						
						if($commandTSQL)
						{
							write-verbose "Disposing Command object..."
							$commandTSQL.Dispose()
						}
						
						if($Close)
						{
							write-verbose "Ending this session!"
							$this.endSession()
						}
						
						if($ReaderParser){
							$ReaderParser  = $null;
						}
					}
					
					return $resultset;
				})
	
	
	#This method provide a form of you call evalute policies stored in this server in anothers servers.
	$evaluatePolicy = [scriptblock]::create({
					param($policies,[string[]]$targetServer,$targetLogon = $null,$evaluationMode="CHECK",$serverInstance = $null,$logon = $null, $close = $false, $AppName = "POWERSHELL-MSSQL-POLICY_BASED_MANAGEMENT")
			
						if(!$this._Session)
						{
							write-verbose "No sessino opended for this object"
							$Close = $true
							
							write-verbose "Creating session objects..."
							$Database = "master"
							$this.newSession($ServerInstance,$Database,$Logon)
						}
			
						$sessionState = $this.getState().state
						
						write-verbose "Current session state is: $sessionState"
						if($sessionState -ne "SLEEPING")
						{
							write-verbose "Session is not sleeping! A erro will trhowed"
							throw "SESSION_BUSY[$sessionState]"
						}
						
						#Loading SMO library for internal PBM access
						$this.LoadSMO()
						
						#Creating the connection
						
						## For evaluation a policy in specific server, we need generate SqlStoreConnection...
						
						
						
						$targetServers = @(
							$targetServer | %{
								$targetConex = New-Object System.Data.SqlClient.SqlConnection
								$AuthenticationString = "Integrated Security=True;";
								
								if($targetLogon.AuthType -eq "SQL") {
									$AuthenticationString = "User=$($targetLogon.User);Password=$($targetLogon.Password);"
								}
								
								$targetConex.ConnectionString = "Server=$_;Database=master;App=$AppName;$AuthenticationString"
								$targetSqlStoreConnection =  New-Object Microsoft.SqlServer.Management.Sdk.Sfc.SqlStoreConnection($targetConex)
								
								return New-Object PSObject -Prop @{name = $_; sqlStoreConnection = $targetSqlStoreConnection}
							}
						)
						
						try {
						#We open connection with the current server, that's it, the current Policy Store.
						
							#Let's create a SqlStoreConnection object.
							$policySqlStoreConnection = New-Object Microsoft.SqlServer.Management.Sdk.Sfc.SqlStoreConnection($this._session)
							$policySqlStoreConnection = New-Object Microsoft.SqlServer.Management.Sdk.Sfc.SqlStoreConnection($this._session)
							
							#Finnaly, lets create the connection with the policystore \o/
							$policyStore = New-Object Microsoft.SqlServer.Management.Dmf.PolicyStore($policySqlStoreConnection)
							
						#All right... Lets get the policies, based on user filter...
						if($policies -is [scriptblock]){
							$filter = $policies
						}
						
						if($policies -is [object[]] -or $policies -is [string] ){
							$policyNames = $policies  -as [string[]]
							$filter = {  $policy = $_; @($policyNames | WHERE {$policy.Name -like $_}).count -gt 0 }
						}
						
						if($Policies -eq $null){
							$filter = {$true}
						}
						
						$filter = [scriptblock]::create($filter);
						
						$elegiblePolicies = @($policyStore.Policies | WHERE $filter)

						#For each server, by time, evaluate the policy by policy...
						$Evaluations = @(
							$targetServers | % {
								$currentServer = $_
							
								$elegiblePolicies  | %{
									$resultObject = $null
									#Creating a event identifier for listen event related with the policy that we call evaluation...
									#This is a unique string that we pass to Register-ObjectEvent cmdlet.
									#We will need do this for get policie evaluation results for this evaluation only.
									$currentPolicy = $_
									try {
										$EventSourceIdentifier = "$($currentServer.ServerInstance)-$($currentPolicy.Name)-"+([Guid]::NewGuid()).Guid
										
										#Registering the event for getting evaluation results....
										Register-ObjectEvent -InputObject $currentPolicy -EventName PolicyEvaluationFinished -SourceIdentifier $EventSourceIdentifier | Out-Null
										
										#Calling the evaluation...
										$evaluateTarget = $currentServer.sqlStoreConnection
										$evresult = $_.evaluate($evaluationMode,$evaluateTarget)
										
										#Waiting on the event... At this moment it must be fired... The Wait must be fast!
										$EventData = Wait-Event -SourceIdentifier $EventSourceIdentifier
										

										#Getting the object containing the evaluation information...
										$EvaluationResultsDetails = $EventData.SourceEventArgs
										$EvaluationResult = $EvaluationResultsDetails.Result
										$EvaluationDetails = $EvaluationResultsDetails.EvaluationHistory.ConnectionEvaluationHistories[1].EvaluationDetails
										
										$resultObject = New-Object PSObject -Prop @{evaluationPolicy = $_.Name
																		evaluationTarget = $currentServer.name
																		evaluationResult = $EvaluationResult
																		evaluationDetails = $EvaluationDetails
																	}
									} finally {
										#Attempting close the target connection
										#Freeing the resources...
										if($EventData) {
											$EventData | Remove-Event 
											if(Get-EventSubscriber -SourceIdentifier  $EventSourceIdentifier)
											{
												Unregister-Event -SourceIdentifier  $EventSourceIdentifier
											}
										}
									}
									
									if($resultObject) {
										return $resultObject
									}
								}
								
							}
						)

					} finally {
						if($policyStore){
							$policyStore = $null
						}
						
						if($policySqlStoreConnection){
							$policySqlStoreConnection = $null
						}
						
						if($close){
							$this.endSession()
						}
					}
					
					return $Evaluations;
				})
	
	
	$Session | Add-member -Type ScriptMethod -Name newSession -Value 	$newSession
	$Session | Add-member -Type ScriptMethod -Name endSession -Value 	$endSession
	$Session | Add-member -Type ScriptMethod -Name connect -Value 	$newSession
	$Session | Add-member -Type ScriptMethod -Name disconnect -Value 	$endSession
	$Session | Add-member -Type ScriptMethod -Name getState -Value 	$getState
	$Session | Add-member -Type ScriptMethod -Name execute -Value 	$execute
	$Session | Add-member -Type ScriptMethod -Name loadSMO -Value 	$loadSMO
	$Session | Add-member -Type ScriptMethod -Name evaluatePolicy -Value 	$evaluatePolicy
	$Session | Add-member -Type Noteproperty -Name _session -Value 	$null
	$Session | Add-member -Type Noteproperty -Name serverInstance -Value 	$null
	$Session | Add-member -Type Noteproperty -Name database -Value 	$null
	$Session | Add-member -Type Noteproperty -Name logon -Value 	$null

	if($serverInstance){
		write-verbose "Starting the creation of a session object!"
		write-verbose "ExString is: $exString"
		$Session.newSession($serverInstance,$database,$logon,$exString)
	}
	
	return $Session 
}

Function Invoke-NewQuery  {
	[CmdLetBinding()]
	param(	
			#This is the Server instance. Can be ip address, ip and port, name\instance, etc.
				[Alias("S")]
				[parameter(Mandatory=$false, ValueFromPipeline=$true)]
				$ServerInstance = $null
			
			,#This is the Database name that you want connect to.
				[Alias("D")]
				$Database = "master"
				
			,#This is the Query that you want execute.
				[Alias("Q")]
				$Query = $null
			
			,#This is the login name, if you want to use SQL Login instead of Windows Authentication.
			 #If you want use Windows Authentication, dont specify this parameter.
				[Alias("U","Username")]
				$Login=$null
				
			,#This is the password of login.
				[Alias("P")]
				$Password = $null
				
			,#This is the application name show in sys.dm_exec_sessions
				$appName = "CustomMSSQL"
			
			,#This options controls if you wont fix the SET OPTIONS that affects the results.
			 #Some options of the session can produce slow query plans if not configured correctly.
			 #Check this technet article to more details: https://technet.microsoft.com/en-us/library/ms175088(v=sql.105).aspx
			 #By default, the cmdlet will execute some "SET" commands before executing the user query, on same connection opened.
			 #If you specify this option, the cmdlet will not execute this set options.
				[Switch]$NoFixSetOptions = $false
				
			,#Specify some additional connection strings parameters that you can use.
				$exString = ""
				
			,#Specify input file with a query. If both Query and InputFile is specified, this takes precedence.
				[Alias("i")]
				$InputFile = $null
				
			,#This is another way of specifu credentials to connect to SQL Server.
			 #It is just a hashtable containing some keys defining the logon informations. 
			 #The keys are:
			 #	AuthType: The type of Authentication, The values are: Windows or SQL
			 #	Login: The SQL Login, if AuthType is "SQL"
			 #	Password: The Login Password.
			 #
			 # If you specify "Login" parameter, it will override this option.
				$Logon = @{AuthType="Windows"}
				
				
			,#Alterantive way to specify "ServerInstance". Is useful to use with results of Get-InstanceByProperty cmdlet.
				[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
				$connectionName = $null
				
			,#Specify the minimum version required by server for script run.
			 #The script will try connect to target instance and get version...
			 #If version returned is less thant this parameter, the script is not execubtale.
			 #The min version must be specified in format MAJOR.MINOR.BUILD or a numeric value represting it.
			 #If cmdlet cannot obtain instance version, the exception CANNOT_GET_VERSION is throwed!
			 #Check the notifications of special output or verbose logging for reason of incompatible version.
				$MinVersion = $null
				
			,#Specify the maximum version required by server for script run.
			 #This will follow the same rules that MinVersion parameter.
			 #Note that build versions is considered. For example, a server with version 10.50.6000 cannot will execute if this parameter is 10. 
			 #If you want execute on all server with maximum version 10.50 (sql 2008 r2) you must specify 10.50.9999. If you wan on sql 2008 only, you can specify 10.00.9999
				$MaxVersion = $null
				
			,#BETA! Executes sp_whoisactive @find_block_leaders = 1,@sort_order = '[blocked_session_count] DESC'
			 #The sp_whoisactive must exists and user must have permissions to run it.
				[switch]
				$FindBlockers = $false
			 
			,#By default, when this cmdlet executes for multiple server, it returns a special object array containing results and errors for each server.
			 #When it execute on a single server, it return the direct resultset or errors, if any.
			 #If this parameter is specified, the output of cmdlet is always the object array,  independently of number of server.
				[switch]
				$ForceSpecialOutput = $false
	)
	
begin {
	#Get all servers!
	$AllConnections = @()
	
	if($MinVersion){
		$NumericMinVersion = GetProductVersionNumeric $MinVersion;
	}
	
	if($MaxVersion){
		$NumericMaxVersion = GetProductVersionNumeric $MaxVersion;
	}
}

process {
	
	$ConexInfo = New-Object PSObject -Prop (GetAllCmdLetParams)
	$ConexInfo | Add-Member -Type Noteproperty -Name Results -Value $null 
	$ConexInfo | Add-Member -Type Noteproperty -Name Errors -Value @()
	$ConexInfo | Add-Member -Type Noteproperty -Name Notifications -Value @()
	$ConexInfo | Add-Member -Type Noteproperty -Name ConnectionInfo -Value $ConexInfo;
	$AllConnections += $ConexInfo;
}
	
end {
	
	$isMultiple = $false;
	
	if($AllConnections.count -gt 1){
		$isMultiple = $true;
	}
	
	:ConexoesLoop foreach($ConexInfo in $AllConnections){

		#If the ServerInstance contains a object with a property connectionName...
		if($ConexInfo.ServerInstance.connectionName){
			$ConexInfo.ServerInstance = $ConexInfo.ServerInstance.connectionName;
		}
		
		elseif($ConexInfo.connectionName -and !$ConexInfo.serverInstance){
			$ConexInfo.ServerInstance = $ConexInfo.connectionName;
		}
		
		if($ConexInfo.Login){
			$ConexInfo.logon = @{
					AuthType = "SQL"
					User=$Login
					Password=$Password
				}
		}
		
		if(!$ConexInfo.ServerInstance)
		{
			$ex = New-Object System.Exception("You must provide a server instance");
			if($isMultiple){
				$ConexInfo.Errors += $ex
				continue :ConexoesLoop;
			} else {
				throw $ex;
			}
		}

		$Query = $ConexInfo.Query;
		if($ConexInfo.InputFile){
			
			if(Test-Path $ConexInfo.InputFile)
			{
				$Query = (Get-Content $ConexInfo.InputFile) -Join "`r`n"
			} else {
				$ex = New-Object System.Exception( "Invalid File: $InputFile");
				
				if($IsMultiple){
					$ConexInfo.Errors += $ex
					continue :ConexoesLoop;
				} else {
					throw $ex;
				}
			}
		}
		
		if($FindBlockers){
			$Query = "EXEC sp_whoisactive @find_block_leaders = 1, @sort_order = '[blocked_session_count] DESC' ";
		}
		
		if(!$Query)
		{
			$ex = New-Object System.Exception( "Invalid Query");
			
			if($IsMultiple){
				$ConexInfo.Errors += $ex
				continue :ConexoesLoop;
			} else {
				throw $ex;
			}
		}
		

		
		$FIX_SET_OPTIONS = @(
						"SET ANSI_NULLS ON;"
						"SET ANSI_PADDING ON;"
						"SET ANSI_WARNINGS ON;"
						"SET ARITHABORT ON;"
						"SET CONCAT_NULL_YIELDS_NULL ON;"
						"SET NUMERIC_ROUNDABORT OFF;"
						"SET QUOTED_IDENTIFIER ON;"
						) -Join "`r`n"
		
		try {
			$NewQuery = $null;
			$NumericServerVersion = $null; #This will store the target server numeric version.
			
			$NewQuery = New-MSSQLSession -serverInstance $ConexInfo.ServerInstance -database $ConexInfo.database -Logon $ConexInfo.logon -appName $ConexInfo.appName -exString $ConexInfo.exString
		
			#Try get maximum version if specified.
			if($ConexInfo.MinVersion -ne $null -or $ConexInfo.MaxVersion -ne $null){
			
				
				$CompatibleVersion = $true;
				$IncompatibilityReason = @()
			
				try {
					$QueryResult = $NewQuery.execute("SELECT SERVERPROPERTY('ProductVersion') as ProductVersion");
					$NumericServerVersion =  GetProductVersionNumeric $QueryResult.ProductVersion;
				} catch {
					throw "CANNOT_GET_VERSION: $_"
				}
				
				#Check if version is compatible!
				if($NumericMinVersion -and $NumericServerVersion -lt $NumericMinVersion){
					$CompatibleVersion = $false;
					$IncompatibilityReason = "Current version < Min Version"
				}
				
				if($NumericMaxVersion -and $NumericServerVersion -gt $NumericMaxVersion){
					$CompatibleVersion = $false;
					$IncompatibilityReason = "Current version > Min Version"
				}
				
				if(!$CompatibleVersion){
					$ReasonText = $IncompatibilityReason -join "`r`n";
					$Message = "Ignoring query execution because version. Required min:$NumericMinVersion max:$NumericMaxVersion Current:$NumericServerVersion. Reasons: $ReasonText";
					write-verbose $Message 
					$ConexInfo.Results = $null;
					$ConexInfo.Notifications += $Message;
					continue :ConexoesLoop;
				}
				
			}
			
			
			
			if(!$ConexInfo.NoFixSetOptions){
				try {
					write-verbose ("Fixing the SET OPTIONS: "+$FIX_SET_OPTIONS)
					$NewQuery.execute($FIX_SET_OPTIONS) | Out-Null
				} catch {
					write-verbose ("SET_OPTIONS FIX ERROR: "+($_.Exception.Message))
				} 
			}
			

			
			$resultset = $NewQuery.execute($Query)
			$ConexInfo.Results = $resultset;
		} catch {
			$ex = $_;
			
			if($IsMultiple){
				$ConexInfo.Errors += $ex
				continue :ConexoesLoop;
			} else {
				throw $ex;
			}
		} finally {
			if($NewQuery){
				$NewQuery.endSession()
			}
		}
	
	}
	
	if($IsMultiple -or $ForceSpecialOutput){
		return $AllConnections
	} else {
		return $AllConnections[0].Results;
	}
}

	<#
		.SYNOPSIS 
			Connects to SQL Server instance and execute a query, using .NET System.Data.SqlClient library.
			
		.DESCRIPTION
			This cmdlet is a rewrite of Invoke-SqlCmd and Sqlcmd.
			It is build on top of "New-MSSQLSession" cmdlet provided by CustomMSSQL for executing queries without session control.
			This cmdlet is useful for run administrative scripts on a sql server.
			
			The cmdlet returns the first resultset only as a array of objects.
			Each row returned is a object. Each column of a row is a "Noteproperty" of the object.
			
			If errors happens while executing the query, the cmdlet throws a exception of type SQLException.
			You can use SQLException to get access to all errors thrown.
			
			The cmdlet provide some parameters that have same name in the Invoke-Sqlcmd (from sqlps module).
			This is for compatibility reasons. But it provides more alternatives and options. Check parameters documentation for more information.
			
			You can pipe output of Get-InstanceByProperty cmdlet in this modudle. This cmdlet is compatible.
			When this cmdlet execute in multiple servers, it returns the results in a special output. Check OUTPUT AND SPECIAL OUTPUT section. 
			
			You also can pipe server names as a string array.
			
			
			OUTPUTS AND SPECIAL OUTPUT
				In some situations, the cmdlet will return a simple output containing the resultset.
				This is default behavior when cmdlet execute on just a single isntance.
				If parameter ForceSpecialOutput or multiple servers are used, the cmdlet will return a special output.
				The special output is a object array containing execution results for each instance the cmdlet tried execute the query.
				The special output can present many properties and informations, but just descrbied here will be supported and compatibility is guaranted.
				
				The special output supported properties is:
				
					
					ConnectionInfo
						This is a object containing the properties that are the parameters and values passed to the cmdlet.
						
					Results
						Will contains the resultset.
						
					Errors
						Will contains the errors generate by execution on that server.
						
					Notifications
						Will contains the notifications generated by cmdlet.
						Check NOTIFICATIONS section for more information.
						
			NOTIFICATIONS
				This cmdlet can generate some useful messages to debug a error or not expected result.
				The notifications is available on special output via property notifications.
				For example, when cmdlet not execute script because MaxVersion or MinVersion parameters, the reason will be placed on notifications.
				
			KNOW BUGS
				- Poor fetch perfomance
					This cmdlet fetchs rows from data reader slow comparing with sqlps module or a direct write on c#.
					We suspect that this is due the fact the all core is write in powershell and powershell is more slow than native .net code. (Invoke-SqlCmd is write in c#)
					Between releases, we stay improve perfomance of this.
					But, this perfomance diference is notable when you read many rows from server. If you use scripts that just returns one row, for example, this cannot be a issue.
					
				- GO 
					This cmdlet dont parse GO. In future releases, this will comes implemented.
					If you need GO, try use sqlps module or another. Sorry.
					
		
		.EXAMPLE
			
			$allTables = Invoke-NewQuery -ServerInstance MyServer -Database "MyDatabase" -Query "SELECT name FROM sys.tables"
			
		.NOTES
		
			KNOW ISSUES
				Handle "GO" - This cmdlet don't handle "GO"
				
			WHAT'S NEW
	#>
}


#This functions create a new object that represent a data reader.
#Its main objective is allow powershell cmdlets access a simple way to convert DataReader to Array of objects!
#User must assign the DataReader object returned by ExecuteReader to member reader. This prevents powershell call read method on sqldatareader (when passed via param...)
Function NewDataReaderParser {
	$o = New-Object PsObject -Prop @{
		#This will contain the _reader object...
		reader = $null
		
		#This store the number of times that read of object was request. This is number of calls to NextResult...
		ReadCount = 0
		
		#This indicates if previous call to NextResult returned $true. When this value is $false, then no more result is available to return and client can stop to requesting rows...
		hadNext = $true #It must be initialize as $true, in order to make a at lear one attempt.
	}

	#this will be GetNextResultSet method of object...
	$GetNextResultSet = [scriptblock]::create({
		#Lets initialize some useful variables...
		$ColumnCount 	= $this.reader.FieldCount;
		$GotColumns = $false;
		[array]$resultset = @();
		$TemplateObject = New-Object PsObject;
		$ColumnNames	= 1..$ColumnCount;
		
		try {
			#Now, lets configure hadNext to points to null. This indicates that we dont know about if there are most results to fetch...
			$this.hadNext = $null;
			
			#If we already read sometime, then we must call NextResult in order to get another results.
			#Note that this call will block if query still running, and can throw sql exceptions...
			if($this.readCount -ge 1){
				$this.hadNext = $this.reader.NextResult();
			} else {
				#If it just first time, then just set to hadNext...
				$this.hadNext = $true;
			}
			
		} finally {
			$this.readCount++; #Increment our readcount, indepently if throws exceptions or not...
		}
		
		
		write-verbose 'READER_PARSE: begin consume loop...'
		#Lets start read the rows from current resultset...
		while($this.reader.read() -eq $true)
		{
			#Lets build a sample object that will contains the columns...
			if(!$GotColumns){
				write-verbose 'READER_PARSE: building columns list...'
				$GotColumns = $true;
				
				$i = $ColumnCount;
				#For each column...
				while($i--){
					$ColumnName 	= $this.reader.GetName($i);  
					
					#If hasn't name, then generate a default...
					if(!$ColumnName){
						$ColumnName = "(No Column Name $i)"
					}
					
					$TemplateObject | Add-Member -Name $ColumnName -Type Noteproperty -Value $null;
					$ColumnNames[$i] = $ColumnName;
				}

				write-verbose "READER_PARSE: column list count: $(@($ColumnNames).count) "
			}

			#Alright, at this point, we can iterate over column for get the value, for each row...
			
			#For each column value, in current row...
			
			$i = $ColumnCount;
			while($i--){
				$ColumnName = $ColumnNames[$i]; #Get current colummn name from column name cache...;
				
				if($this.reader.isDbNull($i)){
					$ColumnValue = $null;
				} else {
					$ColumnValue = $this.reader.getValue($i);
				}
				
				$TemplateObject.$ColumnName = $ColumnValue;
			}
			
			
			
			$resultset += $TemplateObject.psobject.copy();
		}
		
		#Returning to caller...
		return $resultset;
	
	})

	
	$o | Add-Member -Type ScriptMethod -Name GetNextResultSet -Value $GetNextResultSet;
	
	return $o;
}


#This will implement some new releases.
Function New-MSSQLSessionBeta
{
	[CmdLetBinding()]
	param($serverInstance = $null,$database = "master",$logon=@{AuthType="Windows";User="";Password=""},$appName="CUSTOM_MSSQL_POWERSHELL", $exString = "", [switch]$Pooling = $false)
	
	$Session = New-Object -Type PsObject @{ServerInstance = $serverInstance
											database = $database
											logon = $logon
											appName = $appName
											exString = $exString
											pooling=$Pooling
										}
	
	
	#This method allow you load all assemblies need for SMO.
	#This method make all checking need for loading the SMO dependencies.
	#Just call it.
	$LoadSMO = [scriptblock]::create({
	
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
		
		#This contains possible versions of SQL Server folders with SMO libraries.
		$PossibleVersions = 120,110,100
		$BaseFolder = "C:\Program Files\Microsoft SQL Server\{0}\SDK\Assemblies\"
		
		#The script will try select the folder with the major quantity of dll files.
		$LastQtd = 0
		$ElegibleFolder = ""
		$PossibleVersions | %{
			$CurrentFolder = $BaseFolder -f  $_
			$qtdAvailable = @(gci -EA "SilentlyContinue" @($assemblylist|%{"$CurrentFolder\*$_*.dll"})).count
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
	
	})
	

	#This method open a connection with the server...
	$newSession = [scriptblock]::create({
						param($serverInstance = $null,$database = "master",$logon=@{AuthType="Windows";User="";Password=""}, $exString="")
						
						write-verbose "Attemping create the new session."
						
						#Check if already some session for this object...
						$currentSession = $this._session
						
						if($currentSession)
						{
							write-verbose "The current session objects already a value."
							throw "SESSION_ALREADY_CREATED"
						}

						if($serverInstance) {
							$this.serverInstance = $ServerInstance
						}
						write-verbose "The server instance will be: $($this.serverInstance)"
						
						if($database){
							$this.database = $database
						}
						write-verbose "The database will be: $($this.database)"
						
						if($logon){
							$this.logon = $logon
						}
						write-verbose "The logon auth type will be: $($this.logon.AuthType)"
						
						
						$authentication = "Integrated Security=True"
						$appName = $this.appName
						
						if($this.logon.AuthType -eq "SQL") {
							write-verbose "The logon user will be: $($this.logon.User)"
							write-verbose "The logon pass will be: $($this.logon.Password)"
						
							$authentication = "User=$($this.logon.User);Password=$($this.logon.Password)"
						}
						
						if(!$appName){
							$appName = "CUSTOM_MSSQL_POWERSHELL"
						}
						
						write-verbose "The app name will be: $appName"
						
						$ConnectionString = @(
							"Server=$($this.ServerInstance)"
							"Database=$($this.database)"
							$authentication
							"APP=$appName"
						)
						
						if(!$this.Pooling){
							$ConnectionString += "Pooling=false"
						}
						
						$connectionString += ($exString -split ";");
						
						#RRG_EDIT: Changed connection string direct to Join form...
						# "Server=$ServerInstance;Database=$Database;Integrated Security=True;App=$App"
						$NewConex = New-Object System.Data.SqlClient.SqlConnection
						$NewConex.ConnectionString = $ConnectionString -Join ";" 
						
						#All errors and messages will be fired as message events..
						$NewConex.FireInfoMessageEventOnUserErrors = $true;
						
						
						
						write-verbose "The final connection string is: $($NewConex.ConnectionString ) "
						
						try {
							write-verbose "Attempting open tthe connection object"
							$NewConex.Open()
							
							write-verbose "Storing connection object on the session property"
							$this._session = $NewConex
						} catch {
							write-verbose "Some error while connect to server..."
							if($NewConex){
								$NewConex.Dispose()
							}
							throw ($_.Exception.GetBaseException())
						}
					})
					
	#This command ends a connections with server
	$endSession = [scriptblock]::create({
						param($Conex)
						
						if($this._session)
						{
							write-verbose "The  connection object will be disposed."
							$this._session.Dispose()
							
							write-verbose "The  session property will be null"
							$this._session = $null	
						} else {
							write-verbose "No connection on session object available to ending."
						}
	
					})
			
	
	#Get Current Session state, based on SQL Server States.
	#possibles are: SLEEPING;RUNNING
	$getState = [scriptblock]::create({
					$currentState = "SLEEPING"
					$con = $this._session
					
					write-verbose "Attempt get the state."
					
					if($con)
					{
						write-verbose "The current connection state is: $($con.State) "
						
						switch($con.State)
						{
							"Broken" {$currentState="DISCONECTTED"}
							"Closed" {$currentState="DISCONECTTED"}
							"Connecting" {$currentState="RUNNING"}
							"Executing" {$currentState="RUNNING"}
							"Fetching" {$currentState="RUNNING"}
							"Open" {$currentState="SLEEPING"}
						}
					} else {
						$currentState = "DISCONECTTED"
					}
					
					return @{state=$currentState}
				})
	
	#This method execute a batch on the session.
	$execute =  [scriptblock]::create({
					param($TSQL,$ServerInstance = $null,$Database = $null,$Logon = $null,$QueryTimeout = $null,$Close = $false, $ExString = "")
		
					try {
						
						if(!$this._Session)
						{
							write-verbose "No session opended for this objects."
							$Close = $true
							
							write-verbose "Creating session objects..."
							$this.newSession($ServerInstance,$Database,$Logon,$ExString)
						}
			
						$sessionState = $this.getState().state
						
						write-verbose "Current session state is: $sessionState"
						if($sessionState -ne "SLEEPING")
						{
							write-verbose "Session is not sleeping! A erro will trhowed"
							throw "SESSION_BUSY[$sessionState]"
						}
						
						write-verbose "Creating the command object..."
						$commandTSQL = $this._session.CreateCommand()
						
						write-verbose "Setting the SQL script to: $TSQL"
						$commandTSQL.CommandText = $TSQL
						
						write-verbose "Setting the query timeout for : $QueryTimeout"
						$commandTSQL.CommandTimeout = $QueryTimeout
						
						write-verbose "Creating reader parser..."
						#This is a workaround to use SqlData reader in powershell V2...
						#A behavior in powershell cause it call the enumerator of some parameters that are passed.
						#With SqlDataReader, if this happens, the result returned are lost...
						#Thus, using this object, we can "protect" the sqldata reader in some property of objct and pass object between calls...
						$ReaderParser = NewDataReaderParser
						
						#Create the result objects...
						$ExecutionResults = $this.NewResult();
						
						#Register event to catch results...
						$InfoMessageSubcriber = Register-ObjectEvent -InputObject $this._session -EventName "InfoMessage";
						
						#Get the event subcription...
						$EventSubscription = Get-EventSubscriber | ? {$_.SourceObject.Equals($this._session) -and $_.EventName -eq 'InfoMessage'};
			
						
						try{
							$result = $null;
							write-verbose "Executing the command on the connection..."
							$ReaderParser.reader = $commandTSQL.ExecuteReader()
						} catch {
							write-verbose "Some error ocurred while execute the command"
							
							#Check if base exception is SQL Exceptions...
							$Bex = $_.Exception.GetBaseException();
							
							if($Bex -is [System.Data.SqlClient.SqlException]){
								$ExecutionResults.messages += $Bex.Errors;
							}
							else {
								throw ($_.Exception.GetBaseException())
							}

						}
						
						if(!$ReaderParser.reader){
							$ReaderParser.hadNext = $false;
						}
				
						try {
							write-verbose "Attempting get the results"
							
							while( $ReaderParser.hadNext ){
								try {
									$ExecutionResults.resultsets += $ReaderParser.GetNextResultSet();
								} catch {
									$Bex = $_.Exception.GetBaseException();
									
									if($Bex -is [System.Data.SqlClient.SqlException]){
										$ExecutionResults.messages += $Bex.Errors;
									}
									else {
										throw; #Was another error from .NET . Script must ends.
									}
									
								}
							}
							
						} catch {
							$bex = $_.Exception.GetBaseException()
							$Error = "READER_PARSER:"+$bex.Message
							throw New-Object -Type System.Exception -ArgumentList "$Error",$bex
						}
						
					} catch {
						throw
					} finally {
					
	
						#Message events.
						write-verbose "Getting remaining events..."
						Get-Event | ? {$_.Sender.Equals($this._session)} | %{
							$EventArguments = $_.SourceEventArgs -as [System.Data.SqlClient.SqlInfoMessageEventArgs];
							$ExecutionResults.messages += $EventArguments.Errors;
							Remove-Event -EventIdentifier $_.EventIdentifier;
						}
						
						write-verbose "Removing InfoMessage subscriptions..."
						if($EventSubscription){
							$EventSubscription | %{
									UnRegister-Event -SubscriptionId $_.SubscriptionId 
							}
						}
					
						if($ReaderParser.reader)
						{
							write-verbose "Disposing SqlDataReader object..."
							$ReaderParser.reader.Dispose()
						}
						
						if($commandTSQL)
						{
							write-verbose "Disposing Command object..."
							$commandTSQL.Dispose()
						}
						
						if($Close)
						{
							write-verbose "Ending this session!"
							$this.endSession()
						}
						
						if($ReaderParser){
							$ReaderParser  = $null;
						}
					}
					
					#Identifies message severity above 11.
					$ExecutionResults.messages | %{
						if($_.Class -ge 11){
							$ExecutionResults.errors += $_;
							$ExecutionResults.exceptionText += $_.message+"`r`n";
						}
					}
					
					
					return $ExecutionResults;
				})
	
	
	#Creates a object that contains results returned by executions..
	$NewResult = [scriptblock]::create({
			return New-Object PSObject -Prop @{resultsets=@();messages=@();errors=@();exceptionText=$null};
		})
	
	#This method provide a form of you call evalute policies stored in this server in anothers servers.
	$evaluatePolicy = [scriptblock]::create({
					param($policies,[string[]]$targetServer,$targetLogon = $null,$evaluationMode="CHECK",$serverInstance = $null,$logon = $null, $close = $false, $AppName = "POWERSHELL-MSSQL-POLICY_BASED_MANAGEMENT")
			
						if(!$this._Session)
						{
							write-verbose "No sessino opended for this object"
							$Close = $true
							
							write-verbose "Creating session objects..."
							$Database = "master"
							$this.newSession($ServerInstance,$Database,$Logon)
						}
			
						$sessionState = $this.getState().state
						
						write-verbose "Current session state is: $sessionState"
						if($sessionState -ne "SLEEPING")
						{
							write-verbose "Session is not sleeping! A erro will trhowed"
							throw "SESSION_BUSY[$sessionState]"
						}
						
						#Loading SMO library for internal PBM access
						$this.LoadSMO()
						
						#Creating the connection
						
						## For evaluation a policy in specific server, we need generate SqlStoreConnection...
						
						
						
						$targetServers = @(
							$targetServer | %{
								$targetConex = New-Object System.Data.SqlClient.SqlConnection
								$AuthenticationString = "Integrated Security=True;";
								
								if($targetLogon.AuthType -eq "SQL") {
									$AuthenticationString = "User=$($targetLogon.User);Password=$($targetLogon.Password);"
								}
								
								$targetConex.ConnectionString = "Server=$_;Database=master;App=$AppName;$AuthenticationString"
								$targetSqlStoreConnection =  New-Object Microsoft.SqlServer.Management.Sdk.Sfc.SqlStoreConnection($targetConex)
								
								return New-Object PSObject -Prop @{name = $_; sqlStoreConnection = $targetSqlStoreConnection}
							}
						)
						
						try {
						#We open connection with the current server, that's it, the current Policy Store.
						
							#Let's create a SqlStoreConnection object.
							$policySqlStoreConnection = New-Object Microsoft.SqlServer.Management.Sdk.Sfc.SqlStoreConnection($this._session)
							$policySqlStoreConnection = New-Object Microsoft.SqlServer.Management.Sdk.Sfc.SqlStoreConnection($this._session)
							
							#Finnaly, lets create the connection with the policystore \o/
							$policyStore = New-Object Microsoft.SqlServer.Management.Dmf.PolicyStore($policySqlStoreConnection)
							
						#All right... Lets get the policies, based on user filter...
						if($policies -is [scriptblock]){
							$filter = $policies
						}
						
						if($policies -is [object[]] -or $policies -is [string] ){
							$policyNames = $policies  -as [string[]]
							$filter = {  $policy = $_; @($policyNames | WHERE {$policy.Name -like $_}).count -gt 0 }
						}
						
						if($Policies -eq $null){
							$filter = {$true}
						}
						
						$filter = [scriptblock]::create($filter);
						
						$elegiblePolicies = @($policyStore.Policies | WHERE $filter)

						#For each server, by time, evaluate the policy by policy...
						$Evaluations = @(
							$targetServers | % {
								$currentServer = $_
							
								$elegiblePolicies  | %{
									$resultObject = $null
									#Creating a event identifier for listen event related with the policy that we call evaluation...
									#This is a unique string that we pass to Register-ObjectEvent cmdlet.
									#We will need do this for get policie evaluation results for this evaluation only.
									$currentPolicy = $_
									try {
										$EventSourceIdentifier = "$($currentServer.ServerInstance)-$($currentPolicy.Name)-"+([Guid]::NewGuid()).Guid
										
										#Registering the event for getting evaluation results....
										Register-ObjectEvent -InputObject $currentPolicy -EventName PolicyEvaluationFinished -SourceIdentifier $EventSourceIdentifier | Out-Null
										
										#Calling the evaluation...
										$evaluateTarget = $currentServer.sqlStoreConnection
										$evresult = $_.evaluate($evaluationMode,$evaluateTarget)
										
										#Waiting on the event... At this moment it must be fired... The Wait must be fast!
										$EventData = Wait-Event -SourceIdentifier $EventSourceIdentifier
										

										#Getting the object containing the evaluation information...
										$EvaluationResultsDetails = $EventData.SourceEventArgs
										$EvaluationResult = $EvaluationResultsDetails.Result
										$EvaluationDetails = $EvaluationResultsDetails.EvaluationHistory.ConnectionEvaluationHistories[1].EvaluationDetails
										
										$resultObject = New-Object PSObject -Prop @{evaluationPolicy = $_.Name
																		evaluationTarget = $currentServer.name
																		evaluationResult = $EvaluationResult
																		evaluationDetails = $EvaluationDetails
																	}
									} finally {
										#Attempting close the target connection
										#Freeing the resources...
										if($EventData) {
											$EventData | Remove-Event 
											if(Get-EventSubscriber -SourceIdentifier  $EventSourceIdentifier)
											{
												Unregister-Event -SourceIdentifier  $EventSourceIdentifier
											}
										}
									}
									
									if($resultObject) {
										return $resultObject
									}
								}
								
							}
						)

					} finally {
						if($policyStore){
							$policyStore = $null
						}
						
						if($policySqlStoreConnection){
							$policySqlStoreConnection = $null
						}
						
						if($close){
							$this.endSession()
						}
					}
					
					return $Evaluations;
				})
	
	
	$Session | Add-member -Type ScriptMethod -Name newSession -Value 	$newSession
	$Session | Add-member -Type ScriptMethod -Name endSession -Value 	$endSession
	$Session | Add-member -Type ScriptMethod -Name connect -Value 	$newSession
	$Session | Add-member -Type ScriptMethod -Name disconnect -Value 	$endSession
	$Session | Add-member -Type ScriptMethod -Name getState -Value 	$getState
	$Session | Add-member -Type ScriptMethod -Name execute -Value 	$execute
	$Session | Add-member -Type ScriptMethod -Name loadSMO -Value 	$loadSMO
	$Session | Add-member -Type ScriptMethod -Name evaluatePolicy -Value 	$evaluatePolicy
	$Session | Add-member -Type Noteproperty -Name _session -Value 	$null
	$Session | Add-member -Type Noteproperty -Name serverInstance -Value 	$null
	$Session | Add-member -Type Noteproperty -Name database -Value 	$null
	$Session | Add-member -Type Noteproperty -Name logon -Value 	$null
	$Session | Add-member -Type ScriptMethod -Name NewResult -Value $NewResult

	if($serverInstance){
		write-verbose "Starting the creation of a session object!"
		write-verbose "ExString is: $exString"
		$Session.newSession($serverInstance,$database,$logon,$exString)
	}
	
	return $Session 
}

Function Invoke-NewQueryBeta  {
	[CmdLetBinding()]
	param(	
			#This is the Server instance. Can be ip address, ip and port, name\instance, etc.
				[Alias("S")]
				[parameter(Mandatory=$false, ValueFromPipeline=$true)]
				$ServerInstance = $null
			
			,#This is the Database name that you want connect to.
				[Alias("D")]
				$Database = "master"
				
			,#This is the Query that you want execute.
				[Alias("Q")]
				$Query = $null
			
			,#This is the login name, if you want to use SQL Login instead of Windows Authentication.
			 #If you want use Windows Authentication, dont specify this parameter.
				[Alias("U","Username")]
				$Login=$null
				
			,#This is the password of login.
				[Alias("P")]
				$Password = $null
				
			,#This is the application name show in sys.dm_exec_sessions
				$appName = "CustomMSSQL"
			
			,#This options controls if you wont fix the SET OPTIONS that affects the results.
			 #Some options of the session can produce slow query plans if not configured correctly.
			 #Check this technet article to more details: https://technet.microsoft.com/en-us/library/ms175088(v=sql.105).aspx
			 #By default, the cmdlet will execute some "SET" commands before executing the user query, on same connection opened.
			 #If you specify this option, the cmdlet will not execute this set options.
				[Switch]$NoFixSetOptions = $false
				
			,#Specify some additional connection strings parameters that you can use.
				$exString = ""
				
			,#Specify input file with a query. If both Query and InputFile is specified, this takes precedence.
				[Alias("i")]
				$InputFile = $null
				
			,#This is another way of specifu credentials to connect to SQL Server.
			 #It is just a hashtable containing some keys defining the logon informations. 
			 #The keys are:
			 #	AuthType: The type of Authentication, The values are: Windows or SQL
			 #	Login: The SQL Login, if AuthType is "SQL"
			 #	Password: The Login Password.
			 #
			 # If you specify "Login" parameter, it will override this option.
				$Logon = @{AuthType="Windows"}
				
				
			,#Alterantive way to specify "ServerInstance". Is useful to use with results of Get-InstanceByProperty cmdlet.
				[parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
				$connectionName = $null
				
			,#Specify the minimum version required by server for script run.
			 #The script will try connect to target instance and get version...
			 #If version returned is less thant this parameter, the script is not execubtale.
			 #The min version must be specified in format MAJOR.MINOR.BUILD or a numeric value represting it.
			 #If cmdlet cannot obtain instance version, the exception CANNOT_GET_VERSION is throwed!
			 #Check the notifications of special output or verbose logging for reason of incompatible version.
				$MinVersion = $null
				
			,#Specify the maximum version required by server for script run.
			 #This will follow the same rules that MinVersion parameter.
			 #Note that build versions is considered. For example, a server with version 10.50.6000 cannot will execute if this parameter is 10. 
			 #If you want execute on all server with maximum version 10.50 (sql 2008 r2) you must specify 10.50.9999. If you wan on sql 2008 only, you can specify 10.00.9999
				$MaxVersion = $null
				
			,#BETA! Executes sp_whoisactive @find_block_leaders = 1,@sort_order = '[blocked_session_count] DESC'
			 #The sp_whoisactive must exists and user must have permissions to run it.
				[switch]
				$FindBlockers = $false
			 
			,#By default, when this cmdlet executes for multiple server, it returns a special object array containing results and errors for each server.
			 #When it execute on a single server, it return the direct resultset or errors, if any.
			 #If this parameter is specified, the output of cmdlet is always the object array,  independently of number of server.
				[switch]
				$ForceSpecialOutput = $false
	)
	
begin {
	#Get all servers!
	$AllConnections = @()
	
	if($MinVersion){
		$NumericMinVersion = GetProductVersionNumeric $MinVersion;
	}
	
	if($MaxVersion){
		$NumericMaxVersion = GetProductVersionNumeric $MaxVersion;
	}
}

process {
	
	$ConexInfo = New-Object PSObject -Prop (GetAllCmdLetParams)
	$ConexInfo | Add-Member -Type Noteproperty -Name Results -Value $null 
	$ConexInfo | Add-Member -Type Noteproperty -Name Errors -Value @()
	$ConexInfo | Add-Member -Type Noteproperty -Name Notifications -Value @()
	$ConexInfo | Add-Member -Type Noteproperty -Name ConnectionInfo -Value $ConexInfo;
	$AllConnections += $ConexInfo;
}
	
end {
	
	$isMultiple = $false;
	
	if($AllConnections.count -gt 1){
		$isMultiple = $true;
	}
	
	:ConexoesLoop foreach($ConexInfo in $AllConnections){

		#If the ServerInstance contains a object with a property connectionName...
		if($ConexInfo.ServerInstance.connectionName){
			$ConexInfo.ServerInstance = $ConexInfo.ServerInstance.connectionName;
		}
		
		elseif($ConexInfo.connectionName -and !$ConexInfo.serverInstance){
			$ConexInfo.ServerInstance = $ConexInfo.connectionName;
		}
		
		if($ConexInfo.Login){
			$ConexInfo.logon = @{
					AuthType = "SQL"
					User=$Login
					Password=$Password
				}
		}
		
		if(!$ConexInfo.ServerInstance)
		{
			$ex = New-Object System.Exception("You must provide a server instance");
			if($isMultiple){
				$ConexInfo.Errors += $ex
				continue :ConexoesLoop;
			} else {
				throw $ex;
			}
		}

		$Query = $ConexInfo.Query;
		if($ConexInfo.InputFile){
			
			if(Test-Path $ConexInfo.InputFile)
			{
				$Query = (Get-Content $ConexInfo.InputFile) -Join "`r`n"
			} else {
				$ex = New-Object System.Exception( "Invalid File: $InputFile");
				
				if($IsMultiple){
					$ConexInfo.Errors += $ex
					continue :ConexoesLoop;
				} else {
					throw $ex;
				}
			}
		}
		
		if($FindBlockers){
			$Query = "EXEC sp_whoisactive @find_block_leaders = 1, @sort_order = '[blocked_session_count] DESC' ";
		}
		
		if(!$Query)
		{
			$ex = New-Object System.Exception( "Invalid Query");
			
			if($IsMultiple){
				$ConexInfo.Errors += $ex
				continue :ConexoesLoop;
			} else {
				throw $ex;
			}
		}
		

		
		$FIX_SET_OPTIONS = @(
						"SET ANSI_NULLS ON;"
						"SET ANSI_PADDING ON;"
						"SET ANSI_WARNINGS ON;"
						"SET ARITHABORT ON;"
						"SET CONCAT_NULL_YIELDS_NULL ON;"
						"SET NUMERIC_ROUNDABORT OFF;"
						"SET QUOTED_IDENTIFIER ON;"
						) -Join "`r`n"
		
		try {
			$NewQuery = $null;
			$NumericServerVersion = $null; #This will store the target server numeric version.
			
			$NewQuery = New-MSSQLSessionBeta -serverInstance $ConexInfo.ServerInstance -database $ConexInfo.database -Logon $ConexInfo.logon -appName $ConexInfo.appName -exString $ConexInfo.exString
		
			#Try get maximum version if specified.
			if($ConexInfo.MinVersion -ne $null -or $ConexInfo.MaxVersion -ne $null){
			
				
				$CompatibleVersion = $true;
				$IncompatibilityReason = @()
			
				try {
					$QueryResult = $NewQuery.execute("SELECT SERVERPROPERTY('ProductVersion') as ProductVersion");
					
					if($QueryResults.errors){
						throw $QueryResults.exceptionText;
					}
					
					$NumericServerVersion =  GetProductVersionNumeric $QueryResult.ProductVersion;
				} catch {
					throw "CANNOT_GET_VERSION: $_"
				}
				
				#Check if version is compatible!
				if($NumericMinVersion -and $NumericServerVersion -lt $NumericMinVersion){
					$CompatibleVersion = $false;
					$IncompatibilityReason = "Current version < Min Version"
				}
				
				if($NumericMaxVersion -and $NumericServerVersion -gt $NumericMaxVersion){
					$CompatibleVersion = $false;
					$IncompatibilityReason = "Current version > Min Version"
				}
				
				if(!$CompatibleVersion){
					$ReasonText = $IncompatibilityReason -join "`r`n";
					$Message = "Ignoring query execution because version. Required min:$NumericMinVersion max:$NumericMaxVersion Current:$NumericServerVersion. Reasons: $ReasonText";
					write-verbose $Message 
					$ConexInfo.Results = $null;
					$ConexInfo.Notifications += $Message;
					continue :ConexoesLoop;
				}
				
			}
			
			
			
			if(!$ConexInfo.NoFixSetOptions){
				try {
					write-verbose ("Fixing the SET OPTIONS: "+$FIX_SET_OPTIONS)
					$QueryResults = $null;
					$QueryResults = $NewQuery.execute($FIX_SET_OPTIONS)
					
					if($QueryResults.errors){
						throw $QueryResults.exceptionText;
					}
					
				} catch {
					write-verbose ("SET_OPTIONS FIX ERROR: "+($_.Exception.Message))
				} 
			}
			

			
			$resultset = $NewQuery.execute($Query)
			$ConexInfo.Results = $resultset;
		} catch {
			$ex = $_;
			
			if($IsMultiple){
				$ConexInfo.Errors += $ex
				continue :ConexoesLoop;
			} else {
				throw $ex;
			}
		} finally {
			if($NewQuery){
				$NewQuery.endSession()
			}
		}
	
	}
	
	if($IsMultiple -or $ForceSpecialOutput){
		return $AllConnections
	} else {
		return $AllConnections[0].Results;
	}
}

	<#
		.SYNOPSIS 
			Connects to SQL Server instance and execute a query, using .NET System.Data.SqlClient library.
			
		.DESCRIPTION
			This cmdlet is a rewrite of Invoke-SqlCmd and Sqlcmd.
			It is build on top of "New-MSSQLSession" cmdlet provided by CustomMSSQL for executing queries without session control.
			This cmdlet is useful for run administrative scripts on a sql server.
			
			The cmdlet returns the first resultset only as a array of objects.
			Each row returned is a object. Each column of a row is a "Noteproperty" of the object.
			
			If errors happens while executing the query, the cmdlet throws a exception of type SQLException.
			You can use SQLException to get access to all errors thrown.
			
			The cmdlet provide some parameters that have same name in the Invoke-Sqlcmd (from sqlps module).
			This is for compatibility reasons. But it provides more alternatives and options. Check parameters documentation for more information.
			
			You can pipe output of Get-InstanceByProperty cmdlet in this modudle. This cmdlet is compatible.
			When this cmdlet execute in multiple servers, it returns the results in a special output. Check OUTPUT AND SPECIAL OUTPUT section. 
			
			You also can pipe server names as a string array.
			
			
			OUTPUTS AND SPECIAL OUTPUT
				In some situations, the cmdlet will return a simple output containing the resultset.
				This is default behavior when cmdlet execute on just a single isntance.
				If parameter ForceSpecialOutput or multiple servers are used, the cmdlet will return a special output.
				The special output is a object array containing execution results for each instance the cmdlet tried execute the query.
				The special output can present many properties and informations, but just descrbied here will be supported and compatibility is guaranted.
				
				The special output supported properties is:
				
					
					ConnectionInfo
						This is a object containing the properties that are the parameters and values passed to the cmdlet.
						
					Results
						Will contains the resultset.
						
					Errors
						Will contains the errors generate by execution on that server.
						
					Notifications
						Will contains the notifications generated by cmdlet.
						Check NOTIFICATIONS section for more information.
						
			NOTIFICATIONS
				This cmdlet can generate some useful messages to debug a error or not expected result.
				The notifications is available on special output via property notifications.
				For example, when cmdlet not execute script because MaxVersion or MinVersion parameters, the reason will be placed on notifications.
				
			KNOW BUGS
				- Poor fetch perfomance
					This cmdlet fetchs rows from data reader slow comparing with sqlps module or a direct write on c#.
					We suspect that this is due the fact the all core is write in powershell and powershell is more slow than native .net code. (Invoke-SqlCmd is write in c#)
					Between releases, we stay improve perfomance of this.
					But, this perfomance diference is notable when you read many rows from server. If you use scripts that just returns one row, for example, this cannot be a issue.
					
				- GO 
					This cmdlet dont parse GO. In future releases, this will comes implemented.
					If you need GO, try use sqlps module or another. Sorry.
					
		
		.EXAMPLE
			
			$allTables = Invoke-NewQuery -ServerInstance MyServer -Database "MyDatabase" -Query "SELECT name FROM sys.tables"
			
		.NOTES
		
			KNOW ISSUES
				Handle "GO" - This cmdlet don't handle "GO"
				
			WHAT'S NEW
	#>
}

