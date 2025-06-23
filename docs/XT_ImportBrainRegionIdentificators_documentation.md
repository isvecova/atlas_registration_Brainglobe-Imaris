# Imaris XTension Documentation (`XT_ImportBrainRegionIdentificators.m`)

## Overview

This MATLAB XTension for Imaris automates the import of brain region identifiers and names from BrainGlobe-processed masks. It assigns anatomical labels to surface objects and adds region IDs as custom statistics, enabling brain region analysis within Imaris.

## Purpose

The XTension bridges the gap between BrainGlobe atlas registration and Imaris visualization by assigns anatomical names and IDs to surface objects. 


## Installation

### Prerequisites
- **Imaris Version**: 10.x or later with XTension support (compatibility with earlier versions not verified)
- **MATLAB Integration**: Imaris MATLAB interface enabled, Matlab Runtime installed

### Installation Steps

1. **Locate XTensions Folder** in Preferences - CustomTools - XTension Folders

2. **Copy XTension File**
   ```
   Copy: XT_ImportBrainRegionIdentificators.m
   To: [Imaris XTensions folder]
   ```

3. **Verify Installation**
   - Restart Imaris
   - Check: Image Processing menu → "Brain region identificators import"
   - Check: Surfaces tab → XTension menu → "Brain region identificators import"

### Custom Installation Path
If using a custom XTensions folder:
1. Open Imaris → Preferences → CustomTools
2. Set custom path
3. Copy XTension file to custom location
4. Restart Imaris

## User Interface

### Dialog Sequence

#### Dialog 1: Mask File Selection
```
Title: "Select the brain atlas mask"
Filter: *.tif, *.tiff
Purpose: Select the same mask file used to create surfaces
```

#### Dialog 2: CSV File Selection
```
Title: "Select the csv file containing region IDs and corresponding names"  
Filter: *.csv
Purpose: Select region mapping file from mask processing pipeline
```

## Input Requirements

### 1. Surfaces Object
**Prerequisites**:
- Must be created using "Import → Import Segmentation/Label"
- Must be generated from the same mask file selected in Dialog 1
- Should contain multiple surface objects representing brain regions

**Validation**:
```matlab
if vImarisApplication.GetFactory.IsSurfaces(vSurpassComponent)
    vSurfaces = vImarisApplication.GetFactory.ToSurfaces(vSurpassComponent);
else
    msgbox('Please select a Surface object created from a label image.');
    return;
end
```

### 2. Mask TIFF File
**Required Properties**:
- **Format**: 3D TIFF (single or multi-page)
- **Data Type**: 16-bit integer (uint16)
- **Content**: Labeled regions with unique IDs
- **Dimensions**: Must match surface object dimensions
- **Coordinate System**: Must align with Imaris dataset

**File Examples**:
- `adjusted_mask.tiff` (from mask processing pipeline)
- `registered_atlas_original_orientation.tiff` (original BrainGlobe output - NOT IN 16-BIT FORMAT!)

### 3. CSV Mapping File
**Required Columns**:
```csv
region_id,region_name
1,Isocortex
2,Hippocampal formation
3,Thalamus
```

**Column Specifications**:
- **`region_id`** (integer): Must match IDs in mask file
- **`region_name`** (string): Human-readable anatomical names

**File Examples**:
- `used_region_ids.csv` (from mask processing pipeline)
- Custom mapping files with same format

## Technical Implementation

### Coordinate System Mapping

#### Imaris to Mask Conversion
```matlab
% Get dataset extents
vMinX = 0; vMinY = 0; vMinZ = 0;
vMaxX = vDataSet.GetExtendMaxX();
vMaxY = vDataSet.GetExtendMaxY(); 
vMaxZ = vDataSet.GetExtendMaxZ();

% Get mask dimensions
vSizeX = vMaskSize(2);  % Note: dimensions reordered
vSizeY = vMaskSize(1);  % MATLAB uses (Y,X,Z) order
vSizeZ = vMaskSize(3);
```

#### Coordinate Transformation
Imaris uses physical coordinates (μm), while masks use voxel indices:
```matlab
% Convert surface mask to voxel coordinates
vMaskDataSet = vSurfaces.GetSingleMask(i-1, vMinX, vMinY, vMinZ, 
                                       vMaxX, vMaxY, vMaxZ, 
                                       vSizeX, vSizeY, vSizeZ);
```

### Surface Processing Algorithm

#### 1. Surface Iteration
```matlab
for i = 1:vNumSurfaces
    % Process each surface individually
    vMaskDataSet = vSurfaces.GetSingleMask(i-1, ...);
    vRaw = vMaskDataSet.GetDataVolumeAs1DArrayBytes(0, 0);
    maskIndices = find(uint8(vRaw));
```

#### 2. Coordinate Conversion
```matlab
% Convert linear indices to 3D coordinates
[xx, yy, zz] = ind2sub([vSizeX, vSizeY, vSizeZ], maskIndices);

% Validate coordinates are within mask bounds
validMask = (xx >= 1 & xx <= size(vLabelImage,2) & ...
            yy >= 1 & yy <= size(vLabelImage,1) & ...
            zz >= 1 & zz <= size(vLabelImage,3));
```

#### 3. Sampling Optimization
For large surfaces, the XTension samples a subset of points:
```matlab
maxSampleSize = 5000;  % Adjustable parameter
if length(xx) > maxSampleSize
    sampleIdx = randperm(length(xx), maxSampleSize);
    xx = xx(sampleIdx);
    yy = yy(sampleIdx);
    zz = zz(sampleIdx);
end
```

#### 4. Region ID Detection
```matlab
% Extract region IDs from mask
linearIndices = sub2ind(size(vLabelImage), yy, xx, zz);
labels = vLabelImage(linearIndices);
labels = labels(labels > 0);  % Remove background

% Determine most common region ID
regionId = mode(labels);
```

### Label Assignment

#### Surface Labels
```matlab
vLabel = vImarisApplication.GetFactory.CreateObjectLabel(i-1, "Brain region", regionName);
vDataItem.SetLabel(vLabel);
```
- **Category**: "Brain region"
- **Content**: Human-readable anatomical name
- **Visibility**: Appears in Imaris object browser

#### Statistics Integration
```matlab
vSurfaces.AddStatistics(vNames, vLabelIds, vUnits, vFactors, vFactorNames, vIds);
```
- **Statistic Name**: "Region ID"
- **Values**: Numerical region identifiers
- **Category**: "Surface" 
- **Usage**: Quantitative analysis and filtering

#### Expected Results
- **Surface Labels**: All surfaces should have "Brain region" labels
- **Statistics**: "Region ID" column should appear in Statistics tab
- **Completeness**: Number of labeled surfaces should match input

#### Common Issues and Solutions

##### 1. Misaligned Coordinates
**Symptoms**: 
- Many "Unknown" regions
- Incorrect region assignments
- Empty surface labels

**Causes**:
- Different voxel sizes between mask and dataset
- Coordinate system mismatch
- Incorrect mask file selection

**Solutions**:
- Verify mask and dataset have same voxel size
- Check that mask was used to create surfaces
- Ensure consistent coordinate origins

##### 2. Missing Region Names
**Symptoms**:
- Surfaces labeled as "Unknown"
- Partial labeling success

**Causes**:
- Incomplete CSV file
- ID mismatches between mask and CSV
- CSV formatting errors

**Solutions**:
- Verify all mask IDs are in CSV
- Check CSV column names and format
- Validate region ID consistency

##### 3. Performance Issues
**Symptoms**:
- Very slow processing
- Memory errors
- Imaris becomes unresponsive

**Causes**:
- Too many surfaces (>1000)
- Very large surfaces
- Insufficient system memory

**Solutions**:
- Simplify mask before surface creation
- Increase sampling threshold (`maxSampleSize`)
- Close other applications to free memory

## Integration with Pipeline

### Workflow Position
The XTension is used in Step 4 of the complete pipeline:
1. **ImageJ**: Rescale images → `processed_*.tif`
2. **Napari/BrainGlobe**: Register to atlas → `registered_atlas_original_orientation.tiff`
3. **Python**: Process mask → `adjusted_mask.tiff`, `used_region_ids.csv`
4. **Imaris**: Import mask, run XTension → Labeled surfaces

### File Dependencies
- **Input 1**: Surfaces object (created from mask import)
- **Input 2**: `adjusted_mask.tiff` (same file used for surface creation)
- **Input 3**: `used_region_ids.csv` (from mask processing pipeline)
- **Output**: Labeled surfaces with region statistics

### Subsequent Analysis
After running the XTension:
- **Quantitative Analysis**: Use "Region ID" statistics for measurements
- **Visualization**: Toggle surface visibility by anatomical name
- **Export**: Export labeled scenes for documentation
- **Further Processing**: Use region assignments for custom analysis

## Troubleshooting Guide

### Error Messages and Solutions

#### "Please select a Surface object created from a label image"
- **Cause**: Wrong object type selected
- **Solution**: Select surfaces object in Surpass tree, not other object types

#### "Failed to read TIFF. Ensure it is a 3D label image"
- **Cause**: Corrupted or incompatible TIFF file
- **Solution**: Verify TIFF file integrity, check bit depth (should be 16-bit)

#### "CSV must contain columns: region_id, region_name"
- **Cause**: Incorrect CSV format or column names
- **Solution**: Verify CSV has exact column names (case-insensitive)

#### Processing stuck or very slow
- **Cause**: Too many surfaces or very large surfaces
- **Solution**: Confirm processing with dialog, wait for completion, or simplify mask


## Technical Reference

### MATLAB Interface Functions Used
- `vImarisApplication.GetSurpassSelection()`: Get selected object
- `vImarisApplication.GetFactory.IsSurfaces()`: Validate object type
- `vSurfaces.GetSingleMask()`: Extract surface geometry
- `vSurfaces.GetNumberOfSurfaces()`: Count surfaces
- `vSurfaces.AddStatistics()`: Add custom statistics
- `vImarisApplication.GetFactory.CreateObjectLabel()`: Create labels

### File I/O Functions
- `tiffreadVolume()`: Read 3D TIFF files
- `readtable()`: Parse CSV files
- `uigetfile()`: File selection dialogs

