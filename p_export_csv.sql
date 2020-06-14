

CREATE PROCEDURE [dbo].[p_export_csv] 
				 @table_name NVARCHAR(100)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @sSql NVARCHAR(4000);

	DECLARE @column_name NVARCHAR(100);
	DECLARE @sHeader NVARCHAR(4000);
	DECLARE cCol CURSOR
	FOR SELECT column_name
		FROM information_schema.columns
		WHERE table_name = @table_name
		ORDER BY ordinal_position;

	SET @sSql = '';
	SET @sHeader = '';
	OPEN cCol;
	FETCH NEXT FROM cCol INTO @column_name;
	WHILE @@fetch_status = 0
	BEGIN
		IF @sSql = ''
		BEGIN
			SET @sSql = 'Select ''"'' + ';
		END
			ELSE
		BEGIN
			SET @sSql = @sSql + '+'',"''  + ';
		END;
		SET @sSql = @sSql + 'replace(replace(isnull(left([' + @column_name + '],4000),''''),''"'','' ''),''
	'','' '')+''"''';
		IF @sHeader != ''
		BEGIN
			SET @sHeader = @sHeader + ','
		END;
		SET @sHeader = @sHeader + '"[' + @column_name + ']"';
		FETCH NEXT FROM cCol INTO @column_name;
	END;
	SET @sSql = @sSql + ' from ' + @table_name;
	CLOSE cCol;
	DEALLOCATE cCol;
	PRINT @sheader;
	EXEC (@sSql);
END;

GO


