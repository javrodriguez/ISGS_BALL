#!/usr/bin/env python3
"""
Demonstration of the overlap removal algorithm with a simple example.
"""

class Peak:
    def __init__(self, chrom, start, end, score=0.0, peak_id=""):
        self.chrom = chrom
        self.start = start
        self.end = end
        self.score = score
        self.peak_id = peak_id
    
    def __len__(self):
        return self.end - self.start
    
    def __repr__(self):
        return f"Peak({self.chrom}:{self.start}-{self.end}, score={self.score}, id={self.peak_id})"

def remove_overlapping_peaks_demo(peaks):
    """Demonstrate the overlap removal algorithm step by step."""
    if not peaks:
        return []
    
    print("=== OVERLAP REMOVAL DEMONSTRATION ===")
    print(f"Input peaks: {len(peaks)}")
    for i, peak in enumerate(peaks):
        print(f"  {i+1}. {peak}")
    print()
    
    # Sort by chromosome, start position, and score (descending)
    peaks.sort(key=lambda p: (p.chrom, p.start, -p.score))
    print("After sorting (by chrom, start, -score):")
    for i, peak in enumerate(peaks):
        print(f"  {i+1}. {peak}")
    print()
    
    non_overlapping = []
    current_peak = peaks[0]
    print(f"Starting with: {current_peak}")
    
    for i, next_peak in enumerate(peaks[1:], 1):
        print(f"\nStep {i}: Comparing {current_peak} vs {next_peak}")
        
        # Check for overlap
        if (current_peak.chrom == next_peak.chrom and 
            current_peak.end > next_peak.start):
            
            print(f"  → OVERLAP DETECTED!")
            print(f"  → Current peak ends at {current_peak.end}, next peak starts at {next_peak.start}")
            print(f"  → Overlap length: {min(current_peak.end, next_peak.end) - max(current_peak.start, next_peak.start)} bp")
            
            # Overlapping peaks - keep the one with higher score
            if current_peak.score >= next_peak.score:
                print(f"  → KEEPING current peak (score {current_peak.score} >= {next_peak.score})")
                print(f"  → DISCARDING next peak")
            else:
                print(f"  → REPLACING current peak with next peak (score {next_peak.score} > {current_peak.score})")
                current_peak = next_peak
        else:
            # No overlap, add current peak and move to next
            print(f"  → NO OVERLAP - adding {current_peak} to results")
            non_overlapping.append(current_peak)
            current_peak = next_peak
    
    # Don't forget the last peak
    print(f"\nFinal step: Adding last peak {current_peak}")
    non_overlapping.append(current_peak)
    
    print(f"\n=== RESULTS ===")
    print(f"Output peaks: {len(non_overlapping)}")
    for i, peak in enumerate(non_overlapping):
        print(f"  {i+1}. {peak}")
    
    return non_overlapping

def visualize_overlaps(peaks):
    """Create a simple visualization of peak overlaps."""
    print("\n=== PEAK VISUALIZATION ===")
    
    # Find the range
    min_pos = min(p.start for p in peaks)
    max_pos = max(p.end for p in peaks)
    
    # Sort peaks by score for visualization
    sorted_peaks = sorted(peaks, key=lambda p: p.score, reverse=True)
    
    print(f"Genomic range: {min_pos:,} - {max_pos:,} bp")
    print()
    
    for peak in sorted_peaks:
        # Create a simple bar representation
        bar_length = 50
        start_rel = (peak.start - min_pos) / (max_pos - min_pos)
        end_rel = (peak.end - min_pos) / (max_pos - min_pos)
        
        start_pos = int(start_rel * bar_length)
        end_pos = int(end_rel * bar_length)
        
        bar = [' '] * bar_length
        for i in range(start_pos, min(end_pos, bar_length)):
            bar[i] = '█'
        
        print(f"{peak.peak_id:8} [{peak.start:6,}-{peak.end:6,}] score={peak.score:5.1f} {'|' + ''.join(bar) + '|'}")

# Example with overlapping peaks
if __name__ == "__main__":
    # Create example peaks with overlaps
    example_peaks = [
        Peak("chr1", 1000, 2000, 15.0, "peak_A"),  # High score, early
        Peak("chr1", 1500, 2500, 12.0, "peak_B"),  # Overlaps with A, lower score
        Peak("chr1", 3000, 4000, 18.0, "peak_C"),  # No overlap, highest score
        Peak("chr1", 3500, 4500, 10.0, "peak_D"),  # Overlaps with C, lowest score
        Peak("chr1", 5000, 6000, 14.0, "peak_E"),  # No overlap
        Peak("chr2", 1000, 2000, 16.0, "peak_F"),  # Different chromosome
    ]
    
    print("=== EXAMPLE: Overlapping Peaks ===")
    visualize_overlaps(example_peaks)
    
    # Run the overlap removal
    result = remove_overlapping_peaks_demo(example_peaks)
    
    print("\n=== FINAL VISUALIZATION ===")
    visualize_overlaps(result)
    
    print(f"\n=== SUMMARY ===")
    print(f"Input peaks: {len(example_peaks)}")
    print(f"Output peaks: {len(result)}")
    print(f"Peaks removed: {len(example_peaks) - len(result)}")
    print(f"Reduction: {(len(example_peaks) - len(result)) / len(example_peaks) * 100:.1f}%") 