package com.github.kevwil.aspen;

import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.handler.codec.http.*;
import org.jruby.*;
import org.slf4j.*;

import java.util.*;

/**
 * internal class for output translation
 * @author kevwil
 * @since Jul 1, 2009
 */
public final class RackResponseTranslator
{
    private static final Logger log = LoggerFactory.getLogger( RackResponseTranslator.class );

    /**
     * Tranlate Rack output into Netty HttpResponse
     * @param rackOutput result of all Rack middleware output
     * @return response for Netty to return
     * @throws RackException if something goes wrong
     */
    public static HttpResponse translate( RubyArray rackOutput ) throws RackException
    {
        if( rackOutput.size() != 3 )
        {
            RackException ex = new RackException( "received output not in the form of a 3-element array" );
            log.error( "error translating rack output into Netty HttpResponse", ex );
            throw ex;
        }

        int status = RubyInteger.num2int( rackOutput.entry( 0 ).convertToInteger() );
        Map<String,String> headers = new HashMap<String,String>();
        RubyHash rackHash = rackOutput.entry( 1 ).convertToHash();
        for( Object key : rackHash.keySet() )
        {
            headers.put( key.toString(), rackHash.get( key ).toString() );
        }
        String body = rackOutput.entry( 2 ).asJavaString();

        HttpResponse response = new DefaultHttpResponse(
                HttpVersion.HTTP_1_1,
                HttpResponseStatus.valueOf( status ) );
        for( String key : headers.keySet() )
        {
            response.addHeader( key, headers.get( key ) );
        }
         // TODO: need correct content-type
        response.setContent( ChannelBuffers.copiedBuffer( body, "UTF-8" ) );
        return response;
    }
}