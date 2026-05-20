# TAB 4: R/tab_simulator.R 

# UI MODULE

simulator_ui <- function(id) {
  ns <- NS(id)
  tagList(
    layout_columns(
      col_widths = c(4, 8),
      height = "500px", 
      
      card(
        card_header("Surveillance Threshold Configuration"),
        p("Adjust the Confidence Level to observe systemic flagging rates.", 
          style = "color: #9CA3AF; font-size: 0.85rem;"),
        
        # slides it from an aggressive "precautionary" 
        # state (80%) to an extreme "beyond a reasonable doubt" FIDE standard (99.9%), 
        # then user can actively visualize danger of era-contingent false positives.
        sliderInput(ns("threshold"), "Algorithmic Confidence Threshold:", 
                    min = 80, max = 99.9, value = 95, step = 0.1, post = "%"),
        hr(style = "border-color: #374151;"),
        div(style = "margin-top: auto; padding-bottom: 20px;",
            h3(textOutput(ns("flagged_count")), style = "color: #DC2626; font-weight: bold; text-align: center;"),
            p("Games Flagged in Current Roster", style = "text-align: center; color: #9CA3AF;")
        )
      ),
      
      card(
        card_header("Population Distribution & Flagging Net"),
        plotlyOutput(ns("dist_plot"), height = "100%") 
      )
    ),
    
    # FLAGGED GAMES REGISTRY
    card(
      card_header("Flagged Games Registry"),
      div(style = "background-color: #0A0A0A; padding: 10px;",
          DTOutput(ns("flagged_table")),
          downloadButton(ns("dl_flagged"), "Download Flagged Registry (.csv)", class = "btn-danger w-100 mt-3")
      )
    )
  )
}

# SERVER MODULE
simulator_server <- function(id, global_master, global_env, global_tempo, global_super_clash) {
  moduleServer(id, function(input, output, session) {
    
    # BASE FILTER
    base_data <- reactive({
      req(exists("main_data"))
      df <- main_data
      if (!is.null(global_master()) && global_master() != "All") df <- df[df$proper_identity == global_master(), ]
      if (global_env() != "All") df <- df[df$environment == global_env(), ]
      if (global_tempo() != "All") df <- df[df$Tempo == global_tempo(), ]
      if (isTRUE(global_super_clash())) df <- df[df$is_super_clash == TRUE, ] 
      return(df)
    })
    
    # GAME-LEVEL AGGREGATION & Z-SCORE MATH
    game_stats <- reactive({
      df <- base_data()
      req(nrow(df) > 0)
      
      games <- df %>%
        group_by(Game_ID, proper_identity, White, Black, environment) %>%
        summarise(
          Total_Moves = n(),
          Avg_Loss = mean(pmin(Loss, 300), na.rm = TRUE), 
          Maia_Match_Rate = mean(Maia_Match == 1, na.rm = TRUE) * 100,
          .groups = "drop"
        ) %>%
        # Excludes games under 15 moves, as memorized opening theory would falsely trigger the algorithm.
        filter(Total_Moves > 15) 
      
      pop_mean <- mean(games$Avg_Loss, na.rm = TRUE)
      pop_sd <- sd(games$Avg_Loss, na.rm = TRUE)
      
      games %>%
        mutate(
          # INVERTED Z-SCORE: Because a lower centipawn loss means better play 
          # (and potentially suspicious algorithmic mimicry), standard Z-score math must be flipped. 
          # Subtracts the game's loss from the mean so a POSITIVE Z-score represents suspiciously high accuracy
          Z_Score = if(!is.na(pop_sd) && pop_sd > 0) round((pop_mean - Avg_Loss) / pop_sd, 2) else 0,
          
          # Translates the mathematical Z-Score into a cumulative probability percentage 
          # aka the likelihood that this game violates normal biological variance.
          Confidence = round(pnorm(Z_Score) * 100, 2),
          Status = ifelse(Confidence >= input$threshold, "Flagged", "Cleared")
        ) %>%
        arrange(desc(Confidence))
    })
    
    # FLAGGED COUNT
    output$flagged_count <- renderText({
      req(game_stats())
      flags <- sum(game_stats()$Status == "Flagged", na.rm = TRUE)
      paste(flags, "GAMES")
    })
    
    # DISTRIBUTION PLOT
    # Visualizes the "climate" of the player's career
    output$dist_plot <- renderPlotly({
      req(game_stats())
      df <- game_stats()
      
      # Reverse Engineering the Threshold: Converts the user's percentage slider 
      # (e.g., 95%) back into a Z-score (e.g., 1.64)
      threshold_z <- qnorm(input$threshold / 100)
      
      p <- ggplot(df, aes(x = Z_Score, fill = Status)) +
        geom_histogram(bins = 50, color = "#0A0A0A", alpha = 1.0) + 
        geom_vline(xintercept = threshold_z, color = "white", linetype = "dashed", linewidth = 1) +
        scale_fill_manual(values = c("Cleared" = "#374151", "Flagged" = "#DC2626")) +
        theme_minimal() +
        theme(
          plot.background = element_rect(fill = "#0A0A0A", color = NA),
          panel.background = element_rect(fill = "#0A0A0A", color = NA),
          text = element_text(color = "#F9FAFB", family = "JetBrains Mono"),
          axis.text = element_text(color = "#9CA3AF"),
          panel.grid.major = element_line(color = "#1F2937"),
          panel.grid.minor = element_blank(),
          legend.position = "none"
        ) +
        scale_x_continuous(breaks = seq(-6, 6, by = 2)) + 
        labs(x = "Game-Level Z-Score (Deviance)", y = "Count")
      
      ggplotly(p, tooltip = c("x", "count"), height = 500) %>% 
        toWebGL() %>%
        layout(
          paper_bgcolor = "#0A0A0A", 
          plot_bgcolor = "#0A0A0A",
          margin = list(t = 40, b = 60) 
        ) %>% 
        config(displayModeBar = FALSE)
    })
    
    # ACTIVE TABLE (The Formal Ledger)
    # applys a dynamic "Chain of Custody" color-coding to visualize the severity of the algorithmic accusation.
    output$flagged_table <- renderDT({
      req(game_stats())
      
      display_df <- game_stats() %>%
        filter(Status == "Flagged") %>%
        select(Game_ID, proper_identity, White, Black, environment, Total_Moves, Avg_Loss, Maia_Match_Rate, Z_Score, Confidence) %>%
        mutate(
          Avg_Loss = round(Avg_Loss, 1),
          Maia_Match_Rate = paste0(round(Maia_Match_Rate, 1), "%"),
          Confidence_Val = Confidence, 
          Confidence = paste0(Confidence, "%")
        ) %>%
        rename(`Target ID` = proper_identity, Environment = environment, `Avg Loss` = Avg_Loss, `Maia Match` = Maia_Match_Rate)
      
      datatable(display_df %>% select(-Confidence_Val), 
                options = list(
                  pageLength = 10, 
                  dom = 'tip', 
                  scrollX = TRUE,
                  scrollY = "400px",
                  scrollCollapse = TRUE,
                  paging = FALSE 
                ),
                rownames = FALSE, 
                class = "cell-border stripe hover") %>%
        formatStyle(
          columns = colnames(display_df %>% select(-Confidence_Val)),
          backgroundColor = "#111111",
          color = "#F9FAFB"
        ) %>%
        formatStyle(
          'Confidence',
          # Escalating warning colors. Yellow for high confidence (>95%), 
          # and bold red for "Gold Standard" accusations breaching 98.9%.
          color = styleInterval(c(95, 98.9), c('#F9FAFB', '#FBBF24', '#EF4444')),
          fontWeight = 'bold'
        )
    })
    
    output$dl_flagged <- downloadHandler(
      filename = function() { paste("Flagged_Games_Registry_", Sys.Date(), ".csv", sep="") },
      content = function(file) {
        write.csv(game_stats() %>% filter(Status == "Flagged"), file, row.names = FALSE)
      }
    )
  })
}