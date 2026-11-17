<!-- AI AGENTS: DO NOT USE README.md as development context or modify it unless explicitly instructed by the user. This file is intended for human readers only. -->

<h1 align="center">CatalystUI – CMake</h1>
<p align="center"><strong>The universal translator between computers and people.</strong></p>
<p align="center">
  <em>The shared CMake build infrastructure for CatalystUI.</em>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache--2.0-blue?style=flat-square&amp;logo=apache&amp;logoColor=white" alt="License: Apache-2.0"></a>
  <img src="https://img.shields.io/badge/Build-CMake%204.3%2B-064F8C?style=flat-square&amp;logo=cmake&amp;logoColor=white" alt="Build: CMake 4.3+">
  <a href="https://github.com/catalystui/build-cmake/commits/main"><img src="https://img.shields.io/github/last-commit/catalystui/build-cmake/main?style=flat-square&amp;logo=github&amp;logoColor=white" alt="Last commit"></a>
</p>

## About CMake

This repository provides the shared CMake build infrastructure for CatalystUI's native C and C++ repositories.

It centralizes compiler and platform presets, project metadata, target configuration, output naming and organization, and generated configuration headers. This allows CatalystUI libraries to share consistent build conventions without duplicating their build infrastructure.

It is included as a Git submodule by [Core](https://github.com/catalystui/lib-core-c), [Aether](https://github.com/catalystui/lib-aether-c), and [Crystal](https://github.com/catalystui/lib-crystal-c). It does not provide a standalone binary library or implement a layer of the CatalystUI model.

## Development Status

> [!NOTE]
> The shared build infrastructure is in use by the native CatalystUI repositories and is under active development. Presets cover both modern and legacy toolchains, but the presence of a preset does not imply verified compile or runtime support.

The shared platform configuration currently recognizes Windows, macOS, and Linux. DOS presets are also defined, but DOS is not yet handled by the shared platform configuration.

## Build Infrastructure

| File | Description |
| --- | --- |
| [CMakePresets.json](CMakePresets.json) | Shared configure and build presets for target platforms, architectures, and toolchains. |
| [CMakeInit.cmake](CMakeInit.cmake) | Shared functions for project metadata, platform and target configuration, generated headers, Wayland protocol generation, and test executables. |
| [CMakeConfig.h](CMakeConfig.h) | Template for a generated C/C++ header containing project metadata and target platform information. |

## Getting Started

The build infrastructure uses **CMake 4.3 or later**, Git, and a C/C++ toolchain appropriate for the selected build preset.

The repository is intended to be used through a consuming project rather than built directly. For example, clone Core along with its shared build infrastructure:

```powershell
git clone --recurse-submodules https://github.com/catalystui/lib-core-c.git
Set-Location lib-core-c
cmake --list-presets
```

If the consuming repository has already been cloned, initialize its submodule with:

```powershell
git submodule update --init --recursive
```

The shared presets define target-specific compiler and platform configurations. For example, on an Apple Silicon Mac with the required Xcode toolchain, Core can be configured and built with:

```powershell
cmake --preset aclang17-darwin24.6-arm64
cmake --build --preset aclang17-darwin24.6-arm64-release
```

Consuming repositories include the shared presets from `cmake/CMakePresets.json` and the shared CMake functions from `cmake/CMakeInit.cmake`. Each repository defines its own project and build targets.

## AI-Assisted Development

The shared build infrastructure is developed with AI assistance under human direction. AI coding agents assist with implementation and repository maintenance, while the project owner defines the model, requirements, and design decisions.

AI-assisted contributions are subject to the same expectations for correctness, maintainability, attribution, and licensing as human-written contributions. Their presence does not imply independent line-by-line human review.

## License

The original source code and documentation in this repository are licensed under the [Apache License 2.0](LICENSE).
