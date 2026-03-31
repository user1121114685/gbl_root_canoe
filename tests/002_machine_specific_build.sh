#
cd "$(dirname "$0")"
cp 001_myron_abl.elf ../images/abl.img
cd ..
make build HWCOUNTRY=GLOBAL >> /dev/null 2>&1
#check if the patched ABL_with_superfastboot.efi is generated
if [ ! -f dist/ABL_with_superfastboot.efi ]; then
    echo "Test failed: Patched ABL_with_superfastboot.efi not found."
    make clean >> /dev/null 2>&1
    rm ./images/abl.img
    exit 1
else
    echo "Test passed: Patched ABL_with_superfastboot.efi generated successfully."
    rm ./images/abl.img
    make clean >> /dev/null 2>&1
fi
