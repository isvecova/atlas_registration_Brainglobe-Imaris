import tifffile
from brainglobe_atlasapi import BrainGlobeAtlas
from scipy.ndimage import generate_binary_structure
from mask_processing_functions import (
    create_whole_brain_mask,
    flatten_regions,
    flatten_descendants_of_level,
    exclude_regions,
    remove_small_fragments,
    remap_large_values,
    create_label_mapping,
    create_fragment_table
)
from tkinter import Tk
from tkinter.filedialog import askdirectory
import os

# === CONFIGURATION ===
input_mask_filename = "registered_atlas_original_orientation.tiff"
output_mask_filename = "adjusted_mask.tiff"
whole_brain_mask_filename = "whole_brain_mask.tiff"
output_label_csv = "used_region_ids.csv"
output_fragment_csv = "region_fragments_with_sizes.csv"
atlas_name = "perens_lsfm_mouse_20um"
min_fragment_size = 50

# === REGIONS TO MERGE OR EXCLUDE ===
regions_to_flatten = ["fiber tracts", "VS", "CB", "HB", "MB", "TH", "HY", "STR", "PAL", "CTXsp"]
# tracks, ventricular system, ...cerebellum, hidbrain, midbrain, thalamus, hypothalamus, striatum, pallidum, cortical subplate (CTXsp - amygdala, etc) 
# tracks needs to be flattened first before they are excluded 
regions_to_flatten_on_level_1 = ["Isocortex", "OLF"]
# isocortex, olfactory areas - keep their first level descendants
regions_to_exclude = ["fiber tracts", "root"]
# tracks mask is very thin in some parts -> Imaris segments it into many disconnected fragments; root is a parent region that does not really give any information
# these regions will be set to 0 in the final mask

# === STEP 0: Prompt user to select folder with dataset ===
path = askdirectory(title='Select Folder') # shows dialog box and return the path
if not path:
    print("No folder selected. Exiting.")   # If user cancels the dialog, do not do anything
    exit(1)

print(f"Using the following path: {path}") 
os.chdir(path)  # Change current working directory to the selected path


# === STEP 1: Load ===
print("Loading mask and atlas...")
atlas = BrainGlobeAtlas(atlas_name)
mask = tifffile.imread(input_mask_filename)


# === STEP 2: Create overall mask for the whole brain ===
print("Creating overall mask for the whole brain...")
whole_brain_mask = create_whole_brain_mask(mask)

# === STEP 3: Simplify Mask ===
print("Simplifying mask...")
# Flatten specified regions
simplified_mask = flatten_regions(mask, atlas, regions_to_flatten)
# Flatten children of listed parent regions
simplified_mask = flatten_descendants_of_level(simplified_mask, atlas, regions_to_flatten_on_level_1, level=1)
simplified_mask = exclude_regions(simplified_mask, atlas, regions_to_exclude)

# === STEP 4: Remove Small Fragments ===
print("Removing small fragments...")
structure = generate_binary_structure(rank=3, connectivity=1)   # Using connectivity 1, because otherwise, objects were further segmented in Imaris
cleaned_mask, fragment_info = remove_small_fragments(simplified_mask, min_fragment_size, structure, atlas)

# === STEP 5: Remap Large IDs ===
print("Remapping large IDs if necessary...")
adjusted_mask, id_remap, new_id_to_old_id = remap_large_values(cleaned_mask)

# === STEP 6: Save Adjusted Mask ===
print(f"Saving adjusted mask to {output_mask_filename}")
tifffile.imwrite(output_mask_filename, adjusted_mask.astype("uint16"))

# === STEP 7: Save whole brain mask ===
print(f"Saving whole brain mask to {whole_brain_mask_filename}")
tifffile.imwrite(whole_brain_mask_filename, whole_brain_mask.astype("uint8"))

# === STEP 8: Save Label Mapping CSV ===
print(f"Saving region label mapping to {output_label_csv}")
df_labels = create_label_mapping(adjusted_mask, atlas, new_id_to_old_id)
df_labels.to_csv(output_label_csv, index=False)

# === STEP 9: Save Fragment Information ===
print(f"Saving fragment details to {output_fragment_csv}")
df_fragments = create_fragment_table(fragment_info)
df_fragments.to_csv(output_fragment_csv, index=False)

print("Done.")
