obj-$(CONFIG_BBG) += baseband_guard.o

GIT_BIN := /usr/bin/env PATH="$$PATH":/usr/bin:/usr/local/bin git

COMMIT_SHA := $(shell cd $(srctree)/$(src) && $(GIT_BIN) rev-parse --short=8 HEAD 2>/dev/null)

ifeq ($(strip $(COMMIT_SHA)),)
  COMMIT_SHA := unknown
endif

$(info -- BBG was enabled!)
$(info -- BBG version: $(COMMIT_SHA))
ccflags-y += -DBBG_VERSION=$(COMMIT_SHA)

# ---------------------------------------------------------------------
# CONFIG_LSM Check (delayed shell-based check so .config is already loaded)
# ---------------------------------------------------------------------
ifeq ($(CONFIG_BBG),y)
$(info -- Baseband-guard: CONFIG_BBG enabled, now checking LSM setup...)
$(shell \
if ! echo "$(CONFIG_LSM)" | grep -q baseband_guard; then \
echo "ERROR: Baseband_guard not found in CONFIG_LSM!"; \
echo "Please follow Baseband-guard's README.md to integrate properly."; \
exit 1; \
else \
echo "-- Baseband-guard: OK, baseband_guard found in CONFIG_LSM"; \
fi)
endif
