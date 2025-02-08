#!/bin/bash
set -euo pipefail

# Enable extended globbing and ensure that non-matching globs expand to nothing.
shopt -s nullglob

DOWNLOAD_DIR="./data"
SYMLINK_DIR="$HOME/nomadwiki"
TMP_PAGE="/tmp/enwiki_latest_page.html"
BASE_URL="https://dumps.wikimedia.org/enwiki/latest"
FILES=(
  "enwiki-latest-pages-articles-multistream-index.txt.bz2"
  "enwiki-latest-pages-articles-multistream.xml.bz2"
)

mkdir -p "$DOWNLOAD_DIR"
mkdir -p "$SYMLINK_DIR"

cd "$DOWNLOAD_DIR"

# fetch the directory listing.
echo "Fetching directory listing from ${BASE_URL}/ ..."
curl -s "${BASE_URL}/" -o "$TMP_PAGE"

convertDate() {
  ORIGINAL_DATE="$1"
  DATE_FORMAT="$2"
  OUTPUT_FORMAT="%Y-%m-%dT%H:%M:%S%z"

  if [ -n "${3:-}" ]; then
    OUTPUT_FORMAT="$3"
  fi

  if date --version 2>/dev/null | grep "GNU coreutils" >/dev/null; then
    CONVERTED_DATE=$(date --date="$ORIGINAL_DATE" "$OUTPUT_FORMAT")
  else
    BSD_DATE_FORMAT="${DATE_FORMAT#+}"   # remove any leading +
    BSD_DATE_FORMAT=$(echo "$BSD_DATE_FORMAT" | sed 's/%-d/%e/g')
    CONVERTED_DATE=$(date -j -f "$BSD_DATE_FORMAT" "$ORIGINAL_DATE" "$OUTPUT_FORMAT")
  fi

  echo "$CONVERTED_DATE"
}

decompress_index() {
  local source_file="$1"
  # only need to decompress the index file
  if [ "$file" = "enwiki-latest-pages-articles-multistream-index.txt.bz2" ]; then
    local unzipped="${source_file%.bz2}"
    bzip2 -dc "$source_file" > "$unzipped"
    echo "$unzipped"
  else
    echo "$source_file"
  fi
}

getSymlinkFileName() {
  local source_file="$1"
  if [ "$file" = "enwiki-latest-pages-articles-multistream-index.txt.bz2" ]; then
    local unzipped="${source_file%.bz2}"
    echo "$unzipped"
  else
    echo "$source_file"
  fi
}

check_and_download() {
  local file="$1"
  local symlink_path
  symlink_path="${SYMLINK_DIR}/$(getSymlinkFileName "$file")"

  remote_date=$(grep "$file" "$TMP_PAGE" \
    | sed -n 's/.*\([0-9]\{1,2\}-[A-Za-z]\{3\}-[0-9]\{4\} [0-9]\{2\}:[0-9]\{2\}\).*/\1/p' \
    | head -n 1)
  if [ -z "$remote_date" ]; then
    echo "Could not determine the remote upload date for $file. Skipping."
    return
  fi

  safe_remote_date=$(convertDate "$remote_date" "+%-d-%b-%Y %H:%M" "+%Y-%m-%d")
  remote_date_epoch=$(convertDate "$safe_remote_date" "+%Y-%m-%d" "+%s")


  local max_epoch=0
  for candidate in "${file}".*; do
    [ -f "$candidate" ] || continue
    local candidate_date
    candidate_date=$(basename "$candidate")
    candidate_date=${candidate_date#"${file}".}
    candidate_epoch=$(convertDate "$candidate_date" "+%Y-%m-%d" "+%s")
    if [ "$candidate_epoch" -gt "$max_epoch" ]; then
      max_epoch="$candidate_epoch"
    fi
  done

  if [ "$remote_date_epoch" -gt "$max_epoch" ]; then
    echo "New version detected for $file (remote date: $remote_date). Downloading to $file ..."
    wget "${BASE_URL}/${file}"
    echo "Download complete for $file."
    if [ -L "$symlink_path" ] || [ -f "$symlink_path" ]; then
      rm -f "$symlink_path"
    fi
    original_file="${file}"
    file=$(decompress_index "$file")
    target_file="${file}.${safe_remote_date}"
    mv "${file}" "${target_file}"
    [ -f "${original_file}" ] && mv "${original_file}" "${original_file}.${safe_remote_date}"

    ln -s "$(realpath "$target_file")" "$symlink_path"
    echo "Symlink updated: $symlink_path -> $(realpath "$target_file")"

    files_downloaded=$((files_downloaded + 1))
  else
    echo "No new version detected for $file (remote date: $safe_remote_date)."
  fi
}

files_downloaded=0

# Process each target file.
for file in "${FILES[@]}"; do
  check_and_download "$file"
done

# Update the last update file if any files were downloaded.
if [ "$files_downloaded" -gt 0 ]; then
  formatted_remote_date=$(convertDate "$safe_remote_date" "+%Y-%m-%d" "+%m-%d-%Y" )
  echo "$formatted_remote_date" > "${SYMLINK_DIR}/last_update"
fi


# Cleanup the temporary page file.
rm -f "$TMP_PAGE"
