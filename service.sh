#!/system/bin/sh

MODDIR="${0%/*}"

# Wait for boot completion
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 1
done

# Wait for storage
while [ ! -d /sdcard/Android ]; do
    sleep 1
done

# Create necessary directories
mkdir -p /sdcard/Android/cache_cleaner
mkdir -p "$(dirname "$(grep LOG_FILE "$MODDIR/config.conf" | cut -d'=' -f2)")" 2>/dev/null

# Set permissions
chmod 755 "$MODDIR/automatic.sh"
chmod 755 "$MODDIR/cleaner"
chmod 755 "$MODDIR/action.sh"

# Start automatic cleaner in background
log_file=$(grep LOG_FILE "$MODDIR/config.conf" | cut -d'=' -f2 | tr -d ' ')
{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚀 Cache Cleaner service starting..."
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📁 Log file: $log_file"
} >> "$log_file" 2>/dev/null

nohup "$MODDIR/automatic.sh" >> "$log_file" 2>&1 &

exit 0
