USE [my_db]
GO
/****** Object:  UserDefinedFunction [dbo].[expected_payments]    Script Date: 31.05.2018 3:16:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [dbo].[expected_payments] (@to_date DATE)
RETURNS @payments TABLE(contract_number INT, payment MONEY, expected_date DATE, name VARCHAR(100), bank_account VARCHAR(30)) AS
BEGIN
	DECLARE my_cur CURSOR FOR SELECT number, yacht_id, client_id, payment_scheme, paid_until, expected_closing_date, money_paid
							  FROM contracts
							  WHERE actual_closing_date IS NULL
	DECLARE @contract_number INT
	DECLARE @yacht_id INT
	DECLARE @payment_scheme CHAR(13)
	DECLARE @paid_until DATE
	DECLARE @expected_closing_date DATE
	DECLARE @money_paid MONEY
	DECLARE @client_id VARCHAR(20)
	DECLARE @name VARCHAR(100)
	DECLARE @bank_account VARCHAR(30)
	DECLARE @per_month MONEY
	DECLARE @per_day MONEY
	OPEN my_cur
	FETCH NEXT FROM my_cur INTO  @contract_number, @yacht_id, @client_id, @payment_scheme, @paid_until, @expected_closing_date, @money_paid

	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		IF(DATEDIFF(day, @paid_until, @expected_closing_date) >= 0)
		BEGIN
			SET @name = (SELECT name
						 FROM clients
						 WHERE id = @client_id)
			SET @bank_account = (SELECT bank_account
								 FROM clients
								 WHERE id = @client_id)
			IF(@payment_scheme = 'half upfront')
			BEGIN
				IF(DATEDIFF(day, @expected_closing_date, @to_date) >= 0)
				BEGIN
					INSERT INTO @payments
					VALUES(@contract_number, @money_paid, @expected_closing_date, @name, @bank_account)
				END
			END
			IF(@payment_scheme = 'monthly')
			SET @per_month = (SELECT cost_per_month
							  FROM classes
							  JOIN yachts
							  ON rang = class_rang
							  WHERE id = @yacht_id)
			SET @per_day = (SELECT cost_per_day
							FROM classes
							JOIN yachts
							ON rang = class_rang
							WHERE id = @yacht_id)

			BEGIN
				WHILE(DATEDIFF(day, @paid_until, @expected_closing_date) > 29)
				BEGIN
					SET @paid_until = DATEADD(day, 30, @paid_until)
					IF(DATEDIFF(day, @to_date, @paid_until) > 0)
						BREAK
					INSERT INTO @payments (contract_number,  payment,    expected_date, name,  bank_account)
					VALUES                (@contract_number, @per_month, @paid_until,   @name, @bank_account)
				END

				IF(DATEDIFF(day, @to_date, @paid_until) <= 0 AND DATEDIFF(day, @paid_until, @expected_closing_date) > 0)
				BEGIN
					INSERT INTO @payments (contract_number,  payment,                                                         expected_date,          name,  bank_account)
					VALUES                (@contract_number, (DATEDIFF(day, @paid_until, @expected_closing_date)) * @per_day, @expected_closing_date, @name, @bank_account)
				END
			END
		END
		FETCH NEXT FROM my_cur INTO  @contract_number, @yacht_id, @client_id, @payment_scheme, @paid_until, @expected_closing_date, @money_paid
	END
	CLOSE my_cur
	DEALLOCATE my_cur
	RETURN
END