Function Send-Data2Zabbix {
	[CmdLetBinding(SupportsShouldProcess=$True)]
	param(
		#This is the custom parameters the you can pass to powershell script
			[hashtable]$Params = @{}
		
		,#This are the Keys Definitions. The Keys Definitions are a powershell hashtable.
		 #It defines which items will be send to server and the query that generate values.
		 #You can pass a path to the powershell ps1 file or a hahstable directly.
			[Object]$KeysDefinitions
			
		,#This is zabbix server. Specify host. You can speicy a port by appending ":" at end of.
		 #If no port is specified, the default is used.
			[string]$ZabbixServer
			
		,#This is path to a zabbix sender tool. This tool is provided with Zabbix Agent.
		 #Check www.zabbix.com/download.php for most recent version
		 #The script uses sender to delivery keys to zabbix server. This is well documented and supported by zabbix team.
			[string]$zabbixSender
			
		,#This is directory where scripts specified in keys file will be searched.
			[string]$DirScripts  = "."
		
		,#This is hostname defined on Zabbix. The script will send the keys to this hostname. It must match a existent host on zabbix server.
		 #If null, the scripts builds hostname from @@ServerName. The "\" is replaced by "space". 
			[string]$HostName		= $null

		,#This is time that script will wait before re-executing queries to send to zabbix server again.
		 #If this value is $null, then script will query one time and ends. This value is in milliseconds.
			[int]$PoolingTime	= $null
			
		,#This control time, in seconds, for reload keys definitions.
			[int]$ReloadTime	= 600
			
		,#This controls the logging.
		 #Specifies level between brackets. 
			$LogTo = "#"
		
		,#Specifies log level.
			$LogLevel = "DETAILED"
	)

	$ErrorActionPreference = "stop";
	
	$INFO = @{
		INSTANCE_NAME=$null
		HOSTNAME=$Hostname
		ZABBIX = @{
				SERVER=$null
				PORT=$null
			}
	}
	
#Global Values
	$VALUES = @{
				WIN_USERNAME			= [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
				COMPUTER_NAME			= $Env:ComputerName
			}
	
	
#Lets use Logging facilities provide by CustomMSSQL module...
	$Log = (GetLogObject)
	$Log.LogTo = $LogTo;
	$Log.LogLevel = $LogLevel; 
	$Log.ExternalVerboseMode = $IsVerbose; 

	Function Log {
		param($message,$LogLevel = $null,$Force = $false, $Retain = $false, $Flush = $false)

		$Options = @{retain=$Retain;flush=$Flush};

		$Log.Log($message,$LogLevel,$Force,$null,$null,$Options)
	}
	
	Log "Script is starting! User: $($VALUES.WIN_USERNAME) Computer:$($VALUES.COMPUTER_NAME)"
#Some dependencies
	Add-Type -Assembly System.Web.Extensions
	$jsonParser = New-Object System.Web.Script.Serialization.JavascriptSerializer
	
	
#Lets interpret zabbix server info
	
	Log "Evaluating zabbix server and port"
	$ServerPort = $ZabbixServer -Split ":";
	$INFO.ZABBIX.SERVER = $ServerPort[0];
	
	if($ServerPort[1]){
		$INFO.ZABBIX.PORT = $ServerPort[1]
	} else {
		$INFO.ZABBIX.PORT = 10051
	}
	
	Log "	Server is: $($INFO.ZABBIX.SERVER) Port is: $($INFO.ZABBIX.PORT)"
	
	
#This is all functions responsible for getting keys and determing which is sql source or powershell source...
	Function UpdateKeysForGet {
		param($KeysDefinitions, $Logging = "VERBOSE")
		
		$AllKeysDefintions = @{};
		
		foreach($KeyDef in $KeysDefinitions){
			
			if($KeyDef -is [string]){
				if(![System.IO.File]::Exists($KeyDef)){
					throw "INVALID_KEY_DEFINITIONS: FileNotExists $KeysDefinitions";
				}
				
				Log "Getting keys definitions from FILE $KeysDefinitions" $Logging
				$TempHash = & $KeyDef
				$TempHash.GetEnumerator() | %{
					$AllKeysDefintions.add($_.Key,$_.Value)
				}
				Log "	Sucessfuly" $Logging
			}
			
			if($KeyDef -is [hashtable]){
				Log "Key defintiions is a hashtable!"
				$KeyDef.GetEnumerator() | %{
					$AllKeysDefintions.add($_.Key,$_.Value)
				}
				Log "	Sucessfuly" $Logging
			}
		}
		
		if(!$AllKeysDefintions.Count){
			throw "INVALID_KEY_DEFINITIONS"
		}
	
		return $AllKeysDefintions;
	}

	Function UpdateKeysFinal {
		param($KeysForGet, $Logging = "VERBOSE")
		
		$AllKeysFinal = @()
		
		$KeysForGet.GetEnumerator() | %{
			$KeyName 		=  $_.Key;
			$KeySourceFull	= $_.Value;
			$KeySource		= @{}
			
			Log "	Key: $KeyName" $Logging
			
			$isLLD = $false;
			if($KeyName -like "LLD:*"){
				$KeyName = $KeyName -replace '^LLD:',''
				$isLLD = $true;
			}

			$SourceType = "PS";
			
			if ($KeySourceFull -is [scriptblock]){ #If keys is a scriptblock
				$SourceType = "PS";
				$KeySource.add("SCRIPT",$KeySourceFull);
				$KeySource.add("SOURCE",$KeySourceFull);
				$KeySource.add("COLUMN",$null);
			}
			
			$KeySource.add("TYPE",$SourceType);

			Log "	Source Type: $SourceType Source: $($KeySource.SOURCE)" $Logging
			
			$AllKeysFinal += New-Object PSObject -Prop @{
												KEY 		= $KeyName
												SOURCE		= $KeySource
												isLLD		= $isLLD
										}
		}
		
		return $AllKeysFinal;
	
	}

	Log "Evaluating keys file..."
	$KeysForGet = (UpdateKeysForGet -KeysDefinitions $KeysDefinitions "PROGRESS") 
	$KeysFinal = (UpdateKeysFinal -KeysForGet $KeysForGet "PROGRESS") 
	$LastReloadTime = Get-Date
	
Log "Hostname is: $($INFO.HOSTNAME)"
$Params.GetEnumerator() | %{
	Log "Param $($_.Key): $($_.Value)" "VERBOSE"
}

Log "Entering on main loop"

do {

	if( $LastReloadTime -eq $null -or ((Get-Date)-$LastReloadTime).totalSeconds -ge $ReloadTime){
		Log "Reloading keys" "VERBOSE"
		try {
			$KeysForGet = (UpdateKeysForGet -KeysDefinitions $KeysDefinitions)
			$KeysFinal = (UpdateKeysFinal -KeysForGet $KeysForGet)
			$LastReloadTime = (Get-Date)
		} catch {
			$FormattedError = (FormatPSException $_)
			Log "	Failed reload keys. Last keys will be used: $FormattedError"
		}
	}

	$DataForSend = @()

	Log "	Looping through keys" "VERBOSE"
	foreach($k in $Keysfinal){
		$queryResults = $null;
		
		Log "		Executing source for key $($k.KEY)" "VERBOSE"
		try {
			if($k.SOURCE.TYPE -eq "PS") {
				$queryResults = @(& $k.SOURCE.SCRIPT $Params)
				if($queryResults.count -eq 1 -and  $queryResults[0] -ne $null -and $queryResults[0].getType().Name -ne "PSCustomObject"){
					$queryResults = New-Object PSObject -Prop @{ "__results" = $queryResults[0]}
				}
			} else {
				throw "INVALID_SOURCE_TYPE: $($k.SOURCE.TYPE)"
			}
		} catch {
			$FormattedError = (FormatPSException $_)
			Log "			Error when executing query for key $($k.KEY): $FormattedError" "PROGRESS"
			continue;
		}
		
		if(!$queryResults){
			Log "		Query dont return any result or meta-data!" "VERBOSE"
			continue;
		}
		

		
		if($k.isLLD){
			Log "			This key is a LLD mode! Result query will be converted to a zabbix JSON LLD format." "VERBOSE"
			try {
				$r =  ConvertTo-ZabbixLLD $queryResults;
				$DataForSend += "- $($k.KEY) $r";
				continue;
			} catch {
				Log "			Error when generating JSON for LLD KEY $($k.KEY): $_" "PROGRESS"
				continue;
			}
		}
		
		#Lets update columns mapping.
		$realKeyName = $k.KEY;
		$ColumnsForKey	= @();
		$ColumnsForData = @();
		
		
		#Getting all columns available on result. We need this data.
		if($k.SOURCE.COLUMN){
			$AvailColumns = @($k.SOURCE.COLUMN)
		} else {
			$AvailColumns = @($queryResults | gm -Type "Noteproperty" | %{$_.name});
		}
		
		Log "		Total columns is: $($AvailColumns.count)" "VERBOSE"
		
		#This part we resolve ?ColumnName in key names.
		Log "		Determining columns for keys names and key values" "VERBOSE"
		$AvailColumns | %{
			$ColumnName = $_.trim();
			$ColumnName = $ColumnName.trim();
			$r = @($query)[0].$ColumnName;
			if($realKeyName -like "*[?]$ColumnName*"){
				Log "			Column [$ColumnName] is part of key" "VERBOSE"
				$ColumnsForKey += $ColumnName;
			} else {
				$ColumnsForData += $ColumnName;
			}
		}
			
		Log "		Looping through rows" "VERBOSE"
		foreach($row in $queryResults){		
			$realKeyName = $K.KEY;
			#Lets update columns mapping.
			Log "			Resolving key name" "VERBOSE"
			$ColumnsForKey | %{
				$ColumnName = $_;
				$r = $row.$ColumnName;
				
				if(!$r){$r = 0;}
				
				Log "				Replacing ?$ColumnName by $r " "VERBOSE"
				$realKeyName = $realKeyName.replace("?$ColumnName",$r);
			}
			Log "				Result: $realKeyName" "VERBOSE"
			
			Log "			Generating keys for each left column" "VERBOSE"
			$ColumnsForData | %{
				$ColumnName = $_;
				$r = $row.$ColumnName;		
				if(!$r){$r = 0;}
				$realKeyNameForData = $realKeyName.replace("?",$ColumnName);
				$DataForSend += "- $realKeyNameForData $r"
				Log "				Column: $ColumnName | Real Key: $realKeyNameForData Data: $r" "VERBOSE"			
			}
			
		}

	}
	
	$SenderParams = @(
		"-z ""$($INFO.ZABBIX.SERVER)"""
		"-p ""$($INFO.ZABBIX.PORT)"""
		"-s ""$($INFO.HOSTNAME)"""
		"-i ""-"""
		"-vv"
	)
	
	
	Log "	SENDER: $ZabbixSender PARAMS" "VERBOSE"
	$SenderParams | %{
		Log "		$_" "VERBOSE"
	}
	
	Log "	Sending data..." "VERBOSE"
	try{
		if($DataForSend){
			
			$FinalSenderScript = [scriptblock]::create('$BulkDataSend | & $ZabbixSender '+($SenderParams -join  " "));
			Log "	Final Sender Script: $FinalSenderScript" "VERBOSE"
			#logging info.
			$BulkDataSend = ($DataForSend -Join "`r`n");
			
			Log "		ITEMS TO BE SENT: $($DataForSend.count)" "VERBOSE"
			Log "		DATA THAT WILL BE SEND: `r`n$BulkDataSend" "VERBOSE"
			
			# Sending data to server
			Log "		Sending... Calling script: $FinalSenderScript" "VERBOSE"
			$ErrorActionPreference = "continue";
			$Response = & $FinalSenderScript 2>&1
			$ErrorActionPreference = "stop";
			
			
			# Getting time info for informational and debugging purposes.
			if($LastSend){
				$TimeElpased = ((Get-Date)-$LastSend).totalMilliseconds
				Log "Elapsed ms: $TimeElpased" "VERBOSE"
			}
			$LastSend		= (Get-Date)
		} else {
			throw "NO_DATA_FOR_SEND"
		}
	} catch {
		write-host "RESPONSE RESULT: " $_	
		$Response = $_;
	}
	
	#Command will returns something like this: 
	Log "	Server response: $Response" "VERBOSE"
	
	#This is object that we use to store all informaton about response and results.
	$Result = New-Object PSObject -Prop @{
									errors=@()
									ts=(Get-Date)
									answer = @() #This is the JSON deserialized from string above.
								};
	
	if($Response.count){
		$ResponsesWithAnswer = @($Response | where {$_ -match 'answer[^\[](.+)'})
		$Response = $Response -join "`r`n"
	}
	
	if(!$ResponsesWithAnswer){
		$Result.errors += "Invalid response. Some error ocurred: "+($Response -join "`r`n");
	}
	

	
	#Processing response. This is useful for check if all happens sucessfully.
	# The response from server must match this: answer [{"response":"success","info":"processed: N; failed: N; total: N; seconds spent: n.nnnn"}]
	
	foreach($Answer in $ResponsesWithAnswer)
	{			
		Log "	ANSWER LINE IS: $Answer" "VERBOSE"
	
		#Check if match for extract JSON part of response.
		$AnswerMatched = $Answer -match 'answer[^\[](.+)';
	
		if($AnswerMatched){
			$JSONResponse =  $Matches[1];
			
			try {
				$ResponseObject = $jsonParser.DeserializeObject($JSONResponse);
				$responseObject	= $ResponseObject[0];
			} catch {
				$Result.errors += "Error when parsing response JSON: $_";
			}

			if($ResponseObject){
				$Result.answer += $ResponseObject;
			}
		} else {
			$Result.errors += "Invalid response! Some error can be ocurred: $Response"
		}
	}
		
	if($Result.errors){
		Log "	RECEIVED RESPONSE ERRORS:" "PROGRESS"
		$Result.errors | %{
			Log "		$_" "PROGRESS"
		}
	} else {
		if($Result.answer){
			$Result.answer | %{
				if($_.response -eq "success"){
					Log "		 SUCCESS: $($_.info)" "VERBOSE"
				} else {
					Log "		NO SUCCESS: $_" "PROGRESS"
				}
			}
		} else {
			Log " No success on answer: $($Result.answer)" "PROGRESS"
		}
	}
	
	if($PoolingTime){
		Log "	Sleeping for $PoolingTime ms" "VERBOSE"
		Start-Sleep -Milliseconds $PoolingTime
	}
} while($PoolingTime)

Log "Script finished sucessfully. Adjust log level for more messages."

<#
	.SYNOPSIS 
		Sends data queried from a instance to a Zabbix Server based on a configuration file.
		
		
	.DESCRIPTION
	
		The Send-Data2Zabbix is used to execute a SQL query and send results to a Zabbix Server.
		This allows create custom monitoring counters and items based on queries results.
		The script relies of zabbix_sender tool included in Zabbix product. 
		The items must be created as "Zabbix Trapper" to receive the values correctly.
		
		The script accepts a hashtable that define that keys and queries that will be generated to be send to zabbix server. We call this of "Keys Definition".
		For example, if you create a key called "powershell[Filecount]" on a Zabbix server called "ZABBIX" the Keys Definitions can match that one:
			
			@{
				"powershell[Filecount]" = { @(gci "C:\*.txt").count }
			}
			
		The keys files is just a simple powershell script that returns a hashtable. The hashtable have following format:
		
			"<Item>" = "<SCRIPT>"
		
		The parts are:
		
			<Item>
				The item name. This is same name as you configured on ZabbixServer.
				You can specify any string. The string must match the string configued on zabbix server.
				
				You can use special character "?". When script finds a "?" on item it can do some replaces on them.
				If you specify a "?" alone, the script will replace the "?" by the PROPERTY name returned by the object.
				For example, if a script returns a object with property called "FileCount" and item is "powershell[FileStats,?]", the key name will be "powershell[FileStats,FileCount]".
				If you specify a query that returns multiples columns, the script will duplicate the key, one for each column.
				For example, consider following key definition:
				
					"powershell.system[?]" = {  Get-Process "System" | select WorkingSet64,VirtualMemorySize  }
				
				The script will generate this keys to be send to zabbix:
				
					"powershell.volumes[WorkingSet64]" and "powershell.volumes[VirtualMemorySize]"
				
				Each key, will have the column value.
				Note that in this examples, we are scripts that returns a single object.
				For scripts that returns multiple rows, you must take some cautions. For example:
				
					"powershell.services[?]" =  "Get-Process | select WorkingSet64"
					
				The script above will returns multiple rows, causing the same item "powershell.services[WorkingSet64]" to be generated.
				This will cause error on script, because it prevent you create multiple items with same resolved name (the name after replacing "?")
				But, in most cases, you want generate multiple from rows. For this case, you can use a variant of "?" placecholder.
				If you specify "?" + a property name in the obect returned by script, it will replace this placeholder by column value.
				For example, consider this:
				
					"powershell.volume[?name,freeSpace]" = {Get-WMIObject Win32_Volume | select Name,FreeSpace}
					
				If the scripts returns 5 objects (one row for each), then five items keys will be generated. 
				The ?name placeholder will be replaced by value of name property. The item value will be value of FreeSpace property.
				Note that you can keep using "?" placeholder. Look at this:
				
					"powershell[?name,?]" = {Get-WMIObject Win32_Volume | select Name,FreeSpace,LastErrorCode}
					
				Suppose there are volumes "C:\" and "D:\". In this case, 4 keys will be generated. 
				For each object (each volume) the ?name will be replaced.
				Then, for each left column, the "?" will be replaced. The following keys will be generated:
				
					powershell[C:\,?]
					
				This allows you generate multiple items keys with single script.
				This is possible thanks to the way how scripts handle multiple objects and properties. The general rule is:
				
					For objects returned,
						Script first replace "? + PropertyName" placeholder for the value of "PropertyName" in current object and discard this property.
						For the other properties that returned, the script will duplicate the key, and replace "?" for the property name. The property value will be the key value.

				Then, when working with multiple objects, considering correctly use of "?" placeholders syntax for avoiding errors of duplicates keys.
				
				The key name specified dont have a specific format. For convenience use the standard in Zabbix documentation for key names.
				The replacement of placehdolers is just a search string,and dont need stay between "[]". For example "powershell.?name.?" is valid and can be replaced.
				Just, pay attention to the fact the generate key name here must match the key created for the target hostname in zabbix server.
				
				LOW LEVEL DISCOVERY MODE
				
					If you specify "LLD:" before key name, then the script will take the results and generate a Low Level Discovery JSON string.
					For example:
					
						"LLD:powershell.discoveryVolumes" = {Get-WMIObject Win32_Volume | select name}
						
					If the volumes returned are "C:\","D:\","K:\" and "K:\MyMountPoint"
					
						{"data":[{"{#NAME}":"C:\"},{"{#NAME}":"D:\"},{"{#NAME}":"K:\"},{"{#NAME}":"K:\MyMountPoint"}]}
						
					This value will be the value of "powershell.discoveryVolumes"
					Note that in this mode, the "?" syntax will do not work for the corresponding key.
					Check more about Low Level Discovery (LLD) at: https://www.zabbix.com/documentation/2.4/manual/discovery/low_level_discovery
				

			<script>
				This is the source SCRIPT. You can specify a SCRIPTBLOCK or filename.
				You can specify a full path to filename or just filename. For filenames only, $DirScripts is used as directory for file.
				For specify a scriptblock, just write script between the symbols "{" and "}". Dont use quotes, because scripts will guess the its a filename.
				The script must return a valid PSObject array.
				IF none array of PSObject is returned, then the script will convert it to a internal psobject. The property name is randomically generated.
				We dont guarantees the name used, and this can cause different results when used with placeholders.
		
	.EXAMPLE
	
		In this example, we defne a key called "mssql.query[Stats,AvgCPU]". This key must exists on zabbix server as same name for the host.
		This key will be populated with average elapsed time of all queries running on the instance.
		Note that the host name used will be "MyServer MyInst", then the host with this name must be created.
		
		The Keys Definitions is C:\temp\Example1.keys.ps1:
			@{
				"mssq.query[Stats,AvgCpu]" = "SELECT AVG(total_elapsed_time) FROM sys.dm_exec_requests R WHERE R.session_id > 40"
			}
			
		PS C:\> Send-Data2Zabbix -Instance "MyServer\MyInst" -KeysDefinitions C:\temp\Example1.keys.ps1

	.EXAMPLE
	
		

		
	.NOTES
	
		This scripts was developed by Rodrigo Ribeiro Gomes.
		This scripts is free and always will be.
		http://scriptstore.thesqltimes.com/docs/custommssql/custommssql-cmdlets/send-data2zabbix/
		
		

#>
}