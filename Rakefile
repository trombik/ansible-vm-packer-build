require "json"
require "yaml"
require "rspec/core/rake_task"
require "shellwords"
require "uri"
require "rainbow"
require "net/http"

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
      canonical_box_name = "trombik/test-#{boxname}"
      @config["provider"].each do |provider|
        namespace boxname do
          # an internal target to import box file
          task provider.to_sym do
            box_filename = "#{boxname}-#{provider.gsub("-iso", "")}.box"
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
              vagrant_hostname = boxname.gsub(".", "_") + "-#{provider}"
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
    task :all => targets

    all_box_names.each do |boxname|
      namespace boxname do
        @config["provider"].each do |provider|
          vagrant_hostname = "#{boxname.gsub(".", "_")}-#{provider}"
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
