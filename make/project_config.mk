# Makefile support for the menuconfig system

#Find all Kconfig files for all components
COMPONENT_KCONFIGS := $(foreach component,$(COMPONENT_PATHS),$(wildcard $(component)/Kconfig))
COMPONENT_KCONFIGS_PROJBUILD := $(foreach component,$(COMPONENT_PATHS),$(wildcard $(component)/Kconfig.projbuild))

#For doing make menuconfig etc
KCONFIG_TOOL_DIR=$(IDF_PATH)/tools/kconfig

# set SDKCONFIG to the project's sdkconfig,
# unless it's overriden (happens for bootloader)
SDKCONFIG ?= $(PROJECT_PATH)/sdkconfig

# reset MAKEFLAGS as the menuconfig makefile uses implicit compile rules
$(KCONFIG_TOOL_DIR)/mconf $(KCONFIG_TOOL_DIR)/conf:
	MAKEFLAGS=$(ORIGINAL_MAKEFLAGS) CC=$(HOSTCC) LD=$(HOSTLD) \
	$(MAKE) -C $(KCONFIG_TOOL_DIR)

# use a wrapper environment for where we run Kconfig tools
KCONFIG_TOOL_ENV=KCONFIG_AUTOHEADER=$(abspath $(BUILD_DIR_BASE)/include/sdkconfig.h) \
	COMPONENT_KCONFIGS="$(COMPONENT_KCONFIGS)" KCONFIG_CONFIG=$(SDKCONFIG) \
	COMPONENT_KCONFIGS_PROJBUILD="$(COMPONENT_KCONFIGS_PROJBUILD)"

menuconfig: $(KCONFIG_TOOL_DIR)/mconf $(IDF_PATH)/Kconfig $(BUILD_DIR_BASE)
	$(summary) MENUCONFIG
	$(Q) $(KCONFIG_TOOL_ENV) $(KCONFIG_TOOL_DIR)/mconf $(IDF_PATH)/Kconfig

ifeq ("$(wildcard $(SDKCONFIG))","")
#No sdkconfig found. Need to run menuconfig to make this if we need it.
$(SDKCONFIG): menuconfig
endif

defconfig: $(KCONFIG_TOOL_DIR)/mconf $(IDF_PATH)/Kconfig $(BUILD_DIR_BASE)
	$(summary) DEFCONFIG
	$(Q) mkdir -p $(BUILD_DIR_BASE)/include/config
	$(Q) $(KCONFIG_TOOL_ENV) $(KCONFIG_TOOL_DIR)/conf --olddefconfig $(IDF_PATH)/Kconfig

# Work out of whether we have to build the Kconfig makefile
# (auto.conf), or if we're in a situation where we don't need it
NON_CONFIG_TARGETS := clean %-clean get_variable help menuconfig defconfig
AUTO_CONF_REGEN_TARGET := $(BUILD_DIR_BASE)/include/config/auto.conf

# disable AUTO_CONF_REGEN_TARGET if all targets are non-config targets
# (and not building default target)
ifneq ("$(MAKECMDGOALS)","")
ifeq ($(filter $(NON_CONFIG_TARGETS), $(MAKECMDGOALS)),$(MAKECMDGOALS))
AUTO_CONF_REGEN_TARGET :=
# dummy target
$(BUILD_DIR_BASE)/include/config/auto.conf:
endif
endif

$(AUTO_CONF_REGEN_TARGET) $(BUILD_DIR_BASE)/include/sdkconfig.h: $(SDKCONFIG) $(KCONFIG_TOOL_DIR)/conf $(COMPONENT_KCONFIGS) $(COMPONENT_KCONFIGS_PROJBUILD)
	$(summary) GENCONFIG
	$(Q) mkdir -p $(BUILD_DIR_BASE)/include/config
	$(Q) cd $(BUILD_DIR_BASE); $(KCONFIG_TOOL_ENV) $(KCONFIG_TOOL_DIR)/conf --silentoldconfig $(IDF_PATH)/Kconfig
	$(Q) touch $(AUTO_CONF_REGEN_TARGET) $(BUILD_DIR_BASE)/include/sdkconfig.h
# touch to ensure both output files are newer - as 'conf' can also update sdkconfig (a dependency). Without this,
# sometimes you can get an infinite make loop on Windows where sdkconfig always gets regenerated newer
# than the target(!)

clean: config-clean
.PHONY: config-clean
config-clean:
	$(summary RM CONFIG)
	$(MAKE) -C $(KCONFIG_TOOL_DIR) clean
	$(Q) rm -rf $(BUILD_DIR_BASE)/include/config $(BUILD_DIR_BASE)/include/sdkconfig.h
