# Brain Atlas Registration Documentation

This directory contains detailed documentation for all scripts and components in the Brain Atlas Registration pipeline using BrainGlobe and Imaris.

## Documentation Structure

### Script Documentation

- **[ImageJ Rescale Macro](00_rescaleMacro_documentation.md)** (`00a_rescaleMacroBatch.ijm`/`00b_rescaleMacro.ijm`)
  - Batch processing of multiple `.ims` files (`00a_rescaleMacroBatch.ijm`) or single file (`00b_rescaleMacro.ijm`)
  - Automated rescaling to atlas resolution
  - Parameter configuration and optimization

- **[Mask Processing Pipeline](01_mask_processing_pipeline_documentation.md)** (`01_mask_processing_pipeline.py`)
  - Complete mask processing workflow
  - Region simplification and cleanup
  - Output file generation and validation

- **[Mask Processing Functions](mask_processing_functions_documentation.md)** (`mask_processing_functions.py`)
  - Detailed function reference
  - Implementation details and algorithms

- **[Imaris XTension](XT_ImportBrainRegionIdentificators_documentation.md)** (`XT_ImportBrainRegionIdentificators.m`)
  - Brain region label import for Imaris
  - Installation and configuration

## Quick Reference

### Pipeline Overview
1. **Rescaling** (ImageJ) → Convert images to atlas resolution
  **Registration** (Napari/BrainGlobe) → Align images to atlas
2. **Mask rocessing** (Python) → Simplify and clean masks
3. **Imaris import and visualization** (Imaris) → Import and label brain regions

### Key File Formats
- **Input**: `.ims` files (Imaris format)
- **Intermediate**: `.tiff` files (ImageJ/Napari compatible)
- **Output**: Processed masks, CSV mappings, Imaris surfaces

---

*Last updated: 20.6.2025*
*Pipeline version: Current*
*Documentation maintained by: Iva Švecová*
