# R/tab_historical.R 

# UI MODULE
historical_ui <- function(id) {
  ns <- NS(id)  
  tagList(
    layout_columns(
      col_widths = c(12),
      
      # THE SILICON GHOST 
      # Visualizes "Algorithmic Socialization." By tracking the Maia Match 
      # Rate across decades, we can mathematically prove how human intuition has 
      # steadily drifted toward engine-optimal patterns as players grew up training with machines.
      card(
        card_header("The Silicon Ghost: Algorithmic Socialization Over Time"),
        plotlyOutput(ns("evolution_plot"), height = "450px")
      )
    ),
    layout_columns(
      col_widths = c(12),
      
      # HISTORICAL BACK-TEST
      # Applies the strict, modern thresholds for "Anomalous Precision" to pre-engine legends (who could 
      # not possibly have cheated with smartphones), to quantify the exact rate of "False Positives"
      card(
        card_header("The Back-Test: Applying Modern Surveillance to Historical Legends"),
        p("Click any data point to sync that game with the Interactive Board.", 
          style = "color: #2563EB; font-weight: bold; font-size: 0.85rem; padding-left: 5px;"),
        plotlyOutput(ns("backtest_plot"), height = "500px")
      )
    )
  )
}

# SERVER MODULE
historical_server <- function(id, global_active_game) {
  moduleServer(id, function(input, output, session) {
    
    forensic_theme <- function() {
      theme_minimal() +
        theme(
          plot.background = element_rect(fill = "#0A0A0A", color = NA),
          panel.background = element_rect(fill = "#0A0A0A", color = NA),
          text = element_text(color = "#F9FAFB", family = "JetBrains Mono"),
          axis.text = element_text(color = "#9CA3AF"),
          panel.grid.major = element_line(color = "#1F2937"),
          panel.grid.minor = element_blank(),
          legend.background = element_rect(fill = "#0A0A0A"),
          legend.text = element_text(color = "#F9FAFB")
        )
    }
    
    historical_data <- reactive({
      req(exists("main_data"))
      main_data %>%
        mutate(Year = as.numeric(substr(Date.orig, 1, 4))) %>%
        filter(!is.na(Year))
    })
    
    # Plot 1: Evolution
    # Plots the Maia Match Rate over time. The LOESS curve acts as the "Ghost"
    # the invisible gravitational pull of the engine era shifts the biological 
    # baseline of human intuition upward.
    output$evolution_plot <- renderPlotly({
      df <- historical_data()
      plot_df <- df %>%
        group_by(Year, proper_identity) %>%
        summarise(Maia_Match_Rate = mean(Maia_Match == 1, na.rm = TRUE) * 100, .groups = "drop")
      
      p <- ggplot(plot_df, aes(x = Year, y = Maia_Match_Rate, color = proper_identity)) +
        geom_point(size = 3, alpha = 0.7) +
        geom_smooth(aes(group = 1), method = "loess", color = "#A855F7", se = FALSE, linetype = "dashed") +
        forensic_theme() +
        scale_color_viridis_d(option = "turbo")
      
      ggplotly(p) %>% layout(paper_bgcolor = "#0A0A0A", plot_bgcolor = "#0A0A0A")
    })
    
    # Plot 2: The Back-Test
    # Applies the exact flagging logic from Tab 4 (The Audit) to historical players 
    # to prove that modern static thresholds often over-read and penalize human brilliance.
    output$backtest_plot <- renderPlotly({
      df <- historical_data()
      game_df <- df %>%
        group_by(Game_ID, proper_identity, Year) %>%
        summarise(
          Total_Moves = n(), 
          SF_Match = mean(Played_Move == Stockfish_Move, na.rm = TRUE) * 100,
          Avg_Loss = mean(pmin(Loss, 300), na.rm = TRUE),
          .groups = "drop"
        ) %>%
        # filters out games with < 15 moves. Pure opening theory would trigger a false "Anomalous Precision" flag otherwise.
        filter(Total_Moves > 15) %>% 
        
        # (>60% Stockfish Match and <15 CPL) to identify era-dependent false positives
        mutate(Verdict = ifelse(SF_Match > 60 & Avg_Loss < 15, "Anomalous Precision", "Normal Variance"))
      
      p <- ggplot(game_df, aes(x = Year, y = Avg_Loss, color = Verdict, 
                               customdata = Game_ID, 
                               text = paste("<b>Player:</b>", proper_identity, 
                                            "<br><b>Year:</b>", Year,
                                            "<br><b>Avg Loss:</b>", round(Avg_Loss, 1), 
                                            "<br><b>SF Match:</b>", round(SF_Match, 1), "%"))) +
        geom_jitter(width = 0.3, alpha = 0.6, size = 2) +
        geom_hline(yintercept = 15, color = "#9CA3AF", linetype = "dotted") +
        forensic_theme() +
        scale_color_manual(values = c("Anomalous Precision" = "#DC2626", "Normal Variance" = "#374151")) +
        scale_y_reverse() 
      # ^^reverses the Y-axis so "low error" (suspicious perfection) floats to the top visually.
      
      ggplotly(p, tooltip = "text", source = "historical_click") %>%
        layout(
          paper_bgcolor = "#0A0A0A", 
          plot_bgcolor = "#0A0A0A",
          clickmode = "event+select",
          legend = list(orientation = "h", x = 0, y = -0.15)
        ) %>% 
        config(displayModeBar = FALSE)
    })
    
    # CLICK LISTENER
    observeEvent(event_data("plotly_click", source = "historical_click"), {
      click_data <- event_data("plotly_click", source = "historical_click")
      req(click_data)
      clicked_game_id <- click_data$customdata[1]
      if (!is.null(clicked_game_id)) {
        global_active_game(clicked_game_id)
      }
    })
  })
}