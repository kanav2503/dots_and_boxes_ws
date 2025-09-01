#!/usr/bin/env python3
"""
Compute ordered win rates p_{A->B} and p_{B->A}, then derive
order-invariant strength s(A,B) and first-move bias Δ(A,B)
from a per-game CSV produced by your benchmark runner.

Usage:
  python compute_order_summary.py \
      --csv /path/to/benchmark_games.csv \
      --out /path/to/order_summary.tex \
      --tie exclude   # or: half

Assumptions (case-insensitive column matching):
  - grid size: one of ["grid","board","grid_size"]  (values like 4, "4x4", etc.)
  - agents:    P1 in ["p1_agent","agent_p1","p1"], P2 in ["p2_agent","agent_p2","p2"]
  - scores:    P1 in ["p1_score","score_p1"],      P2 in ["p2_score","score_p2"]

Ties handling:
  - exclude : ignore ties for win-rate denominator (binomial-friendly; Wilson CI shown)
  - half    : count tie as 0.5 win (no CI shown to avoid false precision)
"""

import argparse
import pandas as pd
import numpy as np

def _find_col(df, candidates):
    cols = {c.lower(): c for c in df.columns}
    for cand in candidates:
        if cand.lower() in cols:
            return cols[cand.lower()]
    raise KeyError(f"Required column not found. Tried {candidates} in {list(df.columns)}")

def wilson_ci(k, n, z=1.96):
    """Wilson 95% CI (default z≈1.96). Returns (lo, hi)."""
    if n == 0:
        return (np.nan, np.nan)
    phat = k / n
    denom = 1 + (z*z)/n
    center = (phat + (z*z)/(2*n)) / denom
    half = z * np.sqrt((phat*(1-phat) + (z*z)/(4*n)) / n) / denom
    return (max(0.0, center - half), min(1.0, center + half))

def format_pct(p):
    if pd.isna(p):
        return "--"
    return f"{100*p:.1f}\\%"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", required=True, help="per-game CSV path")
    ap.add_argument("--out", default="order_summary.tex", help="LaTeX output path")
    ap.add_argument("--tie", choices=["exclude","half"], default="exclude",
                    help="tie handling in P1 win rate")
    args = ap.parse_args()

    df = pd.read_csv(args.csv)

    grid_col = _find_col(df, ["grid","board","grid_size"])
    p1a_col  = _find_col(df, ["p1_agent","agent_p1","p1","p1_ai"])
    p2a_col  = _find_col(df, ["p2_agent","agent_p2","p2","p2_ai"])
    s1_col   = _find_col(df, ["p1_score","score_p1"])
    s2_col   = _find_col(df, ["p2_score","score_p2"])

    df = df.copy()

    # Normalise grid to strings like "4x4"
    def norm_grid(v):
        try:
            if isinstance(v, str) and "x" in v.lower():
                return v
            n = int(v)
            return f"{n}x{n}"
        except Exception:
            return str(v)

    df["GRID"] = df[grid_col].apply(norm_grid)
    df["P1A"]  = df[p1a_col].astype(str)
    df["P2A"]  = df[p2a_col].astype(str)
    df["P1S"]  = df[s1_col].astype(int)
    df["P2S"]  = df[s2_col].astype(int)

    agents = sorted(set(df["P1A"]).union(set(df["P2A"])))
    grids  = sorted(df["GRID"].unique())

    def p1_winrate(sub):
        """Return (p, (lo,hi), n_used)."""
        if len(sub) == 0:
            return (np.nan, (np.nan, np.nan), 0)
        p1_wins = (sub["P1S"] > sub["P2S"]).sum()
        ties    = (sub["P1S"] == sub["P2S"]).sum()
        losses  = (sub["P1S"] < sub["P2S"]).sum()
        if args.tie == "exclude":
            n = p1_wins + losses
            if n == 0:
                return (np.nan, (np.nan, np.nan), len(sub))
            p = p1_wins / n
            lo, hi = wilson_ci(p1_wins, n)
            return (p, (lo, hi), len(sub))
        else:
            # ties counted as 0.5; no CI to avoid false precision
            n = len(sub)
            p = (p1_wins + 0.5*ties) / n
            return (p, (np.nan, np.nan), len(sub))

    rows = []
    for g in grids:
        dfg = df[df["GRID"] == g]
        for A in agents:
            for B in agents:
                if A == B:
                    continue
                # A as P1 vs B
                sub1 = dfg[(dfg["P1A"] == A) & (dfg["P2A"] == B)]
                p_AB, ci_AB, n1 = p1_winrate(sub1)
                # B as P1 vs A
                sub2 = dfg[(dfg["P1A"] == B) & (dfg["P2A"] == A)]
                p_BA, ci_BA, n2 = p1_winrate(sub2)

                if np.isnan(p_AB) or np.isnan(p_BA):
                    s = np.nan
                    delta = np.nan
                else:
                    s = 0.5 * (p_AB + (1 - p_BA))
                    delta = p_AB - (1 - p_BA)

                rows.append({
                    "Grid": g,
                    "Matchup": f"{A} vs {B}",
                    "p_A_to_B": p_AB,
                    "p_A_to_B_CI": ci_AB,
                    "n_AB": n1,
                    "p_B_to_A": p_BA,
                    "p_B_to_A_CI": ci_BA,
                    "n_BA": n2,
                    "s(A,B)": s,
                    "Delta": delta
                })

    out_df = pd.DataFrame(rows)

    def fmt_ci(ci):
        lo, hi = ci
        if np.isnan(lo) or np.isnan(hi):
            return "--"
        return f"[{100*lo:.1f}\\%, {100*hi:.1f}\\%]"

    tables = []
    for g in grids:
        sub = out_df[out_df["Grid"] == g].copy()
        if sub.empty:
            continue
        sub["p_AB"] = sub["p_A_to_B"].apply(format_pct)
        sub["CI_AB"] = sub["p_A_to_B_CI"].apply(fmt_ci)
        sub["p_BA"] = sub["p_B_to_A"].apply(format_pct)
        sub["CI_BA"] = sub["p_B_to_A_CI"].apply(fmt_ci)
        sub["s_fmt"] = sub["s(A,B)"].apply(format_pct)
        sub["d_fmt"] = sub["Delta"].apply(lambda x: "--" if pd.isna(x) else f"{100*x:+.1f}\\%")

        cols = ["Matchup","p_AB","CI_AB","p_BA","CI_BA","s_fmt","d_fmt"]
        sub = sub[cols].rename(columns={
            "Matchup":"Matchup (A vs B)",
            "p_AB":"$p_{A\\to B}$",
            "CI_AB":"95\\% CI",
            "p_BA":"$p_{B\\to A}$",
            "CI_BA":"95\\% CI",
            "s_fmt":"$s(A,B)$",
            "d_fmt":"$\\Delta(A,B)$"
        })

        latex = sub.to_latex(
            index=False, escape=False, column_format="lcccccc",
            caption=f"Order-invariant strength $s(A,B)$ and first-move bias $\\Delta(A,B)$ on {g}.",
            label=f"tab:order_summary_{g.replace('x','x')}"
        )
        tables.append(latex)

    final_tex = "\n\n".join(tables) if tables else "% No data rows matched."
    with open(args.out, "w") as f:
        f.write(final_tex)

    csv_out = args.out.replace(".tex", "_metrics.csv")
    out_df.to_csv(csv_out, index=False)
    print("Wrote:", args.out)
    print("Also wrote:", csv_out)

if __name__ == "__main__":
    main()
