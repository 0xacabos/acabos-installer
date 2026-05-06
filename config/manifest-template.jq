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
    early_graphics: $egfx,
    runtime_critical: [
      {name: "podman", version: $pv, status: "installed"}
    ]
  },
  inference: {
    runtime: "mistral.rs",
    runtime_required: true,
    profile_driven: true
  },
  native_services: {
    services: $nsvcs
  },
  containers: {
    runtime: "podman",
    services: $csvcs
  },
  graphics: {
    gpu_detected: ($gd == "true"),
    gpu_vendor: $gv,
    gpu_model: $gm,
    gpu_count: ($gc | tonumber),
    gpu_support_tier: $gst,
    gpu_runtime_target: $grt,
    gpu_validation_policy: $gvp,
    gpu_required: true,
    drm_modeset_required: ($grt == "cuda")
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
