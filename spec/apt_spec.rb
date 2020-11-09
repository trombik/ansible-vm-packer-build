require "spec_helper"

case os[:family]
when "ubuntu"
  if os[:release].to_f >= 16.04
    describe file("/etc/apt/apt.conf.d/10disable-periodic") do
      it { should be_exist }
      it { should be_file }
      it { should be_mode 644 }
      its(:content) { should match(/^APT::Periodic::Enable\s+"0";/) }
    end
  end
  describe file("/etc/apt/apt.conf.d/10retry") do
    it { should be_exist }
    it { should be_file }
    it { should be_mode 644 }
    its(:content) { should match(/^Acquire::Retries\s+"10";/) }
  end

  if os[:release].to_f >= 20.04
    describe command("dpkg -l") do
      its(:exit_status) { should eq 0 }
      its(:stdout) { should_not match(/^\S+\s+snapd\s+/) }
    end
  end
end
