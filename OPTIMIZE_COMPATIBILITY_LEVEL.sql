DECLARE @version INT;
SET @version = CONVERT(INT, LEFT(CONVERT(VARCHAR, SERVERPROPERTY('ProductVersion')), 2)) * 10;

DECLARE @db_name SYSNAME;
DECLARE @sSql NVARCHAR(MAX);
DECLARE cDB CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY
FOR SELECT name
	FROM sys.databases
	WHERE name = DB_NAME() --  en enlevant cette condition, on effectue le Alter Database sur toutes les bases du serveur qui ont un mode de compatibilité inférieure à celle du serveur
		  AND compatibility_level < @version
		  AND source_database_id IS NULL; 
OPEN cDB;
FETCH NEXT FROM cDB INTO @db_name;
WHILE @@fetch_status = 0
BEGIN
	SET @sSql = ' alter database ' + @db_name + ' set COMPATIBILITY_LEVEL = ' + LEFT(@version, 3);
	PRINT @sSql;
	EXEC sp_executesql @sSql;
	FETCH NEXT FROM cDB INTO @db_name;
END;
CLOSE cDB;
DEALLOCATE cDB;
