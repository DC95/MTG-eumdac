
import os
import sys
import logging
import glob

def get_existing_files(download_dir, format):
    if format == 'netcdf4':
        return glob.glob(f'{download_dir}/**/*.nc', recursive=True)
    else:
        logging.warning("Only netcdf4 format is supported for MTG-FCI checks.")
        return []

def extract_mtg_start_time(file_id: str) -> str:
    """
    Extracts start time (yyyymmddhhmmss) from MTG FCI file ID and converts to NetCDF-style timestamp.
    """
    try:
        parts = file_id.split('_')
        if len(parts) < 10:
            raise ValueError("Unexpected filename structure")

        start_time_raw = parts[-4]  # e.g., 20250801232003
        return start_time_raw[:8] + 'T' + start_time_raw[8:] + 'Z'  # → 20250801T232003Z
    except Exception as e:
        logging.warning(f"Error extracting start time from filename: {file_id} | Error: {e}")
        return None

def is_file_present(filename, download_dir, format):
    if not os.path.exists(download_dir):
        return False

    existing_files = get_existing_files(download_dir, format)

    if format == 'netcdf4':
        target_timestamp = extract_mtg_start_time(filename)
        if not target_timestamp:
            return False
        for f in existing_files:
            if target_timestamp in os.path.basename(f):
                return True
        return False
    else:
        logging.warning("Unsupported format for presence check.")
        return False

# Entry point
if __name__ == "__main__":
    filename = sys.argv[1]
    download_dir = sys.argv[2]
    format = sys.argv[3]

    if is_file_present(filename, download_dir, format):
        print(f"{filename} exists")
    else:
        print(f"{filename} does not exist")