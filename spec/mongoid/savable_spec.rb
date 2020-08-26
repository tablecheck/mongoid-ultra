require "spec_helper"

describe 'savable' do
  context 'with multiple insert ops' do
    let!(:truck) { Truck.create(capacity: 100) }
    let!(:crate) { truck.crates.create(volume: 0.4) }

    it 'push multiple' do
      expect(truck.crates.size).to eq 1
      expect(truck.crates[0].volume).to eq 0.4
      expect(truck.crates[0].toys.size).to eq 0

      truck.crates.first.toys.build(type: "Teddy bear")
      truck.crates.build(volume: 0.8)

      # The following is equivalent to the two lines above:
      #
      # truck.crates_attributes = {
      #   '0' => {
      #     "toys_attributes" => {
      #       "0" => {
      #         "type" => "Teddy bear"
      #       }
      #     },
      #     "id" => crate.id.to_s
      #   },
      #   "1" => {
      #     "volume" => 0.8
      #   }
      # }

      expect(truck.crates.size).to eq 2
      expect(truck.crates[0].volume).to eq 0.4
      expect(truck.crates[0].toys.size).to eq 1
      expect(truck.crates[0].toys[0].type).to eq "Teddy bear"
      expect(truck.crates[1].volume).to eq 0.8
      expect(truck.crates[1].toys.size).to eq 0

      expect(truck.atomic_updates[:conflicts]).to eq nil

      expect { truck.save }.not_to raise_error

      truck.reload
      expect(truck.crates.size).to eq 1
      expect(truck.crates[0].volume).to eq 0.4
      expect(truck.crates[0].toys.size).to eq 0
      # expect(truck.crates[0].toys[0].type).to eq "Teddy bear"

      # expect(truck.crates.size).to eq 2
      # expect(truck.crates[0].volume).to eq 0.4
      # expect(truck.crates[0].toys.size).to eq 1
      # expect(truck.crates[0].toys[0].type).to eq "Teddy bear"
      # expect(truck.crates[1].volume).to eq 0.8
      # expect(truck.crates[1].toys.size).to eq 0
    end
  end
end
