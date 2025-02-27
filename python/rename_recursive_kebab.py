import os
import re

def to_kebab_case(filename):
    """Convert a filename to kebab-case while keeping the extension."""
    name, ext = os.path.splitext(filename)  # Separate file name and extension
    
    # Convert to lowercase
    name = name.lower()
    
    # Replace spaces, underscores, dots (except extension), and camelCase with hyphens
    name = re.sub(r'([a-z])([A-Z])', r'\1-\2', name)  # Convert camelCase to kebab-case
    name = re.sub(r'[\s._]+', '-', name)  # Replace spaces, underscores, dots with '-'
    name = re.sub(r'-+', '-', name)  # Remove duplicate hyphens
    name = name.strip('-')  # Remove leading/trailing hyphens

    return f"{name}{ext}"  # Reattach the extension

def rename_files_recursively(directory):
    """Rename all files in the given directory and its subdirectories to kebab-case."""
    for root, _, files in os.walk(directory):  # Walk through directories
        for filename in files:
            old_path = os.path.join(root, filename)
            new_filename = to_kebab_case(filename)
            new_path = os.path.join(root, new_filename)

            # Rename only if the name changed
            if filename != new_filename:
                print(f"Renaming: {old_path} -> {new_path}")
                os.rename(old_path, new_path)

if __name__ == "__main__":
    directory = os.getcwd()  # Use the current working directory
    rename_files_recursively(directory)
    print("\n✅ All files (including subdirectories) have been converted to kebab-case!")
