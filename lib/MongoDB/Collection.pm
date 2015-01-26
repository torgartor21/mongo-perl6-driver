use MongoDB::Protocol;
use MongoDB::Cursor;

class MongoDB::Collection does MongoDB::Protocol;

has $.database is rw;
has Str $.name is rw;

submethod BUILD ( :$database, Str :$name ) {

    $!database = $database;

    # TODO validate name
    $!name = $name;
}

method insert ( **@documents, Bool :$continue_on_error = False ) {

    my $flags = +$continue_on_error;

    my @docs;
    if @documents.isa(LoL) {
      if @documents[0].isa(Array) and [&&] @documents[0].list>>.isa(Hash) {
        @docs = @documents[0].list;
      }

      elsif @documents.list>>.isa(Hash) {
        @docs = @documents.list;
      }

      else {
        die "Error: Document type not handled by insert";
      }
    }

    else {
      die "Error: Document type not handled by insert";
    }

    self.wire.OP_INSERT( self, $flags, @docs );
}

method find (
    %criteria = { }, %projection = { },
    Int :$number_to_skip = 0, Int :$number_to_return = 0,
    Bool :$no_cursor_timeout = False
    --> MongoDB::Cursor
) {

    my $flags = +$no_cursor_timeout +< 4;
    my $OP_REPLY;
      $OP_REPLY = self.wire.OP_QUERY( self, $flags, $number_to_skip,
                                      $number_to_return, %criteria,
                                      %projection
                                    );

    return MongoDB::Cursor.new(
        collection  => self,
        OP_REPLY    => $OP_REPLY,
    );
}

method find_one ( %criteria = { }, %projection = { } --> Hash) {

    my MongoDB::Cursor $cursor = self.find( %criteria, %projection
                                          , :number_to_return(1)
                                          );
    return $cursor.fetch();
}

method update (
    %selector, %update,
    Bool :$upsert = False, Bool :$multi_update = False
) {

    my $flags = +$upsert
        + +$multi_update +< 1;

    self.wire.OP_UPDATE( self, $flags, %selector, %update );
}

method remove (
    %selector = { },
    Bool :$single_remove = False
) {

    my $flags = +$single_remove;

    self.wire.OP_DELETE( self, $flags, %selector );
}
