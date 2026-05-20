# ==============================================================================
# --- R/tab_audit.R ---
# ==============================================================================

# 1. THE UI MODULE
# This tab acts as a micro-level microscope. While other tabs look at macro-aggregates,
# this tab provides the Forensic Telemetry of a single specific game, mapping 
# human intuition vs. independent calculation on a move-by-move basis.
audit_ui <- function(id) {
  ns <- NS(id)
  tagList(
    card(
      card_header("Forensic Telemetry: Single Game Move Mapping"),
      div(style = "background-color: #111111; border: 1px solid #1F2937; border-radius: 6px; padding: 20px; color: #F9FAFB; margin-bottom: 10px;",
          div(style = "flex-grow: 1;", 
              selectizeInput(ns("audit_game_select"), "Active Case (Syncs with Interactive Board):", choices = NULL, width = "100%")
          ),
          actionButton(ns("next_game_btn"), "🎲 Randomize Case", class = "btn-warning", style = "margin-bottom: 5px; height: 38px; width: 100%;")
      ),
      
      p("Move-by-move mapping of human intuition vs. independent calculation across temporal phases.", 
        style = "color: #9CA3AF; font-size: 0.85rem; padding-left: 5px;"),
      
      # The main visualizer: A chronological mapping to spot algorithmic mimicry in real-time.
      plotlyOutput(ns("game_timeline_plot"), height = "450px") 
    ),
    
    layout_columns(
      col_widths = c(4, 8),
      card(
        # The Anomaly Spotlight: Automates a statistical judgment based on hard thresholds
        # to remove subjective human bias from the fair-play audit.
        card_header("System Verdict & Phase Analysis"),
        div(style = "min-height: 400px;", uiOutput(ns("anomaly_spotlight")))
      ),
      card(
        # The raw data ledger: Ensures that all algorithmic judgments displayed above 
        # are entirely transparent, reproducible, and mathematically verifiable.
        card_header("Move Telemetry & Chain of Custody"),
        div(style = "background-color: #0A0A0A; padding: 10px;",
            DTOutput(ns("move_table")),
            downloadButton(ns("dl_audit"), "Download Audit Trail (.csv)", class = "btn-success mt-2", style = "width: 100%;")
        )
      )
    )
  )
}

# 2. THE SERVER MODULE
audit_server <- function(id, global_master, global_env, global_tempo, global_super_clash, global_active_game) {
  moduleServer(id, function(input, output, session) {
    
    # --- 1. Master Data Filter ---
    # Inherits the global surveillance net set by the user in the sidebar.
    filtered_data <- reactive({
      req(exists("main_data"))
      df <- main_data
      if (!is.null(global_master()) && global_master() != "All") df <- df[df$proper_identity == global_master(), ]
      if (global_env() != "All") df <- df[df$environment == global_env(), ]
      if (global_tempo() != "All") df <- df[df$Tempo == global_tempo(), ]
      if (isTRUE(global_super_clash())) df <- df[df$is_super_clash == TRUE, ] 
      return(df)
    })
    
    # --- 2. The Global Dropdown Builder ---
    # Keeps the Audit tab perfectly synced with the Interactive Board tab.
    observe({
      df <- filtered_data()
      req(nrow(df) > 0)
      
      game_meta <- df %>% group_by(Game_ID) %>%
        summarise(White = first(White), Black = first(Black), Year = substr(first(Date.orig), 1, 4), Result = first(Result.orig), .groups = 'drop') %>%
        mutate(Label = paste0(White, " vs. ", Black, " (", Year, ") [", Result, "]"))
      
      current_sel <- global_active_game()
      new_sel <- if (!is.null(current_sel) && current_sel %in% game_meta$Game_ID) current_sel else game_meta$Game_ID[1]
      
      if(is.null(global_active_game())) global_active_game(new_sel)
      
      updateSelectizeInput(session, "audit_game_select", 
                           choices = setNames(game_meta$Game_ID, game_meta$Label), 
                           selected = new_sel, server = TRUE)
    })
    
    observeEvent(input$audit_game_select, {
      if(!is.null(input$audit_game_select) && input$audit_game_select != "") {
        global_active_game(input$audit_game_select)
      }
    }, ignoreInit = TRUE)
    
    observeEvent(input$next_game_btn, {
      df <- filtered_data()
      req(nrow(df) > 0)
      global_active_game(sample(unique(df$Game_ID), 1))
    })
    
    # --- 3. Current Game Reactive (The Core Statistical Engine) ---
    current_game <- reactive({
      req(global_active_game(), filtered_data())
      df <- filtered_data() %>% filter(Game_ID == global_active_game())
      req(nrow(df) > 0)
      
      # Phase Fingerprinting: We dynamically chop the game into relative 1/3 chunks.
      # This is crucial because "Move 20" is the middlegame in a 40-move game, 
      # but it's still the opening in an 80-move game.
      total_moves <- max(df$MoveNum, na.rm = TRUE)
      split_1 <- max(1, round(total_moves * 0.33))
      split_2 <- max(split_1 + 1, round(total_moves * 0.66))
      
      df %>%
        mutate(
          # Triangulation of Agency: Categorizing the behavioral state of every single move.
          Match_Type = case_when(
            Played_Move == Stockfish_Move ~ "Silicon Match (Stockfish)", # Machine-optimal path
            Maia_Match == 1 ~ "Human Intuition (Maia)",                  # Sociotechnical proxy match
            Loss >= 50 ~ "Inaccuracy / Blunder",                         # Distinct biological error
            TRUE ~ "Independent Variance"                                # Unassisted human creativity
          ),
          Match_Type = factor(Match_Type, levels = c("Silicon Match (Stockfish)", "Human Intuition (Maia)", "Independent Variance", "Inaccuracy / Blunder")),
          Phase = case_when(
            MoveNum <= split_1 ~ "Opening",
            MoveNum > split_2 ~ "Endgame",
            TRUE ~ "Middlegame"
          ),
          Phase = factor(Phase, levels = c("Opening", "Middlegame", "Endgame"))
        )
    })
    
    # --- Plot: Dark Mode Timeline ---
    # Visualizes the Triangulation of Agency. For example, a sudden, unbroken streak 
    # of "Silicon Matches" (Blue) specifically in the late Middlegame or Endgame 
    # provides a distinct visual signature of potential external assistance.
    output$game_timeline_plot <- renderPlotly({
      req(current_game())
      game_data <- current_game()
      
      p <- ggplot(game_data, aes(x = MoveNum, y = Loss, fill = Match_Type, 
                                 text = paste("Move:", MoveNum, 
                                              "<br>Played:", Played_Move,
                                              "<br>Loss:", Loss, 
                                              "<br>Type:", Match_Type))) +
        geom_bar(stat = "identity", width = 1) +
        facet_grid(~Phase, scales = "free_x", space = "free_x") +
        scale_fill_manual(values = c(
          "Silicon Match (Stockfish)" = "#2563EB", 
          "Human Intuition (Maia)" = "#A855F7",    
          "Independent Variance" = "#374151",      
          "Inaccuracy / Blunder" = "#DC2626"      
        )) +
        coord_cartesian(ylim = c(0, 300)) + 
        theme_minimal() +
        theme(
          plot.background = element_rect(fill = "#0A0A0A", color = NA),
          panel.background = element_rect(fill = "#0A0A0A", color = NA),
          text = element_text(color = "#F9FAFB", family = "JetBrains Mono"),
          axis.text = element_text(color = "#9CA3AF"),
          panel.grid.major = element_line(color = "#1F2937"),
          panel.grid.minor = element_blank(),
          strip.background = element_rect(fill = "#111111"),
          strip.text = element_text(color = "#F9FAFB", face = "bold")
        )
      
      ggplotly(p, tooltip = "text", height = 450) %>%
        toWebGL() %>%
        layout(paper_bgcolor = "#0A0A0A", plot_bgcolor = "#0A0A0A",
               legend = list(orientation = "h", x = 0, y = -0.2, font = list(color = "#F9FAFB"))) %>% 
        config(displayModeBar = FALSE)
    })
    
    # --- UI: The Verdict Spotlight (Fixed Visibility) ---
    # Calculates aggregate game metrics and issues a strict mathematical verdict.
    # To flag a game as "Anomalous Precision", the player must hit an extreme threshold:
    # Match Stockfish > 60% of the time AND maintain an average loss under 15 centipawns.
    output$anomaly_spotlight <- renderUI({
      req(current_game())
      game_data <- current_game()
      
      sf_rate <- round(mean(game_data$Played_Move == game_data$Stockfish_Move, na.rm = TRUE) * 100, 1)
      avg_loss <- round(mean(game_data$Loss, na.rm = TRUE), 1)
      is_anomalous <- (sf_rate > 60) && (avg_loss < 15)
      
      HTML(paste0(
        "<div style='background-color: #111111; color: #F9FAFB; padding: 20px; border-radius: 8px; border: 1px solid #1F2937; font-family: \"JetBrains Mono\", monospace; line-height: 1.6;'>",
        "<h4 style='color: #2563EB; margin-top:0;'>CASE FILE: ", global_active_game(), "</h4>",
        "<b style='color: #9CA3AF;'>MATCHUP:</b> ", unique(game_data$White)[1], " vs. ", unique(game_data$Black)[1], "<br>",
        "<b style='color: #9CA3AF;'>ENV:</b> ", unique(game_data$environment)[1], " | <b style='color: #9CA3AF;'>MOVES:</b> ", max(game_data$MoveNum), "<br><hr style='border-color: #1F2937;'>",
        "<b>STOCKFISH MATCH:</b> <span style='color: #2563EB;'>", sf_rate, "%</span><br>",
        "<b>MAIA MATCH:</b> ", round(mean(game_data$Maia_Match == 1, na.rm = TRUE) * 100, 1), "%<br>",
        "<b>AVG LOSS:</b> ", avg_loss, " CPL<br><br>",
        "<b>SYSTEM VERDICT:</b> ", ifelse(is_anomalous, 
                                          "<span style='color:#DC2626; font-weight:bold;'>ANOMALOUS PRECISION</span>", 
                                          "<span style='color:#00BFA5; font-weight:bold;'>NORMAL BIOLOGICAL VARIANCE</span>"),
        "</div>"
      ))
    })
    
    # --- Table: Move Telemetry ---
    # The raw, verifiable evidence ledger ensuring transparent statistical claims.
    output$move_table <- renderDT({
      req(current_game())
      
      # 1. Create a version of the data with ONLY the columns we want to show
      display_df <- current_game() %>% 
        select(MoveNum, Phase, Played_Move, Stockfish_Move, Maia_Move, Loss, Match_Type) %>% 
        arrange(MoveNum)
      
      # 2. Render the table and style ONLY those display columns
      datatable(display_df, 
                options = list(pageLength = 8, dom = 'tip', scrollX = TRUE), 
                rownames = FALSE, 
                class = "cell-border stripe") %>%
        formatStyle(
          columns = colnames(display_df), # FIX: Style ONLY what is actually in the table
          backgroundColor = "#111111", 
          color = "#F9FAFB"
        )
    })
    
    # Export function for independent peer review of the flagged game.
    output$dl_audit <- downloadHandler(
      filename = function() { paste("Audit_Trail_", global_active_game(), ".csv", sep = "") },
      content = function(file) { write.csv(current_game(), file, row.names = FALSE) }
    )
  })
}