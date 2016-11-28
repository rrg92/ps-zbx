USE tempdb;

DECLARE
	@threshold bigint

SET @threshold = 2000;

SELECT
	*
FROM
(
	SELECT
		COUNT(*) AS HighUsageCount
	FROM
		(
			SELECT
				SU.session_id
				,ISNULL((	
					(SU.internal_objects_alloc_page_count+SU.user_objects_alloc_page_count)
						-
					(SU.internal_objects_dealloc_page_count+SU.user_objects_dealloc_page_count)
				)/128.00,0)					as TempdbDataUsed
				,ISNULL(L.Qtdlog/1024.00/1024.00,0)	as TempdbLogUsed
			FROM
				(
					SELECT
						TU.session_id
						,SUM(TU.internal_objects_alloc_page_count)		internal_objects_alloc_page_count
						,SUM(TU.user_objects_alloc_page_count)			user_objects_alloc_page_count
						,SUM(TU.internal_objects_dealloc_page_count)	internal_objects_dealloc_page_count
						,SUM(TU.user_objects_dealloc_page_count)		user_objects_dealloc_page_count
					FROM
						sys.dm_db_task_space_usage TU
					WHERE
						TU.session_id IN (SELECT R.session_id FROM sys.dm_exec_requests R)
					GROUP BY
						TU.session_id
			
					UNION
			
					SELECT
							SU.session_id
						,SU.internal_objects_alloc_page_count
						,SU.user_objects_alloc_page_count
						,SU.internal_objects_dealloc_page_count
						,SU.user_objects_dealloc_page_count
					FROM
						sys.dm_db_session_space_usage SU
					WHERE
						SU.session_id IN ( SELECT S.session_id FROM sys.dm_exec_sessions S WHERE S.status = 'sleeping' )

				) SU
				LEFT JOIN
				(
						SELECT
							ST.session_id
							,DT.database_transaction_log_bytes_reserved as QtdLog
						FROM
						sys.dm_tran_database_transactions DT
						INNER JOIN
						sys.dm_tran_session_transactions ST
							ON DT.transaction_id = ST.transaction_id
						WHERE
						DT.database_id = 2
				) L
					ON L.session_id = SU.session_id	
		) T
		WHERE
			t.TempdbDataUsed + T.TempdbLogUsed >= @threshold
) U
CROSS JOIN
(
	SELECT
	  CONVERT(bigint,SUM(size))*8*1024								as SpaceAllocated 
	 ,CONVERT(bigint,SUM(FILEPROPERTY(name,'SpaceUsed')))*8*1024	as SpaceUsed
	FROM
		sys.database_files
) SU