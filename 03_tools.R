# Commercial Analytics Agent
# Tool Functions

# Get total number of leads

get_total_leads <- function() {

  result <- dbGetQuery(con, "
    SELECT COUNT(*) AS total_leads
    FROM analytics.vw_leads_reporting
  ")

  return(result)
}


# Tool 2: Get overall conversion metrics
get_conversion_rate <- function() {

  result <- dbGetQuery(con, "
    SELECT
      COUNT(*) AS total_leads,
      SUM(CAST(converted_within_90_days AS INT))
        AS converted_leads,
      100.0 * AVG(CAST(converted_within_90_days AS FLOAT))
        AS conversion_rate_pct
    FROM analytics.vw_leads_reporting
  ")

  return(result)
}

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

# Tool 4: Compare conversion weighting methods

# Inspect account view columns
account_fields <- dbListFields(
  con,
  Id(schema = "analytics", table = "vw_accounts")
)

print(account_fields)


# Tool 4: Compare conversion weighting methods

compare_weighting_methods <- function(size_column) {

  # Business-specific allowlist
  allowed_columns <- c("employee_band")

  # Validate input type and length
  if (!is.character(size_column) ||
      length(size_column) != 1 ||
      is.na(size_column)) {

    stop("Size column must be a single valid character string.")
  }

  # Validate against allowlist
  if (!size_column %in% allowed_columns) {

    stop("Invalid size column. Allowed value: employee_band.")
  }

  size_identifier <- as.character(
    dbQuoteIdentifier(con, size_column)
  )

  query <- paste0("
    WITH account_metrics AS (
      SELECT
        a.account_id,
        a.", size_identifier, " AS company_size,
        COUNT(l.account_id) AS total_leads,
        COALESCE(
          SUM(CAST(l.converted_within_90_days AS INT)), 0
        ) AS converted_leads
      FROM analytics.vw_accounts AS a
      LEFT JOIN analytics.vw_leads_reporting AS l
        ON a.account_id = l.account_id
      GROUP BY
        a.account_id,
        a.", size_identifier, "
    )

    SELECT
      company_size,
      COUNT(*) AS total_accounts,
      SUM(total_leads) AS total_leads,
      SUM(converted_leads) AS converted_leads,

      100.0 * SUM(converted_leads)
        / NULLIF(SUM(total_leads), 0)
        AS lead_weighted_pct,

      100.0 * AVG(
        CASE
          WHEN total_leads = 0 THEN 0.0
          ELSE 1.0 * converted_leads / total_leads
        END
      ) AS equal_account_weighted_pct

    FROM account_metrics
    GROUP BY company_size
    ORDER BY lead_weighted_pct DESC
  ")

  result <- dbGetQuery(con, query)

  return(result)
}



# Tool 5: Check missing values

check_missing_values <- function() {

  query <- "
    SELECT
      COUNT(*) AS total_leads,

      COUNT(*) - COUNT(converted_within_90_days)
        AS missing_conversion,

      COUNT(*) - COUNT(lead_source)
        AS missing_lead_source,

      COUNT(*) - COUNT(touch_count)
        AS missing_touch_count,

      COUNT(*) - COUNT(buyer_role)
        AS missing_buyer_role,

      COUNT(*) - COUNT(seniority)
        AS missing_seniority,

      COUNT(*) - COUNT(pricing_page_views)
        AS missing_pricing_views,

      COUNT(*) - COUNT(demo_page_views)
        AS missing_demo_views

    FROM analytics.vw_leads_reporting
  "

  result <- dbGetQuery(con, query)

  # Extract missing counts
  missing_counts <- as.numeric(
    unlist(result[1, -1])
  )

  # Create a structured summary table
  summary <- data.frame(
    field = names(result)[-1],
    missing_count = missing_counts,
    missing_pct = round(
      100 * missing_counts / result$total_leads[1], 2
    )
  )

  return(summary)
}


# Tool 6: Check data integrity

check_data_integrity <- function() {

  query <- "
    SELECT

      (SELECT COUNT(*)
       FROM analytics.vw_leads_reporting)
        AS total_lead_rows,

      (SELECT COUNT(DISTINCT lead_id)
       FROM analytics.vw_leads_reporting)
        AS unique_lead_ids,

      (SELECT COUNT(*)
       FROM analytics.vw_leads_reporting
       WHERE lead_id IS NULL)
        AS missing_lead_ids,

      (SELECT COUNT(*)
       FROM analytics.vw_accounts)
        AS total_account_rows,

      (SELECT COUNT(DISTINCT account_id)
       FROM analytics.vw_accounts)
        AS unique_account_ids,

      (SELECT COUNT(*)
       FROM analytics.vw_accounts
       WHERE account_id IS NULL)
        AS missing_account_ids,

      (SELECT COUNT(*)
       FROM analytics.vw_leads_reporting AS l
       WHERE NOT EXISTS (
         SELECT 1
         FROM analytics.vw_accounts AS a
         WHERE a.account_id = l.account_id
       ))
        AS unmatched_leads
  "

  result <- dbGetQuery(con, query)

  # Calculate excess duplicate ID occurrences
  result$duplicate_lead_ids <-
    result$total_lead_rows -
    result$missing_lead_ids -
    result$unique_lead_ids

  result$duplicate_account_ids <-
    result$total_account_rows -
    result$missing_account_ids -
    result$unique_account_ids

  # Transform into a structured table
  summary <- data.frame(
    metric = names(result),
    value = as.numeric(unlist(result))
  )

  return(summary)
}


# Test Tool 6
print(check_data_integrity())

# Test Tool 5
print(check_missing_values())



# Test Tool 4
# Replace employee_band with the actual column name
# shown in account_fields if necessary.

print(compare_weighting_methods("employee_band"))


# Test the tool function
print(get_total_leads())

# Test overall conversion metrics
print(get_conversion_rate())

# Test Tool 3: Conversion by lead source
print(get_conversion_by_segment("lead_source"))
