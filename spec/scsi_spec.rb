require "spec_helper"

case os[:family]
when "openbsd"
  describe command("mount -t ffs") do
    its(:exit_status) { should eq 0 }
    its(:stderr) { should eq "" }
    its(:stdout) do
      # XXX commented out to see if the issue still exists
      # pending "SCSI causes disk stall on host OS"
      should match(/^#{Regexp.escape("/dev/sd0")}/)
    end
  end
when "redhat"
  describe command("mount -t xfs") do
    its(:exit_status) { should eq 0 }
    its(:stderr) { should eq "" }
    its(:stdout) { should match(/^#{Regexp.escape("/dev/sda")}/) }
  end
when "freebsd"
  describe command("mount -t ufs") do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^#{Regexp.escape("/dev/")}(?:a?da0|vtbd0s1a)/) }
    its(:stderr) { should eq "" }
  end
when "ubuntu"
  describe command("mount -t ext4") do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^#{Regexp.escape("/dev/sda")}/) }
    its(:stderr) { should eq "" }
  end
end
