Function Test-LogObject {
	[CmdLetBinding()]
	param($Path = $null, [switch]$Screen = $false,[switch]$Buffer = $false,$LogLevel = 3,$LoggingNumber = 15,$BufferIsHostDelay = 1,[switch]$BufferIsHost = $false, $RandomColoring=$null,$RetainedInterval = 1,$RetainedCount = 5)
	
	try {

		$o = GetLogObject
		$o.LogTo = @()
		$o.BufferIsHost = $BufferIsHost;
		
		if($Screen) {
			$o.LogTo += "#"
		}
		
		if($Buffer) {
			$o.LogTo += "#BUFFER"
		}
		
		if($LogLevel){
			$o.LogLevel = $LogLevel;
		}
		
		if($Path){
			$o.LogTo += $Path;
		}
		
		if($BufferIsHost){
			$o.log("THIS WAS FORCED!","PROGRESS",$true)
		}
		
		$o.log("Color logging $_","PROGRESS",$false,"Red")
		
		$o.log("Retained Start!!!","PROGRESS",$false,$null,$null,@{retain=$true})
		
		1..$RetainedCount | %{
			$TestLogLevel = Get-Random -Minimum 1 -Maximum 5
			$o.log("Retained message $_ - LogLevel: $TestLogLevel ",$TestLogLevel,$false,$null,$null)
			Start-Sleep -s $RetainedInterval
		}
		
		$o.log("Flushed message","PROGRESS",$false,$null,$null,@{flush=$true})
		
		
		1..$LoggingNumber | %{
			$TestLogLevel = Get-Random -Minimum 1 -Maximum 5
			
			$fcolor = $null;
			$bcolor = $null;
			$fcolorText  = "";
			$bcolorText  = "";
			
			if($RandomColoring){
				$fcolor = @($RandomColoring,1) | Get-Random
				$fcolorText = "[F:$($fcolor)]"
			}
			
			if($RandomColoring){
				$bcolor = @($RandomColoring,1) | where {$_ -ne $fcolor} | Get-Random
				$bcolorText = "[B:$($bcolor)]"
			}
			
			
			if($fcolor -eq 1){
				$fcolor = $null;
				$fcolorText = ""
			}
			

			if($bcolor -eq 1){
				$bcolor = $null;
				$bcolorText = ""
			}
			
			$o.log(" $fcolorText $bcolorText TestLog $_ LogLevel $TestLogLevel",$TestLogLevel,$false,$fcolor,$bcolor);
			
			Start-Sleep -s $BufferIsHostDelay
		}

	} finally {
		write-host ">>> LOGGIN TEST FINIHED. CHECK NEXT RESULTS."
		
		if($Path){
		write-host "------------ PATHS: "
			$Path | %{
				if(-not(Test-Path $_)){
					write-host "Log file inexistent: $_"
					continue;
				}
				
				$p = gi $_
				write-host "	$($p.FullName):"
				gci $p | %{write-host "		$($_.Name)"}
			}
		}
	
		if($o.outBuffer){
			write-host "------------ BUFFERED CONTENTS: "
			write-host ($o.outBuffer -join "`r`n")
		}
		
		$o = $null
	}
}