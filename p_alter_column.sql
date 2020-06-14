/*

Stored procedure will make the job of altering the type of an SQL Server Table

Alexis Comte
alexis.comte@capit.net

*/

CREATE PROCEDURE [dbo].[p_alter_column] 
				 @tablename  VARCHAR(500)
			   , @columnname VARCHAR(500)
			   , @newtype    VARCHAR(500)
AS
BEGIN

	DECLARE @const_name VARCHAR(8000);
	DECLARE @const_default VARCHAR(8000);

	DECLARE @sSqlDefault VARCHAR(8000);

	SELECT @const_name = constraint_name
		 , @const_default = column_default
	FROM view_default_constraints
	WHERE table_name = @tablename
		  AND column_name = @columnname;



	IF @const_name IS NOT NULL
	BEGIN
		SET @sSqlDefault = ' alter table ' + @tablename + ' add constraint ' + @const_name + ' default ' + @const_default + ' for ' + @columnname;

		SET @const_name = ' alter table ' + @tablename + ' drop constraint ' + @const_name;
		EXEC (@const_name);
	END;

	DECLARE @sSql VARCHAR(8000);

	DECLARE cIdx CURSOR
	FOR SELECT index_name
			 , is_unique
			 , is_primary_key
			 , is_clustered
		FROM VIEW_COLUMNS_INDEXES
		WHERE table_name = @tablename
			  AND column_name = @columnname;

	DECLARE @indexname VARCHAR(200);
	DECLARE @is_unique INT;
	DECLARE @is_primary_key INT;
	DECLARE @is_clustered INT;

	DECLARE @sSqlCreateIndex VARCHAR(8000);
	SET @sSqlCreateIndex = '';
	OPEN cIdx;
	FETCH NEXT FROM cIdx INTO @indexname
							, @is_unique
							, @is_primary_key
							, @is_clustered;
	WHILE @@fetch_status = 0
	BEGIN

		SET @sSqlCreateIndex = @sSqlCreateIndex + '
		' + dbo.f_script_index(@tablename, @indexname);

		IF @is_primary_key = 1
		BEGIN
			SET @sSql = ' alter table ' + @tablename + ' drop constraint ' + @indexname;
		END
			ELSE
		BEGIN
			SET @sSql = ' drop index ' + @tablename + '.' + @indexname;
		END;
		PRINT @sSql;
		EXEC (@sSql);
		FETCH NEXT FROM cIdx INTO @indexname
								, @is_unique
								, @is_primary_key
								, @is_clustered;
	END;
	CLOSE cIdx;
	DEALLOCATE cIdx;


	SET @sSql = 'alter table ' + @tablename + ' alter column  ' + @columnname + ' ' + @newtype;
	PRINT @sSql;
	EXEC (@ssql);
	SET @sSql = @sSqlCreateIndex;
	PRINT @sSql;
	EXEC (@sSql);
	SET @sSql = @sSqlDefault;
	PRINT @sSql;
	EXEC (@sSql);
END;

GO


