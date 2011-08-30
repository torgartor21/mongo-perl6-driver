use BSON;

class MongoDB::Wire is BSON;

# Implements Mongo Wire Protocol
# http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol

multi method _header ( Int $length, Str $op_code ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-StandardMessageHeader
    
    # struct MsgHeader {
    #     int32   messageLength; // total message size, including this
    #     int32   requestID;     // identifier for this message
    #     int32   responseTo;    // requestID from the original request
    #                            //   (used in reponses from db)
    #     int32   opCode;        // request type - see table below
    # }

    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-RequestOpcodes
    my %op_codes = {
        'OP_REPLY'          => 1,       # Reply to a client request. responseTo is set
        'OP_MSG'            => 1000,    # generic msg command followed by a string
        'OP_UPDATE'         => 2001,    # update document
        'OP_INSERT'         => 2002,    # insert new document
        'RESERVED'          => 2003,    # formerly used for OP_GET_BY_OID
        'OP_QUERY'          => 2004,    # query a collection
        'OP_GET_MORE'       => 2005,    # Get more data from a query. See Cursors
        'OP_DELETE'         => 2006,    # Delete documents
        'OP_KILL_CURSORS'   => 2007,    # Tell database client is done with a cursor
    }

    my $struct = self._int32( $length + 4 * 4 )
        ~ self._int32( ( 1 .. 2147483647 ).pick )
        ~ self._int32( 0 )
        ~ self._int32( %op_codes{ $op_code } );

    return $struct;
}

multi method _header ( Buf $b ) {
	
	my %h = (
		'length' => self._int32( $b ),
		'request_id' => self._int32( $b ),
		'response_to' => self._int32( $b ),
		'op_code' => self._int32( $b ),
	);
	
	return %h;
}

method OP_INSERT ( MongoDB::Collection $collection, %document, Int $flags = 0 ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPINSERT

    # struct {
    #     MsgHeader header;             // standard message header
    #     int32     flags;              // bit vector - see below
    #     cstring   fullCollectionName; // "dbname.collectionname"
    #     document* documents;          // one or more documents to insert into the collection
    # }

    my $struct = self._int32( $flags )
        ~ self._cstring( join '.', $collection.database.name, $collection.name )
        ~ self._document( %document );

    my $header = self._header( +$struct.contents, 'OP_INSERT' );

    $collection.database.connection.send( $header ~ $struct, False );
}

method OP_QUERY ( MongoDB::Collection $collection, %query, Int $flags = 0 ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPQUERY

#     struct OP_QUERY {
#         MsgHeader header;                // standard message header
#         int32     flags;                  // bit vector of query options
#         cstring   fullCollectionName;    // "dbname.collectionname"
#         int32     numberToSkip;          // number of documents to skip
#         int32     numberToReturn;        // number of documents to return
#                                      //  in the first OP_REPLY batch
#         document  query;                 // query object.  See below for details.
#         [ document  returnFieldSelector; ] // Optional. Selector indicating the fields
#                                      //  to return.  See below for details.
#     }


    my $struct = self._int32( 0 )
        ~ self._cstring( join '.', $collection.database.name, $collection.name )
        ~ self._int32( 0 )
        ~ self._int32( 0 )
        ~ self._document( %query );

    my $header = self._header( +$struct.contents, 'OP_QUERY' );

    my $reply = $collection.database.connection.send( $header ~ $struct, True );
    $reply.contents.perl.say;
	self.OP_REPLY( $reply );
}

method OP_REPLY ( Buf $b ) {
	# struct {
	#     MsgHeader header;         // standard message header
	#     int32     responseFlags;  // bit vector - see details below
	#     int64     cursorID;       // cursor id if client needs to do get more's
	#     int32     startingFrom;   // where in the cursor this reply is starting
	#     int32     numberReturned; // number of documents in the reply
	#     document* documents;      // documents
	# }
	
	my %r = (
	 	'header' => self._header( $b ),
	my $f = self._int32( $b );
	my $c = MongoDB::Cursor.new( b => $b );
	my $s = self._int32( $b );
	my $r = self._int32( $b );
	my @d;
	for ^$r {
		my %d = self._document( $b );
		@d.push( { %d } )
	}
	@d.perl.say;
}

# HACK to concatenate 2 Buf()s
# workaround for https://rt.perl.org/rt3/Public/Bug/Display.html?id=96430
multi sub infix:<~>(Buf $a, Buf $b) {

    return Buf.new( $a.contents.list, $b.contents.list );
}
