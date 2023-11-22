CREATE PROCEDURE [Tools].[Get_InvalidSqlModules_p]
AS
BEGIN

	SET NOCOUNT, XACT_ABORT ON;

	DROP TABLE IF EXISTS #sql_modules;
	SELECT

		 [id] = ROW_NUMBER() OVER ( ORDER BY [schema_id], [name] )
		,[schema] = SCHEMA_NAME( [schema_id] )
		,[name]
		,[is_invalid] = CONVERT( BIT, 0 )
		,[error_message] = CONVERT( NVARCHAR(4000), NULL )

	INTO #sql_modules
	FROM sys.objects
	WHERE TYPE IN (

		'FN' -- Scalar function
		,'IF' -- Inline table-valued function
		,'P'  -- Stored procedure
		,'TF' -- Table-valued function
		,'V'  -- View
	)
	;

	DECLARE @id INT = 0;
	DECLARE @sql_module NVARCHAR(241);
	DECLARE @error_message NVARCHAR(4000);

	WHILE 1=1
	BEGIN

		SET @id = (
			SELECT TOP 1 [id]
			FROM #sql_modules
			WHERE [id] > @id
			ORDER BY [id] ASC
		);

		IF @id IS NULL
			BREAK;

		SELECT @sql_module = CONCAT( N'[', [schema], N'].[', [name], N']' )
		FROM #sql_modules
		WHERE [id] = @id
		;

		BEGIN TRY

			BEGIN TRAN; -- Without transaction, object last modified date would be updated

			EXEC sp_refreshsqlmodule @sql_module;

			IF @@TRANCOUNT > 0
				ROLLBACK TRAN;

		END TRY
		BEGIN CATCH

			IF @@TRANCOUNT > 0
				ROLLBACK TRAN;

			UPDATE #sql_modules
			SET
				 [is_invalid] = 1
				,[error_message] = ERROR_MESSAGE()
			WHERE [id] = @id
			;

		END catch

	END -- while 1=1

	SELECT *
	FROM #sql_modules
	WHERE [is_invalid] = 1
	ORDER BY [schema], [name]
	;
	RETURN 0

END