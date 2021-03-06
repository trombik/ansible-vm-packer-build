# Building virtual machine images for `ansible` with packer

## Purposes

This project aims at creating virtual machine images, suitable for `ansible`
play in local virtual environment, specifically:

* Installing required packages
* Creating local user
* Modifying the default installations to improve performance in the
  environment (faster boot process, appropriate resource URLs, etc)

The project provides not only means to build reproducible images, also means
to verify the results by written specs.

## Rationales

To develop `ansible` roles, virtual machines are required to test roles.
Official virtual machine images are publicly available, but they are plain
default installations. It is possible to use them in `ansible` role
development, but installing required applications, such as `python` and
`sudo`, is a major overhead. Creating virtual machine images ready for
`ansible` play right after boot remove the overhead.

## Support policy

As described in the Purposes, platforms in the project are primary targets of
my `ansible-role-*`.  The targeted platforms are:

* FreeBSD
* OpenBSD
* Ubuntu
* CentOS

A platform release remains in the repository as long as the image is able to
built, even when the release is no longer officially supported.

A platform release will be removed from the repository when:

* The installation resource of the release is not available (ISO image is not
  available)
* The build fails due to external factors (package repository does not support
  the release)

The project support officially _deprecated_ releases just for development
purpose only.

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

## Typical workflows

### Fixing an issue in a VM image

Here, it is assumed that you are going to fix an issue in FreeBSD 11.1 image.

Add a spec example to one of spec files under
[`spec`](https://github.com/trombik/ansible-vm-packer-build/tree/master/spec).
See [Resource Types](http://serverspec.org/resource_types.html) if you are not
familiar with `serverspec`.

Modify the JSON file of the VM image.

```
vim freebsd-11.1-amd64.json
```

Build the image.

```
bundle exec rake build:freebsd-11.1-amd64
```

After successful build, perform test on the image.

```
bundle exec rake test:spec:freebsd-11.1-amd64:virtualbox-iso
```

After successful test, update `config.yml`:

* Increase `version` number

Upload the box.

```
rake upload:virtualbox:freebsd-11.1-amd64
```

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

### `test:all`

Perform all tests.

### `test:ci`

Perform tests intended for CI environment.

### `test:rubocop`

Run `rubocop`.

### `test:iso_url`

Test if all `iso_url` in all JSON files are available by requesting HTTP
`HEAD` requests.

### `test:spec:all`

Imports all created `.box` files, boots a VM, and run `rspec`.

### `test:spec:$BOXNAME:$PROVIDER`

Imports a created `.box` file, boots a VM, and run `rspec`. An example:

```
test:spec:freebsd-11.1-amd64:virtualbox-iso
```

### `test:clean:all`

Destroys all the VM.

### `test:clean:box`

Removes all `.box` files.

### `upload:all`

Uploads all boxes.

Environment variable `VAGRANT_CLOUD_TOKEN` must be set.

### `upload:$PROVIDER:$BOXNAME`

Upload a box.

Environment variable `VAGRANT_CLOUD_TOKEN` must be set.

```
rake upload:virtualbox:freebsd-11.1-amd64
```

## When in trouble

### A VM locks up during installation

When a guest locks up, i.e. you cannot stop it, the following commands stop
the VM.

First, find out the VM name with `packer-` prefix.

```
VBoxManage list vms
```

Forcibly stop the VM with undocumented `--type emergencystop` option.

```
VBoxManage startvm packer-openbsd-6.0-amd64 --type emergencystop
```

The disks and files are not removed. You need to remove them manually.

### FreeBSD host and `aio` issue

This issue applies to virtualbox-ose-5.2.2, probably earlier versions.

FreeBSD is not a supported _host_ OS by `virtualbox`. When a _guest_ OS issues
lots of I/O, the OS returns `E_AGAIN`, and the `virtualbox` does not handle
the error properly. See issue
[168298](https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=168298) and issue
[212128](https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=212128).

On my local machine, the following `sysctl(8)` values work for me. YMMV.

```
vfs.aio.max_aio_queue=8192
vfs.aio.max_aio_queue_per_proc=4096
vfs.aio.max_aio_per_proc=128
vfs.aio.max_buf_aio=64
```

Also, on some platforms, SATA disk device is chosen. On my 2018-03-08 CURRENT
host OS, SCCI device makes the HOST freeze. It might be due to the issue
above, or due to the underlying driver, nvme(4). Some have reported issues
with the driver. See
[211713](https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=211713).
