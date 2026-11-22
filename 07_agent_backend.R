
# Stage 06.3 — Multi-tool selection test

library(ellmer)
library(DBI)

# 1. Connect to SQL Server
source("02_connection.R")

# 2. Load existing analytics functions
source("03_tools.R")

stopifnot(DBI::dbIsValid(con))
cat("[DATABASE CONNECTED]\n")


# 3. Tool A: Total leads

total_leads_wrapper <- function(metric) {

  if (!identical(metric, "total_leads")) {
    stop("Unsupported metric.")
  }

  cat("\n[TOOL EXECUTED] get_total_leads()\n")

  result <- get_total_leads()

  paste(capture.output(print(result)), collapse = "\n")
}

tool_a <- tool(
  total_leads_wrapper,
  name = "get_total_leads",
  description = paste(
    "Retrieve the total number of leads",
    "from SQL Server.",
    "Use for questions about total lead count.",
    "Set metric to 'total_leads'."
  ),
  arguments = list(
    metric = type_string(
      "Must be 'total_leads'."
    )
  )
)


# 4. Tool B: Conversion by segment

conversion_wrapper <- function(segment) {

  cat(
    "\n[TOOL EXECUTED] get_conversion_by_segment(",
    segment,
    ")\n",
    sep = ""
  )

  # The original function validates allowed segments
  result <- get_conversion_by_segment(segment)

  paste(capture.output(print(result)), collapse = "\n")
}

tool_b <- tool(
  conversion_wrapper,
  name = "get_conversion_by_segment",
  description = paste(
    "Retrieve B2B lead conversion rates",
    "grouped by a business segment from SQL Server.",
    "Use for comparing conversion performance",
    "by lead source, seniority, or buyer role.",
    "Allowed segment values: lead_source, seniority, buyer_role."
  ),
  arguments = list(
    segment = type_string(
      "Grouping dimension: lead_source, seniority, or buyer_role."
    )
  )
)


# Tool C: Overall conversion rate

conversion_rate_wrapper <- function(metric) {

  if (!identical(metric, "conversion_rate")) {
    stop("Unsupported metric.")
  }

  cat("\n[TOOL EXECUTED] get_conversion_rate()\n")

  result <- get_conversion_rate()

  paste(capture.output(print(result)), collapse = "\n")
}

tool_c <- tool(
  conversion_rate_wrapper,
  name = "get_conversion_rate",
  description = paste(
    "Retrieve the overall B2B lead conversion rate",
    "across all leads in the SQL Server database.",
    "Use for questions about overall conversion rate.",
    "Do not use for segment-specific conversion rates.",
    "Set metric to 'conversion_rate'."
  ),
  arguments = list(
    metric = type_string(
      "Must be 'conversion_rate'."
    )
  )
)


# Tool D: Compare conversion weighting methods

weighting_wrapper <- function(size_column) {

  # The SQL function only supports employee_band
  if (!identical(size_column, "employee_band")) {
    stop("Unsupported size column.")
  }

  cat(
    "\n[TOOL EXECUTED] compare_weighting_methods(",
    size_column,
    ")\n",
    sep = ""
  )

  result <- compare_weighting_methods(size_column)

  paste(
    capture.output(print(result)),
    collapse = "\n"
  )
}

tool_d <- tool(
  weighting_wrapper,
  name = "compare_weighting_methods",
  description = paste(
    "Compare lead-weighted and equal-account-weighted",
    "conversion rates across company employee-size bands.",
    "Use when comparing conversion weighting methods",
    "or when analyzing account-level versus lead-level",
    "conversion rates by company size.",
    "Set size_column to 'employee_band'."
  ),
  arguments = list(
    size_column = type_string(
      "Company size dimension. Must be 'employee_band'."
    )
  )
)


# Tool E: Check missing values

missing_values_wrapper <- function(check_type) {

  if (!identical(check_type, "missing_values")) {
    stop("Unsupported check type.")
  }

  cat("\n[TOOL EXECUTED] check_missing_values()\n")

  result <- check_missing_values()

  paste(
    capture.output(print(result)),
    collapse = "\n"
  )
}

tool_e <- tool(
  missing_values_wrapper,
  name = "check_missing_values",
  description = paste(
    "Check missing data across important B2B sales lead fields.",
    "Returns missing counts and percentages",
    "for conversion, lead source, touch count,",
    "buyer role, seniority, pricing views and demo views.",
    "Use for data quality questions about missing values.",
    "Set check_type to 'missing_values'."
  ),
  arguments = list(
    check_type = type_string(
      "Must be 'missing_values'."
    )
  )
)


# Tool F: Check data integrity

integrity_wrapper <- function(check_type) {

  if (!identical(check_type, "data_integrity")) {
    stop("Unsupported check type.")
  }

  cat("\n[TOOL EXECUTED] check_data_integrity()\n")

  result <- check_data_integrity()

  paste(
    capture.output(print(result)),
    collapse = "\n"
  )
}

tool_f <- tool(
  integrity_wrapper,
  name = "check_data_integrity",
  description = paste(
    "Check database key integrity for B2B leads and accounts.",
    "Returns counts of total and unique lead IDs,",
    "total and unique account IDs, missing IDs,",
    "duplicate lead IDs, duplicate account IDs,",
    "and leads without matching accounts.",
    "Use when asked about duplicate records,",
    "missing IDs, unmatched accounts,",
    "referential integrity or ID consistency.",
    "For ordinary missing engagement field values,",
    "use check_missing_values instead.",
    "Set check_type to 'data_integrity'."
  ),
  arguments = list(
    check_type = type_string(
      "Must be 'data_integrity'."
    )
  )
)



# Stage 07.3 — Reusable Agent Backend

# Shared business definitions
agent_system_prompt <- paste(
  "You are a B2B sales analytics assistant.",
  "Select the appropriate registered SQL-backed tool",
  "based on the user's business question.",
  "Use tool results for database facts and metrics.",
  "Never invent numerical results.",
  "Never claim to have retrieved unavailable data.",
  "If no tool supports the requested analysis,",
  "explain the limitation clearly.",
  "Do not present current metrics as future forecasts.",
  "Lead-weighted conversion rate equals total",
  "converted leads divided by total leads.",
  "Equal-account-weighted conversion rate is the",
  "arithmetic mean of account conversion rates.",
  "Accounts with zero leads have a zero conversion",
  "rate in the equal-account-weighted calculation.",
  "Limit data-quality claims to the checks performed."
)

# Create a new chat with all six registered tools
make_agent_chat <- function() {

  agent_chat <- chat_ollama(
    system_prompt = agent_system_prompt,
    base_url = "http://localhost:11434",
    model = "granite4.2:3b",
    echo = "none"
  )

  agent_chat$register_tool(tool_a)
  agent_chat$register_tool(tool_b)
  agent_chat$register_tool(tool_c)
  agent_chat$register_tool(tool_d)
  agent_chat$register_tool(tool_e)
  agent_chat$register_tool(tool_f)

  return(agent_chat)
}

cat("[AGENT BACKEND READY — SIX TOOLS AVAILABLE]\n")
