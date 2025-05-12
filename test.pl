use IO::Async::File;
use IO::Async::Loop;
my $loop = IO::Async::Loop->new;
my $file = IO::Async::File->new(
   filename => "/sys/class/power_supply/BAT1/capacity",
   on_mtime_changed => sub {
      my ( $self ) = @_;
      print "Capacity changed\n";
   }
);
$loop->add( $file );
$loop->run;

