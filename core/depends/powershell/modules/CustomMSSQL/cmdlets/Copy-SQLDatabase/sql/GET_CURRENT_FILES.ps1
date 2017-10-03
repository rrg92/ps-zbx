return "
SELECT 
	 F.file_id as FileID 
	,F.name as logicalName
	,F.physical_name AS physicalName 
	,F.type as Type
	,F.size as Size
FROM 
	sys.database_files F
"
