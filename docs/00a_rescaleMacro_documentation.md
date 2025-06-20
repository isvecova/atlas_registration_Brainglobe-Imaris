# ImageJ Rescale Macro Documentation (`00a_rescaleMacro.ijm`)

## Overview

This ImageJ macro script automatically processes multiple `.ims` files in a folder by rescaling them to match the voxel size of a target atlas (specifically set for the Perens LSFM mouse atlas at 20 μm/pixel resolution).

## Purpose

The macro serves as the first step in the brain atlas registration pipeline, preparing images for subsequent registration by:
- Converting high-resolution microscopy images to atlas-compatible, isotropic resolution
- Extracting specific channels (typically autofluorescence)

## Parameters

### User-Configurable Parameters

```javascript
// Specify the channel that contains autofluorescence information: 
channel = 2;

// Specify the pixel size of the atlas (20 um/pix for the Perens atlas)
endPixelSize = 20;

// Specify the resolution level to start with (depends on initial resolution and endPixelSize)
resolutionLevel = 3;
```

#### Parameter Details:

1. **`channel`** (integer)
   - **Purpose**: Selects which channel contains the autofluorescence signal needed for registration
   - **Default**: `2`
   - **Considerations**: 
     - Channel 1 is typically the signal of interest (e.g., fluorescent labels)
     - Channel 2 is often autofluorescence, which provides anatomical contrast
     - Verify your channel configuration before running

2. **`endPixelSize`** (float, μm)
   - **Purpose**: Target voxel size to match the atlas resolution
   - **Default**: `20` (for Perens LSFM mouse atlas)
   - **Important**: Must match your target atlas specifications
   - **Other common values**:
     - Allen Mouse Brain Atlas: 10 μm, 25 μm, or 50 μm
     - Custom atlases: Check atlas documentation

3. **`resolutionLevel`** (integer)
   - **Purpose**: Specifies which pyramid level to load from the `.ims` file
   - **Default**: `3`
   - **How to choose**:
     - Higher numbers = lower resolution, faster processing
     - Lower numbers = higher resolution, slower processing
     - Choose based on: `original_resolution × 2^(resolutionLevel-1) ≈ endPixelSize`
     - Example: If original = 2.5 μm and target = 20 μm, use level 3 (2.5 × 2² = 10 μm ≈ 20 μm)

## Input Requirements

### File Format
- **Required**: `.ims` files (Imaris format)
- **Structure**: Multi-resolution pyramid with multiple channels
- **Channels**: At least the specified channel number must exist

### Image Properties
- **Dimensions**: 3D (X, Y, Z) stacks
- **Metadata**: Must contain voxel size information
- **Resolution**: Should have multiple pyramid levels for optimal performance

## Output

### Generated Files
- **Format**: `.tif` (TIFF)
- **Naming**: `processed_[original_name].tif`
- **Location**: Same folder as input files
- **Properties**:
  - Single channel (specified channel only)
  - Isotropic and atlas-matched voxel size

## Usage Guidelines

### Before Running
1. **Verify channel assignment**: Check which channel contains autofluorescence
2. **Confirm atlas specifications**: Ensure `endPixelSize` matches your target atlas
3. **Test resolution level**: Try different levels on a single file first

### After Completion
- Verify output files are created correctly
- Check image properties in ImageJ: `Image → Properties`
- Confirm voxel size matches target (`endPixelSize`)
- Visually inspect a few processed images for quality

## Troubleshooting

### Common Issues

1. **"Could not open file" errors**
   - **Cause**: Corrupted .ims files or insufficient memory
   - **Solution**: Check file integrity, increase ImageJ memory allocation

2. **Wrong voxel size in output**
   - **Cause**: Incorrect `endPixelSize` or missing metadata
   - **Solution**: Verify atlas specifications, check original file metadata

3. **Empty or black images**
   - **Cause**: Wrong channel number or very low signal
   - **Solution**: Check channel contents in original file, adjust channel parameter

4. **Out of memory errors**
   - **Cause**: Large files, insufficient RAM allocation
   - **Solution**: Increase ImageJ memory limit, use higher resolution level

5. **Interpolation artifacts**
   - **Cause**: Extreme scaling ratios
   - **Solution**: Choose appropriate resolution level, consider different interpolation methods


## Integration with Pipeline

### Next Steps
After running this macro:
1. **Quality Check**: Verify processed images in ImageJ or Napari
2. **Registration**: Use processed `.tif` files in Napari with BrainGlobe
3. **Orientation**: Check and correct image orientation before registration

### File Dependencies
- **Input**: Original `.ims` files from microscopy
- **Output**: `processed_*.tif` files for registration pipeline
- **Following step**: Manual registration in Napari (Step 2 of pipeline)

## Technical Notes

### Coordinate System
- ImageJ uses (X, Y, Z) coordinate system
- Scaling preserves spatial relationships
- Maintains original image orientation


## Workflow Details

### Step-by-Step Process:

1. **Folder Selection**
   ```javascript
   folder = getDirectory("Choose folder with .ims files");
   ```
   - User selects input folder containing `.ims` files
   - All `.ims` files in the folder will be processed

2. **File Processing Loop**
   - Iterates through all files in the selected folder
   - Processes only files with `.ims` extension

3. **Image Loading**
   ```javascript
   run("Bio-Formats Importer", 
       "open=[" + filePath + "] " +
       "series_list=" + resolutionLevel + " " +
       "autoscale color_mode=Default view=Hyperstack stack_order=XYCZT quiet");
   ```
   - Uses Bio-Formats to open specific resolution level
   - Maintains original image properties and metadata

4. **Channel Extraction**
   ```javascript
   run("Duplicate...", "title=processed duplicate channels=" + channel);
   ```
   - Duplicates only the specified channel
   - Closes the original multi-channel image to save memory

5. **Rescaling Calculation**
   ```javascript
   getPixelSize(unit, pixelWidth, pixelHeight, voxelDepth);
   rescaleXY = pixelWidth / endPixelSize;
   rescaleZ = voxelDepth / endPixelSize;
   ```
   - Retrieves current voxel dimensions
   - Calculates scaling factors for X, Y, and Z dimensions
   - Handles anisotropic voxels correctly

6. **Image Rescaling**
   ```javascript
   run("Scale...", "x=" + rescaleXY + " y=" + rescaleXY + " z=" + rescaleZ + 
       " interpolation=Bilinear average process create title=rescaled");
   ```
   - **Interpolation**: Bilinear (good balance of speed and quality)
   - **Average**: Maintains intensity relationships during downsampling
   - **Process**: Applies to entire stack
   - **Create**: Generates new image, preserving original

7. **File Saving**
   ```javascript
   originalName = substring(list[i], 0, lengthOf(list[i]) - 4); // Remove ".ims"
   savePath = folder + "processed_" + originalName + ".tif";
   saveAs("Tiff", savePath);
   ```
   - Saves as TIFF format for compatibility
   - Adds "processed_" prefix to distinguish from originals
   - Maintains original filename structure
