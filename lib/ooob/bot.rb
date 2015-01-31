require 'socket'
require 'yaml'
module Ooob
  class Bot
    attr_accessor :host, :port, :socket
    @@CONFIG = YAML.load_file('../../config.yml')
    def initialize(host, port)
      @host = @@CONFIG[:server][:hostname]
      @port = @@CONFIG[:server][:port]
      create_socket(@host, @port)
      post_init
    end

    def create_socket(host, port)
      begin
        @socket = TCPSocket.new(host, port)
      rescue SocketError, Errno::ECONNREFUSED => error
        puts "--Error opening socket--"
        if error.message == "getaddrinfo: Name or service not known"
          puts "Invalid hostname!"
        elsif error.message.include? "Connection refused"
          puts "Unable to connect to that socket!"
        else
          puts error.message
        end
        exit
      end

    end

    def post_init
      register()
      join_channel()
      listen()
    end

    def register 
      @socket.puts "NICK #{@@CONFIG[:name]}"
		  @socket.puts "USER #{@@CONFIG[:name]} #{@@CONFIG[:name]} #{@@CONFIG[:server][:hostname]} :#{@@CONFIG[:name]}"
    end

    def join_channel
      @socket.puts "JOIN ##{@@CONFIG[:channel]}"
    end

    def parse(line)
      #:agent_white!~agent_whi@184.21.106.205 PRIVMSG #learnprogramming :>> test
      #PING :hitchcock.freenode.net
      puts line
      case line
      when /PING/
        pong(line.split(":").last)
      when /(PRIVMSG.*?>>)/
        user = /:(.*?)!/.match(line).captures.first
        if @@CONFIG[:users].include? user
          code = line.split(":>>").last.strip
          run(code, user)
        else
          say(user, "Sorry, I am still under construction. Try again later!")
        end
      #TODO: change to proxy that routes commands
      when /PRIVMSG.*?:#{@@CONFIG[:name]}:\sremember/
        msg = line.split(":#{@@CONFIG[:name]}:").last.gsub!("remember", "").strip
        cmd, *cmd_response = msg.split
        remember(cmd, cmd_response.join(" "))
      #Run command
      when /(PRIVMSG.*?!!)/
        user = /:(.*?)!/.match(line).captures.first
        cmd = line.split("!!").last.to_sym
        if @@CONFIG[:commands].has_key? cmd
          say("#{@@CONFIG[:commands][cmd]}")
        end
      else
        #Do not know how to parse
      end
    end

    def run(code, user)
      #eval code; save return value; RESPONSE by SAYING to USER
      code.gsub!("puts", "p")
      code.gsub!("print", "p")
      begin
      result = eval(code, binding, __FILE__, __LINE__)
      if result == nil
        say(user, "nil")
      else
      say(user, result)
      end
      rescue NameError, NoMethodError, SyntaxError => e
        say(user, "#{e.class} raised!")
      end
      #say(user, result)
    end

    def say(target = nil, message)
      if target == nil
        socket.puts "PRIVMSG ##{@@CONFIG[:channel]} :#{message}"
      else
        @socket.puts "PRIVMSG ##{@@CONFIG[:channel]} :#{target}: #{message}"
      end
    end

    def pong(host)
      @socket.puts "PONG :#{@@CONFIG[:server][:hostname]}"
      puts "PONG------------->"
    end

    def remember(new_command, response)
      tmp = @@CONFIG 
      tmp[:commands][new_command.to_sym] = response
      File.open('../../config.yml', 'w') do |f|
        f.write tmp.to_yaml
      end
      say("#{new_command} saved!")
    end

    def add_user(user)
      tmp = @@CONFIG 
      tmp[:users] << user
      File.open('../../config.yml', 'w') do |f|
        f.write tmp.to_yaml
      end
      say(@@CONFIG[:channel], "#{user} added to authorized users!")
    end

    def listen
      Thread.new {
        while line = @socket.gets.chomp
          parse(line)
        end
      }
    end

  end

end

