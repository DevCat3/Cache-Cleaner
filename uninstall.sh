#!/system/bin/sh

# Wait for boot if needed
[ -z "$BOOTMODE" ] && boot_completed() {
    while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 1; done
}

# Cleanup directories and files
cleanup() {
    # Remove settings directory
    rm -rf /sdcard/Android/cache_cleaner
    
    # Remove lock file
    rm -f /data/local/tmp/cache_cleaner.lock
    
    # Remove update marker
    rm -rf /cache/cache_cleaner
}

# Run cleanup
boot_completed
cleanup &

exit 0
