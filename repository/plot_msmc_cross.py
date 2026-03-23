#!/usr/bin/env python3
"""
Plot MSMC Cross-Population Coalescence Rates
=============================================
Usage: python3 plot_msmc_cross.py

Output: visualization/Cross_coalescence.png
"""

import os
import glob
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# =====================================
# Configuration - 修改这里来调整分析
# =====================================
# MSMC输出目录
# MSMC output directory - Set via config or use default
MSMC_OUTPUT_DIR = os.environ.get('MSMC_OUTPUT_DIR', './msmc_output')

# 可视化输出目录
# Visualization output directory
VISUALIZATION_DIR = os.environ.get('VISUALIZATION_DIR', './visualization')

# 突变率和世代时间
MU = 1.25e-8   # 每代每碱基突变率
GEN = 30         # 世代时间(年)

# 要绘制的群体配对 (与MSMC输出文件名匹配)
# 文件名格式: cross_{pop1}_{pop2}.combined.txt
CROSS_PAIRS = [
    ("Jino", "Tibetan"),
    ("Jino", "Han"),
    ("Tibetan", "Han"),
    ("Jino", "Mosuo"),
]

# 颜色映射
COLORS = {
    "Jino-Tibetan": "#E41A1C",
    "Jino-Han": "#377EB8",
    "Tibetan-Han": "#4DAF4A",
    "Jino-Mosuo": "#984EA3",
    "Jino-Dai": "#FF7F00",
    "Mosuo-Tibetan": "#FFFF33",
}

# =====================================
# Functions
# =====================================

def load_cross_data(pop1, pop2, output_dir):
    """Load cross-population MSMC result file"""
    
    # 尝试多种可能的文件名
    possible_names = [
        f"cross_{pop1}_{pop2}.combined.txt",
        f"cross_{pop1}_{pop2}.final.txt",
        f"cross_{pop2}_{pop1}.combined.txt",
        f"cross_{pop2}_{pop1}.final.txt",
    ]
    
    filepath = None
    for name in possible_names:
        path = os.path.join(output_dir, name)
        if os.path.exists(path):
            filepath = path
            break
    
    if filepath is None:
        print(f"Warning: File not found for {pop1} vs {pop2}")
        return None
    
    df = pd.read_csv(filepath, delim_whitespace=True)
    return df

def convert_time(df, mu=MU, gen=GEN):
    """Convert scaled time to years ago"""
    df["time_years"] = df["left_time_boundary"] / mu * gen
    return df

def calculate_relative_ccr(df):
    """
    Calculate relative cross-coalescence rate
    CCR = 2 * lambda_01 / (lambda_00 + lambda_11)
    """
    df["relative_ccr"] = 2 * df["lambda_01"] / (df["lambda_00"] + df["lambda_11"])
    return df

def plot_cross_coalescence(pairs, output_dir, vis_dir, colors=COLORS):
    """Plot cross-population coalescence rates"""
    
    plt.figure(figsize=(12, 8))
    
    for pop1, pop2 in pairs:
        df = load_cross_data(pop1, pop2, output_dir)
        
        if df is None:
            print(f"Skipping {pop1} vs {pop2}")
            continue
        
        df = convert_time(df)
        df = calculate_relative_ccr(df)
        
        key = f"{pop1}-{pop2}"
        color = colors.get(key, "#333333")
        
        plt.step(df["time_years"], df["relative_ccr"], 
                 where='post', label=f"{pop1} vs {pop2}", 
                 color=color, linewidth=2)
    
    plt.xlabel('Years Ago', fontsize=12)
    plt.ylabel('Relative Cross-Coalescence Rate', fontsize=12)
    plt.title('Population Separation History', fontsize=14)
    
    plt.gca().set_xscale('log')
    plt.axhline(y=0.5, color='black', linestyle='--', alpha=0.5, label='50% separation')
    plt.axhline(y=1.0, color='gray', linestyle=':', alpha=0.5, label='Full mixing')
    
    plt.xlim(1000, 1000000)
    plt.ylim(0, 1.1)
    
    plt.legend(loc='upper right', fontsize=10)
    plt.grid(True, alpha=0.3)
    
    os.makedirs(vis_dir, exist_ok=True)
    output_file = os.path.join(vis_dir, "Cross_coalescence.png")
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.savefig(output_file.replace(".png", ".pdf"), bbox_inches='tight')
    
    print(f"Saved: {output_file}")
    plt.close()

def plot_split_time_bar(pairs, output_dir, vis_dir):
    """Plot bar chart of estimated split times"""
    
    split_times = []
    pair_labels = []
    
    for pop1, pop2 in pairs:
        df = load_cross_data(pop1, pop2, output_dir)
        
        if df is None:
            continue
        
        df = convert_time(df)
        df = calculate_relative_ccr(df)
        
        # 找到CCR=0.5的时间点作为分离时间估计
        idx = (df["relative_ccr"] - 0.5).abs().idxmin()
        split_time = df.loc[idx, "time_years"]
        
        split_times.append(split_time)
        pair_labels.append(f"{pop1}\nvs\n{pop2}")
    
    if not split_times:
        print("No data for split time plot")
        return
    
    # 绘制条形图
    plt.figure(figsize=(10, 6))
    
    y_pos = np.arange(len(pair_labels))
    plt.barh(y_pos, split_times, color='steelblue')
    plt.yticks(y_pos, pair_labels)
    
    plt.xlabel('Estimated Split Time (years ago)', fontsize=12)
    plt.ylabel('Population Pair', fontsize=12)
    plt.title('Population Split Time Estimates', fontsize=14)
    
    # 添加数值标签
    for i, v in enumerate(split_times):
        plt.text(v + 500, i, f'{v:.0f}', va='center', fontsize=9)
    
    plt.tight_layout()
    
    os.makedirs(vis_dir, exist_ok=True)
    output_file = os.path.join(vis_dir, "Split_time.png")
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.savefig(output_file.replace(".png", ".pdf"), bbox_inches='tight')
    
    print(f"Saved: {output_file}")
    plt.close()

# =====================================
# Main
# =====================================

if __name__ == "__main__":
    print("=" * 50)
    print("MSMC Cross-Population Visualization")
    print("=" * 50)
    print(f"Population pairs: {CROSS_PAIRS}")
    print(f"Output dir: {VISUALIZATION_DIR}")
    print()
    
    # 绘制跨群体coalescence率
    plot_cross_coalescence(CROSS_PAIRS, MSMC_OUTPUT_DIR, VISUALIZATION_DIR)
    
    # 绘制分离时间
    plot_split_time_bar(CROSS_PAIRS, MSMC_OUTPUT_DIR, VISUALIZATION_DIR)
    
    print("\nDone!")
