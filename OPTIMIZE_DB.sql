/*******************
option PAGE_VERIFY 
CHECKSUM est plus performant :

référence :
https://dba-presents.com/index.php/databases/sql-server/22-checksum-vs-torn-page-detection-performance
*/

ALTER DATABASE CURRENT SET PAGE_VERIFY CHECKSUM; 

/*****************************
AUTO_UPDATE_STATISTICS_ASYNC
****************************
Plus performant lorsque l'option auto_update_statistics_async est à ON

Référence : 
https://sqlespresso.com/2017/10/25/synchronous-vs-asynchronously-statistics-updates/
*/

ALTER DATABASE CURRENT SET AUTO_UPDATE_STATISTICS_ASYNC ON WITH NO_WAIT;

/*******************
DELAYED_DURABILITY
******************

Référence :
https://www.sqlskills.com/blogs/paul/delayed-durability-sql-server-2014/
https://docs.microsoft.com/fr-fr/sql/relational-databases/logs/control-transaction-durability?view=sql-server-ver15
*/

ALTER DATABASE CURRENT SET DELAYED_DURABILITY = FORCED;

/*******************
AUTO_CLOSE
******************
référence :
https://blog.sqlauthority.com/2016/09/22/sql-server-set-auto_close-database-option-off-better-performance/
*/

ALTER DATABASE CURRENT SET AUTO_CLOSE OFF;


/*******************
AUTO_SHRINK
******************
référence :
https://techyaz.com/sql-server/performance-tuning/always-turn-off-database-auto-shrink/
*/

ALTER DATABASE CURRENT SET AUTO_SHRINK OFF;
