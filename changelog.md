# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-08-27
### Added
- Add support for Haiku r1beta6

### Changed
- Install onto a virtio-scsi disk instead of a virtio-blk one. r1beta6 does not
  detect virtio-blk disks, and virtio-scsi is what the action boots the image
  with anyway
- Copy the r1beta5 image from the previous release instead of building it.
  Upstream has removed r1beta5's package repository, so the build can no longer
  install the extra packages

### Fixed
- Retry the package installation. A single failed download would fail the whole
  build

## [0.1.0] - 2026-04-29
### Changed
- Enable immutable releases ([action#140](https://github.com/cross-platform-actions/action/issues/140))

## [0.0.2] - 2025-12-12
### Fixed
- Fix non-fully qualified hostname ([action#113](https://github.com/cross-platform-actions/action/issues/113))

## [0.0.1] - 2025-05-19
### Added
- Initial release

[Unreleased]: https://github.com/cross-platform-actions/haiku-builder/compare/v0.2.0...HEAD

[0.2.0]: https://github.com/cross-platform-actions/haiku-builder/compare/v0.1.0...v0.2.0

[0.1.0]: https://github.com/cross-platform-actions/haiku-builder/compare/v0.0.2...v0.1.0

[0.0.2]: https://github.com/cross-platform-actions/haiku-builder/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/cross-platform-actions/haiku-builder/releases/tag/v0.0.1
