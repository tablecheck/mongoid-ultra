# frozen_string_literal: true

module ActiveDocument
  module ImmutableIds
    def immutable_id_examples_as(name)
      shared_examples_for name do
        shared_examples 'a persisted document' do
          it 'disallows _id to be updated' do
            expect { invoke_operation! }
              .to raise_error(ActiveDocument::Errors::ImmutableAttribute)
          end

          context 'when immutable_ids is false' do
            before { ActiveDocument::Config.immutable_ids = false }
            after { ActiveDocument::Config.immutable_ids = true }

            it 'ignores the change and issue a warning' do
              expect(ActiveDocument::Warnings).to receive(:warn_mutable_ids)
              expect { invoke_operation! }.to_not raise_error
              expect(id_is_unchanged).to_not be legacy_behavior_expects_id_to_change
            end
          end

          context 'when id is set to the existing value' do
            let(:new_id_value) { object._id }

            it 'allows the update to proceed' do
              expect { invoke_operation! }
                .to_not raise_error
            end
          end
        end

        context 'when the field is _id' do
          let(:new_id_value) { 1234 }

          context 'when the document is top-level' do
            let(:legacy_behavior_expects_id_to_change) { false }

            context 'when the document is new' do
              let(:object) { Person.new }

              it 'allows _id to be updated' do
                invoke_operation!
                expect(object.new_record?).to be false
                expect(object.reload._id).to eq new_id_value
              end
            end

            context 'when the document has been persisted' do
              let(:object) { Person.create }
              let!(:original_id) { object._id }
              let(:id_is_unchanged) { Person.exists?(original_id) }

              it_behaves_like 'a persisted document'
            end
          end

          context 'when the document is embedded' do
            let(:parent) { Person.create }
            let(:legacy_behavior_expects_id_to_change) { true }

            context 'when the document is new' do
              let(:object) { parent.favorites.new }

              it 'allows _id to be updated' do
                invoke_operation!
                expect(object.new_record?).to be false
                expect(parent.reload.favorites.first._id).to eq new_id_value
              end
            end

            context 'when the document has been persisted' do
              let(:object) { parent.favorites.create }
              let!(:original_id) { object._id }
              let(:id_is_unchanged) { parent.favorites.exists?(_id: original_id) }

              it_behaves_like 'a persisted document'

              context 'updating embeds_one via parent' do
                context 'when immutable_ids is false' do
                  before { ActiveDocument::Config.immutable_ids = false }
                  after { ActiveDocument::Config.immutable_ids = true }

                  it 'ignores the change' do
                    expect(ActiveDocument::Warnings).to receive(:warn_mutable_ids)

                    parent.pet = pet = Pet.new
                    parent.save

                    original_id = pet._id
                    new_id = BSON::ObjectId.new

                    expect { parent.update(pet: { _id: new_id }) }.to_not raise_error
                    expect(parent.reload.pet._id.to_s).to eq original_id.to_s
                  end
                end

                context 'when immutable_ids is true' do
                  before { expect(ActiveDocument::Config.immutable_ids).to be true }

                  it 'raises an exception' do
                    parent.pet = Pet.new
                    parent.save

                    new_id = BSON::ObjectId.new

                    expect { parent.update(pet: { _id: new_id }) }
                      .to raise_error(ActiveDocument::Errors::ImmutableAttribute)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
