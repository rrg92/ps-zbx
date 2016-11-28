Function New-LogObject {
	[CmdLetBinding(SupportsShouldProcess=$True)]
	param(
		$ServerInstance = ""
	)

	return (GetLogObject);
	
	<#
		.SYNOPSIS 
			Create a new Log object.
			
		.DESCRIPTION
			The CustomMSSQL module provides a log facility, that allows cmdlets share a common mechanism to logging.
			The log facilities is implemented as internal object that only functions and scripts from inside module can access.
			
			This cmdlet, just create a new instance of Log object and return to the caller, exposing the log facilities to users of CustomMSSQL module.
			This object returned must passed to another cmdlets used for logging.
			The Log object returned have many properties that can be adjusted.
			
			The methods of Log object must be callsed using cmdlets that start with "Invoke-Log*", abailable on this module.
			Calling log object methods directly can result errors because module scope.
			
			For more details about logging facilities provided by CustomMSSQL, about_LoggingCustomMSSQL help.
			
		.EXAMPLE
			
			$LogObject = New-LogObject
			$LogObject.LogLevel = "DETAILED"
			
		.NOTES
		
			KNOW ISSUES
				
			WHAT'S NEW
	#>
}

Function Invoke-Log {
	[CmdLetBinding(SupportsShouldProcess=$True)]
	param(
		#The message to be logged.
			$Message = $null
			
		,#The log level of the logged message
			$Level = $null
		
		,#Force message bypass buffering, if enabled.
			[switch]$ForceNoBuffer = $false
			
		,#Foreground color of the message. Applicable to some logging targets, like host.
			[Alias("fcolor")]
			$ForegroundColor  = $null
			
		,#Background color of the message. Applicable to some logging targets, like host.
			[Alias("bcolor")]
			$BackgroundColor = $null
			
		,#Enable retain mode. This force all next logged messages, and this one, to be retained, up to Flush be used.
			[switch]$Retain = $false
			
		,#Flush all reatined messages and disable retain mode.
			[switch]$Flush = $false
			
		,#Raises de ident level
			[switch]$RaiseIdent = $false
			
		,#Raises de ident level
			[switch]$DropIdent = $false
			
		,#Saves ident current value
			$SaveIdent = $null

		,#Saves ident current value
			$ResetIdent = $null
			
		,#Value of ident level
			$IdentLevel = $null
			
		,#Keep current level when reseting.
			[switch]$KeepLevel = $false
			
		,#Keep current level when reseting.
			[switch]$SkipScheduledIdent = $false
			
		,#Force operation to be applied imeditally on current packet only.
			[switch]$ApplyThis = $false
			
		,#Dont change flow of identations when use with ApplyThis
			[switch]$KeepFlow = $false
			
		,#Dont put a timestamp on message
			[switch]$NoUseTimestamp = $false
			
		,#This is the log object! Use the New-LogObject to create one.
			[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
			$LogObject
		
	)
	
	$identRaise = 0;
	$identDrop = 0;
	
	if($RaiseIdent){
		$identRaise = $IdentLevel;
		if(!$identRaise){
			$identRaise = 1;
		}
	}

	if($DropIdent){
		$identDrop = $IdentLevel;
		if(!$identDrop){
			$identDrop = 1;
		}
	}
	
	$LogOptions = @{
		message 		= $message
		Level 			= $Level
		forceNoBuffer 	= $ForceNoBuffer
		bcolor 			= $BackgroundColor
		fcolor 			= $ForegroundColor
		retain 			= $Retain
		flush 			= $Flush
		identRaise 		= $identRaise
		identDrop		= $identDrop
		identSave		= $SaveIdent
		identReset		= $ResetIdent
		identKeepLevel	= $KeepLevel
		identLevel		= $IdentLevel
		identSkipSched	= $SkipScheduledIdent
		identApplyThis	= $ApplyThis
		identKeepFlow	= $KeepFlow
		noUseTimestamp	= $NoUseTimestamp
	};
		
	
	return $LogObject.LogEx($LogOptions)
		
	<#
		.SYNOPSIS 
			Log
			
		.DESCRIPTION
			The CustomMSSQL module provides a log facility, that allows cmdlets share a common mechanism to logging.
			The log facilities is implemented as internal object that only functions and scripts from inside module can access.
			
			This cmdlet, just create a new instance of Log object and return to the caller.
			This object returned must passed to another cmdlets used for logging.
			The Log object returned have many properties that can be adjusted.
			
			The methods of Log object must be callsed using cmdlets that start with "Invoke-Log*", abailable on this module.
			Calling log object methods directly can result errors because module scope.
			
		.EXAMPLE
			
			$LogObject = New-LogObject
			$LogObject.LogLevel = "DETAILED"
			
		.NOTES
		
			KNOW ISSUES
				
			WHAT'S NEW
	#>
}

Function Get-LogLevels {
	return (GetLogLevels)
}