# ImageJ rescale macro documentation (`00a_rescaleMacroBatch.ijm`/`00b_rescaleMacro.ijm`)

## Overview

The `00a_rescaleMacroBatch.ijm` ImageJ macro script automatically processes all `.ims` files in a folder by rescaling them to match the voxel size of a target atlas (by default set for the Perens LSFM mouse atlas at 20 μm/pixel resolution). 
The `00b_rescaleMacro.ijm` script does the same thing, except for processing individual `.ims` file rather than entire folder.

## Purpose

The macro serves as the first step in the brain atlas registration pipeline, preparing images for subsequent registration by:
- Converting high-resolution microscopy images to atlas-compatible, isotropic resolution
- Extracting specific channels (typically autofluorescence)

## Parameters

### User-configurable parameters

```java
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

2. **`endPixelSize`** (float, μm)
   - **Purpose**: Target voxel size to match the atlas resolution and make the image size manageable by BrainGlobe
   - **Default**: `20` (for Perens LSFM mouse atlas)
   - **Other common values**:
     - Allen Mouse Brain Atlas: 10 μm, 25 μm, or 50 μm
     - Custom atlases: Check atlas documentation

3. **`resolutionLevel`** (integer)
   - **Purpose**: Specifies which pyramid level to load from the `.ims` file
   - **Default**: `3`
   - **How to choose**:
     - Make sure that the selected resolution level is available in the dataset.
     - Higher numbers = lower resolution, faster processing
     - Lower numbers = higher resolution, slower processing
     - Choose based on: `original_resolution × 2^(resolutionLevel-1) ≈ endPixelSize`
     - Example: If original = 2.5 μm and target = 20 μm, use level 3 (2.5 × 2² = 10 μm ≈ 20 μm)

## Input requirements

### File Format
- **Required**: `.ims` files (Imaris format)
- **Structure**: Multi-resolution pyramid with multiple channels
- **Channels**: At least the specified channel number must exist

### Image Properties
- **Dimensions**: 3D (X, Y, Z) stacks
- **Metadata**: Must contain voxel size information
- **Resolution**: Should have multiple pyramid levels, has to contain the resolution level indicated by `resolutionLevel` parameter
## Output

### Generated files
- **Format**: `.tif`
- **Naming**: `processed_[original_name].tif`
- **Location**: Same folder as input files
- **Properties**:
  - Single channel (specified channel only)
  - Isotropic and atlas-matched voxel size

## Usage guidelines

### How to run the macro

1. **Prerequisites**:
    - Install [ImageJ](https://imagej.nih.gov/ij/download.html) or [Fiji](https://fiji.sc/) (recommended)
    - Ensure Bio-Formats plugin is installed and working
      - Fiji: Bio-Formats comes pre-installed
      - ImageJ: Install Bio-Formats from [here](https://www.openmicroscopy.org/bio-formats/)

2. **Launch and Run**:
    - Open ImageJ/Fiji
    - Go to `Plugins → Macros → Run...` 
    - Select the `00a_rescaleMacroBatch.ijm` file
    - Follow the folder selection prompt

### Before running
1. **Verify channel assignment**: Check which channel contains autofluorescence
2. **Confirm atlas specifications**: Ensure `endPixelSize` matches your target atlas
3. **Confirm resolution level**: Ensure `resolutionLevel` exists in the image

### After completion
- Verify output files are created correctly
- Check image properties in ImageJ: `Image → Properties`
- Confirm voxel size matches target (`endPixelSize`)
- Visually inspect a few processed images for quality


## Manual process alternative

If you need to rescale images manually instead of using the automated macro, follow these steps:

### Manual rescaling in ImageJ/Fiji

1. **Open the .ims file**:
    - Drag and drop your `.ims` file to ImageJ
    - In the Bio-Formats Import Options dialog, select the appropriate series/resolution level
    - Click OK to open the image

2. **Extract the autofluorescence channel**:
    - Go to `Image → Duplicate...`
    - In the dialog box, check "Duplicate channels" and specify the autofluorescence channel (typically 2)
    - Click "OK" to create a new image with only the selected channel
    - Close the original multi-channel image if not needed

3. **Check current voxel size**:
    - Go to `Image → Properties`
    - Note the current pixel width, height, and voxel depth
    - Record the unit of measurement (usually μm)

4. **Calculate scaling factors**:
    - Divide current pixel width by target pixel size (e.g., 2.5 μm ÷ 20 μm = 0.125)
    - Divide current voxel depth by target pixel size (e.g., 3 μm ÷ 20 μm = 0.15)
    - These are your X/Y and Z scaling factors respectively

5. **Perform the rescaling**:
    - Go to `Image → Scale...`
    - Enter your calculated X, Y scaling factor in respective fields
    - Enter your calculated Z scaling factor
    - Select "Bilinear interpolation"
    - Check "Create new window" and "Scale all slices"
    - Click "OK"

6. **Verify new dimensions**:
    - Go to `Image → Properties`
    - Confirm all dimensions (X, Y, Z) are now at or very close to your target pixel size
    - Adjust if needed

7. **Save the processed image**:
    - Go to `File → Save As → Tiff`
    - Name it with "processed_" prefix followed by original name
    - Save in the same folder as the original for consistency


## Integration with pipeline

### Next steps
After running this macro:
1. **Quality check**: Verify processed images in ImageJ or Napari
2. **Registration**: Use processed `.tif` files in Napari with BrainGlobe

### File Dependencies
- **Input**: Original `.ims` files from microscopy
- **Output**: `processed_*.tif` files for registration pipeline
- **Following step**: Manual registration using BrainGlobe


## Technical notes

### Coordinate system
- The total size of the image in um is preserved, only the voxel size and voxel count changes
- Maintains original image orientation


## Workflow details

### Step-by-Step Process:

1. **Folder selection**
   ```java
   folder = getDirectory("Choose folder with .ims files");
   ```
   - User selects input folder containing `.ims` files
   - All `.ims` files in the folder will be processed

2. **File processing loop**
   - Iterates through all files in the selected folder
   - Processes only files with `.ims` extension

3. **Image loading**
   ```java
   run("Bio-Formats Importer", 
       "open=[" + filePath + "] " +
       "series_list=" + resolutionLevel + " " +
       "autoscale color_mode=Default view=Hyperstack stack_order=XYCZT quiet");
   ```
   - Uses Bio-Formats to open specific resolution level
   - Maintains original image properties and metadata

4. **Channel extraction**
   ```java
   run("Duplicate...", "title=processed duplicate channels=" + channel);
   ```
   - Duplicates only the specified channel
   - Closes the original multi-channel image to save memory

5. **Rescaling calculation**
   ```java
   getPixelSize(unit, pixelWidth, pixelHeight, voxelDepth);
   rescaleXY = pixelWidth / endPixelSize;
   rescaleZ = voxelDepth / endPixelSize;
   ```
   - Retrieves current voxel dimensions
   - Calculates scaling factors for X, Y, and Z dimensions
   - Handles anisotropic voxels correctly

6. **Image rescaling**
   ```java
   run("Scale...", "x=" + rescaleXY + " y=" + rescaleXY + " z=" + rescaleZ + 
       " interpolation=Bilinear average process create title=rescaled");
   ```
   - Rescales the image to match the specified voxel size

7. **File saving**
   ```java
   originalName = substring(list[i], 0, lengthOf(list[i]) - 4); // Remove ".ims"
   savePath = folder + "processed_" + originalName + ".tif";
   saveAs("Tiff", savePath);
   ```
   - Saves as TIFF format for compatibility
   - Adds "processed_" prefix to distinguish from originals
