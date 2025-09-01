# # evaluation/validate_inputs.py
# import pandas as pd
# import numpy as np
# import sys

# SUM = r"D:\Project\dots_and_boxes_ws\packages\game_engine\bin\benchmark2_summary.csv"
# GMS = r"D:\Project\dots_and_boxes_ws\packages\game_engine\bin\benchmark2_games.csv"

# def matchup_key(a, b):
#     return tuple(sorted([a, b]))

# def main():
#     summary = pd.read_csv(SUM)
#     games   = pd.read_csv(GMS)

#     # normalize types/columns
#     summary['grid'] = summary['grid'].astype(int)
#     games['grid']   = games['grid'].astype(int)

#     # ----- 1) Wins/ties must match when aggregating both orders -----
#     summary['pair'] = summary.apply(lambda r: matchup_key(r['p1_ai'], r['p2_ai']), axis=1)
#     # per-game: determine winner per row
#     games['winner'] = np.where(games['p1_score'] > games['p2_score'], 'p1',
#                         np.where(games['p2_score'] > games['p1_score'], 'p2', 'tie'))
#     games['pair'] = games.apply(lambda r: matchup_key(r['p1_ai'], r['p2_ai']), axis=1)

#     errs = []

#     for (grid, pair), sdf in summary.groupby(['grid','pair']):
#         # aggregate unordered wins/ties from summary
#         A,B = pair
#         A_wins = B_wins = ties = games_count = 0
#         for _, r in sdf.iterrows():
#             if (r['p1_ai'], r['p2_ai']) == (A, B):
#                 A_wins += int(r['p1_wins']); B_wins += int(r['p2_wins']); ties += int(r['ties']); games_count += int(r['games'])
#             else:
#                 # reversed order
#                 A_wins += int(r['p2_wins']); B_wins += int(r['p1_wins']); ties += int(r['ties']); games_count += int(r['games'])

#         # from per-game: winners for unordered pair
#         gdf = games[(games['grid']==grid) & (games['pair']==pair)]
#         # Count A wins: p1 wins when p1==A + p2 wins when p2==A
#         wins_A_games = ((gdf['winner']=='p1') & (gdf['p1_ai']==A)).sum() + ((gdf['winner']=='p2') & (gdf['p2_ai']==A)).sum()
#         wins_B_games = ((gdf['winner']=='p1') & (gdf['p1_ai']==B)).sum() + ((gdf['winner']=='p2') & (gdf['p2_ai']==B)).sum()
#         ties_games   = (gdf['winner']=='tie').sum()
#         n_games      = len(gdf)

#         if not (A_wins==wins_A_games and B_wins==wins_B_games and ties==ties_games and games_count==n_games):
#             errs.append(f"[grid={grid}, pair={A} vs {B}] "
#                         f"summary A/B/ties/games=({A_wins},{B_wins},{ties},{games_count}) "
#                         f"!= games A/B/ties/games=({wins_A_games},{wins_B_games},{ties_games},{n_games})")

#     # ----- 2) Unsafe averages: recompute from per-game and compare to summary averages -----
#     # summary rows provide p1_unsafe_avg & p2_unsafe_avg for each role; we compare against per-game means
#     tol = 1e-6  # floating tolerance
#     for _, r in summary.iterrows():
#         grid = int(r['grid'])
#         p1 = r['p1_ai']; p2 = r['p2_ai']
#         gdf = games[(games['grid']==grid) & (games['p1_ai']==p1) & (games['p2_ai']==p2)]
#         # role-aligned means
#         p1_mean = gdf['p1_unsafe'].mean()
#         p2_mean = gdf['p2_unsafe'].mean()
#         if not (np.isfinite(p1_mean) and np.isfinite(p2_mean)):
#             errs.append(f"[grid={grid}, {p1} vs {p2}] missing per-game unsafe data")
#         else:
#             if abs(p1_mean - float(r['p1_unsafe_avg'])) > 1e-3:
#                 errs.append(f"[grid={grid}, {p1} vs {p2}] p1_unsafe_avg mismatch: games={p1_mean:.3f}, summary={r['p1_unsafe_avg']:.3f}")
#             if abs(p2_mean - float(r['p2_unsafe_avg'])) > 1e-3:
#                 errs.append(f"[grid={grid}, {p1} vs {p2}] p2_unsafe_avg mismatch: games={p2_mean:.3f}, summary={r['p2_unsafe_avg']:.3f}")

#     if errs:
#         print("VALIDATION FAILURES:")
#         for e in errs:
#             print(" -", e)
#         sys.exit(1)
#     else:
#         print("All summary↔games cross-checks PASSED.")

# if __name__ == "__main__":
#     main()


# D:\Project\dots_and_boxes_ws\packages\game_engine\bin\evaluation\validate_inputs.py
import pandas as pd
import numpy as np
from pathlib import Path
import argparse
import sys

def main():
    default_summary = r"D:\Project\dots_and_boxes_ws\packages\game_engine\bin\benchmark2_summary.csv"
    default_games   = r"D:\Project\dots_and_boxes_ws\packages\game_engine\bin\benchmark2_games.csv"

    ap = argparse.ArgumentParser(description="Cross-check summary vs per-game CSVs (order-preserving)")
    ap.add_argument("--summary", type=Path, default=default_summary,
                    help="Path to benchmark2_summary.csv")
    ap.add_argument("--games", type=Path, default=default_games,
                    help="Path to benchmark2_games.csv")
    args = ap.parse_args()

    if not args.summary.exists():
        print(f"ERROR: summary CSV not found at: {args.summary}"); sys.exit(1)
    if not args.games.exists():
        print(f"ERROR: games CSV not found at: {args.games}"); sys.exit(1)

    summary = pd.read_csv(args.summary)
    games   = pd.read_csv(args.games)

    summary['grid'] = summary['grid'].astype(int)
    games['grid']   = games['grid'].astype(int)

    # detect per-game unsafe column names
    if {'p1_unsafe_moves','p2_unsafe_moves'}.issubset(games.columns):
        G_UNSAFE_P1, G_UNSAFE_P2 = 'p1_unsafe_moves', 'p2_unsafe_moves'
    elif {'p1_unsafe','p2_unsafe'}.issubset(games.columns):
        G_UNSAFE_P1, G_UNSAFE_P2 = 'p1_unsafe', 'p2_unsafe'
    else:
        print("ERROR: per-game CSV missing unsafe columns "
              "(need p1_unsafe_moves/p2_unsafe_moves or p1_unsafe/p2_unsafe).")
        print("Columns present:", list(games.columns)); sys.exit(1)

    # per-game winners (order-preserving)
    games['winner'] = np.where(games['p1_score'] > games['p2_score'], 'p1',
                        np.where(games['p2_score'] > games['p1_score'], 'p2', 'tie'))

    errs = []

    # ---- 1) Validate wins/ties/games per *ordered* summary row ----
    for _, r in summary.iterrows():
        grid = int(r['grid'])
        p1, p2 = r['p1_ai'], r['p2_ai']
        gdf = games[(games['grid']==grid) & (games['p1_ai']==p1) & (games['p2_ai']==p2)]
        if gdf.empty:
            errs.append(f"[grid={grid}, {p1} vs {p2}] no per-game rows found")
            continue

        p1_wins_g = (gdf['winner']=='p1').sum()
        p2_wins_g = (gdf['winner']=='p2').sum()
        ties_g    = (gdf['winner']=='tie').sum()
        n_g       = len(gdf)

        if (p1_wins_g != int(r['p1_wins']) or
            p2_wins_g != int(r['p2_wins']) or
            ties_g    != int(r['ties'])     or
            n_g       != int(r['games'])):
            errs.append(
                f"[grid={grid}, {p1} vs {p2}] "
                f"summary p1/p2/ties/games=({r['p1_wins']},{r['p2_wins']},{r['ties']},{r['games']}) "
                f"!= per-game ({p1_wins_g},{p2_wins_g},{ties_g},{n_g})"
            )

    # ---- 2) Role-aligned unsafe averages per ordered row ----
    tol = 1e-3
    for _, r in summary.iterrows():
        grid = int(r['grid']); p1, p2 = r['p1_ai'], r['p2_ai']
        gdf = games[(games['grid']==grid) & (games['p1_ai']==p1) & (games['p2_ai']==p2)]
        if gdf.empty:  # already reported above
            continue
        p1_mean = gdf[G_UNSAFE_P1].mean()
        p2_mean = gdf[G_UNSAFE_P2].mean()
        if abs(p1_mean - float(r['p1_unsafe_avg'])) > tol:
            errs.append(f"[grid={grid}, {p1} vs {p2}] p1_unsafe_avg mismatch: "
                        f"games={p1_mean:.3f}, summary={float(r['p1_unsafe_avg']):.3f}")
        if abs(p2_mean - float(r['p2_unsafe_avg'])) > tol:
            errs.append(f"[grid={grid}, {p1} vs {p2}] p2_unsafe_avg mismatch: "
                        f"games={p2_mean:.3f}, summary={float(r['p2_unsafe_avg']):.3f}")

    if errs:
        print("VALIDATION FAILURES:")
        for e in errs: print(" -", e)
        sys.exit(1)

    print("All summary↔games (order-preserving) cross-checks PASSED.")

if __name__ == "__main__":
    main()
