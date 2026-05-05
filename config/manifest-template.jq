{
  schema_version: $sv,
  manifest_kind: $mk,
  install_id: $iid,
  generated_at: $ts,
  topology_version: $tv,
  doctor_schema_version: $dsv,
  station: {
    hostname: $hn,
    station_id: $iid,
    profile: "acabos-baseline-reference-deployment-v0.1",
    platform_class: "baseline-ai-development-station",
    architecture: "x86_64",
    username: $un
  },
  target_disk: {
    by_id: $td,
    wipe_confirmed: true
  },
  zfs: {
    pool_name: $pn,
    pool_guid: $pg,
    encryption_enabled: true,
    topology_version: $tv
  },
  compatibility_cohort: {
    boot_critical: [
      {name: "linux-image-amd64", version: $kv, status: "installed"},
      {name: "linux-headers-amd64", version: $hv, status: "installed"},
      {name: "zfsutils-linux", version: $zv, status: "installed"}
    ],
    early_graphics: [
      {name: "nvidia-driver", version: $nv, status: "installed"}
    ],
    runtime_critical: [
      {name: "podman", version: $pv, status: "installed"}
    ]
  },
  inference: {
    runtime: "mistral.rs",
    runtime_required: true
  },
  containers: {
    runtime: "podman",
    services: ["ollama","ollama-webui","ai-toolbox","stable-diffusion","comfyui","text-generation-webui","localai","whisper-asr","qdrant"]
  },
  graphics: {
    gpu_vendor: "nvidia",
    gpu_required: true,
    drm_modeset_required: true
  },
  desktop: {
    environment: "sway",
    compositor: "wayland"
  },
  ai_stack: {
    python_version: $pyv,
    pytorch_version: $tv2,
    venv_path: "/opt/ai-venv",
    llama_cpp: true
  },
  result: {
    status: "success",
    success: true
  },
  log_artifacts: $la
}
