#  R/tab_thesis.R 

# UI MODULE
thesis_ui <- function(id) {
  ns <- NS(id)
  tagList(
    # TOP ACTION BAR
    div(
      style = "max-width: 1600px; margin: 0 auto; padding: 20px 20px 0 20px; display: flex; justify-content: space-between; align-items: center;",
      h3("Academic Documentation", style = "color: #F9FAFB; margin: 0; font-family: 'JetBrains Mono';"),
      
      div(
        style = "display: flex; gap: 15px;",
        downloadButton(ns("download_methodology"), "Download Methodology", 
                       class = "btn-secondary", 
                       style = "background-color: #1F2937; border: 1px solid #374151; color: #F9FAFB; font-family: 'JetBrains Mono';"),
        downloadButton(ns("download_thesis"), "Download Thesis Paper", 
                       class = "btn-primary", 
                       style = "background-color: #2563EB; border: none; font-family: 'JetBrains Mono';")
      )
    ),
    
    # DOCUMENT LAYOUT
    div(
      style = "max-width: 1600px; margin: 0 auto; padding: 20px;",
      layout_columns(
        col_widths = c(6, 6),
        
        # LEFT SIDE
        card(
          card_header("Walkthrough & Methodology", style = "background: #111111; color: #2563EB;"),
          div(
            style = "padding: 20px; color: #F9FAFB; height: 750px; overflow-y: auto;",
            includeMarkdown("www/methodology.md")
          )
        ),
        
        # RIGHT SIDE
        card(
          card_header("Thesis Paper", style = "background: #111111; color: #F9FAFB;"),
          div(
            style = "height: 750px; border: 1px solid #1F2937; border-radius: 8px; background-color: #0A0A0A; padding: 40px; display: flex; flex-direction: column; align-items: center; text-align: center; justify-content: center;",
            bsicons::bs_icon("journal-check", size = "4rem", class = "mb-4 text-primary"),
            h3("Chess Under Surveillance", style = "color: #F9FAFB; letter-spacing: 2px;"),
            h5("Computational Forensics & Elite Behavioral Mapping", style = "color: #9CA3AF; margin-bottom: 30px; font-style: italic;"),
            p("PAPER HERE", 
              style = "color: #D1D5DB; font-family: 'JetBrains Mono'; max-width: 400px; line-height: 1.6;"),
            p("Click the blue download button above to read the full publication.", 
              style = "color: #2563EB; margin-top: 20px; font-weight: bold;")
          )
        )
      )
    )
  )
}


# SERVER MODULE
thesis_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    
    # METHODOLOGY DOWNLOAD HANDLER
    output$download_methodology <- downloadHandler(
      filename = function() {
        paste0("Methodology_Walkthrough_", Sys.Date(), ".pdf")
      },
      content = function(file) {
        showNotification("Compiling Methodology PDF... This may take a moment.", type = "message", duration = 5)
        rmarkdown::render(
          input = "www/methodology.md", 
          output_format = "pdf_document",
          output_file = file,
          envir = new.env(parent = globalenv())
        )
      }
    )
    
    output$download_thesis <- downloadHandler(
      filename = function() {
        "Jesinger_Undergraduate_STS_Thesis.pdf"
      },
      content = function(file) {
        file.copy("www/thesis_paper.pdf", file) 
      }
    )
    
  })
}