#
cd "$(dirname "$0")"
mkdir -p ../images
rm -f ../images/ABL.elf ../images/ABL.EFI ../images/abl.img
cp ./001_myron_abl.elf ../images/ABL.elf
cd ..
make patch HWCOUNTRY=GLOBAL >> /dev/null 2>&1
if [ ! -f dist/ABL.efi ]; then
    echo "Test failed: Patched ABL.efi not found when using ELF input."
    rm -f ./images/ABL.elf
    make clean >> /dev/null 2>&1
    exit 1
else
    echo "Test passed: ELF input path generated ABL.efi successfully."
    rm -f ./images/ABL.elf
    make clean >> /dev/null 2>&1
fi
