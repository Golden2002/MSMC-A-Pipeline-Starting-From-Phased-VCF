#!/usr/bin/env python3
"""
=====================================
MSMC Visualization - Ne Curves
=====================================
Description: Plot effective population size (Ne) history from MSMC2 output
Author: Generated for MSMC Pipeline
Date: 2025-03-11
=====================================

Usage:
    python plot_msmc_ne.py [--input-dir DIR] [--output-dir DIR] [--populations POP1,POP2,...]
    
Output:
    - Ne_curves.png: Multi-population Ne over time
    - Ne_curves.pdf: Vector format for publication
"""

import os
import sys
import argparse
import glob
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
from pathlib import Path

# =====================================
# Configuration
# =====================================

# Default parameters
GENERATION_TIME = 25  # Years per generation (default for humans)
MUTATION_RATE = 1.2e-8  # Per site per generation
REC_RATE = 1e-8  # Per site per generation

# Plot styling
DEFAULT_FIGSIZE = (10, 8)
DEFAULT_DPI = 300
COLOR_PALETTE = {
    'Jino': '#e41a1c',
    'Tibetan': '#377eb8',
    'Han': '#4daf4a',
    'Dai': '#984ea3',
    'Hani': '#ff7f00',
    'Lahu': '#ffff33',
    'Pumi': '#a65628',
    'Mosuo': '#f781bf',
    'Naxi': '#999999',
    'Qiang': '#66c2a5',
    'Sherpa': '#fc8d62',
    'Wa': '#8da0cb',
    'Zhuang': '#e78ac3',
    'Dong': '#a6d854',
    'Buyei': '#ffd92f',
}


def parse_msmc_output(filename):
    """
    Parse MSMC2 output file and extract time and population size estimates.
    
    MSMC2 output format:
    index\tleft_time_boundary\tright_time_boundary\tlambda\ttime_index\tNe
    
    Parameters:
        filename: Path to MSMC2 output file
        
    Returns:
        times: Array of time points (in years)
        Ne: Array of effective population sizes
    """
    times = []
    Ne = []
    
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('#'):
                continue
            if not line:
                continue
            
            parts = line.split('\t')
            if len(parts) < 6:
                continue
            
            try:
                # Parse time boundaries
                left_time = float(parts[1])
                right_time = float(parts[2])
                
                # Convert to years using mutation rate and generation time
                # time in MSMC is in units of coalescent time (2Ne generations)
                # We need to convert to years
                avg_time = (left_time + right_time) / 2.0
                
                # Using the standard conversion: time * 2 * Ne * generation_time
                # But MSMC outputs lambda (coalescence rate), so Ne = 1/lambda
                lambda_val = float(parts[3])
                
                if lambda_val > 0:
                    ne = 1.0 / lambda_val
                    time_years = avg_time * 2 * ne * GENERATION_TIME / 1e6  # In million years
                    
                    times.append(time_years)
                    Ne.append(ne)
            except (ValueError, IndexError):
                continue
    
    return np.array(times), np.array(Ne)


def load_population_data(input_dir, populations=None):
    """
    Load MSMC data for specified populations.
    
    Parameters:
        input_dir: Directory containing MSMC output files
        populations: List of population names to load (None = all)
        
    Returns:
        Dictionary: {population_name: (times, Ne)}
    """
    data = {}
    
    # Find all MSMC output files
    if populations is None:
        # Get all populations from file names
        files = glob.glob(os.path.join(input_dir, '*.msmc2'))
        pop_names = set()
        for f in files:
            basename = os.path.basename(f)
            # Extract population name (before _chr or _final)
            pop_name = basename.split('_chr')[0].split('_final')[0]
            pop_names.add(pop_name)
        populations = sorted(list(pop_names))
    
    for pop in populations:
        # Look for final combined file first
        final_file = os.path.join(input_dir, f'{pop}_final.msmc2')
        
        if os.path.exists(final_file):
            times, ne = parse_msmc_output(final_file)
            if len(times) > 0:
                data[pop] = (times, ne)
                print(f"Loaded {pop}: {len(times)} time points")
        else:
            # Try to find any chromosome file
            chr_files = sorted(glob.glob(os.path.join(input_dir, f'{pop}_chr*.msmc2')))
            if chr_files:
                # Use first chromosome as representative
                times, ne = parse_msmc_output(chr_files[0])
                if len(times) > 0:
                    data[pop] = (times, ne)
                    print(f"Loaded {pop} (chr1): {len(times)} time points")
    
    return data


def plot_ne_curves(data, output_file, title='Effective Population Size History',
                   xlabel='Time (million years ago)', ylabel='Effective Population Size (Ne)'):
    """
    Plot Ne curves for multiple populations.
    
    Parameters:
        data: Dictionary of {pop_name: (times, Ne)}
        output_file: Output file path
        title: Plot title
        xlabel: X-axis label
        ylabel: Y-axis label
    """
    fig, ax = plt.subplots(figsize=DEFAULT_FIGSIZE)
    
    # Sort populations for consistent legend
    sorted_pops = sorted(data.keys())
    
    for pop in sorted_pops:
        times, ne = data[pop]
        
        # Get color from palette or generate one
        color = COLOR_PALETTE.get(pop, None)
        
        ax.plot(times, ne, label=pop, linewidth=2, color=color, alpha=0.8)
    
    # Formatting
    ax.set_xlabel(xlabel, fontsize=12)
    ax.set_ylabel(ylabel, fontsize=12)
    ax.set_title(title, fontsize=14, fontweight='bold')
    
    # Log scale for better visualization
    ax.set_yscale('log')
    
    # Add legend
    ax.legend(loc='best', fontsize=10, framealpha=0.9)
    
    # Grid
    ax.grid(True, alpha=0.3, linestyle='--')
    
    # Format axis
    ax.tick_params(axis='both', labelsize=10)
    
    # Scientific notation for x-axis if needed
    ax.xaxis.set_major_formatter(ticker.FormatStrFormatter('%.1f'))
    
    plt.tight_layout()
    
    # Save in multiple formats
    # PNG
    png_file = output_file.replace('.png', '.png')
    plt.savefig(png_file, dpi=DEFAULT_DPI, bbox_inches='tight')
    print(f"Saved: {png_file}")
    
    # PDF (vector format for publication)
    pdf_file = output_file.replace('.png', '.pdf')
    plt.savefig(pdf_file, format='pdf', bbox_inches='tight')
    print(f"Saved: {pdf_file}")
    
    plt.close()


def plot_ne_comparison(data, output_file, reference_pop='Han'):
    """
    Plot Ne ratio relative to a reference population.
    
    Parameters:
        data: Dictionary of {pop_name: (times, Ne)}
        output_file: Output file path
        reference_pop: Reference population for comparison
    """
    if reference_pop not in data:
        print(f"Reference population {reference_pop} not found in data")
        return
    
    ref_times, ref_ne = data[reference_pop]
    
    fig, ax = plt.subplots(figsize=DEFAULT_FIGSIZE)
    
    sorted_pops = sorted(data.keys())
    
    for pop in sorted_pops:
        if pop == reference_pop:
            continue
        
        times, ne = data[pop]
        
        # Interpolate to common time points
        # Use reference times as common grid
        common_times = ref_times
        ref_interp = np.interp(common_times, ref_times[::-1], ref_ne[::-1])
        ne_interp = np.interp(common_times, times[::-1], ne[::-1])
        
        # Calculate ratio
        ratio = ne_interp / ref_interp
        
        color = COLOR_PALETTE.get(pop, None)
        ax.plot(common_times, ratio, label=pop, linewidth=2, color=color, alpha=0.8)
    
    # Add reference line
    ax.axhline(y=1, color='black', linestyle='--', linewidth=1, alpha=0.5)
    
    # Formatting
    ax.set_xlabel('Time (million years ago)', fontsize=12)
    ax.set_ylabel(f'Ne ratio (vs {reference_pop})', fontsize=12)
    ax.set_title(f'Effective Population Size Ratio (Reference: {reference_pop})', 
                 fontsize=14, fontweight='bold')
    
    ax.legend(loc='best', fontsize=10, framealpha=0.9)
    ax.grid(True, alpha=0.3, linestyle='--')
    ax.tick_params(axis='both', labelsize=10)
    
    plt.tight_layout()
    
    png_file = output_file.replace('.png', '_ratio.png')
    plt.savefig(png_file, dpi=DEFAULT_DPI, bbox_inches='tight')
    print(f"Saved: {png_file}")
    
    plt.close()


def main():
    parser = argparse.ArgumentParser(
        description='Plot MSMC effective population size curves'
    )
    parser.add_argument(
        '--input-dir', '-i',
        default='msmc_output',
        help='Directory containing MSMC output files'
    )
    parser.add_argument(
        '--output-dir', '-o',
        default='visualization',
        help='Output directory for plots'
    )
    parser.add_argument(
        '--populations', '-p',
        default=None,
        help='Comma-separated list of populations to plot (default: all)'
    )
    parser.add_argument(
        '--reference', '-r',
        default='Han',
        help='Reference population for ratio plots'
    )
    parser.add_argument(
        '--generation-time', '-g',
        type=int,
        default=25,
        help='Generation time in years (default: 25)'
    )
    
    args = parser.parse_args()
    
    # Update global parameters
    global GENERATION_TIME
    GENERATION_TIME = args.generation_time
    
    # Create output directory
    os.makedirs(args.output_dir, exist_ok=True)
    
    # Parse populations
    populations = None
    if args.populations:
        populations = [p.strip() for p in args.populations.split(',')]
    
    print("=" * 60)
    print("MSMC Ne Curve Visualization")
    print("=" * 60)
    print(f"Input directory: {args.input_dir}")
    print(f"Output directory: {args.output_dir}")
    if populations:
        print(f"Populations: {populations}")
    print(f"Generation time: {GENERATION_TIME} years")
    print()
    
    # Load data
    print("Loading MSMC data...")
    data = load_population_data(args.input_dir, populations)
    
    if not data:
        print("ERROR: No data loaded. Please check input directory.")
        sys.exit(1)
    
    print(f"Loaded {len(data)} populations")
    print()
    
    # Plot Ne curves
    print("Generating Ne curve plot...")
    output_file = os.path.join(args.output_dir, 'Ne_curves.png')
    plot_ne_curves(data, output_file, 
                   title='Effective Population Size History')
    
    # Plot ratio if reference exists
    if args.reference in data:
        print(f"\nGenerating ratio plot (reference: {args.reference})...")
        ratio_file = os.path.join(args.output_dir, 'Ne_ratio.png')
        plot_ne_comparison(data, ratio_file, args.reference)
    
    print("\n" + "=" * 60)
    print("Visualization complete!")
    print("=" * 60)


if __name__ == '__main__':
    main()
