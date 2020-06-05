
EXEC sp_configure 'show advanced options', 1;

-- To update the currently configured value for advanced options.
RECONFIGURE;

/****************
max server memory
*****************
Consulter la matrice pour la mémoire maximale recommandée :

Références :

https://bornsql.ca/s/memory/

https://support.microsoft.com/en-us/help/2663912


1 GB of RAM for the OS
plus 1 GB for each 4 GB of RAM installed from 4 – 16 GB
plus 1 GB for every 8 GB RAM installed above 16 GB RAM
*/

DECLARE @PHYSICAL_RAM INT;
DECLARE @PHYSICAL_RAM_BELOW_16 INT;
DECLARE @PHYSICAL_RAM_ABOVE_16 INT;
DECLARE @MAX_RAM INT;
SET @PHYSICAL_RAM =
					(
					 SELECT ROUND(total_physical_memory_kb / 1024.0 / 1024.0, 0) AS [Physical Memory (GB)]
					 FROM sys.dm_os_sys_memory WITH(NOLOCK)
					);
IF @PHYSICAL_RAM <= 16
BEGIN
	SET @PHYSICAL_RAM_BELOW_16 = (@PHYSICAL_RAM - 4) / 4;
	SET @PHYSICAL_RAM_ABOVE_16 = 0;
END;
	ELSE
BEGIN
	SET @PHYSICAL_RAM_BELOW_16 = 3;
	SET @PHYSICAL_RAM_ABOVE_16 = (@PHYSICAL_RAM - 16) / 8;
END;

SET @MAX_RAM = @PHYSICAL_RAM;
SET @MAX_RAM = @MAX_RAM - 1; -- 1 GB of RAM for the OS
SET @MAX_RAM = @MAX_RAM - @PHYSICAL_RAM_BELOW_16; -- 1 GB for each 4 GB of RAM installed from 4 – 16 GB
SET @MAX_RAM = @MAX_RAM - @PHYSICAL_RAM_ABOVE_16; -- 1 GB for every 8 GB RAM installed above 16 GB RAM
SET @MAX_RAM = @MAX_RAM * 1024; -- KB

EXEC sp_configure 'max server memory', @MAX_RAM; 
RECONFIGURE;

/************************
max degree of parallelism
*************************
Il est conseillé de limiter le parallélisme à la moitié des CPU

Références :

https://www.mssqltips.com/sqlservertip/5404/parallelism-in-sql-server-execution-plan/

http://davebland.com/max-degree-of-parallelism-vs-cost-threshold-for-parallelism
*/

DECLARE @NB_CPU INT;

SET @NB_CPU =
			  (
			   SELECT cpu_count / 2 AS [Logical CPU Count]
			   FROM sys.dm_os_sys_info
			  );
EXECUTE sp_configure 'max degree of parallelism'  , @NB_CPU; 
RECONFIGURE;


/**********************
Remote Admin Connection
***********************

Référence :

https://docs.microsoft.com/fr-fr/sql/database-engine/configure-windows/remote-admin-connections-server-configuration-option?view=sql-server-ver15
*/

EXEC sp_configure 'remote admin connections', 1;

RECONFIGURE;

/*****************************
cost threshold for parallelism
******************************

La valeur recommandé du cost threshold est de 50

Il est conseillé de limiter le parallélisme à la moitié des CPU

Références :

https://www.mssqltips.com/sqlservertip/5404/parallelism-in-sql-server-execution-plan/

http://davebland.com/max-degree-of-parallelism-vs-cost-threshold-for-parallelism

*/
EXECUTE sp_configure 'cost threshold for parallelism' , 50;
RECONFIGURE;

/****************************
optimize for ad hoc workloads
*****************************

The term “ad hoc” means “as needed,” and in the case of SQL Server, it refers to a single-use query plan, meaning that a plan is generated for a specific query and never used again

Enabling the optimize for ad hoc workloads configuration setting will reduce the amount of memory used by all query plans the first time they are executed.

Instead of storing the full plan, a stub is stored in the plan cache.

Once that plan executes again, only then is the full plan stored in memory.

What this means is that there is a small overhead for all plans that are run more than once on the second execution.

Références :

https://dzone.com/articles/proposed-sql-server-defaults-optimize-for-ad-hoc-w

https://docs.microsoft.com/fr-fr/sql/database-engine/configure-windows/optimize-for-ad-hoc-workloads-server-configuration-option?view=sql-server-ver15
*/

EXECUTE sp_configure 'optimize for ad hoc workloads' , 1;

RECONFIGURE;
				   
/**********************
Backup checksum default
***********************

Références :
https://www.sqlskills.com/blogs/erin/backup-checksum-default-option-in-sql-server-2014/
*/
IF CONVERT(INT, SERVERPROPERTY('ProductMajorVersion')) >= 12 -- seulement à partir 2014
BEGIN
	EXECUTE sp_configure 'backup checksum default' , 1;
END;
RECONFIGURE;


