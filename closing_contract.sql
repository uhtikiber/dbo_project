USE [my_db]
GO
/****** Object:  StoredProcedure [dbo].[close_contract]    Script Date: 31.05.2018 4:11:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[close_contract] (@contract_number INT,  @curr_date DATE = NULL) AS
BEGIN
	IF(@curr_date IS NULL)
		SET @curr_date = CURRENT_TIMESTAMP
	DECLARE @actual_closing DATE = (SELECT actual_closing_date
									FROM contracts
									WHERE number = @contract_number)
	IF(@actual_closing IS NOT NULL)
	BEGIN
		RAISERROR('The contract is already closed', 14, 1)
		RETURN
	END

	DECLARE @payment_scheme CHAR(13) = (SELECT payment_scheme
									    FROM contracts
							            WHERE number = @contract_number)
	DECLARE @paid_until DATE = (SELECT paid_until
							    FROM contracts
							    WHERE number = @contract_number)
	DECLARE @money MONEY = 0
	DECLARE @closing DATE = (SELECT expected_closing_date
							 FROM contracts
							 WHERE number = @contract_number)
	DECLARE @yacht_id INT = (SELECT yacht_id
							 FROM contracts
							 WHERE number = @contract_number)
	
	DECLARE @to_closing INT = DATEDIFF(day, @paid_until, @closing);
	DECLARE @from_closing INT = DATEDIFF(day, @closing, @curr_date);
	DECLARE @per_month MONEY = (SELECT cost_per_month
								FROM classes
								WHERE rang = (SELECT class_rang
											  FROM yachts
											  WHERE id = @yacht_id));
	DECLARE @per_day MONEY = (SELECT cost_per_day
								FROM classes
								WHERE rang = (SELECT class_rang
											  FROM yachts
											  WHERE id = @yacht_id));
	DECLARE @per_day_overdue MONEY = (SELECT cost_per_day_overdue
									  FROM classes
									  WHERE rang = (SELECT class_rang
													FROM yachts
													WHERE id = @yacht_id));
	IF(@payment_scheme = 'upfront') 
	BEGIN
		SET @money = @per_day_overdue * @from_closing;
	END

	IF(@payment_scheme = 'half upfront')
	BEGIN
		SET @money = (SELECT money_paid
					  FROM contracts
					  WHERE number = @contract_number)
		SET @money = @money + @per_day_overdue * @from_closing
	END
	
	IF(@payment_scheme = 'monthly')
	BEGIN
		WHILE(DATEDIFF(day, @paid_until, @closing) >= 30)
		BEGIN
			EXEC accept_payment @contract_number, @curr_date
			SET @paid_until = DATEADD(day, 30, @paid_until)
		END
		SET @money = @money + @per_day * DATEDIFF(day, @paid_until, @closing) + @per_day_overdue * @from_closing

	END

	DECLARE @prev_money MONEY = (SELECT money_paid
							     FROM contracts
							     WHERE number = @contract_number)
	SET @money = @money + @prev_money

	UPDATE contracts 
	SET paid_until = @curr_date, actual_closing_date = @curr_date, money_paid = @money
	WHERE number = @contract_number

	PRINT 'The payment for ' + CAST(@per_month AS VARCHAR(20)) + ' successfully came through'

	UPDATE yachts
	SET placement = 'in port'
	WHERE id = @yacht_id

	PRINT 'The contract ' + CAST(@contract_number AS VARCHAR(10)) + ' is closed'
END