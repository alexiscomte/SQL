



/*
Optional replacement for "String or binary data would be truncated" message with extended information in SQL Server 2016 and 2017
Référence:
https://support.microsoft.com/en-us/help/4468101/optional-replacement-for-string-or-binary-data-would-be-truncated
https://docs.microsoft.com/en-us/sql/relational-databases/performance/best-practice-with-the-query-store?view=sql-server-2017#Recovery
*/

IF CONVERT(INT, SERVERPROPERTY('ProductMajorVersion')) >= 13 -- seulement à partir 2016
BEGIN
	DBCC TRACEON(460, -1);  -- Improvement: Optional replacement for "String or binary data would be truncated" message with extended information in SQL Server 2017
	DBCC TRACEON(7745, -1); -- Prevents Query Store data from being written to disk in case of a failover or shutdown command
	DBCC TRACEON(7752, -1); -- Enables asynchronous load of Query Store, This allows a database to become online and queries to be executed before the Query Store has been fully recovered 
END;

/*
Suppression des messages de backups réussis dans les logs
Référence: 
https://www.sqlskills.com/blogs/paul/fed-up-with-backup-success-messages-bloating-your-error-logs/
*/
DBCC TRACEON(3226, -1); -- - Supresses logging of successful database backup messages to the SQL Server Error Log

/*
Autostat
Référence : 
https://support.microsoft.com/en-us/help/2754171/controlling-autostat-auto-update-statistics-behavior-in-sql-server
*/

DBCC TRACEON(2371, -1); -- Controlling Autostat (AUTO_UPDATE_STATISTICS) behavior in SQL Server

/*

Références :
https://blogs.msdn.microsoft.com/psssql/2016/03/15/sql-2016-it-just-runs-faster-t1117-and-t1118-changes-for-tempdb-and-user-databases/
*/

IF CONVERT(INT, SERVERPROPERTY('ProductMajorVersion')) < 13 -- en 2016, c'est activé par défaut
BEGIN
	DBCC TRACEON(1117, -1);  --  When growing a data file grow all files at the same time so they remain the same size, reducing allocation contention points
	DBCC TRACEON(1118, -1); -- Prevents Query Store data from being written to disk in case of a failover or shutdown command
END;
