# Mask Processing Functions Documentation (`mask_processing_functions.py`)

## Overview
This module provides the core functionality for the brain atlas mask processing pipeline. It contains functions for brain region manipulation, fragment analysis, and data export that support the main processing pipeline. 

**These functions are not meant to be executed independently.** They are designed to be called from the `01_mask_processing_pipeline.py` script, which orchestrates the entire workflow.

## Function Reference

### 1. `create_whole_brain_mask(mask)`

Creates a binary mask representing the entire brain region.

#### Parameters
- **`mask`** (numpy.ndarray): Input labeled mask with region IDs

#### Returns
- **`whole_brain_mask`** (numpy.ndarray): Binary mask (uint16) where 1 = brain tissue, 0 = background

#### Purpose
- Quality control visualization
- Brain boundary definition
- Registration validation

#### Implementation
```python
def create_whole_brain_mask(mask):
    whole_brain_mask = np.zeros_like(mask, dtype=np.uint16)
    whole_brain_mask[mask > 0] = 1
    return whole_brain_mask
```

#### Usage Example
```python
brain_outline = create_whole_brain_mask(registered_mask)
# Result: Binary mask showing overall brain shape
```

---

### 2. `get_descendants_of_depth(tree, parent_node_id, selected_depth=1)`

Retrieves brain region descendants at a specific hierarchical depth.

#### Parameters
- **`tree`** (treelib.Tree): Atlas region hierarchy tree
- **`parent_node_id`** (int): ID of parent region
- **`selected_depth`** (int): Target depth level (1 = direct children, 2 = grandchildren, etc.)

#### Returns
- **`descendants`** (list): List of region acronyms at specified depth

#### Purpose
- Precise hierarchy navigation
- Selective region flattening
- Anatomical grouping control

#### Algorithm
```python
def recurse(node_id, current_depth):
    children = tree.children(node_id)
    for child in children:
        if current_depth == selected_depth:
            descendants.append(acronym)  # Collect at target depth
        else:
            recurse(child.identifier, current_depth + 1)  # Go deeper
```

#### Usage Example
```python
# Get all primary cortical areas (depth 1 under Isocortex)
primary_areas = get_descendants_of_depth(atlas.structures.tree, 
                                        isocortex_id, selected_depth=1)
# Result: ['VIS', 'AUD', 'MOp', 'MOs', ...] (primary visual, auditory, motor, etc.)
```

#### Depth Level Examples
- **Depth 1**: Primary divisions (e.g., VIS, AUD, MOp)
- **Depth 2**: Secondary areas (e.g., VISp, VISal, VISam)
- **Depth 3**: Layer-specific regions (e.g., VISp1, VISp2/3, VISp4)

---

### 3. `flatten_regions(mask, atlas, region_acronyms)`

Completely flattens specified brain regions by merging all descendants into parent regions.

#### Parameters
- **`mask`** (numpy.ndarray): Input labeled mask
- **`atlas`** (BrainGlobeAtlas): Atlas object with region information
- **`region_acronyms`** (list): List of region acronyms to flatten

#### Returns
- **`simplified_mask`** (numpy.ndarray): Modified mask with flattened regions

#### Process
1. For each region in `region_acronyms`:
   - Get parent region ID
   - Find all descendant regions
   - Replace all descendant IDs with parent ID

#### Implementation Details
```python
for region_name in region_acronyms:
    region_id = atlas.structures[region_name]["id"]
    areas_to_merge = atlas.get_structure_descendants(region_name)
    for area_code in areas_to_merge:
        sub_id = atlas.structures[area_code]["id"]
        simplified_mask[simplified_mask == sub_id] = region_id
```

#### Usage Example
```python
# Flatten cerebellum: merge all cerebellar nuclei, cortical layers, etc.
flattened = flatten_regions(mask, atlas, ["CB"])
# Result: All cerebellar subregions become single "CB" region
```

#### Before/After Example
- **Before**: CB_cortex_1, CB_cortex_2, CB_nuclei_fastigial, CB_nuclei_interposed, ...
- **After**: CB, CB, CB, CB, ...

---

### 4. `flatten_descendants_of_level(mask, atlas, region_acronyms, level=1)`

Selectively flattens brain regions while preserving specific hierarchical levels.

#### Parameters
- **`mask`** (numpy.ndarray): Input labeled mask
- **`atlas`** (BrainGlobeAtlas): Atlas object
- **`region_acronyms`** (list): Parent regions to process
- **`level`** (int): Hierarchical level to preserve (≥1)

#### Returns
- **`simplified_mask`** (numpy.ndarray): Modified mask with selective flattening

#### Process
1. For each parent region:
   - Find descendants at specified level
   - For each level-descendant:
     - Merge its sub-descendants into itself
   - Preserve the level-descendants as separate regions

#### Algorithm Flow
```python
for region_name in region_acronyms:
    # Get regions to keep at specified level
    areas_to_keep = get_descendants_of_depth(atlas.structures.tree, region_id, level)
    
    for kept_area in areas_to_keep:
        # Merge sub-descendants into kept area
        areas_to_merge = atlas.get_structure_descendants(kept_area)
        for sub_area in areas_to_merge:
            simplified_mask[simplified_mask == sub_area_id] = kept_area_id
```

#### Usage Examples

**Example 1: Cortical Areas (Level 1)**
```python
# Input: ["Isocortex"], level=1
# Preserves: VIS, AUD, MOp, MOs, SSp, SSs, etc.
# Merges: All layer-specific subdivisions into primary areas
flattened = flatten_descendants_of_level(mask, atlas, ["Isocortex"], level=1)
```

**Example 2: Detailed Cortical Areas (Level 2)**
```python
# Input: ["Isocortex"], level=2  
# Preserves: VISp, VISal, VISam, VISl, VISpm, etc.
# Merges: Layer subdivisions (VISp1, VISp2/3, etc.) into areas
flattened = flatten_descendants_of_level(mask, atlas, ["Isocortex"], level=2)
```

#### Validation
```python
if level < 1:
    raise ValueError("Level must be at least 1.")
```

---

### 5. `exclude_regions(mask, atlas, region_acronyms)`

Removes specified brain regions from the mask by setting their voxels to 0.

#### Parameters
- **`mask`** (numpy.ndarray): Input labeled mask
- **`atlas`** (BrainGlobeAtlas): Atlas object
- **`region_acronyms`** (list): Regions to exclude

#### Returns
- **`modified_mask`** (numpy.ndarray): Mask with excluded regions set to 0

#### Implementation
```python
for region_name in region_acronyms:
    region_id = atlas.structures[region_name]["id"]
    modified_mask[modified_mask == region_id] = 0
```

#### Usage Example
```python
# Remove fiber tracts and root region
clean_mask = exclude_regions(mask, atlas, ["fiber tracts", "root"])
# Result: Specified regions become background (0)
```

#### Common Exclusions
- **"fiber tracts"**: Often fragmented, difficult to visualize
- **"root"**: Non-informative parent category
- **"VS"** (ventricular system): Sometimes excluded if not of interest

---

### 6. `remove_small_fragments(mask, min_size, structure, atlas)`

Removes disconnected tissue fragments smaller than a specified threshold.

#### Parameters
- **`mask`** (numpy.ndarray): Input labeled mask
- **`min_size`** (int): Minimum fragment size in voxels
- **`structure`** (numpy.ndarray): Connectivity structure for scipy.ndimage.label
- **`atlas`** (BrainGlobeAtlas): Atlas for region name lookup

#### Returns
- **`cleaned_mask`** (numpy.ndarray): Mask with small fragments removed
- **`fragment_info`** (list): List of tuples with fragment details

#### Process
1. For each unique region ID:
   - Create binary mask for that region
   - Use connected component analysis to find fragments
   - Remove fragments smaller than `min_size`
   - Record fragment information

#### Implementation Details
```python
for id in region_ids:
    region_mask = (mask == id)
    labeled, _ = label(region_mask, structure=structure)
    component_sizes = np.bincount(labeled.ravel())[1:]
    
    for i, size in enumerate(component_sizes, start=1):
        if size < min_size:
            cleaned_mask[(labeled == i)] = 0  # Remove small fragment
            fragment_info.append((id, region_name, i, size, True))  # Record removal
        else:
            fragment_info.append((id, region_name, i, size, False))  # Record kept
```

#### Connectivity Structures

**Face Connectivity (connectivity=1) - Recommended**
```python
structure = generate_binary_structure(rank=3, connectivity=1)
# Connects only face-adjacent voxels (6-connectivity)
# More conservative, matches Imaris behavior
```

**Full Connectivity (connectivity=2)**
```python
structure = generate_binary_structure(rank=3, connectivity=2)
# Connects face, edge, and corner-adjacent voxels (26-connectivity)
# More aggressive connection, may merge separate structures
```

#### Fragment Information Format
Each tuple in `fragment_info` contains:
- `region_id` (int): Atlas region identifier
- `region_name` (str): Human-readable region name  
- `fragment_index` (int): Fragment number within region
- `fragment_size_voxels` (int): Size in voxels
- `removed` (bool): Whether fragment was removed

#### Usage Example
```python
structure = generate_binary_structure(rank=3, connectivity=1)
cleaned, fragments = remove_small_fragments(mask, min_size=50, 
                                          structure=structure, atlas=atlas)

# Check removed fragments
removed_fragments = [f for f in fragments if f[4] == True]
print(f"Removed {len(removed_fragments)} small fragments")
```

---

### 7. `remap_large_values(mask, max_value=65535)`

Remaps region IDs that exceed the uint16 maximum value to available smaller IDs.

#### Parameters
- **`mask`** (numpy.ndarray): Input labeled mask
- **`max_value`** (int): Maximum allowed ID value (default: 65535 for uint16)

#### Returns
- **`mask`** (numpy.ndarray): Modified mask with remapped IDs
- **`id_remap`** (dict): Mapping from old IDs to new IDs
- **`new_id_to_old_id`** (dict): Reverse mapping for reference

#### Purpose
- **Imaris Compatibility**: Imaris requires 16-bit integer region IDs
- **Atlas Compatibility**: Some atlases have IDs > 65535
- **Data Integrity**: Maintains bijective mapping for traceability

#### Algorithm
```python
# Find problematic IDs
large_ids = all_ids[all_ids > max_value]
used_ids = set(all_ids[all_ids <= max_value])
available_ids = [i for i in range(1, max_value + 1) if i not in used_ids]

# Create mappings
for old_id in large_ids:
    new_id = available_ids.pop(0)
    id_remap[old_id] = new_id
    new_id_to_old_id[new_id] = old_id
    mask[mask == old_id] = new_id
```

#### Error Handling
```python
if not available_ids:
    raise RuntimeError("No available uint16 IDs left to assign.")
```

#### Usage Example
```python
adjusted, old_to_new, new_to_old = remap_large_values(mask)
print(f"Remapped {len(old_to_new)} large IDs")

# Example mappings:
# old_to_new: {70000: 12345, 80000: 12346}
# new_to_old: {12345: 70000, 12346: 80000}
```

---

### 8. `create_label_mapping(mask, atlas, new_id_to_old_id)`

Creates a comprehensive DataFrame mapping region IDs to names and acronyms.

#### Parameters
- **`mask`** (numpy.ndarray): Final processed mask
- **`atlas`** (BrainGlobeAtlas): Atlas object
- **`new_id_to_old_id`** (dict): Reverse ID mapping from remapping step

#### Returns
- **`df_labels`** (pandas.DataFrame): DataFrame with columns: region_id, region_name, region_acronym

#### Process
1. Extract all unique IDs from final mask
2. For each ID:
   - Look up in atlas directly (if ID unchanged)
   - Look up via reverse mapping (if ID was remapped)
   - Use fallback names for unknown IDs

#### Implementation Logic
```python
for region_id in final_ids:
    if region_id == 0:
        continue  # Skip background
        
    if region_id in atlas_id_to_info:
        info = atlas_id_to_info[region_id]  # Direct lookup
    elif region_id in new_id_to_old_id:
        old_id = new_id_to_old_id[region_id]
        info = atlas_id_to_info.get(old_id, fallback)  # Mapped lookup
    else:
        info = fallback  # Unknown ID
```

#### Output Format
| region_id | region_name | region_acronym |
|-----------|-------------|----------------|
| 1 | Isocortex | CTX |
| 2 | Hippocampal formation | HPF |
| 12345 | Thalamus | TH |

#### Usage Example
```python
labels_df = create_label_mapping(final_mask, atlas, new_to_old_mapping)
labels_df.to_csv("region_labels.csv", index=False)
```

---

### 9. `create_fragment_table(fragment_info)`

Converts fragment analysis data into a structured DataFrame for export.

#### Parameters
- **`fragment_info`** (list): List of fragment tuples from `remove_small_fragments`

#### Returns
- **`df_fragments`** (pandas.DataFrame): Structured fragment data

#### Column Definitions
- **`region_id`**: Atlas region identifier
- **`region_name`**: Human-readable region name
- **`fragment_index`**: Fragment number within region (starts at 1)
- **`fragment_size_voxels`**: Size in voxels
- **`removed`**: Boolean indicating if fragment was removed

#### Implementation
```python
def create_fragment_table(fragment_info):
    df = pd.DataFrame(fragment_info, 
                     columns=["region_id", "region_name", "fragment_index", 
                             "fragment_size_voxels", "removed"])
    return df
```

#### Usage for Analysis
```python
fragments_df = create_fragment_table(fragment_data)

# Analyze fragmentation
total_fragments = len(fragments_df)
removed_count = fragments_df['removed'].sum()
avg_size = fragments_df['fragment_size_voxels'].mean()

print(f"Total fragments: {total_fragments}")
print(f"Removed: {removed_count} ({removed_count/total_fragments*100:.1f}%)")
print(f"Average size: {avg_size:.1f} voxels")

# Export for documentation
fragments_df.to_csv("fragment_analysis.csv", index=False)
```

## Module Integration

### Dependency Chain
```
create_whole_brain_mask() ← Independent
get_descendants_of_depth() ← Independent utility
flatten_regions() ← Uses atlas.get_structure_descendants()
flatten_descendants_of_level() ← Uses get_descendants_of_depth()
exclude_regions() ← Independent
remove_small_fragments() ← Uses scipy.ndimage.label
remap_large_values() ← Independent
create_label_mapping() ← Uses atlas and remap results
create_fragment_table() ← Uses fragment_info from remove_small_fragments()
```
