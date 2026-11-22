
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



# 5. Connect to Granite


# Shared system prompt for integration tests

chat_system_prompt <- paste(
  "You are a B2B sales analytics assistant.",
  "Select the most appropriate registered tool",
  "based on the user's business question.",
  "Never invent database values.",
  "Use actual tool results for all reported metrics.",
  "Lead-weighted conversion rate equals total",
  "converted leads divided by total leads.",
  "Equal-account-weighted conversion rate is the",
  "arithmetic mean of individual account conversion rates.",
  "Each account receives equal weight regardless",
  "of its lead count.",
  "For this project, accounts with zero leads",
  "have a zero conversion rate in the equal-account",
  "weighted calculation."
)

chat <- chat_ollama(
  system_prompt = chat_system_prompt,
  base_url = "http://localhost:11434",
  model = "granite4.2:3b",
  echo = "none"
)


# Register all six analytics tools

chat$register_tool(tool_a)
chat$register_tool(tool_b)
chat$register_tool(tool_c)
chat$register_tool(tool_d)
chat$register_tool(tool_e)
chat$register_tool(tool_f)

cat("[SIX TOOLS REGISTERED]\n")

# 7. Test: Model must choose the appropriate tool

# 7. Reverse tool-selection test



# Test data integrity tool selection


# Stage 6.4-B — Six-tool integration test


test_questions <- c(
  paste(
    "For companies with 2000+ employees,",
    "what are the lead-weighted and",
    "equal-account-weighted conversion rates?"
  ),
  paste(
    "Which sales engagement fields have missing values?",
    "Report their missing counts and percentages."
  ),
  paste(
    "Check lead and account ID integrity.",
    "Are there duplicate IDs, missing IDs,",
    "or leads without matching accounts?"
  )
)

for (i in seq_along(test_questions)) {

  cat(
    "\n========== TEST ", i, " ==========\n",
    sep = ""
  )

  cat("[QUESTION] ", test_questions[i], "\n", sep = "")

  # Fresh chat for each test to avoid conversation carryover
  test_chat <- chat_ollama(
    system_prompt = chat_system_prompt,
    base_url = "http://localhost:11434",
    model = "granite4.2:3b",
    echo = "none"
  )

  test_chat$register_tool(tool_a)
  test_chat$register_tool(tool_b)
  test_chat$register_tool(tool_c)
  test_chat$register_tool(tool_d)
  test_chat$register_tool(tool_e)
  test_chat$register_tool(tool_f)

  result <- test_chat$chat(test_questions[i])

  cat("[ANSWER]\n")
  cat(result, "\n")
}
