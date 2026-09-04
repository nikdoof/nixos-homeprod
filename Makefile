# Makefile — deploy NixOS configurations.
#
# Two strategies, depending on the host:
#   * svc-01, svc-02, hyp-01, gw  -> build locally on the target (run the `nrs`
#     zsh alias: `sudo nixos-rebuild switch --refresh --flake
#     github:nikdoof/nixos-homeprod#$(hostname)`).
#   * ns-01 .. ns-04              -> build on svc-02 and push to the target over
#     SSH (c.f. scripts/update-ns.sh), since those hosts can't build themselves.
#
# Because `nrs` is a shell *alias*, the local command is executed through an
# interactive login shell so the alias is expanded.
#
# Usage:
#   make                # deploy all hosts in sequence
#   make svc-01         # deploy a single host
#   make ns-01          # build ns-01 from svc-02
#   make all            # deploy all hosts in sequence

BUILD_HOST ?= svc-02.int.doofnet.uk
FLAKE      ?= github:nikdoof/nixos-homeprod

# Shell on the target used to expand the `nrs` alias (override if not zsh).
REMOTE_SHELL ?= zsh

# Hosts that build locally on themselves.
LOCAL_SYSTEMS := svc-01 svc-02 hyp-01 gw

# Hosts that are built on BUILD_HOST and deployed over SSH.
REMOTE_SYSTEMS := ns-01 ns-03 ns-04

# Map a remote host to its deploy FQDN.
fqdn = $(if $(filter ns-01,$1),ns-01.int.doofnet.uk,\
          $(if $(filter ns-03,$1),ns-03.doofnet.uk,\
          $(if $(filter ns-04,$1),ns-04.doofnet.uk,$1))))

SYSTEMS := $(LOCAL_SYSTEMS) $(REMOTE_SYSTEMS)

.PHONY: all $(SYSTEMS)

all: $(SYSTEMS)

# Local build: SSH to the host and run `nrs` there.
$(LOCAL_SYSTEMS):
	@echo "==> Deploying $@ (local)"; \
	ssh -t "$@.int.doofnet.uk" $(REMOTE_SHELL) -ic "nrs"; \
	echo "    [ok] $@ done"

# Remote build: SSH to BUILD_HOST and run nixos-rebuild against the target.
$(REMOTE_SYSTEMS):
	@echo "==> Deploying $@ via $(BUILD_HOST)"; \
	ssh -t "$(BUILD_HOST)" \
		nixos-rebuild switch --refresh \
		--flake "$(FLAKE)#$@" \
		--target-host "$(strip $(call fqdn,$@))" \
		--sudo; \
	echo "    [ok] $@ done"
