#!/bin/bash

# Test script for the multi-sample genetic screening pipeline
# This script validates the pipeline setup and tests with a small subset

echo "Multi-Sample Genetic Screening Pipeline - Test Mode"
echo "=================================================="

# Configuration - Update these paths according to your setup
BEDFILE="../unified_peakome_1kb_no_overlaps.bed"
SAMPLES_FILE="../samples.txt"
INPUT_DIR="/gpfs/data/abl/home/rodrij92/PROJECTS/BALL_Corigami/C.Origami/data/hg38"
MODEL_PATH="/gpfs/data/abl/home/rodrij92/PROJECTS/BALL_Corigami/C.Origami/ball_stringent-oe_exp_pred_ep32.ckpt"
SEQ_PATH="/gpfs/data/abl/home/rodrij92/PROJECTS/BALL_Corigami/C.Origami/data/hg38/dna_sequence"

echo "Configuration:"
echo "BED file: $BEDFILE"
echo "Samples file: $SAMPLES_FILE"
echo "Input directory: $INPUT_DIR"
echo "Model path: $MODEL_PATH"
echo "Sequence path: $SEQ_PATH"
echo ""

# Check if all files exist
echo "Checking input files..."
if [ ! -f "$BEDFILE" ]; then
    echo "ERROR: BED file not found: $BEDFILE"
    exit 1
fi

if [ ! -f "$SAMPLES_FILE" ]; then
    echo "ERROR: Samples file not found: $SAMPLES_FILE"
    exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
    echo "ERROR: Input directory not found: $INPUT_DIR"
    exit 1
fi

if [ ! -f "$MODEL_PATH" ]; then
    echo "ERROR: Model file not found: $MODEL_PATH"
    exit 1
fi

if [ ! -d "$SEQ_PATH" ]; then
    echo "ERROR: Sequence directory not found: $SEQ_PATH"
    exit 1
fi

echo "All input files found successfully!"
echo ""

# Count samples
TOTAL_SAMPLES=$(grep -v '^[[:space:]]*#' "$SAMPLES_FILE" | grep -v '^[[:space:]]*$' | wc -l)
echo "Total samples in file: $TOTAL_SAMPLES"
echo ""

# Show sample list
echo "Sample list:"
grep -v '^[[:space:]]*#' "$SAMPLES_FILE" | grep -v '^[[:space:]]*$' | nl
echo ""

# Check sample files
echo "Checking sample files..."
echo "Sample,CTCF_Exists,ATAC_Exists,Status"
echo "------,-----------,----------,------"

while IFS= read -r sample_name; do
    # Skip empty lines and comments
    [[ -z "$sample_name" || "$sample_name" =~ ^[[:space:]]*# ]] && continue
    
    CTCF_PATH="${INPUT_DIR}/${sample_name}.dd-maxATAC-predict/maxatac_predict.bw"
    ATAC_PATH="${INPUT_DIR}/${sample_name}.dd-maxATAC_prepare/${sample_name}.dd_IS_slop20_RP20M_minmax01.bw"
    
    if [ -f "$CTCF_PATH" ]; then
        ctcf_exists="YES"
    else
        ctcf_exists="NO"
    fi
    
    if [ -f "$ATAC_PATH" ]; then
        atac_exists="YES"
    else
        atac_exists="NO"
    fi
    
    if [ "$ctcf_exists" = "YES" ] && [ "$atac_exists" = "YES" ]; then
        status="READY"
    else
        status="MISSING_FILES"
    fi
    
    echo "$sample_name,$ctcf_exists,$atac_exists,$status"
    
done < "$SAMPLES_FILE"

echo ""
echo "Pipeline validation complete!"
echo ""
echo "Next steps:"
echo "1. If all samples show 'READY' status, you can run the full pipeline"
echo "2. If some samples show 'MISSING_FILES', check the file paths"
echo "3. To run the full pipeline: ./run_multi_sample_screening.sh"
echo "4. To test with a single sample, create a test_samples.txt with just one sample" 