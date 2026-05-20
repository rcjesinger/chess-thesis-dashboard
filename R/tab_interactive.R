# TAB 1: tab_interactive.R 

# UI MODULE
interactive_ui <- function(id) {
  ns <- NS(id)
  tagList(
    tags$head(
      tags$style(HTML("
        /* Forensic Dark Mode CSS for Interactive Tab */
        .board-container { background: transparent; padding: 10px 0 25px 0; border-bottom: 1px solid #1F2937; }
        
        /* THE MOVE CARDS */
        /* These cards act as the 'chain of custody' for each ply in the game. */
        .move-card { 
          padding: 15px; margin-bottom: 12px; background: #111111; border-radius: 6px; 
          border: 1px solid #1F2937; color: #F9FAFB; transition: all 0.2s; 
          border-left: 6px solid #374151; cursor: pointer;
        }
        .move-card:hover { border-color: #2563EB; box-shadow: 0 0 8px rgba(37,99,235,0.2); }
        .active-move-border { 
          border-left-color: #2563EB !important; border-left-width: 8px !important; 
          background: #1e1e1e !important; border: 1px solid #2563EB;
        }

        /* DISTINCTIVE DATA RIBBONS */
        /* Color theory is utilized here to make anomalies instantly pop out during scrolling. */
        .ribbon-blunder { border-left-color: #DC2626 !important; } /* Loss Red: Error */
        .ribbon-sf { border-left-color: #2563EB !important; }      /* Stockfish Blue: Machine-optimal path */
        .ribbon-human { border-left-color: #10B981 !important; }   /* Human Green: Expected biological variance */
        .ribbon-maia { border-left-color: #A855F7 !important; }    /* Maia Purple: Trained on Human Moves; Proxy */
        
        [id$='chess_board'] { width: 450px !important; height: 450px !important; }
        .case-dossier { background: #111111; border: 1px solid #1F2937; border-radius: 6px; padding: 15px; margin-bottom: 15px; color: #D1D5DB; }
        .case-dossier strong { color: #F9FAFB; font-weight: 700; }
        
        .dice-btn { background-color: #2563EB; border: none; color: white; }
        .dice-btn:hover { background-color: #1D4ED8; color: white; }
      "))
    ),
    
    div(class = "board-container",
        fluidRow(
          column(width = 10, offset = 1, 
                 card(
                   layout_columns(
                     col_widths = c(4, 8),
                     
                     # --- LEFT PANEL: FORENSIC CONTROLS ---
                     div(
                       h5("Forensic Controls"),
                       
                       div(style = "display: flex; align-items: flex-end; gap: 8px;",
                           div(style = "flex-grow: 1;", 
                               selectizeInput(ns("select_game"), "Active Case:", choices = NULL)
                           ),
                           actionButton(ns("btn_random"), "", icon = icon("dice"), class = "btn-secondary dice-btn")
                       ),
                       
                       
                       uiOutput(ns("case_dossier")),
                       
                       radioButtons(ns("search_mode"), "Behavior Filter:", 
                                    choices = list(
                                      "All Games" = "all", 
                                      "Suspicious Precision (High SF)" = "sf", 
                                      "Cognitive Fractures (Blunders)" = "blunder"
                                    )),
                       hr(style = "border-color: #374151;"),
                       
                       # PERSPECTIVE SWITCHER: Toggles physical board rendering 
                       # to show alternate realities
                       h6("Perspective Switcher"),
                       shinyWidgets::radioGroupButtons(
                         inputId = ns("view_mode"), label = NULL,
                         choices = c("Human", "Stockfish", "Maia"),
                         selected = "Human", justified = TRUE, status = "primary"
                       )
                     ),
                     
                     # THE CHESSBOARD
                     div(
                       style = "display: flex; flex-direction: column; align-items: center; min-height: 480px;",
                       rchess::chessboardjsOutput(ns("chess_board"), width = "450px", height = "450px"),
                       
                       div(
                         style = "display: flex; gap: 15px; align-items: center; margin-top: 10px;",
                         h4(textOutput(ns("current_move_label")), style = "margin: 0; font-weight: bold; color: #F9FAFB;"),
                         uiOutput(ns("eval_badge"))
                       )
                     )
                   )
                 )
          )
        )
    ),
    
    # MOVES TRANSCRIPT
    fluidRow(
      column(width = 10, offset = 1, style = "margin-top: 30px; padding-bottom: 100px;",
             h3("Behavioral Transcript", style = "color: #9CA3AF; margin-bottom: 20px; font-family: 'Inter', sans-serif;"),
             uiOutput(ns("scroll_timeline"))
      )
    ),
    
    tags$script(HTML(sprintf("
      $(document).on('click', '.move-card', function() {
        var idx = $(this).attr('data-index');
        Shiny.setInputValue('%s', idx, {priority: 'event'});
      });
    ", ns("selected_index"))))
  )
}


# SERVER MODULE
interactive_server <- function(id, global_master, global_env, global_tempo, global_super_clash, global_active_game) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # applies data filtering
    filtered_pool <- reactive({
      req(exists("main_data"))
      df <- main_data 
      
      # Apply Global Filters
      if (global_master() != "All") df <- df %>% filter(proper_identity == global_master())
      if (global_env() != "All") df <- df %>% filter(environment == global_env())
      if (global_tempo() != "All") df <- df %>% filter(Tempo == global_tempo())
      if (global_super_clash() == TRUE) df <- df %>% filter(is_super_clash == TRUE) 
      
      if (input$search_mode == "blunder") {
        # Loss >= 300, aka dropping a full piece
        ids <- df %>% filter(!is.na(Loss) & Loss >= 300) %>% pull(Game_ID) %>% unique()
        df <- df %>% filter(Game_ID %in% ids)
        
      } else if (input$search_mode == "sf") {
        
        # Requires at least 20 calculated moves (post-opening) at an extreme 70%+ match rate.
        ids <- df %>% 
          filter(MoveNum > 15) %>% 
          group_by(Game_ID) %>% 
          summarise(
            sf_rate = mean(Played_Move == Stockfish_Move, na.rm = TRUE),
            moves_evaluated = n(),
            .groups = 'drop'
          ) %>% 
          filter(moves_evaluated >= 20 & sf_rate >= 0.70) %>% 
          pull(Game_ID)
        
        df <- df %>% filter(Game_ID %in% ids)
      }
      return(df)
    })
    
    # dropdown formatting
    game_choices <- reactive({
      df <- filtered_pool()
      req(nrow(df) > 0)
      meta <- df %>% group_by(Game_ID) %>%
        summarise(White = first(White), Black = first(Black), Year = substr(first(Date.orig), 1, 4), Result = first(Result.orig), .groups = 'drop') %>%
        mutate(Label = paste0(White, " vs. ", Black, " (", Year, ") [", Result, "]"))
      setNames(meta$Game_ID, meta$Label)
    })
    
    observeEvent(game_choices(), {
      choices <- game_choices()
      
      num_games <- length(choices)
      dynamic_label <- paste0("Active Case (", num_games, " Games Found):")
      
      current_sel <- isolate(input$select_game)
      new_sel <- if (!is.null(current_sel) && current_sel %in% choices && current_sel != "") current_sel else choices[1]
      
      updateSelectizeInput(session, "select_game", 
                           label = dynamic_label, 
                           choices = choices, 
                           selected = new_sel, 
                           server = TRUE)
    }, ignoreInit = FALSE)
    
    # RANDOM BUTTON
    observeEvent(input$btn_random, {
      choices <- game_choices()
      req(length(choices) > 0)
      random_id <- sample(choices, 1)
      updateSelectizeInput(session, "select_game", choices = choices, selected = random_id, server = TRUE)
      global_active_game(random_id)
      active_idx(1) # Reset board to move 1
      shinyWidgets::updateRadioGroupButtons(session, "view_mode", selected = "Human")
    })
    
    # GLOBAL SYNC
    observeEvent(input$select_game, {
      if(!is.null(input$select_game) && input$select_game != "") {
        global_active_game(input$select_game)
      }
    }, ignoreInit = TRUE)
    
    observeEvent(global_active_game(), {
      choices <- game_choices()
      if(!is.null(global_active_game()) && input$select_game != global_active_game() && global_active_game() %in% choices) {
        updateSelectizeInput(session, "select_game", choices = choices, selected = global_active_game(), server = TRUE)
      }
    }, ignoreInit = TRUE)
    
    

    output$case_dossier <- renderUI({
      if (global_super_clash() == TRUE && global_master() == "All") {
        return(
          div(class = "case-dossier", style = "border: 1px solid #f39c12; background: rgba(243, 156, 18, 0.1);",
              tags$div(style = "color: #f39c12; font-weight: bold; margin-bottom: 5px;", 
                       icon("triangle-exclamation"), " Forensic Recommendation"),
              p("Super-Clash mode is active. To avoid blending statistics, please select a specific Grandmaster in the sidebar to isolate behavioral markers for one side of the board.",
                style = "font-size: 13px; color: #D1D5DB; margin: 0;")
          )
        )
      }
      
      req(input$select_game)
      df <- filtered_pool() %>% filter(Game_ID == input$select_game)
      validate(need(nrow(df) > 0, "No records match filters.")) 
      meta <- df[1, ]
      
      # historical PGNs (like early Fischer games) often lack Elo ratings, say unrated
      w_elo <- if("WhiteElo.orig" %in% colnames(meta) && !is.na(meta$WhiteElo.orig)) meta$WhiteElo.orig else "Unrated"
      b_elo <- if("BlackElo.orig" %in% colnames(meta) && !is.na(meta$BlackElo.orig)) meta$BlackElo.orig else "Unrated"
      
      tags$div(class = "case-dossier",
               tags$div(strong("White: "), meta$White, tags$span(style="color: #9CA3AF;", paste0(" (", w_elo, ")"))),
               tags$div(strong("Black: "), meta$Black, tags$span(style="color: #9CA3AF;", paste0(" (", b_elo, ")"))),
               tags$hr(style = "margin: 8px 0; border-color: #374151;"),
               tags$div(tags$span(strong("Event: "), meta$Event.orig, style="margin-right: 15px;"),
                        tags$span(strong("Opening: "), paste0(meta$Opening_Name, " (", meta$ECO.orig, ")"))),
               tags$div(tags$span(strong("Env: "), meta$environment, style="margin-right: 15px;"),
                        tags$span(strong("Tempo: "), meta$Tempo)),
               tags$div(tags$span(strong("Result: "), meta$Result.orig, style="margin-right: 15px;"),
                        tags$span(strong("Date: "), substr(meta$Date.orig, 1, 4)))
      )
    })
    
    
    active_idx <- reactiveVal(1)
    observeEvent(input$selected_index, { 
      active_idx(as.numeric(input$selected_index)) 
      shinyWidgets::updateRadioGroupButtons(session, "view_mode", selected = "Human")
    })
    observeEvent(input$select_game, { active_idx(1) })
    
    # Reconstructs the exact board state at any given move
    target_fen <- reactive({
      req(input$select_game, active_idx(), input$view_mode)
      game_df <- filtered_pool() %>% filter(Game_ID == input$select_game) %>% arrange(MoveNum)
      req(nrow(game_df) > 0)
      idx <- max(1, min(active_idx(), nrow(game_df)))
      row <- game_df[idx, ]
      
      move_to_make <- switch(input$view_mode, "Human" = row$Played_Move, "Stockfish" = row$Stockfish_Move, "Maia" = row$Maia_Move)
      
      # extracts the board position, turn color, castling rights, and en passant availability.
      parts <- strsplit(trimws(row$FEN), " ")[[1]]
      board_part <- if(length(parts) >= 1) parts[1] else "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR"
      turn_part <- if(length(row$Color) > 0 && grepl("W", toupper(row$Color))) "w" else "b"
      castling_part <- if(length(parts) >= 3) parts[3] else "-"
      ep_part <- if(length(parts) >= 4) parts[4] else "-"
      legal_start_fen <- paste(board_part, turn_part, castling_part, ep_part, "0 1", sep=" ")
      
      if (length(move_to_make) == 0 || is.na(move_to_make) || move_to_make == "") return(legal_start_fen)
      
      tryCatch({
        ch <- rchess::Chess$new(legal_start_fen)
        move_str <- trimws(as.character(move_to_make))
        
        # Coordinates Notation & Promotions
        if (nchar(move_str) %in% c(4, 5)) {
          from_sq <- substr(move_str, 1, 2); to_sq <- substr(move_str, 3, 4)
          promo <- if (nchar(move_str) == 5) substr(move_str, 5, 5) else ""
          legal_moves_df <- ch$moves(verbose = TRUE)
          match_row <- if (promo != "") {
            legal_moves_df[legal_moves_df$from == from_sq & legal_moves_df$to == to_sq & legal_moves_df$promotion == promo, ]
          } else {
            legal_moves_df[legal_moves_df$from == from_sq & legal_moves_df$to == to_sq, ]
          }
          if (nrow(match_row) > 0) ch$move(match_row$san[1])
        } else { ch$move(move_str) }
        return(ch$fen())
      }, error = function(e) { return(legal_start_fen) })
    })
    
    # Board Renderer
    output$chess_board <- rchess::renderChessboardjs({
      df <- filtered_pool()
      req(input$select_game %in% df$Game_ID) 
      game_df <- df %>% filter(Game_ID == input$select_game)
      validate(need(nrow(game_df) > 0, "Board Offline."))
      req(target_fen())
      rchess::chessboardjs(fen = target_fen())
    })
    
    
    # TIMELINE 
    output$current_move_label <- renderText({ 
      req(input$select_game)
      game_df <- filtered_pool() %>% filter(Game_ID == input$select_game) %>% arrange(MoveNum)
      if(nrow(game_df) == 0) return("")
      idx <- max(1, min(active_idx(), nrow(game_df)))
      paste("Viewing Move:", game_df$MoveNum[idx]) 
    })
    
    # colors the Evaluation Badge (Blue = White Winning, Red = Black Winning)
    output$eval_badge <- renderUI({
      req(input$select_game)
      game_df <- filtered_pool() %>% filter(Game_ID == input$select_game) %>% arrange(MoveNum)
      
      if(nrow(game_df) == 0) return(NULL)
      idx <- max(1, min(active_idx(), nrow(game_df)))
      
      if(!"Best_Eval" %in% colnames(game_df)) return(tags$span("Eval: Offline", style = "background-color: #374151; color: white; padding: 5px 12px; border-radius: 12px; font-weight: bold; font-size: 14px;"))
      eval_val <- game_df$Best_Eval[idx]
      
      if(is.na(eval_val)) return(tags$span("Eval: N/A", style = "background-color: #374151; color: white; padding: 5px 12px; border-radius: 12px; font-weight: bold; font-size: 14px;"))
      eval_text <- if(eval_val > 0) paste0("+", eval_val) else as.character(eval_val)
      bg_color <- if(eval_val >= 1.0) "white" else if(eval_val <= -1.0) "black" else "green"
      tags$span(paste("Eval:", eval_text), style = sprintf("background-color: %s; color: white; padding: 5px 12px; border-radius: 12px; font-weight: bold; font-size: 14px;", bg_color))
    })
    
    # visual move cards via HTML tagging
    output$scroll_timeline <- renderUI({
      req(input$select_game)
      game_df <- filtered_pool() %>% filter(Game_ID == input$select_game) %>% arrange(MoveNum)
      validate(need(nrow(game_df) > 0, ""))
      
      lapply(seq_len(nrow(game_df)), function(i) {
        row <- game_df[i, ]
        
        ribbon <- if(!is.na(row$Loss) && row$Loss >= 50) "ribbon-blunder" else if(row$Played_Move == row$Stockfish_Move) "ribbon-sf" else "ribbon-human"
        
        tags$div(
          class = paste("move-card", ribbon, if(i == active_idx()) "active-move-border" else ""),
          `data-index` = i,
          fluidRow(
            column(2, h4(row$MoveNum, style = "color: #F9FAFB; margin-top: 5px; font-family: 'JetBrains Mono', monospace;")),
            
            # Human (Green)
            column(3, strong("Human:", style = "color: #10B981; font-size: 12px;"), 
                   br(), span(row$Played_Move, style="font-family: 'JetBrains Mono', monospace;")),
            
            # Stockfish (Blue)
            column(3, strong("SF:", style = "color: #2563EB; font-size: 12px;"), 
                   br(), span(row$Stockfish_Move, style="font-family: 'JetBrains Mono', monospace;")),
            
            # Maia (Purple)
            column(3, strong("Maia:", style = "color: #A855F7; font-size: 12px;"), 
                   br(), span(row$Maia_Move, style="font-family: 'JetBrains Mono', monospace;")),
            
            # Loss (Red)
            column(1, strong("Loss:", style = "color: #DC2626; font-size: 12px;"), 
                   br(), span(row$Loss, style="font-family: 'JetBrains Mono', monospace;"))
          )
        )
      })
    })
  })
}