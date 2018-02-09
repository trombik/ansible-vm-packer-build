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
end
