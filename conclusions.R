# conclusions.R
library(dplyr)
library(tidyr)
library(writexl) 

# this script collapses the moves into the final, static summary tables
main_data <- readRDS("data/optimized/main_data_thesis_final.rds")

data_standardized <- main_data %>%
  group_by(proper_identity) %>%
  mutate(
    # I limited max loss to 300 centipawns. Dropping a Queen 
    # (900 loss) vs dropping a Rook (500 loss) are both terminal blunders. Capping 
    # it at 300 prevents a single blunder from destroying the player's 
    # overall standard deviation math.
    Loss_Capped = pmin(Loss, 300, na.rm = TRUE),
    Z_Score = if (isTRUE(sd(Loss_Capped, na.rm = TRUE) > 0)) as.numeric(scale(Loss_Capped)) else 0
  ) %>%
  ungroup()

# TAB 1 - INTERACTIVE BOARD RESULTS 
# Calculates shift between Social (OTB) and Isolated (Online) play.
interactive_board_results <- data_standardized %>%
  filter(!is.na(Played_Move), !is.na(Stockfish_Move)) %>%
  group_by(proper_identity, environment) %>%
  summarise(
    Total_Moves = n(),
    Stockfish_Match_Pct = round(mean(Played_Move == Stockfish_Move, na.rm = TRUE) * 100, 2),
    Maia_Match_Pct = round(mean(Maia_Match == 1, na.rm = TRUE) * 100, 2),
    Avg_Centipawn_Loss = round(mean(Loss, na.rm = TRUE), 2),
    .groups = "drop"
  ) %>%
  pivot_wider(names_from = environment, 
              values_from = c(Total_Moves, Stockfish_Match_Pct, Maia_Match_Pct, Avg_Centipawn_Loss)) %>%
  mutate(
    Stockfish_Shift = Stockfish_Match_Pct_Isolated - Stockfish_Match_Pct_Social,
    Maia_Shift = Maia_Match_Pct_Isolated - Maia_Match_Pct_Social
  )


# TAB 2 - THE DEFENSE RESULTS
# Calculate the global complexity breaks first so the tertiles are universally standard.
# Ensures a "High Complexity" game means the same thing for all players
comp_breaks <- quantile(as.numeric(unlist(main_data$Complexity)), probs = c(0.33, 0.66), na.rm = TRUE)

defense_conclusions <- data_standardized %>%
  group_by(Game_ID, proper_identity, environment) %>%
  summarise(
    Avg_Comp = mean(as.numeric(Complexity), na.rm = TRUE),
    Cramped_Pct = mean(Cramped == TRUE, na.rm = TRUE),
    Avg_Loss = mean(Loss, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    Complexity_Tier = case_when(
      Avg_Comp < comp_breaks[1] ~ "Low",
      Avg_Comp <= comp_breaks[2] ~ "Med",
      TRUE ~ "High"
    ),
    Is_Cramped_Game = ifelse(Cramped_Pct > 0.20, "Cramped", "Open")
  )

# How much does a player's accuracy decay when 
# the position becomes mathematically overwhelming?
complexity_results <- defense_conclusions %>%
  group_by(proper_identity, Complexity_Tier) %>%
  summarise(Avg_Game_Loss = round(mean(Avg_Loss, na.rm = TRUE), 2), Games = n(), .groups = "drop") %>%
  pivot_wider(names_from = Complexity_Tier, values_from = c(Avg_Game_Loss, Games)) %>%
  mutate(Friction_Delta = Avg_Game_Loss_High - Avg_Game_Loss_Low) %>%
  arrange(desc(Friction_Delta))

# Spatial analysis measures the impact of physical board suffocation.
spatial_results <- defense_conclusions %>%
  group_by(proper_identity, Is_Cramped_Game) %>%
  summarise(Avg_Game_Loss = round(mean(Avg_Loss, na.rm = TRUE), 2), Games = n(), .groups = "drop") %>%
  filter(!is.na(Is_Cramped_Game)) %>%
  pivot_wider(names_from = Is_Cramped_Game, values_from = c(Avg_Game_Loss, Games)) %>%
  mutate(Spatial_Shift = Avg_Game_Loss_Cramped - Avg_Game_Loss_Open)

defense_time_paradox <- data_standardized %>%
  group_by(proper_identity, Tempo, environment) %>%
  summarise(Maia_Match_Pct = round(mean(Maia_Match == 1, na.rm = TRUE) * 100, 2), .groups = "drop") %>%
  pivot_wider(names_from = environment, values_from = Maia_Match_Pct)

# The blunder desert calculates maximum endurance. What is the absolute longest 
# a human can play without dropping 50+ centipawns?
defense_blunder_desert <- data_standardized %>%
  filter(!is.na(Loss)) %>%
  arrange(proper_identity, Game_ID, MoveNum) %>%
  group_by(proper_identity, Game_ID, environment) %>%
  mutate(Is_Err = ifelse(Loss > 50, 1, 0), run_id = cumsum(Is_Err)) %>%
  group_by(proper_identity, Game_ID, environment, run_id) %>%
  summarise(streak_len = sum(Is_Err == 0), .groups = "drop") %>%
  group_by(proper_identity, Game_ID, environment) %>%
  summarise(max_streak = max(streak_len), .groups = "drop") %>%
  group_by(proper_identity, environment) %>%
  summarise(Avg_Max_Streak = round(mean(max_streak, na.rm = TRUE), 1), 
            Abs_Max_Streak = max(max_streak, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = environment, values_from = c(Avg_Max_Streak, Abs_Max_Streak))


# TAB 3 - THE INDEX RESULTS 
# Silicon Streaks-- Looks for unnatural strings of perfect engine compliance.
index_streaks <- data_standardized %>%
  filter(!is.na(Played_Move), !is.na(Stockfish_Move)) %>%
  arrange(proper_identity, Game_ID, MoveNum) %>%
  group_by(proper_identity, Game_ID, environment) %>%
  mutate(Is_Silicon = ifelse(Played_Move == Stockfish_Move, 1, 0), Streak_Breaker = cumsum(Is_Silicon == 0)) %>%
  group_by(proper_identity, Game_ID, environment, Streak_Breaker) %>%
  summarise(Consecutive_Silicon = sum(Is_Silicon), .groups = "drop") %>%
  group_by(proper_identity, environment) %>%
  summarise(Max_Silicon_Streak = max(Consecutive_Silicon, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = environment, values_from = Max_Silicon_Streak)

# 24-Hour Panopticon groups behavior into Day vs. Night shifts 
# to test for biological circadian dips.
index_fatigue <- data_standardized %>%
  mutate(Hour = as.numeric(as.character(local_hour))) %>% filter(!is.na(Hour)) %>%
  mutate(Time_Block = case_when(Hour >= 6 & Hour < 18 ~ "Daytime", TRUE ~ "Night/Fatigue")) %>%
  group_by(proper_identity, Time_Block) %>%
  summarise(Avg_Loss = round(mean(Loss, na.rm = TRUE), 2), 
            Blunder_Rate = round(mean(Loss > 50, na.rm = TRUE) * 100, 2), .groups = "drop") %>%
  pivot_wider(names_from = Time_Block, values_from = c(Avg_Loss, Blunder_Rate))

# Phase Fingerprint: Does intuition collapse in the middlegame?
index_phase_fingerprint <- data_standardized %>%
  group_by(Game_ID) %>% mutate(Max_Move = max(MoveNum, na.rm = TRUE)) %>% ungroup() %>%
  mutate(Phase = case_when(MoveNum <= (Max_Move / 3) ~ "1_Beg", MoveNum <= (2 * Max_Move / 3) ~ "2_Mid", TRUE ~ "3_End")) %>%
  group_by(proper_identity, Phase, environment) %>%
  summarise(Maia_Match_Pct = round(mean(Maia_Match == 1, na.rm = TRUE) * 100, 2), .groups = "drop") %>%
  pivot_wider(names_from = Phase, values_from = Maia_Match_Pct, names_prefix = "Match_")

# Stress test uses same board sharpness math 
# (Complexity + Tension) that I implemented in tab_index.R, avoiding any variance issues
index_stress_test <- data_standardized %>%
  filter(!is.na(Loss), !is.na(Complexity), !is.na(Tension)) %>%
  group_by(proper_identity, Game_ID, environment) %>%
  summarise(
    Avg_Comp = mean(as.numeric(Complexity), na.rm = TRUE),
    Avg_Tens = mean(as.numeric(Tension), na.rm = TRUE),
    Maia_Match_Pct = mean(Maia_Match == 1, na.rm = TRUE) * 100, 
    .groups = "drop"
  ) %>%
  mutate(
    Board_Sharpness = as.numeric(scale(Avg_Comp)) + as.numeric(scale(Avg_Tens)),
    Board_State = case_when(
      Board_Sharpness < quantile(Board_Sharpness, 0.33, na.rm = TRUE) ~ "1_Positional",
      Board_Sharpness > quantile(Board_Sharpness, 0.66, na.rm = TRUE) ~ "3_Tactical",
      TRUE ~ "2_Dynamic"
    )
  ) %>%
  group_by(proper_identity, Board_State, environment) %>%
  summarise(Avg_Match_Pct = round(mean(Maia_Match_Pct, na.rm = TRUE), 2), .groups = "drop") %>%
  pivot_wider(names_from = Board_State, values_from = Avg_Match_Pct)

# TAB 4 - THE AUDIT RESULTS
# Automates a strict FIDE-style anomaly check. It flags any game (over 15 moves) 
# where a human played with >60% Stockfish accuracy and <15 average centipawn loss.
audit_anomalies <- data_standardized %>%
  group_by(proper_identity, Game_ID, environment) %>%
  summarise(
    Total_Moves = n(),
    SF_Rate = round(mean(Played_Move == Stockfish_Move, na.rm = TRUE) * 100, 1),
    Avg_Loss = round(mean(Loss, na.rm = TRUE), 1),
    .groups = "drop"
  ) %>%
  filter(Total_Moves > 15) %>%
  mutate(Is_Anomalous = ifelse(SF_Rate > 60 & Avg_Loss < 15, TRUE, FALSE)) %>%
  group_by(proper_identity, environment) %>%
  summarise(
    Total_Games = n(),
    Anomalous_Games = sum(Is_Anomalous),
    Anomaly_Rate_Pct = round((Anomalous_Games / Total_Games) * 100, 2),
    .groups = "drop"
  ) %>%
  pivot_wider(names_from = environment, values_from = c(Total_Games, Anomalous_Games, Anomaly_Rate_Pct))

# TAB 5 - CI SIMULATOR RESULTS
sim_games <- data_standardized %>%
  group_by(Game_ID, proper_identity, environment) %>%
  summarise(Avg_Loss = mean(pmin(Loss, 300), na.rm = TRUE), Total_Moves = n(), .groups = "drop") %>%
  filter(Total_Moves > 15)

pop_mean <- mean(sim_games$Avg_Loss, na.rm = TRUE)
pop_sd <- sd(sim_games$Avg_Loss, na.rm = TRUE)

simulator_sensitivity <- sim_games %>%
  mutate(
    # inverted Z-score calculation. lower Centipawn Loss indicates 
    # stronger play, the math is flipped so "too perfect" yields a high positive deviance.
    Z_Score = if(!is.na(pop_sd) && pop_sd > 0) (pop_mean - Avg_Loss) / pop_sd else 0,
    Confidence = pnorm(Z_Score) * 100
  ) %>%
  group_by(proper_identity, environment) %>%
  summarise(
    Total_Games = n(),
    Flagged_90_Pct = sum(Confidence >= 90),
    Flagged_95_Pct = sum(Confidence >= 95),
    Flagged_99_Pct = sum(Confidence >= 99),
    Flagged_99_9_Pct = sum(Confidence >= 99.9),
    .groups = "drop"
  )


# TAB 6 - DANYA MEMORIAL RESULTS (The Baseline Contrast)
# isolates Kramnik's online games to pit "The Auditor" directly 
# against Naroditsky ("The Native").
danya_data <- readRDS("data/optimized/danya_light.rds")

memorial_contrast <- bind_rows(
  data_standardized %>% 
    filter(grepl("Kramnik", proper_identity), environment == "Isolated") %>% 
    mutate(Player = "Kramnik (The Auditor)"),
  danya_data %>% 
    mutate(Player = "Naroditsky (The Native)")
) %>%
  filter(!is.na(Loss), !is.na(Played_Move), !is.na(Stockfish_Move)) %>%
  group_by(Player) %>%
  summarise(
    Total_Moves = n(),
    Avg_Loss = round(mean(Loss, na.rm = TRUE), 2),
    Median_Loss = round(median(Loss, na.rm = TRUE), 2),
    Maia_Match_Pct = round(mean(Maia_Match == 1, na.rm = TRUE) * 100, 2),
    Stockfish_Match_Pct = round(mean(Played_Move == Stockfish_Move, na.rm = TRUE) * 100, 2),
    .groups = "drop"
  )

# TAB 7 - HISTORICAL AUDITOR RESULTS
historical_evolution <- data_standardized %>%
  mutate(Year = as.numeric(substr(Date.orig, 1, 4))) %>%
  filter(!is.na(Year)) %>%
  group_by(Year, proper_identity) %>%
  summarise(
    Games_Played = n_distinct(Game_ID),
    Maia_Match_Rate = round(mean(Maia_Match == 1, na.rm = TRUE) * 100, 2),
    .groups = "drop"
  )

# Back-testing the modern tribunal thresholds against the 1970s and 1980s 
# to quantify "False Positives" on historical legends.
historical_backtest <- data_standardized %>%
  mutate(Year = as.numeric(substr(Date.orig, 1, 4))) %>%
  filter(!is.na(Year)) %>%
  group_by(Game_ID, proper_identity, Year) %>%
  summarise(
    Total_Moves = n(),
    SF_Match = mean(Played_Move == Stockfish_Move, na.rm = TRUE) * 100,
    Avg_Loss = mean(pmin(Loss, 300), na.rm = TRUE),
    .groups = "drop"
  ) %>%
  filter(Total_Moves > 15) %>%
  mutate(Verdict = ifelse(SF_Match > 60 & Avg_Loss < 15, "Anomalous Precision", "Normal Variance")) %>%
  group_by(proper_identity, Year, Verdict) %>%
  summarise(Game_Count = n(), .groups = "drop") %>%
  pivot_wider(names_from = Verdict, values_from = Game_Count, values_fill = 0) %>%
  mutate(
    Total_Games = `Normal Variance` + `Anomalous Precision`,
    Historical_Flag_Rate = round((`Anomalous Precision` / Total_Games) * 100, 2)
  ) %>%
  arrange(proper_identity, Year)

# COMPREHENSIVE RESULTS  
thesis_results_comprehensive <- data_standardized %>%
  group_by(Game_ID, proper_identity, White, Black, Result.orig, is_super_clash) %>%
  summarise(FIDE_Blunders = sum(Loss > 50, na.rm = TRUE), Relative_Blunders = sum(Z_Score > 3.0, na.rm = TRUE), .groups = "drop") %>%
  group_by(proper_identity) %>%
  summarise(Total_Games = n(), Total_FIDE_Blunders = sum(FIDE_Blunders, na.rm = TRUE), Total_Rel_Blunders = sum(Relative_Blunders, na.rm = TRUE)) %>%
  arrange(desc(Total_Games))

env_comparison <- data_standardized %>%
  group_by(proper_identity, environment) %>%
  summarise(Games = n_distinct(Game_ID), FIDE_per_Game = round(sum(Loss > 50, na.rm = TRUE) / n_distinct(Game_ID), 2), .groups = "drop") %>%
  pivot_wider(names_from = environment, values_from = c(Games, FIDE_per_Game))

# make 1 workbook
thesis_workbook <- list(
  "Comprehensive_Stats"  = thesis_results_comprehensive,
  "Env_Shift_Totals"     = env_comparison,
  "Interactive_Board"    = interactive_board_results,
  "Defense_Complexity"   = complexity_results,
  "Defense_Spatial"      = spatial_results,
  "Defense_Time_Paradox" = defense_time_paradox,
  "Defense_Blunder_Des"  = defense_blunder_desert,
  "Index_Streaks"        = index_streaks,
  "Index_Fatigue"        = index_fatigue,
  "Index_Phase_Finger"   = index_phase_fingerprint,
  "Index_Stress_Test"    = index_stress_test,
  "Audit_Anomalies"      = audit_anomalies,
  "Simulator_Thresholds" = simulator_sensitivity,
  "Memorial_Native_Base" = memorial_contrast,
  "Hist_Evolution"       = historical_evolution,
  "Hist_Backtest"        = historical_backtest
)

writexl::write_xlsx(thesis_workbook, "Thesis_Master_Results.xlsx")