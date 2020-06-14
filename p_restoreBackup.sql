

/*

Will restore a backup from a file

alexis.comte@capit.net

*/


CREATE PROCEDURE [dbo].[p_restoreBackup] 
				 @dstDBname NVARCHAR(512)
			   , @Path      NVARCHAR(512)
AS
BEGIN
	EXEC KillProcess @dstDBname;

	DECLARE @SQLCommand NVARCHAR(512);
	DECLARE @DefaultData NVARCHAR(512);
	DECLARE @DefaultLog NVARCHAR(512);
	EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE'
									  , N'Software\Microsoft\MSSQLServer\MSSQLServer'
									  , N'DefaultData'
									  , @DefaultData OUTPUT;
	EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE'
									  , N'Software\Microsoft\MSSQLServer\MSSQLServer'
									  , N'DefaultLog'
									  , @DefaultLog OUTPUT;
	IF @DefaultData IS NULL
	BEGIN
		EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE'
										  , N'Software\Microsoft\MSSQLServer\MSSQLServer\Parameters'
										  , N'SqlArg0'
										  , @DefaultData OUTPUT;
		SELECT @DefaultData = SUBSTRING(@DefaultData, 3, 255);
		SELECT @DefaultData = SUBSTRING(@DefaultData, 1, LEN(@DefaultData) - CHARINDEX('\', REVERSE(@DefaultData)));
	END;
	IF @DefaultLog IS NULL
	BEGIN
		EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE'
										  , N'Software\Microsoft\MSSQLServer\MSSQLServer\Parameters'
										  , N'SqlArg2'
										  , @DefaultLog OUTPUT;
		SELECT @DefaultLog = SUBSTRING(@DefaultLog, 3, 255);
		SELECT @DefaultLog = SUBSTRING(@DefaultLog, 1, LEN(@DefaultLog) - CHARINDEX('\', REVERSE(@DefaultLog)));
	END;

	DECLARE @Table TABLE (
						 LogicalName            VARCHAR(128)
					   , [PhysicalName]         VARCHAR(128)
					   , [Type]                 VARCHAR
					   , [FileGroupName]        VARCHAR(128)
					   , [Size]                 VARCHAR(128)
					   , [MaxSize]              VARCHAR(128)
					   , [FileId]               VARCHAR(128)
					   , [CreateLSN]            VARCHAR(128)
					   , [DropLSN]              VARCHAR(128)
					   , [UniqueId]             VARCHAR(128)
					   , [ReadOnlyLSN]          VARCHAR(128)
					   , [ReadWriteLSN]         VARCHAR(128)
					   , [BackupSizeInBytes]    VARCHAR(128)
					   , [SourceBlockSize]      VARCHAR(128)
					   , [FileGroupId]          VARCHAR(128)
					   , [LogGroupGUID]         VARCHAR(128)
					   , [DifferentialBaseLSN]  VARCHAR(128)
					   , [DifferentialBaseGUID] VARCHAR(128)
					   , [IsReadOnly]           VARCHAR(128)
					   , [IsPresent]            VARCHAR(128)
					   , [TDEThumbprint]        VARCHAR(128));

	DECLARE @LogicalNameData VARCHAR(128)
		  , @LogicalNameLog  VARCHAR(128);
	INSERT INTO @table
	EXEC ('
RESTORE FILELISTONLY 
   FROM DISK='''+@Path+'''
   ');

	SELECT @LogicalNameData = LogicalName
	FROM @Table
	WHERE Type = 'D';
	SELECT @LogicalNameLog = LogicalName
	FROM @Table
	WHERE Type = 'L';


	SET @Sqlcommand = 'RESTORE DATABASE [' + @dstDBname + '] FROM  DISK = N''' + @Path + ''' WITH  FILE = 1, 

MOVE N''' + @LogicalNameData + ''' TO N''' + @DefaultData + '\' + @dstDBname + '.mdf'',  
MOVE N''' + @LogicalNameLog + ''' TO N''' + @DefaultLog + '\' + @dstDBname + '_log.ldf'',

 NOUNLOAD,  REPLACE,  STATS = 10 ';

	PRINT @SQLCommand;
	EXEC sp_executesql @Sqlcommand;

END;

GO


