/*

drops the primary key of a table

alexis.comte@capit.net

*/

CREATE PROCEDURE [dbo].[p_drop_primaryKey] 
				 @tablename VARCHAR(100)
AS
BEGIN

	DECLARE @pkname SYSNAME;
	SET @pkname = NULL;
	SELECT @pkname = CONSTRAINT_NAME
	FROM information_schema.table_constraints
	WHERE constraint_type = 'PRIMARY KEY'
		  AND table_name = @tablename;

	IF @pkname IS NOT NULL
	BEGIN
		DECLARE @sSql VARCHAR(8000);
		SET @sSql = 'alter table ' + @tablename + ' drop constraint ' + @pkname;
		EXEC (@sSQl);
	END;
END;

GO


