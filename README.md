# B-ALL Foundation Model: Multi-Sample ATAC-seq Genetic Screening Pipeline

This repository contains a comprehensive pipeline for in-silico genetic screening of ATAC-seq peaks across multiple B-ALL (B-cell Acute Lymphoblastic Leukemia) samples using the CoRIGAMI foundation model.

## 🎯 Project Overview

This project performs genetic screening on **155 B-ALL samples** using:
- **ATAC-seq peaks** from each individual sample
- **CTCF binding data** (log2 fold change)
- **CoRIGAMI foundation model** for chromatin structure prediction
- **Unified peakome** created from all samples with overlap removal

## 📁 Repository Structure

```
├── ISGS/                          # In-Silico Genetic Screening pipeline
│   ├── src/                       # Pipeline scripts
│   │   ├── multi_sample_scheduler.sh    # Main orchestrator
│   │   ├── run_multi_sample_screening.sh # Convenient wrapper
│   │   ├── test_pipeline.sh             # Validation script
│   │   └── test_single_sample.sh        # Single sample test
│   └── README.md                  # Pipeline documentation
├── peaks/                         # Individual sample peak files (see Data Files section)
├── *.py                          # Python analysis scripts
├── samples.txt                   # Sample list for pipeline
└── README.md                     # This file
```

## 📊 Data Files

**⚠️ Important**: Due to GitHub's file size limits, the BED files are not included in this repository. You need to obtain them separately.

### Required BED Files (Not in Repository)
- **Individual Sample Peaks**: 155 GSM files in `peaks/` directory
  - Each file contains ATAC-seq peaks for one sample
  - Format: BED4 (chr, start, end, peak_id)
  - Typical range: 100,000-150,000 peaks per sample
  - Example: `peaks/GSM6481643.peaks.bed` (113,449 peaks)

- **Unified Peakome**: `unified_peakome_1kb_no_overlaps.bed`
  - Created from all 155 samples
  - Contains 191,876 unique peaks after overlap removal
  - Used for screening across all samples

### How to Obtain BED Files
1. **Contact the authors** for access to the BED files
2. **Use the Python scripts** in this repository to generate them:
   ```bash
   # Generate individual peak files from your ATAC-seq data
   python create_unified_peakome.py
   
   # This will create both individual sample peaks and the unified peakome
   ```

### Sample List
- `samples.txt` contains sample names
- One sample per line
- Comments start with `#`

## 🔬 Scientific Background

### B-ALL Foundation Model
The CoRIGAMI foundation model has been trained on B-ALL chromatin structure data and can predict:
- Chromatin accessibility changes
- Transcription factor binding effects
- Regulatory element perturbations

### Multi-Sample Approach
- **155 B-ALL samples** with individual ATAC-seq data
- **Sample-specific genomic features** (CTCF, ATAC bigwigs)
- **Shared model parameters** for consistency
- **Unified peakome** for comprehensive coverage

## 🚀 Quick Start

### 1. Prerequisites
- SLURM cluster access
- CoRIGAMI environment (`conda activate corigami_ball`)
- Access to genomic data files
- **BED files** (see Data Files section above)

### 2. Setup
```bash
# Clone the repository
git clone https://github.com/javrodriguez/ISGS_BALL.git
cd ISGS_BALL

# Obtain the required BED files (see Data Files section)
# Place them in the correct locations:
# - Individual peaks: peaks/GSM*.peaks.bed
# - Unified peakome: unified_peakome_1kb_no_overlaps.bed

# Update paths in the configuration
cd ISGS/src
# Edit run_multi_sample_screening.sh with your paths
```

### 3. Validate Setup
```bash
cd ISGS/src
./test_pipeline.sh
```

### 4. Run Pipeline
```bash
./run_multi_sample_screening.sh
```

## 🔧 Pipeline Components

### Main Scripts
1. **`multi_sample_scheduler.sh`** - Main orchestrator
   - Processes samples sequentially
   - Generates sample-specific scripts
   - Manages HPC resources

2. **`run_multi_sample_screening.sh`** - User-friendly wrapper
   - Path validation
   - User confirmation
   - Job submission

3. **`test_pipeline.sh`** - Validation script
   - Checks file existence
   - Validates sample data
   - Reports readiness status

### Generated Scripts (per sample)
- `screen_<sample>.sh` - Peak-level processing
- `job_scheduler_<sample>.sh` - Batch-level processing

## 🏗️ Pipeline Architecture

```
multi_sample_scheduler.sh (Main)
├── job_scheduler_<sample>.sh (Sample-level)
    ├── screen_<sample>.sh (Peak-level)
        └── corigami-screen (Individual peak)
```

### Resource Management
- **Sequential Processing**: Samples processed one at a time
- **Batch Processing**: 1000 peaks per batch
- **Array Jobs**: SLURM array jobs for parallelization
- **Wait Mechanisms**: Each level waits for completion

## 📈 Expected Output

### Directory Structure
```
screening_results_YYYYMMDD_HHMMSS/
├── sample_timing.csv                    # Overall timing
├── BALL-MCG001/
│   ├── screen_BALL-MCG001.sh           # Sample-specific script
│   ├── job_scheduler_BALL-MCG001.sh    # Sample-specific scheduler
│   ├── batch_timing.csv                # Sample timing
│   └── [CoRIGAMI output files]
├── BALL-MCG002/
│   └── ...
└── logs-*/                              # Log directories
```

### Output Files
- **BedGraph files**: Chromatin accessibility predictions
- **Frame files**: Structural predictions
- **Timing logs**: Performance metrics
- **Status logs**: Success/failure tracking

## ⚙️ Configuration

### Required Paths
Update these in `ISGS/src/run_multi_sample_screening.sh`:
```bash
BEDFILE="../unified_peakome_1kb_no_overlaps.bed"
SAMPLES_FILE="../samples.txt"
INPUT_DIR="/path/to/genomic/data"
MODEL_PATH="/path/to/corigami/model.ckpt"
SEQ_PATH="/path/to/dna/sequence"
```

### Directory Structure
```
<input_dir>/
├── <sample_name>/
│   └── genomic_features/
│       ├── ctcf_log2fc.bw
│       └── atac.bw
```

## 📊 Performance Considerations

### Timing Estimates
- **Per sample**: 4-8 hours (depending on HPC load and ~100-150k peaks per sample)
- **Total time**: 3-4 weeks for 155 samples
- **Storage**: ~200-400GB total output

### Resource Requirements
- **Multi-sample scheduler**: 2GB, gpu4_long/gpu8_long
- **Job scheduler**: 2GB, gpu4_long/gpu8_long
- **Screen jobs**: 10GB, gpu4_short/gpu4_medium/gpu8_short/gpu8_medium

## 🔍 Analysis Scripts

### Python Scripts
- `create_unified_peakome.py` - Creates unified peakome from individual samples
- `analyze_peakome.py` - Analyzes peakome characteristics
- `analyze_overlaps.py` - Analyzes peak overlaps between samples
- `analyze_score_comparability.py` - Compares scores across samples
- `demonstrate_overlap_removal.py` - Demonstrates overlap removal process

## 🐛 Troubleshooting

### Common Issues
1. **Missing BED files**: Ensure you have obtained the required BED files
2. **Missing genomic features**: Check file paths in `samples.txt`
3. **SLURM job failures**: Check log files in `logs-*/` directories
4. **Permission errors**: Ensure scripts are executable (`chmod +x *.sh`)

### Debug Mode
```bash
# Test with single sample
echo "BALL-MCG001" > test_samples.txt
./test_single_sample.sh
```

## 📚 Documentation

- **Pipeline Documentation**: See `ISGS/README.md`
- **Script Documentation**: Inline comments in all scripts
- **Usage Examples**: Provided in test scripts

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

[Add your license information here]

## 👥 Authors

[Add author information here]

## 🙏 Acknowledgments

- CoRIGAMI development team
- B-ALL research community
- HPC cluster support team

---

**For detailed pipeline documentation, see `ISGS/README.md`** 