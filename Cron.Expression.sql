CREATE FUNCTION [dbo].[Cron.Expression]
(
	@expression NVARCHAR(MAX),
	@value INT
)
RETURNS BIT
AS
BEGIN
	DECLARE @result BIT = 1;
		
	IF (@expression = '*') SET @result &= 1;
	ELSE IF (ISNUMERIC(@expression) = 1)
		SET @result = IIF(CONVERT(INT, @expression) = @value, 1, 0);
	ELSE IF (@expression LIKE '%,%')
		SET @result &=
			IIF(EXISTS (
				SELECT * 
				FROM [string_split](@expression, ',') S0 
				WHERE S0.[value] = @value
			), 1, 0);
	ELSE IF (@expression LIKE '%-%')
		SET @result &= 
			IIF(EXISTS(
				SELECT *
				FROM (
					SELECT ROW_NUMBER() OVER (ORDER BY (SELECT 1)) [Id], CONVERT(INT, S0.[value]) [Data] 
					FROM [string_split](@expression, '-') S0 
					WHERE TRY_CONVERT(INT, S0.[value]) IS NOT NULL) T0
				PIVOT(
					MAX(T0.[Data])
					FOR T0.[Id] IN ([1], [2])
				) P0
				WHERE (@value BETWEEN P0.[1] AND P0.[2])
			), 1, 0);
	ELSE IF (@expression LIKE '%/%')
		SET @result &= 
			IIF(EXISTS(
				SELECT *
				FROM (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT 1)) [Id], S0.[value] [Data] FROM [string_split](@expression, '/') S0) T0
				PIVOT(
					MAX(T0.[Data])
					FOR T0.[Id] IN ([1], [2])
				) P0
				WHERE (P0.[1] = '*') AND (@value % TRY_CONVERT(INT, P0.[2])) = 0
			), 1, 0);
	ELSE SET @result &= 0;

	RETURN @result;
END