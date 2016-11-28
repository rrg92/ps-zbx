#GMV is global module values.
#This contains lot of values that can be shared with programmers of this module.
#Check about_Custom_MSSQL to detailed informations.

Function GetGMV {

	return $GMV;

}

#Return a GMV VAR SLOT!
#A GMV VAR SLOT is a simply entri o GMV "VARS" key. The "VARS" entry on GMV contains all variables used by cmdlets in CustomMSSQL.
#A developer of cmdlet can request a slot to add values shared by cmdlets.

Function GetVarSlot {
	param($slotName = $null)
	
	$GMV = (GetGMV);
	
	if(!$GMV){
		throw "GMV is empty. This is a internal error of CustomMSSQL module. Contact developer!"
	}
	
	$VARS = $GMV.VARS;
	
	if(!$slotName){
		return $VARS;
	} else {
	
		if($VARS.Contains($slotName)){
			return $VARS.$slotName;
		} else{
			$VARS.add($slotName,@{});
			return $VARS.$slotName;
		}
	}
		
}

#Update a variable on a var slot

Function UpdateVarSlot {
	param($slot,$varName,$value=$null)
	
	if(!$slot -or $slot -isnot [hashtable]){
		throw "Invalid slot!"
	}
	
	if($slot.Contains($varName)){
		$slot.$varName = $value;
	} else {
		$slot.add($varName,$value);
	}

}


#Returns all parameters and corresponding value as a hashtable
#This can be useful when showing to user.
#The caller must pass the $MyInvocation info object. If not passed, the object on parent scope will be get.
Function GetAllCmdLetParams {
	param($InvocationObject = $null)
	
	if(!$InvocationObject){
		$InvocationObject = (Get-Variable -Name "MyInvocation" -Scope 1).Value
	}
	
	$ModuleName = $null;
	if($InvocationObject){
		$ModuleName = $InvocationObject.MyCommand.Module.Name;
	}

	$CmdLetName = $InvocationObject.MyCommand.Name

	$AllParameters = (Get-Command -Name $CmdLetName -Module $ModuleName).Parameters;
	$ParamsValues = @{};
	$AllParameters.GetEnumerator() | %{
		$ParameterMeta = $_.Value;
		
		#Get value of parameter on parent scope...
		try {
			$ParamVar = Get-Variable -Name $ParameterMeta.Name -Scope 1;
			$ParamValue = $ParamVar.Value
		} catch {
			$ParamValue = $null;
		}

		$ParamsValues.Add($ParameterMeta.Name,$ParamValue)
	}
	
	
	return $ParamsValues;
}


#Convert a PsCustomOject to hashtable!!!
Function Object2HashString {
	param($Objects, [switch]$Expand = $false)

	$ALLObjects = @()
	foreach($object in $Objects){
		$PropsString = @()
		
		foreach($Prop in $Object.psobject.properties) { 
			$PropValue = $Prop.Value;
			
			if($PropValue -is [HashTable] -and $Expand){
				$PropValue  = Object2HashString (New-Object PsObject -Prop $PropValue) -Expand
			} else {
				if($PropValue){
					$PropValue = $PropValue.toString()
				}
			}
			
			$PropsString	 += "$($Prop.Name)=$($PropValue)";
		}
		
		$ALLObjects += "@{"+($PropsString -join ";")+"}"
	}
	


	return ($ALLObjects -join "`r`n");
}


#Get specific version number from a Product version string from SQL Server. This can be obtained with SERVERPROPERTY('ProductVersion')
Function GetProductVersionPart {
	param($VersionText,$Position = 1)
	
	
	$FirstMatchCount = $Position - 1;
	
	#The logic is simple: Match the string NNN.NNN.NNN.NNN 
	#The first parentheses, matchs first pairs "NNNN." The amount of matches depends of $FirstMatchCount
	#Next parenthesis matchs our deserided part, because previous expressions already matchs that parts that we not want.
		#This is because we can decrement position. If we want first part, then the first expression must match 0 for next catch correct part. 
	$m = [regex]::Match($VersionText,"^(\d+\.){$FirstMatchCount}(\d+).*$");

	#The match results will contains thee groups: The first is entire string, the second is last match of {count}. The next have our data. It is os offset 2 of array.
	$part = $m.Groups[2].Value;
	
	if($part){
		return ($part -as [int])
	} else {
		return $null;
	}
	
	
}

#https://msdn.microsoft.com/en-us/library/ms143694.aspx
Function GetProductVersionNumeric {
	param($Version1,$Parts = 3)

	$Major1 = GetProductVersionPart $Version1 1
	$Minor1 = GetProductVersionPart $Version1 2
	$Build1 = GetProductVersionPart $Version1 3
	$Revision1 = GetProductVersionPart $Version1 4
	
	
	return $Major1 + ($Minor1*0.01) + ($Build1*0.000001) + ($Revision1*0.00000001);
}












