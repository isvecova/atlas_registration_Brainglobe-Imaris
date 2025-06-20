# Brain Atlas Registration Documentation

This directory contains detailed documentation for all scripts and components in the Brain Atlas Registration pipeline using BrainGlobe and Imaris.

## Documentation Structure

### Script Documentation

- **[ImageJ Rescale Macro](00a_rescaleMacro_documentation.md)** (`00a_rescaleMacro.ijm`)
  - Batch processing of multiple `.ims` files
  - Automated rescaling to atlas resolution
  - Parameter configuration and optimization

- **[ImageJ Batch Rescale Macro](00b_rescaleMacroBatch_documentation.md)** (`00b_rescaleMacroBatch.ijm`)
  - Single file processing workflow
  - Parameter testing and validation
  - Quality control procedures

- **[Mask Processing Pipeline](01_mask_processing_pipeline_documentation.md)** (`01_mask_processing_pipeline.py`)
  - Complete mask processing workflow
  - Region simplification and cleanup
  - Output file generation and validation

- **[Mask Processing Functions](mask_processing_functions_documentation.md)** (`mask_processing_functions.py`)
  - Detailed function reference
  - Implementation details and algorithms
  - Usage examples and best practices

- **[Imaris XTension](XT_ImportBrainRegionIdentificators_documentation.md)** (`XT_ImportBrainRegionIdentificators.m`)
  - Brain region label import for Imaris
  - Installation and configuration
  - Troubleshooting and optimization

## Quick Reference

### Pipeline Overview
1. **Rescaling** (ImageJ) → Convert images to atlas resolution
2. **Registration** (Napari/BrainGlobe) → Align images to atlas
3. **Processing** (Python) → Simplify and clean masks
4. **Visualization** (Imaris) → Import and label brain regions

### Key File Formats
- **Input**: `.ims` files (Imaris format)
- **Intermediate**: `.tiff` files (ImageJ/Napari compatible)
- **Output**: Processed masks, CSV mappings, Imaris surfaces

### Configuration Files
- **Atlas**: `perens_lsfm_mouse_20um` (default)
- **Pixel size**: 20 μm (configurable)
- **Fragment threshold**: 50 voxels (adjustable)


---

*Last updated: 20.6.2025*
*Pipeline version: Current*
*Documentation maintained by: Iva Švecová*
