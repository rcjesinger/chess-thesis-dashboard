# helper.R

library(stringr)

# POSITION TENSION (T)
# mathematically defines the "sharpness" of a game 
# calculates the Euclidean distance of evaluation swings; measures the mathematical penalty for deviation.
# A perfectly stable positional game will have near-zero tension. A chaotic 
# tactical bloodbath will have high tension, creating severe cognitive friction 
# for a human, but zero friction for an engine.
calculate_tension <- function(eval_sequence) {
  diffs <- diff(eval_sequence)
  tension <- sqrt(sum(diffs^2, na.rm = TRUE))
  return(tension)
}


# POSITION COMPLEXITY (C)
# Since empty squares + pieces always = 64, measuring "empty space" was mathematically redundant. 
# uses material density as a proxy for the decision-tree branching factor.
# Higher complexity equates to higher cognitive stress, allowing us to map 
# algorithmic conformity directly against the mathematical difficulty of the board.
calculate_complexity <- function(fen) {
  # Extract the board portion of the FEN (before the first space)
  board <- str_split(fen, " ")[[1]][1]
  
  # Count total pieces remaining on the board (A-Z and a-z)
  piece_density <- str_count(board, "[A-Za-z]")
  
  return(piece_density)
}


# FEN PARSER
# Extracts specific board-state environments to test if 
# physical/spatial conditions break a player's algorithmic conformity. 
# Like, if a human  matches an engine at 70% in open space, do they 
# become less accurate board becomes more closed?
parse_fen_anomalies <- function(fen) {
  
  parts <- str_split(fen, " ")[[1]]
  board <- parts[1]
  
  # Queenless Environment (Testing Endgame/Positional Grinding)
  # Removes the most powerful piece to see if grandmaster's accuracy is artificially 
  # inflated by memorized tactical sequences rather than real understanding.
  no_queens <- !str_detect(board, "q|Q")
  
  # Cramped Test 
  # FENs are written from Rank 8 down to Rank 1 (ranks being rows on the board, from black to white) 
  ranks <- str_split(board, "/")[[1]]
  
  # Checks how many pieces (white or black) are cramped in white's territory.
  # If precision remains flawless under extreme spatial restriction, then it flags 
  # a potential disconnect between stressor and result
  bottom_half <- paste(ranks[6:8], collapse = "")
  piece_count_cramped <- str_count(bottom_half, "[A-Za-z]")
  is_cramped <- piece_count_cramped > 12 # Threshold for cramped
  
  # Pawn Material Equality
  # Checks if game is materially balanced in terms of pawn structure,
  # avoides endgames where one side is just blindly pushing a pawn to upgrade.
  # Ensures the engine accuracy is measured in states of actual competitive tension.
  equal_pawns <- str_count(board, "p") == str_count(board, "P")
  
  return(list(
    queenless = no_queens,
    cramped = is_cramped,
    equal_pawns = equal_pawns
  ))
}