require "yaml"

Vagrant.configure("2") do |config|
  yaml = YAML.load_file("config.yml")
  images = yaml["box"].map { |b| Pathname(b["name"]) }

  7.times do
    config.vm.network :private_network, type: :dhcp
  end

  images.sort.each do |template|
    name = template.basename(".json").to_s
    escaped_name = name.gsub(/[.]/, "_")

    yaml["provider"].each do |provider|
      config.vm.define "#{escaped_name}-#{provider}" do |c|
        c.vm.box = "trombik/test-#{name}"

        c.vm.provider :virtualbox do |v|
          v.name = name
          v.gui = false
          v.cpus = ENV["VAGRANT_CPU_CORE"] || 2
        end
      end
    end
  end
end
# vim: ft=ruby
