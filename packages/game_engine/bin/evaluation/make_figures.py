#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path
import argparse

# ---------- helpers ----------

def p1_winrate_from_games(games: pd.DataFrame) -> pd.DataFrame:
    """Compute P1 win rate (%) from per-game csv (robust against summary mismatches)."""
    df = games.copy()
    df["p1_win"] = (df["p1_score"] > df["p2_score"]).astype(int)
    winrates = (
        df.groupby(["grid", "p1_ai", "p2_ai"])["p1_win"]
          .mean()
          .mul(100.0)
          .reset_index(name="p1_winrate_pct")
    )
    return winrates

def collect_agent_series(df_games: pd.DataFrame, grid: int, col_p1: str, col_p2: str):
    """Return a dict[agent] -> 1D values combined from p1 and p2 columns for a given grid."""
    g = df_games[df_games["grid"] == grid]
    agents = sorted(set(g["p1_ai"]) | set(g["p2_ai"]))
    out = {}
    for a in agents:
        s1 = g.loc[g["p1_ai"] == a, col_p1]
        s2 = g.loc[g["p2_ai"] == a, col_p2]
        out[a] = pd.concat([s1, s2], ignore_index=True)
    return out

def ensure_out(out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    return out_dir

# ---------- plots ----------

def plot_winrate_heatmap(winrates: pd.DataFrame, grid: int, out_dir: Path):
    W = winrates[winrates["grid"] == grid]
    rows = sorted(W["p1_ai"].unique().tolist())
    cols = sorted(W["p2_ai"].unique().tolist())
    mat = np.full((len(rows), len(cols)), np.nan)
    for i, ra in enumerate(rows):
        for j, cb in enumerate(cols):
            m = W[(W["p1_ai"] == ra) & (W["p2_ai"] == cb)]
            if len(m):
                mat[i, j] = float(m["p1_winrate_pct"].iloc[0])

    fig, ax = plt.subplots(figsize=(8, 6), dpi=300)
    im = ax.imshow(mat, cmap="viridis", vmin=0, vmax=100, aspect="auto")
    ax.set_xticks(range(len(cols)), labels=cols, rotation=45, ha="right")
    ax.set_yticks(range(len(rows)), labels=rows)
    ax.set_title(f"Win-rate heatmap (P1 wins %) — {grid}×{grid}")

    # annotate cells
    for i in range(len(rows)):
        for j in range(len(cols)):
            if not np.isnan(mat[i, j]):
                ax.text(j, i, f"{mat[i,j]:.0f}%", ha="center", va="center", color="white", fontsize=9)

    cbar = fig.colorbar(im, ax=ax)
    cbar.set_label("P1 win rate (%)")
    fig.tight_layout()
    fig.savefig(out_dir / f"winrate_heatmap_{grid}x{grid}.png")
    plt.close(fig)

def plot_slope_selected_pairs(winrates: pd.DataFrame, out_dir: Path):
    """Show P1 win rate across grids for selected pairs to illustrate scaling."""
    pairs = [
        ("Deep2", "Random"),
        ("Deep2", "Heuristic1"),
        ("Heuristic1", "Random"),
    ]
    grids = sorted(winrates["grid"].unique().tolist())
    fig, ax = plt.subplots(figsize=(8, 5), dpi=300)
    for a, b in pairs:
        ys = []
        for g in grids:
            row = winrates[(winrates["grid"] == g) & (winrates["p1_ai"] == a) & (winrates["p2_ai"] == b)]
            ys.append(float(row["p1_winrate_pct"].iloc[0]) if len(row) else np.nan)
        ax.plot(grids, ys, marker="o", label=f"{a} vs {b}")
    ax.set_xticks(grids, labels=[f"{g}×{g}" for g in grids])
    ax.set_ylabel("P1 win rate (%)")
    ax.set_title("Head-to-head P1 win rate across grid sizes")
    ax.legend(frameon=False)
    fig.tight_layout()
    fig.savefig(out_dir / "slope_winrates_selected_pairs.png")
    plt.close(fig)

def plot_unsafe_boxplot_at_6(games: pd.DataFrame, out_dir: Path):
    grid = 6
    data = collect_agent_series(games, grid, "p1_unsafe_moves", "p2_unsafe_moves")
    agents = sorted(data.keys())
    series = [data[a].dropna().values for a in agents]

    fig, ax = plt.subplots(figsize=(8, 5), dpi=300)
    bp = ax.boxplot(series, labels=agents, showmeans=True, meanline=False)
    ax.set_ylabel("Unsafe moves per game")
    ax.set_title("Unsafe moves by agent — distribution (6×6)")
    plt.xticks(rotation=0)
    fig.tight_layout()
    fig.savefig(out_dir / "unsafe_boxplot_6x6.png")
    plt.close(fig)

def plot_streak_errorbars(games: pd.DataFrame, out_dir: Path):
    grids = sorted(games["grid"].unique().tolist())
    agents = sorted(set(games["p1_ai"]) | set(games["p2_ai"]))
    means = {a: [] for a in agents}
    stds  = {a: [] for a in agents}

    for g in grids:
        data = collect_agent_series(games, g, "p1_longest_streak", "p2_longest_streak")
        for a in agents:
            v = data[a].dropna().astype(float)
            means[a].append(v.mean())
            stds[a].append(v.std())

    fig, ax = plt.subplots(figsize=(8, 5), dpi=300)
    for a in agents:
        ax.errorbar(grids, means[a], yerr=stds[a], marker="o", capsize=3, label=a)
    ax.set_xticks(grids, labels=[f"{g}×{g}" for g in grids])
    ax.set_ylabel("Longest scoring streak (mean ± SD)")
    ax.set_title("Longest scoring streak by agent across grids")
    ax.legend(frameon=False)
    fig.tight_layout()
    fig.savefig(out_dir / "streak_errorbars.png")
    plt.close(fig)

def plot_hbar_unsafe_matchups_6(games: pd.DataFrame, out_dir: Path):
    g = games[games["grid"] == 6].copy()
    g["avg_unsafe_both"] = (g["p1_unsafe_moves"] + g["p2_unsafe_moves"]) / 2.0
    m = g.groupby(["p1_ai", "p2_ai"])["avg_unsafe_both"].mean().reset_index()
    m["label"] = m["p1_ai"] + " vs " + m["p2_ai"]
    m = m.sort_values("avg_unsafe_both", ascending=True)

    fig, ax = plt.subplots(figsize=(9, 8), dpi=300)
    ax.barh(m["label"], m["avg_unsafe_both"])
    ax.set_xlabel("Average unsafe moves per game (both players)")
    ax.set_title("Average unsafe moves per matchup — 6×6 (sorted)")
    plt.tight_layout()
    fig.savefig(out_dir / "hbar_unsafe_matchups_6x6.png")
    plt.close(fig)

# ---------- main ----------

def main():
    DEFAULT_SUMMARY = Path(r"D:\Project\dots_and_boxes_ws\packages\game_engine\bin\benchmark2_summary.csv")
    DEFAULT_GAMES   = Path(r"D:\Project\dots_and_boxes_ws\packages\game_engine\bin\benchmark2_games.csv")
    
    ap = argparse.ArgumentParser(description="Generate evaluation figures from summary & games CSVs.")
    ap.add_argument("--summary", type=str, default=str(DEFAULT_SUMMARY), help="Path to benchmark2_summary.csv")
    ap.add_argument("--games",   type=str, default=str(DEFAULT_GAMES),   help="Path to benchmark2_games.csv")
    ap.add_argument("--out",     type=str, default=None,                 help="Output folder for PNGs")
    args = ap.parse_args()

    
    sum_path  = Path(args.summary)
    games_path = Path(args.games)

    if args.out:
        out_dir = ensure_out(Path(args.out))
    else:
        out_dir = ensure_out(games_path.parent / "figs_eval2")

    # Load CSVs
    summary = pd.read_csv(sum_path)
    games   = pd.read_csv(games_path)

    # Basic column checks (fail fast with clear errors)
    req_games = {
        "grid","p1_ai","p2_ai","p1_score","p2_score",
        "p1_unsafe_moves","p2_unsafe_moves",
        "p1_longest_streak","p2_longest_streak"
    }
    missing_g = req_games - set(games.columns)
    if missing_g:
        raise ValueError(f"games CSV missing columns: {sorted(missing_g)}")

    # Compute winrates from per-game data to avoid any mismatches
    winrates = p1_winrate_from_games(games)

    # 1) Heatmaps per grid
    for g in sorted(winrates["grid"].unique()):
        plot_winrate_heatmap(winrates, g, out_dir)

    # 2) Slope chart across grids for selected pairs
    plot_slope_selected_pairs(winrates, out_dir)

    # 3) Distribution of unsafe moves at 6×6
    if 6 in games["grid"].unique():
        plot_unsafe_boxplot_at_6(games, out_dir)
        plot_hbar_unsafe_matchups_6(games, out_dir)

    # 4) Longest scoring streak — mean ± SD across grids
    plot_streak_errorbars(games, out_dir)

    print(f"Saved figures to: {out_dir.resolve()}")

if __name__ == "__main__":
    main()
