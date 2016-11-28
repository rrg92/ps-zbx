param($CmdLetsDir = ".\cmdlets", $AuxDir = ".\helpers")

#For detailed informations about structure and internals about this code check !Help.txt file in module root directory.

$ErrorActionPreference ="Stop"
#Save current location
push-location
#Change current location to dir where this script are executed (the module root)
#ModuleRoot will store where user call this module. This is important when importaing from shares.
#If two modules exists, one on share a another on modulepath, importing without correctly location can lead to incosistent states.
$ModuleRoot 	= (Split-Path -Parent $MyInvocation.MyCommand.Definition );
$ModulePsm 	= $MyInvocation.MyCommand.Definition;
set-location $ModuleRoot

$CurrentFunctions  = @()
$ExportedFunctions = @()
$FunctionsToExport = @()

#Setting global module values. This is documented in about and is shared by all cmdlets...
$GMV = @{MODULE_ROOT=$ModuleRoot; PSM_PATH=$ModulePsm};
$GMV.add("CMDLETSIDR",(Resolve-Path $CmdLetsDir))
$GMV.add("AUXDIR",(Resolve-Path $AuxDir))
$GMV.add("CHANGELOGFILE",(Resolve-Path ".\CHANGELOG.md"))
$GMV.add("VARS",@{})

# Function created just to we have access to moduleinfo object that represent this module. If you know another way, update this method.
# We'll create a dummy function in order to acess your "Module" property via Get-Command cmdlet. This allows us reference this instance of import.
#Wehn this was developed, it was thinking in compatibility with powershell 2.0
	
	#Here, we generate a dummy name and append this to dynamic Function command in powershell.
	$DummyFunctionName = "ImportDummy_"+[System.Guid]::NewGuid().Guid.replace("-","");
	$DummyFunction = [scriptblock]::create("Function $DummyFunctionName{return 'XLogging';}")

	#Call command to import in current module.
	. $DummyFunction;

	#Lets get function meta-data in order to access ModuleInfo object that represent this module.
 	$CurrentModule = (Get-Command $DummyFunctionName).Module;

	if(!$CurrentModule){
		throw "CANNOT GET THE CURRENT MODULE OBJECT REFERENCE. CONTACT DEVELOPER. rodrigo@thesqltimes.com | Dummy Function: $DummyFunctionName"
	}

#At this point, we have reference to XLogging module.
$GMV.add("CURRENT_MODULE",$currentModule);

try {
	gci "$AuxDir\*.aux.ps1" | %{
		write-verbose "Calling auxiliar file: $($_.FullName)"
		. $_.FullName
	}

	
	$ExportedFunctions += Get-Command | where {$_.Module.Path -eq $CurrentModule.Path} | %{$_.Name}
	
	gci "$CmdLetsDir\*.cmdlet.ps1" | %{
		write-verbose "Calling cmdlet file: $($_.FullName)"
		. $_.FullName
	}
	

	$FunctionsToExport = Get-Command | where {$_.Module.Path -eq $CurrentModule.Path} | where {!($ExportedFunctions -Contains $_.Name) -and $_.Name -like "*-*"} | %{$_.Name}
} finally {
	pop-location
}

#Using "Function" to force override .psd1 setting...


$FunctionsToExport | %{
	Export-ModuleMember -Function $_
}