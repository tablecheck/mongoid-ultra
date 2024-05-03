# frozen_string_literal: true

require 'spec_helper'
require_relative './has_many_models'
require_relative './has_one_models'

describe Mongoid::Association::Referenced::AutoSave do

  describe '.auto_save' do

    before(:all) do
      Person.has_many :drugs, validate: false, autosave: true
      Person.has_one :account, validate: false, autosave: true
    end

    after(:all) do
      Person.reset_callbacks(:save)
    end

    it 'doesnt matter' do
      # true eq true
      expect(true).to eq(true)
    end
  end
end
