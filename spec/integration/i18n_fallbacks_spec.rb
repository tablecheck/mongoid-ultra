# frozen_string_literal: true

require 'spec_helper'

describe 'i18n fallbacks' do
  with_i18n_fallbacks

  context 'when fallbacks are enabled with a locale list' do
    with_default_i18n_configs

    before { I18n.fallbacks[:de] = [:en] }

    let(:product) { Product.new }

    context 'when translation is present in active locale' do
      around { |example| I18n.with_locale(:de) { example.run } }

      before do
        product.description = 'Marvelous in German'
        I18n.with_locale(:en) { product.description = 'Marvelous!' }
      end

      it 'uses active locale' do
        expect(product.description).to eq('Marvelous in German')
      end
    end

    context 'when translation is missing in active locale and present in fallback locale' do
      around { |example| I18n.with_locale(:de) { example.run } }
      before { I18n.with_locale(:en) { product.description = 'Marvelous!' } }

      it 'falls back on default locale' do
        expect(product.description).to eq('Marvelous!')
      end
    end

    context 'when translation is missing in all locales' do
      around { |example| I18n.with_locale(:ru) { example.run } }
      before { I18n.with_locale(:en) { product.description = 'Marvelous!' } }

      it 'returns nil' do
        expect(product.description).to be_nil
      end
    end
  end
end
