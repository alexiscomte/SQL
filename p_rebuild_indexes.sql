/*

rebuild the all the indexes of a databases

alexis.comte@capit.net

*/


CREATE PROCEDURE [dbo].[p_rebuild_indexes]
AS
BEGIN
	DECLARE @sSql VARCHAR(4000);
	DECLARE cIndex CURSOR
	FOR SELECT 'DBCC DBREINDEX ("' + table_schema + '.' + table_name + '")'
		FROM information_schema.TABLES
		WHERE TABLE_TYPE = 'BASE TABLE';
	OPEN cIndex;
	FETCH NEXT FROM cIndex INTO @sSql;
	WHILE @@FETCH_STATUS = 0
	BEGIN
		PRINT @sSql;
		EXEC (@sSql);
		FETCH NEXT FROM cIndex INTO @sSql;
	END;

	CLOSE cIndex;
	DEALLOCATE cIndex;
END;


GO


