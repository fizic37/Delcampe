import cv2
import numpy as np
import os

def clean_boundaries(boundaries, min_distance=100):
    """Remove boundaries that are too close together."""
    if not boundaries:
        return []
    boundaries = sorted(set(int(b) for b in boundaries))
    cleaned = [boundaries[0]]
    for b in boundaries[1:]:
        if b - cleaned[-1] >= min_distance:
            cleaned.append(b)
    return cleaned

def detect_rows_by_contour(image, min_area_frac=0.03):  
    """Detect horizontal boundaries using contour analysis."""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (7, 7), 0)
    _, th = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    contours, _ = cv2.findContours(th, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    img_area = image.shape[0] * image.shape[1]
    card_like = [cnt for cnt in contours if cv2.contourArea(cnt) > img_area * min_area_frac]

    print(f"PYTHON DEBUG: Found {len(card_like)} candidate cards")

    boxes = []
    for cnt in card_like:
        x, y, w, h = cv2.boundingRect(cnt)
        boxes.append((y, y + h))  # (top, bottom)

    # Return only the boundary positions (both top and bottom of each box)
    boundaries = [y for y, _ in boxes] + [b for _, b in boxes]
    return boundaries

def detect_grid_layout(image_path):
    """
    Detect grid layout from image and return consistent boundary format.

    Returns:
        dict with:
        - detected_rows: number of detected rows
        - detected_cols: number of detected columns
        - h_boundaries: list of ALL horizontal boundaries (including 0 and height)
        - v_boundaries: list of ALL vertical boundaries (including 0 and width)
        - h_boundaries_internal: list of INTERNAL horizontal boundaries only
        - v_boundaries_internal: list of INTERNAL vertical boundaries only
    """
    import traceback
    import inspect
    print(f"\n{'='*80}")
    print(f"🚨🚨🚨 PYTHON DEBUG: detect_grid_layout() CALLED 🚨🚨🚨")
    print(f"{'='*80}")
    print(f"Image path: {image_path}")
    print(f"Exists: {os.path.exists(image_path)}")
    print(f"\n📍 FULL CALL STACK (with code context):")
    for frame_info in inspect.stack()[1:]:  # Skip this function
        print(f"  File: {frame_info.filename}:{frame_info.lineno}")
        print(f"  Function: {frame_info.function}")
        if frame_info.code_context:
            print(f"  Code: {frame_info.code_context[0].strip()}")
        print()
    print(f"{'='*80}\n")
    
    image = cv2.imread(image_path)
    if image is None:
        return {
            "detected_rows": None,
            "detected_cols": None,
            "h_boundaries": [0],  # Fallback with at least edge boundaries
            "v_boundaries": [0],
            "h_boundaries_internal": [],
            "v_boundaries_internal": [],
            "image_width": None,
            "image_height": None,
            "info": "Could not read image.",
            "error": "Could not read image."
        }
    
    height, width = image.shape[:2]
    
    # Get internal row boundaries using contour detection
    internal_h_boundaries = detect_rows_by_contour(image)
    
    # Clean internal boundaries to remove those too close to edges or each other
    internal_h_boundaries = [b for b in internal_h_boundaries 
                           if b > height * 0.05 and b < height * 0.95]  # Keep away from edges
    internal_h_boundaries = clean_boundaries(internal_h_boundaries, min_distance=height // 10)
    
    # Remove edge boundaries if they somehow got included
    internal_h_boundaries = [b for b in internal_h_boundaries if b != 0 and b != height]
    
    # For columns, we currently don't have detection logic, so use empty list
    internal_v_boundaries = []
    
    # Construct complete boundary lists (always include edges)
    h_boundaries_complete = sorted(set([0] + internal_h_boundaries + [height]))
    v_boundaries_complete = sorted(set([0] + internal_v_boundaries + [width]))
    
    # Calculate grid dimensions
    detected_rows = len(h_boundaries_complete) - 1
    detected_cols = len(v_boundaries_complete) - 1
    
    print("PYTHON DEBUG: Grid detection results:")
    print(f"  - Internal H boundaries: {internal_h_boundaries}")
    print(f"  - Internal V boundaries: {internal_v_boundaries}")
    print(f"  - Complete H boundaries: {h_boundaries_complete}")
    print(f"  - Complete V boundaries: {v_boundaries_complete}")
    print(f"  - Detected rows: {detected_rows}")
    print(f"  - Detected cols: {detected_cols}")

    return {
        "detected_rows": detected_rows,
        "detected_cols": detected_cols,
        "h_boundaries": h_boundaries_complete,
        "v_boundaries": v_boundaries_complete,
        "h_boundaries_internal": internal_h_boundaries,
        "v_boundaries_internal": internal_v_boundaries,
        "image_width": width,
        "image_height": height,
        "info": f"Detected {detected_rows} rows, {detected_cols} cols by contour bounding boxes.",
        "error": None,
        "debug_info": f"h_boundaries_complete={h_boundaries_complete}, v_boundaries_complete={v_boundaries_complete}"
    }
    
def crop_image_with_boundaries(image_path, h_boundaries, v_boundaries, output_dir):
    """
    Crop an image into sub-images based on horizontal and vertical boundaries.
    ENHANCED WITH EXTENSIVE DEBUGGING

    Args:
        image_path (str): Path to the input image.
        h_boundaries (list of int): Y-coordinates (in pixels) for horizontal cuts, sorted.
        v_boundaries (list of int): X-coordinates (in pixels) for vertical cuts, sorted.
        output_dir (str): Directory where cropped images will be saved.

    Returns:
        dict: {"extracted_paths": list of file paths of cropped images}
    """
    # ULTRA-VISIBLE DEBUG - IF YOU DON'T SEE THIS, WRONG FUNCTION IS BEING CALLED!
    print(f"\n{'#'*80}")
    print(f"### 🐍🐍🐍 CROP_IMAGE_WITH_BOUNDARIES CALLED - VERSION 2025-10-06 ###")
    print(f"### ✅✅✅ THIS IS THE CORRECT FUNCTION! ✅✅✅")
    print(f"{'#'*80}")
    print(f"🐍 Image path: {image_path}")
    print(f"🐍 H boundaries received: {h_boundaries}")
    print(f"🐍 H boundaries type: {type(h_boundaries)}")
    print(f"🐍 V boundaries received: {v_boundaries}")
    print(f"🐍 V boundaries type: {type(v_boundaries)}")
    print(f"🐍 Output dir: {output_dir}")
    print(f"{'#'*80}\n")
    
    # Debug the exact structure of the boundaries
    if hasattr(h_boundaries, '__iter__'):
        print(f"🐍 H boundaries length: {len(h_boundaries)}")
        print(f"🐍 H boundaries items: {list(h_boundaries)}")
        print(f"🐍 H boundaries item types: {[type(x) for x in h_boundaries]}")
    
    if hasattr(v_boundaries, '__iter__'):
        print(f"🐍 V boundaries length: {len(v_boundaries)}")
        print(f"🐍 V boundaries items: {list(v_boundaries)}")
        print(f"🐍 V boundaries item types: {[type(x) for x in v_boundaries]}")
    
    print(f"\n❗❗❗ THESE ARE THE BOUNDARIES FROM R - MUST USE THESE! ❗❗❗\n")
    # Read the image
    image = cv2.imread(image_path)
    if image is None:
        print("🐍❌ ERROR: Could not read image")
        return {"extracted_paths": []}

    img_height, img_width = image.shape[:2]
    print(f"🐍📐 Image dimensions: {img_width}x{img_height}")

    # Ensure the output directory exists
    os.makedirs(output_dir, exist_ok=True)

    # Sort and deduplicate boundaries, ensure they're integers
    # Handle various input formats that might come from R/reticulate
    def convert_boundaries(boundaries):
        if boundaries is None:
            return []
        
        # If it's a single value, wrap it in a list
        if not hasattr(boundaries, '__iter__'):
            boundaries = [boundaries]
        
        # Flatten any nested lists and convert to integers
        flat_boundaries = []
        for item in boundaries:
            if hasattr(item, '__iter__') and not isinstance(item, str):
                flat_boundaries.extend(item)
            else:
                flat_boundaries.append(item)
        
        # Convert to integers and clean
        try:
            int_boundaries = [int(float(x)) for x in flat_boundaries if x is not None]
            return sorted(set(int_boundaries))
        except (ValueError, TypeError) as e:
            print(f"🐍❌ Error converting boundaries: {e}")
            return []
    
    h = convert_boundaries(h_boundaries)
    v = convert_boundaries(v_boundaries)
    
    print(f"🐍🔧 Converted H boundaries: {h}")
    print(f"🐍🔧 Converted V boundaries: {v}")
    
    # CRITICAL: Verify these are the boundaries we'll actually use
    print(f"\n🐍🎯 FINAL BOUNDARIES TO BE USED FOR CROPPING:")
    print(f"🐍🎯 H (vertical cuts): {h}")
    print(f"🐍🎯 V (horizontal cuts): {v}")
    print(f"🐍🎯 These should match the boundaries sent from R!\n")
    
    # Validate boundaries are within image dimensions
    h_valid = [y for y in h if 0 <= y <= img_height]
    v_valid = [x for x in v if 0 <= x <= img_width]
    
    print(f"🐍✅ Valid H boundaries: {h_valid}")
    print(f"🐍✅ Valid V boundaries: {v_valid}")
    
    # Check if we have enough boundaries to create crops
    if len(h_valid) < 2:
        print(f"🐍❌ ERROR: Need at least 2 horizontal boundaries, got {len(h_valid)}")
        return {"extracted_paths": []}
    
    if len(v_valid) < 2:
        print(f"🐍❌ ERROR: Need at least 2 vertical boundaries, got {len(v_valid)}")
        return {"extracted_paths": []}

    extracted_paths = []
    expected_crops = (len(h_valid) - 1) * (len(v_valid) - 1)
    print(f"🐍📊 Expected number of crops: {expected_crops}")

    # Iterate through each grid cell defined by adjacent boundaries
    crop_count = 0
    for i in range(len(h_valid) - 1):
        y0, y1 = h_valid[i], h_valid[i + 1]
        if y1 <= y0:
            print(f"🐍⚠️ Skipping invalid H range: {y0}-{y1}")
            continue
            
        for j in range(len(v_valid) - 1):
            x0, x1 = v_valid[j], v_valid[j + 1]
            if x1 <= x0:
                print(f"🐍⚠️ Skipping invalid V range: {x0}-{x1}")
                continue

            crop_count += 1
            print(f"🐍✂️ Processing crop #{crop_count}: row {i}, col {j}")
            print(f"🐍   Coordinates: x={x0}-{x1}, y={y0}-{y1}")
            print(f"🐍   Dimensions: {x1-x0} x {y1-y0}")

            # Crop the region
            crop = image[y0:y1, x0:x1]
            
            # Validate crop dimensions
            if crop.shape[0] == 0 or crop.shape[1] == 0:
                print(f"🐍❌ Zero-dimension crop at row {i}, col {j}")
                continue

            # Save the cropped image
            filename = f"crop_row{i}_col{j}.jpg"
            out_path = os.path.join(output_dir, filename)
            
            print(f"🐍💾 Saving: {filename}")
            success = cv2.imwrite(out_path, crop)
            if success:
                extracted_paths.append(out_path)
                print(f"🐍✅ SUCCESS: {filename} (dimensions: {crop.shape[1]}x{crop.shape[0]})")
            else:
                print(f"🐍❌ FAILED to save: {filename}")

    print(f"🐍🎉 EXTRACTION COMPLETE:")
    print(f"🐍   Total processed: {crop_count} crops")
    print(f"🐍   Successfully saved: {len(extracted_paths)} images")
    print(f"🐍   Output directory: {output_dir}")
    print(f"🐍   First few paths: {extracted_paths[:3] if extracted_paths else 'None'}")
    
    return {"extracted_paths": extracted_paths}


def combine_face_verso_images(face_dir, verso_dir, output_dir, num_rows, num_cols):
    """
    Create both lot images (by columns) and individual combined images.
    
    Args:
        face_dir (str): Directory containing extracted face images
        verso_dir (str): Directory containing extracted verso images  
        output_dir (str): Directory where combined images will be saved
        num_rows (int): Number of rows in the grid (used as fallback)
        num_cols (int): Number of columns in the grid (used as fallback)
        
    Returns:
        dict: {
            "lot_paths": list of file paths of lot images,
            "combined_paths": list of file paths of individual combined images
        }
    """
    print(f"\nPYTHON DEBUG: combine_face_verso_images called")
    print(f"  - Face dir: {face_dir}")
    print(f"  - Verso dir: {verso_dir}")
    print(f"  - Output dir: {output_dir}")
    print(f"  - Suggested grid: {num_rows}x{num_cols}")
    
    # Verify directories exist
    if not os.path.exists(face_dir) or not os.path.exists(verso_dir):
        print("  - ERROR: Face or verso directory does not exist")
        return {"lot_paths": [], "combined_paths": []}
    
    # AUTO-DETECT ACTUAL GRID FROM FILES
    face_files = [f for f in os.listdir(face_dir) if f.startswith('crop_row') and f.endswith('.jpg')]
    verso_files = [f for f in os.listdir(verso_dir) if f.startswith('crop_row') and f.endswith('.jpg')]
    
    print(f"  - Found {len(face_files)} face files: {face_files}")
    print(f"  - Found {len(verso_files)} verso files: {verso_files}")
    
    if not face_files or not verso_files:
        print("  - ERROR: No matching crop files found")
        return {"lot_paths": [], "combined_paths": []}
    
    # Parse file names to determine actual grid dimensions
    positions = set()
    for filename in face_files:
        # Extract row and col from filename like "crop_row0_col1.jpg"
        try:
            parts = filename.replace('.jpg', '').split('_')
            row = int(parts[1].replace('row', ''))
            col = int(parts[2].replace('col', ''))
            positions.add((row, col))
        except (IndexError, ValueError):
            print(f"  - WARNING: Could not parse filename: {filename}")
            continue
    
    if not positions:
        print("  - ERROR: Could not parse any filenames")
        return {"lot_paths": [], "combined_paths": []}
    
    # Determine actual grid dimensions from files
    actual_rows = max(pos[0] for pos in positions) + 1
    actual_cols = max(pos[1] for pos in positions) + 1
    
    print(f"  - AUTO-DETECTED grid: {actual_rows}x{actual_cols} (from actual files)")
    print(f"  - Found positions: {sorted(positions)}")
    
    # Use actual dimensions instead of passed parameters
    num_rows = actual_rows
    num_cols = actual_cols
    
    # Ensure the output directory exists
    os.makedirs(output_dir, exist_ok=True)
    
    lot_paths = []
    combined_paths = []
    
    # PART 1: Create lot images (by columns) - AUTO-DETECT VERSION
    # Each lot should contain individual face+verso pairs stacked vertically
    for col in range(num_cols):
        print(f"\n  - Processing lot for column {col}")
        
        # Collect face+verso pairs for this column (only for positions that exist)
        pair_images = []
        
        for row in range(num_rows):
            # Only process if this position actually exists in the files
            if (row, col) not in positions:
                print(f"    - Row {row}: Position ({row},{col}) not found in files, skipping")
                continue
                
            face_filename = f"crop_row{row}_col{col}.jpg"
            verso_filename = f"crop_row{row}_col{col}.jpg"
            
            face_path = os.path.join(face_dir, face_filename)
            verso_path = os.path.join(verso_dir, verso_filename)
            
            print(f"    - Row {row}: Checking {face_filename} and {verso_filename}")
            
            # Check if both images exist
            if os.path.exists(face_path) and os.path.exists(verso_path):
                face_img = cv2.imread(face_path)
                verso_img = cv2.imread(verso_path)
                
                if face_img is not None and verso_img is not None:
                    print(f"      - Successfully loaded both images for row {row}, col {col}")
                    
                    # Create individual face+verso pair for this position
                    face_h, face_w = face_img.shape[:2]
                    verso_h, verso_w = verso_img.shape[:2]
                    
                    # Resize images to have the same height (use the smaller height)
                    target_height = min(face_h, verso_h)
                    
                    # Calculate new widths maintaining aspect ratio
                    face_new_width = int(face_w * target_height / face_h)
                    verso_new_width = int(verso_w * target_height / verso_h)
                    
                    # Resize images
                    face_resized = cv2.resize(face_img, (face_new_width, target_height))
                    verso_resized = cv2.resize(verso_img, (verso_new_width, target_height))
                    
                    # Combine face+verso horizontally for this pair
                    pair_combined = np.hstack([face_resized, verso_resized])
                    pair_images.append(pair_combined)
                    
                    print(f"      - Created pair image: {pair_combined.shape[1]}x{pair_combined.shape[0]}")
                else:
                    print(f"      - Failed to load images for row {row}, col {col}")
            else:
                print(f"      - Missing files for row {row}, col {col}")
        
        # Skip if no valid pairs found for this column
        if not pair_images:
            print(f"    - No valid pairs found for column {col}")
            continue
        
        print(f"    - Found {len(pair_images)} valid pairs for column {col}")
        
        # Find the maximum width among all pairs to ensure consistent stacking
        max_pair_width = max(img.shape[1] for img in pair_images)
        
        # Resize all pair images to have the same width (maintaining aspect ratio)
        pair_resized = []
        for img in pair_images:
            height, width = img.shape[:2]
            if width != max_pair_width:
                new_height = int(height * max_pair_width / width)
                resized = cv2.resize(img, (max_pair_width, new_height))
                pair_resized.append(resized)
            else:
                pair_resized.append(img)
        
        # Stack all face+verso pairs vertically to create the lot image
        lot_image = np.vstack(pair_resized)
        
        # Save the lot image
        lot_filename = f"lot_column_{col + 1}.jpg"
        lot_path = os.path.join(output_dir, lot_filename)
        
        success = cv2.imwrite(lot_path, lot_image)
        if success:
            lot_paths.append(lot_path)
            print(f"    - Successfully saved lot image: {lot_filename} ({lot_image.shape[1]}x{lot_image.shape[0]})")
        else:
            print(f"    - Failed to save lot image: {lot_filename}")
    
    # PART 2: Create individual combined images - AUTO-DETECT VERSION
    print(f"\n  - Creating individual combined images...")
    
    # Only process positions that actually exist
    for (row, col) in sorted(positions):
        face_filename = f"crop_row{row}_col{col}.jpg"
        verso_filename = f"crop_row{row}_col{col}.jpg"
        
        face_path = os.path.join(face_dir, face_filename)
        verso_path = os.path.join(verso_dir, verso_filename)
        
        print(f"    - Processing individual pair: row {row}, col {col}")
        
        # Check if both images exist
        if not os.path.exists(face_path) or not os.path.exists(verso_path):
            print(f"      - Missing files for row {row}, col {col}")
            continue
            
        # Load both images
        face_img = cv2.imread(face_path)
        verso_img = cv2.imread(verso_path)
        
        if face_img is None or verso_img is None:
            print(f"      - Failed to load images for row {row}, col {col}")
            continue
            
        # Get dimensions
        face_h, face_w = face_img.shape[:2]
        verso_h, verso_w = verso_img.shape[:2]
        
        # Resize images to have the same height (use the smaller height)
        target_height = min(face_h, verso_h)
        
        # Calculate new widths maintaining aspect ratio
        face_new_width = int(face_w * target_height / face_h)
        verso_new_width = int(verso_w * target_height / verso_h)
        
        # Resize images
        face_resized = cv2.resize(face_img, (face_new_width, target_height))
        verso_resized = cv2.resize(verso_img, (verso_new_width, target_height))
        
        # Combine images horizontally (face on left, verso on right)
        combined_img = np.hstack([face_resized, verso_resized])
        
        # Save combined image
        combined_filename = f"combined_row{row}_col{col}.jpg"
        combined_path = os.path.join(output_dir, combined_filename)
        
        success = cv2.imwrite(combined_path, combined_img)
        if success:
            combined_paths.append(combined_path)
            print(f"      - Successfully saved: {combined_filename} ({combined_img.shape[1]}x{combined_img.shape[0]})")
        else:
            print(f"      - Failed to save: {combined_filename}")
    
    print(f"\n  - SUMMARY:")
    print(f"    - Created {len(lot_paths)} lot images")
    print(f"    - Created {len(combined_paths)} individual combined images")
    
    return {"lot_paths": lot_paths, "combined_paths": combined_paths}


# Module for R-Python integration
# No command-line interface to avoid issues with reticulate import
