# Imaris XTension Documentation (`XT_ImportBrainRegionIdentificators.m`)

## Overview

This MATLAB XTension for Imaris automates the import of brain region identifiers and names from BrainGlobe-processed masks. It assigns anatomical labels to surface objects and adds region IDs as custom statistics, enabling brain region analysis within Imaris.

## Purpose

The XTension bridges the gap between BrainGlobe atlas registration and Imaris visualization by assigns anatomical names and IDs to surface objects. 


## Installation

### Prerequisites
- **Imaris version**: 10.x or later with XTension support (tested on 10.2, compatibility with earlier versions not verified)
- **MATLAB integration**: Imaris MATLAB interface enabled, Matlab Runtime installed

### Installation steps

1. **Locate XTensions folder** in Preferences - CustomTools - XTension Folders

2. **Copy XTension file**
   ```
   Copy: XT_ImportBrainRegionIdentificators.m
   To: [Imaris XTensions folder]
   ```

3. **Verify installation**
   - Restart Imaris
   - Check: Image Processing menu → "Brain region identificators import"
   - Check: Surfaces tab → XTension menu → "Brain region identificators import"

### Custom installation path
If using a custom XTensions folder:
1. Open Imaris → Preferences → CustomTools
2. Set custom path
3. Copy XTension file to custom location
4. Restart Imaris

## Usage guidelines
1. Open original `.ims` file
2. Go to:
   ```
   Import → Import Segmentation/Label
   ```
   and select the adjusted mask → This creates new surfaces

   IMPORTANT: The mask cannot be 32-bit, otherwise the loading gets stuck.
3. Select the surfaces object, in **XTension** tab → Run *Brain region identificators import*
4. When prompted, provide:
   - `adjusted_mask.tif` (the adjusted mask that was loaded in the previous step)
   - `used_region_ids.csv` (a CSV file with two columns: `region_id` for the numeric region identifiers and `region_name` for the corresponding anatomical names)&#x20;
5. Wait for label import to finish (may take a few minutes)

### Alternative import to Imaris

In case of big datasets, the import of identifiers can get stuck. In that case, you can use a workaround. Instead of opening the original `.ims` file, you can use the downsampled `.tiff` file directly:

1. Open the downsampled `.tiff` file in Imaris.
   - It will be automatically converted to `.ims` format.
2. Use the same mask import procedure as described above:
   ```
   Import → Import Segmentation/Label
   ```
   - This creates new surfaces.
3. Run the *Brain region identificators import* XTension on the surfaces.
4. When prompted, provide:
   - `adjusted_mask.tif`
   - `used_region_ids.csv`
5. Once the labels are imported, export the scene via:
   ```
   File → Export Scene
   ```
6. Open the original `.ims` file.
7. Import the previously exported scene using:
   ```
   File → Import Scene → Add to existing objects
   ```
8. Important: Before importing, make sure the voxel origin of the image (minimum µm) is set to **0** in all dimensions. Otherwise, the imported surfaces may be shifted.

This approach is useful if you want to work with a smaller image first and transfer results back to the full-resolution dataset.

## Input requirements

### 1. Surfaces object
**Prerequisites**:
- Must be created using "Import → Import Segmentation/Label"
- Must be generated from the same mask file selected in Dialog 1
- Should contain multiple surface objects representing brain regions


### 2. Mask TIFF file
**Required properties**:
- **Format**: 3D TIFF (single or multi-page)
- **Data type**: 16-bit integer (uint16)
- **Content**: Labeled regions with unique IDs
- **Dimensions**: Must match surface object dimensions
- **Coordinate system**: Must align with Imaris dataset

**File examples**:
- `adjusted_mask.tiff` (from mask processing pipeline)
- `registered_atlas_original_orientation.tiff` (original BrainGlobe output - NOT IN 16-BIT FORMAT!)

### 3. CSV mapping file
**Required columns**:
```csv
region_id,region_name
1,Isocortex
2,Hippocampal formation
3,Thalamus
```

**Column specifications**:
- **`region_id`** (integer): Must match IDs in mask file
- **`region_name`** (string): Human-readable anatomical names

**File examples**:
- `used_region_ids.csv` (from mask processing pipeline)
- Custom mapping files with same format


## Integration with pipeline

### Workflow position
The XTension is used in step 3 of the pipeline:
1. **ImageJ**: Rescale images → `processed_*.tif`
    
    **Napari/BrainGlobe**: Register to atlas → `registered_atlas_original_orientation.tiff`
2. **Python**: Process mask → `adjusted_mask.tiff`, `used_region_ids.csv`
3. **Imaris**: Import mask, run XTension → Labeled surfaces

### File dependencies
- **Input 1**: Surfaces object (created from mask import)
- **Input 2**: `adjusted_mask.tiff` (same file used for surface creation)
- **Input 3**: `used_region_ids.csv` (from mask processing pipeline)
- **Output**: Labeled surfaces with region statistics

## Detailed script description

### Coordinate system mapping

#### Imaris to mask conversion
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

#### Coordinate transformation
Imaris uses physical coordinates (μm), while masks use voxel indices:
```matlab
% Convert surface mask to voxel coordinates
vMaskDataSet = vSurfaces.GetSingleMask(i-1, vMinX, vMinY, vMinZ, 
                                       vMaxX, vMaxY, vMaxZ, 
                                       vSizeX, vSizeY, vSizeZ);
```

### Surface processing algorithm

#### 1. Surface iteration
```matlab
for i = 1:vNumSurfaces
    % Process each surface individually
    vMaskDataSet = vSurfaces.GetSingleMask(i-1, ...);
    vRaw = vMaskDataSet.GetDataVolumeAs1DArrayBytes(0, 0);
    maskIndices = find(uint8(vRaw));
```

#### 2. Coordinate conversion
```matlab
% Convert linear indices to 3D coordinates
[xx, yy, zz] = ind2sub([vSizeX, vSizeY, vSizeZ], maskIndices);

% Validate coordinates are within mask bounds
validMask = (xx >= 1 & xx <= size(vLabelImage,2) & ...
            yy >= 1 & yy <= size(vLabelImage,1) & ...
            zz >= 1 & zz <= size(vLabelImage,3));
```

#### 3. Sampling optimization
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

#### 4. Region ID detection
```matlab
% Extract region IDs from mask
linearIndices = sub2ind(size(vLabelImage), yy, xx, zz);
labels = vLabelImage(linearIndices);
labels = labels(labels > 0);  % Remove background

% Determine most common region ID
regionId = mode(labels);
```

### Label assignment

#### Surface labels
```matlab
vLabel = vImarisApplication.GetFactory.CreateObjectLabel(i-1, "Brain region", regionName);
vDataItem.SetLabel(vLabel);
```
- **Category**: "Brain region"
- **Content**: Human-readable anatomical name
- **Visibility**: Appears in Imaris object browser

#### Statistics integration
```matlab
vSurfaces.AddStatistics(vNames, vLabelIds, vUnits, vFactors, vFactorNames, vIds);
```
- **Statistic Name**: "Region ID"
- **Values**: Numerical region identifiers
- **Category**: "Surface" 
- **Usage**: Quantitative analysis and filtering

#### Expected results
- **Surface labels**: All surfaces should have "Brain region" labels
- **Statistics**: "Region ID" column should appear in Statistics tab
- **Completeness**: Number of labeled surfaces should match input


### MATLAB interface functions used
- `vImarisApplication.GetSurpassSelection()`: Get selected object
- `vImarisApplication.GetFactory.IsSurfaces()`: Validate object type
- `vSurfaces.GetSingleMask()`: Extract surface geometry
- `vSurfaces.GetNumberOfSurfaces()`: Count surfaces
- `vSurfaces.AddStatistics()`: Add custom statistics
- `vImarisApplication.GetFactory.CreateObjectLabel()`: Create labels

### File I/O functions
- `tiffreadVolume()`: Read 3D TIFF files
- `readtable()`: Parse CSV files
- `uigetfile()`: File selection dialogs

