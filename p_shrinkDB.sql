
/*

Shrinks the current database

alexis.comte@capit.net

*/

CREATE PROCEDURE [dbo].[p_shrinkDB]
AS
BEGIN

	DECLARE @dbname SYSNAME;
	SET @dbname = DB_NAME();
	DBCC SHRINKDATABASE(@dbname);

END;

GO


