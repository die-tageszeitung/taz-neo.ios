#!/usr/bin/env ruby
#
# getResources is used download the resources zip-file as used by
# taz and lmd apps.

require 'net/http'
require 'json'
require 'fileutils'

# class GetResources is used to download the resources zip file
#
class GetResources

  @@TazUrl = "https://dl.taz.de/appGraphQl"
  @@LmdUrl = "https://dl.monde-diplomatique.de/appGraphQl"

  @@HttpHeader = {
    "Content-Type" => "application/json",
    "Accept" => "application/json"
  }

  @@Query = <<~EOF
  { 
    "query": "query {
      resources: product {
        resourceVersion, 
        resourceBaseUrl,
        resourceZipName: resourceZip,
        files: resourceList {
          name, storageType, sMoTime: moTime, sha256, sSize: size
        }
      }
    }"
  }
  EOF
  
  @@QueryVersion = <<~EOF
  { 
    "query": "query {
      resources: product {
        resourceVersion 
      }
    }"
  }
  EOF
  
  # URL of server
  attr_reader :url
  attr_reader :uri

  # destination directory
  attr_reader :dir
  # files in destination folder
  def jsonFile; "#{@dir}/resources.json" end
  def zipFile;  "#{@dir}/resources.zip" end

  # resource version, zip file URL and list of resource files
  attr_reader :resourceVersion
  attr_reader :resourceURL
  attr_reader :ResourceFiles
  
  # command line options
  attr_reader :options
  
  # Usage message
  @@Usage = <<~EOF
    SYNOPSIS
      getResources [options] taz|lmd
      options:
        -d directory : where to write resources to
        -f           : force download of resources (even if local version is current)
        -u           : unzip resources to <directory>/files
      By default getResources requests a resources.json file from taz|lmd
      GraphQl server and writes it to <directory>/taz|lmd/resources.json.
      It then downloads the resources zip file to <directory>/taz|lmd/resources.json
      and unpacks it into <directory>/taz|lmd/files if -u is used.
  EOF
  
  def usage
    puts(@@Usage)
    exit(2)
  end
  
  # GetResources.new parses the command line arguments and initializes the
  # server connection.
  #
  def initialize
    @options = {}
    @dir = "."
    av = ARGV
    while av.length > 0
      case av[0]
        when "--"
          av.shift
          break
        when "+", "++", "--help"
          usage
      end
      if av[0][0] == "-"[0]
        opt = av[0]
        i = 1
        n = opt.length
        while i < n
          case opt[i]
            when "f"[0]
              @options[:force] = true
            when "u"[0]
              @options[:unzip] = true
            when "d"[0]
              raise "-d argument missing" if av.length < 2
              @dir = av[1]
              av.shift
            else
              usage
          end
          i += 1
        end
      else
        break
      end
      av.shift
    end
    usage if av.length < 1
    if av[0] == "taz"
      @url = @@TazUrl
    elsif av[0] == "lmd"
      @url = @@LmdUrl
    else
      usage
    end
    @dir += "/#{av[0]}"
    @uri = URI(@url)
  end

  # get resources version from GraphQl server
  #
  def getVersion()
    query = @@QueryVersion.gsub(/\s+/, ' ')
    response = Net::HTTP.post(@uri, query, @@HttpHeader)
    raise response if response.code != "200"
    dict = JSON.parse(response.body)
    return dict["data"]["resources"]["resourceVersion"]
  end

  # get resources version from local file
  #
  def getLocalVersion()
    begin
      File.open(jsonFile, "r") do |f|
        s = f.read 
        return 0 if s.length == 0
        dict = JSON.parse(s)
        return dict["data"]["resources"]["resourceVersion"]
      end
    rescue 
      return 0
    end
  end

  # isAvailable checks whether the remote host is available
  #
  def isAvailable()
    begin
      http = Net::HTTP.start(@uri.host, @uri.port, open_timeout: 2, read_timeout: 2)
      response = http.head("/")
      return true
    rescue 
      return false
    end
  end

  # get resources.json file from GraphQl server
  #
  def getJson()
    query = @@Query.gsub(/\s+/, ' ')
    response = Net::HTTP.post(@uri, query, @@HttpHeader)
    raise response if response.code != "200"
    dict = JSON.parse(response.body)
    @resourceVersion = dict["data"]["resources"]["resourceVersion"]
    baseURL = dict["data"]["resources"]["resourceBaseUrl"]
    fname = dict["data"]["resources"]["resourceZipName"]
    @resourceURL = "#{baseURL}/#{fname}"
    @resourceFiles = dict["data"]["resources"]["files"]
    return response.body
  end

  # get resources.zip file from GraphQl server
  #
  def getZip()
    uri = URI(@resourceURL)
    response = Net::HTTP.get_response(uri)
    File.open(zipFile, "w") do |f|
      s = f.write(response.body)
    end
  end

  # put resources.json to local file (create directory if necessary)
  #
  def putJson(json)
    FileUtils.mkdir_p(@dir)
    File.open(jsonFile, "w") do |f|
      f.write(json)
    end
  end

  # unzip resources.zip to subfolder 'files'
  #
  def unzip
    files = "#{@dir}/files"
    FileUtils.rm_rf(files)
    FileUtils.mkdir_p(files)
    output = `cd '#{files}'; unzip ../resources.zip`
    if $?.exitstatus != 0
      raise("unzip failed:\n#{output}")
    end
  end

  # checkFiles verifies that all resource files listed in resources.json 
  # were available in the zip file
  #
  def checkFiles
    unzippedFiles = Dir.glob("#{@dir}/files/*")
    rc = @resourceFiles.count
    uc = unzippedFiles.count
    if rc == uc
      puts("Checking #{rc} files")
    else
      puts("Checking files:")
      puts("  file count differs: #{rc} in resources.json, #{uc} unzipped")
    end
    unzipMissing = []
    jsonMissing = []
    resFiles = {}
    for f in @resourceFiles
      fn = f["name"]
      unzipMissing += fn if !File.exists?("#{@dir}/files/#{fn}")
      if resFiles[fn]
        puts("  #{fn} listed twice in resources.json")
      end
      resFiles[fn] = true
    end
    for f in unzippedFiles
      base = File.basename(f)
      jsonMissing += base if !resFiles[base]
    end
    if unzipMissing.count > 0
      puts("  the following files are missing in resources.zip:")
      unzipMissing.each { |f| puts("    #{f}") }
      raise "Unmatched file count"
    end
    if jsonMissing.count > 0
      puts("  the following files are missing in resources.json:")
      jsonMissing.each { |f| puts("    #{f}") }
      raise "Unmatched file count"
    end
  end
  
  # update checks for local and remote resource versions and updates the resources
  # if needed
  def update
    if !isAvailable
      msg = "Server #{@uri.host} is not available"
      if File.exists?(zipFile)
        puts(msg)
      else
        raise msg
      end
      return 
    end
    local = getLocalVersion
    if @options[:force] || local < 1 || !File.exists?(zipFile) || local < getVersion
      json = getJson
      puts("Resource Update: #{@resourceVersion} -> #{local} (local)")
      putJson(json)
      getZip
      if @options[:unzip]
        unzip
	checkFiles
      end
    else
      puts("Resources are current at version #{local}")
    end
  end

end  # GetResources

begin
  res = GetResources.new
  res.update
rescue => err
  puts("error: #{err}")
  exit(1)
else
  exit(0)
end
  
