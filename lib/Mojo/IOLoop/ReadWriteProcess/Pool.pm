package Mojo::IOLoop::ReadWriteProcess::Pool;
our $VERSION = "0.04";
use Mojo::Base 'Mojo::Collection';

sub get { my $s = shift; @{$s}[+shift()] }
sub add { push @{+shift()}, Mojo::IOLoop::ReadWriteProcess->new(@_) }
sub remove { my $s = shift; delete @{$s}[+shift()] }

sub _cmd {
  my $c    = shift;
  my $f    = pop;
  my @args = @_;
  my @r;
  $c->each(
    sub {
      push(@r, +shift()->$f(@args));
    });
  wantarray ? @r : $c;
}

sub AUTOLOAD {
  our $AUTOLOAD;
  my $fn = $AUTOLOAD;
  $fn =~ s/.*:://;
  return if $fn eq "DESTROY";
  +shift()->_cmd(@_, $fn);
}

1;

=encoding utf-8

=head1 NAME

Mojo::IOLoop::ReadWriteProcess::Pool - Pool of Mojo::IOLoop::ReadWriteProcess objects.

=head1 SYNOPSIS

    my $n_proc = 20;
    my $fired;

    my $p = parallel sub { print "Hello world\n"; } => $n_proc;

    # Subscribe to all "stop" events in the pool
    $p->once(stop => sub { $fired++; });

    # Start all processes belonging to the pool
    $p->start();

    # Receive the process output
    $p->each(sub { my $p = shift; $p->getline(); });
    $p->wait_stop;

    # Get the last one! (it's a Mojo::Collection!)
    $p->last()->stop();

=head1 METHODS

L<Mojo::IOLoop::ReadWriteProcess::Pool> inherits all methods from L<Mojo::Collection> and implements
the following new ones.
Note: It proxies all the other methods of L<Mojo::IOLoop::ReadWriteProcess> for the whole process group.

=head2 get

    use Mojo::IOLoop::ReadWriteProcess qw(parallel);
    my $pool = parallel(sub { print "Hello" } => 5);
    $pool->get(4);

Get the element specified in the pool (starting from 0).

=head2 add

    use Mojo::IOLoop::ReadWriteProcess qw(parallel);
    my $pool = pool;
    $pool->add(sub { print "Hello 2! " });

Add the element specified in the pool.


=head2 remove

    use Mojo::IOLoop::ReadWriteProcess qw(parallel);
    my $pool = parallel(sub { print "Hello" } => 5);
    $pool->remove(4);

Remove the element specified in the pool.


=head1 LICENSE

Copyright (C) Ettore Di Giacinto.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Ettore Di Giacinto E<lt>edigiacinto@suse.comE<gt>
