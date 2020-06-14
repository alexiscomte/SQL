
/*

Kill all actives connections on a database

*/

CREATE PROCEDURE [dbo].[KillProcess] 
				 @dstDBname NVARCHAR(200)
AS
BEGIN
	IF EXISTS
			  (
			   SELECT 1
			   FROM sys.databases
			   WHERE name = @dstDBname
			  ) 
	BEGIN
		DECLARE @p TABLE (
						 processid INT);

		DECLARE @processid INT;
		SELECT @processid = MIN(spid)
		FROM master.dbo.sysprocesses
		WHERE dbid = DB_ID(@dstDBname);


		WHILE @processid IS NOT NULL
		BEGIN
			INSERT INTO @p(processid)
			VALUES(@processid);
			BEGIN TRY
				EXEC ('KILL '+@processid);
			END TRY
			BEGIN CATCH
			END CATCH;
			SELECT @processid = MIN(spid)
			FROM master.dbo.sysprocesses
			WHERE dbid = DB_ID(@dstDBname)
				  AND spid NOT IN
								  (
								   SELECT processid
								   FROM @p
								  );

		END;
	END;
END;

GO


