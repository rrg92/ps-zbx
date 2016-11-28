SELECT
	CONVERT(XML,QP.query_plan) as XMLData
FROM
	sys.dm_exec_query_stats QS
	CROSS APPLY
	sys.dm_exec_text_query_plan(QS.plan_handle,QS.statement_start_offset,QS.statement_end_offset) QP