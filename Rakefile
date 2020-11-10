require "json"
require "yaml"
require "rspec/core/rake_task"
require "shellwords"
require "uri"
require "rainbow"
require "net/http"
require "vagrant_cloud"
require "pry"
require "open3"

@config_file = "config.yml"
@config = YAML.load_file @config_file

def packer_builder(box_provider)
  case box_provider
  when "virtualbox"
    "virtualbox-iso"
  when "libvirt"
    "qemu"
  end
end

def all_box_names
  @config["box"].map { |i| i["name"] }
end

def all_json_files
  all_box_names.map { |i| i + ".json" }
end

def all_json
  all_json_files.map do |f|
    JSON.parse(File.read(f))
  end
end

def request_head(uri, &block)
  uri = URI(uri)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true if uri.scheme == "https"
  http.request_head(uri, &block)
end

def available?(response)
  response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection)
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
      sh "packer build -only #{@config['provider'].map do |p|
                                 packer_builder(p)
                               end .join(',').shellescape} #{json_file.shellescape}"
    end
  end
end

namespace :test do
  desc "Run all tests"
  task all: [:rubocop, :iso_url]

  desc "Run all tests for CI environment"
  task ci: [:rubocop, :iso_url]

  desc "Run rubocop"
  task :rubocop do
    sh "rubocop"
  end

  desc "Validate iso_url"
  task :iso_url do
    all_json.each do |j|
      mirror = j["variables"]["mirror"]
      iso_urls = j["builders"].map { |i| i["iso_url"].gsub("{{user `mirror`}}", mirror) }
      iso_urls.uniq.each do |u|
        print Rainbow(u).green + " "
        request_head(u) do |res|
          if available?(res)
            puts Rainbow(res.message).green
          else
            puts Rainbow(res.message).red
            puts Rainbow(res.to_s).red
            res.each_header do |h|
              out = format("%<header>s: %<value>s", header: h, value: res[h])
              puts Rainbow(out).red
            end
            raise "#{u}: is not available"
          end
        end
      end
    end
  end

  namespace :import do
    all_box_names.each do |boxname|
      canonical_box_name = "#{@config['vagrant_cloud']['username']}/test-#{boxname}"
      @config["provider"].each do |provider|
        namespace boxname do
          # an internal target to import box file
          task provider.to_sym do
            box_filename = "#{boxname}-#{provider}.box"
            Bundler.with_clean_env do
              sh format("vagrant box add --force --provider %<provider>s --name %<name>s %<file>s",
                        provider: provider.shellescape,
                        name: canonical_box_name.shellescape,
                        file: box_filename.shellescape)
            end
          end
        end
      end
    end
  end

  namespace :boot do
    all_box_names.each do |boxname|
      namespace boxname do
        @config["provider"].each do |provider|
          # an internal target to boot a VM
          task provider.to_sym => ["test:import:#{boxname}:#{provider}"] do
            Bundler.with_clean_env do
              vagrant_hostname = boxname.tr(".", "_") + "-#{provider}"
              sh "vagrant up #{vagrant_hostname.shellescape}"
            end
          end
        end
      end
    end
  end

  namespace :spec do
    # test:spec:boxname:provider, test:spec:boxname:provider:clean
    targets = []
    all_box_names.each do |boxname|
      @config["provider"].each do |provider|
        targets << "test:spec:#{boxname}:#{provider}"
        targets << "test:spec:#{boxname}:#{provider}:clean"
      end
    end
    desc "Run rspec on all VMs"
    task all: targets

    all_box_names.each do |boxname|
      namespace boxname do
        @config["provider"].each do |provider|
          vagrant_hostname = "#{boxname.tr('.', '_')}-#{provider}"
          desc "Run rspec on #{boxname} #{provider}"
          task provider.to_sym => ["test:boot:#{boxname}:#{provider}"] do
            ENV["HOST"] = vagrant_hostname
            sh "rspec --pattern 'spec/**/*_spec.rb'"
          end

          namespace provider.to_sym do
            task :clean do
              Bundler.with_clean_env do
                sh "vagrant destroy -f #{vagrant_hostname.shellescape}"
              end
            end
          end
        end
      end
    end
  end

  namespace :clean do
    desc "Destroy all VMs"
    task :all do
      Bundler.with_clean_env do
        sh "vagrant destroy -f"
      end
    end

    desc "Clean cached files"
    # this target is intended for CI environments, where files in a repository
    # are not removed after tests _and_ disk space is limited (Jenkins)
    task :cache do
      sh "rm -rf packer_cache/*"
    end

    desc "Clean box files"
    task :box do
      sh "rm -f *.box"
    end
  end
end

def ansible_version_in_vm(vm_name)
  ansible_version = nil
  begin
    Bundler.with_clean_env do
      sh "vagrant up #{vm_name.shellescape}"
      cmd = "vagrant ssh #{vm_name.shellescape} -- 'ansible --version | head -n1'"
      o, e, s = Open3.capture3(cmd)
      raise "failed to run command `#{cmd}`: #{e}" unless s.success?

      ansible_version = o.chomp
      puts Rainbow("ansible --version: #{ansible_version}").green
    end
  ensure
    Bundler.with_clean_env do
      sh "vagrant destroy -f #{vm_name}"
    end
  end
  raise "failed to find ansible version" if ansible_version.nil?

  ansible_version
end

def publish_box(args)
  [:name, :version, :provider, :file].each do |attr|
    raise "missing argument: `#{attr}`" unless args[attr]
  end
  raise "file `#{args[:file]}` does not exist" unless File.exist?(args[:file])

  Bundler.with_clean_env do
    # vagrant cloud publish trombik/ansible-freebsd-12.1-amd64 20200514 libvirt freebsd-12.1-amd64-libvirt.box
    sh format("vagrant cloud publish %<name>s %<version>s %<provider>s %<file>s",
              name: args[:name],
              version: args[:version],
              provider: args[:provider],
              file: args[:file])
  end
end
namespace :upload do
  username = @config["vagrant_cloud"]["username"]
  token = if ENV["VAGRANT_CLOUD_TOKEN"] || ENV["ATLAS_TOKEN"]
            ENV["VAGRANT_CLOUD_TOKEN"] || ENV["ATLAS_TOKEN"]
          elsif @config["vagrant_cloud"].key?("token")
            @config["vagrant_cloud"]["token"]
          end
  @config["box"].each do |box|
    @config["provider"].each do |provider|
      desc "Upload #{box['name']}-#{provider}.box"
      file = "#{box['name']}-#{provider}.box"
      task file do
        raise "file #{file} does not exist" unless File.exist?(file)
        raise "Token is not defined either in config.yml, or environment variable VAGRANT_CLOUD_TOKEN" unless token

        vagrant_hostname = box["name"].tr(".", "_") + "-#{provider}"
        ansible_version = ansible_version_in_vm(vagrant_hostname)
        vagrant_cloud_box_name = "#{username}/ansible-#{box['name']}"
        mtime = File.mtime(file)
        version = format("%<year>d%<month>02d%<day>02d",
                         year: mtime.year,
                         month: mtime.month,
                         day: mtime.day)
        puts "Publishing a box"
        puts "file name: #{Rainbow(file).green}"
        puts "box name: #{Rainbow(box['name']).green}"
        puts "box version: #{Rainbow(version).green}"
        puts "provider: #{Rainbow(provider).green}"
        puts "ansible version: #{Rainbow(ansible_version).green}"
        publish_box(name: vagrant_cloud_box_name, version: version, provider: provider, file: file)
      end
    end
  end
end
