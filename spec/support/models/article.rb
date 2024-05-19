# frozen_string_literal: true

class Article
  include ActiveDocument::Document

  field :author_id, type: Integer
  field :public, type: ActiveDocument::Boolean
  field :title, type: String
  field :is_rss, type: ActiveDocument::Boolean, default: false
  field :user_login, type: String

  has_and_belongs_to_many :tags, validate: false
  has_and_belongs_to_many :preferences, inverse_of: nil, validate: false
end
