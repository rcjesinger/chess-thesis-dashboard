# TAB 2: R/tab_defense.R

# UI MODULE

defense_ui <- function(id) {
  ns <- NS(id)
  tagList(
    
    card(
      card_header("Surveillance Calibration & Data Export"),
      layout_columns(
        col_widths = c(5, 4, 3), 
        class = "align-items-start", 
        
        # COLUMN 1: Threshold Logic
        # shows an absolute definition of a "blunder" (like 50 CPL)
        # The dynamic Relative Z-score approach 
        # adjusts the threshold to the specific player's historical biological baseline,
        # ensuring we are measuring deviance from *their* norm, not a universal one.
        shinyWidgets::radioGroupButtons(
          inputId = ns("thresh_mode"),
          label = "Threshold Logic:",
          choices = c("Absolute (FIDE)" = "abs", "Relative (Personal)" = "rel"),
          selected = "abs",
          justified = FALSE, 
          status = "secondary",
          checkIcon = list(yes = icon("check"))
        ),
        
        # COLUMN 2: The Sociotechnical Stressors
        # If a player is using external assistance, their accuracy should remain perfectly flat regardless of board state. 
        # Humans, however, experience friction. Spatial restriction (Cramped) or heavy 
        # mathematical burden (Complexity) should naturally degrade human precision.
        div(
          class = "d-flex flex-column gap-2", 
          checkboxInput(
            inputId = ns("cramped_filter"), 
            label = "Apply 'Cramped' Filter (Spatial Stress)", 
            value = FALSE
          ),
          selectInput(
            inputId = ns("complexity_tier"),
            label = "Calculation Load (Relative Complexity):",
            choices = c("All Tiers" = "all", 
                        "Low (Bottom 33%)" = "low", 
                        "Medium (Middle 33%)" = "med", 
                        "High (Top 33%)" = "high"),
            selected = "all",
            width = "100%"
          )
        ),
        
        # COLUMN 3: Result Collection
        # Allows you to pull the filtered subset out of the dashboard for secondary 
        # statistical testing or inclusion in the thesis appendix.
        downloadButton(
          outputId = ns("export_results"), 
          label = "Export to CSV", 
          class = "btn-success mt-4" 
        )
      )
    ),
    
    # FORENSIC VALUE BOXES
    # These display the immediate aggregate conclusions of the active dataset,
    # establishing the mathematical boundaries of the player's behavior.
    layout_columns(
      col_widths = c(4, 4, 4),
      value_box(
        title = "Environment Significance", 
        value = tags$div(class = "fs-4", textOutput(ns("p_val"))), 
        showcase = bsicons::bs_icon("graph-up"),
        theme = value_box_theme(bg = "#111111", fg = "#F9FAFB") 
      ),
      value_box(
        title = "Games Flagged", 
        value = textOutput(ns("threshold_count")), 
        showcase = bsicons::bs_icon("exclamation-triangle-fill"),
        theme = value_box_theme(bg = "#111111", fg = "#2563EB"), 
        class = "border-primary"
      ),
      value_box(
        title = "Max Z-Score Observed", 
        value = textOutput(ns("z_score")), 
        showcase = bsicons::bs_icon("shield-exclamation"),
        theme = value_box_theme(bg = "#111111", fg = "#DC2626")
      )
    ),
    
    # MAIN STATISTICAL PLOTS 
    layout_columns(
      col_widths = c(6, 6),
      card(
        # Does algorithmic conformity degrades under extreme time pressure?
        card_header("The Time Paradox: Maia Match Rate vs. Clock Speed"), 
        plotlyOutput(ns("time_paradox_plot"), height = "350px") 
      ),
      card(
        # High complexity and tension should naturally induce a higher centipawn loss. 
        # If loss remains pinned at zero, the subject could be defying natural human cognitive friction.
        card_header("The Tension Paradox: Complexity vs. Error (Click to sync)"), 
        plotlyOutput(ns("tension_complexity_plot"), height = "350px")
      )
    ),
    
    # --- THE BLUNDER DESERT ---
    # Instead of looking at single moves, 
    # I chart the longest uninterrupted stretches of "perfect" play, split this across Isolated (Online) 
    # and Social (OTB) environments, 
    card(
      card_header("The Blunder Desert: Errorless Streaks by Environment (Click to sync)"), 
      plotlyOutput(ns("blunder_desert_plot"), height = "400px")
    )
  )
}

# THE SERVER MODULE
defense_server <- function(id, global_master, global_env, global_tempo, global_super_clash, global_active_game) {
  moduleServer(id, function(input, output, session) {
    
    # funnels the global parameters through my specific defense parameters.
    filtered_data <- reactive({
      req(exists("main_data"))
      df <- main_data
      if (global_master() != "All") df <- df %>% filter(proper_identity == global_master())
      if (global_env() != "All") df <- df %>% filter(environment == global_env())
      if (global_tempo() != "All") df <- df %>% filter(Tempo == global_tempo())
      if (global_super_clash() == TRUE) df <- df %>% filter(is_super_clash == TRUE)
      
      # Apply the Cramped test
      if (input$cramped_filter == TRUE && "Cramped" %in% colnames(df)) {
        df <- df %>% filter(Cramped == TRUE)
      }
      
      # Apply the Complexity Tier Filter
      # I used a dynamic quantile method here to calculate the tertile breaks (33rd/66th percentiles).
      # Note: I purposely calculate the breaks based on the FULL main_data, not the filtered subset,
      # so that a "High Complexity" game means the same thing universally across all players and eras.
      if (input$complexity_tier != "all" && "Complexity" %in% colnames(df)) {
        
        df$Complexity <- as.numeric(unlist(df$Complexity))
        
        breaks <- quantile(as.numeric(unlist(main_data$Complexity)), probs = c(0.33, 0.66), na.rm = TRUE)
        
        if (input$complexity_tier == "low") {
          df <- df %>% filter(Complexity < breaks[1])
        } else if (input$complexity_tier == "med") {
          df <- df %>% filter(Complexity >= breaks[1] & Complexity <= breaks[2])
        } else if (input$complexity_tier == "high") {
          df <- df %>% filter(Complexity > breaks[2])
        }
      }
      
      return(df)
    })
    
    output$export_results <- downloadHandler(
      filename = function() {
        paste0("Defense_Results_", global_master(), "_", Sys.Date(), ".csv")
      },
      content = function(file) {
        write.csv(filtered_data(), file, row.names = FALSE)
      }
    )
    
    # VALUE BOXES
    
    # The formal T-Test
    # Are online errors mathematically distinct from over-the-board errors? 
    # If p > 0.05, the player's online accuracy is statistically indistinguishable from physical play.
    output$p_val <- renderText({ 
      df <- filtered_data() %>% filter(!is.na(Loss))
      req(nrow(df) > 0)
      if(length(unique(df$environment)) < 2) return("N/A (Both Envs Required)")
      
      iso_loss <- df$Loss[df$environment == "Isolated"]
      soc_loss <- df$Loss[df$environment == "Social"]
      if(length(iso_loss) < 2 || length(soc_loss) < 2) return("Insufficient Data")
      
      test_result <- t.test(iso_loss, soc_loss)
      p <- test_result$p.value
      if(p < 0.001) return("< 0.001") else return(as.character(round(p, 3)))
    })
    
    # Calculates number of games containing a breach of selected threshold metric
    output$threshold_count <- renderText({ 
      df <- filtered_data() %>% filter(!is.na(Loss))
      req(nrow(df) > 0)
      
      total_games <- length(unique(df$Game_ID))
      
      if (input$thresh_mode == "abs") {
        flagged_games <- df %>% filter(Loss > 50) %>% pull(Game_ID) %>% unique()
      } else {
        # Capped the raw loss at 300 (Z-score logic) to prevent a single 
        # dropped queen from heavily skewing the standard deviation, then scaled
        df$Loss_Capped <- pmin(df$Loss, 300)
      
        sd_loss <- sd(df$Loss_Capped, na.rm = TRUE)
        df$Z <- if(!is.na(sd_loss) && sd_loss > 0) as.vector(scale(df$Loss_Capped)) else 0
        
        flagged_games <- df %>% filter(Z > 3.0) %>% pull(Game_ID) %>% unique()
      }
      
      paste0(length(flagged_games), " / ", total_games)
    })
    
    # Proves biological variance exists by highlighting the most extreme error in the dataset.
    output$z_score <- renderText({ 
      req(nrow(filtered_data()) > 0)
      capped_loss <- pmin(filtered_data()$Loss, 300, na.rm = TRUE)
      
      sd_loss <- sd(capped_loss, na.rm = TRUE)
      z_vec <- if(!is.na(sd_loss) && sd_loss > 0) as.vector(scale(capped_loss)) else 0
      
      round(max(z_vec, na.rm = TRUE), 2)
    })
    
    # PLOTS
    
    # Plot A: The Time Paradox
    # Groups data strictly by Tempo to determine if stripping away calculation time
    # forces the human to rely on more intuition (Maia match rate).
    output$time_paradox_plot <- renderPlotly({
      df <- filtered_data()
      validate(need(nrow(df) > 0, "No data available."))
      
      tp_df <- df %>%
        group_by(Tempo, environment) %>%
        summarise(Match_Rate = mean(Maia_Match == 1, na.rm = TRUE) * 100, .groups = "drop")
      
      p <- ggplot(tp_df, aes(x = Tempo, y = Match_Rate, fill = environment, 
                             text = paste("Env:", environment, "<br>Rate:", round(Match_Rate, 1), "%"))) +
        geom_bar(stat = "identity", position = "dodge") + 
        scale_fill_manual(values = c("Isolated" = "#2563EB", "Social" = "#DC2626")) + 
        theme_minimal() + 
        theme(
          plot.background = element_rect(fill = "#0A0A0A", color = NA),
          panel.background = element_rect(fill = "#0A0A0A", color = NA),
          text = element_text(color = "#F9FAFB", family = "JetBrains Mono"),
          axis.text = element_text(color = "#9CA3AF"),
          panel.grid.major = element_line(color = "#1F2937"),
          panel.grid.minor = element_blank()
        )
      
      ggplotly(p, tooltip = "text") %>% 
        toWebGL() %>%
        layout(paper_bgcolor = "#0A0A0A", plot_bgcolor = "#0A0A0A") %>% 
        config(displayModeBar = FALSE)
    })
    
    # Plot B: The Tension Paradox
    # Maps Complexity against Centipawn Loss here to see if a player maintains 
    # engine-like precision even when the board is mathematically overwhelming.
    # The 'Tension' variable colors the points to show the volatility of the evaluation.
    output$tension_complexity_plot <- renderPlotly({
      df <- filtered_data() %>% ungroup()
      
      validate(need(all(c("Loss", "Complexity", "Tension") %in% colnames(df)), 
                    "Requires pre-calculated 'Complexity' and 'Tension' columns."))
      
      plot_df <- df %>%
        select(Game_ID, Loss, Complexity, Tension) %>% 
        tidyr::unnest(cols = c(Loss, Complexity, Tension)) %>% 
        mutate(
          Loss = as.numeric(Loss),
          Complexity = as.numeric(Complexity),
          Tension = as.numeric(Tension)
        ) %>%
        filter(!is.na(Loss), !is.na(Complexity), !is.na(Tension)) %>%
        as.data.frame() 
      
      validate(need(nrow(plot_df) > 0, "No valid data to plot after cleaning."))
      
      if(nrow(plot_df) > 10000) plot_df <- plot_df %>% sample_n(10000)
      
      p <- ggplot(plot_df, aes(x = Complexity, y = Loss, color = Tension,
                               customdata = Game_ID,
                               text = paste("Game ID:", Game_ID,
                                            "<br>Loss:", round(Loss, 1), 
                                            "<br>Complexity:", round(Complexity, 1),
                                            "<br>Tension:", round(Tension, 1)))) +
        geom_point(alpha = 0.6, size = 1.5) +
        scale_color_viridis_c(option = "plasma") +
        coord_cartesian(ylim = c(0, 300)) + 
        geom_hline(yintercept = 50, linetype = "dashed", color = "#DC2626") + 
        theme_minimal() +
        theme(
          plot.background = element_rect(fill = "#0A0A0A", color = NA),
          panel.background = element_rect(fill = "#0A0A0A", color = NA),
          text = element_text(color = "#F9FAFB", family = "JetBrains Mono"),
          axis.text = element_text(color = "#9CA3AF"),
          panel.grid.major = element_line(color = "#1F2937"),
          panel.grid.minor = element_blank(),
          legend.position = "none"
        )
      
      gp <- ggplotly(p, tooltip = "text", source = "tension_click")
      gp <- event_register(gp, "plotly_click") 
      
      gp %>% 
        toWebGL() %>%
        layout(paper_bgcolor = "#0A0A0A", plot_bgcolor = "#0A0A0A") %>% 
        config(displayModeBar = FALSE)
    })
    
    # Plot C: The Blunder Desert
    # Calculates the longest uninterrupted streak of accurate moves a player makes.
    # A highly compressed Social (Online) distribution versus a massive Isolated (OTB) distribution
    # proves that physical environments allow for deeper, longer states of sustained calculation.
    output$blunder_desert_plot <- renderPlotly({
      df <- filtered_data() %>% filter(!is.na(Loss))
      validate(need(nrow(df) > 0, "No data available."))
      
      global_mean <- mean(df$Loss, na.rm = TRUE)
      plot_df <- df %>%
        arrange(Game_ID, MoveNum) %>%
        group_by(Game_ID, environment) %>%
        mutate(
          Threshold = if(input$thresh_mode == "abs") 50 else (global_mean * 0.8),
          Is_Err = ifelse(Loss > Threshold, 1, 0), 
          run_id = cumsum(Is_Err)
        ) %>%
        group_by(Game_ID, environment, run_id) %>%
        summarise(streak_len = sum(Is_Err == 0), .groups = "drop") %>%
        group_by(Game_ID, environment) %>%
        summarise(max_streak = max(streak_len), .groups = "drop")
      
      p <- ggplot(plot_df, aes(x = environment, y = max_streak, 
                               fill = environment, color = environment,
                               customdata = Game_ID, 
                               text = paste("Environment:", environment,
                                            "<br>Max Streak:", max_streak,
                                            "<br>Game ID:", Game_ID))) +
        geom_boxplot(alpha = 0.3, outlier.shape = NA, color = "#F9FAFB") +
        geom_jitter(width = 0.2, alpha = 0.4) +
        scale_fill_manual(values = c("Isolated" = "#2563EB", "Social" = "#DC2626")) +
        scale_color_manual(values = c("Isolated" = "#2563EB", "Social" = "#DC2626")) +
        theme_minimal() +
        theme(
          plot.background = element_rect(fill = "#0A0A0A", color = NA),
          panel.background = element_rect(fill = "#0A0A0A", color = NA),
          text = element_text(color = "#F9FAFB", family = "JetBrains Mono"),
          axis.text = element_text(color = "#9CA3AF"),
          panel.grid.major = element_line(color = "#1F2937"),
          panel.grid.minor = element_blank(),
          legend.position = "none"
        )
      
      gp <- ggplotly(p, tooltip = "text", source = "blunder_click")
      gp <- event_register(gp, "plotly_click")
      
      gp %>% 
        toWebGL() %>%
        layout(paper_bgcolor = "#0A0A0A", plot_bgcolor = "#0A0A0A") %>% 
        config(displayModeBar = FALSE)
    })
    
    # INTERACTIVE CLICK 
    
    # The Blunder Desert
    observeEvent(event_data("plotly_click", source = "blunder_click"), {
      click_data <- event_data("plotly_click", source = "blunder_click")
      if (is.null(click_data)) return()
      clicked_game_id <- click_data$customdata[1]
      
      if (!is.null(clicked_game_id) && clicked_game_id != "") {
        tryCatch({
          global_active_game(clicked_game_id)
          showNotification(paste("Syncing Board to:", clicked_game_id), type = "message")
        }, error = function(e) {
          warning("Global update failed: ", e$message)
        })
      }
    })
    
    # Tension Paradox
    observeEvent(event_data("plotly_click", source = "tension_click"), {
      click_data <- event_data("plotly_click", source = "tension_click")
      if (is.null(click_data)) return()
      
      clicked_game_id <- click_data$customdata[1]
      
      if (!is.null(clicked_game_id) && clicked_game_id != "") {
        tryCatch({
          global_active_game(clicked_game_id)
          showNotification(paste("Syncing Board to:", clicked_game_id), type = "message")
        }, error = function(e) {
          warning("Global update failed: ", e$message)
        })
      }
    })
    
  })
}