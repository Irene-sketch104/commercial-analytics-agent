
# Example SQL Server connection configuration
# Copy this file to 02_connection.R and configure it locally.
# Never commit passwords or private credentials.

library(DBI)
library(odbc)

con <- DBI::dbConnect(
  odbc::odbc(),
  Driver = "ODBC Driver 18 for SQL Server",
  Server = Sys.getenv("SQL_SERVER", unset = "YOUR_SERVER_NAME"),
  Database = Sys.getenv("SQL_DATABASE", unset = "B2BLeadAnalytics"),
  Trusted_Connection = "Yes",
  Encrypt = "Yes",
  TrustServerCertificate = "Yes"
)
