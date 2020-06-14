/*

Drop the default constraint associated to a column

*/

CREATE PROCEDURE [dbo].[p_drop_defaultconstraint] 
				 @tablename  SYSNAME
			   , @columnname SYSNAME
AS
BEGIN
	DECLARE @const_name VARCHAR(8000);
	SELECT @const_name = constraint_name
	FROM view_default_constraints
	WHERE table_name = @tablename
		  AND column_name = @columnname;

	IF @const_name IS NOT NULL
	BEGIN
		SET @const_name = ' alter table ' + @tablename + ' drop constraint ' + @const_name;
		PRINT @const_name;
		EXEC (@const_name);
	END;
END;


GO


