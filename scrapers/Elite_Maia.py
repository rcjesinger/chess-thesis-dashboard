import chess
import chess.pgn
import chess.engine
import pandas as pd
import os
import time
import io

# --- PATHS ---
LC0_PATH = r"C:\Users\rcjes\OneDrive\Desktop\Chess_Thesis\lc0-v0.32.1-windows-cpu-dnnl\lc0.exe"
MAIA_WEIGHTS = r"C:\Users\rcjes\OneDrive\Desktop\Chess_Thesis\ckpt-40-400000.pb"
INPUT_CSV = "Master_Engine_Queue.csv"
OUTPUT_CSV = "Analysis_Maia_FullGame.csv"

def run_maia_full_analysis():
    if not os.path.exists(LC0_PATH):
        print(f"❌ Error: Lc0 not found at {LC0_PATH}"); return
    
    # Initialize Lc0 with Maia weights
    try:
        # Using 4 threads to help CPU-based DNNL backend
        maia = chess.engine.SimpleEngine.popen_uci(LC0_PATH)
        maia.configure({"WeightsFile": MAIA_WEIGHTS, "Threads": 4})
        print("🤖 Maia Engine Loaded. Analyzing FULL games...")
    except Exception as e:
        print(f"❌ Failed to start Lc0: {e}"); return

    df = pd.read_csv(INPUT_CSV)
    results = []
    start_time = time.time()

    for idx, row in df.iterrows():
        # Convert CSV string back to PGN object
        game = chess.pgn.read_game(io.StringIO(row['Movetext']))
        if not game: continue
        
        target_id = row['proper_identity']
        white_name = str(row['white'])
        master_color = chess.WHITE if target_id in white_name else chess.BLACK
        
        # --- FORENSIC ANCHOR ---
        # Safely grab the game_uid, fallback to row index if missing
        game_id = row.get('game_uid', f"G_{idx}") 
        # -----------------------
        
        if (idx + 1) % 5 == 0:
            elapsed = (time.time() - start_time) / 3600
            print(f"🚀 Full Game Progress: {idx+1}/{len(df)} | {target_id} | {elapsed:.2f} hrs")

        board = game.board()
        for node in game.mainline():
            # REMOVED: 10-40 filter. Now analyzes EVERY move.
            if board.turn == master_color:
                try:
                    # Maia prediction (Humanity check)
                    info = maia.analyse(board, chess.engine.Limit(nodes=1))
                    maia_move = info["pv"][0]
                    
                    is_match = 1 if node.move == maia_move else 0
                    
                    results.append({
                        "Game_ID": game_id,              # <--- ADDED TO EXPORT
                        "proper_identity": target_id,
                        "environment": row['Environment'],
                        "game_type": row['Tempo'],
                        "MoveNum": board.fullmove_number, 
                        "Maia_Match": is_match,
                        "Played_Move": node.move.uci(),
                        "Maia_Move": maia_move.uci()
                    })
                except Exception as e:
                    print(f"⚠️ Error: {e}")
            
            board.push(node.move)

        # Frequent checkpoints because full-game analysis is long
        if (idx + 1) % 20 == 0:
            pd.DataFrame(results).to_csv(OUTPUT_CSV, index=False)

    maia.quit()
    pd.DataFrame(results).to_csv(OUTPUT_CSV, index=False)
    print(f"\n✅ FULL ANALYSIS DONE. Total Time: {(time.time() - start_time)/60:.1f} minutes")

if __name__ == "__main__":
    run_maia_full_analysis()