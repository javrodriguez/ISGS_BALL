#!/usr/bin/env python3
"""
Script to pool all ATAC-seq peak files and create a unified peakome with 1kb peaks.

This script:
1. Reads all .peaks.bed files in the current directory
2. Merges peaks whose distance is <= 1 bp
3. Converts all peaks to 1kb length through splitting and extending
4. Outputs a unified peakome in BED format

Usage: python create_unified_peakome.py
"""

import os
import glob
import argparse
from collections import defaultdict
import logging

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class Peak:
    """Represents a genomic peak with chromosome, start, end, and score."""
    
    def __init__(self, chrom, start, end, score=0.0, peak_id=""):
        self.chrom = chrom
        self.start = start
        self.end = end
        self.score = score
        self.peak_id = peak_id
    
    def __len__(self):
        return self.end - self.start
    
    def distance_to(self, other):
        """Calculate distance between this peak and another peak."""
        if self.chrom != other.chrom:
            return float('inf')
        
        if self.end < other.start:
            return other.start - self.end
        elif other.end < self.start:
            return self.start - other.end
        else:
            return 0  # Overlapping
    
    def merge_with(self, other):
        """Merge this peak with another peak."""
        if self.chrom != other.chrom:
            raise ValueError("Cannot merge peaks from different chromosomes")
        
        new_start = min(self.start, other.start)
        new_end = max(self.end, other.end)
        new_score = max(self.score, other.score)  # Take the higher score
        new_id = f"{self.peak_id}_{other.peak_id}" if self.peak_id and other.peak_id else ""
        
        return Peak(self.chrom, new_start, new_end, new_score, new_id)
    
    def to_bed_line(self):
        """Convert peak to BED format line."""
        return f"{self.chrom}\t{self.start}\t{self.end}\t{self.peak_id}\t{self.score}"
    
    def __repr__(self):
        return f"Peak({self.chrom}:{self.start}-{self.end}, score={self.score})"

def is_main_chromosome(chrom):
    """Check if chromosome is one of the main chromosomes (chr1-chr22, chrX)."""
    if chrom.startswith('chr'):
        # Extract the chromosome number/letter
        chrom_part = chrom[3:]
        if chrom_part.isdigit():
            return 1 <= int(chrom_part) <= 22
        elif chrom_part in ['X', 'Y']:
            return True
    return False

def read_peak_file(filename, max_peaks_per_sample=50000):
    """Read peaks from a BED file and keep only the top scoring peaks from main chromosomes."""
    peaks = []
    with open(filename, 'r') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            
            try:
                parts = line.split('\t')
                if len(parts) >= 4:
                    chrom = parts[0]
                    start = int(parts[1])
                    end = int(parts[2])
                    peak_id = parts[3]
                    score = float(parts[4]) if len(parts) > 4 else 0
                    
                    # Only keep peaks from main chromosomes
                    if is_main_chromosome(chrom):
                        peaks.append(Peak(chrom, start, end, score, peak_id))
                else:
                    logger.warning(f"Skipping malformed line {line_num} in {filename}: {line}")
            except (ValueError, IndexError) as e:
                logger.warning(f"Error parsing line {line_num} in {filename}: {e}")
    
    # Sort by score (descending) and keep only top peaks
    if len(peaks) > max_peaks_per_sample:
        peaks.sort(key=lambda p: p.score, reverse=True)
        peaks = peaks[:max_peaks_per_sample]
        logger.info(f"  Kept top {max_peaks_per_sample:,} peaks by score from {filename}")
    
    return peaks

def merge_close_peaks(peaks, max_distance=1):
    """Merge peaks that are within max_distance of each other."""
    if not peaks:
        return []
    
    # Sort peaks by chromosome and start position
    peaks.sort(key=lambda p: (p.chrom, p.start))
    
    merged_peaks = []
    current_peak = peaks[0]
    
    for next_peak in peaks[1:]:
        if current_peak.distance_to(next_peak) <= max_distance:
            # Merge the peaks
            current_peak = current_peak.merge_with(next_peak)
        else:
            # Add current peak to results and start new current peak
            merged_peaks.append(current_peak)
            current_peak = next_peak
    
    # Don't forget the last peak
    merged_peaks.append(current_peak)
    
    return merged_peaks

def make_peaks_uniform_length(peaks, target_length=1000):
    """Convert all peaks to target_length by splitting and extending. Ensures ALL peaks are exactly target_length."""
    uniform_peaks = []
    
    for peak in peaks:
        current_length = len(peak)
        
        if current_length == target_length:
            # Already the right size
            uniform_peaks.append(peak)
        
        elif current_length < target_length:
            # Need to extend the peak to exactly target_length
            extension_needed = target_length - current_length
            
            # Try to extend equally on both sides first
            half_extension = extension_needed // 2
            new_start = peak.start - half_extension
            new_end = peak.end + (extension_needed - half_extension)
            
            # Ensure we don't go below 0
            if new_start < 0:
                new_start = 0
                new_end = target_length
            
            # Create the extended peak
            extended_peak = Peak(peak.chrom, new_start, new_end, peak.score, peak.peak_id)
            uniform_peaks.append(extended_peak)
        
        else:
            # Need to split the peak into multiple target_length pieces
            # Start from the beginning of the peak
            current_pos = peak.start
            
            while current_pos < peak.end:
                piece_start = current_pos
                piece_end = piece_start + target_length
                
                # If this piece would extend beyond the original peak, adjust it
                if piece_end > peak.end:
                    # Move the piece back so it ends at the original peak end
                    piece_end = peak.end
                    piece_start = piece_end - target_length
                    
                    # If we can't fit a full piece, skip it
                    if piece_start < peak.start:
                        break
                
                piece_id = f"{peak.peak_id}_piece_{len(uniform_peaks)+1}" if peak.peak_id else f"piece_{len(uniform_peaks)+1}"
                piece_peak = Peak(peak.chrom, piece_start, piece_end, peak.score, piece_id)
                uniform_peaks.append(piece_peak)
                
                # Move to next position
                current_pos = piece_end
    
    return uniform_peaks

def remove_overlapping_peaks(peaks):
    """Remove overlapping peaks, keeping the one with higher score."""
    if not peaks:
        return []
    
    # Sort by chromosome, start position, and score (descending)
    peaks.sort(key=lambda p: (p.chrom, p.start, -p.score))
    
    non_overlapping = []
    current_peak = peaks[0]
    
    for next_peak in peaks[1:]:
        if (current_peak.chrom == next_peak.chrom and 
            current_peak.end > next_peak.start):
            # Overlapping peaks - keep the one with higher score
            if current_peak.score >= next_peak.score:
                continue  # Keep current_peak
            else:
                current_peak = next_peak
        else:
            # No overlap, add current peak and move to next
            non_overlapping.append(current_peak)
            current_peak = next_peak
    
    # Don't forget the last peak
    non_overlapping.append(current_peak)
    
    return non_overlapping

def main():
    parser = argparse.ArgumentParser(description='Create unified peakome with 1kb peaks')
    parser.add_argument('--input-pattern', default='*.peaks.bed', 
                       help='Pattern to match peak files (default: *.peaks.bed)')
    parser.add_argument('--output', default='unified_peakome_1kb.bed',
                       help='Output file name (default: unified_peakome_1kb.bed)')
    parser.add_argument('--target-length', type=int, default=1000,
                       help='Target peak length in bp (default: 1000)')
    parser.add_argument('--merge-distance', type=int, default=1,
                       help='Maximum distance for merging peaks in bp (default: 1)')
    parser.add_argument('--max-peaks-per-sample', type=int, default=50000,
                       help='Maximum number of peaks to keep per sample (default: 50000)')
    parser.add_argument('--remove-overlaps', action='store_true',
                       help='Remove overlapping peaks after processing')
    
    args = parser.parse_args()
    
    # Find all peak files
    peak_files = glob.glob(args.input_pattern)
    if not peak_files:
        logger.error(f"No files found matching pattern: {args.input_pattern}")
        return 1
    
    logger.info(f"Found {len(peak_files)} peak files")
    
    # Read all peaks
    all_peaks = []
    for filename in peak_files:
        logger.info(f"Reading {filename}")
        peaks = read_peak_file(filename, args.max_peaks_per_sample)
        all_peaks.extend(peaks)
        logger.info(f"  Loaded {len(peaks)} peaks from {filename}")
    
    logger.info(f"Total peaks loaded: {len(all_peaks)}")
    
    # Group peaks by chromosome
    peaks_by_chrom = defaultdict(list)
    for peak in all_peaks:
        peaks_by_chrom[peak.chrom].append(peak)
    
    logger.info(f"Peaks distributed across {len(peaks_by_chrom)} chromosomes")
    
    # Process each chromosome separately
    processed_peaks = []
    for chrom, peaks in peaks_by_chrom.items():
        logger.info(f"Processing chromosome {chrom} with {len(peaks)} peaks")
        
        # Step 1: Merge close peaks
        merged_peaks = merge_close_peaks(peaks, args.merge_distance)
        logger.info(f"  After merging: {len(merged_peaks)} peaks")
        
        # Step 2: Make peaks uniform length
        uniform_peaks = make_peaks_uniform_length(merged_peaks, args.target_length)
        logger.info(f"  After uniform length conversion: {len(uniform_peaks)} peaks")
        
        processed_peaks.extend(uniform_peaks)
    
    # Step 3: Remove overlapping peaks if requested
    if args.remove_overlaps:
        logger.info("Removing overlapping peaks")
        processed_peaks = remove_overlapping_peaks(processed_peaks)
        logger.info(f"After removing overlaps: {len(processed_peaks)} peaks")
    
    # Sort final peaks
    processed_peaks.sort(key=lambda p: (p.chrom, p.start))
    
    # Write output
    logger.info(f"Writing {len(processed_peaks)} peaks to {args.output}")
    with open(args.output, 'w') as f:
        for i, peak in enumerate(processed_peaks):
            # Generate a unique ID if none exists
            if not peak.peak_id:
                peak.peak_id = f"unified_peak_{i+1:06d}"
            
            f.write(peak.to_bed_line() + '\n')
    
    logger.info(f"Successfully created unified peakome: {args.output}")
    
    # Print summary statistics
    lengths = [len(p) for p in processed_peaks]
    logger.info(f"Peak length statistics:")
    logger.info(f"  Mean length: {sum(lengths) / len(lengths):.1f} bp")
    logger.info(f"  Min length: {min(lengths)} bp")
    logger.info(f"  Max length: {max(lengths)} bp")
    
    return 0

if __name__ == "__main__":
    exit(main()) 