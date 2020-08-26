class Toy
  include Mongoid::Document
  include Mongoid::Timestamps::Short

  embedded_in :toyable, polymorphic: true

  field :type
end
