package AttachContentPluginTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use warnings;
use Error qw( :try );
use Foswiki;

my $DEBUG = 0;

sub new {
    my $self = shift()->SUPER::new( 'AttachContentPlugin', @_ );
    return $self;
}

sub loadExtraConfig {
    my $this = shift;
    $this->SUPER::loadExtraConfig();
    setLocalSite();
}

sub setLocalSite {
    $Foswiki::cfg{Plugins}{AttachContentPlugin}{Enabled} = 1;
    $Foswiki::cfg{Plugins}{AttachContentPlugin}{Debug}   = $DEBUG;
}

sub test_STARTATTACH {
    my ($this) = @_;

    my $input = '<verbatim>%STARTATTACH{"mysaved.txt"}%
My content
%ENDATTACH%';

    my $expected = <<END_EXPECTED;
<verbatim>
My content
</verbatim>
END_EXPECTED

    _trimSpaces($input);
    _trimSpaces($expected);

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web} );
    $this->_performTestHtmlOutput( $expected, $result, 0 );
}

sub test_save {
    my ($this) = @_;

    my $testText = <<'HERE';
%META:TOPICINFO{author="ProjectContributor" date="1111931141" format="1.0" version="$Rev$"}%
<verbatim>%STARTATTACH{"mysaved.txt"}%
My content
%ENDATTACH%
after
HERE
    my $UI_FN = $this->getUIFn('save');
    Foswiki::Func::saveTopicText( $this->{test_web}, "MyTopic", $testText );
    my $query = new Unit::Request(
        {
            action => ['save'],
            topic  => [ $this->{test_web} . '.MyTopic' ]
        }
    );
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $this->captureWithKey( save => $UI_FN, $this->{session} );
    my $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web}, 'MyTopic' );

    my @attachments = $meta->find('FILEATTACHMENT');

    $this->assert_equals( scalar @attachments, 1 );

    foreach my $a (@attachments) {
        try {
            my $fh = $meta->openAttachment( $a->{name}, '<' );
            my $data = <$fh>;
            $this->assert_equals( $data, 'My content' );
        }
        catch Foswiki::AccessControlException with {
            print STDOUT "ERROR reading attachment data\n";
        };
    }

}

=pod

_trimSpaces( $text ) -> $text

Removes spaces from both sides of the text.

=cut

sub _trimSpaces {

    #my $text = $_[0]

    $_[0] =~ s/^[[:space:]]+//s;    # trim at start
    $_[0] =~ s/[[:space:]]+$//s;    # trim at end
}

=pod

This formats the text up to immediately before <nop>s are removed, so we
can see the nops.

=cut

sub _performTestHtmlOutput {
    my ( $this, $expected, $actual, $doRender ) = @_;
    my $session   = $this->{session};
    my $webName   = $this->{test_web};
    my $topicName = $this->{test_topic};

    $actual = _renderHtml( $webName, $topicName, $actual ) if ($doRender);
    $this->assert_html_equals( $expected, $actual );
}

1;
