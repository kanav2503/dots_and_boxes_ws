# D:\Project\dots_and_boxes_ws\packages\game_engine\bin\evaluation\analyze_all.py
from pathlib import Path
import argparse
import sys
import pandas as pd
import numpy as np

def detect_unsafe_cols(games_df: pd.DataFrame):
    """
    Return (p1_col, p2_col) for per-game unsafe move columns.
    """
    if {'p1_unsafe_moves','p2_unsafe_moves'}.issubset(games_df.columns):
        return 'p1_unsafe_moves', 'p2_unsafe_moves'
    if {'p1_unsafe','p2_unsafe'}.issubset(games_df.columns):
        return 'p1_unsafe', 'p2_unsafe'
    raise KeyError(
        "Per-game CSV missing unsafe columns. "
        "Expected p1_unsafe_moves/p2_unsafe_moves or p1_unsafe/p2_unsafe. "
        f"Found: {list(games_df.columns)}"
    )

def wins_unordered(summary: pd.DataFrame) -> pd.DataFrame:
    """
    Combine both orders into an unordered matchup key (A vs B == B vs A).
    For self-play (A vs A), this reduces to the single row.
    Outputs total wins, ties, and win rates for each agent by grid.
    """
    def key(a, b): return tuple(sorted([a, b]))
    rows = []
    for (grid, pair), sdf in summary.assign(pair=lambda r: r.apply(lambda x: key(x['p1_ai'], x['p2_ai']), axis=1)).groupby(['grid','pair']):
        A, B = pair
        # Aggregate both orders
        A_wins = B_wins = ties = games = 0
        for _, r in sdf.iterrows():
            if (r['p1_ai'], r['p2_ai']) == (A, B):
                A_wins += int(r['p1_wins']); B_wins += int(r['p2_wins'])
                ties   += int(r['ties']);    games  += int(r['games'])
            else:  # reversed
                A_wins += int(r['p2_wins']); B_wins += int(r['p1_wins'])
                ties   += int(r['ties']);    games  += int(r['games'])
        rows.append({
            'grid': grid, 'agent_A': A, 'agent_B': B,
            'A_wins': A_wins, 'B_wins': B_wins, 'ties': ties, 'games': games,
            'A_win_rate': A_wins / games if games else np.nan,
            'B_win_rate': B_wins / games if games else np.nan,
            'tie_rate':   ties   / games if games else np.nan,
        })
    out = pd.DataFrame(rows).sort_values(['grid','agent_A','agent_B']).reset_index(drop=True)
    return out

def unsafe_by_agent_games(games: pd.DataFrame) -> pd.DataFrame:
    """
    From per-game CSV, compute unsafe-move averages per agent & grid (combining roles).
    """
    p1u, p2u = detect_unsafe_cols(games)
    # melt-like accumulation
    rec = []
    for _, r in games.iterrows():
        rec.append({'grid': r['grid'], 'agent': r['p1_ai'], 'unsafe': r[p1u]})
        rec.append({'grid': r['grid'], 'agent': r['p2_ai'], 'unsafe': r[p2u]})
    df = pd.DataFrame(rec)
    out = df.groupby(['grid','agent'], as_index=False)['unsafe'].mean().rename(columns={'unsafe':'unsafe_mean_games'})
    return out

def unsafe_by_agent_summary(summary: pd.DataFrame) -> pd.DataFrame:
    """
    From summary CSV, compute unsafe-move averages per agent & grid by combining both orders.
    Uses p1_unsafe_avg / p2_unsafe_avg.
    """
    rows = []
    # group only by grid → one key to unpack
    for grid, sdf in summary.groupby('grid'):
        # all agents that appear on this grid (either role)
        agents = set(sdf['p1_ai']).union(set(sdf['p2_ai']))
        for a in agents:
            # gather unsafe averages where agent appears as p1 or p2
            as_p1 = sdf.loc[sdf['p1_ai'] == a, 'p1_unsafe_avg'].astype(float)
            as_p2 = sdf.loc[sdf['p2_ai'] == a, 'p2_unsafe_avg'].astype(float)
            vals = pd.concat([as_p1, as_p2], ignore_index=True)
            if not vals.empty:
                rows.append({
                    'grid': int(grid),
                    'agent': a,
                    'unsafe_mean_summary': float(vals.mean())
                })
    out = (pd.DataFrame(rows)
             .sort_values(['grid', 'agent'])
             .reset_index(drop=True))
    return out

def game_length_by_grid(games: pd.DataFrame) -> pd.DataFrame:
    """
    Average game length in turns (p1_turns + p2_turns), grouped by grid and pairing (unordered).
    """
    def key(a, b): return tuple(sorted([a, b]))
    games = games.copy()
    games['pair'] = games.apply(lambda r: key(r['p1_ai'], r['p2_ai']), axis=1)
    games['turns_total'] = games['p1_turns'] + games['p2_turns']
    agg = (games.groupby(['grid','pair'], as_index=False)
                .agg(turns_mean=('turns_total','mean'),
                     turns_std=('turns_total','std'),
                     n=('turns_total','size')))
    # split pair back to two columns for readability
    agg[['agent_A','agent_B']] = pd.DataFrame(agg['pair'].tolist(), index=agg.index)
    return agg.drop(columns=['pair']).sort_values(['grid','agent_A','agent_B']).reset_index(drop=True)

def streaks_by_agent(games: pd.DataFrame) -> pd.DataFrame:
    """
    Average longest-scoring streak per agent & grid (combining roles).
    """
    rec = []
    for _, r in games.iterrows():
        rec.append({'grid': r['grid'], 'agent': r['p1_ai'], 'streak': r['p1_longest_streak']})
        rec.append({'grid': r['grid'], 'agent': r['p2_ai'], 'streak': r['p2_longest_streak']})
    df = pd.DataFrame(rec)
    out = df.groupby(['grid','agent'], as_index=False)['streak'].mean().rename(columns={'streak':'longest_streak_mean'})
    return out.sort_values(['grid','agent']).reset_index(drop=True)

def build_winner_col(games: pd.DataFrame) -> pd.DataFrame:
    g = games.copy()
    g['winner'] = np.where(g['p1_score'] > g['p2_score'], 'p1',
                   np.where(g['p2_score'] > g['p1_score'], 'p2', 'tie'))
    return g

def main():
    from pathlib import Path
    default_summary = Path(r"D:\Project\dots_and_boxes_ws\packages\game_engine\bin\benchmark2_summary.csv")
    default_games   = Path(r"D:\Project\dots_and_boxes_ws\packages\game_engine\bin\benchmark2_games.csv")
    default_out     = Path(r"D:\Project\dots_and_boxes_ws\packages\game_engine\bin\evaluation\out")


    ap = argparse.ArgumentParser(description="Analyze Dots & Boxes benchmarks (summary + per-game).")
    ap.add_argument("--summary", type=Path, default=default_summary, help="Path to benchmark2_summary.csv")
    ap.add_argument("--games",   type=Path, default=default_games,   help="Path to benchmark2_games.csv")
    ap.add_argument("--out",     type=Path, default=default_out,     help="Output directory for derived CSVs")
    args = ap.parse_args()

    if not args.summary.exists():
        print(f"ERROR: summary CSV not found at: {args.summary}"); sys.exit(1)
    if not args.games.exists():
        print(f"ERROR: games CSV not found at: {args.games}"); sys.exit(1)
    args.out.mkdir(parents=True, exist_ok=True)

    summary = pd.read_csv(args.summary)
    games   = pd.read_csv(args.games)

    # types & sanity
    for col in ['grid','games','p1_wins','p2_wins','ties']:
        if col in summary.columns:
            summary[col] = summary[col].astype(int)
    for col in ['grid','p1_score','p2_score','p1_turns','p2_turns','p1_longest_streak','p2_longest_streak']:
        if col in games.columns:
            games[col] = games[col].astype(int)

    # add winner column to games
    games = build_winner_col(games)

    # ---------- analyses ----------
    wins_unord = wins_unordered(summary)
    unsafe_g   = unsafe_by_agent_games(games)
    unsafe_s   = unsafe_by_agent_summary(summary)
    turns      = game_length_by_grid(games)
    streaks    = streaks_by_agent(games)

    # merge unsafe summary vs games for quick side-by-side
    unsafe_both = (pd.merge(unsafe_s, unsafe_g, on=['grid','agent'], how='outer')
                     .sort_values(['grid','agent'])
                     .reset_index(drop=True))

    # ---------- write outputs ----------
    wins_unord.to_csv(args.out / "wins_unordered.csv", index=False)
    unsafe_both.to_csv(args.out / "unsafe_by_agent_summary_vs_games.csv", index=False)
    turns.to_csv(args.out / "game_length_by_grid.csv", index=False)
    streaks.to_csv(args.out / "longest_streak_by_agent.csv", index=False)

    print(f"Wrote:\n - {args.out / 'wins_unordered.csv'}"
          f"\n - {args.out / 'unsafe_by_agent_summary_vs_games.csv'}"
          f"\n - {args.out / 'game_length_by_grid.csv'}"
          f"\n - {args.out / 'longest_streak_by_agent.csv'}")

if __name__ == "__main__":
    main()
