USE [Easymed_Bulgaria];
GO


/*

Detect the processes actually waiting for the release of a lock

*/

CREATE PROCEDURE [dbo].[p_waits]
AS
BEGIN

	SELECT [owt].[session_id]
		 , [owt].[exec_context_id]
		 , [ot].[scheduler_id]
		 , [owt].[wait_duration_ms]
		 , [owt].[wait_type]
		 , [owt].[blocking_session_id]
		 , [owt].[resource_description]
		 , CASE [owt].[wait_type]
			   WHEN N'CXPACKET'
				   THEN RIGHT([owt].[resource_description], CHARINDEX(N'=', REVERSE([owt].[resource_description])) - 1)
			   ELSE NULL
		   END AS [Node ID]
		 , [es].[program_name]
		 , [est].text
		 , [er].[database_id]
		 , [eqp].[query_plan]
		 , [er].[cpu_time]
	FROM sys.dm_os_waiting_tasks AS [owt]
		INNER JOIN sys.dm_os_tasks AS [ot]
			ON [owt].[waiting_task_address] = [ot].[task_address]
		INNER JOIN sys.dm_exec_sessions AS [es]
			ON [owt].[session_id] = [es].[session_id]
		INNER JOIN sys.dm_exec_requests AS [er]
			ON [es].[session_id] = [er].[session_id]
		OUTER APPLY sys.dm_exec_sql_text([er].[sql_handle]) AS [est]
		OUTER APPLY sys.dm_exec_query_plan([er].[plan_handle]) AS [eqp]
	WHERE [es].[is_user_process] = 1
	ORDER BY [owt].[session_id]
		   , [owt].[exec_context_id];
END;

GO


