Function FormatSQLErrors {
	param([System.Exception]$Exception, $SQLErrorPrefix = "MSSQL_ERROR:")
	
	if(!$Exception){
		throw "INVALID_EXCEPTION_FOR_FORMATTING"
	}
	
	$ALLErrors = @();
	$bex = $Exception.GetBaseException();
	
	if($bex.Errors)
	{
		$Exception.GetBaseException().Errors | %{
			$ALLErrors += "$SQLErrorPrefix "+$_.Message
		}
	} else {
		$ALLErrors = $bex.Message;
	}
	
	
	return ($ALLErrors -join "`r`n`r`n")
	
	<#
		Returns a object containing formated sql errors messages
	#>
}

Function FormatPSException {
	param($e,$errCode = "EXCEPTON_CHAIN ")
	
	. {
		$msgTemplate 	= "ERROR $errCode.{0}: [{1}.{2}][$InvocationName] {3}: {4}"
		$AllMessages	= @()

		$ex = $e.Exception
		
		if($e.InvocationInfo){
			$exInf = $e.InvocationInfo
		}
				
		$num = 1;
		while($ex)
		{
			if(!$exInf) {
				$exInf = $ex.ErrorRecord.InvocationInfo;
			}
			
			if($exInf)
			{
				$linha = $exInf.ScriptLineNumber
				$linhaOffset	 = $exInf.OffsetInLine
				$InvocationName	 = $exInf.InvocationName
				$CommandName	 = $exInf.MyCommand.Name
				$code = $exInf.Line.trim()
			}
			
			
			$msg = $ex.Message
			$AllMessages +=  "ERROR $($errCode).$($num): [$linha,$linhaOffset][$InvocationName|$CommandName] $($code): $msg"
			$num++
			
			
			$ex = $ex.InnerException
			$exInf = $null
		}
		
		$msgErr = ($AllMessages -join "`r`n")
	}

	return $msgErr
}
