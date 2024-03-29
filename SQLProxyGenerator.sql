
CREATE PROCEDURE [dbo].[GenerateProxyClass]
(
	@ProcName VARCHAR(128),
	@NameSpace VARCHAR(128) = 'DataAccess',
	@ConnectionString VARCHAR(128) = '""'

)
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @NewLine CHAR(1) = CHAR(13)
	DECLARE @Tab CHAR(1) = CHAR(9)


	/* BEGIN ================================================================= Templates ================================================================= BEGIN */

	DECLARE @ClassTemplate VARCHAR(MAX) = 
	'
#region Imports

%Imports%

#endregion

namespace %Namespace%
{
	public class %ProcName%
	{
		public const string PROCNAME = "%ProcName%";

		%MemberVariables%

		#region Properties

		%Properties%

		#endregion
        
		public void Execute(DataTable dt)
		{
			using (SqlConnection conn = new SqlConnection(%ConnectionString%))
			{
				using (SqlCommand cmd = new SqlCommand(PROCNAME, conn))
				{
					%Parameters%

					using (SqlDataAdapter adapter = new SqlDataAdapter(cmd))
					{
						adapter.Fill(dt);
					}
				}
			}
		}
	}
}
'

	DECLARE @ImportTemplate VARCHAR(MAX) = 'using %Import%;' + @NewLine
	DECLARE @PropertyTemplate VARCHAR(MAX) =  
		@NewLine + @Tab + @Tab + 'public %PropertyTypeName% %PropertyName%'
		+ @NewLine + @Tab + @Tab + '{' 
		+ @NewLine + @Tab + @Tab + @Tab + 'get { return %MemberName%; }'
		+ @NewLine + @Tab + @Tab + @Tab + 'set { %MemberName% = value; }'
		+ @NewLine + @Tab + @Tab + '}'
		+ @NewLine

	DECLARE @MemberTemplate VARCHAR(MAX) =	@Tab + @Tab + 'private %MemberTypeName% %MemberName%;' + @NewLine
	DECLARE @ParameterTemplate VARCHAR(MAX) = @Tab + @Tab + @Tab + @Tab + @Tab + 'cmd.Parameters.Add("%ParameterName%", SqlDbType.%SQLDBTypeName%).Value = %MemberName%;' + @NewLine
	DECLARE @LengthRestrictedParameterTemplate VARCHAR(MAX) = @Tab + @Tab + @Tab + @Tab + @Tab + 'cmd.Parameters.Add("%ParameterName%", SqlDbType.%SQLDBTypeName%, %MaxLength%).Value = %MemberName%;' + @NewLine
	DECLARE @Output VARCHAR(MAX) = @ClassTemplate


	DECLARE @TableTypeTemplate VARCHAR(MAX) =
	'
#region Imports

using System.Data;
using System.Threading;

#endregion

namespace DataTables
{
	public sealed class %TableName% : DataTable
	{
		public const string Name = "%TableName%";
		%ColumnConstants%

		#region Constructors

		public %TableName%() :
			base(Name)
		{
			base.Locale = Thread.CurrentThread.CurrentCulture;
            
			%Columns%
		}

		#endregion
	}
}
	'

	DECLARE @ColumnConstantTemplate VARCHAR(MAX) = @Tab + @Tab + 'public const string %ColumnName%_Column = "%ColumnName%";' + @NewLine
	DECLARE @ColumnTemplate VARCHAR(MAX) = @Tab + @Tab + @Tab + 'base.Columns.Add(%ColumnName%_Column, typeof(%TableType%));' + @NewLine

	/* END ================================================================= Templates ================================================================= END */


	DECLARE @Imports TABLE (
		Import VARCHAR(256) PRIMARY KEY
	)

	INSERT INTO @Imports (
		Import
	) VALUES 
		('System.Data'),
		('System.Data.SqlClient')


	DECLARE @TypeMap TABLE (
		SQLTypeName VARCHAR(128) NOT NULL,
		DotNetTypeName VARCHAR(128) NOT NULL,
		SQLDBTypeName VARCHAR(128) NOT NULL,
		RestrictLength BIT NOT NULL
	)

	-- Define the C# to SQL to SQLDBType mappings
	INSERT INTO @TypeMap (
		SQLTypeName, 
		DotNetTypeName, 
		SQLDBTypeName,  
		RestrictLength
	)
	VALUES
		('text', 'string', 'Text', 1),
		('date', 'DateTime', 'Date', 0),
		('time', 'TimeSpan', 'Time', 0),
		('datetime2', 'DateTime', 'DateTime2', 0),
		('datetimeoffset', 'DateTime', 'DateTimeOffset', 0),
		('tinyint', 'short', 'TinyInt', 0),
		('smallint', 'short', 'SmallInt', 0),
		('int', 'int', 'Int', 0),
		('smalldatetime', 'DateTime', 'SmallDateTime', 0),
		('real', 'Single', 'Real', 0),
		('money', 'decimal', 'Money', 0),
		('datetime', 'DateTime', 'DateTime', 0),
		('float', 'double', 'Float', 0),
		--('sql_variant', 'object', ''),
		('ntext', 'string', 'NText', 1),
		('bit', 'bool', 'Bit', 0),
		('decimal', 'decimal', 'Decimal', 0),
		('numeric', 'decimal', 'Decimal', 0),
		('smallmoney', 'decimal', 'SmallMoney', 0),
		('bigint', 'long', 'BigInt', 0),
		--('geography', 'SqlGeography', ''),
		('varbinary', 'Byte[]', 'VarBinary', 1),
		('varchar', 'string', 'VarChar', 1),
		('binary', 'Byte[]', 'Binary', 1),
		('char', 'string', 'Char', 1),  -- if 1 char use char
		('timestamp', 'Byte[]', 'TimeStamp', 0),
		('nvarchar', 'string', 'NVarChar', 1),
		('nchar', 'string', 'NChar', 1),  -- if 1 char use char
		('xml', 'Xml', 'Xml', 0)


	-- Add custom structured types to the type map
	INSERT INTO @TypeMap (
		SQLTypeName, 
		DotNetTypeName, 
		SQLDBTypeName,
		RestrictLength
	)
	SELECT
		t.name,
		t.name,
		'Structured',
		0
	FROM sys.types t WITH (NOLOCK)
	WHERE t.is_table_type = 1


	-- Define proc parameters 
	DECLARE @Parameters TABLE (
		ParameterName VARCHAR(128) NOT NULL,
		ID INT NOT NULL,
		MemberName VARCHAR(128) NOT NULL,
		TypeID INT NOT NULL,
		SQLTypeName VARCHAR(128) NOT NULL,
		DotNetTypeName VARCHAR(128) NOT NULL,
		SQLDBTypeName VARCHAR(128) NOT NULL,
		MaxLength INT NULL,
		IsTableType BIT NOT NULL,
		IsOutput BIT NOT NULL,
		HasDefaultValue BIT NOT NULL,
		DefaultValue SQL_VARIANT,
		IsReadOnly BIT NOT NULL
	)

	INSERT INTO @Parameters (
		ParameterName,
		ID,
		MemberName,
		TypeID,
		SQLTypeName,
		DotNetTypeName,
		SQLDBTypeName,
		MaxLength,
		IsTableType,
		IsOutput, 
		HasDefaultValue, 
		DefaultValue, 
		IsReadOnly
	)
	SELECT 
		SUBSTRING(p.name, 2, 127),
		p.parameter_id, 
		' _' + LOWER(SUBSTRING(p.Name, 2, 1)) + SUBSTRING(p.Name, 3, 126),
		p.user_type_id, 
		tm.SQLTypeName,
		tm.DotNetTypeName,
		tm.SQLDBTypeName,
		CASE WHEN tm.RestrictLength = 1 THEN p.max_length ELSE NULL END,
		t.is_table_type,
		p.is_output, 
		p.has_default_value, 
		p.default_value, 
		p.is_readonly
	FROM sys.objects o WITH (NOLOCK)
	INNER JOIN sys.parameters p WITH (NOLOCK)
		ON o.object_id = p.object_id
	INNER JOIN sys.types t WITH (NOLOCK)
		ON p.user_type_id = t.user_type_id
	INNER JOIN @TypeMap tm
		ON t.name = tm.SQLTypeName
	WHERE 
		o.name = @ProcName



	DECLARE @ImportsOutput VARCHAR(8000) = ''
	SELECT
		@ImportsOutput += REPLACE(@ImportTemplate, '%Import%', i.Import) 
	FROM @Imports i

	SET @Output = REPLACE(@Output, '%Imports%', SUBSTRING(@ImportsOutput, PATINDEX('%[a-zA-Z0-9]%', @ImportsOutput), LEN(@ImportsOutput)))

	SET @Output = REPLACE(@Output, '%Namespace%', @Namespace)

	SET @Output = REPLACE(@Output, '%ProcName%', @ProcName)


	DECLARE @MemberOutput VARCHAR(8000) = ''
	SELECT 
		@MemberOutput += REPLACE(REPLACE(@MemberTemplate, '%MemberTypeName%', p.DotNetTypeName), '%MemberName%', p.MemberName)
	FROM @Parameters p

	SET @Output = REPLACE(@Output, '%MemberVariables%', SUBSTRING(@MemberOutput, PATINDEX('%[a-zA-Z0-9]%', @MemberOutput), LEN(@MemberOutput)))

	DECLARE @PropertyOutput VARCHAR(MAX) = '' 




	SELECT 
		@PropertyOutput += REPLACE(REPLACE(REPLACE(@PropertyTemplate, '%PropertyTypeName%', p.DotNetTypeName), '%PropertyName%', p.ParameterName), '%MemberName%', p.MemberName)
	FROM @Parameters p
				

	SET @Output = REPLACE(@Output, '%Properties%', SUBSTRING(@PropertyOutput, PATINDEX('%[a-zA-Z0-9]%', @PropertyOutput), LEN(@PropertyOutput)))

	SET @Output = REPLACE(@Output, '%ConnectionString%', @ConnectionString)

	DECLARE @ParameterOutput VARCHAR(MAX) = ''

	SELECT 
		@ParameterOutput += CASE 
			WHEN p.MaxLength IS NULL THEN 
				REPLACE(REPLACE(REPLACE(@ParameterTemplate, '%ParameterName%', p.ParameterName), '%SQLDBTypeName%', p.SQLDBTypeName), '%MemberName%', p.MemberName)
			ELSE
				REPLACE(REPLACE(REPLACE(REPLACE(@LengthRestrictedParameterTemplate, '%ParameterName%', p.ParameterName), '%SQLDBTypeName%', p.SQLDBTypeName), '%MaxLength%', CAST(p.MaxLength AS VARCHAR(5))), '%MemberName%', p.MemberName)
		END
	FROM @Parameters p

	SET @Output = REPLACE(@Output, '%Parameters%', SUBSTRING(@ParameterOutput, PATINDEX('%[a-zA-Z0-9]%', @ParameterOutput), LEN(@ParameterOutput)))


	-- Output proxy class code
	SELECT 
		@ProcName AS ProcName,
		@Output AS Code

	DECLARE @TableTypes TABLE (
		TableTypeName VARCHAR(128) NOT NULL,
		ColumnName VARCHAR(128) NOT NULL,
		DotNetTypeName VARCHAR(128) NOT NULL,
		IsNullable BIT NOT NULL,
		IsPrimaryKey BIT NOT NULL
	)


	INSERT INTO @TableTypes (
		TableTypeName,
		ColumnName,
		DotNetTypeName,
		IsNullable,
		IsPrimaryKey
	)
	SELECT 
		tt.name,
		c.name,
		tm.DotNetTypeName,
		c.is_nullable,
		CASE WHEN i.is_primary_key IS NOT NULL AND c.column_id = ic.column_id THEN i.is_primary_key ELSE 0 END
	FROM sys.table_types tt WITH (NOLOCK)
	INNER JOIN sys.columns c WITH (NOLOCK)
		ON tt.type_table_object_id = c.object_id
	INNER JOIN sys.types t WITH (NOLOCK)
		ON c.user_type_id = t.user_type_id
	INNER JOIN @TypeMap tm
		ON t.name = tm.SQLTypeName
	LEFT OUTER JOIN sys.indexes i WITH (NOLOCK)
		ON tt.type_table_object_id = i.object_id
	LEFT OUTER JOIN sys.index_columns ic WITH (NOLOCK)
		ON tt.type_table_object_id = ic.object_id 
		AND c.column_id = ic.column_id


	DECLARE @TableOutput TABLE
	(
		TableName VARCHAR(128) NOT NULL,
		Code VARCHAR(MAX) NOT NULL

		PRIMARY KEY
		(
			TableName ASC
		)
	)

	INSERT INTO @TableOutput
	(
		TableName,
		Code
	)
	SELECT
		tt.TableTypeName,
		REPLACE(@TableTypeTemplate, '%TableName%', tt.TableTypeName)
	FROM @TableTypes tt
	GROUP BY
		tt.TableTypeName

	-- Use recursive CTEs to concat DataTable columns and constants.
	;
	WITH 
	RANKEDUDTS(TableTypeName, OutputRank, ColumnConstantOutput, ColumnOutput) 
	AS (
		SELECT 
			tt.TableTypeName,
			ROW_NUMBER() OVER( PARTITION BY tt.TableTypeName ORDER BY tt.TableTypeName ),
			CAST(REPLACE(@ColumnConstantTemplate, '%ColumnName%', tt.ColumnName) AS VARCHAR(8000)),
			CAST(REPLACE(REPLACE(@ColumnTemplate, '%ColumnName%', tt.ColumnName), '%TableType%', tt.DotNetTypeName) AS VARCHAR(8000))
		FROM @TableTypes tt
	),
	RECURUDTS (TableTypeName, OutputRank, ColumnConstantOutput, ColumnOutput)
	AS (
		SELECT 
			ru.TableTypeName, 
			ru.OutputRank, 
			ru.ColumnConstantOutput,
			ru.ColumnOutput
		FROM RANKEDUDTS ru
		WHERE
			ru.OutputRank = 1
		UNION ALL
		SELECT 
			ru.TableTypeName, 
			ru.OutputRank,
			rud.ColumnConstantOutput + ru.ColumnConstantOutput,
			rud.ColumnOutput + ru.ColumnOutput
		FROM RANKEDUDTS ru
		INNER JOIN RECURUDTS rud
		ON ru.TableTypeName = rud.TableTypeName
			AND ru.OutputRank = rud.OutputRank + 1 
	),
	UDTS
	AS (
		SELECT
			ru.TableTypeName,
			SUBSTRING(ru.ColumnConstantOutput, PATINDEX('%[a-zA-Z0-9]%', ru.ColumnConstantOutput), LEN(ru.ColumnConstantOutput)) AS ColumnConstantOutput,
			SUBSTRING(ru.ColumnOutput, PATINDEX('%[a-zA-Z0-9]%', ru.ColumnOutput), LEN(ru.ColumnOutput)) AS ColumnOutput,
			ROW_NUMBER() OVER (PARTITION BY TableTypeName ORDER BY OutputRank DESC) AS RowNo
		FROM RECURUDTS ru
	)

	-- Output UDT proxy classes
	SELECT
		t.TableName,
		REPLACE(REPLACE(t.Code, '%ColumnConstants%', u.ColumnConstantOutput), '%Columns%', u.ColumnOutput) AS Code
	FROM @TableOutput t
	INNER JOIN UDTS u
	ON t.TableName = u.TableTypeName
	WHERE 
		u.RowNo = 1
END


/*

EXEC dbo.GenerateProxyClass 'GenerateProxyClass'

*/