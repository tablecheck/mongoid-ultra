# frozen_string_literal: true

class Alert
  include ActiveDocument::Document
  field :message, type: String
  belongs_to :account
  has_many :items
  belongs_to :post
end
