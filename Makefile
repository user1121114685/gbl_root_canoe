HWCOUNTRY_LIST := CN GLOBAL EU IN RU ID TW TR
HWCOUNTRY ?=
PATCH_HWCOUNTRY := $(if $(strip $(HWCOUNTRY)),$(firstword $(strip $(HWCOUNTRY))),GLOBAL)
BUILD_OUTPUT := edk2/Build/RELEASE_CLANG35/AARCH64/LinuxLoader.efi

clean:
	rm -rf edk2/Build || true
	rm -rf edk2/Conf || true
	rm edk2/QcomModulePkg/Include/Library/ABL.h || true
	rm tools/patch_abl || true
	rm -rf dist || true
	mkdir -p dist

prepare_patch: clean
	python tools/extractfv.py ./images/abl.img -o ./dist
	mv ./dist/LinuxLoader.efi ./dist/ABL_original.efi
	gcc -o tools/patch_abl tools/patch_abl.c

patch: prepare_patch
	./tools/patch_abl ./dist/ABL_original.efi ./dist/ABL.efi $(PATCH_HWCOUNTRY) > ./dist/patch_log.txt
	rm tools/patch_abl
	cat ./dist/patch_log.txt

build: prepare_patch
	@set -e; \
	trap 'rm -f tools/patch_abl' EXIT; \
	build_countries="$(if $(strip $(HWCOUNTRY)),$(strip $(HWCOUNTRY)),$(HWCOUNTRY_LIST))"; \
	first_country=""; \
	for country in $$build_countries; do \
		if [ -z "$$first_country" ]; then first_country="$$country"; fi; \
		echo "==> Building HwCountry=$$country"; \
		./tools/patch_abl ./dist/ABL_original.efi ./dist/ABL_$$country.efi "$$country" > ./dist/patch_log_$$country.txt; \
		cp ./dist/ABL_$$country.efi ./dist/ABL.efi; \
		cp ./dist/patch_log_$$country.txt ./dist/patch_log.txt; \
		xxd -i dist/ABL.efi > edk2/QcomModulePkg/Include/Library/ABL.h; \
		rm -rf edk2/Build edk2/Conf; \
		cp -r ./Conf ./edk2/; \
		bash -c 'cd edk2 && . ./edksetup.sh && make BOARD_BOOTLOADER_PRODUCT_NAME=canoe TARGET_ARCHITECTURE=AARCH64 TARGET=RELEASE \
  		CLANG_BIN=/usr/bin/ CLANG_PREFIX=aarch64-linux-gnu- VERIFIED_BOOT_ENABLED=1 \
  		VERIFIED_BOOT_LE=0 AB_RETRYCOUNT_DISABLE=0 TARGET_BOARD_TYPE_AUTO=0 \
  		BUILD_USES_RECOVERY_AS_BOOT=0 DISABLE_PARALLEL_DOWNLOAD_FLASH=0 PVMFW_BCC_ENABLED=-DPVMFW_BCC\
  		REMOVE_CARVEOUT_REGION=1 QSPA_BOOTCONFIG_ENABLE=1 USER_BUILD_VARIANT=0 \
  		PREBUILT_HOST_TOOLS="BUILD_CC=clang BUILD_CXX=clang++ LDPATH=-fuse-ld=lld BUILD_AR=llvm-ar"' || true; \
		if [ ! -f $(BUILD_OUTPUT) ]; then \
			echo "Build failed for HwCountry=$$country"; \
			exit 1; \
		fi; \
		cp $(BUILD_OUTPUT) ./dist/ABL_with_superfastboot_$$country.efi; \
		if [ "$$country" = "GLOBAL" ]; then \
			cp $(BUILD_OUTPUT) ./dist/ABL_with_superfastboot.efi; \
		fi; \
	done; \
	if [ ! -f ./dist/ABL_with_superfastboot.efi ]; then \
		cp ./dist/ABL_with_superfastboot_$$first_country.efi ./dist/ABL_with_superfastboot.efi; \
	fi
	cat ./dist/patch_log.txt
	ls -l ./dist
dist: build
	mkdir release
	zip -r release/$(DIST_NAME).zip dist

build_superfbonly: clean
	cp -r ./Conf ./edk2/
	bash -c 'cd edk2 && . ./edksetup.sh && make BOARD_BOOTLOADER_PRODUCT_NAME=canoe TARGET_ARCHITECTURE=AARCH64 TARGET=RELEASE \
  		CLANG_BIN=/usr/bin/ CLANG_PREFIX=aarch64-linux-gnu- VERIFIED_BOOT_ENABLED=1 \
  		VERIFIED_BOOT_LE=0 AB_RETRYCOUNT_DISABLE=0 TARGET_BOARD_TYPE_AUTO=0 \
  		BUILD_USES_RECOVERY_AS_BOOT=0 DISABLE_PARALLEL_DOWNLOAD_FLASH=0 PVMFW_BCC_ENABLED=-DPVMFW_BCC\
  		REMOVE_CARVEOUT_REGION=1 QSPA_BOOTCONFIG_ENABLE=1 USER_BUILD_VARIANT=0 TEST_ADAPTER=1 \
  		PREBUILT_HOST_TOOLS="BUILD_CC=clang BUILD_CXX=clang++ LDPATH=-fuse-ld=lld BUILD_AR=llvm-ar"' || true
	# test if the build is successful by checking the output file
	if [ ! -f edk2/Build/RELEASE_CLANG35/AARCH64/LinuxLoader.efi ]; then \
		echo "Build failed"; \
		exit 1; \
	fi
	cp edk2/Build/RELEASE_CLANG35/AARCH64/LinuxLoader.efi ./dist/superfastboot.efi
	ls -l ./dist

build_generic: clean
	cp -r ./Conf ./edk2/
	bash -c 'cd edk2 && . ./edksetup.sh && make BOARD_BOOTLOADER_PRODUCT_NAME=canoe TARGET_ARCHITECTURE=AARCH64 TARGET=RELEASE \
  		CLANG_BIN=/usr/bin/ CLANG_PREFIX=aarch64-linux-gnu- VERIFIED_BOOT_ENABLED=1 \
  		VERIFIED_BOOT_LE=0 AB_RETRYCOUNT_DISABLE=0 TARGET_BOARD_TYPE_AUTO=0 \
  		BUILD_USES_RECOVERY_AS_BOOT=0 DISABLE_PARALLEL_DOWNLOAD_FLASH=0 PVMFW_BCC_ENABLED=-DPVMFW_BCC\
  		REMOVE_CARVEOUT_REGION=1 QSPA_BOOTCONFIG_ENABLE=1 USER_BUILD_VARIANT=0 AUTO_PATCH_ABL=1 DISABLE_PRINT=1\
  		PREBUILT_HOST_TOOLS="BUILD_CC=clang BUILD_CXX=clang++ LDPATH=-fuse-ld=lld BUILD_AR=llvm-ar"' || true
	# test if the build is successful by checking the output file
	if [ ! -f edk2/Build/RELEASE_CLANG35/AARCH64/LinuxLoader.efi ]; then \
		echo "Build failed"; \
		exit 1; \
	fi
	cp edk2/Build/RELEASE_CLANG35/AARCH64/LinuxLoader.efi ./dist/generic_superfastboot.efi
	ls -l ./dist

test_exploit:
	@echo "This script is used to test the ABL exploit. Please make sure you tested before ota."
	@echo Please enter the Builtin Fastboot in the project. And put abl.img in the images folder. Press Enter to continue.
	@bash -c read -n 1 -s
	@python tools/extractfv.py ./images/abl.img ./ABL_original.efi
	@fastboot boot ./ABL_original.efi
	@echo 'If the exploit existed in the new abl image, the device will show two lines of "Press Volume Down key to enter Fastboot mode, waiting for 5 seconds into Normal mode..."'
	@echo 'If the exploit does not exist in the new abl image, the device will show red state screen'
	@rm ./ABL_original.efi
test_boot:
	$(MAKE) build HWCOUNTRY=GLOBAL
	fastboot boot ./dist/ABL_with_superfastboot.efi

test:
	bash ./tests/runall.sh
