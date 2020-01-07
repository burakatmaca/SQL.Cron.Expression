CREATE FUNCTION [dbo].[Cron.Schedule.Control]
(
	@expression NVARCHAR(MAX),
	@date DATETIME NULL
)
RETURNS BIT
AS
BEGIN
	
	-- *  *  *  *  *  
	-- ┬  ┬  ┬  ┬  ┬
	-- │  │  │  │  └─── day of week(0 - 6) (Sunday=0 )
	-- │  │  │  └────── month(1 - 12)
	-- │  │  └───────── day of month(1 - 31)
	-- │  └──────────── hour(0 - 23)
	-- └─────────────── min (0 - 59)

	--  * * * * *        Every minute.
	--  0 * * * *        Top of every hour.
	--  0,1,2 * * * *    Every hour at minutes 0, 1, and 2.
	--  */2 * * * *      Every two minutes.
	--  1-55 * * * *     Every minute through the 55th minute.
	--  * 1,10,20 * * *  Every 1st, 10th, and 20th hours.

	DECLARE @result BIT = 1;
	DECLARE @now DATETIME = ISNULL(@date, GETDATE());
	DECLARE @month INT = MONTH(@now),
			@dayOfWeek INT = DATEPART(DW, @now) - 1,
			@day INT = DAY(@now),
			@hour INT = TRY_CONVERT(INT, FORMAT(@now, 'HH')),
			@minute INT = TRY_CONVERT(INT, FORMAT(@now, 'mm'));

	DECLARE @cron_month NVARCHAR(MAX),
			@cron_dayOfWeek NVARCHAR(MAX),
			@cron_day NVARCHAR(MAX),
			@cron_hour NVARCHAR(MAX),
			@cron_minute NVARCHAR(MAX);

	SELECT 
		@cron_minute = P0.[1],
		@cron_hour = P0.[2],
		@cron_day = P0.[3],
		@cron_month = P0.[4],
		@cron_dayOfWeek = P0.[5]
	FROM (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT 1)) [Id], S0.[value] [Data] FROM [string_split](@expression, ' ') S0) T0
	PIVOT(
		MAX(T0.[Data])
		FOR T0.[Id] IN ([1], [2], [3], [4], [5])
	) P0

	IF ((@cron_minute IS NULL) OR 
		(@cron_hour IS NULL) OR 
		(@cron_day IS NULL) OR 
		(@cron_month IS NULL) OR 
		(@cron_dayOfWeek IS NULL))
		BEGIN
			SET @result &= 0;
		END
	ELSE
		BEGIN
			SET @result &= [dbo].[Cron.Expression](@cron_minute, @minute);
			SET @result &= [dbo].[Cron.Expression](@cron_hour, @hour);
			SET @result &= [dbo].[Cron.Expression](@cron_day, @day);
			SET @result &= [dbo].[Cron.Expression](@cron_month, @month);
			SET @result &= [dbo].[Cron.Expression](@cron_dayOfWeek, @dayOfWeek);
		END

	RETURN @result;

END
GO