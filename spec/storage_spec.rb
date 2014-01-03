require 'spec_helper'

describe Faraday::HttpCache::Storage do
  let(:request) do
    { method: :get, request_headers: {}, url: URI.parse('http://foo.bar/') }
  end

  let(:response) { double(serializable_hash: {}) }
  let(:cache) { HashCache.new }
  let(:storage) { Faraday::HttpCache::Storage.new(store: cache) }

  subject { storage }

  describe 'storing responses' do

    shared_examples 'serialization' do
      it 'writes the response json to the underlying cache using a digest as the key' do
        expect(cache).to receive(:write).with(cache_key, serialized)
        subject.write(request, response)
      end
    end

    context 'with default serializer' do
      let(:serialized) { MultiJson.dump(response.serializable_hash) }
      let(:cache_key)  { '503ac9f7180ca1cdec49e8eb73a9cc0b47c27325' }
      it_behaves_like 'serialization'
    end

    context 'with Marshal serializer' do
      let(:storage)    { Faraday::HttpCache::Storage.new store: cache, serializer: Marshal }
      let(:serialized) { Marshal.dump(response.serializable_hash) }
      let(:cache_key) do
        array = request.inject([]) { |memo, (k,v)| memo << [k.to_s, v] }.sort
        Digest::SHA1.hexdigest(Marshal.dump(array))
      end
      it_behaves_like 'serialization'
    end

  end

  describe 'reading responses' do
    it 'returns nil if the response is not cached' do
      expect(subject.read(request)).to be_nil
    end

    it 'decodes a stored response' do
      subject.write(request, response)

      expect(subject.read(request)).to be_a(Faraday::HttpCache::Response)
    end
  end

  describe 'remove age before caching and normalize max-age if non-zero age present' do
    it 'is fresh if the response still has some time to live' do
      headers = {
          'Age' => 6,
          'Cache-Control' => 'public, max-age=40',
          'Date' => (Time.now - 38).httpdate,
          'Expires' => (Time.now + 37).httpdate,
          'Last-Modified' => (Time.now - 300).httpdate
      }
      response = Faraday::HttpCache::Response.new(response_headers: headers)
      expect(response).to be_fresh
      subject.write(request, response)

      cached_response = subject.read(request)
      expect(cached_response.max_age).to eq(34)
      expect(cached_response).not_to be_fresh
    end

    it 'is fresh until cached and that 1 second elapses then the response is no longer fresh' do
      headers = {
          'Date' => (Time.now - 39).httpdate,
          'Expires' => (Time.now + 40).httpdate,
      }
      response = Faraday::HttpCache::Response.new(response_headers: headers)
      expect(response).to be_fresh
      subject.write(request, response)

      sleep(1)
      cached_response = subject.read(request)
      expect(cached_response).not_to be_fresh
    end
  end

end
