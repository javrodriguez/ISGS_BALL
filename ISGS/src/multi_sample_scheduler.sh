#!/bin/bash
#SBATCH -J multiSampleScheduler
#SBATCH --partition=gpu4_long,gpu8_long
#SBATCH --mem=2gb 
#SBATCH --output=logs-multi_sample_scheduler/%J.logout
#SBATCH --error=logs-multi_sample_scheduler/%J.logerr

# Multi-sample genetic screening scheduler
# Usage: sbatch multi_sample_scheduler.sh <bedfile> <samples_file> <input_dir> <model_path> <seq_path>

BEDFILE=$1
SAMPLES_FILE=$2
INPUT_DIR=$3
MODEL_PATH=$4
SEQ_PATH=$5

# Validate inputs
if [ $# -ne 5 ]; then
    echo "Usage: sbatch multi_sample_scheduler.sh <bedfile> <samples_file> <input_dir> <model_path> <seq_path>"
    echo "Example: sbatch multi_sample_scheduler.sh unified_peakome_1kb_exact.bed samples.txt /path/to/data /path/to/model.ckpt /path/to/seq"
    exit 1
fi

# Check if files exist
if [ ! -f "$BEDFILE" ]; then
    echo "Error: BED file $BEDFILE not found"
    exit 1
fi

if [ ! -f "$SAMPLES_FILE" ]; then
    echo "Error: Samples file $SAMPLES_FILE not found"
    exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Input directory $INPUT_DIR not found"
    exit 1
fi

if [ ! -f "$MODEL_PATH" ]; then
    echo "Error: Model file $MODEL_PATH not found"
    exit 1
fi

if [ ! -d "$SEQ_PATH" ]; then
    echo "Error: Sequence directory $SEQ_PATH not found"
    exit 1
fi

# Record overall start time
overall_start_time=$(date +%s)

echo "Starting multi-sample genetic screening pipeline"
echo "BED file: $BEDFILE"
echo "Samples file: $SAMPLES_FILE"
echo "Input directory: $INPUT_DIR"
echo "Model path: $MODEL_PATH"
echo "Sequence path: $SEQ_PATH"

# Create main output directory
BEDFILE_BASENAME=$(basename "$BEDFILE" .bed)
SAMPLES_BASENAME=$(basename "$SAMPLES_FILE" .txt)
MAIN_OUTDIR="results_${BEDFILE_BASENAME}_${SAMPLES_BASENAME}"
mkdir -p "$MAIN_OUTDIR"

# Create log directories
mkdir -p "logs-multi_sample_scheduler"

# Create timing log file
echo "Sample,Start Time,End Time,Duration (seconds),Status" > "${MAIN_OUTDIR}/sample_timing.csv"

# Count actual samples (excluding comments and empty lines)
total_samples=$(grep -v '^[[:space:]]*#' "$SAMPLES_FILE" | grep -v '^[[:space:]]*$' | wc -l)
echo "Total samples to process: $total_samples"

# Process each sample
sample_count=0

while IFS= read -r sample_name; do
    # Skip empty lines and comments
    [[ -z "$sample_name" || "$sample_name" =~ ^[[:space:]]*# ]] && continue
    
    # Check if sample was already completed
    SAMPLE_OUTDIR="${MAIN_OUTDIR}/${sample_name}"
    if [ -d "$SAMPLE_OUTDIR" ] && [ -f "${SAMPLE_OUTDIR}/compiled_impact_scores.bedgraph" ]; then
        echo "Sample $sample_name already completed. Skipping to next sample."
        echo "${sample_name},$(date +%s),$(date +%s),0,SKIPPED_ALREADY_COMPLETED" >> "${MAIN_OUTDIR}/sample_timing.csv"
        continue
    fi
    
    sample_count=$((sample_count + 1))
    echo "Processing sample $sample_count/$total_samples: $sample_name"
    
    # Record sample start time
    sample_start_time=$(date +%s)
    
    # Set sample-specific paths
    CTCF_PATH="${INPUT_DIR}/${sample_name}.dd-maxATAC-predict/maxatac_predict.bw"
    ATAC_PATH="${INPUT_DIR}/${sample_name}.dd-maxATAC_prepare/${sample_name}.dd_IS_slop20_RP20M_minmax01.bw"
    
    # Check if sample files exist
    if [ ! -f "$CTCF_PATH" ]; then
        echo "Warning: CTCF file not found for sample $sample_name: $CTCF_PATH"
        sample_end_time=$(date +%s)
        sample_duration=$((sample_end_time - sample_start_time))
        echo "${sample_name},${sample_start_time},${sample_end_time},${sample_duration},SKIPPED_CTCF_MISSING" >> "${MAIN_OUTDIR}/sample_timing.csv"
        continue
    fi
    
    if [ ! -f "$ATAC_PATH" ]; then
        echo "Warning: ATAC file not found for sample $sample_name: $ATAC_PATH"
        sample_end_time=$(date +%s)
        sample_duration=$((sample_end_time - sample_start_time))
        echo "${sample_name},${sample_start_time},${sample_end_time},${sample_duration},SKIPPED_ATAC_MISSING" >> "${MAIN_OUTDIR}/sample_timing.csv"
        continue
    fi
    
    # Create sample output directory
    mkdir -p "$SAMPLE_OUTDIR"
    
    # Create log directories with sample_name expanded at generation time
    mkdir -p "${SAMPLE_OUTDIR}/logs-screen_${sample_name}"
    
    # Create sample-specific screen script
    SAMPLE_SCREEN_SCRIPT="${SAMPLE_OUTDIR}/screen_${sample_name}.sh"
    echo "#!/bin/bash" > "$SAMPLE_SCREEN_SCRIPT"
    echo "#SBATCH -J screen_${sample_name}" >> "$SAMPLE_SCREEN_SCRIPT"
    echo "#SBATCH --mem=10gb" >> "$SAMPLE_SCREEN_SCRIPT"
    echo "#SBATCH --partition=gpu4_short,gpu4_medium,gpu8_short,gpu8_medium" >> "$SAMPLE_SCREEN_SCRIPT"
    echo "#SBATCH --output=${SAMPLE_OUTDIR}/logs-screen_${sample_name}/%A.out" >> "$SAMPLE_SCREEN_SCRIPT"
    echo "#SBATCH --error=${SAMPLE_OUTDIR}/logs-screen_${sample_name}/%A.err" >> "$SAMPLE_SCREEN_SCRIPT"
    echo "#SBATCH --time=12:00:00" >> "$SAMPLE_SCREEN_SCRIPT"
    cat >> "$SAMPLE_SCREEN_SCRIPT" << EOF
bedfile=\$1
outdir=\$2
model=${MODEL_PATH}
seq=${SEQ_PATH}
ctcf=${CTCF_PATH}
atac=${ATAC_PATH}

chr=\$(awk "NR==\${SLURM_ARRAY_TASK_ID} {print \\\$1}" \${bedfile})
start=\$(awk "NR==\${SLURM_ARRAY_TASK_ID} {print \\\$2}" \${bedfile})
end=\$(awk "NR==\${SLURM_ARRAY_TASK_ID} {print \\\$3}" \${bedfile})
peak_id=\$(awk "NR==\${SLURM_ARRAY_TASK_ID} {print \\\$4}" \${bedfile})
peak_length=\$((end-start))

source /gpfs/home/rodrij92/home_abl/miniconda3/etc/profile.d/conda.sh
conda activate corigami_ball
sleep 5

corigami-screen --out \${outdir} --celltype \${peak_id} --chr \${chr} --model \${model} --seq \${seq} --ctcf \${ctcf} --atac \${atac} --screen-start \${start} --screen-end \${end} --perturb-width \${peak_length} --step-size \${peak_length} --save-bedgraph --padding zero --save-frames
EOF
    
    chmod +x "$SAMPLE_SCREEN_SCRIPT"
    
    # Run the sample-specific job scheduler
    echo "Starting screening for sample: $sample_name"
    
    # Define batch parameters (previously in job_scheduler script)
    BATCH_SIZE=1000
    MAX_INDEX=2500
    
    # Record sample processing start time
    sample_processing_start_time=$(date +%s)
    
    # Create output directory if it doesn't exist
    mkdir -p "${SAMPLE_OUTDIR}"

    # Create timing log file
    echo "Batch,Start Time,End Time,Duration (seconds)" > "${SAMPLE_OUTDIR}/batch_timing.csv"

    # Split BED file into chunks
    split -l $MAX_INDEX -d $BEDFILE ${SAMPLE_OUTDIR}/bed_chunk_

    for chunk in ${SAMPLE_OUTDIR}/bed_chunk_*; do
        lines=$(wc -l < "$chunk")
        num_batches=$(( (lines + BATCH_SIZE - 1) / BATCH_SIZE ))
        
        for ((i=0; i<num_batches; i++)); do
            # Record batch start time
            batch_start_time=$(date +%s)
            
            start=$((i * BATCH_SIZE + 1))
            end=$(( (i + 1) * BATCH_SIZE ))
            [ "$end" -gt "$lines" ] && end=$lines
            
            # Submit batch job directly from main scheduler (no nested sbatch)
            JOB=$(sbatch --time=12:00:00 --array=${start}-${end} ${SAMPLE_SCREEN_SCRIPT} "$chunk" "${SAMPLE_OUTDIR}" | awk '{print $4}')
            echo "Submitted batch job with ID $JOB for sample ${sample_name}, waiting to complete..."
            sleep 5
            # Wait for job to appear in squeue
            while ! squeue -j $JOB | grep -q $JOB; do
                echo "Waiting for squeue to recognize job $JOB..."
                sleep 2
            done
            # Wait for job to finish (disappear from squeue), but timeout if no running jobs after 20 min (timeout starts after first task runs)
            wait_time=0
            timeout=1200  # 20 minutes
            has_run=0
            while squeue -j $JOB | grep -q $JOB; do
                running_jobs=$(squeue -u $USER -h -o "%i %T" | awk -v jid="$JOB" '$1 ~ ("^"jid"_") && ($2 == "R" || $2 == "RUNNING")' | wc -l)
                if [ $running_jobs -gt 0 ]; then
                    has_run=1
                fi
                if [ $has_run -eq 1 ]; then
                    if [ $running_jobs -eq 0 ] && [ $wait_time -ge $timeout ]; then
                        echo "WARNING: Batch job $JOB has no running jobs after $timeout seconds. Moving to next batch."
                        break
                    fi
                    wait_time=$((wait_time + 10))
                fi
                sleep 10
            done
            
            # Record batch end time and duration
            batch_end_time=$(date +%s)
            batch_duration=$((batch_end_time - batch_start_time))
            
            # Log batch timing
            echo "${chunk}_batch_${i},${batch_start_time},${batch_end_time},${batch_duration}" >> "${SAMPLE_OUTDIR}/batch_timing.csv"
            
            echo "Completed batch ${i} of ${chunk} for sample ${sample_name} in ${batch_duration} seconds"
            sleep 30  # Add delay between batches to reduce SLURM scheduler load
        done
        
        echo "Completed all batches for chunk ${chunk} for sample ${sample_name}"
        sleep 60  # Add delay between chunks to reduce SLURM scheduler load
    done

    # Compile all bedgraph files for this sample into one file and clean up (local execution)
    COMPILED_BEDGRAPH="${SAMPLE_OUTDIR}/compiled_impact_scores.bedgraph"
    echo "Compiling bedgraph files for sample $sample_name..."
    
    # Find and compile bedgraph files
    if find "${SAMPLE_OUTDIR}" -type f -name "*impact_score.bedgraph" > /tmp/found_files_${sample_name}.txt; then
        if [ -s /tmp/found_files_${sample_name}.txt ]; then
            echo "Found $(wc -l < /tmp/found_files_${sample_name}.txt) bedgraph files for sample $sample_name"
            
            # Compile the files
            > "$COMPILED_BEDGRAPH"
            processed_count=0
            while IFS= read -r file; do
                if [ -r "$file" ]; then
                    peak_id=$(echo "$file" | grep -o "PEAK_[0-9]\+")
                    if [ -n "$peak_id" ]; then
                        awk -v peak="$peak_id" '{print $0, peak}' "$file" >> "$COMPILED_BEDGRAPH"
                        processed_count=$((processed_count + 1))
                    fi
                fi
            done < /tmp/found_files_${sample_name}.txt
            
            echo "Successfully compiled $processed_count bedgraph files for sample $sample_name"
            
            # Remove PEAK_* directories
            peaks_removed=$(find "${SAMPLE_OUTDIR}" -type d -name "PEAK_*" | wc -l)
            find "${SAMPLE_OUTDIR}" -type d -name "PEAK_*" -exec rm -rf {} + 2>/dev/null
            echo "Removed $peaks_removed PEAK_* directories for sample $sample_name"
            
            # Clean up temp file
            rm -f /tmp/found_files_${sample_name}.txt
        else
            echo "WARNING: No bedgraph files found for sample $sample_name"
        fi
    else
        echo "WARNING: Could not search for bedgraph files in sample $sample_name"
    fi

    # Record overall end time and calculate total duration
    overall_end_time=$(date +%s)
    total_duration=$((overall_end_time - sample_processing_start_time))

    # Add total duration to timing log
    echo "TOTAL,${sample_processing_start_time},${overall_end_time},${total_duration}" >> "${SAMPLE_OUTDIR}/batch_timing.csv"
    echo "Total execution time for sample ${sample_name}: ${total_duration} seconds"
    
    # Record sample end time and duration
    sample_end_time=$(date +%s)
    sample_duration=$((sample_end_time - sample_start_time))
    
    # Check if sample completed successfully (all batch jobs should have completed by now)
    status="COMPLETED"
    echo "Sample $sample_name completed successfully in ${sample_duration} seconds"
    
    # Log sample timing
    echo "${sample_name},${sample_start_time},${sample_end_time},${sample_duration},${status}" >> "${MAIN_OUTDIR}/sample_timing.csv"
    
    echo "Completed processing sample ${sample_name}. Waiting before next sample..."
    sleep 120  # Add delay between samples to reduce SLURM scheduler load
done < "$SAMPLES_FILE"

# Compile all bedgraphs from all samples into one matrix
echo ""
echo "Compiling all bedgraphs into unified matrix..."
echo "=============================================="

# Check if we have any compiled bedgraph files
if [ -d "$MAIN_OUTDIR" ] && [ "$(find "$MAIN_OUTDIR" -name "compiled_impact_scores.bedgraph" | wc -l)" -gt 0 ]; then
    echo "Found compiled bedgraph files. Creating unified matrix..."
    
    # Run the compilation script
    python3 "$(dirname "$0")/compile_all_bedgraphs.py" \
        --input-dir "$MAIN_OUTDIR" \
        --output-file "${MAIN_OUTDIR}/unified_impact_scores_matrix.tsv"
    
    if [ $? -eq 0 ]; then
        echo "Successfully created unified impact scores matrix!"
        echo "Matrix saved to: ${MAIN_OUTDIR}/unified_impact_scores_matrix.tsv"
    else
        echo "Warning: Failed to create unified matrix. Check the logs above."
    fi
else
    echo "Warning: No compiled bedgraph files found. Skipping matrix compilation."
fi

# Record overall end time and calculate total duration
overall_end_time=$(date +%s)
total_duration=$((overall_end_time - overall_start_time))

# Add total duration to timing log
echo "TOTAL,${overall_start_time},${overall_end_time},${total_duration}" >> "${MAIN_OUTDIR}/sample_timing.csv"

echo ""
echo "Multi-sample screening completed!"
echo "Total execution time: ${total_duration} seconds"
echo "Results saved in: ${MAIN_OUTDIR}"
echo "Sample timing log: ${MAIN_OUTDIR}/sample_timing.csv"
echo "Unified matrix: ${MAIN_OUTDIR}/unified_impact_scores_matrix.tsv" 