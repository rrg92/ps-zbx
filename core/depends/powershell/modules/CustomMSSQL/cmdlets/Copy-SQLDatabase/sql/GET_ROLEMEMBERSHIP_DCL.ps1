param($RoleName,$MemberName)
	
return "EXEC sp_addrolemember '$RoleName','$MemberName';"