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
			
		,#For debugging purposes!
			$debugID = $null
			
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
		debugID			= $debugID
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



Function New-InvokeLogProxy {
	param(
		#The name of new function!
		[Parameter(Mandatory=$true)]
		$Name 
	
		,#This is the log object! Use the New-LogObject to create one.
			[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
			$LogObject
	)
	
	
	#Generate a new function with identical prametes...
	#Add this code to it...

	$CurrentModule  = $MyInvocation.MyCommand.ModuleName
	$InvokeLogMeta  = New-object System.Management.Automation.CommandMetaData ( (Get-Command Invoke-Log -Module $CurrentModule) )
	$InvokeLogMeta.Parameters.LogObject.ParameterSets.__AllParameterSets.ValueFromPipeline = $false;	
	$InvokeLogMeta.Parameters.LogObject.ParameterSets.__AllParameterSets.IsMandatory = $false;	
	
	$NewID = 'InvokeLogProxy_'+([Guid]::NewGuid().Guid);
	Set-Variable -Name $NewID -Value $LogObject -Scope "Global" -Visibility "Public";
	
	$NewFunctionScript = [scriptblock]::create("
		function $Name {
			#Proxy function for Invoke-Log
			#Created on $(Get-Date)
		
			 $([Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($InvokeLogMeta))
			 param(
				 $([Management.Automation.ProxyCommand]::GetParamBlock($InvokeLogMeta))
			 )
			 
			 `$LogObject = Get-Variable -Name $NewID -ValueOnly;
			 `$Params = `$PSBoundParameters;
			
			  Invoke-Log @Params -LogObject `$LogObject;
		}
	")
	
	return $NewFunctionScript;
	

	<#
		.SYNOPSIS 
			Create a copy of this function with with a default log object.
			
		.DESCRIPTION
			Creates a custom invoke-log function.
			Users can specify a name and a log object.
			The cmdlet will return a string with function defintion. Just executes in current scope. (this is necessary because the module resided in different session state.)
			After this, user can user this name to invoke log. With this, the log object dont need be piped!
			This simplify use of log functions!
			
			Note that if two users create the function in same scope, this can lead to errors!
			
			Thanks to https://github.com/thlorenz/settings/blob/master/WindowsPowerShell/Modules/PSCodeGen/New-ScriptCmdlet.ps1
			
			You must take caution where definiing your function name.
			This function will be added to the current scope!
			If another function defined same script, this can overwrite the function!
			
		.EXAMPLE
			
			$LogObject = New-LogObject
			$LogObject.LogLevel = "DETAILED"
			
			#Calls the script
			. ($Log | New-InvokeLogProxy -Name "Log");
			
			
			#Now, just call Log how if was Invoke-Log...
			Log "My Log already uses my log object without pipeping it!"
			
			
		.NOTES
		
			KNOW ISSUES
				
			WHAT'S NEW
	#>
}


Function Get-LogLevels {
	return (GetLogLevels)
}

#Set the default log level of logged messages
Function Set-DefaultLogLevel {
	param(
		#This is the log object! Use the New-LogObject to create one.
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
		$LogObject
		
		,#The default level value. Use Get-LogLevels to valid log levels list
			$DefaultLevel = $null
	)
	
	$LogObject.setDefaultLogLevel($DefaultLevel);
}

#Returns true if can log.
Function Test-LogLevel {
	param(
		
		#The desired log level to check if can
		$LogLevel
		
		,#This is the log object! Use the New-LogObject to create one.
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
		$LogObject
	)
	
	return $LogObject.canlog($LogLevel);
}


