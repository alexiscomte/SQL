
/*

Procedure in order to Quick launch the backup of a database

*/

CREATE PROCEDURE [dbo].[p_backupDB]
AS
BEGIN

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


	EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE'
									  , N'Software\Microsoft\MSSQLServer\MSSQLServer'
									  , N'BackupDirectory'
									  , @backupdirectory OUTPUT
									  , 'no_output';

	SET @Sqlcommand = '';
	SET @Sqlcommand = @Sqlcommand + 'BACKUP DATABASE [' + DB_NAME() + '] TO  DISK = N''' + @backupdirectory + '\' + DB_NAME() + '_' + @dateheurestring + '.bak'' WITH NOFORMAT, INIT,  NAME = N''' + DB_NAME() + '-Full Database Backup'', SKIP, NOREWIND, NOUNLOAD,  STATS = 10' + +CHAR(13) + CHAR(10) + ';' + CHAR(13) + CHAR(10);
	PRINT @Sqlcommand;
	EXEC sp_executesql @Sqlcommand;
END;

GO


