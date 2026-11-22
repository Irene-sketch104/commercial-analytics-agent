# Commercial Analytics Agent
# Environment Setup

# Install required packages if missing
packages <- c("DBI", "odbc", "ellmer", "shiny")

for (pkg in packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg)
  }
}

# Load database packages
library(DBI)
library(odbc)

# Check available ODBC drivers
print(odbcListDrivers())
