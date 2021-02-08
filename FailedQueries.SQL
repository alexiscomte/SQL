if  exists (SELECT 1  
      FROM sys.server_event_sessions
	  where name = 'FailedQueries')
	  DROP 	  EVENT SESSION [FailedQueries] ON SERVER;

CREATE EVENT SESSION [FailedQueries] ON SERVER 
ADD EVENT sqlserver.error_reported 
    (ACTION(sqlserver.client_app_name, sqlserver.client_hostname,  
        sqlserver.database_name, sqlserver.sql_text,sqlserver.tsql_frame,sqlserver.tsql_stack, sqlserver.username) 
    WHERE [package0].[greater_than_int64]([severity], (10)) -- Only errors
		AND [error_number] <> 18456 -- Login failed for user
		AND [error_number] <> 4060 -- login error
	)  
ADD TARGET package0.event_file (SET
    filename = N'FailedQueries.xel'
    ,metadatafile = N'FailedQueries.xem'
    ,max_file_size = (5)
    ,max_rollover_files = (2))
 WITH (MAX_MEMORY=4096 KB,
EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,
MAX_DISPATCH_LATENCY=30 SECONDS,
MAX_EVENT_SIZE=0 KB,
MEMORY_PARTITION_MODE=NONE,
TRACK_CAUSALITY=OFF,
STARTUP_STATE=ON);

ALTER EVENT SESSION [FailedQueries] ON SERVER 
    STATE = START;
go
IF OBJECT_ID (N'dbo.UVW_FAILEDQUERIES') IS NOT NULL
   DROP VIEW dbo.UVW_FAILEDQUERIES
GO
CREATE VIEW dbo.UVW_FAILEDQUERIES
AS
/******************************************************************************
**  Cette vue ramène les erreurs survenues sur le serveur SQL.
*******************************************************************************/


SELECT DATEADD(hh, DATEDIFF(hh, GETUTCDATE(), CURRENT_TIMESTAMP), event_data.value('(event/@timestamp)[1]', 'datetime')) AS                                                                                                           timestamp
	 , event_data.value('(event/data[@name="message"]/value)[1]', 'varchar(max)') AS                                                                                                                                                  Error
	 , ISNULL(SUBSTRING(st.text, (frame_data.value('./@offsetStart', 'int') / 2) + 1, ((CASE frame_data.value('./@offsetEnd', 'int')
																							WHEN-1
																								THEN DATALENGTH(st.text)
																							ELSE frame_data.value('./@offsetEnd', 'int')
																						END - frame_data.value('./@offsetStart', 'int')) / 2) + 1), event_data.value('(event/action[@name="sql_text"]/value)[1]', 'varchar(max)')) AS sql
	 , OBJECT_NAME(st.objectid, st.dbid) AS                                                                                                                                                                                           objectname
	 , event_data.value('(event/action[@name="database_name"]/value)[1]', 'varchar(max)') AS                                                                                                                                          database_name
	 , event_data.value('(event/action[@name="client_hostname"]/value)[1]', 'varchar(max)') AS                                                                                                                                        client_hostname
	 , event_data.value('(event/action[@name="client_app_name"]/value)[1]', 'varchar(max)') AS                                                                                                                                        client_app_name
	 , event_data.value('(event/action[@name="username"]/value)[1]', 'varchar(max)') AS                                                                                                                                               username

	 , event_data.value('(event/data[@name="error_number"]/value)[1]', 'varchar(max)') AS                                                                                                                                             [error_number]
	-- ,event_data
FROM sys.dm_xe_sessions AS FailedQueries
	INNER JOIN sys.dm_xe_session_targets AS files
		ON FailedQueries.[address] = files.event_session_address
	CROSS APPLY
				(
				 SELECT object_name
					  , CAST(event_data AS XML) AS event_data
				 FROM sys.fn_xe_file_target_read_file(CAST(files.target_data AS XML).value('(/EventFileTarget/File/@name)[1]', 'nvarchar(max)'), NULL, NULL, NULL)
				) AS x
	OUTER APPLY x.event_data.nodes('event/action[@name="tsql_frame"]/value/frame') AS Frame(frame_data)
	OUTER APPLY sys.dm_exec_sql_text(CONVERT(VARBINARY(MAX), frame_data.value('./@handle', 'varchar(max)'), 1)) AS st
WHERE FailedQueries.[name] = 'FailedQueries';

GO
