DECLARE
	@count bigint;

SET @count = 0;
WHILE(1 = 1)
BEGIN
	

	IF @count >= 3
	begin
		print 'A print message'
		select 1 as Result;
	end

	if @count = 4
	begin
		exec('SELECT 1/0 as Error')
	end

	
	

	raiserror('Generate by raiserror',0,1) with nowait;

	if @count >= 5
		return;
	
	waitfor delay '00:00:01';
	set @count = @count + 1;
END