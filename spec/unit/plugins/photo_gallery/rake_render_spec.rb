require 'spec_helper'
require 'rake'
require 'tmpdir'
require_relative '../../../../public/plugin/lokka-photo_gallery/lib/lokka/photo_gallery'

describe 'photo_gallery:render' do
  around do |example|
    previous = Rake.application
    Rake.application = Rake::Application.new
    load File.expand_path('../../../../public/plugin/lokka-photo_gallery/Rakefile', __dir__)
    Dir.mktmpdir('photo-gallery-ordering') do |folder|
      @folder = folder
      @metadata = [
        { filename: '10.jpg', url: 'https://example.test/10.jpg', taken_at: '2020:01:01 10:00:00' },
        { filename: '2.jpg', url: 'https://example.test/2.jpg', taken_at: '2022-01-01' },
        { filename: '1.jpg', url: 'https://example.test/1.jpg', taken_at: '2021-01-01' }
      ].to_json
      File.write(File.join(folder, 'metadata.json'), @metadata)
      example.run
    end
  ensure
    Rake.application = previous
  end

  it 'preserves filename ordering without an extra argument' do
    expect { Rake::Task['photo_gallery:render'].invoke(@folder) }.
      to output(/example\.test\/1\.jpg.*example\.test\/2\.jpg.*example\.test\/10\.jpg/m).to_stdout
    expect(File.read(File.join(@folder, 'metadata.json'))).to eq(@metadata)
  end

  it 'accepts taken_at as the second argument without changing metadata' do
    expect { Rake::Task['photo_gallery:render'].invoke(@folder, 'taken_at') }.
      to output(/example\.test\/10\.jpg.*example\.test\/1\.jpg.*example\.test\/2\.jpg/m).to_stdout
    expect(File.read(File.join(@folder, 'metadata.json'))).to eq(@metadata)
  end

  it 'rejects unsupported options before generating HTML' do
    expect do
      expect { Rake::Task['photo_gallery:render'].invoke(@folder, 'unknown') }.to raise_error(SystemExit)
    end.to output(/filename.*taken_at/).to_stderr
  end
end
