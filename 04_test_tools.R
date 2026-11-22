
# Commercial Analytics Agent
# Automated Tool Validation

source("02_connection.R")
source("03_tools.R")
# Test 1: Total leads

total <- get_total_leads()

stopifnot(total$total_leads == 5000)

cat("PASS: Tool 1 - Total leads\n")


# Test 2: Overall conversion rate

conversion <- get_conversion_rate()

stopifnot(
  conversion$total_leads == 5000,
  conversion$converted_leads == 1049,
  abs(conversion$conversion_rate_pct - 20.98) < 0.01
)

cat("PASS: Tool 2 - Conversion rate\n")


# Test 3: Segment comparison

for (segment in c("lead_source", "seniority", "buyer_role")) {

  segment_result <- get_conversion_by_segment(segment)

  stopifnot(
    sum(segment_result$total_leads) == 5000,
    sum(segment_result$converted_leads) == 1049
  )

  cat("PASS: Tool 3 -", segment, "\n")
}


# Test 4: Weighting comparison

weighting <- compare_weighting_methods("employee_band")

large_company <- weighting[
  weighting$company_size == "2000+", ]

stopifnot(
  sum(weighting$total_accounts) == 1280,
  sum(weighting$total_leads) == 5000,
  sum(weighting$converted_leads) == 1049,
  nrow(large_company) == 1,
  abs(large_company$lead_weighted_pct - 22.13) < 0.01,
  abs(large_company$equal_account_weighted_pct - 19.89) < 0.01
)

cat("PASS: Tool 4 - Weighting comparison\n")


# Test 5: Missing values

missing <- check_missing_values()

expected_missing <- c(
  missing_conversion = 0,
  missing_lead_source = 0,
  missing_touch_count = 413,
  missing_buyer_role = 0,
  missing_seniority = 0,
  missing_pricing_views = 408,
  missing_demo_views = 389
)

actual_missing <- setNames(
  missing$missing_count,
  missing$field
)

stopifnot(
  all(names(expected_missing) %in% names(actual_missing)),
  all(actual_missing[names(expected_missing)] == expected_missing)
)

cat("PASS: Tool 5 - Missing values\n")


# Test 6: Data integrity

integrity <- check_data_integrity()

expected <- c(
  total_lead_rows = 5000,
  unique_lead_ids = 5000,
  missing_lead_ids = 0,
  total_account_rows = 1280,
  unique_account_ids = 1280,
  missing_account_ids = 0,
  unmatched_leads = 0,
  duplicate_lead_ids = 0,
  duplicate_account_ids = 0
)

actual <- setNames(integrity$value, integrity$metric)

stopifnot(
  all(names(expected) %in% names(actual)),
  all(actual[names(expected)] == expected)
)

cat("PASS: Tool 6 - Data integrity\n")


# Final validation result

cat("\nAll six tools passed validation.\n")

# Tool 3: Get conversion metrics by segment

get_conversion_by_segment <- function(segment) {

  allowed_segments <- c(
    "lead_source",
    "seniority",
    "buyer_role"
  )

  # Validate input type and length
  if (!is.character(segment) ||
      length(segment) != 1 ||
      is.na(segment)) {

    stop("Segment must be a single valid character string.")
  }

  # Validate against allowlist
  if (!segment %in% allowed_segments) {

    stop("Invalid segment. Allowed values: lead_source, seniority, buyer_role.")
  }

  segment_identifier <- as.character(
    dbQuoteIdentifier(con, segment)
  )

  query <- paste0("
    SELECT
      ", segment_identifier, " AS segment,
      COUNT(*) AS total_leads,
      SUM(CAST(converted_within_90_days AS INT))
        AS converted_leads,
      100.0 * AVG(CAST(converted_within_90_days AS FLOAT))
        AS conversion_rate_pct
    FROM analytics.vw_leads_reporting
    GROUP BY ", segment_identifier, "
    ORDER BY conversion_rate_pct DESC
  ")

  result <- dbGetQuery(con, query)

  return(result)
}

# Step 3.5.2: Guardrail validation

expect_error <- function(
    test_function,
    label,
    expected_message
) {

  error_message <- tryCatch(
    {
      test_function()
      NULL
    },
    error = function(e) {
      conditionMessage(e)
    }
  )

  stopifnot(
    !is.null(error_message),
    grepl(
      expected_message,
      error_message,
      fixed = TRUE
    )
  )

  cat("PASS: Rejected", label, "\n")
}


# Tool 3: Invalid input tests

expect_error(
  function() get_conversion_by_segment("invalid_column"),
  "invalid segment",
  "Invalid segment."
)

expect_error(
  function() get_conversion_by_segment(NA_character_),
  "missing segment",
  "Segment must be"
)

expect_error(
  function() get_conversion_by_segment(123),
  "numeric segment",
  "Segment must be"
)

expect_error(
  function() get_conversion_by_segment(
    c("lead_source", "seniority")
  ),
  "multiple segments",
  "Segment must be"
)

expect_error(
  function() get_conversion_by_segment(
    "lead_source; SELECT 1"
  ),
  "SQL-like segment input",
  "Invalid segment."
)


# Tool 4: Invalid input tests

expect_error(
  function() compare_weighting_methods("account_id"),
  "unauthorised account column",
  "Invalid size column."
)

expect_error(
  function() compare_weighting_methods(NA_character_),
  "missing size column",
  "Size column must be"
)

expect_error(
  function() compare_weighting_methods(123),
  "numeric size column",
  "Size column must be"
)

expect_error(
  function() compare_weighting_methods(
    c("employee_band", "account_id")
  ),
  "multiple size columns",
  "Size column must be"
)

expect_error(
  function() compare_weighting_methods(
    "employee_band; SELECT 1"
  ),
  "SQL-like size column input",
  "Invalid size column."
)

cat("\nAll guardrail tests passed.\n")
