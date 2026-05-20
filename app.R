# app.R

library(shiny)
library(bslib)
library(ggplot2)
library(dplyr)
library(plotly)
library(DT)
library(bsicons)
library(rchess)
library(stringr)
library(bigchess)
library(tidyverse)
library(shinyWidgets)
library(zoo)
library(markdown)   
library(rmarkdown)

source("global.R") 

# GLOBAL PARAMETERS & THEMING

# Master Roster: The longitudinal subject list spanning multiple chess eras.
master_list <- c("All", "Magnus Carlsen", "Hikaru Nakamura", "Hans Niemann", "Daniel Naroditsky", 
                 "Garry Kasparov", "Vladimir Kramnik", "Bobby Fischer", "Anatoly Karpov")

# Theme layout
my_theme <- bs_theme(
  version = 5,
  bg = "#0A0A0A",        
  fg = "#F9FAFB",         
  primary = "#2563EB",    
  secondary = "#1F2937",  
  danger = "#DC2626",   
  base_font = font_google("JetBrains Mono"), 
  heading_font = font_google("Inter")
)

# UI ARCHITECTURE
ui <- page_navbar(
  theme = my_theme,
  title = "Chess Under Surveillance",
  id = "main_nav",
  
  header = tags$head(
    tags$style(HTML("
      /* Overriding standard Bootstrap behavior to enforce a consistent 'Terminal' feel */
      body, .bslib-page-navbar { background-color: #0A0A0A !important; color: #F9FAFB !important; }
      .bslib-sidebar-layout > .sidebar { 
        background-color: #111111 !important; 
        border-right: 1px solid #1F2937 !important; 
      }
      .card { 
        background-color: #0A0A0A !important;
        border: 1px solid #1F2937 !important; 
        border-radius: 6px !important; 
        transition: border-color 0.3s ease, box-shadow 0.3s ease;
      }
      .card:hover {
        border-color: #2563EB !important; 
        box-shadow: 0 0 10px rgba(37, 99, 235, 0.15) !important;
      }
      
      /* Enforcing plot transparency to avoid visual clashing with the dark theme */
      .js-plotly-plot, .plot-container, .main-svg { background-color: transparent !important; }
      .plotly .bg { fill: #0A0A0A !important; }
      h1, h2, h3, h4, h5, h6, label, p { color: #F9FAFB !important; }
      
      /* Workflow Table Styling: Visualizing the project's technical architecture */
      .workflow-table { width: 100%; border-collapse: collapse; margin-top: 20px; font-size: 0.85rem; }
      .workflow-table th { border-bottom: 2px solid #1F2937; padding: 10px; color: #2563EB; text-align: left; }
      .workflow-table td { border-bottom: 1px solid #1F2937; padding: 10px; color: #D1D5DB; }
    "))
  ),
  
  # SURVEILLANCE SIDEBAR
  # Every parameter selected here 
  # reactively updates every calculation in every tab simultaneously.
  sidebar = sidebar(
    width = 300,
    h4("Global Filters"),
    selectInput("master", "Select Grandmaster:", choices = master_list, selected = "All"),
    radioButtons("environment", "Environment:", choices = c("All", "Social (OTB)", "Isolated (Online)")),
    radioButtons("tempo", "Tempo / Speed:", choices = c("All", "Fast (Blitz)", "Slow (Classical)")),
    checkboxInput("super_clash", "Super-Clash Mode (Elite Matchups)", value = FALSE)
  ),
  
  # HOME TAB
  nav_panel(title = "Home", icon = bsicons::bs_icon("house"), value = "home",
            div(style = "max-width: 1000px; margin: 0 auto; padding: 50px 20px; text-align: center;",
                
                h1("CHESS UNDER SURVEILLANCE", 
                   style = "letter-spacing: 8px; font-weight: 900; color: #F9FAFB; text-shadow: 0 0 20px rgba(37, 99, 235, 0.5);"),
                h5("Computational Forensics & Elite Behavioral Mapping", 
                   style = "color: #2563EB; letter-spacing: 2px; margin-bottom: 40px; font-family: 'JetBrains Mono';"),
                
                layout_column_wrap(
                  width = 1/2,
                  card(
                    card_header("Project Objective", style = "background: #111111; color: #F9FAFB;"),
                    p("Evaluating the mathematical accuracy of bot-detection methodologies in high-stakes environments. This research quantifies the 'Human-in-the-Loop' through the delta between synthetic intuition and algorithmic optimization.",
                      style = "font-size: 0.9rem; line-height: 1.6; color: #D1D5DB; padding: 10px; text-align: left;")
                  ),
                  card(
                    card_header("Mathematical Framework", style = "background: #111111; color: #F9FAFB;"),
                    p("Standardizing anomaly detection through Z-score scaling. Utilizing a 3.0σ confidence interval, we distinguish elite performance from automated precision by establishing biological baselines.",
                      style = "font-size: 0.9rem; line-height: 1.6; color: #D1D5DB; padding: 10px; text-align: left;")
                  )
                ),
                
                # SIGNAL CLASSIFICATION: Defining the behavioral states for the auditor
                div(style = "margin-top: 40px; padding: 20px; background: #0F172A; border-radius: 8px; border: 1px solid #1E293B;",
                    h6("SIGNAL CLASSIFICATION KEY", style = "letter-spacing: 2px; color: #9CA3AF; margin-bottom: 15px;"),
                    div(style = "display: flex; justify-content: center; gap: 30px; flex-wrap: wrap;",
                        span(style="color: #2563EB; font-weight: bold;", bsicons::bs_icon("cpu-fill"), " Silicon (Stockfish)"),
                        span(style="color: #A855F7; font-weight: bold;", bsicons::bs_icon("robot"), " Synthetic (Maia)"),
                        span(style="color: #10B981; font-weight: bold;", bsicons::bs_icon("person-fill"), " Biological (Human)"),
                        span(style="color: #DC2626; font-weight: bold;", bsicons::bs_icon("exclamation-octagon"), " Anomaly (Blunder)")
                    )
                ),
                
                # SYSTEM MODULES:explains everything, different than methodology though
                div(style = "margin-top: 50px; text-align: left;",
                    h5("System Modules & Research Logic", style = "color: #F9FAFB; border-left: 4px solid #2563EB; padding-left: 15px;"),
                    withMathJax(
                      tags$table(class = "workflow-table",
                                 tags$thead(
                                   tags$tr(
                                     tags$th("Module"), tags$th("Dashboard Tool"), tags$th("Thesis Function")
                                   )
                                 ),
                                 tags$tbody(
                                   tags$tr(
                                     tags$td("Behavioral Transcript"), tags$td("Interactive Board"), tags$td("Move-by-move mapping of individual game telemetry and human intent.")
                                   ),
                                   tags$tr(
                                     tags$td("Statistical Defense"), tags$td("The Defense"), tags$td("Validation of environmental significance via t-tests and Z-score distribution analysis.")
                                   ),
                                   tags$tr(
                                     tags$td("Stylistic Index"), tags$td("The Index"), tags$td("Profiling cognitive fatigue, stylistic drift, and 24-hour behavioral patterns.")
                                   ),
                                   tags$tr(
                                     tags$td("Phase Audit"), tags$td("The Audit"), tags$td("Identifying precision spikes across Opening, Middlegame, and Endgame phases.")
                                   ),
                                   tags$tr(
                                     tags$td("Detection Simulator"), 
                                     tags$td("CI Simulator"), 
                                     tags$td("Modeling flagging net sensitivity using variable confidence thresholds.")
                                   ),
                                   tags$tr(
                                     tags$td("Biological Baseline"), tags$td("Danya Memorial"), tags$td("Establishing the 'Digital Native' standard for natural, high-accuracy intuition.")
                                   ),
                                   tags$tr(
                                     tags$td("The Silicon Ghost"), tags$td("Historical Auditor"), tags$td("Back-testing modern thresholds against historical legends to map era-dependent false positives.")
                                   )
                                 )
                      )
                    )
                ),
                
                # REPOSITORY ACCESS
                div(style = "margin-top: 40px; text-align: center;",
                    tags$a(href = "https://github.com/rcjesinger/chess-thesis-dashboard",
                           target = "_blank", 
                           class = "btn btn-primary btn-lg", 
                           style = "background-color: #2563EB; border: none; font-family: 'JetBrains Mono'; padding: 12px 24px; box-shadow: 0 4px 14px rgba(37, 99, 235, 0.4); font-size: 1rem;",
                           bsicons::bs_icon("github", class = "me-2", size = "1.2rem"), "View Source Code & Data Pipeline")
                ),
                
                div(style = "margin-top: 80px; padding: 15px; border-top: 1px solid #1F2937; color: #4B5563; font-family: 'JetBrains Mono'; font-size: 0.75rem;",
                    "Undergraduate Thesis | Statistics & Science and Technology Studies | University of California, Davis"),
                
            )
  ),
  
  # MODULE CALLS
  nav_panel(title = "Interactive Board", icon = bsicons::bs_icon("grid-3x3"), value = "interactive_board", interactive_ui("interactive_board")),
  nav_panel(title = "The Defense", value = "defense", defense_ui("defense")),
  nav_panel(title = "The Index", value = "index", index_ui("index")),
  nav_panel(title = "The Audit", value = "audit", audit_ui("audit")),
  nav_panel(title = "CI Simulator", value = "simulator", simulator_ui("simulator")),
  nav_panel(title = "Danya Memorial", value = "memorial", memorial_ui("memorial")),
  nav_panel(title = "Historical Auditor", value = "historical", historical_ui("historical")),
  
  # ACADEMIC TAB: Linking the interactive tool to the formal publication.
  nav_panel(title = "Academic Paper", icon = bsicons::bs_icon("file-earmark-text"), value = "academic_paper", thesis_ui("thesis_tab"))
)

# SERVER ORCHESTRATION
server <- function(input, output, session) {
  
  clean_env <- reactive({
    if (input$environment == "Social (OTB)") return("Social")
    if (input$environment == "Isolated (Online)") return("Isolated")
    return("All")
  })
  clean_tempo <- reactive({
    if (input$tempo == "Fast (Blitz)") return("Fast")
    if (input$tempo == "Slow (Classical)") return("Slow")
    return("All")
  })
  
  # THE GLOBAL SYNC 
  # When a user clicks a game on any tab (Index, Audit, Historical), this value is updated. 
  # Every other tab listens to this value and instantly refreshes its view.
  global_active_game <- reactiveVal(NULL) 
  
  # Each module inherits the global filters and the 'global_active_game' state.
  interactive_server("interactive_board",
                     global_master = reactive(input$master),
                     global_env = clean_env,     
                     global_tempo = clean_tempo,
                     global_super_clash = reactive(input$super_clash),
                     global_active_game = global_active_game) 
  
  defense_server("defense", 
                 global_master = reactive(input$master),
                 global_env = clean_env,         
                 global_tempo = clean_tempo, 
                 global_super_clash = reactive(input$super_clash),
                 global_active_game = global_active_game) 
  
  index_server("index", 
               global_master = reactive(input$master), 
               global_env = clean_env, 
               global_tempo = clean_tempo, 
               global_super_clash = reactive(input$super_clash),
               global_active_game = global_active_game)
  
  audit_server("audit", 
               global_master = reactive(input$master), 
               global_env = clean_env, 
               global_tempo = clean_tempo, 
               global_super_clash = reactive(input$super_clash),
               global_active_game = global_active_game) 
  
  simulator_server("simulator", 
                   global_master = reactive(input$master), 
                   global_env = clean_env, 
                   global_tempo = clean_tempo, 
                   global_super_clash = reactive(input$super_clash))
  
  memorial_server("memorial")
  
  historical_server("historical", 
                    global_active_game = global_active_game)
  
  thesis_server("thesis_tab")
}

shinyApp(ui = ui, server = server)