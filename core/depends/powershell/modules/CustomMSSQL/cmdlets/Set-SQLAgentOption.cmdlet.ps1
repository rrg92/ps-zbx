Function Set-SQLAgentOption {
	[CmdLetBinding()]
	param($InstanceName = $null, $Option = $null, $Value)

	$ErrorActionPreference="Stop"
	$Options = @{};
	$option = Get-SQLAgentOptions -InstanceName $InstanceName -Option $Option -SingleOnly -HashOptions $Options
	$RegKey = $Options.FullPath;
	 
	write-host "Full path is: $RegKey"
	write-host "Changing option $($option.Option) from $($option.Value) to $($Value)"
	Set-ItemProperty -Path $RegKey -Name $option.Option -Value $Value
	write-host "Success!"
}