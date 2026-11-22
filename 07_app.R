
# Stage 07.3 — Commercial Analytics Agent MVP

library(shiny)
library(ellmer)
library(DBI)

# Load SQL connection and six analytics tools
source("07_agent_backend.R")

# 1. User interface
ui <- fluidPage(

  titlePanel("Commercial Analytics Agent"),

  p("Ask a business question about your B2B sales pipeline."),

  textAreaInput(
    inputId = "question",
    label = "Your question",
    placeholder = "How many total leads do we have?",
    rows = 3,
    width = "100%"
  ),

  actionButton(
    inputId = "ask",
    label = "Ask Agent"
  ),

  hr(),

  h4("Agent Response"),

  verbatimTextOutput("answer")
)

# 2. Server logic
server <- function(input, output, session) {

  response <- eventReactive(input$ask, {

    question <- trimws(input$question)

    if (!nzchar(question)) {
      return("Please enter a business question first.")
    }

    withProgress(
      message = "Granite is analysing your question...",
      value = 0,
      {

        tryCatch({

          incProgress(0.2, detail = "Preparing analytics tools")

          if (!DBI::dbIsValid(con)) {
            stop("SQL Server connection is unavailable.")
          }

          agent_chat <- make_agent_chat()

          incProgress(0.3, detail = "Querying the local AI agent")

          answer <- agent_chat$chat(question)

          incProgress(0.5, detail = "Preparing the response")

          as.character(answer)

        }, error = function(e) {

          paste(
            "Agent error:",
            conditionMessage(e)
          )

        })

      }
    )

  })


  # Display the response without raw Markdown bold markers
  output$answer <- renderText({

    answer_text <- response()

    # Remove Markdown bold markers for plain-text display
    gsub("**", "", answer_text, fixed = TRUE)

  })


}

# 3. Launch the application
shinyApp(ui = ui, server = server)
