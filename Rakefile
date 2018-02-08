require "json"
require "yaml"
require "rspec/core/rake_task"
require "shellwords"

@config_file = "config.yml"
@config = YAML.load_file @config_file

def all_box_names
  @config["box"].map { |i| i["name"] }
end

namespace :build do
  desc "Build all boxes"
  task all: all_box_names.map { |i| "build:#{i}" }
  all_box_names.each do |b|
    json_file = "#{b}.json"
    json = JSON.parse(File.read(json_file))
    available_builder_types = json["builders"].map { |i| i["type"] }
    desc "Build #{b} (builder types: #{available_builder_types.join(', ')})"
    task b.to_sym do
      sh "packer build -only #{@config['provider'].join(',').shellescape} #{json_file.shellescape}"
    end
  end
end
