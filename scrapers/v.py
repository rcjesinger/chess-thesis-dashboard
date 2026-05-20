import chess.pgn
import pandas as pd
import os
import io

# --- 1. SETTINGS ---
ALL_PGN_FILES = [
    r"C:\Users\rcjes\OneDrive\Desktop\Chess_Thesis\Fischer.pgn",
    r"C:\Users\rcjes\OneDrive\Desktop\Chess_Thesis\Karpov.pgn",
    r"C:\Users\rcjes\OneDrive\Desktop\Chess_Thesis\Kasparov.pgn",
    r"C:\Users\rcjes\OneDrive\Desktop\Chess_Thesis\Kramnik.pgn",
    r"C:\Users\rcjes\OneDrive\Desktop\Chess_Thesis\Carlsen.pgn",
    r"C:\Users\rcjes\OneDrive\Desktop\Chess_Thesis\Nakamura.pgn",
    r"C:\Users\rcjes\OneDrive\Desktop\Chess_Thesis\Niemann.pgn",
    r"C:\Users\rcjes\OneDrive\Desktop\Chess_Thesis\Naroditsky.pgn",
    r"C:\Users\rcjes\OneDrive\Desktop\Chess_Thesis\titled_social_relay.pgn",
    r"C:\Users\rcjes\OneDrive\Desktop\Chess_Thesis\all_online.pgn",
    r"C:\Users\rcjes\OneDrive\Desktop\Chess_Thesis\Master_Isolated.pgn",
    r"C:\Users\rcjes\OneDrive\Desktop\Chess_Thesis\Master_Social.pgn"
]

# Robust Identity Map to catch OTB initials (e.g., Carlsen, M.)
identity_map = {
    "Naroditsky, Daniel": ["naroditsky, daniel", "rebeccaharris", "penguingm1", "danielnaroditsky", "danya", "naroditsky, d.", "naroditsky,d"],
    "Carlsen, Magnus": ["carlsen, magnus", "carlsen, m.", "nykterstein", "drnykterstein", "drdrunkenstein", "drgrekenstein", "manwithavan", "stl_carlsen"],
    "Nakamura, Hikaru": ["nakamura, hikaru", "nakamura, h.", "tsmftxh", "smallville", "capilanobridge", "star wars", "gmhikaru", "hikaru"],
    "Fischer, Robert James": ["fischer, robert james", "fischer, robert j.", "fischer, r.", "bobby fischer"],
    "Niemann, Hans": ["niemann, hans", "niemann, h.", "niemann, hans moke", "hanontwitch"],
    "Kramnik, Vladimir": ["kramnik, vladimir", "kramnik, v.", "kramnik", "vladimirkramnik", "veteran", "vladimir_kramnik"],
    "Kasparov, Garry": ["kasparov, garry", "kasparov, g.", "kasparov", "kasparov7", "gazza"],
    "Karpov, Anatoly": ["karpov, anatoly", "karpov, a.", "karpov"]
}

SOCIAL_KEYWORDS = [
    "tournament", "championship", "fide", "titled", "masters", "cup", 
    "open", "swiss", "arena", "grand prix", "speed chess", "pro chess", 
    "candidates", "memorial", "invitational", "tour", "cct", "gct", "match"
]

# --- 2. PGN PARSER LOOP ---
all_rows = []

for pgn_path in ALL_PGN_FILES:
    if not os.path.exists(pgn_path):
        print(f"⚠️  Missing: {os.path.basename(pgn_path)}")
        continue
        
    print(f"📖 Reading: {os.path.basename(pgn_path)}")
    with open(pgn_path, "r", encoding="utf-8", errors="replace") as f:
        while True:
            game = chess.pgn.read_game(f)
            if game is None: break
            
            h = game.headers
            w_raw, b_raw = str(h.get("White", "")).lower().strip(), str(h.get("Black", "")).lower().strip()

            w_id, b_id = None, None
            for proper, aliases in identity_map.items():
                clean_aliases = [a.lower().strip() for a in aliases]
                if w_raw in clean_aliases: w_id = proper
                if b_raw in clean_aliases: b_id = proper
            
            if not w_id and not b_id: continue

            # Tagging logic
            event = str(h.get("Event", "Unknown")).lower()
            site = str(h.get("Site", "Unknown")).lower()
            
            # OTB/Tournament = Social (per your request)
            is_social = any(kw in event for kw in SOCIAL_KEYWORDS) or ("relay" in pgn_path.lower())
            env = "Social" if is_social else "Isolated"
            
            # Online Platforms = Blitz
            is_blitz = any(x in event for x in ["blitz", "bullet", "rapid"]) or \
                       any(x in site for x in ["chess.com", "lichess"])
            g_type = "Blitz" if is_blitz else "Classical"

            # Capture the full PGN string for Stockfish
            pgn_content = str(game) 

            for pid in [p for p in [w_id, b_id] if p is not None]:
                all_rows.append({
                    "proper_identity": pid,
                    "environment": env,
                    "game_type": g_type,
                    "white": h.get("White"),
                    "black": h.get("Black"),
                    "event": h.get("Event"),
                    "site": h.get("Site"),
                    "date": h.get("Date"),
                    "pgn_text": pgn_content
                })

# Convert and Deduplicate
master_df = pd.DataFrame(all_rows).drop_duplicates(subset=["proper_identity", "pgn_text"])

# --- 3. STRATIFIED SAMPLING ---
print("🎲 Sampling: Selecting 250 RANDOM games per quadrant...")

def random_cap(group):
    # If the group has fewer than 250 games, take all of them
    # If it has more, pick 250 at random
    n = min(len(group), 250)
    return group.sample(n=n, random_state=42)

# Apply the random sampler to each Identity/Environment/GameType combo
final_sample = (
    master_df.groupby(['proper_identity', 'environment', 'game_type'], group_keys=False)
    .apply(random_cap)
    .reset_index(drop=True)
)

# --- 4. FINAL AUDIT TABLE ---
print("\n--- 📊 FINAL STRATIFIED AUDIT (THE BIG 8) ---")
audit_table = (
    final_sample.groupby(['proper_identity', 'environment', 'game_type'])
    .size()
    .unstack(level='game_type', fill_value=0)
)
print(audit_table)

final_sample.to_csv("Final_Thesis_Sample_Complete.csv", index=False)
print("\n✅ Saved: Final_Thesis_Sample_Complete.csv (Moves Included)")