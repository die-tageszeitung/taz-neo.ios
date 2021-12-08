#!/usr/bin/env ruby
#
# genBuildConst is used generate some build time constants and to manage the
# build number

require 'fileutils'

# class BuildParameter specifies some branch specific parameters like app name.
#
class BuildParameter
  # name of app (as seen on the home screen)
  attr_reader :name
  
  # bundleID of app (used as unique key identifying the app in the app store)
  attr_reader :id
  
  # state of app in app store: alpha|beta|stable
  attr_reader :state
  
  # BuildParameter.new takes an options hash and produces a BuildParameter object,
  # e.g. BuildParameter(name: "taz", id: "de.taz.taz.neo", state: "stable")
  #
  def initialize(opt)
    if val = opt[:name]
      @name = val
    else
      raise "BuildParameter.new needs name:"
    end
    if val = opt[:id]
      @id = val
    else
      raise "BuildParameter.new needs id:"
    end
    if val = opt[:state]
      @state = val
    else
      raise "BuildParameter.new needs state:"
    end
  end

end # class BuildParameter

# Relation between git branch and build parameters
#
BuildParameters = {
  "alpha" => BuildParameter.new(name: "taz.alpha", id: "de.taz.taz.neo", state: "alpha"),
  "beta" => BuildParameter.new(name: "taz.beta", id: "de.taz.taz.beta", state: "beta"),
  "release" => BuildParameter.new(name: "die tageszeitung", id: "de.taz.taz.2", state: "release")
}

# class System offers some OS-related methods
#
class System
  
  # System.absolutePath returns the absolute Path of the given file/directory
  # /path'.
  #
  def System.absolutePath(path)
    if File.directory?(path)
      Dir.chdir(path) { abs = Dir.getwd }
    else
      parent = File.dirname(path)
      if File.directory?(parent)
        System.absolutePath(parent) + "/" + File.basename(path)
      else
        raise "Can't find '#{path}'"
      end
    end
  end
  
  # System.findInDirPath looks for a file named 'fn' in 'dir' and all directorys
  # above 'dir.
  #
  def System.findInDirPath(fn, dir, cwd = nil)
    if !cwd
      cwd = Dir.getwd
      dir = System.absolutePath(dir)
    end
    if File.exist?(dir + "/" + fn)
      Dir.chdir(cwd)
      dir
    else
      Dir.chdir(dir + "/..")
      tmp = Dir.getwd
      if tmp == dir
        Dir.chdir(cwd)
        nil
      else
        findInDirPath(fn, tmp, cwd)
      end
    end
  end

end # class System

# class Git offers some methods to manage git repositories
#
class Git
  
  # URL of remote repository
  attr_reader :remote
  
  # Path to directory containing local git repository
  attr_reader :local
  
  # Current branch
  attr_reader :branch
  
  # Current git status
  attr_reader :status
  
  # evaluate local status
  #
  def readStatus
    @branch = Git.cmd(@local, "branch --show-current")
    @status = Git.status(@local)
  end
  
  # Initialize with path to dir containing local repository and URL of remote
  # git repository
  #
  def initialize(remote, local = ".")
    @local = Git.topdir(local)
    @remote = remote
    readStatus
  end
  
  # Git.topdir searches in the passed directory and above for a .git subdirectory
  #
  def Git.topdir(dir = ".")
    topdir = System.findInDirPath(".git", dir)
    raise "Can't find git-Repository in '#{dir}' and above" if !topdir
    topdir
  end
  
  # Git.cmd performs the git command in the given directory
  #
  def Git.cmd(dir = ".", cmd)
    `cd "#{dir}"; git #{cmd}`.strip
  end
  
  # Git.status performs the git status command and returns a hash reflecting
  # the current status as FILE -> CODE (see git status). In addition the following
  # keys/value are defined:
  #   :nMerge -> number of files to merge
  #   :nCommit -> number of files to commit
  #   :nUntracked -> number of untracked files
  #   :fToMerge -> array of files to merge
  #   :fChanged -> array of changed files
  #
  def Git.status(dir = ".")
    status = { :nMerge=>0, :nCommit=>0, :nUntracked=>0,
               :fToMerge=>[], :fChanged=>[] }
    Git.cmd( "status --porcelain" ).
      each_line do |l|
      fn = l.sub( /^..."(.*)"\s*/, '\1' )
      fn = l.sub( /^...(.*)\s*/, '\1' ) if fn == l
      st = l.sub( /^(..).*\s*/, '\1' )
      status[fn] = st
      if (st == "DD") || st.index("U")
        status[:nMerge] += 1
        status[:fToMerge] << fn
      end
      if (st != "??")
        status[:nCommit] += 1
        status[:fChanged] << fn
      else
        status[:nUntracked] += 1
      end
    end
    status
  end
  
  # cmd performs the given git command in that directory holding the .git
  # subdirectory
  #
  def git(cmd)
    Git.cmd(@local, cmd)
  end
  
  # needsMerge? returns true if there are files to merge
  #
  def needsMerge?
    @status[:nMerge] != 0
  end
  
  # filesChanged returns a string of files in need to commit
  #
  def filesChanged
    fl = @status[:fChanged]
    return nil if !fl || fl.empty?
    str = ""
    fl.each { |f| str << "  " + f + "\n" }
    return str
  end
  
  # needsCommit? returns true if there are files to commit
  #
  def needsCommit?
    @status[:nCommit] != 0
  end

  # remoteHash returns the most recent commit hash from the remote repository
  # in the current branch
  #
  def remoteHash
    output = git("ls-remote '#{@remote}' '#{@branch}'")
    hash = output.sub(/([^\s\t]*).*/, '\1')
    return nil if output == hash
    return hash
  end
  
  # localHash returns the most recent commit hash from the local repository in
  # the current branch
  #
  def localHash
    git("log -1 --pretty=format:%H")
  end

end # class Git

class BuildNumber
  attr_reader :time
  attr_reader :serial
  
  def initialize(str = nil)
    if str
      raise "Invalid BuildNumber format: #{str}" if str.length != 10
      if m = /(\d\d\d\d)(\d\d)(\d\d)(\d\d)/.match(str)
        @time = Time.new(m[1].to_i, m[2].to_i, m[3].to_i)
        @serial = m[4].to_i
      else
        raise "Invalid BuildNumber format: #{str}" if str.length != 10
      end
    else
      @time = Time.now
      @serial = 1
    end
  end
  
  def to_s
    format("%04d%02d%02d%02d", @time.year, @time.month, @time.day, @serial)
  end
  
  def inc
    t = Time.now
    if t.year != @time.year || t.month != @time.month || t.day != @time.day
      @time = Time.now
      @serial = 1
    else
      raise "BuildNumber getting too large: #{to_s}" if @serial > 98
      @serial += 1
    end
    self
  end
  
end # class BuildNumber
  
# class GenBuildConst is used to generate build time constants
#
class GenBuildConst
  
  # URL of remote repository
  attr_reader :remote
  
  # git access object
  attr_reader :git
  
  # directory to read/write BuildConst.rb from/to
  attr_reader :dir
  
  # build parameters
  attr_reader :param
  
  # app build number
  attr_reader :buildNumber
  
  # app git hash
  attr_reader :hash
  
  # command line options
  attr_reader :options
  
  # Usage message
  @@Usage = <<~EOF
    SYNOPSIS
      genBuildConst [options]
      options:
        -d directory : where to write BuildConst.swift, LastBuildNumber.rb to
        -r remote    : URL of the remote repository
        -i           : ignore merge/commit and branch errors
        -n           : don't commit LastBuildNumber.rb
        -A           : archive mode, implied by environment variable
                         ACTION=install
      By default (in non archive mode) the options -in are applied to ignore
      merge/commit and branch errors and to not increase and commit
      LastBuildNumber.rb. In archive mode for errors is checked and the build
      number is incremented as well as LastBuildNumber.rb is committed and pushed
      to the remote repository.
  EOF
  
  def usage
    puts(@@Usage)
    exit(0)
  end
  
  # check whether merge/commit is needed and the local branch is in sync with
  # the remote branch
  #
  def checkState
    if !@options[:ignore]
      raise "Merge needed" if @git.needsMerge?
      raise "Commit needed:\n#{@git.filesChanged}" if @git.needsCommit?
    end
    @param = BuildParameters[@git.branch]
    if !@param
      @param = BuildParameters["alpha"] if @options[:ignore]
      raise "Invalid/Unknown branch: #{@git.branch}" if !@param
    end
    @hash = @git.localHash
    if !@options[:ignore] && @param.state != "alpha" && @hash != @git.remoteHash
      raise "Remote branch differs, perform merge first"
    end
  end
  
  # GenBuildConst.new manages the creation of BuildConst.swift
  #
  def initialize
    @dir = File.dirname($PROGRAM_NAME)
    @remote = "git@github.com:die-tageszeitung/taz-neo.ios.git"
    @options = {}
    if ENV["ACTION"] != "install"
      @options[:devel] = true
      @options[:ignore] = true
      @options[:noCommit] = true
    end
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
            when "d"[0]
              raise "-d argument missing" if av.length < 2
              @dir = av[1]
              av.shift
            when "r"[0]
              raise "-r argument missing" if av.length < 2
              @remote = av[1]
              av.shift
            when "i"[0]
              @options[:ignore] = true
            when "n"[0]
              @options[:noCommit] = true
            when "A"[0]
              @options[:devel] = false
              @options[:ignore] = false
              @options[:noCommit] = false
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
    @git = Git.new(@remote, @dir)
    checkState
  end
  
  # updateBuildNumber creates/increases the build number
  #
  def updateBuildNumber
    if File.exist?("#{@dir}/LastBuildNumber.rb")
      load("#{@dir}/LastBuildNumber.rb")
      @buildNumber = BuildNumber.new(LastBuildNumber)
      @buildNumber.inc if !@options[:devel]
    else
      @buildNumber = BuildNumber.new
    end
    File.open("#{dir}/LastBuildNumber.rb", "w") do |f|
      f.write("LastBuildNumber=\"#{@buildNumber}\"")
    end
    if !@options[:noCommit]
      Git.cmd(@dir, "add LastBuildNumber.rb")
      Git.cmd(@dir, "commit -m \"New build number #{@buildNumber}\"")
      Git.cmd(@dir, "push \"#{@git.remote}\"")
      @git.readStatus
      @hash = @git.localHash
    end
  end
  
  # write build constants to BuildConst.swift, ../ConfigSettings.xcconfig
  #
  def write
    swiftConst = <<~EOF
      // Generated on branch #{@git.branch} at #{Time.now.to_s}
      //
      public struct BuildConst {
        static var name: String { "#{@param.name}" }
        static var id: String { "#{@param.id}" }
        static var state: String { "#{@param.state}" }
        static var hash: String { "#{@hash}" }
      }
      EOF
    File.open("#{dir}/BuildConst.swift", "w") { |f| f.write(swiftConst) }
    schemeConst = <<~EOF
      PRODUCT_NAME = #{@param.name}
      PRODUCT_BUNDLE_IDENTIFIER = #{@param.id}
      CURRENT_PROJECT_VERSION = #{@buildNumber}
      EOF
    File.open("#{dir}/../ConfigSettings.xcconfig", "w") { |f| f.write(schemeConst) }
  end
  
end # class GenBuildConst

gbc = GenBuildConst.new
gbc.updateBuildNumber
gbc.write
