#!/system/bin/sh

# Load configuration
CONFIG_DIR="${0%/*}"
. "$CONFIG_DIR/config.conf"

# Logging function
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    [ "$VERBOSE_LOG" = "true" ] && echo "$message"
    echo "$message" >> "$LOG_FILE"
}

# Check if already running
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        log "⚠️ Cleaner already running (PID: $PID)"
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"

# Cleanup on exit
cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT

# Calculate total cache size
calculate_size() {
    local total=0
    for path in $CACHE_PATHS; do
        if [ -e "$path" ] 2>/dev/null; then
            size=$(du -cs $path 2>/dev/null | tail -1 | cut -f1)
            total=$((total + size))
        fi
    done
    echo $total
}

# Main cleaning function
cleaner() {
    log "🧹 Starting cache cleanup..."
    local files_deleted=0
    local size_before=$(calculate_size)
    
    for path in $CACHE_PATHS; do
        if [ -e "$path" ] 2>/dev/null; then
            count=$(find $path -type f 2>/dev/null | wc -l)
            if [ $count -gt 0 ]; then
                find $path -delete 2>/dev/null
                files_deleted=$((files_deleted + count))
                log "   ✓ Cleaned $count files from $path"
            fi
        fi
    done
    
    local size_after=$(calculate_size)
    local size_freed=$((size_before - size_after))
    
    # Update stats
    echo "{\"last_clean\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"files_deleted\":$files_deleted,\"size_freed_mb\":$((size_freed / 1024))}" > "$STATS_FILE"
    
    log "✅ Cleanup complete! Deleted $files_deleted files, freed $((size_freed / 1024)) MB"
}

# Main loop
log "🚀 Cache Cleaner service started (Threshold: ${THRESHOLD_MB}MB, Interval: ${CHECK_INTERVAL}s)"
while true; do
    # Check if disabled
    if [ -f /sdcard/Android/cache_cleaner/disable ]; then
        log "⏸️ Auto-clean disabled... waiting"
        sleep 60
        continue
    fi
    
    # Check cache size
    total_size_kb=$(calculate_size)
    total_size_mb=$((total_size_kb / 1024))
    
    if [ $total_size_mb -gt $THRESHOLD_MB ]; then
        log "⚡ Cache size (${total_size_mb}MB) exceeds threshold (${THRESHOLD_MB}MB)"
        
        # Check minimum interval
        if [ -f "$STATS_FILE" ]; then
            last_clean=$(grep -o '"last_clean":"[^"]*' "$STATS_FILE" | cut -d'"' -f4)
            if [ -n "$last_clean" ]; then
                last_timestamp=$(date -d "$last_clean" +%s 2>/dev/null || echo "0")
                current_timestamp=$(date +%s)
                time_diff=$((current_timestamp - last_timestamp))
                
                if [ $time_diff -lt $MIN_CLEAN_INTERVAL ]; then
                    sleep_time=$((MIN_CLEAN_INTERVAL - time_diff))
                    log "⏰ Minimum interval not reached, waiting ${sleep_time}s"
                    sleep $sleep_time
                    continue
                fi
            fi
        fi
        
        cleaner
    fi
    
    sleep $CHECK_INTERVAL
done
