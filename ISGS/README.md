# Multi-Sample Genetic Screening Pipeline

This pipeline performs in-silico genetic screening of ATAC-seq peaks across multiple samples using the CoRIGAMI tool.

## Overview

The pipeline screens all peaks in `unified_peakome_1kb_no_overlaps.bed` for all samples listed in `samples.txt`. Each sample uses its own genomic features (CTCF and ATAC bigwig files) while sharing the same model and sequence parameters.

## Pipeline Architecture

### 1. **multi_sample_scheduler.sh** (Main Orchestrator)
- Processes samples sequentially to avoid HPC resource limits
- Creates sample-specific directories and scripts
- Tracks timing for each sample and overall execution
- Handles missing files gracefully

### 2. **job_scheduler.sh** (Sample-level Orchestrator)
- Splits BED file into chunks of 2500 lines
- Processes chunks in batches of 1000 peaks
- Uses SLURM array jobs for parallelization
- Waits for each batch to complete before submitting the next

### 3. **screen.sh** (Individual Peak Processor)
- Processes one peak per SLURM array task
- Runs `corigami-screen` with sample-specific parameters
- Uses peak_id as celltype parameter

## Directory Structure

```
<input_dir>/
├── <sample_name>.dd-maxATAC_prepare/
│   └── <sample_name>.dd_IS_slop20_RP20M_minmax01.bw
└── <sample_name>.dd-maxATAC-predict/
    └── maxatac_predict.bw
```

## Usage

### 1. Prepare Sample List
Create a `samples.txt` file with one sample name per line:
```
# Sample list for genetic screening
BALL-MCG001
BALL-MCG002
BALL-MCG003
# Add more samples...
```

### 2. Test the Pipeline
```bash
cd ISGS/src
./test_pipeline.sh
```

### 3. Run the Full Pipeline
```bash
cd ISGS/src
./run_multi_sample_screening.sh
```

### 4. Manual Execution
```bash
sbatch multi_sample_scheduler.sh \
  unified_peakome_1kb_no_overlaps.bed \
  samples.txt \
  /path/to/input/dir \
  /path/to/model.ckpt \
  /path/to/seq/dir
```

## Configuration

Update paths in `run_multi_sample_screening.sh`:
- `BEDFILE`: Path to the unified peakome BED file
- `SAMPLES_FILE`: Path to the samples list file
- `INPUT_DIR`: Base directory containing sample data
- `MODEL_PATH`: Path to the CoRIGAMI model file
- `SEQ_PATH`: Path to the DNA sequence directory

## Output Structure

```
screening_results_YYYYMMDD_HHMMSS/
├── sample_timing.csv                    # Overall sample timing
├── <sample_name>/
│   ├── batch_timing.csv                 # Sample-specific batch timing
│   ├── screen_<sample_name>.sh          # Sample-specific screen script
│   ├── job_scheduler_<sample_name>.sh   # Sample-specific job scheduler
│   ├── bed_chunk_*                      # BED file chunks
│   └── [CoRIGAMI output files]
└── logs-*/                              # Various log directories
```

## Resource Management

### HPC Resource Limits
- **Sequential Processing**: Samples are processed one at a time to avoid overwhelming the HPC
- **Batch Processing**: Each sample is processed in batches of 1000 peaks
- **Array Jobs**: Uses SLURM array jobs for parallel peak processing
- **Wait Mechanisms**: Each level waits for completion before proceeding

### Memory and Partition Requirements
- **Multi-sample scheduler**: 2GB, gpu4_long/gpu8_long
- **Job scheduler**: 2GB, gpu4_long/gpu8_long  
- **Screen jobs**: 10GB, gpu4_short/gpu4_medium/gpu8_short/gpu8_medium

## Monitoring

### Job Status
```bash
squeue -u $USER
```

### Sample Progress
Check the sample timing log:
```bash
tail -f screening_results_*/sample_timing.csv
```

### Individual Sample Progress
```bash
tail -f screening_results_*/<sample_name>/batch_timing.csv
```

## Error Handling

### Missing Files
- CTCF or ATAC files not found: Sample is skipped and logged
- Missing input files: Pipeline exits with error message

### Job Failures
- Failed samples are marked as "FAILED" in timing log
- Pipeline continues with remaining samples
- Detailed logs available in sample-specific directories

## Performance Considerations

### Timing
- Each sample processes ~100-150,000 peaks (based on unified_peakome_1kb_no_overlaps.bed)
- Estimated time per sample: 4-8 hours (depending on HPC load)
- Total time for 155 samples: ~3-4 weeks

### Storage
- Each sample generates ~2-4GB of output
- Total storage requirement: ~200-400GB for 155 samples

## Troubleshooting

### Common Issues

1. **Missing genomic features**
   - Check file paths in `samples.txt`
   - Verify directory structure matches expected format

2. **SLURM job failures**
   - Check log files in `logs-*/` directories
   - Verify partition and memory requirements

3. **Permission errors**
   - Ensure all scripts are executable: `chmod +x *.sh`
   - Check write permissions for output directories

### Debug Mode
Run with a single sample first:
```bash
echo "BALL-MCG001" > test_samples.txt
sbatch multi_sample_scheduler.sh unified_peakome_1kb_no_overlaps.bed test_samples.txt /path/to/input /path/to/model /path/to/seq
```

## Files

- `multi_sample_scheduler.sh`: Main pipeline orchestrator
- `job_scheduler.sh`: Original single-sample scheduler
- `screen.sh`: Individual peak processing script
- `run_screening_timed.sh`: Chunk processing with timing
- `run_multi_sample_screening.sh`: Convenient wrapper script
- `test_pipeline.sh`: Pipeline validation script
- `samples.txt`: Sample list template 