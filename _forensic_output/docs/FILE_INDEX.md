# FILE INDEX

Classification keys used: `source_code`, `config`, `documentation`, `test`, `build_artifact`, `unknown`.

## source_code

- `acabos-install` - installer orchestrator/state-machine entrypoint.
- `doctor/acabos-doctor` - invariant validation engine.
- `lib/common.sh` - shared runtime utilities and state/log helpers.
- `lib/topology.sh` - ZFS topology builder.
- `lib/detect_virt.sh` - runtime physical/virtual detector.
- `lib/probes.sh` - resume probes by stage.
- `lib/stage_preflight.sh`
- `lib/stage_input.sh`
- `lib/stage_disk_safety.sh`
- `lib/stage_zfs_create.sh`
- `lib/stage_base_install.sh`
- `lib/stage_boot_chain.sh`
- `lib/stage_nvidia_bringup.sh`
- `lib/stage_podman.sh`
- `lib/stage_desktop.sh`
- `lib/stage_ai.sh`
- `lib/stage_inference.sh`
- `lib/stage_validation.sh`
- `lib/stage_finalize.sh`
- `config/first-boot-setup` - first boot script.
- `config/start-desktop` - desktop launcher wrapper.
- `config/sway-nvidia` - environment wrapper for sway.
- `config/waybar/scripts/nvidia.sh` - Waybar GPU status script.
- `config/jupyter/jupyter_server_config.py` - executable Python config object assignment.
- `config/manifest-template.jq` - jq program template used for manifest generation.

## config

- `config/ai-system-packages.list`
- `config/ai-venv-requirements.txt`
- `config/apt-preferences`
- `config/apt-sources.list`
- `config/apt-trust.conf`
- `config/bashrc-aliases`
- `config/cuda-env.sh`
- `config/cuda-ldconfig.conf`
- `config/cudnn.version`
- `config/desktop-packages.list`
- `config/dracut.conf.d/zfs.conf`
- `config/first-boot.service`
- `config/issue`
- `config/mistral.version`
- `config/motd`
- `config/nvidia-container-toolkit.list`
- `config/nvidia-keyring.sha256`
- `config/nvidia-modprobe/nvidia.conf`
- `config/nvidia-modprobe/nvidia-drm.conf`
- `config/nvidia-modprobe/nvidia-uvm.conf`
- `config/nvidia-power.service`
- `config/nvidia-udev/70-nvidia.rules`
- `config/podman/containers.conf`
- `config/podman/registries.conf`
- `config/podman/storage.conf`
- `config/quadlets/ai-services.pod`
- `config/quadlets/ai-toolbox.container`
- `config/quadlets/comfyui.container`
- `config/quadlets/localai.container`
- `config/quadlets/ollama.container`
- `config/quadlets/ollama-webui.container`
- `config/quadlets/qdrant.container`
- `config/quadlets/stable-diffusion.container`
- `config/quadlets/text-generation-webui.container`
- `config/quadlets/whisper-asr.container`
- `config/ssh-hardening.conf`
- `config/sudoers-acabos`
- `config/sway/config`
- `config/sway/config.d/input`
- `config/sway/config.d/nvidia`
- `config/sway/config.d/output`
- `config/sysctl/99-hugepages.conf`
- `config/sysctl/99-performance.conf`
- `config/waybar/config`
- `config/waybar/style.css`
- `config/zfs-tuning.conf`
- `config/zfsbootmenu-config.yaml`

## documentation

- `README.md`
- `CONTRIBUTING.md`
- `docs/architecture.md`
- `docs/stage-reference.md`

## test

- None observed.

## build_artifact

- None observed in repository file set.

## unknown

- No unknown classified files in current tree.
