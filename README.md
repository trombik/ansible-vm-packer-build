# Building virtual machine images with packer

## Rationales

To develop `ansible` roles, virtual machines are required to test roles.
Official virtual machine images are publicly available, but they are plain
default installations. It is possible to use them in `ansible` role
development, but installing required applications, such as `python` and
`sudo`, is a major overhead. Creating virtual machine images ready for
`ansible` play right after boot remove the overhead.

## Purposes

This project aims at creating virtual machine images, suitable for `ansible`
play in local virtual environment, specifically:

* Installing required packages
* Creating local user
* Modifying the default installations to improve performance in the
  environment (faster boot process, appropriate resource URLs, etc)

The project provides not only means to build reproducible images, also means
to verify the results by written specs.

## Usage

Choose a directory to keep vendor files. Here, `vendor` in the project
directory is used. The path can be anywhere you have write access to.

```
cd ansible-vm-packer-build
bundle install --path vendor
```

## Requirements

* `Virtualbox`
* `packer`
* `ruby`
* `bundler`

## Targets

The whole build process is implemented by a `Rakefile`. Each task is
implemented in a target in the `Rakefile`.

The following command shows all available targets.

```
bundle exec rake -T
```

### `build`

The `build` target builds one or more boxes.

```
bundle exec rake build:openbsd-6.2-amd64
```
