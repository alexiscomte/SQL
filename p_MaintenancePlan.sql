/*

Quick maintenance plan for a database

alexis.comte@capit.net

*/

CREATE PROCEDURE [dbo].[p_MaintenancePlan] 
				 @bBackup INT = 1
AS
BEGIN

/************************ 

BACKUP 

*******************/

	-- Timestamp jour et heure
	DECLARE @dateheurestring NVARCHAR(100);
	SET @dateheurestring = replace(CONVERT(NVARCHAR, GETDATE(), 104), ':', '_');
	SET @dateheurestring = replace(@dateheurestring, ' ', '-');
	SET @dateheurestring = replace(@dateheurestring, '.', '-');

	-- Récupère le chemin par défaut du backup 
	DECLARE @backupdirectory NVARCHAR(4000);
	DECLARE @Sqlcommand NVARCHAR(MAX);
	DECLARE @databasename NVARCHAR(1024);
	DECLARE @Retention REAL;
	DECLARE @seuil DATETIME;
	-- Récupère l'ensemble des bases systèmes

	IF @bBackup = 1
	BEGIN

		EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE'
										  , N'Software\Microsoft\MSSQLServer\MSSQLServer'
										  , N'BackupDirectory'
										  , @backupdirectory OUTPUT
										  , 'no_output';

		SET @Sqlcommand = '';
		SET @Sqlcommand = @Sqlcommand + 'BACKUP DATABASE [' + DB_NAME() + '] TO  DISK = N''' + @backupdirectory + '\' + DB_NAME() + '_' + @dateheurestring + '.bak'' WITH NOFORMAT, INIT,  NAME = N''' + DB_NAME() + '-Full Database Backup'', SKIP, NOREWIND, NOUNLOAD,  STATS = 10' + +CHAR(13) + CHAR(10) + ';' + CHAR(13) + CHAR(10);
		PRINT @Sqlcommand;
		EXEC sp_executesql @Sqlcommand;

		SET @Retention = 1;
		-- Purge les fichiers backups
		SET @seuil = GETDATE() - @Retention;
		SET @Sqlcommand = 'EXECUTE master.dbo.xp_delete_file 0,N''' + @backupdirectory + '\'',N''bak'',''' + CONVERT(NVARCHAR, @seuil) + '''';
		PRINT @SqlCommand;
		EXEC sp_executesql @Sqlcommand;
	END;
/*****************************

DBCC CHECKDB

**************************/

	SELECT @Sqlcommand = @Sqlcommand + 'PRINT ''-- Database in progress = ' + DB_NAME() + ' --'';' + 'DBCC CHECKDB(' + DB_NAME() + ');' + CHAR(13) + CHAR(10);
	PRINT @Sqlcommand;
	EXEC sp_executesql @Sqlcommand;


/*****************************

rebuild index

**************************/
	DECLARE @fillfactor INT;
	SET @fillfactor = 90;

	DECLARE @sSql VARCHAR(4000);
	DECLARE cIndex CURSOR
	FOR SELECT 'ALTER INDEX ALL ON ' + table_name + ' REBUILD WITH (FILLFACTOR = ' + CONVERT(VARCHAR(3), @fillfactor) + ')'
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

/*****************************

update stats

**************************/

	SET @Sqlcommand = @Sqlcommand + 'PRINT ''-- Database en cours = ' + DB_NAME() + ' --'';' + 'Exec ' + DB_NAME() + '..sp_updatestats;' + CHAR(13) + CHAR(10);
	PRINT @Sqlcommand;
	EXEC sp_executesql @Sqlcommand;

/*****************************

shrink

**************************/

	PRINT 'shrinkDB';
	EXEC p_shrinkDB;
END;


GO


