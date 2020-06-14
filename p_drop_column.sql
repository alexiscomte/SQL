
/*

Easyly drop a column

alexis.comte@capit.net

*/

CREATE PROCEDURE [dbo].[p_drop_column] 
				 @tablename  VARCHAR(500)
			   , @columnname VARCHAR(500)
AS
BEGIN
	DECLARE @bOk TINYINT;
	SET @bOk = 1;

	IF EXISTS
			  (
			   SELECT 1
			   FROM sysobjects
			   WHERE name = 'sysmergearticles'
			  ) 
	BEGIN
		SELECT @bOk = 0
		FROM sysmergearticles
		WHERE name = @tablename
	END;

	IF @bOk = 1
	BEGIN
		DECLARE @const_name VARCHAR(8000);
		SELECT @const_name = constraint_name
		FROM view_default_constraints
		WHERE table_name = @tablename
			  AND column_name = @columnname;

		IF @const_name IS NOT NULL
		BEGIN
			SET @const_name = ' alter table ' + @tablename + ' drop constraint ' + @const_name;
			EXEC (@const_name);
		END;

		DECLARE @sSql VARCHAR(8000);


		DECLARE cIdx CURSOR
		FOR SELECT index_name
			FROM VIEW_COLUMNS_INDEXES
			WHERE table_name = @tablename
				  AND column_name = @columnname;

		DECLARE @indexname VARCHAR(200);

		OPEN cIdx;
		FETCH NEXT FROM cIdx INTO @indexname;
		WHILE @@fetch_status = 0
		BEGIN
			SET @sSql = ' drop index ' + @tablename + '.' + @indexname;
			EXEC (@sSql);
			FETCH NEXT FROM cIdx INTO @indexname;
		END;
		CLOSE cIdx;
		DEALLOCATE cIdx;

		DECLARE cCon CURSOR
		FOR SELECT [CONSTRAINT_NAME]
			FROM [INFORMATION_SCHEMA].[CONSTRAINT_COLUMN_USAGE]
			WHERE table_name = @tablename
				  AND column_name = @columnname;

		OPEN cCon;
		FETCH NEXT FROM cCon INTO @const_name;
		WHILE @@fetch_status = 0
		BEGIN
			SET @const_name = ' alter table ' + @tablename + ' drop constraint ' + @const_name;
			EXEC (@const_name);
			FETCH NEXT FROM cCon INTO @const_name;
		END;

		CLOSE cCon;
		DEALLOCATE cCon;

		SET @sSql = 'alter table ' + @tablename + ' drop column  ' + @columnname;
		EXEC (@ssql);



	END;
END;


GO


