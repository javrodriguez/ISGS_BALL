#!/usr/bin/env python3
"""
Script to analyze overlapping peaks in the unified peakome and assess redundancy.
"""

import sys
from collections import defaultdict, Counter

class Peak:
    def __init__(self, chrom, start, end, peak_id, score):
        self.chrom = chrom
        self.start = start
        self.end = end
        self.peak_id = peak_id
        self.score = score
    
    def overlaps_with(self, other):
        """Check if this peak overlaps with another peak."""
        if self.chrom != other.chrom:
            return False
        return not (self.end <= other.start or other.end <= self.start)
    
    def overlap_length(self, other):
        """Calculate the length of overlap with another peak."""
        if not self.overlaps_with(other):
            return 0
        return min(self.end, other.end) - max(self.start, other.start)

def analyze_overlaps(filename):
    """Analyze overlapping peaks in the unified peakome."""
    
    # Read all peaks
    peaks = []
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
                    
                    peaks.append(Peak(chrom, start, end, peak_id, score))
                    
            except (ValueError, IndexError) as e:
                print(f"Error parsing line {line_num}: {e}")
    
    print(f"=== Overlap Analysis: {filename} ===")
    print(f"Total peaks: {len(peaks):,}")
    print()
    
    # Group peaks by chromosome
    peaks_by_chrom = defaultdict(list)
    for peak in peaks:
        peaks_by_chrom[peak.chrom].append(peak)
    
    # Analyze overlaps by chromosome
    total_overlaps = 0
    overlap_lengths = []
    overlapping_peaks = set()
    overlap_groups = []
    
    for chrom, chrom_peaks in peaks_by_chrom.items():
        print(f"Analyzing chromosome {chrom} ({len(chrom_peaks):,} peaks)")
        
        # Sort peaks by start position
        chrom_peaks.sort(key=lambda p: p.start)
        
        chrom_overlaps = 0
        chrom_overlap_lengths = []
        
        # Check for overlaps
        for i, peak1 in enumerate(chrom_peaks):
            overlaps_with = []
            for j, peak2 in enumerate(chrom_peaks[i+1:], i+1):
                if peak1.overlaps_with(peak2):
                    overlap_len = peak1.overlap_length(peak2)
                    overlaps_with.append((peak2, overlap_len))
                    chrom_overlaps += 1
                    overlapping_peaks.add(peak1)
                    overlapping_peaks.add(peak2)
                    chrom_overlap_lengths.append(overlap_len)
            
            if overlaps_with:
                overlap_groups.append([peak1] + [p[0] for p in overlaps_with])
        
        total_overlaps += chrom_overlaps
        overlap_lengths.extend(chrom_overlap_lengths)
        
        print(f"  Overlaps found: {chrom_overlaps:,}")
        if chrom_overlaps > 0:
            print(f"  Average overlap length: {sum(chrom_overlap_lengths)/len(chrom_overlap_lengths):.1f} bp")
            print(f"  Max overlap length: {max(chrom_overlap_lengths)} bp")
        print()
    
    # Overall statistics
    print("=== Overall Overlap Statistics ===")
    print(f"Total overlapping peak pairs: {total_overlaps:,}")
    print(f"Peaks involved in overlaps: {len(overlapping_peaks):,} ({len(overlapping_peaks)/len(peaks)*100:.1f}%)")
    print(f"Non-overlapping peaks: {len(peaks) - len(overlapping_peaks):,} ({(len(peaks) - len(overlapping_peaks))/len(peaks)*100:.1f}%)")
    
    if overlap_lengths:
        print(f"Average overlap length: {sum(overlap_lengths)/len(overlap_lengths):.1f} bp")
        print(f"Median overlap length: {sorted(overlap_lengths)[len(overlap_lengths)//2]} bp")
        print(f"Min overlap length: {min(overlap_lengths)} bp")
        print(f"Max overlap length: {max(overlap_lengths)} bp")
    
    # Overlap length distribution
    if overlap_lengths:
        print("\n=== Overlap Length Distribution ===")
        overlap_counts = Counter(overlap_lengths)
        for length in sorted(overlap_counts.keys())[:20]:  # Top 20
            count = overlap_counts[length]
            percentage = (count / len(overlap_lengths)) * 100
            print(f"{length} bp: {count:,} overlaps ({percentage:.1f}%)")
    
    # Analyze overlap groups
    print(f"\n=== Overlap Group Analysis ===")
    print(f"Number of overlap groups: {len(overlap_groups):,}")
    
    if overlap_groups:
        group_sizes = [len(group) for group in overlap_groups]
        print(f"Average group size: {sum(group_sizes)/len(group_sizes):.1f} peaks")
        print(f"Max group size: {max(group_sizes)} peaks")
        
        # Show some examples of large overlap groups
        large_groups = [g for g in overlap_groups if len(g) > 3]
        if large_groups:
            print(f"\nLarge overlap groups (>3 peaks): {len(large_groups):,}")
            print("Examples of large overlap groups:")
            for i, group in enumerate(large_groups[:5]):  # Show first 5
                print(f"  Group {i+1}: {len(group)} peaks at {group[0].chrom}:{group[0].start}-{group[0].end}")
                print(f"    Scores: {[p.score for p in group]}")
    
    # Assess potential bias
    print(f"\n=== Potential Bias Assessment ===")
    
    if overlapping_peaks:
        # Compare scores between overlapping and non-overlapping peaks
        overlapping_scores = [p.score for p in overlapping_peaks]
        non_overlapping_scores = [p.score for p in peaks if p not in overlapping_peaks]
        
        if non_overlapping_scores:
            print(f"Overlapping peaks - Mean score: {sum(overlapping_scores)/len(overlapping_scores):.3f}")
            print(f"Non-overlapping peaks - Mean score: {sum(non_overlapping_scores)/len(non_overlapping_scores):.3f}")
            
            score_diff = (sum(overlapping_scores)/len(overlapping_scores)) - (sum(non_overlapping_scores)/len(non_overlapping_scores))
            print(f"Score difference: {score_diff:.3f}")
            
            if abs(score_diff) > 0.5:
                print("⚠️  WARNING: Significant score difference between overlapping and non-overlapping peaks!")
                print("   This could indicate bias in the peak selection process.")
            else:
                print("✅ No significant score bias detected between overlapping and non-overlapping peaks.")
    
    # Recommendations
    print(f"\n=== Recommendations ===")
    if total_overlaps > 0:
        overlap_percentage = (total_overlaps / (len(peaks) * (len(peaks) - 1) / 2)) * 100
        print(f"Overlap rate: {overlap_percentage:.2f}% of possible peak pairs")
        
        if overlap_percentage > 5:
            print("⚠️  HIGH OVERLAP RATE: Consider removing overlapping peaks for downstream analysis")
            print("   - Use --remove-overlaps flag in create_unified_peakome.py")
            print("   - Or implement custom overlap removal based on your analysis needs")
        elif overlap_percentage > 1:
            print("⚠️  MODERATE OVERLAP RATE: Monitor for potential redundancy in downstream analysis")
        else:
            print("✅ LOW OVERLAP RATE: Minimal redundancy concerns")
        
        if len(overlapping_peaks) / len(peaks) > 0.3:
            print("⚠️  MANY OVERLAPPING PEAKS: Consider impact on statistical power")
            print("   - Overlapping peaks may not be independent observations")
            print("   - Could affect statistical tests that assume independence")
    else:
        print("✅ NO OVERLAPS: Perfect peak separation")

if __name__ == "__main__":
    filename = sys.argv[1] if len(sys.argv) > 1 else "unified_peakome_1kb_all_samples.bed"
    analyze_overlaps(filename) 