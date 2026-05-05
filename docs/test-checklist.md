# ACABOS Test Checklist

## 1. Pre-install sanity

From the live environment, confirm:

```bash
nvidia-smi
lsmod | grep nvidia
lspci | grep -Ei 'vga|3d|display'
ping -c 1 deb.debian.org
ping -c 1 ollama.com
ping -c 1 docker.io
```

Expected:
- GPU visible
- network works
- installer dependencies reachable

If you are intentionally testing an AMD or Intel path, expect GPU detection to continue with an experimental support tier rather than a supported NVIDIA path.

## 2. Run installer

Run the normal install path.

Watch especially for:
- `NVIDIA_BRINGUP`
- `AI_SUBSTRATE`
- `INFERENCE_SUBSTRATE`
- `FINALIZE`

Expected:
- no crash/fail in these stages
- no `ollama.container` references
- no `acab-inference.service` generation
- no hugepages sysctl install in default path

## 3. Before reboot, inspect target filesystem

Verify these exist:

```bash
ls /mnt/install/etc/systemd/system/ollama.service
ls /mnt/install/etc/systemd/system/acab-jupyter.service
ls /mnt/install/etc/systemd/system/acab-inference@.service
ls /mnt/install/etc/acabos/inference/example.env
ls /mnt/install/etc/containers/systemd/qdrant.container
ls /mnt/install/etc/containers/systemd/localai.container
ls /mnt/install/etc/containers/systemd/comfyui.container
```

Expected:
- all present

Also confirm these do not exist:

```bash
ls /mnt/install/etc/containers/systemd/ollama.container
ls /mnt/install/etc/containers/systemd/ollama-webui.container
ls /mnt/install/etc/containers/systemd/whisper-asr.container
ls /mnt/install/etc/containers/systemd/text-generation-webui.container
ls /mnt/install/etc/containers/systemd/stable-diffusion.container
ls /mnt/install/etc/containers/systemd/ai-toolbox.container
ls /mnt/install/etc/systemd/system/acab-inference.service
```

Expected:
- missing / not found

## 4. Hugepages check

Before reboot or after first boot:

```bash
grep -R "nr_hugepages" /mnt/install/etc/sysctl.d /etc/sysctl.d 2>/dev/null
```

Expected:
- no default hugepages file installed for target

After boot:

```bash
cat /proc/sys/vm/nr_hugepages
```

Expected:
- `0` unless manually changed

## 5. SSH default check

After first boot:

```bash
systemctl status ssh.service --no-pager
ss -tln | grep ':22'
```

Expected:
- `ssh.service` active
- port 22 listening

Also inspect:

```bash
grep -E 'PermitRootLogin|PasswordAuthentication|X11Forwarding' /etc/ssh/sshd_config.d/hardening.conf
```

Expected:
- `PermitRootLogin no`
- `PasswordAuthentication yes`
- `X11Forwarding no`

## 6. First-boot service check

After first login:

```bash
systemctl status first-boot.service --no-pager
cat /etc/acabos/first-boot-done
ls /etc/acabos/runtime-readiness.*
```

Expected:
- first-boot completed
- marker file exists
- readiness TSV/log exist

## 7. Review first-boot report

```bash
cat /etc/acabos/runtime-readiness.tsv
less /etc/acabos/runtime-readiness.log
```

Expected rows to inspect:
- `gpu_vendor`
- `gpu_support_tier`
- `gpu_runtime_target`
- `gpu_validation_policy`
- `cdi`
- `podman`
- `gpu-container-smoke`
- `ollama.service`
- `qdrant:image`
- `qdrant.service`
- `localai:image`
- `localai.service`
- `comfyui:image`
- `comfyui.service`
- `acab-jupyter.service`

What you want:
- `pass` for runtime essentials
- if `localai` or `comfyui` fail, capture exact log lines
- on non-NVIDIA systems, explicit `skip` rows for NVIDIA-only validation are acceptable and expected

## 8. Native Ollama check

```bash
which ollama
systemctl status ollama.service --no-pager
ollama --version
```

Expected:
- `/usr/local/bin/ollama`
- service active or installed correctly
- version prints cleanly

## 9. `mistral.rs` check

```bash
/opt/acab/bin/mistral-rs --version
/opt/acab/bin/mistral-rs doctor
ls /etc/acabos/inference/
systemctl cat 'acab-inference@.service'
```

Expected:
- binary present
- doctor passes
- `example.env` exists
- templated service exists

## 10. Jupyter check

```bash
systemctl status acab-jupyter.service --no-pager
cat /etc/acabos/jupyter.env
grep -E 'ip|token|allow_origin|allow_root' /etc/jupyter/jupyter_server_config.py
```

Expected:
- service installed but disabled/inactive by default
- token exists
- config shows:
  - `127.0.0.1`
  - token from env
  - no wildcard origin
  - `allow_root = False`

Then enable manually:

```bash
sudo systemctl enable acab-jupyter.service
sudo systemctl start acab-jupyter.service
systemctl status acab-jupyter.service --no-pager
ss -tln | grep 8888
```

Expected:
- active
- listening only on `127.0.0.1:8888`

## 11. Home-folder docs check

As installed user:

```bash
ls ~/RELEASE-NOTES.md ~/FIRST-STEPS.md
sed -n '1,80p' ~/RELEASE-NOTES.md
sed -n '1,120p' ~/FIRST-STEPS.md
```

Expected:
- files present
- placeholders rendered
- Jupyter token present
- username/path/version fields filled in

## 12. Retained container unit check

```bash
grep '^Image=' /etc/containers/systemd/qdrant.container
grep '^Image=' /etc/containers/systemd/localai.container
grep '^Image=' /etc/containers/systemd/comfyui.container
grep '^AddDevice=' /etc/containers/systemd/localai.container
grep '^AddDevice=' /etc/containers/systemd/comfyui.container
```

Expected:
- digest-pinned images
- `AddDevice=nvidia.com/gpu=all`

## 13. Podman generator/systemd check

```bash
systemctl daemon-reload
journalctl -b --no-pager | grep -i 'unsupported key'
```

Expected:
- no quadlet parser warnings
- especially no `unsupported key 'Device'`

## 14. Container service spot checks

```bash
systemctl status qdrant.service --no-pager
systemctl status localai.service --no-pager
systemctl status comfyui.service --no-pager
```

Expected:
- if enabled by first boot, active
- if failed, logs should explain why

Check endpoints:

```bash
ss -tln | grep -E '6333|6334|8081|8188'
```

Expected:
- only services that passed should be listening

## 15. Memory sanity after boot

```bash
free -h
cat /proc/sys/vm/nr_hugepages
```

Expected:
- no mysterious 16 GB reservation from hugepages
- `nr_hugepages = 0`

## Pass / Fail Criteria

### Hard pass
- installer completes
- first-boot completes
- `ollama` native works
- `mistral-rs doctor` passes
- Jupyter secure local-only setup works
- no invalid quadlet warnings
- hugepages not reserved by default
- GPU support tier is recorded explicitly in readiness output

### Acceptable partial pass
- `qdrant` passes
- one of `localai` or `comfyui` fails, but failure is explicit and logged
- AMD or Intel systems continue install and are clearly marked experimental

### Fail
- first-boot loops or bricks services
- `ollama` native install fails
- `acab-inference@.service` missing/broken
- Jupyter binds to `0.0.0.0`
- hugepages still reserved by default
- unsupported quadlet syntax warnings still appear
- GPU vendor/support tier is missing or contradictory in readiness output
