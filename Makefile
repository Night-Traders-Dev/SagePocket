# SagePocket build system.
#
# Requires:
#   - sage compiler  (SageLang >= 4.1.7, see plan.md Appendix)
#   - arm-none-eabi-gcc (in PATH)            -- ARM (Cortex-M33) builds
#   - riscv32-unknown-elf-gcc (in PATH)      -- RISC-V (Hazard3) builds
#   - picotool, cmake, ninja/make
#   - PICO_SDK_PATH (or --sdk via SAGE_FLAGS)
#
# Targets:
#   make all         build everything for both architectures
#   make arm         build ARM (Cortex-M33) UF2s
#   make rv          build RISC-V (Hazard3) UF2s
#   make sageboot    boot/sageboot.sage
#   make hal         kernel/hal.sage
#   make host-test   host smoke test of SageBoot logic
#   make test        full Phase 0 test suite
#   make clean       remove build output

SAGE        ?= sage
BOARD       ?= waveshare_rp2350_lcd_1_47
SDK         ?= $(abspath .deps/pico-sdk)
BUILD_DIR   ?= build

ARM_FLAGS   = --board $(BOARD) --chip rp2350-arm --sdk $(SDK) --board-dir boards
RV_FLAGS    = --board $(BOARD) --chip rp2350-riscv --sdk $(SDK) --board-dir boards

UF2_ARM     = $(BUILD_DIR)/arm
UF2_RV      = $(BUILD_DIR)/rv

SAGE_BOOT_SRC = boot/sageboot.sage
HAL_SRC       = kernel/hal.sage

ALL_SRC = $(SAGE_BOOT_SRC) $(HAL_SRC)

.PHONY: all arm rv sageboot hal host-test test clean

all: arm rv

arm: $(UF2_ARM)/sageboot/$(BOARD)-sageboot-arm.uf2 \
     $(UF2_ARM)/hal/$(BOARD)-hal-arm.uf2

rv: $(UF2_RV)/sageboot/$(BOARD)-sageboot-rv.uf2 \
    $(UF2_RV)/hal/$(BOARD)-hal-rv.uf2

# Build a UF2 for one program and one architecture.
# $1 = source, $2 = name, $3 = chip flags, $4 = output dir, $5 = suffix
# NOTE: the sage compiler sanitizes names; keep them [-_a-zA-Z0-9].
define build-uf2
$(4)/$(2)/$(BOARD)-$(2)-$(5).uf2: $(1)
	@mkdir -p $$(dir $$@)
	$(SAGE) --compile-pico $(1) -o $(4)/$(2) \
		--name $(subst -,_,$(BOARD)-$(2)-$(5)) $(3) 2>&1 | tail -n 1
	@cp $(4)/$(2)/build/$(subst -,_,$(BOARD)-$(2)-$(5)).uf2 $$@
endef

$(eval $(call build-uf2,$(SAGE_BOOT_SRC),sageboot,$(ARM_FLAGS),$(UF2_ARM),arm))
$(eval $(call build-uf2,$(SAGE_BOOT_SRC),sageboot,$(RV_FLAGS),$(UF2_RV),rv))
$(eval $(call build-uf2,$(HAL_SRC),hal,$(ARM_FLAGS),$(UF2_ARM),arm))
$(eval $(call build-uf2,$(HAL_SRC),hal,$(RV_FLAGS),$(UF2_RV),rv))

sageboot: $(UF2_ARM)/sageboot/$(BOARD)-sageboot-arm.uf2 \
          $(UF2_RV)/sageboot/$(BOARD)-sageboot-rv.uf2

hal: $(UF2_ARM)/hal/$(BOARD)-hal-arm.uf2 \
     $(UF2_RV)/hal/$(BOARD)-hal-rv.uf2

host-test:
	@tests/run.sh host

test:
	@tests/run.sh

clean:
	rm -rf $(BUILD_DIR) .tmp
