require 'java'
require File.dirname(__FILE__) + '/aspenj.jar'
import com.github.kevwil.aspen.RackProxy
import com.github.kevwil.aspen.RackUtil
import java.nio.ByteBuffer
import java.nio.CharBuffer
import java.nio.channels.Channels
import org.jboss.netty.channel.ChannelHandlerContext
import org.jboss.netty.buffer.ChannelBuffers
import org.jboss.netty.buffer.ChannelBufferInputStream
import org.jboss.netty.handler.codec.http.DefaultHttpResponse
import org.jboss.netty.handler.codec.http.HttpResponseStatus
import org.jboss.netty.handler.codec.http.HttpVersion
require 'stringio'
require 'aspen/version'

module Aspen

  class RackParseError < RuntimeError; end

  # implementation of RackProxy interface from Java side
  # @author Kevin Williams
  # @since 1.0.0
  # @version 1.0.0
  class NettyProxy

    # implement RackProxy interface
    # @todo stay on top of JRuby interface use, in case behavior changes
    include RackProxy

    # create new instance of NettyProxy
    # @param #call(env) a Ruby Object which responds to :call(env)
    # @return [Array]an array of [Integer (status code), Hash (headers), and Object responding to #each returning Strings]
    def initialize( app )
      @app = app
    end

    # process an incoming message which has been received on the socket
    # this method does most of the heavy lifting of translating Netty classes and behaviors into Rack 
    # @param [ChannelHandlerContext] the Netty context for message handling
    # @param [HttpRequest] the Netty request object
    # @return [HttpResponse] the Netty response
    # @todo handle chunking, keep-alive, content-encoding, etc.
    def process( cxt, req )
      env = {}
      RackUtil.parse_headers( cxt, req, env )
      env["SCRIPT_NAME"] = ""  if env["SCRIPT_NAME"] == "/"
      env.delete "PATH_INFO"  if env["PATH_INFO"] == ""
      env["SERVER_PORT"] = "80" unless env["SERVER_PORT"]
      data = req.content.to_string("UTF-8").to_s
      rack_input = StringIO.new( data )
      rack_input.set_encoding( Encoding::BINARY ) if rack_input.respond_to?( :set_encoding )
      env.update( {"rack.version" => ::Aspen::VERSION::RACK,
                   "rack.input" => rack_input,
                   "rack.errors" => $stderr,

                   "rack.multithread" => true,
                   "rack.multiprocess" => false,
                   "rack.run_once" => false,

                   "rack.url_scheme" => "http",
                 } )

      # g env.inspect if Logging.debug?
      status, headers, body = @app.call(env)
      # g body.inspect if (Logging.debug? and body)
      # g status.inspect if (Logging.debug? and status)
      raise RackParseError, "status is a #{status.class} class, not an integer" unless status.is_a?(Integer)
      raise RackParseError, "body doesn't respond to :each and return strings" unless body.respond_to?(:each)

      resp = DefaultHttpResponse.new( HttpVersion::HTTP_1_1, HttpResponseStatus.value_of( status ) )
      headers.each do |k,vs|
        vs.each { |v| resp.add_header k, v.chomp } if vs
      end if headers
      out_buf = ChannelBuffers.dynamic_buffer
      body.each do |line|
        out_buf.write_bytes ChannelBuffers.copied_buffer( line, "UTF-8" )
      end
      resp.content = out_buf
      # g resp.inspect if Logging.debug?
      resp
    end
  end
end