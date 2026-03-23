#!/usr/bin/env python3
"""
Plot MSMC Effective Population Size (Ne) Curves
================================================
Usage: python3 plot_msmc_ne.py

Output: visualization/Ne_curves.png
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

# 要绑定的群体/组合 (与MSMC输出文件名匹配)
# 可以是单个群体(如"Jino")或组合(如"JTH", "MTH")
POPULATIONS = [
    "JTH",      # Jino + Tibetan + Han
    "MTH",      # Mosuo + Tibetan + Han
    "QTH",      # Qiang + Tibetan + Han
    "BTH",      # Blang + Tibetan + Han
]

# 颜色映射
COLORS = {
    "JTH": "#E41A1C",      # Red
    "MTH": "#377EB8",      # Blue
    "QTH": "#4DAF4A",      # Green
    "BTH": "#984EA3",      # Purple
    "Jino": "#FF7F00",     # Orange
    "Tibetan": "#FFFF33",  # Yellow
    "Han": "#A65628",      # Brown
    "Mosuo": "#F781BF",    # Pink
    "Dai": "#999999",      # Gray
    "Hani": "#66C2A5",    # Teal
}

# =====================================
# Functions
# =====================================

def load_msmc_data(prefix, output_dir):
    """Load MSMC final result file"""
    filepath = os.path.join(output_dir, f"{prefix}.final.txt")
    
    if not os.path.exists(filepath):
        # 尝试其他扩展名
        for ext in [".msmc2.final.txt", ".msmc2"]:
            filepath = os.path.join(output_dir, f"{prefix}{ext}")
            if os.path.exists(filepath):
                break
    
    if not os.path.exists(filepath):
        print(f"Warning: File not found: {prefix}")
        return None
    
    df = pd.read_csv(filepath, delim_whitespace=True)
    return df

def convert_time(df, mu=MU, gen=GEN):
    """Convert scaled time to years ago"""
    df["time_years"] = df["left_time_boundary"] / mu * gen
    return df

def calculate_ne(df, mu=MU, gen=GEN):
    """Calculate effective population size: Ne = lambda^(-1) / (2*mu)"""
    df["Ne"] = (1 / df["lambda"]) / (2 * mu)
    return df

def plot_ne_curves(populations, output_dir, vis_dir, colors=COLORS):
    """Plot Ne curves for multiple populations"""
    
    plt.figure(figsize=(12, 8))
    
    for pop in populations:
        df = load_msmc_data(pop, output_dir)
        
        if df is None:
            print(f"Skipping {pop} - file not found")
            continue
        
        df = convert_time(df)
        df = calculate_ne(df)
        
        color = colors.get(pop, "#333333")
        
        # 使用step plot
        plt.step(df["time_years"], df["Ne"], 
                 where='post', label=pop, color=color, linewidth=2)
    
    plt.xlabel('Years Ago', fontsize=12)
    plt.ylabel('Effective Population Size (Ne)', fontsize=12)
    plt.title('Effective Population Size History', fontsize=14)
    
    plt.gca().set_xscale('log')
    plt.gca().set_yscale('log')
    
    plt.xlim(1000, 1000000)
    plt.ylim(1000, 100000)
    
    plt.legend(loc='upper left', fontsize=10)
    plt.grid(True, alpha=0.3)
    
    # 保存图片
    os.makedirs(vis_dir, exist_ok=True)
    output_file = os.path.join(vis_dir, "Ne_curves.png")
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.savefig(output_file.replace(".png", ".pdf"), bbox_inches='tight')
    
    print(f"Saved: {output_file}")
    plt.close()

def plot_ne_ratio(populations, reference_pop, output_dir, vis_dir, colors=COLORS):
    """Plot Ne ratio relative to a reference population"""
    
    # 加载参考群体
    ref_df = load_msmc_data(reference_pop, output_dir)
    if ref_df is None:
        print(f"Reference population {reference_pop} not found")
        return
    
    ref_df = convert_time(ref_df)
    ref_df = calculate_ne(ref_df)
    
    plt.figure(figsize=(12, 8))
    
    for pop in populations:
        if pop == reference_pop:
            continue
            
        df = load_msmc_data(pop, output_dir)
        
        if df is None:
            continue
        
        df = convert_time(df)
        df = calculate_ne(df)
        
        # 插值到参考群体的时间点
        ref_times = ref_df["time_years"].values
        ref_ne = ref_df["Ne"].values
        
        pop_ne_interp = np.interp(ref_times, df["time_years"].values, df["Ne"].values)
        
        ratio = pop_ne_interp / ref_ne
        
        color = colors.get(pop, "#333333")
        plt.step(ref_times, ratio, where='post', label=f"{pop}/{reference_pop}", 
                 color=color, linewidth=2)
    
    plt.xlabel('Years Ago', fontsize=12)
    plt.ylabel('Ne Ratio', fontsize=12)
    plt.title(f'Effective Population Size Ratio (relative to {reference_pop})', fontsize=14)
    
    plt.gca().set_xscale('log')
    plt.axhline(y=1, color='black', linestyle='--', alpha=0.5)
    
    plt.legend(loc='upper left', fontsize=10)
    plt.grid(True, alpha=0.3)
    
    output_file = os.path.join(vis_dir, "Ne_ratio.png")
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.savefig(output_file.replace(".png", ".pdf"), bbox_inches='tight')
    
    print(f"Saved: {output_file}")
    plt.close()

# =====================================
# Main
# =====================================

if __name__ == "__main__":
    print("=" * 50)
    print("MSMC Ne Curves Visualization")
    print("=" * 50)
    print(f"Populations: {POPULATIONS}")
    print(f"Output dir: {VISUALIZATION_DIR}")
    print()
    
    # 绘制Ne曲线
    plot_ne_curves(POPULATIONS, MSMC_OUTPUT_DIR, VISUALIZATION_DIR)
    
    # 绘制Ne比例 (以第一个群体为参考)
    if len(POPULATIONS) > 1:
        plot_ne_ratio(POPULATIONS, POPULATIONS[0], MSMC_OUTPUT_DIR, VISUALIZATION_DIR)
    
    print("\nDone!")
