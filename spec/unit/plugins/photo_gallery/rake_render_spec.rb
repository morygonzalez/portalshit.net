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

  it 'accepts a JSON file path and preserves the default filename ordering' do
    json_path = File.join(@folder, '夕暮れ のアルバム.json')
    File.write(json_path, @metadata)
    expect { Rake::Task['photo_gallery:render'].invoke(json_path) }.
      to output(/example\.test\/1\.jpg.*example\.test\/2\.jpg.*example\.test\/10\.jpg/m).to_stdout
    expect(File.read(json_path)).to eq(@metadata)
  end

  it 'accepts a JSON file path with capture-time ordering without changing metadata' do
    json_path = File.join(@folder, '夕暮れ のアルバム.json')
    File.write(json_path, @metadata)
    expect { Rake::Task['photo_gallery:render'].invoke(json_path, 'taken_at') }.
      to output(/example\.test\/10\.jpg.*example\.test\/1\.jpg.*example\.test\/2\.jpg/m).to_stdout
    expect(File.read(json_path)).to eq(@metadata)
  end

  it 'reports a missing input argument' do
    expect do
      expect { Rake::Task['photo_gallery:render'].invoke }.to raise_error(SystemExit)
    end.to output(/フォルダまたはJSONファイルのパス/).to_stderr
  end

  it 'reports a missing JSON file' do
    json_path = File.join(@folder, 'missing.json')
    expect do
      expect { Rake::Task['photo_gallery:render'].invoke(json_path) }.to raise_error(SystemExit)
    end.to output(/missing\.json.*見つかりません/).to_stderr
  end

  it 'reports missing metadata inside an existing directory' do
    empty_folder = File.join(@folder, 'empty')
    Dir.mkdir(empty_folder)
    expect do
      expect { Rake::Task['photo_gallery:render'].invoke(empty_folder) }.to raise_error(SystemExit)
    end.to output(%r{empty/metadata\.json.*見つかりません}).to_stderr
  end

  it 'reports malformed JSON without generating HTML' do
    json_path = File.join(@folder, 'broken.json')
    File.write(json_path, '{broken')
    expect do
      expect { Rake::Task['photo_gallery:render'].invoke(json_path) }.to raise_error(SystemExit)
    end.to output(/正しいJSONではありません/).to_stderr
  end

  it 'rejects JSON that is not an array of photo objects' do
    [nil, {}, [nil], ['photo']].each do |value|
      json_path = File.join(@folder, 'invalid.json')
      File.write(json_path, value.to_json)
      Rake::Task['photo_gallery:render'].reenable
      expect do
        expect { Rake::Task['photo_gallery:render'].invoke(json_path) }.to raise_error(SystemExit)
      end.to output(/写真オブジェクトの配列/).to_stderr
    end
  end

  it 'rejects unsupported options before generating HTML' do
    expect do
      expect { Rake::Task['photo_gallery:render'].invoke(@folder, 'unknown') }.to raise_error(SystemExit)
    end.to output(/filename.*taken_at/).to_stderr
  end
end
