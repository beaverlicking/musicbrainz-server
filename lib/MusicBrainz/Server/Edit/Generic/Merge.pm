package MusicBrainz::Server::Edit::Generic::Merge;
use Moose;
use MooseX::ABC;

use MusicBrainz::Server::Constants qw( :expire_action :quality );
use MusicBrainz::Server::Data::Utils qw( model_to_type );
use MooseX::Types::Moose qw( ArrayRef Int Str );
use MooseX::Types::Structured qw( Dict );

extends 'MusicBrainz::Server::Edit';
requires '_merge_model';

sub alter_edit_pending
{
    my $self = shift;
    return {
        $self->_merge_model => $self->_entity_ids
    }
}

sub related_entities
{
    my $self = shift;
    return {
        model_to_type($self->_merge_model) => $self->_entity_ids
    }
}

sub edit_conditions
{
    return {
        $QUALITY_LOW => {
            duration      => 4,
            votes         => 1,
            expire_action => $EXPIRE_ACCEPT,
            auto_edit     => 0,
        },
        $QUALITY_NORMAL => {
            duration      => 14,
            votes         => 3,
            expire_action => $EXPIRE_ACCEPT,
            auto_edit     => 0,
        },
        $QUALITY_HIGH => {
            duration      => 14,
            votes         => 4,
            expire_action => $EXPIRE_REJECT,
            auto_edit     => 0,
        },
    };
}

has '+data' => (
    isa => Dict[
        new_entity_id => Int,
        old_entities => ArrayRef[ Dict[
            name => Str,
            id   => Int
        ] ]
    ]
);

sub new_entity_id { shift->data->{new_entity_id} }

sub foreign_keys
{
    my $self = shift;
    return {
        $self->_merge_model => $self->_entity_ids
    }
}

sub build_display_data
{
    my ($self, $loaded) = @_;
    my $model = $self->_merge_model;

    my $data = {
        new => $loaded->{ $model }->{ $self->new_entity_id },
        old => []
    };

    for my $old (@{ $self->data->{old_entities} }) {
        my $ent = $loaded->{ $model }->{ $old->{id} } ||
            $self->c->model($model)->_entity_class->new($old);

        push @{ $data->{old} }, $ent;
    }

    return $data;
}

override 'accept' => sub
{
    my $self = shift;
    $self->c->model( $self->_merge_model )->merge($self->new_entity_id, $self->_old_ids);
};

sub _entity_ids
{
    my $self = shift;
    return [
        $self->new_entity_id,
        $self->_old_ids
    ];
}

sub _old_ids
{
    my $self = shift;
    return map { $_->{id} } @{ $self->data->{old_entities} }
}

sub _xml_arguments { ForceArray => ['old_entities'] }

__PACKAGE__->meta->make_immutable;
no Moose;

1;

