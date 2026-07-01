#!/bin/bash

maintainer="romeo_13card"                                                        # Here we get the name of maintainer
path=~/luna                                                                      # Here you will need to specify the path to the LunarisAOSP source code folder
device=$(ls $path/out/target/product)                                            # Here we get the name of the device based on the name of the folder
time=$(cat $path/out/build_date.txt 2>/dev/null || date +"%Y%m%d_%H%M%S")        # Here we get the build time

# Fixed: Correct pattern for Lunaris-AOSP zip files
zip=$(basename $path/out/target/product/$device/Lunaris-AOSP-$device-*.zip)      # Here we get the package name with the extension .zip
nozip=$(basename $path/out/target/product/$device/Lunaris-AOSP-$device-*.zip .zip) # Here we get the package name without the extension .zip
date=$(echo $zip | cut -f5 -d '-')                                               # Here we get the build date (in YYYYMMDDHH format)

case "${device,,}" in 
    "fog") devicename="Redmi 10C" && oem="Xiaomi" ;;                             # fog - Redmi 10C
esac

buildtype="Monthly"                                                              # choose from Testing/Alpha/Beta/Weekly/Monthly
forum=""                                                                         # https link (mandatory)
gapps="https://bitgapps.io/"                                                     # https link (leave empty if unused)
firmware=""                                                                      # https link (leave empty if unused)
modem=""                                                                         # https link (leave empty if unused)
bootloader=""                                                                    # https link (leave empty if unused)
recovery=""                                                                      # https link (leave empty if unused)
paypal=""                                                                        # https link (leave empty if unused)
telegram="https://t.me/Romeo_13card"                                             # https link (leave empty if unused)
dt="https://github.com/Lunar-Project/android_device_xiaomi_fog"                  # https://github.com/<vendor>/android_device_<oem>_<device_codename>
commondt=""                                                                      # https://github.com/<vendor>/android_device_<oem>_<soc>-common
kernel=""                                                                        # https://github.com/<vendor>/android_kernel_<oem>_<soc>

#don't modify from here
zip_name=$path/out/target/product/$device/$zip
buildprop=$path/out/target/product/$device/system/build.prop

# Check if files exist
if [ ! -f "$zip_name" ]; then
    echo "❌ Error: ZIP file not found!"
    echo "Looking for: $zip_name"
    echo "Trying to find with pattern: $path/out/target/product/$device/Lunaris-AOSP-$device-*.zip"
    exit 1
fi

# Get timestamp from build.prop or use current time
if [ -f "$buildprop" ]; then
    linenr=`grep -n "ro.system.build.date.utc" $buildprop | cut -d':' -f1`
    if [ -z "$linenr" ]; then
        linenr=`grep -n "ro.build.date.utc" $buildprop | cut -d':' -f1`
    fi
    if [ -n "$linenr" ]; then
        timestamp=`sed -n $linenr'p' < $buildprop | cut -d'=' -f2`
    else
        timestamp=$(date +%s)
    fi
else
    echo "⚠️ Warning: build.prop not found, using current time"
    timestamp=$(date +%s)
fi

# Determine build type (user/userdebug) from build.prop or filename
if [ -f "$buildprop" ]; then
    build_type=$(grep "ro.build.type=" "$buildprop" 2>/dev/null | cut -d'=' -f2)
    if [ -z "$build_type" ]; then
        build_type=$(grep "ro.system.build.type=" "$buildprop" 2>/dev/null | cut -d'=' -f2)
    fi
else
    build_type="unknown"
fi

# If still empty, try to get from filename
if [ -z "$build_type" ] || [ "$build_type" = "unknown" ]; then
    if echo "$zip" | grep -qi "userdebug"; then
        build_type="userdebug"
    elif echo "$zip" | grep -qi "user"; then
        build_type="user"
    else
        build_type="unknown"
    fi
fi

# Determine build variant (VANILLA/GAPPS) from filename
if echo "$zip" | grep -qi "VANILLA"; then
    build_variant="VANILLA"
elif echo "$zip" | grep -qi "GAPPS"; then
    build_variant="GAPPS"
else
    build_variant=""
fi

zip_only=`basename "$zip_name"`
md5=`md5sum "$zip_name" | cut -d' ' -f1`
sha256=`sha256sum "$zip_name" | cut -d' ' -f1`
size=`stat -c "%s" "$zip_name" 2>/dev/null || stat -f "%z" "$zip_name" 2>/dev/null`
version=`echo "$zip_only" | grep -oP '\d+\.\d+' | head -1`
[ -z "$version" ] && version="3.11"

echo '{
  "response": [
    {
        "maintainer": "'$maintainer'",
        "oem": "'$oem'",
        "device": "'$devicename'",
        "filename": "'$zip_only'",
        "download": "https://github.com/Romeo13card/OTA/releases/download/'$nozip'/'$zip'",
        "timestamp": '$timestamp',
        "md5": "'$md5'",
        "sha256": "'$sha256'",
        "size": '$size',
        "version": "'$version'",
        "buildtype": "'$buildtype'",
        "build_variant": "'$build_variant'",
        "build_type": "'$build_type'",
        "forum": "'$forum'",
        "gapps": "'$gapps'",
        "firmware": "'$firmware'",
        "modem": "'$modem'",
        "bootloader": "'$bootloader'",
        "recovery": "'$recovery'",
        "paypal": "'$paypal'",
        "telegram": "'$telegram'",
        "dt": "'$dt'",
        "common-dt": "'$commondt'",
        "kernel": "'$kernel'"
    }
  ]
}' > $device.json

echo "✅ JSON created: $device.json"

# Show JSON content for verification
echo ""
echo "📄 JSON content:"
cat $device.json
echo ""

# Push to GitHub
echo "🚀 Pushing to GitHub..."

git add -A
git commit -m "Update autogenerated json LunarisAOSP $version for $device $date/$time"
git push

# Create GitHub Release
echo "📦 Creating release..."

if [ -f "$path/out/target/product/$device/boot.img" ]; then
    gh release create $nozip \
        --notes "Automated release LunarisAOSP $version for $device $date/$time" \
        $path/out/target/product/$device/$zip \
        $path/out/target/product/$device/boot.img
    echo "✅ Release created with boot.img"
else
    gh release create $nozip \
        --notes "Automated release LunarisAOSP $version for $device $date/$time" \
        $path/out/target/product/$device/$zip
    echo "⚠️ boot.img not found, release created without it"
fi

echo ""
echo "🎉 Done!"
echo "📌 JSON: $device.json"
echo "📌 Release: https://github.com/Romeo13card/OTA/releases/tag/$nozip"
