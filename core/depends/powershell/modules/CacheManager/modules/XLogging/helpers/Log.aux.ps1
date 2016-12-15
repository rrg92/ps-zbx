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
		HConfigs = @{} #Specific configurations specific for each handler. This configurations overrides global.
		IdentString = "`t" #Controls the character used for identiation.
		
		#Contains internal data must be not modified by user.
		internal=@{
					START_TS=(Get-Date)
					RANDOM_LOG_FILE=$null
					DESTINATON_HANDLERS=(GetLogDestinationsHandlers);
					FILE_INITIALIZED=$false
					RETAINING=$FALSE
					RETAINED_LOG_PACKETS=@()
					IDENT_CONTROL = @{
							CURRENT_LEVEL=0
							SCHEDULED_LEVEL=$null
							IDENT_MARKS=@{} #Used to track marks
						}
					METHODS = @{};
				} 
	}

	$o = New-Object PsObject -Prop $PublicProperties
	
	#INTERNAL METHODS
		
		$o.internal.METHODS = @{
		
			CalculateIdentation = [scriptblock]::create({
				param($LogPacket, $Options)
				
				$LogObject = $LogPacket.LogObject;
				#Calculating identiation
				if($LogObject.internal.IDENT_CONTROL.SCHEDULED_LEVEL -and !$Options.identKeepFlow){
					if(!$Options.identSkipSched){
						$LogObject.setIdentLevel($LogObject.internal.IDENT_CONTROL.SCHEDULED_LEVEL);
					}
					
					$LogObject.internal.IDENT_CONTROL.SCHEDULED_LEVEL = $null;
				}
				
				$finalIdentLevel 	= $LogObject.getIdentLevel();
				$finalIdentString	= $LogObject.identString;
				

				#If user wants reset the level!
				if($Options.identReset){
					$finalIdentLevel 	= $LogObject.getIdentLevel();
					$finalIdentString	= $LogObject.identString;
					
					if($LogObject.internal.IDENT_CONTROL.IDENT_MARKS.Contains($Options.identReset)){
						$LevelToRestore = $Options.identReset
						$finalIdentLevel = $LogObject.internal.IDENT_CONTROL.IDENT_MARKS.$LevelToRestore
						
						if(!$Options.identKeepLevel){
							$LogObject.internal.IDENT_CONTROL.IDENT_MARKS.remove($LevelToRestore);
						} else {
							$finalIdentString = "(IDENTATION_ERROR_RESET_DONTEXISTS: $LevelToRestore already not exists)"
							$finalIdentLevel  = 1;
						}
					}
				}
				
				#If user wants drops the level.
				if($Options.identDrop){
					$LogObject.dropIdent($Options.identDrop,$finalIdentLevel)
					#The dropIdent method updates current level...
					$finalIdentLevel = $LogObject.getIdentLevel();
				}
				
				#If user wants raise the level. Note that if a drop was specified, the level after the drop will be used.
				if($Options.identRaise){
					if($Options.identApplyThis){
						$finalIdentLevel += $Options.identRaise;
						if(!$Options.identKeepFlow){
							$LogObject.setIdentLevel($finalIdentLevel);
						}
					} else {
						$LogObject.internal.IDENT_CONTROL.SCHEDULED_LEVEL  = $finalIdentLevel + $Options.identRaise;
					}
				}
				


				#If user specifies a level, then apply it. This override all previous calculates levels.
				if($Options.identLevel -ge 0){
					$finalIdentLevel = $Options.identLevel;
					$LogObject.setIdentLevel($finalIdentLevel);
				}
				
				#If user want save the level.
				if($Options.identSave){
					$IdentToSave = $Options.identSave;
					if($IdentToSave -and $LogObject.internal.IDENT_CONTROL.IDENT_MARKS.Contains($IdentToSave)){
						$finalIdentString = "(IDENTATION_ERROR_SAVING_EXISTS: $IdentToSave already exists)"
						$finalIdentLevel  = 1;
					} else {
						$LevelToSave = $LogObject.getIdentLevel();
						$LogObject.internal.IDENT_CONTROL.IDENT_MARKS.add($IdentToSave,$LevelToSave);
					}
				}
				
				$LogPacket.identString=$finalIdentString;
				$LogPacket.identLevel=$finalIdentLevel;
			})
		
			ConfigureLogPacket = [scriptblock]::create({
				param($LogObject, $Options)
				
				$LogPacket = (NewLogPacket -LogObject $LogObject -message $Options.message -ts (Get-Date) -level $Options.Level);
				$LogPacket.forceNoBuffer = $Options.forceNoBuffer;
				$LogPacket.style.BackgroundColor = $Options.bcolor;
				$LogPacket.style.ForegroundColor = $Options.fcolor
				
				#Call configure identition...
				& $LogObject.internal.METHODS.CalculateIdentation -LogPacket $LogPacket -Options $Options;
				
				if($options.retain -ne $null){
					$LogPacket.retain = $options.retain;
				}
				
				if($options.flush -ne $null){
					$LogPacket.flush = $options.flush;
				}
				
				if($Options.noUseTimestamp){
					$LogPacket.noUseTimestamp = $true;
				}
				
				#Determining current level, if not already determined.
				if(!$LogPacket.level){
					$LogPacket.level = "PROGRESS"  #Default...
	
					if($LogObject.UseDLD){		
						$DDLScriptToUse = $LogObject.DLDScript
						if(!$DDLScriptToUse){
							$DDLScriptToUse = {param($LogPacket) (DefaultDDLScript $LogPacket) }
						}
						
						$LogPacket.level = & $DDLScriptToUse $LogPacket
						
						if(!(ValidateLogLevel $LogPacket.level)){
							$LogPacket.level = "PROGRESS"
						}
					}
				}
				
				return $LogPacket;
			})
	
		}
		
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
				} + $options)
		})

		$LogMethodEx = [scriptblock]::create({
			param($Options = @{})
			
			<#
				All log methods Options:
					message 		- The message to be logged
					Level 			- The message level
					forceNoBuffer 	- Forces message not to be bufferized, when buffering is enabled.
					bcolor 			- Background color. Useful with destination that accept formating.
					fcolor 			- Foreground color. Useful with destination that accept formating.
					reatain 		- Retain message up to a flush.
					flush 			- Force all reatined messages to be flushed.
					identRaise 		- Raises the ident a specific level.
					identDrop		- Drops ident a specific level number
					identSave		- Save current level to internal level store.
					identReset		- Restore a saved level and drops by default.
					identKeepLevel	- Indicates that level must be maintaned when reseted.
					identLevel		- Sets the ident levelt o this value.
					identSkipSched	- Ignore any scheduled value.	
					identApplyThis	- Apply ident operation just on current log packet.
					identKeepFlow	- Dont change flow for next packets. Useful only with applyThis.
					blankLine		- write a blank line to the log. All other params will ignored.
					noUseTimestamp	- dont put a timestamp on final message.
			#>
			
			try {
				$DestinationHandlers = $this.internal.DESTINATON_HANDLERS;
				$LOG_LEVELS = GetLogLevels

				
				$LogPacket = & $this.internal.METHODS.ConfigureLogPacket -LogObject $this -Options $Options;

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

				if( $this.canLog($LogPacket.level) )  { #If actual level <= required level.
				
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
				
				if($this.ExternalVerboseMode -or ($VerbosePreference -and $VerbosePreference -ne "SilentlyContinue")){
					$IsVerbose = $true;
				}
				
				return $IsVerbose;
			}).GetNewClosure()
			
			
		#Test if log object can log on specific log level...
		#It is useful for the user execute some codes only if a specific log level is active...
		$canLog = [scriptblock]::create({
				param($LogLevel)
		
				#If desired level <= max level, then return true.
				$can = (GetLogLevelNumber($LogLevel)) -le (GetLogLevelNumber($this.LogLevel))
				return $can;
			})
			
		
		#Drops current identation by specific number of times.
		#This is useful for drop identation without a logging a message. Useful in loops.
		$DropIdentMethod = [scriptblock]::create({
				param([int]$DropCount = 1, $finalIdentLevel = $null)
		
				if(!$finalIdentLevel){
					$finalIdentLevel = $LogObject.internal.IDENT_CONTROL.CURRENT_LEVEL;
				}
		
				$finalIdentLevel -= $DropCount;
				$this.internal.IDENT_CONTROL.CURRENT_LEVEL = $finalIdentLevel;
				return;
			})
			
		#Gets current identation level.
		$GetIdentMethod = 	[scriptblock]::create({
				return $this.internal.IDENT_CONTROL.CURRENT_LEVEL;
			})
		
		#Set current ident level to a specified in param.
		$SetIdentMethod = 	[scriptblock]::create({
				param($Level)
				
				if($Level -ge 0){
					$this.internal.IDENT_CONTROL.CURRENT_LEVEL = $Level;
				}
				
			})
		
			
	$o | Add-Member -Type ScriptMethod -Name Log -Value  $LogMethod;
	$o | Add-Member -Type ScriptMethod -Name LogEx -Value  $LogMethodEx;
	$o | Add-Member -Type ScriptMethod -Name LogSQLErrors -Value  $LogSQLErrors;
	$o | Add-Member -Type ScriptMethod -Name isInVerbose -Value  $InVerboseMode
	$o | Add-Member -Type ScriptMethod -Name canLog -Value  $canLog
	$o | Add-Member -Type ScriptMethod -Name dropIdent -Value  $DropIdentMethod
	$o | Add-Member -Type ScriptMethod -Name getIdentLevel -Value  $GetIdentMethod
	$o | Add-Member -Type ScriptMethod -Name setIdentLevel -Value  $SetIdentMethod

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
		identLevel=0;
		identString=$null;
		noUseTimestamp=$false
	}
		
	$getSimpleMessageMethod = [scriptblock]::create({
		
		if($this.noUseTimestamp){
			$tsString = "";
		} else {
			$tsString = $this.ts.toString("yyyy-MM-dd HH:mm:ss");
		}
		
		
		if($this.identString -and $this.identLevel -gt 0){
			#Calculates number of ident string.
			$Identation = $this.identString * $this.identLevel;
		} else {
			$Identation = "";
		}

		
		$finalLogMessage = "$tsString $Identation"
		
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


