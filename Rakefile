require "json"
require "yaml"
require "rspec/core/rake_task"
require "shellwords"
require "uri"
require "rainbow"
require "net/http"
require "vagrant_cloud"
require "pry"

@config_file = "config.yml"
@config = YAML.load_file @config_file

def all_box_names
  @config["box"].map { |i| i["name"] }
end

def all_json_files
  all_box_names.map { |i| i + ".json" }
end

def all_json
  all_json_files.map { |f| JSON.parse(File.read(f)) }
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
      sh "packer build -only #{@config['provider'].join(',').shellescape} #{json_file.shellescape}"
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
            box_filename = "#{boxname}-#{provider.gsub('-iso', '')}.box"
            Bundler.with_clean_env do
              sh "vagrant box add --force --name #{canonical_box_name.shellescape} #{box_filename.shellescape}"
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
                # XXX use `|| true` here as vagrant destroy exit with status 1
                # https://github.com/hashicorp/vagrant/issues/9137
                sh "vagrant destroy -f #{vagrant_hostname.shellescape} || true"
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
        # XXX use `|| true` here as vagrant destroy exit with status 1
        # https://github.com/hashicorp/vagrant/issues/9137
        sh "vagrant destroy -f || true"
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

namespace :upload do
  username = @config["vagrant_cloud"]["username"]
  token = if ENV["VAGRANT_CLOUD_TOKEN"] || ENV["ATLAS_TOKEN"]
            ENV["VAGRANT_CLOUD_TOKEN"] || ENV["ATLAS_TOKEN"]
          elsif @config["vagrant_cloud"].key?("token")
            @config["vagrant_cloud"]["token"]
          end
  # rubocop:disable Metrics/BlockLength
  @config["provider"].map { |i| i.gsub("-iso", "") }.each do |provider|
    desc "Upload all boxes"
    task all: @config["box"].map { |b| "upload:#{provider}:#{b['name']}" }

    @config["box"].each do |b|
      desc "Upload #{b['name']}-#{provider}.box"
      task "#{provider}:#{b['name']}" do
        file = "#{b['name']}-#{provider}.box"
        raise "file #{file} does not exist" unless File.exist?(file)
        raise "Token is not defined either in config.yml, or environment variable VAGRANT_CLOUD_TOKEN" unless token
        account = VagrantCloud::Account.new(username, token)
        boxname = "ansible-#{b['name']}"
        puts Rainbow("Ensuring box #{boxname} exist").green
        box = account.ensure_box(boxname)
        puts Rainbow("Ensuring version #{b['version']} exist").green
        version = box.ensure_version(b["version"], b["description"])
        pr = version.providers.select { |p| p.name == provider }.first
        unless pr
          puts Rainbow("Creating provider #{provider}").green
          pr = version.create_provider(provider)
        end
        puts Rainbow("Uploading file #{file}").green
        pr.upload_file(file)
        puts Rainbow("Uploading #{file} completed").green
        puts Rainbow("Releasing version #{version.version}").green
        version.release
        puts Rainbow("Released").green
      end
    end
  end
  # rubocop:enable Metrics/BlockLength
end
