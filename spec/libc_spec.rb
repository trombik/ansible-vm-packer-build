require "spec_helper"

case os[:family]
when "redhat"
  describe file "/etc/sysconfig/64bit_strstr_via_64bit_strstr_sse2_unaligned" do
    it { should exist }
    it { should be_file }
    it { should be_mode 644 }
  end
end
