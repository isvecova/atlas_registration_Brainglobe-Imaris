import numpy as np
import pandas as pd
from scipy.ndimage import label


def create_whole_brain_mask(mask):
    # Create an overall mask for the whole brain by setting all non-zero regions in the mask to 1.
    # Returns a binary mask where all non-zero regions are set to 1.
    whole_brain_mask = np.zeros_like(mask, dtype=np.uint16)
    whole_brain_mask[mask > 0] = 1
    return whole_brain_mask


def get_descendants_of_depth(tree, parent_node_id, selected_depth=1):
    # Instead of listing all the tiny regions to flatten, I can specify their parents and to which depth I want the details. 
    # Returns a list of acronyms of the descendants at the specified depth.
    descendants = []

    def recurse(node_id, current_depth):
        children = tree.children(node_id)
        for child in children:
            tag = child.tag
            acronym = tag.split(" ")[0]

            if current_depth == selected_depth:
                # append descendants only if we are at the selected depth
                descendants.append(acronym)
            else:
                # if we have not yet reached the selected depth, recurse deeper
                recurse(child.identifier, current_depth + 1)

    recurse(parent_node_id, current_depth=1)
    return descendants


def flatten_regions(mask, atlas, region_acronyms):
    # Flatten specified regions in the mask by merging their descendants into the parent region.
    # Returns the modified mask with regions flattened.
    simplified_mask = mask.copy()

    for region_name in region_acronyms:
        region_id = atlas.structures[region_name]["id"]
        areas_to_merge = atlas.get_structure_descendants(region_name)
        for area_code in areas_to_merge:
            sub_id = atlas.structures[area_code]["id"]
            simplified_mask[simplified_mask == sub_id] = region_id

    return simplified_mask


def flatten_descendants_of_level(mask, atlas, region_acronyms, level=1):
    # Flatten specified regions in the mask by merging their descendants at a given level.
    # Returns the modified mask with regions flattened to the specified level.
    if level < 1:
        raise ValueError("Level must be at least 1.")
    simplified_mask = mask.copy()

    for region_name in region_acronyms:
        region_id = atlas.structures[region_name]["id"]
        areas_to_keep = get_descendants_of_depth(atlas.structures.tree, region_id, selected_depth=level)
        for kept_area_code in areas_to_keep:
            kept_id = atlas.structures[kept_area_code]["id"]
            areas_to_merge = atlas.get_structure_descendants(kept_area_code)
            for area_code in areas_to_merge:
                sub_id = atlas.structures[area_code]["id"]
                simplified_mask[simplified_mask == sub_id] = kept_id

    return simplified_mask


def exclude_regions(mask, atlas, region_acronyms):
    # Exclude specified regions from the mask by setting them to 0.
    # Returns the modified mask with specified regions excluded.
    modified_mask = mask.copy()

    for region_name in region_acronyms:
        region_id = atlas.structures[region_name]["id"]
        modified_mask[modified_mask == region_id] = 0

    return modified_mask


def remove_small_fragments(mask, min_size, structure, atlas):
    # Remove small disconnected regions with size less than min_size from the mask - replace them with 0.
    # Returns the cleaned mask and a list of fragment information to be saved in a CSV.
    cleaned_mask = mask.copy()
    region_ids = np.unique(mask)
    region_ids = region_ids[region_ids != 0]
    fragment_info = []
    id_to_name = {s["id"]: s["name"] for s in atlas.structures.values()}

    for id in region_ids:
        region_mask = (mask == id)
        region_name = id_to_name.get(id, f"Unknown ID {id}")
        labeled, _ = label(region_mask, structure=structure)
        component_sizes = np.bincount(labeled.ravel())[1:]
        for i, size in enumerate(component_sizes, start=1): # Starts from 1 because features in scipy-label start from 1
            if size < min_size:
                cleaned_mask[(labeled == i)] = 0
                fragment_info.append((id, region_name, i, size, True))
            else:
                fragment_info.append((id, region_name, i, size, False))

    return cleaned_mask, fragment_info


def remap_large_values(mask, max_value=65535):
    # Remap any values in the mask that exceed max_value to a new ID within the uint16 range.
    # Replaces any large IDs with available IDs in the range 1 to max_value.
    # Returns the remapped mask, a dictionary mapping old IDs to new IDs, and a reverse mapping for name lookup.
    # This is necessary because in the perens atlas, some IDs exceed the uint16 limit.
    all_ids = np.unique(mask)
    large_ids = all_ids[all_ids > max_value]
    used_ids = set(all_ids[all_ids <= max_value])
    available_ids = [i for i in range(1, max_value + 1) if i not in used_ids]

    id_remap = {}
    new_id_to_old_id = {}

    for old_id in large_ids:
        if not available_ids:
            raise RuntimeError("No available uint16 IDs left to assign.")
        new_id = available_ids.pop(0)
        id_remap[old_id] = new_id
        new_id_to_old_id[new_id] = old_id
        mask[mask == old_id] = new_id

    return mask, id_remap, new_id_to_old_id


def create_label_mapping(mask, atlas, new_id_to_old_id):
    # Create a dataframe containing region IDs, names, and acronyms based on the atlas.
    final_ids = np.unique(mask)
    atlas_id_to_info = {s["id"]: {"name": s["name"], "acronym": s["acronym"]} for s in atlas.structures.values()}
    id_to_label = []

    for region_id in final_ids:
        if region_id == 0:
            continue
        if region_id in atlas_id_to_info:
            info = atlas_id_to_info[region_id]
        elif region_id in new_id_to_old_id:
            old_id = new_id_to_old_id[region_id]
            info = atlas_id_to_info.get(old_id, {"name": f"Remapped_{old_id}", "acronym": f"Remapped_{old_id}"})
            # If the id is found in the remap, use the old id's info, otherwise use a default name and acronym
        else:
            info = {"name": f"Unknown_{region_id}", "acronym": f"Unknown_{region_id}"}
        id_to_label.append({"region_id": region_id, "region_name": info["name"], "region_acronym": info["acronym"]})

    return pd.DataFrame(id_to_label)


def create_fragment_table(fragment_info):
    # Convert the fragment information into a DataFrame for export.
    df = pd.DataFrame(fragment_info, columns=["region_id", "region_name", "fragment_index", "fragment_size_voxels", "removed"])
    return df