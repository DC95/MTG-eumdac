#!/bin/bash
script_start_time=$(date +%s)

##### CONFIG PARAMETERS
default_start_time="2025-04-01T00:00"
default_end_time="2025-05-01T00:00"
default_download_dir="/p/scratch/exaww/chatterjee1/msg_warmworld/2025/"

START_TIME="${1:-$default_start_time}"
END_TIME="${2:-$default_end_time}"
DOWNLOAD_DIR="${3:-$default_download_dir}"
SCRIPT_DIR="/p/project1/exaww/chatterjee1/Daniele_scripts/"
LOG_DIR="$DOWNLOAD_DIR/logs/"
mkdir -p "$LOG_DIR"

echo "Using START_TIME: $START_TIME"
echo "Using END_TIME: $END_TIME"
echo "Downloading to: $DOWNLOAD_DIR"

PRODUCT="EO:EUM:DAT:0662"
FORMAT='netcdf4'

# Bounding Box (North, South, West, East)
N=55
S=30
W=-3.5
E=32.5

batch_size=10

# Get credentials
credentials=$(python ${SCRIPT_DIR}credentials_1.py)
readarray -td' ' cred_array <<<"$credentials"
ConsumerKey=${cred_array[0]}
ConsumerSecret=${cred_array[1]}
ConsumerKey=$(echo $ConsumerKey | tr -d '\n')
ConsumerSecret=$(echo $ConsumerSecret | tr -d '\n')

eumdac set-credentials $ConsumerKey $ConsumerSecret

LOG_FILE="${LOG_DIR}logfile.txt"
python_script_path="${SCRIPT_DIR}check_file_presence_MTG.py"

# Clean old sessions
eumdac order delete --all
eumdac tailor clean --all

# Search for products
rm -f "${LOG_DIR}products.txt"
echo "Searching for available products..."
eumdac search -c $PRODUCT --start $START_TIME --end $END_TIME > "${LOG_DIR}products.txt"

if [ ! -s "${LOG_DIR}products.txt" ]; then
    echo "Search failed or returned no products. Exiting."
    exit 1
fi

echo "Number of lines before checking: $(wc -l < ${LOG_DIR}products.txt)"

touch "${LOG_DIR}temp_products.txt"
while IFS= read -r line; do
    result=$(python "$python_script_path" "$line" "$DOWNLOAD_DIR" "$FORMAT")
    echo "$result"
    if echo "$result" | grep -q "does not exist"; then
        echo "$line" >> "${LOG_DIR}temp_products.txt"
    fi
done < "${LOG_DIR}products.txt"

mv "${LOG_DIR}temp_products.txt" "${LOG_DIR}products.txt"
echo "Number of lines after checking: $(wc -l < ${LOG_DIR}products.txt)"

if [ -s "${LOG_DIR}products.txt" ]; then
    echo "Files are available for download."
    total_lines=$(wc -l < "${LOG_DIR}products.txt")
    num_batches=$(( (total_lines + batch_size - 1) / batch_size ))
    touch "${LOG_DIR}temp_batch_files.txt"

    for (( batch=1; batch<=num_batches; batch++ )); do
        start_line=$(( (batch - 1) * batch_size + 1 ))
        end_line=$(( batch * batch_size ))
        sed -n "${start_line},${end_line}p" "${LOG_DIR}products.txt" > "${LOG_DIR}temp_batch_files.txt"

        echo "Processing batch $batch:"
        eumdac download -c $PRODUCT -p @"${LOG_DIR}temp_batch_files.txt" \
            --tailor "product: FCIL1FDHSI, format: $FORMAT, projection: geographic, filter: fcil1fdhsi_2km, roi: {NSWE: [$N, $S, $W, $E]}" \
            -o "$DOWNLOAD_DIR" -y

        # Clean up customization state
        eumdac order delete --all
        eumdac tailor clean --all
    done

    rm -f "${LOG_DIR}temp_batch_files.txt"
else
    echo "No files are available to download."
fi

script_end_time=$(date +%s)
elapsed_time=$((script_end_time - script_start_time))
echo "Elapsed Time: $elapsed_time seconds" >> "$LOG_FILE"
echo "Download concluded!"