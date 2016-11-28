param($Principal,$PermissionName,$State,$SecurableClass,$majorName,$minorName)


if(!$SecurableClass){
	throw "INVALID_SECURABLE_CLASS: $SecurableClass";
}

if(!$majorName){
	throw "INVALID_SECURABLE_NAME: $majorName";
}

$FullSecurableDCL = "ON $($SecurableClass)::$majorName";

if($minorName){
	$FullSecurableDCL += "($minorName)";
}

if($SecurableClass -eq "DATABASE"){
	$FullSecurableDCL = ""
}


$dcl = "$State $PermissionName $FullSecurableDCL TO [$Principal]";

return $dcl;