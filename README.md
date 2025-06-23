# Brain registration and atlas processing using BrainGlobe and Imaris

This repository contains a pipeline for registering Imaris .ims brain images to a BrainGlobe atlas using ImageJ, Napari, BrainGlobe tools, and Imaris. You can use the full pipeline or just selected components - for example, to process a region mask and import it into Imaris with anatomical region names and IDs

**[Detailed Documentation](docs/01_mask_processing_pipeline_documentation.md)** | **[Function Reference](docs/mask_processing_functions_documentation.md)**

You can run the script from the Anaconda Prompt as follows:ne for registering Imaris `.ims` brain images to a BrainGlobe atlas using ImageJ, Napari, BrainGlobe tools, and Imaris. You can use the full pipeline or just selected components, for example, to process a region mask and import it into Imaris with anatomical region names and IDs.

## Documentation

Detailed documentation for all scripts and components is available in the [`docs/`](docs/) directory:

- **[Script Documentation Overview](docs/README.md)** - Complete documentation index
- **[ImageJ Rescale Macro](docs/00a_rescaleMacro_documentation.md)** - Batch image rescaling
- **[ImageJ Batch Macro](docs/00b_rescaleMacroBatch_documentation.md)** - Single file processing  
- **[Mask Processing Pipeline](docs/01_mask_processing_pipeline_documentation.md)** - Python processing workflow
- **[Processing Functions](docs/mask_processing_functions_documentation.md)** - Function reference
- **[Imaris XTension](docs/XT_ImportBrainRegionIdentificators_documentation.md)** - Brain region import

---

## &#x20;Requirements

- [ImageJ / Fiji](https://fiji.sc/) ([Schindelin et al., 2012](https://doi.org/10.1038/nmeth.2019))
- [Miniconda](https://docs.conda.io/en/latest/miniconda.html)
- [Python 3.10+](https://www.python.org/)
- [Napari](https://napari.org/) (napari contributors (2019). napari: a multi-dimensional image viewer for python. [doi:10.5281/zenodo.3555620](https://zenodo.org/record/3555620))
- [BrainGlobe](https://brainglobe.info/) ([Claudi et al., 2021](https://joss.theoj.org/papers/10.21105/joss.02668); [Tyson et al., 2022](https://doi.org/10.1038/s41598-021-04676-9))
- [Imaris](https://imaris.oxinst.com/) (with XTension support)

---

## Installation

### 1. Set up the Python environment

```bash
conda create -n brainglobe_env python=3.10
conda activate brainglobe_env
pip install napari[all]
pip install brainglobe-napari-io brainreg brainrender
```

For more detailed description, follow information on the BrainGlobe webpage: [https://brainglobe.info/documentation/index.html](https://brainglobe.info/documentation/index.html)

### 2. Install the Imaris XTension

Copy the `XT_BrainAtlasLabelImport.py` to your Imaris XTensions folder, such as:

```
C:\Users\<YourUsername>\Documents\Imaris\XTensions
```

(Path to Imaris extension folder can be set in Imaris Preferences.)

Restart Imaris.

## Workflow Overview

1. **Rescale** image to isotropic resolution and voxel size of the atlas using ImageJ
2. **Register** the image to an atlas using Napari + BrainGlobe
3. **Process the mask** with Python script
4. \*\*Import labels and corresponding names and ids \*\*in Imaris

---

## 1. Rescaling (ImageJ / Fiji)

1. Open the macro script (`00a_rescaleMacro.ijm`) in Fiji. Alternatively, if you want to process more files at once, open the batch script option (`00b_rescaleMacroBatch.ijm`)
2. In the macro, adjust parameters if needed.
3. Run the macro.

**[Detailed Documentation](docs/00a_rescaleMacro_documentation.md)** | **[Batch Version](docs/00b_rescaleMacroBatch_documentation.md)**

What the macro does:

- Opens `.ims` file
- Duplicates autofluorescence channel
- Calculates scale to the set selected pixel size in X, Y, Z.
- Rescales and saves as `.tiff`

---

## 2. Registration (manually in Napari + BrainGlobe)

1. Open Napari and drag the `.tiff` image (use 'napari defaults' reader, if asked).
2. Download the atlas if needed via brainrender → *Manage atlas versions*
3. Open **brainreg** plugin
4. Configure:
   - **Atlas**: `perens_lsmf_mouse_20um`
   - **Orientation**: Use *Check Orientation* tool ([docs](https://brainglobe.info/documentation/brainreg/user-guide/checking-orientation.html))
   - **Region**: Full brain or hemisphere
   - **Voxel size**: \~20 µm (check in Fiji: *Image → Properties*)
   - **Save original orientation**: Check this option
   - **Output directory**: Set accordingly
   - Keep other settings default unless optimizing
5. Click **Run**
6. If registration misaligned, try changing *Smoothing sigma* to `0`, and optimize other parameters

---

## 3. Mask Processing (Python script)

1. Open `01_mask_processing_pipeline.py`
2. If needed, adjust parameters, such as the list of regions to flatten.
3. Run the script. 

You can run the script from the Anaconda Prompt as follows:

1. Open the Anaconda Prompt.
2. Activate the BrainGlobe environment:

```bash
conda activate brainglobe_env
```

3. Navigate to the folder containing the script:

```bash
cd path/to/your/script
```

4. Run the script:

```bash
python mask_processing_pipeline.py
```

5. When prompted, select the original mask path.

6. The script will output the processed mask (adjusted\_mask.tiff) in the same folder.

---

## 4. Import and Label in Imaris

**[Detailed Documentation](docs/XT_ImportBrainRegionIdentificators_documentation.md)**

1. Open original `.ims` file
2. Go to:
   ```
   Import → Import Segmentation/Label
   ```
   and select the adjusted mask → This creates new surfaces

   IMPORTANT: The mask cannot be 32-bit, otherwise the loading gets stuck.
3. Select the surfaces object, in **XTension** tab → Run *Brain atlas label import*
4. When prompted, provide:
   - `adjusted_mask.tif` (the adjusted mask that was loaded in the previous step)
   - `used_region_ids.csv` (a CSV file with two columns: `region_id` for the numeric region identifiers and `region_name` for the corresponding anatomical names)&#x20;
5. Wait for label import to finish (may take a few minutes)



## Alternative import to Imaris

In case of big datasets, the import of identifiers can get stuck. In that case, you can use a workaround. Instead of opening the original `.ims` file, you can use the downsampled `.tiff` file directly:

1. Open the downsampled `.tiff` file in Imaris.
   - It will be automatically converted to `.ims` format.
2. Use the same mask import procedure as described above:
   ```
   Import → Import Segmentation/Label
   ```
   - This creates new surfaces.
3. Run the *Brain atlas label import* XTension on the surfaces.
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

---

## Troubleshooting

| Issue                      | Suggestion                                                                                                         |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Registration misaligned    | Check voxel size & orientation in Napari                                                                           |
| Too many objects in Imaris | Filter or simplify mask before import, or adjust the min\_fragment\_size parameter in the mask processing pipeline |
| XTension not visible       | Ensure it's placed in the correct folder & restart Imaris                                                          |



## Author

Iva Švecová, Institute of Experimental Medicine

---

