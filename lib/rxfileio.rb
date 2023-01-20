#!/usr/bin/env ruby

# file: rxfileio.rb

require 'rxfreadwrite'
require 'drb_fileclient'
require 'mymedia_ftp'



module RXFileIOModule
  include RXFReadWriteModule

  def FileX.exist?(filename) exist?(filename)     end
  def FileX.chmod(num, s) RXFileIO.chmod(num, s)  end
  def FileX.cp(s, s2)     RXFileIO.cp(s, s2)      end
  def FileX.ls(s)         RXFileIO.ls(s)          end
  def FileX.mkdir(s)      RXFileIO.mkdir(s)       end
  def FileX.mkdir_p(s)    RXFileIO.mkdir_p(s)     end
  def FileX.mv(s, s2)     RXFileIO.mv(s, s2)      end
  def FileX.read(x)       RXFileIO.read(x).first  end
  def FileX.rm(s)         RXFileIO.rm(s)          end

  def FileX.rm_r(s, force: false)
    RXFileIO.rm_r(s, force: force)
  end

  def FileX.ru(s)         RXFileIO.ru(s)          end
  def FileX.ru_r(s)       RXFileIO.ru_r(s)        end

  def FileX.touch(s, mtime: Time.now)
    RXFileIO.touch(s, mtime: mtime)
  end

  def FileX.write(x, s)   RXFileIO.write(x, s)    end
  def FileX.zip(s, a)     RXFileIO.zip(s, a)      end

end


class RXFileIOException < Exception
end

class RXFileIO < RXFReadWrite
  using ColouredText


  def self.chmod(permissions, s)

    return unless permissions.is_a? Integer
    return unless s.is_a? String

    if s[/^dfs:\/\//] or @@fs[0..2] == 'dfs' then
      DfsFile.chmod permissions, s
    else
      FileUtils.chmod permissions, s
    end

  end

  def self.cp(s1, s2, debug: false)

    found = [s1,s2].grep /^\w+:\/\//
    puts 'found: ' + found.inspect if debug

    if found.any? then

      case found.first[/^\w+(?=:\/\/)/]

      when 'dfs'
        DfsFile.cp(s1, s2)
      when 'ftp'
        MyMediaFTP.cp s1, s2
      else

      end

    else

      FileUtils.cp s1, s2

    end
  end



  def self.ls(x='*')

    return Dir[x] if File.exist?(File.dirname(x))

    case x[/^\w+(?=:\/\/)/]
    when 'file'
      Dir[x]
    when 'dfs'
      DfsFile.ls x
    when 'ftp'
      MyMediaFTP.ls x
    else

    end

  end

  def self.mkdir_p(x)

    if x[/^dfs:\/\//] or @@fs[0..2] == 'dfs' then
      DfsFile.mkdir_p x
    else
      FileUtils.mkdir_p x
    end

  end

  def self.mv(s1, s2)
    DfsFile.mv(s1, s2)
  end

  def self.read(x, h={})

    opt = {debug: false}.merge(h)

    debug = opt[:debug]

    puts 'x: ' + x.inspect if opt[:debug]
    raise RXFileIOException, 'nil found, expected a string' if x.nil?

    if x.class.to_s =~ /Rexle$/ then

      [x.xml, :rexle]

    elsif x.strip[/^<(\?xml|[^\?])/] then

      [x, :xml]

    elsif x.lines.length == 1 then

      puts 'x.lines == 1'.info if debug

      if x[/^https?:\/\//] then

        puts 'before GPDRequest'.info if debug

        r = if opt[:username] and opt[:password] then
          GPDRequest.new(opt[:username], opt[:password]).get(x)
        else
          response = RestClient.get(x)
        end

        case r.code
        when '404'
          raise(RXFileIOException, "404 %s not found" % x)
        when '401'
          raise(RXFileIOException, "401 %s unauthorized access" % x)
        end

        [r.body, :url]

      elsif  x[/^dfs:\/\//] then

        r = DfsFile.read(x)
        [r.force_encoding('UTF-8'), :dfs]

      elsif  x[/^ftp:\/\//] then

        [MyMediaFTP.read(x), :ftp]

      elsif x[/^file:\/\//] or File.exist?(x) then

        contents = File.read(File.expand_path(x.sub(%r{^file://}, '')))

        puts 'contents2: ' + contents.inspect if opt[:debug]

        puts 'opt: ' + opt.inspect if opt[:debug]

        [contents, :file]

      elsif x =~ /\s/
        [x, :text]
      elsif DfsFile.exists?(x)
        [DfsFile.read(x).force_encoding('UTF-8'), :dfs]
      else
        [x, :unknown]
      end

    else

      [x.force_encoding("UTF-8"), :unknown]
    end
  end

  def self.rm(filename)

    case filename[/^\w+(?=:\/\/)/]
    when 'dfs'
      DfsFile.rm filename
    when 'ftp'
      MyMediaFTP.rm filename
    else

      if File.basename(filename) =~ /\*/ then

        Dir.glob(filename).each do |file|

          begin
            FileUtils.rm file
          rescue
            puts ('RXFileIO#rm: ' + file + ' is a Directory').warning
          end

        end

      else
        FileUtils.rm filename
      end

    end

  end

  def self.rm_r(filename, force: false)

    case filename[/^\w+(?=:\/\/)/]
    when 'dfs'
      DfsFile.rm_r filename, force: force
    #when 'ftp'
    #  MyMediaFTP.rm filename
    else

      if File.basename(filename) =~ /\*/ then

        Dir.glob(filename).each do |file|

          begin
            FileUtils.rm_r file, force: force
          rescue
            puts ('RXFileIO#rm: ' + file + ' is a Directory').warning
          end

        end

      else
        FileUtils.rm_r filename, force: force
      end

    end

  end

  # recently_updated
  #
  def self.ru(path='.')

    case path[/^\w+(?=:\/\/)/]
    when 'dfs'
      DfsFile.ru path

    else

      DirToXML.new(path, recursive: false, verbose: false).latest

    end

  end

  # recently updated recursively check directories
  #
  def self.ru_r(path='.')

    case path[/^\w+(?=:\/\/)/]
    when 'dfs'
      DfsFile.ru_r path

    else

      DirToXML.new(path, recursive: true, verbose: false).latest

    end

  end

  def self.touch(filename, mtime: Time.now)

    if @@fs[0..2] == 'dfs' then
      return DfsFile.touch(@@fs + pwd + '/' + filename, mtime: mtime)
    end

    case filename[/^\w+(?=:\/\/)/]
    when 'dfs'
      DfsFile.touch filename, mtime: mtime
    #when 'ftp'
    #  MyMediaFTP.touch filename
    else
      FileUtils.touch filename, mtime: mtime
    end

  end

  def self.write(location, s=nil)

    case location
    when /^dfs:\/\//

      DfsFile.write location, s

    when  /^ftp:\/\// then

      MyMediaFTP.write location, s

    else

      if DfsFile.exists?(File.dirname(location)) then
        DfsFile.write location, s
      else
        File.write(location, s)
      end

    end

  end

  def self.writeable?(source)

    return false if source.lines.length > 1

    if not source =~ /:\/\// then

      return true if File.exist? source

    else

      return true if source =~ /^dfs:/

    end

    return false
  end

  def self.zip(filename, a)
    DfsFile.zip(filename, a)
  end

end
