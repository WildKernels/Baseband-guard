bbg-objs += baseband_guard.o
bbg-objs += tracing/tracing.o

ccflags-y += -I$(srctree)/security/selinux -I$(srctree)/security/selinux/include
ccflags-y += -I$(objtree)/security/selinux -include $(srctree)/include/uapi/asm-generic/errno.h

obj-$(CONFIG_BBG) += bbg.o

BBG_CLEAN_GOALS := $(filter clean mrproper distclean,$(MAKECMDGOALS))

BBG_SELINUX_OUT := $(objtree)/security/selinux
BBG_FLASK_H := $(BBG_SELINUX_OUT)/flask.h
BBG_AV_PERM_H := $(BBG_SELINUX_OUT)/av_permissions.h
BBG_GENHEADERS := $(objtree)/bbg_genheaders

$(BBG_GENHEADERS): $(srctree)/scripts/selinux/genheaders/genheaders.c
	$(HOSTCC) -I$(srctree)/scripts/selinux/genheaders -Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89 -I$(srctree)/include/uapi -I$(srctree)/include -I$(srctree)/security/selinux/include -fuse-ld=lld -o $@ $< 2>/dev/null || $(HOSTCC) -I$(srctree)/scripts/selinux/genheaders -Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89 -I$(srctree)/include/uapi -I$(srctree)/include -I$(srctree)/security/selinux/include -o $@ $<

$(BBG_FLASK_H) $(BBG_AV_PERM_H): $(BBG_GENHEADERS)
	mkdir -p $(BBG_SELINUX_OUT)
	$(BBG_GENHEADERS) flask.h av_permissions.h
	mv $(objtree)/flask.h $(objtree)/av_permissions.h $(BBG_SELINUX_OUT)

ifeq ($(strip $(BBG_CLEAN_GOALS)),)
$(addprefix $(obj)/,$(bbg-objs)): $(BBG_FLASK_H) $(BBG_AV_PERM_H)
endif

GIT_BIN := /usr/bin/env PATH="$$PATH":/usr/bin:/usr/local/bin git

ifeq ($(findstring $(srctree),$(src)),$(srctree))
  BBG_DIR := $(src)
else
  BBG_DIR := $(srctree)/$(src)
endif

$(shell cd $(BBG_DIR) && test -f .git/shallow && $(GIT_BIN) fetch --unshallow)

REPO_LINK := $(shell cd $(BBG_DIR) && $(GIT_BIN) remote get-url origin 2>/dev/null)
COMMIT_SHA := $(shell cd $(BBG_DIR) && $(GIT_BIN) rev-parse --short=8 HEAD 2>/dev/null)

ifeq ($(strip $(REPO_LINK)),)
  REPO_LINK := unknown
endif
ifeq ($(strip $(COMMIT_SHA)),)
  COMMIT_SHA := unknown
endif

ifeq ($(shell grep -q "file_ioctl_compat" $(srctree)/include/linux/lsm_hook_defs.h $(srctree)/include/linux/lsm_hooks.h 2>/dev/null && echo true),true)
    ccflags-y += -DBB_HAS_IOCTL_COMPAT
endif

HAS_DEFINE_LSM := $(shell grep -q "\#define DEFINE_LSM(lsm)" $(srctree)/include/linux/lsm_hooks.h 2>/dev/null && echo true)
BBG_HAS_AUTOCONF := $(wildcard $(objtree)/include/config/auto.conf)

ifeq ($(CONFIG_BBG),y)
  $(info -- Baseband-guard: CONFIG_BBG enabled, now checking...)
  $(info -- Kernel Version: $(VERSION).$(PATCHLEVEL))
  ifeq ($(HAS_DEFINE_LSM),true)
    $(info -- Baseband_guard: Found DEFINE_LSM,now checking CONFIG_LSM...)
    $(info -- CONFIG_LSM value: $(CONFIG_LSM))
    ifneq ($(strip $(BBG_CLEAN_GOALS)),)
      $(info -- Baseband-guard: Skipping CONFIG_LSM check for $(BBG_CLEAN_GOALS))
    else ifeq ($(strip $(BBG_HAS_AUTOCONF)),)
      $(info -- Baseband-guard: No autoconf yet, skipping CONFIG_LSM check)
    else ifeq ($(strip $(CONFIG_LSM)),)
      $(info -- Baseband-guard: CONFIG_LSM not set yet, skipping check)
    else
      ifneq ($(findstring baseband_guard,$(CONFIG_LSM)),baseband_guard)
        $(info -- Baseband-guard: BBG not enable in CONFIG_LSM, but CONFIG_BBG is y,abort...)
        $(error Please follow Baseband-guard's README.md, to correct integrate)
      else
        $(info -- Baseband-guard: Okay, Baseband_guard was found in CONFIG_LSM)
        ccflags-y += -DBBG_USE_DEFINE_LSM
      endif
    endif
  else
    $(info -- Baseband-guard: Okay,seems this Kernel doesn't need to check config.)
  endif
endif

$(info -- BBG was enabled!)
$(info -- BBG version: $(COMMIT_SHA))
$(info -- BBG repo: $(REPO_LINK))
ccflags-y += -DBBG_VERSION=\"$(COMMIT_SHA)\"
ccflags-y += -DBBG_REPO=\"$(REPO_LINK)\"
