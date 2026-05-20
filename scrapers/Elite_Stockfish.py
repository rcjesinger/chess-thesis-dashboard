import chess, chess.pgn, chess.engine
import pandas as pd
import time, os, io

# --- CONFIG ---
STOCKFISH_PATH = r"C:\Users\rcjes\OneDrive\Desktop\Chess_Thesis\stockfish-windows-x86-64-avx2\stockfish\stockfish-windows-x86-64-avx2.exe"
INPUT_CSV = "Danya_End_Analysis_Input.csv"
OUTPUT_CSV = "Analysis_Stockfish_Danya_End.csv"

# EFFICIENCY PARAMETERS
THREADS = 6        
HASH_SIZE = 2048   
NODES_LIMIT = 250000 
MATE_VAL = 10000

def run_efficient_full_analysis():
    if not os.path.exists(STOCKFISH_PATH):
        print(f"❌ Error: Stockfish not found at {STOCKFISH_PATH}")
        return

    sf = chess.engine.SimpleEngine.popen_uci(STOCKFISH_PATH)
    sf.configure({"Threads": THREADS, "Hash": HASH_SIZE})
    
    df = pd.read_csv(INPUT_CSV)
    results = []
    start_time = time.time()

    print(f"🚀 Analyzing {len(df)} games... (Extracting FEN, Engine Moves, & Game IDs)")

    for idx, row in df.iterrows():
        game = chess.pgn.read_game(io.StringIO(row['Movetext']))
        if not game: continue
        
        target_id = row['proper_identity']
        master_color = chess.WHITE if target_id in str(row['white']) else chess.BLACK
        
        # Safely grab the game_uid from your Queue, fallback to row index if missing
        game_id = row.get('game_uid', f"G_{idx}") 
        
        if (idx + 1) % 10 == 0:
            elapsed = (time.time() - start_time) / 3600
            print(f"📊 Progress: {idx+1}/{len(df)} | {target_id} | {elapsed:.2f} hrs")

        board = game.board()
        for node in game.mainline():
            move_num = board.fullmove_number
            
            if board.turn == master_color:
                try:
                    # 1. Evaluate BEFORE move
                    info = sf.analyse(board, chess.engine.Limit(nodes=NODES_LIMIT))
                    best_ev = info["score"].pov(master_color).score(mate_score=MATE_VAL)
                    
                    # --- THE FORENSIC VARIABLES ---
                    current_fen = board.fen()
                    stockfish_move = info["pv"][0].uci() if "pv" in info and info["pv"] else ""
                    played_move = node.move.uci() # Capture what the human actually did
                    # ------------------------------

                    # 2. Evaluate AFTER move (Skip if already +/- 10.0)
                    if abs(best_ev) < 1000:
                        board.push(node.move)
                        post_info = sf.analyse(board, chess.engine.Limit(nodes=NODES_LIMIT))
                        played_ev = post_info["score"].pov(master_color).score(mate_score=MATE_VAL)
                    else:
                        board.push(node.move)
                        played_ev = best_ev

                    results.append({
                        "Game_ID": game_id,                # <--- ADDED
                        "proper_identity": target_id,
                        "environment": row['Environment'],
                        "game_type": row['Tempo'],
                        "MoveNum": move_num,
                        "Loss": max(0, best_ev - played_ev),
                        "Best_Eval": best_ev,
                        "Color": "White" if master_color == chess.WHITE else "Black",
                        "Played_Move": played_move,        # <--- ADDED
                        "Stockfish_Move": stockfish_move,  # <--- ADDED
                        "FEN": current_fen                 # <--- ADDED
                    })
                except Exception:
                    board.push(node.move)
            else:
                board.push(node.move)

        if (idx + 1) % 50 == 0:
            pd.DataFrame(results).to_csv(OUTPUT_CSV, index=False)

    sf.quit()
    pd.DataFrame(results).to_csv(OUTPUT_CSV, index=False)
    print(f"✅ Full Analysis Complete: {OUTPUT_CSV}")

if __name__ == "__main__":
    run_efficient_full_analysis()