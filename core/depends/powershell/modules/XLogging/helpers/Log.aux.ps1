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
		UseDLD=$true #Try discover message level based on characters. For this work, the default log level must set to $null...
		DLDScript=$null #Try discover message level based on characters
		ExternalVerboseMode=$false
		RandomFileNamePrefix="Log"
		OutBuffer = @()
		BufferIsHost=$false
		IgnoreLogFail=$true
		HConfigs = @{} #Specific configurations specific for each handler. This configurations overrides global.
		IdentString = "`t" #Controls the character used for identiation.
		append		= $false #controls if log must be appended!
		consoleHostOnly = $true #Just logs write-host (due to # in LogTO) if currenthostName is ConsoleHost

		#Enable debugging log messages of the log object!
		debugmode 		= $false
		dyndebugscript	= $null


		
		#Contains internal data must be not modified by user.
		internal=@{
					START_TS=(Get-Date)
					RANDOM_LOG_FILE=$null
					DESTINATON_HANDLERS=$null;
					FILE_INITIALIZED=$false
					RETAINING=$FALSE
					RETAINED_LOG_PACKETS=@()
					IDENT_CONTROL = @{
							CURRENT_LEVEL=0
							SCHEDULED_LEVEL=$null
							IDENT_MARKS=@{} #Used to track marks
						}
					METHODS = @{};
					DEFAULT_LOG_LEVEL = $null;
				} 
	}

	$o = New-Object PsObject -Prop $PublicProperties
	$o.internal.DESTINATON_HANDLERS = (GetLogDestinationsHandlers $o);
	
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
				$LogPacket.debugID		= $Options.debugID;
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
					$LogPacket.level = $LogObject.internal.DEFAULT_LOG_LEVEL
				}
				
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
					debugID			- a string to be identified on debugging dynamic script!
			#>
			
			try {
				$DestinationHandlers = $this.internal.DESTINATON_HANDLERS;
				$LOG_LEVELS = GetLogLevels

				
				$LogPacket = & $this.internal.METHODS.ConfigureLogPacket -LogObject $this -Options $Options;

				if($this.debugmode){
				
					#Determine the level os debugs based on script...
					if($this.dyndebugscript){
						. $this.dyndebugscript;
					}
					
					$PacketString = Object2HashString $LogPacket -Expand;
					$this.debuglog("Current Log Packet: $PacketString");
				}
			
			

				#At this point we can determine if loggin must be out...
				
				#If this packet was logged with retention option...
				if($LogPacket.retain){
					$this.internal.RETAINING=$true;
				} 

				#If flush was specifified. Note flush have priority over retain...
				
				if($LogPacket.flush)  {
					$this.internal.RETAINING=$false;
					$FlushFest = $true;
				} else {
					$FlushFest = $false;
				}


				#Here is the destination loop.
				#Here, is where the each specified destination is verified to determine if we can log to it!
				$this.debuglog("Entering on main destination loop...")
				foreach($LogDestination in $this.LogTo) {
					$AllowedLevel = $null;
					
					#If destination is a hashtable, broken the parts...
					if($LogDestination -is [hashtable]){
						$AllowedLevel 		= $LogDestination.LogLevel;
						$LogDestination		= $LogDestination.LogTo;
					}
					
					$this.debuglog("dest: $LogDestination | Allowed: $AllowedLevel");
						
					# if this code running under Verbose powershell mode, use a verbose to handler to write output...
						#This will no check requested level vs current level because verbose mode assume any logging must be out...
					if( $this.IsInVerbose() ){
						$this.debuglog("Verbose enabled!");
						& $DestinationHandlers.VERBOSE.script $LogPacket;
					}
				
					
					
					#If cannot log, continue...
					if( !$this.canLog($LogPacket.level, $AllowedLevel) ){
						continue;
					}
					
					$this.debuglog("This destination can log!", "verbose");

					#Now, the destination handler will be determined based on LogDestinations...
					$Handler = $null;
					$HandlerArgs = @{LogPacket=$LogPacket;Destination=$LogDestination};
					$ElegibleArgs = @{	LogObject=$this
										LogPacket=$LogPacket
										LogDestination=$LogDestination
										CallHandler = $true;
									};
									
					#iterates over handler to discovery the handler...
					$DestinationHandlers.GetEnumerator() | %{
						
						if($this.debugmode){
							$this.debuglog("Inside handler discovery loop..,", "verbose")
							$this.debuglog("Handler: $($_.Key) | Elegible Script: $($_.Value.elegible)")
						}
					
						if($_.Value.elegible){
							if( (& $_.Value.elegible $ElegibleArgs) -eq $true){
								$Handler = $_.Value;
								$this.debuglog("*** $($_.key) was CHOOSED! ***")
								return;
							} 
						}
					}
					
					if(!$Handler){
						$Handler = $DestinationHandlers.FILE;
					}

					if($this.debugmode){
						$HandlerString = Object2HashString $Handler;
						$this.debuglog("Handler: $HandlerString");
					}
					
					$this.debuglog("Reatining ? $($this.internal.RETAINING) CallHandler? $($ElegibleArgs.CallHandler)");
					
					
					if($Handler){
					
						#If retention was enabled, the packet will be queued on the destination retention queue...
						#This will be used next flush to this target!
						if($this.internal.RETAINING){
							$this.debuglog("reatining...");
							$Handler.retainPacket($LogPacket, $LogDestination);
							$this.debuglog("retained called...");
							continue;
						}
						
						#If it times tog et flushed packets...
						if($FlushFest){
							$this.debuglog("flushing fest!");
							$LogPacket.flushedPackets = $Handler.flushPackets($LogDestination);
						}
						
						if($ElegibleArgs.CallHandler){
							$this.debuglog("about to call handler!");
							& $Handler.script @HandlerArgs
							$this.debuglog("call ended!");
						}
						
					} else {
						throw 'FATAL_ERROR: HandlerNotDetermined!'
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
				
				try {
					if($PSCmdlet.MyInvocation.BoundParameters.Contains){
						if($PSCmdlet.MyInvocation.BoundParameters.Contains("Verbose")){
							$IsVerbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent
						}
					}
				} catch {
					$IsVerbose = $false;
				}
				
				if($this.ExternalVerboseMode -or ($VerbosePreference -and $VerbosePreference -ne "SilentlyContinue")){
					$IsVerbose = $true;
				}
				
				return $IsVerbose;
			}).GetNewClosure()
			
			
		#Test if log object can log on specific log level...
		#It is useful for the user execute some codes only if a specific log level is active...
		#first param is the current message level...
		#Second parameter is the level allowed. If null, the method will query LogLevel property of the log...
		$canLog = [scriptblock]::create({
				param($LogLevel, $AllowedLevel = $null)
		
				if(!$AllowedLevel){
					$AllowedLevel = $this.LogLevel
				}
				
		
				#If desired level <= max level, then return true.
				$can = (GetLogLevelNumber($LogLevel)) -le (GetLogLevelNumber($AllowedLevel))
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
				
				if($finalIdentLevel -lt 0){
					$finalIdentLevel = 0;
				}
				
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
		
		
		#Sets a default log level!
		$DefaultLogLevelMethod = [scriptblock]::create({
					param($LogLevel = $null)

					if( (ValidateLogLevel $LogLevel) -or $LogLevel -eq $null){
						$this.internal.DEFAULT_LOG_LEVEL = $LogLevel;
					} else {
						throw "INVALID_LOG_LEVEL: $LogLevel";
					}
		
			})
		
		
		$debuglog = {
			param($m, $writetype = "debug")
			
			if($this.debugmode){
				$cmdlet = "write-$writetype";
				& $cmdlet $m;
			}
		}	
		

		
	$o | Add-Member -Type ScriptMethod -Name Log -Value  $LogMethod;
	$o | Add-Member -Type ScriptMethod -Name LogEx -Value  $LogMethodEx;
	$o | Add-Member -Type ScriptMethod -Name LogSQLErrors -Value  $LogSQLErrors;
	$o | Add-Member -Type ScriptMethod -Name isInVerbose -Value  $InVerboseMode
	$o | Add-Member -Type ScriptMethod -Name canLog -Value  $canLog
	$o | Add-Member -Type ScriptMethod -Name dropIdent -Value  $DropIdentMethod
	$o | Add-Member -Type ScriptMethod -Name getIdentLevel -Value  $GetIdentMethod
	$o | Add-Member -Type ScriptMethod -Name setIdentLevel -Value  $SetIdentMethod
	$o | Add-Member -Type ScriptMethod -Name setDefaultLogLevel -Value  $DefaultLogLevelMethod
	$o | Add-Member -Type ScriptMethod -Name debuglog -Value  $debuglog

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
		debugID = $null
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
	param($LogObject)
	
	return @{
		VERBOSE = NewDestinationHandle $LogObject  {
			param($LogPacket,$Destination = $null)

			if($LogPacket.LogObject.IsInVerbose()){
				$LogPacket.alreadyScreened = $true;
			} 
			
			write-verbose ($LogPacket.getVerboseMessage());
		}
	
		HOST = NewDestinationHandle $LogObject {
			param($LogPacket,$Destination = $null)
			
			$LogPacket.LogObject.debuglog("Inside host destination handler!");
			
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
			
			
			if($LogPacket.LogObject.consoleHostOnly){
				$CanHostLog = $host.Name -eq "ConsoleHost";
			} else {
				$CanHostLog = $true;
			}

			if($CanHostLog){
				write-host @CmdLetParams;
			}
			
		} -ElegibleScript {
			param($HandlerParams)
			
			
			
			if($HandlerParams.LogDestination -ne "#"){
				return $false;
			}
			
			$BufferIsHost = $HandlerParams.LogObject.BufferIsHost;
			
			if($LogPacket.forceNoBuffer){ #if user wants force buffer...
				$BufferIsHost = $false;
			}
			
			if($BufferIsHost){
				$HandlerParams.CallHandler = $false;
			}
			
			return $true;
		}

		FILE = NewDestinationHandle $LogObject {
			param($LogPacket,$Destination)
			
			$LogPacket.LogObject.debuglog("Inside FILE destination handler!");
			
			$Destination | %{
				if(!$LogPacket.LogObject.internal.FILE_INITIALIZED){
					try {
						if(!$LogPacket.LogObject.append){
							[void](New-Item -Force -ItemType File -Path $_)
						}
						$LogPacket.LogObject.internal.FILE_INITIALIZED = $true;		
					} catch {
						$LogPacket.LogObject.internal.FILE_INITIALIZED = $false;
						return;
					}
				}
	
				$LogPacket.getSimpleMessage() >> $_
			}
		}
		
		SCRIPTBLOCK =  NewDestinationHandle $LogObject {
			param($LogPacket,$Destination)
			
			$LogPacket.LogObject.debuglog("Inside SCRIPTBLOCK destination handler!");
			
			& $Destination $LogPacket
		} -ElegibleScript {
			param($HandlerParams)
			return $HandlerParams.LogDestination -is [scriptblock];
		}
		
		SQLAGENT = NewDestinationHandle $LogObject  {
			param($LogPacket, $Destination = $null)
			
			$LogPacket.LogObject.debuglog("Inside SQLAGENT destination handler!");
			
			write-output $LogPacket.getSimpleMessage();
		} -ElegibleScript {
			param($HandlerParams)
			
			return $HandlerParams.LogDestination -eq "#SQLAGENT";
		}
		
		FOLDER =  NewDestinationHandle $LogObject {
			param($LogPacket, $Destination = $null)
			
			$LogPacket.LogObject.debuglog("Inside FOLDER destination handler!");
			
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
		} -ElegibleScript {
			param($HandlerParams)
			
			return [IO.Directory]::Exists([string]$HandlerParams.LogDestination);
		}

		BUFFER =  NewDestinationHandle $LogObject {
				param($LogPacket,$Destination = $null)
				
				$LogPacket.LogObject.debuglog("Inside BUFFER destination handler!");
				
				$LogPacket.LogObject.OutBuffer += @($LogPacket.getSimpleMessage())
				$LogPacket.buffered = $true;
			} -ElegibleScript {
				param($HandlerParams)
				
				if($HandlerParams.LogDestination -ne "#BUFFER"){
					return $false;
				}
				
				if($HandlerParams.LogPacket.forceNoBuffer){
					$HandlerParams.CallHandler = $false;
				}
				
				return $true;
			}
	
	
	}

}


#Creates a new destination handler.
#A destination handler is a object that knows all about a specific destination type.
#It acts like a agent between log engine and the destination. All handlers all maintaned by developers and users just 
#needs knows about supported destinations! One destination handler can handle one or more destinations types!
Function NewDestinationHandle {
	param($LogObject, $Script, $ElegibleScript = $null)
	
	$DH = New-Object PsObject -Prop @{
							retention_queue = @{};
							script			= $Script;
							elegible		= $ElegibleScript
							logObject		= $LogObject
						}
						
	$Methods = @{
		retainPacket = {
			param($Packet, $Destination)
			$rq = $this.retention_queue;
			$d = $Destination.toString();
			
			if(!$rq.Contains($d)){
				$rq.add($d,@());
			}
			
			$rq[$d] += $Packet;
			$this.LogObject.debuglog("Queue count: $($rq[$d].count) Destination queue: $($Destination)")
		}
		
		flushPackets = {
			param($Destination)
			
			$rq = $this.retention_queue;
			$d = $Destination.toString();
			
			if($rq.Contains($d)){
				$Packets = $rq[$d];
				$rq[$d] = @();
			}
			
			$this.LogObject.debuglog("Flushed count: $($Packets.count) Destination queue: $($Destination)")
			return $Packets;
		}
	}
	
	
	$Methods.GetEnumerator() | %{
		$DH | Add-Member -Type ScriptMethod -Name $_.Key -Value $_.Value;
	}

	
	return $DH;
}



