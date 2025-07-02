#!/usr/bin/env python3
"""
Script to analyze whether MACS2 scores are comparable across different samples.
"""

import sys
import glob
import numpy as np
from collections import defaultdict
import matplotlib.pyplot as plt

def analyze_score_distributions():
    """Analyze score distributions across different samples."""
    
    # Get all peak files
    peak_files = glob.glob("peaks/GSM*.peaks.bed")
    
    print(f"=== MACS2 Score Comparability Analysis ===")
    print(f"Analyzing {len(peak_files)} peak files")
    print()
    
    # Collect score statistics for each sample
    sample_stats = {}
    
    for filename in peak_files:
        sample_id = filename.split('/')[-1].replace('.peaks.bed', '')
        scores = []
        
        with open(filename, 'r') as f:
            for line in f:
                parts = line.strip().split('\t')
                if len(parts) >= 5:
                    try:
                        score = float(parts[4])
                        scores.append(score)
                    except ValueError:
                        continue
        
        if scores:
            sample_stats[sample_id] = {
                'count': len(scores),
                'mean': np.mean(scores),
                'median': np.median(scores),
                'std': np.std(scores),
                'min': np.min(scores),
                'max': np.max(scores),
                'q25': np.percentile(scores, 25),
                'q75': np.percentile(scores, 75)
            }
    
    # Print summary statistics
    print("=== Sample Score Statistics ===")
    print(f"{'Sample':<15} {'Count':<8} {'Mean':<8} {'Median':<8} {'Std':<8} {'Min':<8} {'Max':<8}")
    print("-" * 80)
    
    means = []
    medians = []
    stds = []
    
    for sample_id, stats in sorted(sample_stats.items()):
        print(f"{sample_id:<15} {stats['count']:<8} {stats['mean']:<8.2f} {stats['median']:<8.2f} "
              f"{stats['std']:<8.2f} {stats['min']:<8.2f} {stats['max']:<8.2f}")
        means.append(stats['mean'])
        medians.append(stats['median'])
        stds.append(stats['std'])
    
    print()
    
    # Overall statistics
    print("=== Overall Score Distribution ===")
    print(f"Mean of sample means: {np.mean(means):.3f} ± {np.std(means):.3f}")
    print(f"Mean of sample medians: {np.mean(medians):.3f} ± {np.std(medians):.3f}")
    print(f"Mean of sample stds: {np.mean(stds):.3f} ± {np.std(stds):.3f}")
    print()
    
    # Coefficient of variation analysis
    print("=== Coefficient of Variation Analysis ===")
    cv_means = np.std(means) / np.mean(means) * 100
    cv_medians = np.std(medians) / np.mean(medians) * 100
    cv_stds = np.std(stds) / np.mean(stds) * 100
    
    print(f"CV of sample means: {cv_means:.1f}%")
    print(f"CV of sample medians: {cv_medians:.1f}%")
    print(f"CV of sample stds: {cv_stds:.1f}%")
    print()
    
    # Assess comparability
    print("=== Score Comparability Assessment ===")
    
    if cv_means < 20:
        print("✅ LOW VARIATION: Sample means are relatively consistent")
        print("   → MACS2 scores appear comparable across samples")
    elif cv_means < 50:
        print("⚠️  MODERATE VARIATION: Some variation in sample means")
        print("   → MACS2 scores may be partially comparable")
    else:
        print("❌ HIGH VARIATION: Large variation in sample means")
        print("   → MACS2 scores may NOT be comparable across samples")
    
    print()
    
    # Check for systematic differences
    print("=== Systematic Differences Analysis ===")
    
    # Calculate rank correlation between sample means and medians
    from scipy.stats import spearmanr
    correlation, p_value = spearmanr(means, medians)
    print(f"Correlation between sample means and medians: {correlation:.3f} (p={p_value:.3e})")
    
    if correlation > 0.8:
        print("✅ HIGH CORRELATION: Sample means and medians are strongly correlated")
        print("   → Consistent ranking across samples")
    else:
        print("⚠️  LOW CORRELATION: Inconsistent ranking across samples")
    
    print()
    
    # Check for extreme outliers
    print("=== Outlier Analysis ===")
    
    # Find samples with extreme statistics
    mean_mean = np.mean(means)
    mean_std = np.std(means)
    
    outliers = []
    for sample_id, stats in sample_stats.items():
        z_score = abs(stats['mean'] - mean_mean) / mean_std
        if z_score > 2:
            outliers.append((sample_id, stats['mean'], z_score))
    
    if outliers:
        print(f"Found {len(outliers)} samples with extreme mean scores (|z-score| > 2):")
        for sample_id, mean_score, z_score in sorted(outliers, key=lambda x: x[2], reverse=True):
            print(f"  {sample_id}: mean={mean_score:.2f}, z-score={z_score:.2f}")
    else:
        print("✅ No extreme outliers detected")
    
    print()
    
    # Recommendations
    print("=== Recommendations ===")
    
    if cv_means < 20 and correlation > 0.8:
        print("✅ RECOMMENDATION: Use score-based overlap removal")
        print("   → MACS2 scores are comparable across samples")
        print("   → Score-based selection is appropriate")
    elif cv_means < 50:
        print("⚠️  RECOMMENDATION: Consider score normalization or alternative methods")
        print("   → Some variation in scores across samples")
        print("   → Consider using rank-based methods instead")
    else:
        print("❌ RECOMMENDATION: Avoid score-based overlap removal")
        print("   → MACS2 scores are not comparable across samples")
        print("   → Use alternative methods (e.g., random selection, position-based)")
    
    # Additional considerations
    print()
    print("=== Additional Considerations ===")
    print("1. MACS2 scores are sample-specific and depend on:")
    print("   - Sequencing depth")
    print("   - Library complexity")
    print("   - Background noise levels")
    print("   - Peak calling parameters")
    print()
    print("2. Alternative overlap removal strategies:")
    print("   - Random selection (maintains sample diversity)")
    print("   - Position-based selection (e.g., keep leftmost peak)")
    print("   - Sample-based selection (e.g., keep peak from sample with more peaks)")
    print("   - Score normalization (z-score within each sample)")
    
    return sample_stats

if __name__ == "__main__":
    analyze_score_distributions() 