# R/tab_memorial.R

# UI MODULE (The Control Group)
memorial_ui <- function(id) {
  ns <- NS(id)
  tagList(
    tags$head(
      tags$style(HTML("
        .memorial-card { background-color: #0A0A0A; border: 1px solid #1F2937; border-radius: 6px; }
        .memorial-header { 
          background-color: #111111; color: #F9FAFB !important; font-weight: 600; 
          border-bottom: 1px solid #1F2937; text-transform: uppercase; letter-spacing: 1px;
        }
        .memorial-title-container { text-align: center; margin-bottom: 30px; padding-top: 20px; }
        .memorial-title { color: #F9FAFB; font-weight: 800; font-family: 'JetBrains Mono', monospace; }
        .memorial-subtitle { color: #9CA3AF; font-weight: 400; }
      "))
    ),
    
    div(class = "memorial-title-container",
        h2("The Prophet of Intuition", class = "memorial-title"),
        h5("A Digital Native Case Study: Daniel Naroditsky", class = "memorial-subtitle")
    ),
    
    # BASELINE METRICS
    layout_column_wrap(
      width = 1/3,
      gap = "15px",
      class = "mb-4", 
      style = "min-height: 180px;", 
      
      value_box(
        title = "Silicon Alignment", 
        value = textOutput(ns("mem_silicon")), 
        showcase = bsicons::bs_icon("cpu"),
        theme = value_box_theme(bg = "#111111", fg = "#2563EB") # Engine Blue
      ),
      value_box(
        title = "Humanity Baseline", 
        value = textOutput(ns("mem_humanity")), 
        showcase = bsicons::bs_icon("fingerprint"),
        theme = value_box_theme(bg = "#111111", fg = "#A855F7") # Maia Purple
      ),
      value_box(
        title = "Auditor Variance Delta", 
        value = textOutput(ns("mem_delta")), 
        showcase = bsicons::bs_icon("binoculars"),
        theme = value_box_theme(bg = "#111111", fg = "#10B981") # Human Green
      )
    ),
    
    # TIMELINE OF INTUITION
    # I Plots his rolling humanity over his final months of play. The goal is to show 
    # that "high engine matching" isn't a spike for a digital native; it's a stable climate.
    card(class = "memorial-card", full_screen = TRUE, 
         style = "min-height: 480px;",
         card_header("The Timeline of Intuition: Rolling Humanity Index", class = "memorial-header"),
         p("A 50-move rolling average of Maia Match rates across Daniel Naroditsky's isolated online play within the last few months of life.", 
           style = "color: #9CA3AF; font-size: 0.9rem; padding-left: 15px; padding-top: 10px; margin-bottom: 0;"),
         plotlyOutput(ns("danya_timeline"), height = "350px")
    ),
    
    layout_columns(
      col_widths = c(6, 6),
      
      # FLOW STATE (Density Plot)
      # Visualizes speed and accuracy. It proves that native online players 
      # operate in a low-loss, high-depth "flow state" that auditors often mistake for cheating.
      card(class = "memorial-card", full_screen = TRUE, 
           style = "min-height: 550px;",
           card_header("The 'Flow State': Speed Mastery Density", class = "memorial-header"),
           p("Density of moves based on Game Depth and Precision.", 
             style = "color: #9CA3AF; font-size: 0.85rem; padding-left: 15px; padding-top: 10px; margin-bottom: 0;"),
           plotlyOutput(ns("danya_flow"), height = "400px")
      ),
      
      # CONTRAST: NATIVE VS. AUDITOR
      # the statistical gap between Kramnik's physical-first approach and Danya's digital-first approach.
      card(class = "memorial-card", full_screen = TRUE, 
           style = "min-height: 550px;",
           card_header("The Contrast: Native vs. Auditor", class = "memorial-header"),
           p("Loss Variance: Naroditsky (Digital Native) vs. Kramnik (The Auditor) in Online play.", 
             style = "color: #9CA3AF; font-size: 0.85rem; padding-left: 15px; padding-top: 10px; margin-bottom: 0;"),
           plotlyOutput(ns("danya_contrast"), height = "400px")
      )
    )
  )
}

# THE SERVER MODULE
memorial_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    
    output$mem_silicon <- renderText({
      req(exists("danya_data"))
      rate <- mean(danya_data$Played_Move == danya_data$Stockfish_Move, na.rm = TRUE) * 100
      paste0(round(rate, 1), "%")
    })
    
    output$mem_humanity <- renderText({
      req(exists("danya_data"))
      rate <- mean(danya_data$Maia_Match == 1, na.rm = TRUE) * 100
      paste0(round(rate, 1), "%")
    })
    
    # The Delta: The absolute difference in average error between Kramnik 
    # (in Isolated online environments) and Naroditsky.
    output$mem_delta <- renderText({
      req(exists("main_data"), exists("danya_data"))
      k_loss <- mean(main_data$Loss[grepl("Kramnik", main_data$proper_identity) & main_data$environment == "Isolated"], na.rm = TRUE)
      d_loss <- mean(danya_data$Loss, na.rm = TRUE)
      delta <- abs(k_loss - d_loss)
      paste0(round(delta, 1), " CPL")
    })
    
    # Plot 1: Timeline
    output$danya_timeline <- renderPlotly({
      req(exists("danya_summary"))
      
      plot_df <- as.data.frame(danya_summary)
      
      validate(need("Date.orig" %in% colnames(plot_df), 
                    "'Date.orig' missing from summary. Please save global.R and restart."))
      
      plot_df$Date_Processed <- as.Date(gsub("\\.", "-", plot_df$Date.orig))
      plot_df <- plot_df[!is.na(plot_df$Date_Processed), ]
      
      p <- suppressWarnings(
        ggplot(plot_df, aes(x = Date_Processed, y = Rolling_Humanity, group = 1,
                            text = paste("Date:", Date_Processed, 
                                         "<br>Humanity:", round(Rolling_Humanity, 1), "%"))) +
          geom_line(color = "#10B981", alpha = 0.6) + 
          geom_smooth(method = "loess", color = "#A855F7", se = FALSE, linetype = "dashed", linewidth = 1) +
          theme_minimal() +
          theme(
            plot.background = element_rect(fill = "#0A0A0A", color = NA),
            panel.background = element_rect(fill = "#0A0A0A", color = NA),
            text = element_text(color = "#F9FAFB", family = "JetBrains Mono"),
            axis.text = element_text(color = "#9CA3AF"),
            panel.grid.major = element_line(color = "#1F2937"),
            panel.grid.minor = element_blank()
          ) +
          labs(x = "Game Date", y = "Maia Match %")
      )
      
      p_built <- ggplotly(p, tooltip = "text", height = 350) %>%
        toWebGL() %>%
        layout(paper_bgcolor = "#0A0A0A", plot_bgcolor = "#0A0A0A") %>% 
        config(displayModeBar = FALSE)
      
      plotly_build(p_built)
    })
    
    # Plot 2: Flow State 
    output$danya_flow <- renderPlotly({
      req(exists("danya_data"))
      # I filter out the massive blunder outliers (>150 loss) so the density heatmap 
      # doesn't get washed out by a few dropped queens.
      df <- danya_data %>% filter(!is.na(Loss), Loss <= 150)
      
      p <- ggplot(df, aes(x = MoveNum, y = Loss)) +
        geom_bin2d(bins = 60) + 
        scale_fill_viridis_c(option = "plasma", trans = "sqrt") + 
        theme_minimal() +
        theme(
          plot.background = element_rect(fill = "#0A0A0A", color = NA),
          panel.background = element_rect(fill = "#0A0A0A", color = NA),
          text = element_text(color = "#F9FAFB", family = "JetBrains Mono"),
          axis.text = element_text(color = "#9CA3AF"),
          panel.grid.major = element_line(color = "#1F2937"),
          panel.grid.minor = element_blank()
        ) +
        labs(x = "Move Depth", y = "Centipawn Loss")
      
      p_built <- ggplotly(p, height = 400) %>% 
        layout(paper_bgcolor = "#0A0A0A", plot_bgcolor = "#0A0A0A") %>% 
        config(displayModeBar = FALSE)
      
      plotly_build(p_built)
    })
    
    # Plot 3: Contrast (The Boxplot)
    output$danya_contrast <- renderPlotly({
      req(exists("main_data"), exists("danya_data"))
      
      # Extracts Kramnik's online data from the global pool, ignoring whatever 
      # the user clicked in the sidebar to ensure this comparison remains stable.
      k_data <- main_data %>%
        filter(grepl("Kramnik", proper_identity), environment == "Isolated") %>%
        mutate(Player = "Kramnik (The Auditor)")
      
      d_data <- danya_data %>% mutate(Player = "Naroditsky (The Native)")
      
      contrast_df <- bind_rows(k_data %>% select(Player, Loss), d_data %>% select(Player, Loss)) %>% filter(!is.na(Loss))
      
      p <- ggplot(contrast_df, aes(x = Player, y = Loss, fill = Player)) +
        geom_boxplot(alpha = 0.4, color = "#F9FAFB", outlier.shape = NA) +
        coord_cartesian(ylim = c(0, 80)) + 
        scale_fill_manual(values = c(
          "Kramnik (The Auditor)" = "#DC2626", # Social Red
          "Naroditsky (The Native)" = "#10B981" # Human Green
        )) +
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
        labs(x = "", y = "CPL Distribution")
      
      p_built <- ggplotly(p, height = 400) %>% 
        layout(paper_bgcolor = "#0A0A0A", plot_bgcolor = "#0A0A0A") %>% 
        config(displayModeBar = FALSE)
      
      plotly_build(p_built)
    })
  })
}