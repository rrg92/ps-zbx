<#
	Log allow you use logging facilities in your scripts.
	This is standard logging script for use across CustomMSSQL module.
	It is implemented basically by GetLogObject functions, that returns a object for use its features.
	
	For help about this functions, check about_LoggingCustomMSSQL help.
#>

Function GetLogObject {
	param([switch]$GetLogLevels = $false)

	#Log levels allowed on the script.

	if($GetLogLevels){
		return GetLogLevels;
	}
	
	$PublicProperties = @{
		LogLevel = 2
		LogTo = @("#")
		UseDLD=$true #Try discover message level based on characters
		DLDScript=$null #Try discover message level based on characters
		ExternalVerboseMode=$false
		RandomFileNamePrefix="Log"
		OutBuffer = @()
		BufferIsHost=$false
		IgnoreLogFail=$true

		#Contains internal data must be not modified by user.
		internal=@{
					START_TS=(Get-Date)
					RANDOM_LOG_FILE=$null
					DESTINATON_HANDLERS=(GetLogDestinationsHandlers);
					FILE_INITIALIZED=$false
					RETAINING=$FALSE
					RETAINED_LOG_PACKETS=@()
				} 
	}

	$o = New-Object PsObject -Prop $PublicProperties
	
	#METHODS
	
		#This is a deprecitated. Use LogEx instead.
		$LogMethod = [scriptblock]::create({
			param($message,$Level = $null,$forceNoBuffer=$false,$fcolor=$null,$bcolor=$null,$options = @{})
			
			return $this.LogEx(@{
					message = $Message
					level = $LEVEL
					forceNoBuffer = $forceNoBuffer
					fcolor = $fcolor
					bcolor = $bcolor
					options = $options
				})
		})

		$LogMethodEx = [scriptblock]::create({
			param($Options = @{})
			
			try {
				$DestinationHandlers = $this.internal.DESTINATON_HANDLERS;
				$LOG_LEVELS = GetLogLevels
				$LogPacket = (NewLogPacket -LogObject $this -message $Options.message -ts (Get-Date) -level $Options.Level)
				$LogPacket.forceNoBuffer = $Options.forceNoBuffer;
				$LogPacket.style.BackgroundColor = $Option.bcolor
				$LogPacket.style.ForegroundColor = $Option.fcolor
				
				if($options.retain -ne $null){
					$LogPacket.retain = $options.retain;
				}
				
				if($options.flush -ne $null){
					$LogPacket.flush = $options.flush;
				}
				
				#Determining current level, if not already determined.
				if(!$LogPacket.level){
					$LogPacket.level = "PROGRESS"  #Default...
	
					if($this.UseDLD){		
						$DDLScriptToUse = $this.DLDScript
						if(!$DDLScriptToUse){
							$DDLScriptToUse = {param($LogPacket) (DefaultDDLScript $LogPacket) }
						}
						
						$LogPacket.level = & $DDLScriptToUse $LogPacket
						
						if(!(ValidateLogLevel $LogPacket.level)){
							$LogPacket.level = "PROGRESS"
						}
					}
				}
				

				#At this point we can determine if loggin must be out...
				
				# if this code running under Verbose powershell mode, use a verbose to handler to write output...
					#This will no check requested level vs current level because verbose mode assume any logging must be out...
 				if( $this.IsInVerbose() ){
					& $DestinationHandlers.VERBOSE $LogPacket;
				}
				

				#If this packet was logged with retention option...
				if($LogPacket.retain){
					$this.internal.RETAINING=$true;
				} 

				#If flush was specifified. Note flush have priority over retain...
				if($LogPacket.flush)  {
					$this.internal.RETAINING=$false;
					$LogPacket.flushedPackets = $this.internal.RETAINED_LOG_PACKETS;
					$this.internal.RETAINED_LOG_PACKETS = @();
				}

				#Check destinations...

				if( (GetLogLevelNumber($LogPacket.level)) -le (GetLogLevelNumber($this.LogLevel)) )  { #If actual level <= required level.
				
					if($this.internal.RETAINING){
						$this.internal.RETAINED_LOG_PACKETS += $LogPacket;
						return;
					}
					
					foreach($LogDestination in $this.LogTo) {
					
						if($LogDestination -is [scriptblock]){
							& $DestinationHandlers.SCRIPTBLOCK $LogPacket $LogDestination;
							continue;
						}
						
						if($LogDestination -eq "#"){
							$BufferIsHost = $this.BufferIsHost;
							
							if($LogPacket.forceNoBuffer){ #if user wants force buffer...
								$BufferIsHost = $false;
							}
							
						
							if(!$BufferIsHost){
								& $DestinationHandlers.HOST $LogPacket $LogDestination;
							}
							
							continue;
						}
						
						if($LogDestination -eq "#SQLAGENT"){
							& $DestinationHandlers.SQLAGENT $LogPacket $LogDestination;
							continue;
						}
						
						if($LogDestination -eq "#BUFFER"){
							if(!$LogPacket.forceNoBuffer){
								& $DestinationHandlers.BUFFER $LogPacket $LogDestination;
							}
							continue;
						}
						
						#Is a path...
						if(Test-Path $LogDestination){
							if(IsDirectory $LogDestination){
								& $DestinationHandlers.FOLDER $LogPacket $LogDestination;
								continue;
							}
						}
						
						#If nothing else, its considered a file...
						& $DestinationHandlers.FILE $LogPacket $LogDestination;
						
					}
				}
			} catch {
				if(!$this.IgnoreLogFail){
					throw;
				}
			}
		})

		
		$LogSQLErrors = [scriptblock]::create({
			param($exception,$level = "PROGRESS",$forceNoBuffer = $false)
			
			$ex = $exception;
			
			if($ex){
				if($ex.GetType().FullName -eq "System.Management.Automation.ErrorRecord"){
					$ex = $ex.Exception
				}
			}
			
			$message = FormatSQLErrors $ex
			$this.log($message ,$level,$forceNoBuffer,"Red",$null);
		})
		
		
		$InVerboseMode = [scriptblock]::create({
				$IsVerbose =  $false;
				if($PSCmdlet.MyInvocation.BoundParameters){
					if($PSCmdlet.MyInvocation.BoundParameters.Contains("Verbose")){
						$IsVerbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent
					}
				}
				
				if($this.ExternalVerboseMode){
					$IsVerbose = $true;
				}
				
				return $IsVerbose;
			}).GetNewClosure()
		
	$o | Add-Member -Type ScriptMethod -Name Log -Value  $LogMethod;
	$o | Add-Member -Type ScriptMethod -Name LogEx -Value  $LogMethodEx;
	$o | Add-Member -Type ScriptMethod -Name LogSQLErrors -Value  $LogSQLErrors;
	$o | Add-Member -Type ScriptMethod -Name isInVerbose -Value  $InVerboseMode

	return $o;
}

Function NewLogPacket {
	param($LogObject,$message = $null,$ts = $null,$level = $null,$custom =$null)
	
	if($Level){
		if(!(ValidateLogLevel $level)){
			$level = "PROGRESS";
		}
		
		$level = GetLogLevels -Specific $Level
	}
	
	$o = New-Object -Type PsObject -Prop @{
		message=$message
		ts=$ts
		level=$level
		alreadyScreened=$false
		custom=$custom
		IsInVerbose=$false
		LogObject=$LogObject
		buffered=$false
		forceNoBuffer=$false
		style=@{
				BackgroundColor=$null
				ForegroundColor=$null
			}
		retain=$false;
		flush=$false;
		flushedPackets=@()
	}
	
	$getSimpleMessageMethod = [scriptblock]::create({
		$tsString = $this.ts.toString("yyyy-MM-dd HH:mm:ss");
		$finalLogMessage = "$tsString "
		
		if($this.flushedPackets){
			$this.flushedPackets | %{
				$finalLogMessage += $_.message+"`r`n";
			}
		}

		$finalLogMessage += $this.message;
		
		return $finalLogMessage;
	})
	
	$getVerboseMessageMethod = [scriptblock]::create({
		$tsString = $this.ts.toString("yyyy-MM-dd HH:mm:ss");
		return "$tsString [$($this.level)] $($this.message)"
	})
	
	
	$o | Add-Member -Type ScriptMethod -Name getSimpleMessage -Value $getSimpleMessageMethod
	$o | Add-Member -Type ScriptMethod -Name getVerboseMessage -Value $getVerboseMessageMethod
	
	return $o;
}

Function GetLogLevels {
	param($Specific = $null)
	#The order which logs are created determine log level value.
	[hashtable]$LogLevels = @{}
	$OrderControl = 1;
	
	$LogLevels.add("PROGRESS",$OrderControl++) 	#Just main progress and errors
	$LogLevels.add("DETAILED",$OrderControl++)	#Detailed progressve
	$LogLevels.add("DEBUG",$OrderControl++)		#Show SQL Commands values
	$LogLevels.add("VERBOSE",$OrderControl++)	#All verbose
	
	if($Specific){
		if($Specific -is [int]){
			$s =  $LogLevels.GetEnumerator() | where {$_.Value -eq $Specific}
			return $s.Key;
		} 
		
		elseif($Specific -is [string]) {
			if(ValidateLogLevel $Specific){
				return $Specific
			} else {
				return $null;
			}
		}
	}
	
	return $LogLevels;
}

Function GetLogLevelNumber {
	param($LogLevelName)
	
	if($LogLevelName -is [int]){
		return $this.LogLevel;
	}
	

	$LOG_LEVELS = (GetLogLevels)
	
	return ($LOG_LEVELS.Item($LogLevelName) -as [int])
}

Function ValidateLogLevel{
	param($LogLevel)
	
	$LOG_LEVELS = GetLogLevels
	
	
	if($LogLevel -is [int]){
		return $LOG_LEVELS.ContainsValue($LogLevel);
	}
	
	if($LogLevel -is [string]){
		return $LOG_LEVELS.Contains($LogLevel)
	}
	
}

Function DefaultDDLScript {
	param($LogPacket)

	if(!$LogPacket){
		return $null;
	} 
	
	$LogPacket.level = "PROGRESS";
	
	if(!$LogPacket.message){
		return $LogPacket.level;
	} 
	
	if($LogPacket.message -match "^.+Command:.*"){#If string starts with "* Command:" string
		return "DEBUG";
	}

	if($LogPacket.message.toCharArray()[0] -eq "`t"){#If first character is a table, then set message to detailed progresss...
		return "DETAILED";
	}
	

	return $LogPacket.level;
}

Function GetLogDestinationsHandlers {

	return @{
		VERBOSE = {
			param($LogPacket,$Destination = $null)

			if($LogPacket.LogObject.IsInVerbose()){
				$LogPacket.alreadyScreened = $true;
			}
			
			write-verbose ($LogPacket.getVerboseMessage());
		}
	
		HOST = {
			param($LogPacket,$Destination = $null)
			
			if($LogPacket.alreadyScreened) {
				return;
			}
			
			$LogPacket.alreadyScreened = $true;
			
			$CmdLetParams = @{
				Object = $LogPacket.getSimpleMessage()
			}
			
			if($LogPacket.style.BackgroundColor){
				$CmdLetParams.add("BackgroundColor",$LogPacket.style.BackgroundColor)
			}
			
			if($LogPacket.style.ForegroundColor){
				$CmdLetParams.add("ForegroundColor",$LogPacket.style.ForegroundColor)
			}
			
			write-host @CmdLetParams;
		}

		FILE = {
			param($LogPacket,$Destination)
			
			$Destination | %{
				if(!$LogPacket.LogObject.internal.FILE_INITIALIZED){
					try {
						echo "" > $_;
						$LogPacket.LogObject.internal.FILE_INITIALIZED = $true;		
					} catch {
						$LogPacket.LogObject.internal.FILE_INITIALIZED = $false;
						return;
					}
				}
	
				$LogPacket.getSimpleMessage() >> $_
			}
		}
		
		SCRIPTBLOCK = {
			param($LogPacket,$Destination)
			
			& $Destination $LogPacket
		}
		
		SQLAGENT = {
			param($LogPacket, $Destination = $null)
			write-output $LogPacket.getSimpleMessage();
		}
		
		FOLDER = {
			param($LogPacket, $Destination = $null)
			
			if($LogPacket.LogObject.internal.Contains("RANDOM_LOG_FILE")){
				$RandomLogFile = $LogPacket.LogObject.internal.RANDOM_LOG_FILE;
			} else {
				$LogPacket.LogObject.internal.add("RANDOM_LOG_FILE",$RandomLogFile);
			}

			if(!$RandomLogFile){
				$ts = $LogPacket.LogObject.internal.START_TS.toString("yyyyMMddHHmmss")
				$prefix = $LogPacket.LogObject.RandomFileSuffix;
				if(!$prefix){
					$prefix = "LOG"
				}
				$RandomLogFile = (PutFolderSlash $Destination)+"$prefix.$ts.log"
				$LogPacket.LogObject.internal.RANDOM_LOG_FILE = $RandomLogFile;
			}
			
			
			$LogPacket.getSimpleMessage() >> $RandomLogFile;
		}

		BUFFER = {
				param($LogPacket,$Destination = $null)
				
				$LogPacket.LogObject.OutBuffer += @($LogPacket.getSimpleMessage())
				$LogPacket.buffered = $true;
			}
	
	
	}

}