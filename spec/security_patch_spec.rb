require "spec_helper"

case os[:family]
when "freebsd"
  describe command "freebsd-update --not-running-from-cron fetch" do

    # XXX os[:release] does not report proper value when `uname -r` contains
    # patche-level. use uname -K instead
    kernel_version = Specinfra.backend.run_command("uname -K").stdout.to_i
    if kernel_version < 1004000

      # `freebsd-update` exits with non-zero on EoLed releases
      its(:exit_status) { should eq 1 }
    else
      its(:exit_status) { should eq 0 }
    end
    its(:stderr) { should eq "" }
    its(:stdout) { should match(/^No updates needed to update system to/) }
  end

  describe command "freebsd-update --not-running-from-cron install" do
    its(:exit_status) { should eq 1 }
    its(:stderr) { should eq "" }
    its(:stdout) { should match(/^No updates are available to install/) }
  end
end
