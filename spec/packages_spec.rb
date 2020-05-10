require "spec_helper"

package_ansible = case os[:family]
                  when "freebsd"
                    "sysutils/ansible"
                  else
                    "ansible"
                  end
packages = %w[rsync curl sudo]
packages << package_ansible

packages.each do |p|
  describe package(p) do
    it { should be_installed }
  end
end

case os[:family]
when "freebsd"
  status = Specinfra.backend.run_command("sysctl dev.virtio_pci").exit_status
  if status != 0
    describe package("virtualbox-ose-additions-nox11") do
      it { should be_installed }
    end
  end
when "openbsd"
  kern_version = Specinfra.backend.run_command("sysctl -n kern.version").stdout
  describe command("syspatch -c") do
    if kern_version =~ /-(current|beta)/
      its(:exit_status) { should eq 1 }
      its(:stderr) { should match(/^Unsupported release: \d+\.\d+-(current|beta)/) }
    else
      its(:exit_status) { should eq 0 }
      its(:stderr) { should eq "" }
      its(:stdout) { should eq "" }
    end
  end
end

describe command "python3 --version" do
  its(:exit_status) { should eq 0 }
  its(:stderr) { should eq "" }
  its(:stdout) { should match(/^Python\s+3\./) }
end
