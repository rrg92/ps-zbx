Function Send-SQL2Zabbix {
	[CmdLetBinding(SupportsShouldProcess=$True)]
	param(
		#This is instance name! You can specify IP, ServerName\Instance, etc.
			[string]$Instance
		
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
			
		,#This allows specify custom values that can be accessed by scripts executed via keys.
		 #This is a member of hashtable passed as parameter to scripts of keys that are a powershell scriptblock.
		 #This member will be available on "USER.CUSTOM" member!
			$UserCustomData = $null
			
		,#Allows cache networks  keys files in a local path.
		 #If non empty, must be a path to a local path to cache keys retrivied from entwork.
		 #The keys taht starts with '\\server\' will be donwloaded.
		 #The script will donwload files only if modification date is later thant current file date.
		 #This check will be made in "ReloadTime" basis!
			$CacheFolder = $null
		
			
		,#This controls the logging.
		 #Specifies level between brackets. 
			$LogTo = "#"
		
		,#Specifies log level.
			$LogLevel = "DETAILED"
			
		,#Specifies app name to be used in sql
			$SQLAppName="SQL2ZABBIX"
			
		,#Enables script to no execute zabbixer sender tool. It just dump results...
		 #Used for debug purposes only.
			[switch]$NoSenderMode = $false
	)

$ErrorActionPreference = "stop";
	
#Global Values. USER must be used by user custom scripts...
	$VALUES = @{
				WIN_USERNAME			= [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
				COMPUTER_NAME			= $Env:ComputerName
				TEMP_FOLDER				= [System.IO.Path]::GetTempPath()
				ZABBIX_SENDER			= $null
				HOSTNAME				= $HostName
				ZABBIX					= @{SERVER=$null;PORT=$NULL}
				PARAMS					= (GetAllCmdLetParams)
				USER 					= @{INSTANCE_NAME=$Instance;CUSTOM=$UserCustomData}
				
				#Controls de cache!
				CACHE					= @{
											ENABLED = $false
											FOLDER 	= $NULL
											BASE_FODLER = $NULL
											DB = @{}
											DB_FILE = $null
											LOADED=$false;
											READY=$false
										}
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

	$NoWEX = $false;
	try {
		Add-Type -Assembly System.Web.Extensions
		$jsonParser = New-Object System.Web.Script.Serialization.JavascriptSerializer
	} catch {
		$NoWEX = $true;
		Log " System.Web.Extensions cannot be loaded. JSON operations will be made manually. Exception: $_";
	}
	
#Choosing a zabbix sender

	if(!$NoSenderMode){
		:FindPath foreach($SenderPath in @($ZabbixSender)){
			Log "Checking if zabbix sender path $SenderPath exists" 
			if([System.IO.File]::Exists($SenderPath)){
				Log "	Found! This will be used!"
				$VALUES.ZABBIX_SENDER = $SenderPath;
				break :FindPath;
			}
		}
		
		if(!$VALUES.ZABBIX_SENDER){
			Log "	No Zabbix Sender executable found!" 
			return;
		}
	}


#This part simply get hostname from a custom script if hostname isn't provided.
#Future implementation must alow user specify a custom script.

	$HostNameScript = {
			param($VALUES)
			$InstanceName = Invoke-NewQuery -ServerInstance $Instance -Query "SELECT @@SERVERNAME as FullServerName" -AppName $SQLAppName;
			$VALUES.HOSTNAME = $InstanceName.FullServerName.replace("\"," ");
			$VALUES.USER.INSTANCE_NAME = $InstanceName.FullServerName;
		}

		
	if(!$VALUES.HOSTNAME){
		Log "Getting hostname from custom script!"
	
		try {
			. $HostNameScript $VALUES
		} catch {
			Log "Error on custom script to determine hostname: $_" "PROGRESS";
		}
	}
	
	if(!$VALUES.HOSTNAME){
		Log "ERROR: Impossible determine zabbix hostname. Check if custom previous errors." "PROGRESS"
		throw "NO_HOSTNAME!"
	}
	
	$VALUES.HOSTNAME = $VALUES.HOSTNAME;
	Log "	HostName is: $($VALUES.HOSTNAME)"

	if($CacheFolder){
		
		Log " Caching enabled!"
		
		$SubFolder = $VALUES.HOSTNAME;
		@([IO.Path]::GetInvalidPathChars()) | %{
			$SubFolder = $SubFolder.replace($_.toString(),'');
		}
	
		$VALUES.CACHE.FOLDER 		= $CacheFolder + '\' + $SubFolder
		$VALUES.CACHE.BASE_FODLER 	= $CacheFolder
		$VALUES.CACHE.ENABLED  		= $true;
		
		#IF folder doenst not exits, creates a new one!
		if(![IO.Directory]::Exists($VALUES.CACHE.FOLDER )){
			$NewCacheFolder = mkdir $VALUES.CACHE.FOLDER -force;
		}
		
		#If db doents exists, create a new one!
		$DbFileName = $VALUES.CACHE.FOLDER + '\' + 'mapping.xml';
		$VALUES.CACHE.DB_FILE = $DBFileName;
		
		Log " 	Base folder: $($VALUES.CACHE.BASE_FODLER). Current Host folder: $($VALUES.CACHE.FOLDER)"
	}
	
	
#Lets interpret zabbix server info
	
	Log "Evaluating zabbix server and port"
	$ServerPort = $ZabbixServer -Split ":";
	$VALUES.ZABBIX.SERVER = $ServerPort[0];
	
	if($ServerPort[1]){
		$VALUES.ZABBIX.PORT = $ServerPort[1]
	} else {
		$VALUES.ZABBIX.PORT = 10051
	}
	
	Log "	Server is: $($VALUES.ZABBIX.SERVER) Port is: $($VALUES.ZABBIX.PORT)"
	
	
#This is all functions responsible for getting keys and determing which is sql source or powershell source...
	
	
	#Functions to manage local cache!
		Function UpdateLocalCacheFile {
		
			Log "Updating local cache file!!!!" "VERBOSE"
			
			try {
				$VALUES.CACHE.DB | Export-CliXML $VALUES.CACHE.DB_FILE
			} catch {
				throw 'UPDATE_LOCAL_CACHE_FILE_ERROR: $_';
			}
			
		}
		
		Function LoadLocalCacheFile {
			try {
				if(!$VALUES.CACHE.LOADED){
					if([IO.File]::Exists($VALUES.CACHE.DB_FILE)){
						Log "Loading cache database from $($VALUES.CACHE.DB_FILE)" "VERBOSE"
						$VALUES.CACHE.DB = Import-CliXML $VALUES.CACHE.DB_FILE
						$VALUES.CACHE.LOADED=$true;
					}
				}
			} catch {
				throw "LOAD_LOCAL_CACHE_FILE_ERROR: $_";
			}
			
		}
	
		Function SetupLocalCache {
	
			if($VALUES.CACHE.READY){
				return;
			}
	
			Log "Setting up local cache" "VERBOSE"
	
			#Loads database from file!
			LoadLocalCacheFile
			
			$LocalCacheDB = $VALUES.CACHE.DB;

			#Maps network file to a local file!
			if(!$LocalCacheDB.Contains("FILE_MAP")){
				$LocalCacheDB.add("FILE_MAP",@{});
			}
			
			$VALUES.CACHE.READY = $true;
		}
	
		Function GetNewFileCacheName {
			param($RemoteName)
			
			[string]$NewFileGuid =  ([Guid]::NewGuid()).Guid.replace('-','');
			$FileExt = [Io.Path]::GetExtension($RemoteName);
			$BaseName = [Io.Path]::GetFileNameWithoutExtension($RemoteName);
			$FileName = $BaseName +'.'+$NewFileGuid.replace("-","") + $FileExt;
			return $Filename;
		}
	
		Function GetFileCachePath {
			param($FileName)
			
				$FileExt =  [Io.Path]::GetExtension($FileName);
				$BaseFileTypeDir =  $VALUES.CACHE.FOLDER +'\'+ $FileExt.replace('.','');
				
				if(![Io.Directory]::Exists($BaseFileTypeDir)){
					$NewBaseDirr = mkdir $BaseFileTypeDir -force;
				}
				
				$FullLocalPath = $BaseFileTypeDir +'\'+ $FileName;
				return $FullLocalPath;
		}
	
		Function GetFileFromCache {
			param([string]$RemoteName)
			
			#If cache is enabled and file is a remote...
			if($VALUES.CACHE.ENABLED){
				$FileURI = New-Object Uri($RemoteName);
				if(!$FileURI.IsUnc){
					return $RemoteName;
				}
			} else {
				return $RemoteName;
			}
			
			SetupLocalCache;
			
			$FileMap = $VALUES.CACHE.DB.FILE_MAP;
			$CacheFilePath = $null;
			
			#Search file name in mapping...
			if($FileMap.Contains($RemoteName)){
				#Check if file needs be updated!
				$CacheEntry = $FileMap[$RemoteName];
				$FullLocalPath = GetFileCachePath  $CacheEntry.FileName 

				Log "Remote $RemoteName cached: $($FullLocalPath) lastDownloadTime: $($CacheEntry.LastDownloadTime)" "VERBOSE"
				
				if(![Io.File]::Exists($FullLocalPath)){
					try {
						Log "CacheManager: The local path $FullLocalPath (original: $( $RemoteName)) was not found. Trying re-copy!" "DETAILED";
						copy -Path $RemoteName -Destination $FullLocalPath -force;
						$CacheEntry.LastDownloadTime = (Get-Date);
						UpdateLocalCacheFile;
						Log "Sucess!" "DETAILED"
					} catch {
						Log "	Cannot recopy! Error: $_" "DETAILED";
						return $null;
					}
				}
				
				try {
					$RemoteFile = Get-Item $RemoteName;
					
					Log "Remote last modification time: $($RemoteFile.LastWriteTime)" "VERBOSE"
					
					if($RemoteFile.LastWriteTime -ge $CacheEntry.LastDownloadTime){
						Log "Updating local copy!" "VERBOSE"
						copy -Path $RemoteName -Destination $FullLocalPath -force;
						$CacheEntry.LastDownloadTime = (Get-Date);
						UpdateLocalCacheFile
					}
				} catch {
					Log "	Cannot make update check process on remote file $RemoteName. Error: $_" "DETAILED"
				}

				$CacheFilePath = $FullLocalPath
			} else {
				#Generate a new file name!
				$NewFileName = GetNewFileCacheName $RemoteName;
				$FullLocalPath = GetFileCachePath $NewFileName 
				
				Log "Remote $RemoteName not cached: creating a new on $FullLocalPath" "VERBOSE"
				
				#Copy remote file to filename!
				try {
					copy -Path $RemoteName -Destination $FullLocalPath -force;
					$FileMap.add($RemoteName,@{FileName=$NewFileName; LastDownloadTime=(Get-Date)});
					UpdateLocalCacheFile
				} catch {
					Log "	Cannot cache $RemoteName into $FileName. Error: $_" "DETAILED"
					return $null;
				}

				$CacheFilePath = $FullLocalPath
			}
			
			Log "Remote file $($RemoteName) will be $FullLocalPath" "VERBOSE"
			return $CacheFilePath;
		}
		
	
	#This function just expand keys definitions.
	#For example, if user pass a file, this function will execute the file in order to get hashtable with the keys!
	Function UpdateKeysForGet {
		param($KeysDefinitions, $Logging = "VERBOSE")
		
		$AllKeysDefintions = @{};
		
		foreach($KeyDef in $KeysDefinitions){
			
			if($KeyDef -is [string]){
				$KeyDef = GetFileFromCache $KeyDef;

				if(![System.IO.File]::Exists($KeyDef)){
					throw "INVALID_KEY_DEFINITIONS: FileNotExists $KeyDef";
				}
				
				Log "Getting keys definitions from FILE $KeyDef" $Logging
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
	
	#Thus function will resolve need keys for collect and associated execution engine (eg: sql script or powershell script block).
	Function UpdateKeysFinal {
		param($KeysForGet, $Logging = "VERBOSE")
		
		$AllKeysFinal = @()
		
		:KeysForGet foreach($k in $KeysForGet.GetEnumerator()) {
			$KeyName 		= $k.Key;
			$KeySourceFull	= $k.Value;
			$KeySource		= @{}
			
			Log "	Key: $KeyName" $Logging
			
			$isLLD = $false;
			if($KeyName -like "LLD:*"){
				$KeyName = $KeyName -replace '^LLD:',''
				$isLLD = $true;
			}

			$SourceType = "SQL";
			
			if ($KeySourceFull -is [scriptblock]){ #If keys is a scriptblock
				$SourceType = "PS";
				$KeySource.add("SOURCE",$KeySourceFull);
				$KeySource.add("SCRIPT",$KeySourceFull);
				$KeySource.add("COLUMN",$null);
			} elseif($KeySourceFull -like "*::*"){ #If key source is a string and contains the columns...
				$KeySourceParts = $KeySourceFull -Split "::"
				$KeySource.add("COLUMN",$KeySourceParts[0] -Split ","); #Note that with this, commans dont ae accepted on name.
				$KeySource.add("SOURCE",$KeySourceParts[1].trim());
			} 
			else {
				$KeySource.add("COLUMN",$null); #If key source is a string and not contains the columns
				$KeySource.add("SOURCE",$KeySourceFull.trim());
			}
		
			#If ends with ".sql" and file exists.
			if($SourceType -eq "SQL"){
				if($KeySource.Source -like "*.sql"){
					
					#Replace macro <DIRSCRIPTS>
					$KeySource.Source = $KeySource.Source.replace('<DIRSCRIPTS>',$DirScripts);
					
					#If if dont have any bars...
					if($KeySource.Source -notmatch "[\\/]" ){
						$KeySource.Source  = $DirScripts +"\"+$KeySource.Source;
					}
					
					
					
					if([System.IO.File]::Exists($KeySource.SOURCE)){
						$KeySource.SOURCE = GetFileFromCache $KeySource.SOURCE;
						$KeySource.add("QUERY",((Get-Content $KeySource.SOURCE) -join "`r`n")); #Pre caches query in order to save time to read from disk each time.
					} else {	
						Log "Key $KeyName will ignored because specified file dont was found: $($KeySource.SOURCE)" $Logging
						continue :KeysForGet;
					}
				}
				else {
					#If not a file, then consider being a query.
					$KeySource.add("QUERY",$KeySource.SOURCE); 
				}
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
	
Log "User data: "
foreach($UserData in $VALUES.USER.GetEnumerator()){
	Log "$($UserData.Key): $($UserData.Value)" "PROGRESS"; 
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
	:KeysFinal foreach($k in $Keysfinal){
		$queryResults = $null;
		
		Log "		Executing source for key $($k.KEY)" "VERBOSE"
		try {
			if($k.SOURCE.TYPE -eq "SQL"){
				$queryResults = Invoke-NewQuery -ServerInstance $Instance -Query $k.SOURCE.QUERY -AppName $SQLAppName
			}
			elseif($k.SOURCE.TYPE -eq "PS") {
				$queryResults = @(& $k.SOURCE.SCRIPT $VALUES)
				if($queryResults.count -eq 1 -and  $queryResults[0] -ne $null -and $queryResults[0].getType().Name -ne "PSCustomObject"){
					$queryResults = New-Object PSObject -Prop @{ "__results" = $queryResults}
				}
			} else {
				throw "INVALID_SOURCE_TYPE: $($k.SOURCE.TYPE)"
			}
		} catch {
			$FormattedError = (FormatPSException $_)
			Log "			Error when executing query for key $($k.KEY): $FormattedError" "PROGRESS"
			continue :KeysFinal;
		}
		
		if(!$queryResults){
			Log "		Query dont return any result or meta-data!" "VERBOSE"
			continue :KeysFinal;
		}
		

		
		if($k.isLLD){
			Log "			This key is a LLD mode! Result query will be converted to a zabbix JSON LLD format." "VERBOSE"
			try {
				$r =  ConvertTo-ZabbixLLD $queryResults;
				$DataForSend += "- $($k.KEY) $r";
				continue :KeysFinal;
			} catch {
				Log "			Error when generating JSON for LLD KEY $($k.KEY): $_" "PROGRESS"
				continue :KeysFinal;
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
		"-z ""$($VALUES.ZABBIX.SERVER)"""
		"-p ""$($VALUES.ZABBIX.PORT)"""
		"-s ""$($VALUES.HOSTNAME)"""
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
			
			$FinalSenderScript = [scriptblock]::create('$BulkDataSend | & $($VALUES.ZABBIX_SENDER) '+($SenderParams -join  " "));
			Log "	Final Sender Script: $FinalSenderScript" "VERBOSE"
			#logging info.
			$BulkDataSend = ($DataForSend -Join "`r`n");
			
			Log "		ITEMS TO BE SENT: $($DataForSend.count)" "VERBOSE"
			Log "		DATA THAT WILL BE SEND: `r`n$BulkDataSend" "VERBOSE"
			
			# Sending data to server
			Log "		Sending... Calling script: $FinalSenderScript" "VERBOSE"
			
			if($NoSenderMode){
				write-host "NoSenderMode: $FinalSenderScript";
			} else {
				$ErrorActionPreference = "continue";
				$Response = & $FinalSenderScript 2>&1
				$ErrorActionPreference = "stop";
			}
			
			
			
			
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
				if($NoWex){
					#Manual convert response.
					#The $JSONResponse var will have somehting like this [{"response":"success","info":"processed: 3; failed: 0; total: 3; seconds spent: 0.036191"}]
					
					
					#Get response part!
					$regMatched = $JSONResponse -match '"response":"([^"]+)"'
					$resObj = New-Object PSObject -Prop @{response=$null;info=$null};
					
					if($regMatched){
						$resObj.response = $matches[1];
					}
					
					$regMatched = $JSONResponse -match '"info":"([^"]+)"'
					if($regMatched){
						$resObj.info = $matches[1];
					}
					
					$responseObject = $resObj;
				} else {
					$ResponseObject = $jsonParser.DeserializeObject($JSONResponse);
					$responseObject	= $ResponseObject[0];
				}
				
				
				
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
	
		The Send-SQL2Zabbix is used to execute a SQL query and send results to a Zabbix Server.
		This allows create custom monitoring counters and items based on queries results.
		The script relies of zabbix_sender tool included in Zabbix product. 
		The items must be created as "Zabbix Trapper" to receive the values correctly.
		
		The script accepts a hashtable that define that keys and queries that will be generated to be send to zabbix server. We call this of "Keys Definition".
		For example, if you create a key called "mssql.query[DatabaseCount]" on a Zabbix server called "ZABBIX" the Keys Definitions can match that one:
			
			@{
				"mssql.query[DatabaseCount]" = "SELECT COUNT(*) FROM sys.databases"
			}
			
		The keys files is just a simple powershell script that returns a hashtable. The hashtable have following format:
		
			"<Item>" = "<COLUMNS>::<SQL>"
			or
			"<Item>" = {SCRIPTBLOCK}
			
		This means that you can specify SQL scripts or powershell custom script blocks. The script must return a array of object.
		The script will access the "Noteproperty" members of eah object returned. In the case of SQL Scripts, the cmdlet will transform query results in a valid Object, where each row is a object and each column is a noteproperty of row.
		When you specify a "scriptblock" the cmdlet will call this scriptblock and pass as first parameter, a hashtable. The hash table will contain many values.
		Check section "THE GLOBAL VALUES HASHTABLE" for more information.
		
		The parts are:
		
			<Item>
				The item name. This is same name as you configured on ZabbixServer.
				You can specify any string. The string must match the string configued on zabbix server.
				
				You can use special character "?". When script finds a "?" on item it can do some replaces on them.
				If you specify a "?" alone, the script will replace the "?" by the property name returned.
				For example, if query returns a column called "PageCount" and item is "mssql.database[MyDb,?]", the key name will be "mssql.database[MyDB,PageCount]".
				If you specify a query that returns multiples columns, the script will duplicate the key, one for each column.
				For example, consider following key definition:
				
					"mssql.instanceInfo[?]" = "select cpu_count,scheduler_count from sys.dm_os_sys_info"
				
				The script will generate this keys to be send to zabbix:
				
					"mssql.instance[cpu_count]" and "mssql.instance[scheduler_count]"
				
				Each key, will have the column value.
				Note that in this examples, we are considering queries that returns a single row only.
				For queries that returns multiple rows, you must take some cautions. For example:
				
					"mssql.database[?]" =  "select state from sys.databases"
					
				The query above will returns multiple rows, causing the same item "mssql.database[state]" to be generated.
				This will cause error on script, because it prevent you create multiple items with same resolved name (the name after replacing "?")
				But, in most cases, you want generate multiple from rows. For this case, you can use a variant of "?" placecholder.
				If you specify "?" plus a 'property name' returned by script, the cmdlet will replace this placeholder by column value.
				For example, consider this:
				
					"mssq.database[?name,state]" = "select name,state from sys.databases"
					
				If the query returns 5 databases (one row for each), then five items will be generated. 
				The "?name" placeholder will be replaced by value of "name" column. The item value will be value of state column.
				NOTE: Remeber that cmdlet will transform rows in objects, and columns in "noteproperty" for each object, respectively.
				Note that you can keep using "?" placeholder. Look at this:
				
					"mssql.database[?name,?]" = "select name,state,is_read_only from sys.databases"
					
				In this case, 10 items will be generated. For each row (database) the ?name will be replaced.
				Then, for each left column, the "?" will be replaced. In this case, if databases are "master","model","tempdb","msdb"and "MyDB", the following items will be generated:
				
					mssql.database[master,state]
					mssql.database[master,is_read_only]
					mssql.database[model,state]
					mssql.database[model,is_read_only]
					mssql.database[tempdb,state]
					mssql.database[tempdb,is_read_only]
					mssql.database[msdb,state]
					mssql.database[msdb,is_read_only]
					mssql.database[MyDB,state]
					mssql.database[MyDB,is_read_only]
					
				This allows you generate multiple items keys with single script, or, for example,in best words, single connection to the database. This can save resources.
				This is possible thanks to the way how scripts handle multiple rows and columns. The general algorithm is:
				
					For each object returned,
						First replace "? + PropertyName" placeholder by the value of "PropertyName" in current object and discard this property.
						For the other properties that was returned, the script will duplicate item, and replace "?" for the property name. The property value will be the key value.

				Then, when working with multiple objects and properties, considering correctly use of "?" placeholders syntax for avoiding errors of duplicates keys.
				
				The key name specified dont have a specific format. For convenience, use names like "mssql." or "sql.", following zabbix standards.
				The replacement of placehdolers just search string, and don't require that it be between "[]". For example "mssql.?name.?" is valid and can be replaced.
				Just, pay attention to the fact the generate key name here must match the key created for the target hostname in zabbix server.
				
				LOW LEVEL DISCOVERY MODE
				
					If you specify "LLD:" at begining of item name, then the script will take the query results and generate a Low Level Discovery JSON string.
					The script just will get returned array object and represent it into a JSON format.
					For example:
					
						"LLD:mssql.discoveryDatabases" = "SELECT name FROM sys.databases"
						
					If the databases returned are "master","model","tempdb","msdb", then this JSON will be generated:
					
						{"data":[{"{#NAME}":"master"},{"{#NAME}":"model"},{"{#NAME}":"tempdb"},{"{#NAME}":"msdb"}]}
						
					This value will be the value of "mssql.discoveryDatabases"
					Note that in this mode, the "?" syntax will do not work for the corresponding key.
					The cmdlet will cmdlet will change the case of properties names to UPPER, because this is required by LLD.
					Check more about Low Level Discovery (LLD) at: https://www.zabbix.com/documentation/2.4/manual/discovery/low_level_discovery
				
			<COLUMNS>
				This is the optional column list where the data come from. You can specify multiple columns separated by ",".
				This is useful for use with stored procedures, where you can select just columns that you want work.
				If you specify this column list is same as the script return just this choosed columns, and replacemnts will not consider another columns.
				
			<SQL>
				This is the source query. You can specify a TSQL code or filename.
				If you want specify filename, you must use ".sql" extensions. For example, "DatabaseCount.sql".
				You can specify a full path to filename or just filename. For filenames only, $DirScripts parameter is used as directory for file.
				You can enforce use of $DirScript by specifying "<DIRSCRIPTS>" macro. This will cause the script replace by $DirScript values.
				For specify query, just write query. For example: "SELECT COUNT(*) FROM sys.dm_exec_requests R"
				If you specify querie without name the columns, then the current provider used to connect with SQL can rename columns.
				We dont guarantees the name used, and this can cause different results when used with placeholders.
		
		THE GLOBAL VALUES HASHTABLE
		
			This cmdlet provides a special hashtable called "VALUES" that contains a lot of useful data.
			The data can be about the script itself or custom data passed to user.
			This hashtable is oassed in most part os code to code of user, for it can use in own scripts.
			The keys of the hashtable can be changed according the version. Allways check this part in each release:
			
				WIN_USERNAME
					Contains username of user that called the script
				COMPUTER_NAME
					Contains the computer name from script was called.
				TEMP_FOLDER
					Contains temporary folder used by script instance. Can change in ech execution
				ZABBIX_SENDER
					Contains the path to the zabbix_sender.exe used by script. Can change in each execution.
				HOSTNAME
					Hostname for which the data will be sent
				ZABBIX
					Is a hashtable containing zabbix server connection info. Keys are: 
						SERVER	= The server adddress (IP ou DNS Name)
						PORT	= Port number
				PARAMS
					Is a hashtable where each key is the parameter of script. Check script parameter to know which parameters will available.
				USER
					Hashtable containing custom user data. This data is not pertinent to script and can be changed by the user scripts.
					The folloing keys are created by default:
						INSTANCE_NAME = Contains the instance name for which the script will connect to execute SQL scripts.
						CUSTOM = Contains data passed on parameter $UserCustomData
		
	.EXAMPLE
	
		In this example, we defne a key called "mssql.query[Stats,AvgCPU]". This key must exists on zabbix server as same name for the host.
		This key will be populated with average elapsed time of all queries running on the instance.
		Note that the host name used will be "MyServer MyInst", then the host with this name must be created.
		
		The Keys Definitions is C:\temp\Example1.keys.ps1:
			@{
				"mssq.query[Stats,AvgCpu]" = "SELECT AVG(total_elapsed_time) FROM sys.dm_exec_requests R WHERE R.session_id > 40"
			}
			
		PS C:\> Send-SQL2Zabbix -Instance "MyServer\MyInst" -KeysDefinitions C:\temp\Example1.keys.ps1

	.EXAMPLE
	
		In this example, we define a key using "?" special character. 
		In the zabbix server, there are two keys: mssql.query[Stats,AvgTime] and mssql.query[Stats,AvgCPU].
		
		The Keys Definitions is C:\temp\Example1.keys.ps1:
			@{
				"mssq.query[Stats,?]" = "SELECT AVG(total_elapsed_time),AVG(cpu_time) FROM sys.dm_exec_requests R WHERE R.session_id > 50"
			}
			
		PS C:\> Send-SQL2Zabbix -Instance "MyServer\MyInst" -KeysDefinition C:\temp\Example1.keys.ps1
		
	.EXAMPLE 
	
		In this example will show how you can specify Keys Definitions hashtable type.
		
		
		
		PS C:\> Send-SQL2Zabbix -Instance "MyServer\MyInst" -KeysDefinition @{"mssql.instance[?]" = "select * from sys.dm_os_sys_info"}
		
		
		
	.EXAMPLE 
	
		In this example, we use the column placeholder.
		In this example, we will have to many keys defined on server with format mssql.database[name,prop].
		The name in the key is the database name and prop is a prop from sys.databases.
		
		
		PS C:\> Send-SQL2Zabbix -Instance "MyServer\MyInst" -KeysDefinition @{"mssql.database[?DBName,?]" = "select name as DBName,state from sys.databases"}
		

		
	.NOTES
	
		This scripts was developed by Rodrigo Ribeiro Gomes.
		This scripts is free and always will be.
		http://scriptstore.thesqltimes.com/docs/custommssql/custommssql-cmdlets/send-sql2zabbix/
		
		

#>
}