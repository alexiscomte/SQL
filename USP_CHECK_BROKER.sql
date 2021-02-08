IF OBJECT_ID(N'dbo.USP_CHECK_BROKER') IS NOT NULL
BEGIN
	DROP PROCEDURE DBO.USP_CHECK_BROKER;
END;
GO

CREATE PROCEDURE dbo.USP_CHECK_BROKER 
				 @REPAIR  BIT      = 0
			   , @START   DATETIME = NULL
			   , @VERBOSE BIT      = 0
AS
/******************************************************************************
**  Diagnostics sur le service BROKER de SQL Server

Réparation du Broker	:  EXEC USP_CHECK_BROKER @REPAIR = 1
Diagnostics détaillés   :  EXEC USP_CHECK_BROKER @VERBOSE = 1

*******************************************************************************/
BEGIN
	SET NOCOUNT ON;
	DECLARE @WARNINGS TABLE (
							MSG VARCHAR(MAX));


	DECLARE @SQL NVARCHAR(MAX) = '';
	DECLARE @TIMER INT;
	DECLARE @QNAME VARCHAR(200);

	DECLARE @END DATETIME = GETDATE();

	DECLARE @CONVERSATION_HANDLE UNIQUEIDENTIFIER;

	IF @START IS NULL
	BEGIN
		SET @START = DATEADD(dd, -1, GETDATE());
	END;

	IF @REPAIR = 1
	BEGIN

		SET @SQL = '';


		-- Fin des conversation ouvertes
		DECLARE CONV CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY
		FOR SELECT DISTINCT 
				   [conversation_handle]
			FROM sys.conversation_endpoints;
		OPEN CONV;
		FETCH NEXT FROM CONV INTO @CONVERSATION_HANDLE;
		WHILE @@FETCH_STATUS = 0
		BEGIN
			END CONVERSATION @CONVERSATION_HANDLE WITH CLEANUP;
			FETCH NEXT FROM CONV INTO @CONVERSATION_HANDLE;
		END;
		CLOSE CONV;
		DEALLOCATE CONV;

		--on set le owner de la DB à sa
		SET @SQL = 'USE master;
					ALTER AUTHORIZATION ON DATABASE::' + DB_NAME() + ' TO sa;';
		EXEC sp_executesql @SQL;

		IF
		   (
			SELECT DB.is_broker_enabled
			FROM sys.databases AS DB
			WHERE DB.name = DB_NAME()
		   ) = 0
		BEGIN
			--afin d'éviter tout soucis de service_broker_id identique, on reseed
			--et on met en route le broker

			SET @SQL = 'USE master;
					ALTER DATABASE ' + DB_NAME() + ' SET NEW_BROKER WITH ROLLBACK IMMEDIATE;
					ALTER DATABASE ' + DB_NAME() + ' SET ENABLE_BROKER WITH ROLLBACK IMMEDIATE;';
			EXEC sp_executesql @SQL;
		END;

		SET @SQL = '';
		SELECT @SQL+=' ALTER QUEUE ' + name + ' WITH STATUS = ON , ACTIVATION  (STATUS = ON), POISON_MESSAGE_HANDLING (STATUS = OFF) ; 
'
		FROM sys.service_queues
		WHERE is_ms_shipped = 0;


		-- Activation des queues inactives
		EXEC sp_executesql @SQL;
	END;



	--Test 1: is SB enabled and running properly?   
	IF EXISTS
			  (
			   SELECT 'sys.databases' AS [sys.databases]
					, DB.service_broker_guid
					, DB.is_broker_enabled
					, DB.name
					, DB.database_id
			   FROM sys.databases AS DB
			   WHERE DB.database_id = DB_ID()
					 AND DB.service_broker_guid IS NOT NULL
					 AND DB.is_broker_enabled <> 1
			  ) 
	BEGIN
		INSERT INTO @WARNINGS(MSG)
		VALUES('Test 1: Service Broker is not enabled/running correctly.');
	END;


	--Test 2: look for dropped Q monitors
	IF EXISTS
			  (
			   SELECT 1
			   FROM sys.service_queues AS Q
				   INNER JOIN sys.dm_broker_queue_monitors AS MON
					   ON Q.object_id = MON.queue_id
						  AND MON.database_id = DB_ID()
			   WHERE Q.is_ms_shipped = 0 --dont show me system stuff
					 AND MON.State = 'DROPPED'
			  ) 
	BEGIN
		INSERT INTO @WARNINGS(MSG)
		VALUES('Test 2: We have DROPPED queue monitors.  Please investigate.');

	END;
	
	--Test 3: check for Qs in NOTIFIED state
	--this means that the Q activator was notified, but is not issuing the proper RECEIVE.  This could mean that the shell activator proc is enabled, or it 
	--could mean the activator is bad, or ???
	SET @TIMER = 0;
	WHILE EXISTS
				 (
				  SELECT 1
				  FROM sys.service_queues AS Q
					  INNER JOIN sys.dm_broker_queue_monitors AS MON
						  ON Q.object_id = MON.queue_id
							 AND MON.database_id = DB_ID()
				  WHERE Q.is_ms_shipped = 0 --dont show me system stuff
						AND MON.state = 'NOTIFIED'
				 ) 
	BEGIN
		SET @TIMER = @TIMER + 1;
		IF @TIMER > 5
		BEGIN
			INSERT INTO @WARNINGS(MSG)
			VALUES('WARNING: Queues exist in NOTIFIED state for over 10 seconds.  This may mean we have only a shell activator proc installed.  Please investigate.');
			BREAK;

		END;

		WAITFOR DELAY '00:00:02';  --wait 2 seconds and try again
	END;	
	
	--Test 4: are any of our activated Qs sitting in a disabled state.  This likely means the activator isn't working.  
	IF EXISTS
			  (
			   SELECT 1
			   FROM sys.service_queues
			   WHERE is_activation_enabled = 1
					 AND (is_enqueue_enabled = 0
						  OR is_receive_enabled = 0)
			  ) 
	BEGIN
		INSERT INTO @WARNINGS(MSG)
		VALUES('Test 4:  Activated Queues exist that are disabled for enqueue and receive.  
		This likely means the activator procedure is throwing errors.
		Issue the following command:  ALTER QUEUE [] WITH ACTIVATION (DROP);
		Then manually run the activation procedure that is erroring, correct the errors, and run SETUP again.');

	END;
	
	--Test 5: "Poison Message" detection
	IF EXISTS
			  (
			   SELECT 1
			   FROM sys.service_queues
			   WHERE is_receive_enabled = 0
			  ) 
	BEGIN
		INSERT INTO @WARNINGS(MSG)
		VALUES('We have disabled queues, probably from poison messages. Please investigate.
		The queue can be re-enabled with: ALTER QUEUE [] WITH STATUS = ON 
		after the problem is resolved.  ');
	END;
	
	--Test 6: do we have a "Conversation Population Explosion"?  
	--this means that we have a ton of conversations not in a CLOSED state.  
	--CLOSED conversations hang around for about 30 mins as a security precaution so just ignore them.  
	--In this case we may not have our conversations working correctly and the receiver is not ending the conversation. 
	--there is no magic to 500.  And if we ever enable Service Broker for more things then the number may need to go up.  
	IF
	   (
		SELECT COUNT(*)
		FROM sys.conversation_endpoints
		WHERE state_desc != 'CLOSED'
	   ) > 500
	BEGIN
		INSERT INTO @WARNINGS(MSG)
		VALUES('WARNING: We may not be CLOSEing conversations properly.  Please investigate.');
	END;
	
	--Test 7: do we have conversations stuck in the transmission Q?  If so something is misconfigured.  
	SET @TIMER = 0;
	WHILE EXISTS
				 (
				  SELECT 1
				  FROM sys.transmission_queue
				 ) 
	BEGIN
		SELECT @TIMER = @TIMER + 1;
		IF @TIMER > 5
		BEGIN
			INSERT INTO @WARNINGS(MSG)
			VALUES('WARNING: There may be items in the transmission_queue that are not being processed.  Or we have VERY busy queues.  Please investigate.');
			BREAK;
		END;

		WAITFOR DELAY '00:00:02';  --wait 2 seconds and try again
	END;


	--Test 8: Monitoring is not activated
	IF EXISTS
			  (
			   SELECT 1
			   FROM sys.service_queues AS Q
			   WHERE Q.is_ms_shipped = 0
					 AND NOT EXISTS
									(
									 SELECT 1
									 FROM sys.dm_broker_queue_monitors AS MON
									 WHERE Q.object_id = MON.queue_id
										   AND MON.database_id = DB_ID()
									)
			  ) 
	BEGIN
		INSERT INTO @WARNINGS(MSG)
		VALUES('Test 8: Monitoring is not activated,   EXEC USP_CHECK_BROKER @REPAIR = 1; ');

	END;


	IF NOT EXISTS
				  (
				   SELECT 1
				   FROM @WARNINGS
				  ) 
	BEGIN
		SELECT 'Service Broker OK' AS MSG;
	END;
		ELSE
	BEGIN
		SELECT WARN.MSG
		FROM @WARNINGS AS WARN
		WHERE WARN.MSG != '';

	END;

	SELECT Q.[name] AS                   QUEUE_NAME
		 , MON.[STATE] AS                [STATE]
		 , DB.IS_BROKER_ENABLED AS       IS_BROKER_ENABLED
		 , Q.IS_ENQUEUE_ENABLED AS       IS_ENQUEUE_ENABLED
		 , Q.IS_RECEIVE_ENABLED AS       IS_RECEIVE_ENABLED
		 , Q.IS_ACTIVATION_ENABLED AS    IS_ACTIVATION_ENABLED
		 , MON.TASKS_WAITING AS          TASKS_WAITING
		 , MON.LAST_ACTIVATED_TIME AS    LAST_ACTIVATED_TIME
		 , MON.LAST_EMPTY_ROWSET_TIME AS LAST_EMPTY_ROWSET_TIME
		 , Q.MAX_READERS AS              MAX_READERS
		 , Q.ACTIVATION_PROCEDURE AS     ACTIVATION_PROCEDURE
		 , Q.EXECUTE_AS_PRINCIPAL_ID AS  EXECUTE_AS_PRINCIPAL_ID
		 , SUSER_SNAME(DB.owner_sid) AS  [OWNER_NAME]
		 , DB.[name] AS                  [DB_NAME]
		 , DB.service_broker_guid
	FROM SYS.SERVICE_QUEUES AS Q
		CROSS JOIN sys.databases AS db
		LEFT JOIN sys.dm_broker_queue_monitors AS mon
			ON Q.object_id = mon.queue_id
			   AND db.database_id = mon.database_id
	WHERE db.database_id = DB_ID()
		  AND Q.IS_MS_SHIPPED = 0;

	IF @VERBOSE = 1
	BEGIN

		--just runs a bunch of misc queries that may be helpful for troubleshooting

		IF EXISTS
				  (
				   SELECT 1
				   FROM sys.transmission_queue
				  ) 
		BEGIN
			SELECT *
				 , CONVERT(XML, message_body) AS message_body_XML
				 , 'sys.transmission_queue' AS   [sys.transmission_queue]
			FROM sys.transmission_queue;
		END;

		IF EXISTS
				  (
				   SELECT 1
				   FROM sys.conversation_endpoints
				  ) 
		BEGIN
			SELECT SVC.NAME AS                        [SERVICE_NAME]
				 , Q.ACTIVATION_PROCEDURE
				 , SVC_CONTRACT.NAME AS               [CONTRACT_NAME]
				 , Q_CONTRACT.ACTIVATION_PROCEDURE AS [CONTRACT_PROCEDURE]
				 , CONV.*
				 , 'sys.conversation_endpoints' AS    [sys.conversation_endpoints]
			FROM sys.conversation_endpoints AS CONV
				INNER JOIN sys.services AS SVC
					ON SVC.SERVICE_ID = CONV.SERVICE_ID
				INNER JOIN sys.services AS SVC_CONTRACT
					ON SVC_CONTRACT.SERVICE_ID = CONV.SERVICE_CONTRACT_ID
				INNER JOIN sys.SERVICE_QUEUES AS Q
					ON Q.OBJECT_ID = SVC.SERVICE_QUEUE_ID
				LEFT JOIN sys.SERVICE_QUEUES AS Q_CONTRACT
					ON Q_CONTRACT.OBJECT_ID = SVC_CONTRACT.SERVICE_QUEUE_ID;
		END;

		IF EXISTS
				  (
				   SELECT 1
				   FROM sys.dm_broker_activated_tasks
				  ) 
		BEGIN
			SELECT *
				 , 'sys.dm_broker_activated_tasks' AS [sys.dm_broker_activated_tasks]
			FROM sys.dm_broker_activated_tasks;
		END;
		IF EXISTS
				  (
				   SELECT 1
				   FROM sys.conversation_endpoints
				  ) 
		BEGIN
			SELECT far_service
				 , state_desc
				 , COUNT(*) AS messages
			FROM sys.conversation_endpoints
			GROUP BY state_desc
				   , far_service
			ORDER BY far_service
				   , state_desc;
		END;


		-- Log SQL SERVER

		EXEC xp_readerrorlog 0
						   , 1
						   , NULL
						   , NULL
						   , @START
						   , @END
						   , 'DESC';



		--display the contents of the queues 

		DECLARE ssb CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY
		FOR SELECT Q.name
			FROM sys.service_queues AS Q
			WHERE Q.is_ms_shipped = 0;
		OPEN ssb;
		FETCH NEXT FROM ssb INTO @QNAME;
		SET @SQL = '';
		WHILE(@@fetch_status = 0)
		BEGIN
			IF @SQL != ''
			BEGIN
				SET @SQL = @SQL + ' UNION ';
			END;
			SET @SQL = @SQL + 'SELECT ''' + @QNAME + ''' AS QUEUENAME , * FROM ' + @QNAME + ' WITH (NOLOCK)';
			FETCH NEXT FROM ssb INTO @QNAME;
		END;
		CLOSE ssb;
		DEALLOCATE ssb;

		IF @SQL != ''
		BEGIN
			SET @SQL = ' DECLARE @NB INT ;
	WITH Q AS ( ' + @SQL + ' )    SELECT @NB = COUNT(*) FROM Q ;
	IF @NB >0
	WITH Q AS ( ' + @SQL + ' )    SELECT * FROM Q ;	
	';

			EXEC sp_executesql @SQL;
		END;


		-- Performance counters

		SELECT [object_name]
			 , counter_name
			 , cntr_value
			 , instance_name
		FROM sys.dm_os_performance_counters
		WHERE instance_name = DB_NAME()
			  AND counter_name IN('Tasks Running', 'Task Limit Reached', 'Tasks Aborted/sec')
		UNION
		SELECT [object_name]
			 , counter_name
			 , cntr_value
			 , instance_name
		FROM sys.dm_os_performance_counters
		WHERE counter_name IN('Activation Errors Total', 'Broker Transaction Rollbacks', 'Corrupted Messages Total', 'Enqueued TransmissionQ Msgs/sec', 'Dequeued TransmissionQ Msgs/sec', 'SQL SENDs/sec', 'SQL SEND Total', 'SQL RECEIVEs/sec', 'SQL RECEIVE Total');

	END;

END;
GO

