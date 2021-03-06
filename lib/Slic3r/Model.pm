package Slic3r::Model;
use Moo;

use Slic3r::Geometry qw(X Y Z);

has 'materials' => (is => 'ro', default => sub { {} });
has 'objects'   => (is => 'ro', default => sub { [] });

sub read_from_file {
    my $class = shift;
    my ($input_file) = @_;
    
    my $model = $input_file =~ /\.stl$/i            ? Slic3r::Format::STL->read_file($input_file)
              : $input_file =~ /\.obj$/i            ? Slic3r::Format::OBJ->read_file($input_file)
              : $input_file =~ /\.amf(\.xml)?$/i    ? Slic3r::Format::AMF->read_file($input_file)
              : die "Input file must have .stl, .obj or .amf(.xml) extension\n";
    
    return $model;
}

sub add_object {
    my $self = shift;
    
    my $object = Slic3r::Model::Object->new(model => $self, @_);
    push @{$self->objects}, $object;
    return $object;
}

# flattens everything to a single mesh
sub mesh {
    my $self = shift;
    
    my @meshes = ();
    foreach my $object (@{$self->objects}) {
        my @instances = $object->instances ? @{$object->instances} : (undef);
        foreach my $instance (@instances) {
            my $mesh = $object->mesh->clone;
            if ($instance) {
                $mesh->rotate($instance->rotation);
                $mesh->align_to_origin;
                $mesh->move(@{$instance->offset});
            }
            push @meshes, $mesh;
        }
    }
    
    return Slic3r::TriangleMesh->merge(@meshes);
}

package Slic3r::Model::Material;
use Moo;

has 'model'         => (is => 'ro', weak_ref => 1, required => 1);
has 'attributes'    => (is => 'rw', default => sub { {} });

package Slic3r::Model::Object;
use Moo;

use Slic3r::Geometry qw(X Y Z);

has 'input_file' => (is => 'rw');
has 'model'     => (is => 'ro', weak_ref => 1, required => 1);
has 'vertices'  => (is => 'ro', default => sub { [] });
has 'volumes'   => (is => 'ro', default => sub { [] });
has 'instances' => (is => 'rw');

sub add_volume {
    my $self = shift;
    
    my $volume = Slic3r::Model::Volume->new(object => $self, @_);
    push @{$self->volumes}, $volume;
    return $volume;
}

sub add_instance {
    my $self = shift;
    
    $self->instances([]) if !defined $self->instances;
    push @{$self->instances}, Slic3r::Model::Instance->new(object => $self, @_);
    return $self->instances->[-1];
}

sub mesh {
    my $self = shift;
    
    return Slic3r::TriangleMesh->new(
        vertices => $self->vertices,
        facets   => [ map @{$_->facets}, @{$self->volumes} ],
    );
}

package Slic3r::Model::Volume;
use Moo;

has 'object'        => (is => 'ro', weak_ref => 1, required => 1);
has 'material_id'   => (is => 'rw');
has 'facets'        => (is => 'rw', default => sub { [] });

sub mesh {
    my $self = shift;
    return Slic3r::TriangleMesh->new(
        vertices => $self->object->vertices,
        facets   => $self->facets,
    );
}

package Slic3r::Model::Instance;
use Moo;

has 'object'    => (is => 'ro', weak_ref => 1, required => 1);
has 'rotation'  => (is => 'rw', default => sub { 0 });
has 'offset'    => (is => 'rw');

1;
