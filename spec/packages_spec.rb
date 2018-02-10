require "spec_helper"

packages = %w[ansible rsync curl sudo]

packages.each do |p|
  describe package(p) do
    it { should be_installed }
  end
end

case os[:family]
when "freebsd"
  describe package("virtualbox-ose-additions-nox11") do
    it { should be_installed }
  end
when "openbsd"
  # XXX RE_5_9 does not have the latest ansible yet
  if os[:release].to_f >= 6.0 && os[:release].to_f <= 6.2
    describe command "ansible --version" do
      its(:exit_status) { should eq 0 }
      its(:stdout) { should match(/^ansible\s+2\.(?:3\.2\.0|4\.\d+\.\d+)\s+/) }
    end
  end
  if os[:release].to_f >= 6.1
    describe file("/etc/pkg.conf") do
      it { should_not exist }
    end
    describe file("/etc/installurl") do
      it { should be_file }
      it { should be_mode 644 }
      its(:content) { should match(/^#{Regexp.escape("https://fastly.cdn.openbsd.org/pub/OpenBSD")}$/) }
    end
  else
    describe file("/etc/pkg.conf") do
      it { should exist }
      it { should be_file }
      it { should be_mode 644 }
      its(:content) { should match(/^installpath\s*=\s*fastly\.cdn\.openbsd\.org/) }
    end
  end

  prefix = "/usr/local/bin"
  python_version = "2.7"
  python_symlinks = {
    "#{prefix}/python" => "#{prefix}/python#{python_version}",
    "#{prefix}/2to3" => "#{prefix}/python#{python_version}-2to3",
    "#{prefix}/python-config" => "#{prefix}/python#{python_version}-config",
    "#{prefix}/pydoc" => "#{prefix}/pydoc#{python_version}"
  }
  python_symlinks.each do |k, v|
    describe file(k) do
      it { should exist }
      it { should be_symlink }
      it { should be_linked_to v }
    end

    describe file(v) do
      it { should exist }
      it { should be_file }
      it { should be_mode os[:release].to_f >= 6.0 ? 755 : 555 }
    end
  end
  if os[:release].to_f < 6.0
    # Specify a package branch
    describe file("/usr/local/lib/python2.7/site-packages/ansible/modules/extras/packaging/os/openbsd_pkg.py") do
      it { should exist }
      it { should be_file }
      its(:content) { should match(/^#{Regexp.escape("# Specify a package branch (requires at least OpenBSD 6.0)")}$/) }
    end
  end
  if os[:release].to_f >= 6.0

    # test if `openbsd_pkg` is able to parse valid package names below.
    log_dir = "/var/log/ansible"
    describe command("mkdir -p #{log_dir}") do
      its(:exit_status) { should eq 0 }
      its(:stderr) { should eq "" }
    end
    %w[openldap-server--%openldap jdk--%1.8 screen--shm postfix--sasl2-pgsql%stable].each do |p|
      describe command("ansible -C -t #{log_dir} -m openbsd_pkg -a 'name=#{p} state=installed' localhost") do
        its(:exit_status) { should eq 0 }
        its(:stderr) do
          # rubocop:disable Metrics/LineLength:
          should eq(" [WARNING]: provided hosts list is empty, only localhost is available")
            .or(eq(" [WARNING]: provided hosts list is empty, only localhost is available. Note\nthat the implicit localhost does not match 'all'\n"))
          # rubocop:enable Metrics/LineLength:
        end
      end

      describe file("#{log_dir}/localhost") do
        it { should exist }
        it { should be_file }
        its(:content_as_json) { should include("name" => [p]) }
        its(:content_as_json) { should include("state" => "installed") }
      end
    end
  end
end
