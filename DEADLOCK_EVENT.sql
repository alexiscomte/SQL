/******************************************************************************
DEADLOCK_EVENT
*******************************************************************************/

------------------------------Début script---------------------------------------
if not exists ( SELECT * FROM sys.server_event_sessions where name='Deadlock')
BEGIN


	CREATE EVENT SESSION [Deadlock] ON SERVER 
	ADD EVENT sqlserver.blocked_process_report(ACTION(sqlserver.session_id, sqlserver.session_nt_username, sqlserver.sql_text, sqlserver.username)), 
	ADD EVENT sqlserver.lock_cancel(ACTION(sqlserver.client_app_name, sqlserver.client_pid, sqlserver.database_name, sqlserver.nt_username, sqlserver.server_principal_name, sqlserver.session_id, sqlserver.session_nt_username, sqlserver.sql_text, sqlserver.username)), 
	ADD EVENT sqlserver.lock_deadlock(ACTION(sqlserver.client_app_name, sqlserver.client_pid, sqlserver.database_name, sqlserver.nt_username, sqlserver.server_principal_name, sqlserver.session_id, sqlserver.session_nt_username, sqlserver.sql_text, sqlserver.username)), 
	ADD EVENT sqlserver.lock_deadlock_chain(ACTION(sqlserver.database_name, sqlserver.session_id, sqlserver.session_nt_username, sqlserver.sql_text, sqlserver.username)), 
	ADD EVENT sqlserver.xml_deadlock_report(ACTION(sqlserver.server_principal_name, sqlserver.session_id, sqlserver.session_nt_username, sqlserver.sql_text, sqlserver.username)) 
	ADD TARGET package0.event_file(SET filename = N'Deadlock') 
	WITH (MAX_MEMORY = 4096 KB, EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY = 30 SECONDS, MAX_EVENT_SIZE = 0 KB, MEMORY_PARTITION_MODE = NONE, TRACK_CAUSALITY = ON, STARTUP_STATE = ON);


	ALTER EVENT SESSION [Deadlock] ON SERVER  
	STATE = start;  

END

