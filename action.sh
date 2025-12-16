#!/system/bin/sh

# Cache Cleaner Action Button Script
# This shows live output in Magisk app

MODDIR="${0%/*}"
CONFIG_FILE="$MODDIR/config.conf"

# Load config
. "$CONFIG_FILE"

# Function to print with emoji and timestamp
print_status() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# Function to send notification
send_notify() {
    su -lp 2000 -c "cmd notification post -S bigtext -t 'Cache Cleaner' -c 'Cache Cleaner' 'Action' '$1' 2>/dev/null"
}

print_status "🚀 Starting cache cleaning..."

# Check root access
if [ "$(id -u)" != "0" ]; then
    print_status "❌ Error: Root access required!"
    send_notify "❌ Error: Root access required!"
    exit 1
fi

# Check if already running
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        print_status "⚠️ Cleaning already in progress (PID: $PID)"
        print_status "⏳ Please wait for the current operation to finish..."
        send_notify "⚠️ Cleaning already in progress!"
        exit 0
    fi
fi

# Create lock file
echo $$ > "$LOCK_FILE"

# Calculate before stats
print_status "📊 Analyzing cache size before cleaning..."
TOTAL_BEFORE=$(du -cs $CACHE_PATHS 2>/dev/null | tail -1 | cut -f1)
TOTAL_BEFORE_MB=$((TOTAL_BEFORE / 1024))

print_status "💾 Current cache size: ${TOTAL_BEFORE_MB} MB"

# Count files before
FILES_BEFORE=0
for path in $CACHE_PATHS; do
    if [ -e "$path" ] 2>/dev/null; then
        count=$(find $path -type f 2>/dev/null | wc -l)
        FILES_BEFORE=$((FILES_BEFORE + count))
    fi
done

print_status "📁 Files to delete: ${FILES_BEFORE}"

# Perform cleaning
print_status "🧹 Cleaning cache files..."
FILES_DELETED=0

for path in $CACHE_PATHS; do
    if [ -e "$path" ] 2>/dev/null; then
        count=$(find $path -type f 2>/dev/null | wc -l)
        if [ $count -gt 0 ]; then
            find $path -delete 2>/dev/null
            FILES_DELETED=$((FILES_DELETED + count))
        fi
    fi
done

# Calculate after stats
TOTAL_AFTER=$(du -cs $CACHE_PATHS 2>/dev/null | tail -1 | cut -f1)
TOTAL_AFTER_MB=$((TOTAL_AFTER / 1024))
SIZE_FREED_MB=$((TOTAL_BEFORE_MB - TOTAL_AFTER_MB))

# Update stats file
echo "{\"last_clean\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"files_deleted\":$FILES_DELETED,\"size_freed_mb\":$SIZE_FREED_MB}" > "$STATS_FILE"

# Log to file
log_entry="[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Action Button: Deleted $FILES_DELETED files, freed ${SIZE_FREED_MB} MB"
echo "$log_entry" >> "$LOG_FILE"

# Print results
print_status ""
print_status "═══════════════════════════════════════"
print_status "✅ Cleaning completed successfully!"
print_status "📁 Files deleted: $FILES_DELETED"
print_status "💾 Space freed: ${SIZE_FREED_MB} MB"
print_status "💾 Remaining cache: ${TOTAL_AFTER_MB} MB"
print_status "═══════════════════════════════════════"
print_status ""
print_status "📝 Full log: $LOG_FILE"

# Send notification
send_notify "✅ Cleaned $FILES_DELETED files, freed ${SIZE_FREED_MB} MB"

# Remove lock file
rm -f "$LOCK_FILE"

exit 0
