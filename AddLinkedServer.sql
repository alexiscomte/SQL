/*

Procedure to make create of SQL Server Linked server easier
Alexis Comte
alexis.comte@capit.net

*/

CREATE PROCEDURE [dbo].[AddLinkedServer] 
				 @srvname     SYSNAME
			   , @srvlogin    SYSNAME
			   , @srvPassword SYSNAME
AS
BEGIN
	IF NOT EXISTS
				  (
				   SELECT 1
				   FROM sys.servers
				   WHERE name = @srvname
				  )
	   AND @srvlogin IS NOT NULL
	   AND @srvPassword IS NOT NULL
	BEGIN
		EXEC sp_addlinkedserver @server = @srvname;
		EXEC sp_addlinkedsrvlogin @rmtsrvname = @srvname
								, @useself = 'false'
								, @rmtuser = @srvlogin
								, @rmtpassword = @srvpassword;
	END;

	EXEC sp_serveroption @server = @srvname
					   , @optname = 'collation compatible'
					   , @optvalue = 'true';
END; 

GO


