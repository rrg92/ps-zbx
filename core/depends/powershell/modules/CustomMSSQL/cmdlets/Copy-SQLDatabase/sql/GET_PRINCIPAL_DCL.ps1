#Generate the DCL command for restore permission!
param($principalName,$mappedName,$type) 

if($type -eq "DATABASE_ROLE"){
	$DCL = "IF USER_ID('$principalName') IS NULL EXEC('CREATE ROLE [$principalName]')";
}

else {
	$CreateDCL = "";
	$AlterDCL = "";
	
	if($mappedName){
		$CreateDCL = "CREATE USER [$principalName] FROM LOGIN [$mappedName]";
		$AlterDCL = "ALTER USER [$principalName] WITH LOGIN = [$mappedName]"
	} else {
		$CreateDCL = "CREATE USER [$principalName] WITHOUT LOGIN";
		$AlterDCL = "/*MAPPED LOGIN IS EMPTY*/"

	}

	$DCL = "IF USER_ID('$principalName') IS NULL EXEC('$CreateDCL') ELSE EXEC('$AlterDCL')";
}


return $DCL;