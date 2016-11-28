IF OBJECt_ID('tempdb..#CollectSamples') IS NOT NULL
	DROP TABLE 	#CollectSamples;
CREATE TABLE #CollectSamples(SampleID bigint NOT NULL IDENTITY, CounterName varchar(300),CounterValue bigint, ts datetime);

DECLARE @Collected bigint
SET @Collected = 0

WHILE @Collected < 2
BEGIN
	INSERT INTO
		#CollectSamples
	SELECT
		*
	FROM
		(
			SELECT 
				REPLACE(REPLACE(RTRIM(counter_name),' (KB)',''),' ','_') as CounterName 
				,CONVERT(bigint,cntr_value)	as CounterValue
				,CURRENT_TIMESTAMP as ts
			FROM 
				sys.dm_os_performance_counters
			WHERE
				object_name like '%:SQL Statistics%'
		) CNT
	WHERE
		CNT.CounterName IN (
			'Batch_Requests/sec                                                                                                              '
		)


	set @Collected = @Collected + 1;
	WAITFOR DELAY '00:00:01'
END

SELECT
	C2.CounterName
	,(C2.CounterValue-C1.CounterValue)/DATEDIFF(SS,C1.ts,C2.ts) as CounterValue
FROM
	#CollectSamples C1
	OUTER APPLY
	(
		SELECT TOP 1
			*
		FROM
			#CollectSamples C2
		ORDER BY
			C2.ts DESC
	) C2
WHERE
	C1.SampleID = 1


