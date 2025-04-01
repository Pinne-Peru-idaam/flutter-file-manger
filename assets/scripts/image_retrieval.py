import tensorflow as tf
from PIL import Image
import numpy as np
import os
import sys
import argparse
from transformers import AutoProcessor, TFCLIPModel

def retrieve_image_path_by_text(image_folder, text_prompt):
    """
    Retrieves the file path of the image that best matches the given text prompt from a local folder.
    
    Args:
        image_folder (str): Path to folder containing images
        text_prompt (str): Text description to match against images
        
    Returns:
        str: File path of the best matching image
    """
    print(f"Starting image retrieval for prompt: '{text_prompt}'", file=sys.stderr)
    print(f"Looking in folder: {image_folder}", file=sys.stderr)
    
    # Check if folder exists
    if not os.path.exists(image_folder):
        print(f"Error: Folder '{image_folder}' does not exist", file=sys.stderr)
        return ""
    
    # List directory contents
    dir_contents = os.listdir(image_folder)
    print(f"Found {len(dir_contents)} files in folder", file=sys.stderr)
    
    try:
        # Load model and processor
        print("Loading CLIP model...", file=sys.stderr)
        model = TFCLIPModel.from_pretrained("openai/clip-vit-base-patch32")
        processor = AutoProcessor.from_pretrained("openai/clip-vit-base-patch32")
        
        # Get all image files from the folder
        image_extensions = ['.jpg', '.jpeg', '.png', '.bmp', '.gif']
        image_paths = []
        
        for file in dir_contents:
            if any(file.lower().endswith(ext) for ext in image_extensions):
                image_paths.append(os.path.join(image_folder, file))
        
        print(f"Found {len(image_paths)} images with valid extensions", file=sys.stderr)
        
        if not image_paths:
            print("No valid images found in the folder", file=sys.stderr)
            return ""
        
        # Load and process images
        images = []
        valid_paths = []
        
        for path in image_paths:
            try:
                img = Image.open(path).convert('RGB')
                images.append(img)
                valid_paths.append(path)
            except Exception as e:
                print(f"Could not load {path}: {e}", file=sys.stderr)
        
        print(f"Successfully loaded {len(images)} images", file=sys.stderr)
        
        if not images:
            print("No images could be loaded successfully", file=sys.stderr)
            return ""
        
        # Process inputs
        print("Processing images with CLIP...", file=sys.stderr)
        inputs = processor(text=[text_prompt], images=images, return_tensors="tf", padding=True)
        
        # Get model predictions
        outputs = model(**inputs)
        logits_per_image = outputs.logits_per_image
        scores = tf.squeeze(logits_per_image).numpy()
        
        # Find the best matching image
        best_match_idx = np.argmax(scores)
        best_score = scores[best_match_idx]
        
        print(f"Best match score: {best_score}", file=sys.stderr)
        print(f"Best match path: {valid_paths[best_match_idx]}", file=sys.stderr)
        
        # Return the file path of the best matching image
        return valid_paths[best_match_idx]
    
    except Exception as e:
        print(f"Error during image retrieval: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        return ""

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--folder', required=True, help='Path to image folder')
    parser.add_argument('--prompt', required=True, help='Text description to match')
    args = parser.parse_args()
    
    print(f"Script started with folder={args.folder}, prompt={args.prompt}", file=sys.stderr)
    
    # Get the best matching image path
    best_image_path = retrieve_image_path_by_text(args.folder, args.prompt)
    
    # Print just the file path to stdout for the Dart code to capture
    print(best_image_path)