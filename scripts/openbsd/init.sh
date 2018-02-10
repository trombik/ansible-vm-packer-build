#!/bin/ksh

set -e
set -x

# pkg.conf has been replaced with installurl since 6.1
if [ `uname -r` == 5.9 -o `uname -r` == 6.0 ]; then
    sudo tee /etc/pkg.conf <<EOF
installpath = fastly.cdn.openbsd.org
EOF
fi

sudo pkg_add ansible rsync--
sudo ln -sf /usr/local/bin/python2.7 /usr/local/bin/python
sudo ln -sf /usr/local/bin/python2.7-2to3 /usr/local/bin/2to3
sudo ln -sf /usr/local/bin/python2.7-config /usr/local/bin/python-config
sudo ln -sf /usr/local/bin/pydoc2.7  /usr/local/bin/pydoc

sudo pkg_add curl

sudo tee /etc/rc.conf.local <<EOF
sndiod_flags=NO
sendmail_flags=NO
EOF

# XXX OPENBSD_6_2 has a patch, skip it
if [ `uname -r` != '6.2' ]; then

    # ensure that only `ansible` is installed from our ports tree
    # XXX `OPENBSD_6_2` has a fix, others need fixes in our ports tree
    sudo pkg_delete ansible
    ftp -o - https://github.com/reallyenglish/ports/archive/RE_`uname -r | sed -e 's/[.]/_/'`.tar.gz | sudo tar -C /usr -zxf -
    sudo mv /usr/ports-RE_`uname -r | sed -e 's/[.]/_/'` /usr/ports
    ( cd /usr/ports/sysutils/ansible && sudo make install clean && sudo rm -rf /usr/ports/* )
fi

# replace buggy openbsd_pkg.py with the latest, and known-to-work, one.
# fixes https://github.com/reallyenglish/ansible-role-postfix/issues/13 and
# others
# XXX remove the workaround below when 5.9 has the latest ansible
if [ `uname -r` == '5.9' ]; then
    sudo ftp -o /usr/local/lib/python2.7/site-packages/ansible/modules/extras/packaging/os/openbsd_pkg.py https://raw.githubusercontent.com/ansible/ansible/b134352d8ca33745c4277e8cb85af3ad2dcae2da/lib/ansible/modules/packaging/os/openbsd_pkg.py
elif [ `ansible --version | head -n 1 | cut -d' ' -f 2` == '2.3.2.0' -a `uname -r` != '6.2' ]; then

# apply a patch obtained from:
# https://raw.githubusercontent.com/ansible/ansible/b1b90024e53614e556a23191eae4e9c262d05154/lib/ansible/modules/packaging/os/openbsd_pkg.py
#
# XXX however, the PR, #26016, introduced a bug, which failed to parse a valid
# name, `jdk--%1.8`. added my fix in regexp.
#
# XXX this patch should be applied in our ports tree, but we desparately need
# package builder first. remove this when the builder is ready.
#
    sudo patch -t -p3 -d /usr/local/lib/python2.7/site-packages/ansible <<__EOF__
diff --git a/lib/ansible/modules/packaging/os/openbsd_pkg.py b/lib/ansible/modules/packaging/os/openbsd_pkg.py
index 47c27f9..53659cf 100644
--- a/lib/ansible/modules/packaging/os/openbsd_pkg.py
+++ b/lib/ansible/modules/packaging/os/openbsd_pkg.py
@@ -3,130 +3,124 @@
 
 # (c) 2013, Patrik Lundin <patrik@sigterm.se>
 #
-# This file is part of Ansible
-#
-# Ansible is free software: you can redistribute it and/or modify
-# it under the terms of the GNU General Public License as published by
-# the Free Software Foundation, either version 3 of the License, or
-# (at your option) any later version.
-#
-# Ansible is distributed in the hope that it will be useful,
-# but WITHOUT ANY WARRANTY; without even the implied warranty of
-# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-# GNU General Public License for more details.
-#
-# You should have received a copy of the GNU General Public License
-# along with Ansible.  If not, see <http://www.gnu.org/licenses/>.
+# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
+
+from __future__ import absolute_import, division, print_function
+__metaclass__ = type
+
 
 ANSIBLE_METADATA = {'metadata_version': '1.0',
                     'status': ['preview'],
                     'supported_by': 'community'}
 
-
 DOCUMENTATION = '''
 ---
 module: openbsd_pkg
-author: "Patrik Lundin (@eest)"
+author:
+- Patrik Lundin (@eest)
 version_added: "1.1"
-short_description: Manage packages on OpenBSD.
+short_description: Manage packages on OpenBSD
 description:
     - Manage packages on OpenBSD using the pkg tools.
-requirements: [ "python >= 2.5" ]
+requirements:
+- python >= 2.5
 options:
     name:
-        required: true
         description:
         - Name of the package.
+        required: yes
     state:
-        required: true
-        choices: [ present, latest, absent ]
         description:
           - C(present) will make sure the package is installed.
             C(latest) will make sure the latest version of the package is installed.
             C(absent) will make sure the specified package is not installed.
+        choices: [ absent, latest, present ]
+        default: present
     build:
-        required: false
-        choices: [ yes, no ]
-        default: no
         description:
           - Build the package from source instead of downloading and installing
             a binary. Requires that the port source tree is already installed.
             Automatically builds and installs the 'sqlports' package, if it is
             not already installed.
+        type: bool
+        default: 'no'
         version_added: "2.1"
     ports_dir:
-        required: false
-        default: /usr/ports
         description:
-          - When used in combination with the 'build' option, allows overriding
+          - When used in combination with the C(build) option, allows overriding
             the default ports source directory.
+        default: /usr/ports
         version_added: "2.1"
     clean:
-        required: false
-        choices: [ yes, no ]
-        default: no
         description:
           - When updating or removing packages, delete the extra configuration
             file(s) in the old packages which are annotated with @extra in
             the packaging-list.
+        type: bool
+        default: 'no'
         version_added: "2.3"
     quick:
-        required: false
-        choices: [ yes, no ]
-        default: no
         description:
           - Replace or delete packages quickly; do not bother with checksums
             before removing normal files.
+        type: bool
+        default: 'no'
         version_added: "2.3"
 '''
 
 EXAMPLES = '''
-# Make sure nmap is installed
-- openbsd_pkg:
+- name: Make sure nmap is installed
+  openbsd_pkg:
     name: nmap
     state: present
 
-# Make sure nmap is the latest version
-- openbsd_pkg:
+- name: Make sure nmap is the latest version
+  openbsd_pkg:
     name: nmap
     state: latest
 
-# Make sure nmap is not installed
-- openbsd_pkg:
+- name: Make sure nmap is not installed
+  openbsd_pkg:
     name: nmap
     state: absent
 
-# Make sure nmap is installed, build it from source if it is not
-- openbsd_pkg:
+- name: Make sure nmap is installed, build it from source if it is not
+  openbsd_pkg:
     name: nmap
     state: present
     build: yes
 
-# Specify a pkg flavour with '--'
-- openbsd_pkg:
+- name: Specify a pkg flavour with '--'
+  openbsd_pkg:
     name: vim--no_x11
     state: present
 
-# Specify the default flavour to avoid ambiguity errors
-- openbsd_pkg:
+- name: Specify the default flavour to avoid ambiguity errors
+  openbsd_pkg:
     name: vim--
     state: present
 
-# Specify a package branch (requires at least OpenBSD 6.0)
-- openbsd_pkg:
+- name: Specify a package branch (requires at least OpenBSD 6.0)
+  openbsd_pkg:
     name: python%3.5
     state: present
 
-# Update all packages on the system
-- openbsd_pkg:
+- name: Update all packages on the system
+  openbsd_pkg:
     name: '*'
     state: latest
 
-# Purge a package and it's configuration files
-- openbsd_pkg: name=mpd clean=yes state=absent
+- name: Purge a package and it's configuration files
+  openbsd_pkg:
+    name: mpd
+    clean: yes
+    state: absent
 
-# Quickly remove a package without checking checksums
-- openbsd_pkg: name=qt5 quick=yes state=absent
+- name: Quickly remove a package without checking checksums
+  openbsd_pkg:
+    name: qt5
+    quick: yes
+    state: absent
 '''
 
 import os
@@ -137,6 +131,8 @@ import sqlite3
 
 from distutils.version import StrictVersion
 
+from ansible.module_utils.basic import AnsibleModule
+
 
 # Function used for executing commands.
 def execute_command(cmd, module):
@@ -146,6 +142,7 @@ def execute_command(cmd, module):
     cmd_args = shlex.split(cmd)
     return module.run_command(cmd_args)
 
+
 # Function used to find out if a package is currently installed.
 def get_package_state(names, pkg_spec, module):
     info_cmd = 'pkg_info -Iq'
@@ -167,6 +164,7 @@ def get_package_state(names, pkg_spec, module):
         else:
             pkg_spec[name]['installed_state'] = False
 
+
 # Function used to make sure a package is present.
 def package_present(names, pkg_spec, module):
     build = module.params['build']
@@ -192,7 +190,8 @@ def package_present(names, pkg_spec, module):
                         flavors = pkg_spec[name]['flavor'].replace('-', ' ')
                         install_cmd = "cd %s && make clean=depends && FLAVOR=\"%s\" make install && make clean=depends" % (port_dir, flavors)
                     elif pkg_spec[name]['subpackage']:
-                        install_cmd = "cd %s && make clean=depends && SUBPACKAGE=\"%s\" make install && make clean=depends" % (port_dir, pkg_spec[name]['subpackage'])
+                        install_cmd = "cd %s && make clean=depends && SUBPACKAGE=\"%s\" make install && make clean=depends" % (port_dir,
+                                                                                                                               pkg_spec[name]['subpackage'])
                     else:
                         install_cmd = "cd %s && make install && make clean=depends" % (port_dir)
                 else:
@@ -217,9 +216,8 @@ def package_present(names, pkg_spec, module):
             #
             # It is important to note that "version" relates to the
             # packages-specs(7) notion of a version. If using the branch syntax
-            # (like "python%3.5") the version number is considered part of the
-            # stem, and the pkg_add behavior behaves the same as if the name did
-            # not contain a version (which it strictly speaking does not).
+            # (like "python%3.5") even though a branch name may look like a
+            # version string it is not used an one by pkg_add.
             if pkg_spec[name]['version'] or build is True:
                 # Depend on the return code.
                 module.debug("package_present(): depending on return code for name '%s'" % name)
@@ -234,10 +232,7 @@ def package_present(names, pkg_spec, module):
                     # "file:/local/package/directory/ is empty" message on stderr
                     # while still installing the package, so we need to look for
                     # for a message like "packagename-1.0: ok" just in case.
-                    if pkg_spec[name]['style'] == 'branch':
-                        match = re.search("\W%s-[^:]+: ok\W" % pkg_spec[name]['pkgname'], pkg_spec[name]['stdout'])
-                    else:
-                        match = re.search("\W%s-[^:]+: ok\W" % name, pkg_spec[name]['stdout'])
+                    match = re.search("\W%s-[^:]+: ok\W" % pkg_spec[name]['stem'], pkg_spec[name]['stdout'])
 
                     if match:
                         # It turns out we were able to install the package.
@@ -259,6 +254,7 @@ def package_present(names, pkg_spec, module):
             pkg_spec[name]['stderr'] = ''
             pkg_spec[name]['changed'] = False
 
+
 # Function used to make sure a package is the latest available version.
 def package_latest(names, pkg_spec, module):
     if module.params['build'] is True:
@@ -318,6 +314,7 @@ def package_latest(names, pkg_spec, module):
         module.debug("package_latest(): calling package_present() to handle leftovers")
         package_present(names, pkg_spec, module)
 
+
 # Function used to make sure a package is not installed.
 def package_absent(names, pkg_spec, module):
     remove_cmd = 'pkg_delete -I'
@@ -347,6 +344,7 @@ def package_absent(names, pkg_spec, module):
             pkg_spec[name]['stderr'] = ''
             pkg_spec[name]['changed'] = False
 
+
 # Function used to parse the package name based on packages-specs(7).
 # The general name structure is "stem-version[-flavors]".
 #
@@ -374,60 +372,59 @@ def parse_package_name(names, pkg_spec, module):
 
         # If name includes a version.
         if version_match:
-            match = re.search("^(?P<stem>.*)-(?P<version>[0-9][^-]*)(?P<flavor_separator>-)?(?P<flavor>[a-z].*)?$", name)
+            match = re.search("^(?P<stem>[^%]+)-(?P<version>[0-9][^-]*)(?P<flavor_separator>-)?(?P<flavor>[a-z].*)?(%(?P<branch>.+))?$", name)
             if match:
-                pkg_spec[name]['stem']              = match.group('stem')
+                pkg_spec[name]['stem'] = match.group('stem')
                 pkg_spec[name]['version_separator'] = '-'
-                pkg_spec[name]['version']           = match.group('version')
-                pkg_spec[name]['flavor_separator']  = match.group('flavor_separator')
-                pkg_spec[name]['flavor']            = match.group('flavor')
-                pkg_spec[name]['style']             = 'version'
+                pkg_spec[name]['version'] = match.group('version')
+                pkg_spec[name]['flavor_separator'] = match.group('flavor_separator')
+                pkg_spec[name]['flavor'] = match.group('flavor')
+                pkg_spec[name]['branch'] = match.group('branch')
+                pkg_spec[name]['style'] = 'version'
+                module.debug("version_match: stem: %(stem)s, version: %(version)s, flavor_separator: %(flavor_separator)s, "
+                             "flavor: %(flavor)s, branch: %(branch)s, style: %(style)s" % pkg_spec[name])
             else:
                 module.fail_json(msg="unable to parse package name at version_match: " + name)
 
         # If name includes no version but is version-less ("--").
         elif versionless_match:
-            match = re.search("^(?P<stem>.*)--(?P<flavor>[a-z].*)?$", name)
+            match = re.search("^(?P<stem>[^%]+)--(?P<flavor>[^%]+)?(%(?P<branch>.+))?$", name)
             if match:
-                pkg_spec[name]['stem']              = match.group('stem')
+                pkg_spec[name]['stem'] = match.group('stem')
                 pkg_spec[name]['version_separator'] = '-'
-                pkg_spec[name]['version']           = None
-                pkg_spec[name]['flavor_separator']  = '-'
-                pkg_spec[name]['flavor']            = match.group('flavor')
-                pkg_spec[name]['style']             = 'versionless'
+                pkg_spec[name]['version'] = None
+                pkg_spec[name]['flavor_separator'] = '-'
+                pkg_spec[name]['flavor'] = match.group('flavor')
+                pkg_spec[name]['branch'] = match.group('branch')
+                pkg_spec[name]['style'] = 'versionless'
+                module.debug("versionless_match: stem: %(stem)s, flavor: %(flavor)s, branch: %(branch)s, style: %(style)s" % pkg_spec[name])
             else:
                 module.fail_json(msg="unable to parse package name at versionless_match: " + name)
 
-        # If name includes no version, and is not version-less, it is all a stem.
+        # If name includes no version, and is not version-less, it is all a
+        # stem, possibly with a branch (%branchname) tacked on at the
+        # end.
         else:
-            match = re.search("^(?P<stem>.*)$", name)
+            match = re.search("^(?P<stem>[^%]+)(%(?P<branch>.+))?$", name)
             if match:
-                pkg_spec[name]['stem']              = match.group('stem')
+                pkg_spec[name]['stem'] = match.group('stem')
                 pkg_spec[name]['version_separator'] = None
-                pkg_spec[name]['version']           = None
-                pkg_spec[name]['flavor_separator']  = None
-                pkg_spec[name]['flavor']            = None
-                pkg_spec[name]['style']             = 'stem'
+                pkg_spec[name]['version'] = None
+                pkg_spec[name]['flavor_separator'] = None
+                pkg_spec[name]['flavor'] = None
+                pkg_spec[name]['branch'] = match.group('branch')
+                pkg_spec[name]['style'] = 'stem'
+                module.debug("stem_match: stem: %(stem)s, branch: %(branch)s, style: %(style)s" % pkg_spec[name])
             else:
                 module.fail_json(msg="unable to parse package name at else: " + name)
 
-        # If the stem contains an "%" then it needs special treatment.
-        branch_match = re.search("%", pkg_spec[name]['stem'])
-        if branch_match:
-
+        # Verify that the managed host is new enough to support branch syntax.
+        if pkg_spec[name]['branch']:
             branch_release = "6.0"
 
-            if version_match or versionless_match:
-                module.fail_json(msg="package name using 'branch' syntax also has a version or is version-less: " + name)
             if StrictVersion(platform.release()) < StrictVersion(branch_release):
                 module.fail_json(msg="package name using 'branch' syntax requires at least OpenBSD %s: %s" % (branch_release, name))
 
-            pkg_spec[name]['style'] = 'branch'
-
-            # Key names from description in pkg_add(1).
-            pkg_spec[name]['pkgname'] = pkg_spec[name]['stem'].split('%')[0]
-            pkg_spec[name]['branch'] = pkg_spec[name]['stem'].split('%')[1]
-
         # Sanity check that there are no trailing dashes in flavor.
         # Try to stop strange stuff early so we can be strict later.
         if pkg_spec[name]['flavor']:
@@ -435,6 +432,7 @@ def parse_package_name(names, pkg_spec, module):
             if match:
                 module.fail_json(msg="trailing dash in flavor: " + pkg_spec[name]['flavor'])
 
+
 # Function used for figuring out the port path.
 def get_package_source_path(name, pkg_spec, module):
     pkg_spec[name]['subpackage'] = None
@@ -475,7 +473,7 @@ def get_package_source_path(name, pkg_spec, module):
         if len(results) < 1:
             module.fail_json(msg="could not find a port by the name '%s'" % name)
         if len(results) > 1:
-            matches = map(lambda x:x[1], results)
+            matches = map(lambda x: x[1], results)
             module.fail_json(msg="too many matches, unsure which to build: %s" % ' OR '.join(matches))
 
         # there's exactly 1 match, so figure out the subpackage, if any, then return
@@ -485,6 +483,7 @@ def get_package_source_path(name, pkg_spec, module):
             pkg_spec[name]['subpackage'] = parts[1]
         return parts[0]
 
+
 # Function used for upgrading all installed packages.
 def upgrade_packages(pkg_spec, module):
     if module.check_mode:
@@ -514,25 +513,25 @@ def upgrade_packages(pkg_spec, module):
     else:
         pkg_spec['*']['rc'] = 0
 
+
 # ===========================================
 # Main control flow.
-
 def main():
     module = AnsibleModule(
-        argument_spec = dict(
-            name = dict(required=True, type='list'),
-            state = dict(required=True, choices=['absent', 'installed', 'latest', 'present', 'removed']),
-            build = dict(default='no', type='bool'),
-            ports_dir = dict(default='/usr/ports'),
-            quick = dict(default='no', type='bool'),
-            clean = dict(default='no', type='bool')
+        argument_spec=dict(
+            name=dict(type='list', required=True),
+            state=dict(type='str', default='present', choices=['absent', 'installed', 'latest', 'present', 'removed']),
+            build=dict(type='bool', default=False),
+            ports_dir=dict(type='path', default='/usr/ports'),
+            quick=dict(type='bool', default=False),
+            clean=dict(type='bool', default=False),
         ),
-        supports_check_mode = True
+        supports_check_mode=True
     )
 
-    name      = module.params['name']
-    state     = module.params['state']
-    build     = module.params['build']
+    name = module.params['name']
+    state = module.params['state']
+    build = module.params['build']
     ports_dir = module.params['ports_dir']
 
     rc = 0
@@ -578,7 +577,7 @@ def main():
         # Not sure how the branch syntax is supposed to play together
         # with build mode. Disable it for now.
         for n in name:
-            if pkg_spec[n]['style'] == 'branch' and module.params['build'] is True:
+            if pkg_spec[n]['branch'] and module.params['build'] is True:
                 module.fail_json(msg="the combination of 'branch' syntax and build=%s is not supported: %s" % (module.params['build'], n))
 
         # Get state for all package names.
@@ -596,6 +595,10 @@ def main():
     # is changed this is set to True.
     combined_changed = False
 
+    # The combined failed status for all requested packages. If anything
+    # failed this is set to True.
+    combined_failed = False
+
     # We combine all error messages in this comma separated string, for example:
     # "msg": "Can't find nmapp\n, Can't find nmappp\n"
     combined_error_message = ''
@@ -604,6 +607,7 @@ def main():
     # changed.
     for n in name:
         if pkg_spec[n]['rc'] != 0:
+            combined_failed = True
             if pkg_spec[n]['stderr']:
                 if combined_error_message:
                     combined_error_message += ", %s" % pkg_spec[n]['stderr']
@@ -620,15 +624,12 @@ def main():
 
     # If combined_error_message contains anything at least some part of the
     # list of requested package names failed.
-    if combined_error_message:
-        module.fail_json(msg=combined_error_message)
+    if combined_failed:
+        module.fail_json(msg=combined_error_message, **result)
 
     result['changed'] = combined_changed
 
     module.exit_json(**result)
 
-# Import module snippets.
-from ansible.module_utils.basic import *
-
 if __name__ == '__main__':
     main()
__EOF__
fi

sudo sed -i'.bak' -e 's/ \/opt ffs rw,nodev,nosuid 1 2/ \/opt ffs rw,nosuid 1 2/' /etc/fstab
sudo rm /etc/fstab.bak

sudo sed -i'.bak' -e 's/\(ttyC[^0].*getty.*\)on /\1off/' /etc/ttys
sudo rm /etc/ttys.bak

if sysctl -n kern.version | head -n1 | grep -q -- -current ;then
    # syspatch is not available for -current
    :
else
    case `uname -r` in
        6.[12])
            sudo syspatch
            ;;
    esac
fi
