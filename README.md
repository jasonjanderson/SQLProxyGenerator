SQLProxyGenerator
=================

SQL Proxy Generator generates C# wrapper classes around stored procedures and user defined table types.  Since users typically don't have access to the sys.* SQL namespace this could not be done in C#.

To generate a C# class based on a SQL proc, execute the following:
```sql
EXEC dbo.GenerateProxyClass 'TestProc'
```

The output will look similar to this:
![SQL Proxy Output](http://i.imgur.com/IEm6Np1.png)

The first table contains the C# for the stored procedure; the second contains C# for the user defined table types.

Stored Procedure:
```C#

#region Imports

using System.Data;
using System.Data.SqlClient;


#endregion

namespace DataAccess
{
  public class TestProc
	{
		public const string PROCNAME = "TestProc";

		private int  _iD;
		private string  _txt;
		private TestUDT1  _testUDT1;
		private TestUDT2  _testUDT2;
		private TestUDT3  _testUDT3;


		#region Properties

		public int ID
		{
			get { return  _iD; }
			set {  _iD = value; }
		}

		public string Txt
		{
			get { return  _txt; }
			set {  _txt = value; }
		}

		public TestUDT1 TestUDT1
		{
			get { return  _testUDT1; }
			set {  _testUDT1 = value; }
		}

		public TestUDT2 TestUDT2
		{
			get { return  _testUDT2; }
			set {  _testUDT2 = value; }
		}

		public TestUDT3 TestUDT3
		{
			get { return  _testUDT3; }
			set {  _testUDT3 = value; }
		}


		#endregion
        
		public void Execute(DataTable dt)
		{
			using (SqlConnection conn = new SqlConnection(""))
			{
				using (SqlCommand cmd = new SqlCommand(PROCNAME, conn))
				{
					cmd.Parameters.Add("ID", SqlDbType.Int).Value =  _iD;
					cmd.Parameters.Add("Txt", SqlDbType.VarChar, 32).Value =  _txt;
					cmd.Parameters.Add("TestUDT1", SqlDbType.Structured).Value =  _testUDT1;
					cmd.Parameters.Add("TestUDT2", SqlDbType.Structured).Value =  _testUDT2;
					cmd.Parameters.Add("TestUDT3", SqlDbType.Structured).Value =  _testUDT3;


					using (SqlDataAdapter adapter = new SqlDataAdapter(cmd))
					{
						adapter.Fill(dt);
					}
				}
			}
		}
	}
}
```

Tables:
```C#
#region Imports

using System.Data;
using System.Threading;

#endregion

namespace DataTables
{
	public sealed class TestUDT1 : DataTable
	{
		public const string Name = "TestUDT1";
		public const string ID_Column = "ID";
		public const string LimitedLength_Column = "LimitedLength";
		public const string CharField_Column = "CharField";


		#region Constructors

		public TestUDT1() :
			base(Name)
		{
			base.Locale = Thread.CurrentThread.CurrentCulture;
            
			base.Columns.Add(ID_Column, typeof(int));
			base.Columns.Add(LimitedLength_Column, typeof(string));
			base.Columns.Add(CharField_Column, typeof(string));

		}

		#endregion
	}
}
```
