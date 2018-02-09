require "spec_helper"

case os[:family]
when "openbsd"
  describe file("/etc/boot.conf") do
    it { should exist }
    it { should be_file }
    its(:content) { should match(/^set timeout 1$/) }
  end
when "debian", "ubuntu"
  describe file("/etc/default/grub") do
    it { should exist }
    it { should be_file }
    its(:content) { should match(/^GRUB_TIMEOUT=0$/) }
  end
when "freebsd"
  describe file("/boot/loader.conf") do
    it { should exist }
    it { should be_file }
    its(:content) { should match(/^autoboot_delay="0"$/) }
  end
end
