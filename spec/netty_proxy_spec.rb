
require 'spec_helper'

describe Aspen::NettyProxy, "with Java setup" do

  it "should process request and create response" do
    @ctx = RackUtil.build_channel_handler_context 'localhost', '80'
    @req = DefaultHttpRequest.new( HttpVersion::HTTP_1_1, HttpMethod::GET, 'http://localhost/foo.html')
    @app = lambda { |env| [200, {}, ['hello world']] }
    @proxy = ::Aspen::NettyProxy.new(@app)

    response = @proxy.process(@ctx, @req)
    
    response.should_not be_nil
    response.status.should_not be_nil
    response.status.code.should == 200
    response.content.should_not be_nil
    # content_length operates on the Content-Length header, not the length of the data in the ChannelBuffer 
    # response.content_length.should == 'hello world'.length
    response.header_names.should_not be_nil
    response.header_names.size.should == 0
    response.is_chunked.should be_false
  end

  it "should include headers given" do
    @ctx = RackUtil.build_channel_handler_context 'localhost', '80'
    @req = DefaultHttpRequest.new( HttpVersion::HTTP_1_1, HttpMethod::GET, 'http://localhost/foo.html')
    @app = lambda { |env| [200, {'Content-Type' => 'text/plain'}, ['hello world']] }
    @proxy = ::Aspen::NettyProxy.new(@app)

    response = @proxy.process(@ctx, @req)

    response.should_not be_nil
    response.header_names.contains('Content-Type').should be_true
    response.get_header('Content-Type').should == 'text/plain'
  end
end