# frozen_string_literal: true

require 'spec_helper'
require_relative '../belongs_to_models'

describe Mongoid::Association::Referenced::BelongsTo::Proxy do

  before(:all) do
    Person.reset_callbacks(:validate)
  end

  let(:person) do
    Person.create!
  end

  describe '#= nil' do

    context 'when dependent is nullify' do

      let(:account) do
        Account.create!(name: 'Foobar')
      end

      let(:drug) do
        Drug.create!
      end

      let(:person) do
        Person.create!
      end

      context 'when relation is has_many' do

        around do |example|
          original_drug_dependents = Drug.dependents
          Drug.dependents = []
          example.run
          Drug.dependents = original_drug_dependents
        end

        before do
          Drug.belongs_to :person, dependent: :nullify
          Person.has_many :drugs
          person.drugs = [drug]
          person.save!
        end

        context 'when parent exists' do

          context 'when child is destroyed' do

            before do
              drug.destroy
            end

            it 'deletes child' do
              expect(drug).to be_destroyed
            end

            # it "doesn't delete parent" do
            #   expect(person).to_not be_destroyed
            # end

            # it 'removes the link' do
            #   expect(person.drugs).to eq([])
            # end
          end
        end
      end
    end

  end

end
