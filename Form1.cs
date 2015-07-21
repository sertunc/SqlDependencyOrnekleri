using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Drawing;
using System.Linq;
using System.Security.Permissions;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace SqlDependencyOrnekleri
{
    public partial class Form1 : Form
    {
        public static string mStarterConnectionString = ConfigurationManager.ConnectionStrings["mStarterConnectionString"].ConnectionString;
        public static string mSubscriberConnectionString = ConfigurationManager.ConnectionStrings["mSubscriberConnectionString"].ConnectionString;

        public Form1()
        {
            InitializeComponent();
        }

        private void Form1_Load(object sender, EventArgs e)
        {
            // Starting the listener infrastructure...
            SqlDependency.Start(mStarterConnectionString);

            // Registering for changes... 
            RegisterForChanges();

            // Quitting...
            //SqlDependency.Stop(mStarterConnectionString);
        }

        public string[] RegisterForChanges()
        {
            string[] result = null;

            using (SqlConnection conn = new SqlConnection(mSubscriberConnectionString))
            {
                if (conn.State != ConnectionState.Open) conn.Open();

                using (SqlCommand cmd = new SqlCommand("SELECT [BilgilendirmeTipi],[Baslik],[Icerik] FROM [dbo].[Bilgilendirmeler]", conn))
                {
                    SqlDependency dependency = new SqlDependency(cmd);
                    dependency.OnChange += new OnChangeEventHandler(OnNotificationChange);

                    using (SqlDataAdapter adap = new SqlDataAdapter(cmd))
                    {
                        using (DataTable dt = new DataTable())
                        {
                            adap.Fill(dt);
                            if (dt.Rows.Count > 0)
                            {
                                result = new string[3];

                                result[0] = (string)dt.Rows[0][0];
                                result[1] = (string)dt.Rows[0][1];
                                result[2] = (string)dt.Rows[0][2];
                            }
                        }
                    }
                }
            }

            return result;
        }

        public void OnNotificationChange(object caller, SqlNotificationEventArgs e)
        {
            string[] sonuc = RegisterForChanges();

            MessageBox.Show(sonuc[0] + " " + sonuc[1] + " " + sonuc[2]);
        }

        private void Form1_FormClosing(object sender, FormClosingEventArgs e)
        {
            SqlDependency.Stop(mStarterConnectionString);
        }
    }
}
