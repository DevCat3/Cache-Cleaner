#!/system/bin/sh

SKIPUNZIP=1

# UI Print Helper
ui_print() {
    echo "$1"
}

# Module info
ui_print "================================"
ui_print "  Cache Cleaner Enhanced v2.0"
ui_print "================================"
ui_print ""
ui_print "✨ Features:"
ui_print "• Auto-clean when cache > threshold"
ui_print "• Manual cleaning via terminal"
ui_print "• WebUI for easy management"
ui_print "• Action Button support"
ui_print "• Customizable settings"
ui_print ""
ui_print "📱 Requirements:"
ui_print "• Android 5.0+"
ui_print "• Magisk 23.0+"
ui_print ""
sleep 2

# Check requirements
if [ "$API" -lt 21 ]; then
    abort "❌ Requires API 21+ (Android 5.0+)"
fi

if [ "$MAGISK_VER_CODE" -lt 23000 ]; then
    abort "❌ Requires Magisk v23.0+"
fi

if ! $BOOTMODE; then
    abort "❌ Install via Magisk app only"
fi

# Extract module files
ui_print "📦 Extracting files..."
unzip -o "$ZIPFILE" "module.prop" -d "$MODPATH" >&2
unzip -o "$ZIPFILE" "config.conf" -d "$MODPATH" >&2
unzip -o "$ZIPFILE" "automatic.sh" -d "$MODPATH" >&2
unzip -o "$ZIPFILE" "cleaner" -d "$MODPATH" >&2
unzip -o "$ZIPFILE" "action.sh" -d "$MODPATH" >&2
unzip -o "$ZIPFILE" "service.sh" -d "$MODPATH" >&2
unzip -o "$ZIPFILE" "uninstall.sh" -d "$MODPATH" >&2
unzip -o "$ZIPFILE" "webroot/*" -d "$MODPATH" >&2

# Setup binaries
ui_print "⚙️ Setting up binaries..."
mkdir -p "$MODPATH/system/bin"
cp "$MODPATH/cleaner" "$MODPATH/system/bin/cleaner"
chmod 755 "$MODPATH/system/bin/cleaner"

# Create directories
ui_print "📁 Creating directories..."
mkdir -p /sdcard/Android/cache_cleaner
touch /sdcard/Android/cache_cleaner/logs.txt
touch /sdcard/Android/cache_cleaner/stats.json

# Set permissions
ui_print "🔐 Setting permissions..."
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/system/bin/cleaner" 0 0 0755
set_perm "$MODPATH/automatic.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755

ui_print ""
ui_print "✅ Installation complete!"
ui_print "📍 Access WebUI from Magisk app"
ui_print "💡 Use 'su -c cleaner' for manual cleaning"
ui_print "📝 Logs: /sdcard/Android/cache_cleaner/logs.txt"
ui_print ""
