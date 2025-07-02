#!/usr/bin/env python3
"""
Script to analyze the unified peakome and provide detailed statistics.
"""

import sys
from collections import defaultdict, Counter

def analyze_peakome(filename):
    """Analyze the unified peakome file."""
    
    chrom_stats = defaultdict(int)
    score_stats = []
    length_stats = []
    
    with open(filename, 'r') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            
            try:
                parts = line.split('\t')
                if len(parts) >= 5:
                    chrom = parts[0]
                    start = int(parts[1])
                    end = int(parts[2])
                    peak_id = parts[3]
                    score = float(parts[4])
                    
                    # Calculate length
                    length = end - start
                    
                    # Collect statistics
                    chrom_stats[chrom] += 1
                    score_stats.append(score)
                    length_stats.append(length)
                    
                else:
                    print(f"Warning: Skipping malformed line {line_num}")
                    
            except (ValueError, IndexError) as e:
                print(f"Error parsing line {line_num}: {e}")
    
    # Print summary statistics
    print(f"=== Unified Peakome Analysis: {filename} ===")
    print(f"Total peaks: {len(score_stats):,}")
    print(f"Chromosomes: {len(chrom_stats)}")
    print()
    
    # Length statistics
    print("=== Peak Length Statistics ===")
    print(f"Mean length: {sum(length_stats) / len(length_stats):.1f} bp")
    print(f"Median length: {sorted(length_stats)[len(length_stats)//2]} bp")
    print(f"Min length: {min(length_stats)} bp")
    print(f"Max length: {max(length_stats)} bp")
    print()
    
    # Score statistics
    print("=== Peak Score Statistics ===")
    print(f"Mean score: {sum(score_stats) / len(score_stats):.3f}")
    print(f"Median score: {sorted(score_stats)[len(score_stats)//2]:.3f}")
    print(f"Min score: {min(score_stats):.3f}")
    print(f"Max score: {max(score_stats):.3f}")
    print()
    
    # Chromosome distribution (top 10)
    print("=== Chromosome Distribution (Top 10) ===")
    sorted_chroms = sorted(chrom_stats.items(), key=lambda x: x[1], reverse=True)
    for chrom, count in sorted_chroms[:10]:
        print(f"{chrom}: {count:,} peaks")
    print()
    
    # Length distribution
    print("=== Length Distribution ===")
    length_counts = Counter(length_stats)
    for length in sorted(length_counts.keys()):
        count = length_counts[length]
        percentage = (count / len(length_stats)) * 100
        print(f"{length} bp: {count:,} peaks ({percentage:.1f}%)")
    
    # Check for 1kb peaks specifically
    kb_peaks = length_counts.get(1000, 0)
    print(f"\nPeaks exactly 1000 bp: {kb_peaks:,} ({kb_peaks/len(length_stats)*100:.1f}%)")

if __name__ == "__main__":
    filename = sys.argv[1] if len(sys.argv) > 1 else "unified_peakome_1kb.bed"
    analyze_peakome(filename) 