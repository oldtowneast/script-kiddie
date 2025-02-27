import os
import re

def to_kebab_case(filename):
    name, ext = os.path.splitext(filename)  # Separate file name and extension
    
    # Convert to lowercase
    name = name.lower()
    
    # Replace spaces, underscores, dots (except extension), and camelCase with hyphens
    name = re.sub(r'([a-z])([A-Z])', r'\1-\2', name)  # Split camelCase
    name = re.sub(r'[\s._]+', '-', name)  # Replace spaces, underscores, dots with '-'
    name = re.sub(r'-+', '-', name)  # Remove duplicate hyphens
    name = name.strip('-')  # Remove trailing hyphens

    return f"{name}{ext}"  # Reattach the extension

def rename_files_in_directory(directory):
    for filename in os.listdir(directory):
        old_path = os.path.join(directory, filename)
        
        # Ignore directories, only rename files
        if os.path.isfile(old_path):
            new_filename = to_kebab_case(filename)
            new_path = os.path.join(directory, new_filename)

            # Rename only if the name changed
            if filename != new_filename:
                print(f"Renaming: {filename} -> {new_filename}")
                os.rename(old_path, new_path)

if __name__ == "__main__":
    directory = os.getcwd()  # Use the current working directory
    rename_files_in_directory(directory)
    print("\nAll files have been converted to kebab-case!")
