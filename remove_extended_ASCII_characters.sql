SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
use  <database_name>
go
--Query to remove Extended Character from Consumer Details to avoid any issue in Checks processing
Declare @case_num       	int
Declare @name_key 			int
Declare @special_char_ascii	int
Declare @special_char		char(1)
Declare @reference			char(40)

DECLARE @asciichars TABLE (dec_value TINYINT NOT NULL, char_value AS CHAR(dec_value) COLLATE Latin1_General_CS_AS PERSISTED NOT NULL)

--Fill in table var with numbers from 128 to 255 {extended ASCII dec values}
INSERT INTO @asciichars(dec_value)
SELECT rownum
FROM 
( SELECT ROW_NUMBER() OVER(ORDER BY object_id) AS rownum FROM sys.columns  ) AS nums
WHERE rownum BETWEEN 128 AND 255

/*************************************************CASE REFERENCE CHECK STARTS HERE*****************************************************************/
--Create Cursor to find extended ascii character in reference field
DECLARE find_case_reference CURSOR 
FOR 
SELECT DISTINCT  b.dec_value as special_char_ascii,b.char_value as special_char,t.reference ,t.case_num,t.name_key
FROM  dbo.checks_to_send_tbl t with(nolock) 
CROSS APPLY (
SELECT a.dec_value, a.char_value, 
PATINDEX('%' + CHAR(a.dec_value) +'%' COLLATE Latin1_General_CS_AS, t.reference COLLATE Latin1_General_CS_AS) AS reference_patindex 
FROM @asciichars AS a) AS b
WHERE  
( b.reference_patindex > 0 AND ASCII(SUBSTRING(t.reference, b.reference_patindex ,1)) = b.dec_value ) 

OPEN find_case_reference  

FETCH NEXT FROM find_case_reference  
INTO @special_char_ascii, @special_char ,@reference ,@case_num,@name_key

WHILE @@FETCH_STATUS = 0 
BEGIN 

print 'Cursor for Reference check Starts'

If  (@special_char_ascii >= 128 and @special_char_ascii <= 255 ) 
 Begin

	Print @special_char_ascii 
	Print @special_char 
	Print @reference 
	Print @case_num 
	Print @name_key 

	Select @reference = replace(@reference,@special_char,' ')

	Update checks_to_send_tbl Set reference = @reference
	Where name_key = @name_key
	and case_num=@case_num

	Select @special_char_ascii = 0
 End

FETCH NEXT FROM find_case_reference  
INTO @special_char_ascii, @special_char ,@reference ,@case_num,@name_key

END

CLOSE find_case_reference
DEALLOCATE find_case_reference
/*************************************************CASE REFERENCE CHECK ENDS HERE*****************************************************************/
