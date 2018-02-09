require "spec_helper"

case os[:family]
when "openbsd"
  if os[:release].to_f >= 5.9
    describe file("/etc/fstab") do
      it { should exist }
      it { should be_file }
      its(:content) { should match(/^[0-9a-zA-Z]+\.[a-zA-Z]+\s+#{Regexp.escape("/opt ffs rw,nosuid 1 2")}$/) }
      its(:content) { should_not match(/^[0-9a-zA-Z]+\.[a-zA-Z]+\s+#{Regexp.escape("/opt ffs rw,nodev,nosuid 1 2")}$/) }
    end
  end
end
