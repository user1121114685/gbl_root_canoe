#
cd "$(dirname "$0")"
mkdir -p ../images
rm -f ../images/ABL.EFI ../images/abl.img
python3 ../tools/extractfv.py ./001_myron_abl.elf -o ../images >> /dev/null 2>&1
mv ../images/LinuxLoader.efi ../images/ABL.EFI
cd ..
make patch HWCOUNTRY=GLOBAL >> /dev/null 2>&1
if [ ! -f dist/ABL.efi ]; then
    echo "Test failed: Patched ABL.efi not found when using EFI input."
    rm -f ./images/ABL.EFI
    make clean >> /dev/null 2>&1
    exit 1
else
    echo "Test passed: EFI input path generated ABL.efi successfully."
    rm -f ./images/ABL.EFI
    make clean >> /dev/null 2>&1
fi
