# frozen_string_literal: true

require 'spec_helper'

describe Mongoid::Criteria do

  describe '#only' do

    let!(:band) do
      Band.create!(name: 'Depeche Mode', likes: 3, views: 10)
    end

    context 'when not using inheritance' do

      context 'when passing splat args' do

        let(:criteria) do
          Band.only(:_id)
        end

        it 'limits the returned fields' do
          expect do
            criteria.first.name
          end.to raise_error(Mongoid::Errors::AttributeNotLoaded, /Attempted to access attribute 'name' on Band which was not loaded/)
        end

        it 'does not add _type to the fields' do
          expect(criteria.options[:fields]['_type']).to be_nil
        end
      end

      context 'when not including id' do

        let(:criteria) do
          Band.only(:name)
        end

        it 'responds to id anyway' do
          expect do
            criteria.first.id
          end.to_not raise_error
        end
      end

      context 'when passing an array' do

        let(:criteria) do
          Band.only(%i[name likes])
        end

        it 'includes the limited fields' do
          expect(criteria.first.name).to_not be_nil
        end

        it 'excludes the non included fields' do
          expect do
            criteria.first.active
          end.to raise_error(Mongoid::Errors::AttributeNotLoaded, /Attempted to access attribute 'active' on Band which was not loaded/)
        end

        it 'does not add _type to the fields' do
          expect(criteria.options[:fields]['_type']).to be_nil
        end
      end

      context 'when instantiating a class of another type inside the iteration' do

        let(:criteria) do
          Band.only(:name)
        end

        it 'only limits the fields on the correct model' do
          criteria.each do |_band|
            expect(Person.new.age).to eq(100)
          end
        end
      end

      context 'when instantiating a document not in the result set' do

        let(:criteria) do
          Band.only(:name)
        end

        it 'only limits the fields on the correct criteria' do
          criteria.each do |_band|
            expect(Band.new.active).to be true
          end
        end
      end

      context 'when nesting a criteria within a criteria' do

        let(:criteria) do
          Band.only(:name)
        end

        it 'only limits the fields on the correct criteria' do
          criteria.each do |_band|
            Band.all.each do |b|
              expect(b.active).to be true
            end
          end
        end
      end
    end

    context 'when using inheritance' do
      context 'when using the default discriminator key' do
        let(:criteria) do
          Doctor.only(:_id)
        end

        it 'adds _type to the fields' do
          expect(criteria.options[:fields]).to include('_type')
        end
      end

      context 'when setting a custom discriminator key' do
        before do
          Person.discriminator_key = 'dkey'
        end

        after do
          Person.discriminator_key = nil
        end

        let(:criteria) do
          Doctor.only(:_id)
        end

        it 'adds custom discriminator key to the fields' do
          expect(criteria.options[:fields]).to include('dkey')
        end

        it 'does not add _type to the fields' do
          expect(criteria.options[:fields]).to_not include('_type')
        end
      end
    end

    context 'when limiting to embedded documents' do

      context 'when the embedded documents are aliased' do

        let(:criteria) do
          Person.only(:phones)
        end

        it 'properly uses the database field name' do
          expect(criteria.options).to eq(fields: { '_id' => 1, 'mobile_phones' => 1 })
        end
      end
    end

    context 'when the field is localized' do
      with_default_i18n_configs

      let(:dictionary) { Dictionary.new }

      around { |example| I18n.with_locale(:de) { example.run } }

      before do
        I18n.with_locale(:en) { dictionary.description = 'english-text' }
        dictionary.description = 'deutsch-text'
        dictionary.save!
      end

      context 'when entire field is included' do

        let(:dict_descr) do
          Dictionary.only(:description).first
        end

        it 'loads all translations' do
          expect(dict_descr.description_translations.keys).to include('de', 'en')
        end

        it 'returns the field value for the current locale' do
          expect(dict_descr.description).to eq('deutsch-text')
        end

        it 'returns the field value for the en locale' do
          I18n.with_locale(:en) do
            expect(dict_descr.description).to eq('english-text')
          end
        end
      end

      context 'when a specific locale is included' do

        let(:dict_descr_de) do
          Dictionary.only(:'description.de').first
        end

        it 'loads translations only for the included locale' do
          expect(dict_descr_de.description_translations.keys).to include('de')
          expect(dict_descr_de.description_translations.keys).to_not include('en')
        end

        it 'returns the field value for the included locale' do
          expect(dict_descr_de.description).to eq('deutsch-text')
        end

        it 'doesnt return the field value for the excluded locale' do
          I18n.with_locale(:en) do
            expect(dict_descr_de.description).to be_nil
          end
        end
      end

      context 'when entire field is excluded' do

        let(:dict_wo_descr) do
          Dictionary.without(:description).first
        end

        it 'does not load all translations' do
          expect(dict_wo_descr.description_translations.keys).to_not include('de', 'en')
        end

        it 'raises an Mongoid::Errors::AttributeNotLoaded when attempting to access the field' do
          expect { dict_wo_descr.description }.to raise_error Mongoid::Errors::AttributeNotLoaded
        end
      end

      context 'when a specific locale is excluded' do

        let(:dict_wo_descr_de) do
          Dictionary.without(:'description.de').first
        end

        it 'does not load excluded translations' do
          expect(dict_wo_descr_de.description_translations.keys).to_not include('de')
          expect(dict_wo_descr_de.description_translations.keys).to include('en')
        end

        it 'returns nil for excluded translations' do
          expect(dict_wo_descr_de.description).to be_nil
        end

        it 'returns the field value for included translations' do
          I18n.with_locale(:en) do
            expect(dict_wo_descr_de.description).to eq('english-text')
          end
        end
      end
    end

    context 'when restricting to id' do

      context 'when id is aliased to _id' do
        shared_examples 'requests _id field' do
          it 'requests _id field' do
            expect(criteria.options[:fields]).to eq({ '_id' => 1 })
          end
        end

        ['id', '_id', :id, :_id].each do |field|
          context "using #{field.inspect}" do
            let(:criteria) do
              Band.where.only(field)
            end

            include_examples 'requests _id field'
          end
        end

        context 'using a content field' do
          let(:criteria) do
            Band.where.only(:name)
          end

          it 'requests content field and _id field' do
            expect(criteria.options[:fields]).to eq({ '_id' => 1, 'name' => 1 })
          end
        end
      end

      context 'when id is not aliased to _id' do
        shared_examples 'requests _id field' do
          it 'requests _id field' do
            expect(criteria.options[:fields]).to eq({ '_id' => 1 })
          end
        end

        shared_examples 'requests id field and _id field' do
          it 'requests id field and _id field' do
            expect(criteria.options[:fields]).to eq({ '_id' => 1, 'id' => 1 })
          end
        end

        ['_id', :_id].each do |field|
          context "using #{field.inspect}" do
            let(:criteria) do
              Shirt.where.only(field)
            end

            include_examples 'requests _id field'
          end
        end

        ['id', :id].each do |field|
          context "using #{field.inspect}" do
            let(:criteria) do
              Shirt.where.only(field)
            end

            include_examples 'requests id field and _id field'
          end
        end
      end
    end
  end

  describe '#without' do

    let!(:person) do
      Person.create!(username: 'davinci', age: 50, pets: false)
    end

    context 'when omitting to embedded documents' do

      context 'when the embedded documents are aliased' do

        let(:criteria) do
          Person.without(:phones)
        end

        it 'properly uses the database field name' do
          expect(criteria.options).to eq(fields: { 'mobile_phones' => 0 })
        end
      end
    end

    context 'when excluding id fields' do

      shared_examples 'does not raise error' do
        it 'does not raise error' do
          expect do
            criteria.first._id
          end.to_not raise_error
        end
      end

      shared_examples 'does not unproject _id' do
        it 'does not unproject _id' do
          expect(criteria.options[:fields]).to be_nil
        end

        it 'returns id anyway' do
          expect(criteria.first.id).to_not be_nil
        end
      end

      shared_examples 'unprojects id' do
        it 'does not unproject _id' do
          expect(criteria.options[:fields]).to eq({ 'id' => 0 })
        end

        let(:instance) { criteria.first }

        it 'returns _id' do
          expect(instance._id).to eq('foo')
        end

        it 'does not return id' do
          expect do
            instance.id
          end.to raise_error(Mongoid::Errors::AttributeNotLoaded, /Attempted to access attribute 'id' on Shirt which was not loaded/)
        end
      end

      context 'model with id aliased to _id' do
        context 'id field' do
          let(:criteria) do
            Person.without(:id, 'id')
          end

          include_examples 'does not raise error'
          include_examples 'does not unproject _id'
        end

        context '_id field' do
          let(:criteria) do
            Person.without(:_id, '_id')
          end

          include_examples 'does not raise error'
          include_examples 'does not unproject _id'
        end
      end

      context 'model without id aliased to _id' do
        let!(:shirt) { Shirt.create!(id: 1, _id: 'foo') }

        context 'id field' do
          let(:criteria) do
            Shirt.without(:id, 'id')
          end

          include_examples 'does not raise error'
          include_examples 'unprojects id'
        end

        context '_id field' do
          let(:criteria) do
            Shirt.without(:_id, '_id')
          end

          include_examples 'does not raise error'
          include_examples 'does not unproject _id'
        end
      end
    end
  end
end
