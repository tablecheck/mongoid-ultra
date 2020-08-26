class Crate
  include Mongoid::Document
  include Mongoid::Timestamps::Short

  embedded_in :crateable, polymorphic: true
  embeds_many :toys, cascade_callbacks: true

  accepts_nested_attributes_for :toys

  field :volume
end
