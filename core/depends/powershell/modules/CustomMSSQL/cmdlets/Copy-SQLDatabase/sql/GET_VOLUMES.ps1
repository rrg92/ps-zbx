return "
SELECT DISTINCT
	VS.logical_volume_name
	,VS.volume_mount_point
	,VS.available_bytes
FROM
	sys.master_files MF
	OUTER APPLY
	sys.dm_os_volume_stats(MF.database_id,MF.file_id) VS
WHERE
	VS.volume_mount_point IS NOT NULL
"
