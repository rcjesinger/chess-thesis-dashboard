# TAB 3: tab_index.R

# UI MODULE

index_ui <- function(id) {
  ns <- NS(id)  
  
  tagList(
    # ROW 1: CORE STYLISTIC PROFILING
    layout_columns(
      col_widths = c(4, 4, 4),
      
      # The Style Matrix: in a natural biological state, high volatility (messy, high-loss games) 
      # should correlate with lower engine compliance.
      card(card_header("The Style Matrix: Volatility vs. Compliance"), plotlyOutput(ns("style_matrix"))),
      
      # Stylistic Drift quantifies exactly how much the physical vs. digital platform 
      # alters the player's psychometric baselines (Accuracy, Precision, Endurance).
      card(card_header("Stylistic Drift (OTB vs. Online)"), plotlyOutput(ns("drift_radar"))), 
      
      # Phase Fingerprint: Maps accuracy across the lifespan of a game
      card(card_header("Game Phase Fingerprint"), plotlyOutput(ns("phase_fingerprint")))
    ),
    
    # ROW 2: BEHAVIORAL ANOMALIES & BIOLOGY
    layout_columns(
      col_widths = c(4, 4, 4),
      
      # Stylistic Performance
      card(
        card_header("Stylistic Performance (Positional vs. Tactical)"), 
        plotlyOutput(ns("stress_test_plot"))
      ),
      
      # Cognitive Fatigue
      card(
        card_header("Cognitive Fatigue: Accuracy over Move Depth"),
        plotlyOutput(ns("fatigue_plot"))
      ),
      
      # The Sleep Tracker
      card(
        card_header("The Sleep Tracker: 24-Hour Panopticon"),
        plotlyOutput(ns("sleep_tracker"))
      )
    )
  )
}

# SERVER MODULE 
index_server <- function(id, global_master, global_env, global_tempo, global_super_clash, global_active_game) {
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
    
    # MASTER DATA FILTER 
    filtered_data <- reactive({
      req(exists("main_data"))
      df <- main_data
      if (global_master() != "All") df <- df %>% filter(proper_identity == global_master())
      if (global_env() != "All") df <- df %>% filter(environment == global_env())
      if (global_tempo() != "All") df <- df %>% filter(Tempo == global_tempo())
      if (global_super_clash() == TRUE) df <- df %>% filter(is_super_clash == TRUE)
      return(df)
    })
    
    # PLOT 1: STYLE MATRIX 
    # A cluster of games in the top-right quadrant (High Volatility + High Compliance) identifies a player who 
    # perfectly matches intuitive machine lines even when the position is chaotic.
    output$style_matrix <- renderPlotly({
      df <- filtered_data() %>% filter(!is.na(Loss))
      validate(need(nrow(df) > 0, "No data available."))
      
      plot_df <- df %>%
        group_by(Game_ID, environment) %>%
        summarise(
          Avg_Loss = mean(pmin(Loss, 300), na.rm = TRUE),
          Match_Rate = mean(Maia_Match == 1, na.rm = TRUE) * 100,
          .groups = "drop"
        )
      
      p <- ggplot(plot_df, aes(x = Avg_Loss, y = Match_Rate, color = environment, 
                               customdata = Game_ID, 
                               text = paste("<b>Game ID:</b>", Game_ID, 
                                            "<br><b>Avg Loss:</b>", round(Avg_Loss,1), 
                                            "<br><b>Match:</b>", round(Match_Rate,1), "%"))) + 
        geom_point(size = 2, alpha = 0.5) +
        forensic_theme() +
        labs(x = "Game Volatility (Avg Loss)", y = "Maia Match Rate (%)") +
        scale_color_manual(values = c("Isolated" = "#2563EB", "Social" = "#DC2626"))
      
      ggplotly(p, tooltip = "text", source = "matrix_click") %>%
        toWebGL() %>%
        layout(paper_bgcolor = "#0A0A0A", plot_bgcolor = "#0A0A0A", clickmode = "event+select", margin = list(b = 40)) %>% 
        config(displayModeBar = FALSE)
    })
    
    observeEvent(event_data("plotly_click", source = "matrix_click"), {
      click_data <- event_data("plotly_click", source = "matrix_click")
      req(click_data)
      clicked_game_id <- click_data$customdata[1]
      if (!is.null(clicked_game_id)) global_active_game(clicked_game_id)
    })
    
    # PLOT 2: PHASE FINGERPRINT 
    # Slices every game into 1/3 proportional chunks to standardize
    output$phase_fingerprint <- renderPlotly({
      df <- filtered_data() %>%
        group_by(Game_ID) %>%
        mutate(Max_Move = max(MoveNum, na.rm = TRUE)) %>%
        ungroup() %>%
        mutate(Phase = factor(case_when(
          MoveNum <= (Max_Move / 3) ~ "Beginning",
          MoveNum <= (2 * Max_Move / 3) ~ "Middle",
          TRUE ~ "Endgame"
        ), levels = c("Beginning", "Middle", "Endgame"))) %>%
        group_by(Phase, environment) %>%
        summarise(Match_Rate = mean(Maia_Match == 1, na.rm = TRUE) * 100, .groups = "drop")
      
      p <- ggplot(df, aes(x = Phase, y = Match_Rate, fill = environment,
                          text = paste("<b>Phase:</b>", Phase, "<br><b>Match:</b>", round(Match_Rate, 1), "%"))) +
        geom_bar(stat = "identity", position = "dodge", alpha = 0.9) + 
        forensic_theme() +
        labs(x = "Game Phase (Relative Length)", y = "Engine Match Rate (%)") +
        scale_fill_manual(values = c("Isolated" = "#2563EB", "Social" = "#DC2626"))
      
      ggplotly(p, tooltip = "text") %>%
        toWebGL() %>%
        layout(paper_bgcolor = "#0A0A0A", plot_bgcolor = "#0A0A0A", margin = list(b = 50)) %>% 
        config(displayModeBar = FALSE)
    })
    
    # PLOT 3: STYLISTIC PERFORMANCE 
    output$stress_test_plot <- renderPlotly({
      df <- filtered_data() %>% filter(!is.na(Loss))
      validate(need(nrow(df) > 0, "No data available."))
      
      plot_df <- df %>%
        group_by(Game_ID, environment) %>%
        summarise(
          Avg_Complexity = mean(as.numeric(Complexity), na.rm = TRUE),
          Avg_Tension = mean(as.numeric(Tension), na.rm = TRUE),
          Match_Rate = mean(Maia_Match == 1, na.rm = TRUE) * 100,
          .groups = "drop"
        ) %>%
        # Create a unified "Sharpness" score by standardizing (Z-scaling) and adding 
        # the complexity (piece density) and tension (evaluation volatility) metrics.
        mutate(
          # scaling is skipped on 1-2 games
          Board_Sharpness = if(n() > 2) as.numeric(scale(Avg_Complexity)) + as.numeric(scale(Avg_Tension)) else 0,
          
          # Uses Tertile Method on the new unified Sharpness metric to classify games
          Board_State = factor(if(n() > 2) {
            case_when(
              Board_Sharpness < quantile(Board_Sharpness, 0.33, na.rm = TRUE) ~ "Positional",
              Board_Sharpness > quantile(Board_Sharpness, 0.66, na.rm = TRUE) ~ "Tactical",
              TRUE ~ "Dynamic"
            )
          } else {
            "Dynamic" 
            # Default assignment fallback for single game isolation
          }, levels = c("Positional", "Dynamic", "Tactical"))
        ) %>%
        group_by(Board_State, environment) %>%
        summarise(Match_Rate = mean(Match_Rate, na.rm = TRUE), .groups = "drop")
      
      p <- ggplot(plot_df, aes(x = Board_State, y = Match_Rate, fill = environment,
                               text = paste("<b>Profile:</b>", Board_State, "<br><b>Match:</b>", round(Match_Rate, 1), "%"))) +
        geom_col(position = "dodge", alpha = 0.9) +
        forensic_theme() + 
        labs(x = "Inherent Board Sharpness (Complexity + Tension)", y = "Engine Match Rate (%)") +
        scale_fill_manual(values = c("Isolated" = "#2563EB", "Social" = "#DC2626"))
      
      ggplotly(p, tooltip = "text") %>%
        toWebGL() %>%
        layout(paper_bgcolor = "#0A0A0A", plot_bgcolor = "#0A0A0A", margin = list(b = 40)) %>% 
        config(displayModeBar = FALSE)
    })
    
    # PLOT 4: COGNITIVE FATIGUE
    output$fatigue_plot <- renderPlotly({
      df <- filtered_data() %>% filter(!is.na(Loss))
      p <- ggplot(df, aes(x = MoveNum, y = pmin(Loss, 300), color = environment)) +
        geom_smooth(method = "gam", formula = y ~ s(x, bs = "cs"), se = FALSE, linewidth = 1.2) + 
        coord_cartesian(xlim = c(0, 80), ylim = c(0, 50)) +
        forensic_theme() + 
        labs(x = "Move Number", y = "Trend: Average Loss") +
        scale_color_manual(values = c("Isolated" = "#2563EB", "Social" = "#DC2626"))
      
      ggplotly(p) %>% 
        toWebGL() %>%
        layout(paper_bgcolor = "#0A0A0A", plot_bgcolor = "#0A0A0A", margin = list(b = 40)) %>% 
        config(displayModeBar = FALSE)
    })
    
    # PLOT 5: STYLISTIC DRIFT
    output$drift_radar <- renderPlotly({
      df <- filtered_data() %>% filter(!is.na(Loss))
      validate(need(nrow(df) > 0, "No data available."))
      
      game_lengths <- df %>% group_by(Game_ID, environment) %>% summarise(Length = max(MoveNum), .groups = "drop")
      
      radar_df <- df %>%
        group_by(environment) %>%
        summarise(
          `Accuracy (Match %)` = mean(Maia_Match == 1, na.rm = TRUE) * 100,
          `Precision (Low Loss)` = 100 - min(mean(pmin(Loss, 300), na.rm = TRUE), 100), 
          .groups = "drop"
        ) %>%
        left_join(
          # Scales endurance by 1.5 to safely normalize raw move depths
          game_lengths %>% group_by(environment) %>% summarise(`Endurance (Moves)` = min(mean(Length) * 1.5, 100), .groups = "drop"),
          by = "environment"
        ) %>%
        pivot_longer(cols = -environment, names_to = "Metric", values_to = "Score") %>%
        mutate(Score = as.numeric(Score))
      
      p <- ggplot(radar_df, aes(x = Score, y = Metric)) +
        geom_line(aes(group = Metric), color = "#4B5563", linewidth = 2) +
        geom_point(aes(color = environment, 
                       text = paste("<b>Metric:</b>", Metric,
                                    "<br><b>Environment:</b>", environment, 
                                    "<br><b>Score:</b>", round(Score, 1))), 
                   size = 6) + 
        forensic_theme() +
        labs(x = "Relative Score (0-100)", y = "") +
        scale_color_manual(values = c("Isolated" = "#2563EB", "Social" = "#DC2626")) +
        scale_x_continuous(limits = c(0, 100), breaks = c(0, 25, 50, 75, 100)) +
        theme(
          axis.text.y = element_text(face = "bold", size = 11), 
          panel.grid.major.y = element_blank()
        )
      
      ggplotly(p, tooltip = "text") %>%
        layout(
          paper_bgcolor = "#0A0A0A", 
          plot_bgcolor = "#0A0A0A", 
          margin = list(l = 140, b = 40)
        ) %>% 
        config(displayModeBar = FALSE)
    })
    
    # PLOT 6: SLEEP TRACKER
    output$sleep_tracker <- renderPlotly({
      df <- filtered_data()
      if ("local_hour" %in% colnames(df) && !all(is.na(df$local_hour))) {
        plot_df <- df %>%
          filter(!is.na(local_hour)) %>%
          group_by(local_hour, environment) %>%
          summarise(Match_Rate = mean(Maia_Match == 1, na.rm = TRUE) * 100, .groups = "drop")
        
        p <- ggplot(plot_df, aes(x = local_hour, y = Match_Rate, color = environment)) +
          geom_line(linewidth = 1.2) +
          geom_point(size = 2) +
          forensic_theme() +
          scale_x_continuous(breaks = seq(0, 23, by = 3), labels = paste0(seq(0, 23, by = 3), "h")) +
          labs(x = "Local Time (24H)", y = "Engine Match Rate (%)") +
          scale_color_manual(values = c("Isolated" = "#2563EB", "Social" = "#DC2626"))
        
        ggplotly(p) %>% 
          toWebGL() %>%
          layout(paper_bgcolor = "#0A0A0A", plot_bgcolor = "#0A0A0A", margin = list(b = 40)) %>% 
          config(displayModeBar = FALSE)
      } else {
        p <- ggplot() + 
          annotate("text", x = 0.5, y = 0.5, label = "Timestamp Data Unavailable", size = 5, color = "#9CA3AF") +
          forensic_theme() + theme_void()
        ggplotly(p) %>% 
          toWebGL() %>%
          layout(paper_bgcolor = "#0A0A0A", plot_bgcolor = "#0A0A0A") %>% 
          config(displayModeBar = FALSE)
      }
    })
  })
}