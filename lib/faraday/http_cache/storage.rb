require 'digest/sha1'

module Faraday
  class HttpCache < Faraday::Middleware
    # Internal: A Wrapper around a ActiveSupport::CacheStore to store responses.
    #
    # Examples
    #   # Creates a new Storage using a MemCached backend from ActiveSupport.
    #   Faraday::HttpCache::Storage.new(:mem_cache_store)
    #
    #   # Reuse some other instance of a ActiveSupport::CacheStore object.
    #   Faraday::HttpCache::Storage.new(Rails.cache)
    #
    #   # Creates a new Storage using Marshal for serialization.
    #   Faraday::HttpCache::Storage.new(:memory_store, serializer: Marshal)
    class Storage
      attr_reader :cache

      # Internal: Initialize a new Storage object with a cache backend.
      #
      # options      - Storage options (default: {}).
      #                :store         - A cache object, should respond to #read
      #                                 and #write.
      #                :serializer    - A serializer class for the body.
      #                                 Should respond to #dump and #load.
      def initialize(options = {})
        @cache = options[:store]
        @serializer = options[:serializer] || MultiJson
      end

      # Internal: Writes a response with a key based on the given request.
      #
      # request - The Hash containing the request information.
      #           :method          - The HTTP Method used for the request.
      #           :url             - The requested URL.
      #           :request_headers - The custom headers for the request.
      # response - The Faraday::HttpCache::Response instance to be stored.
      def write(request, response)
        key = cache_key_for(request)
        value = @serializer.dump(response.serializable_hash)
        cache.write(key, value)
      end

      # Internal: Reads a key based on the given request from the underlying cache.
      #
      # request - The Hash containing the request information.
      #           :method          - The HTTP Method used for the request.
      #           :url             - The requested URL.
      #           :request_headers - The custom headers for the request.
      # klass - The Class to be instantiated with the recovered informations.
      def read(request, klass = Faraday::HttpCache::Response)
        key = cache_key_for(request)
        value = cache.read(key)

        if value
          payload = @serializer.load(value).inject({}) do |memo, (k,v)|
            memo.update(k.to_sym => v)
          end
          klass.new(payload)
        end
      end

      private

      # Internal: Generates a String key for a given request object.
      # The request object is folded into a sorted Array (since we can't count
      # on hashes order on Ruby 1.8), encoded as JSON and digested as a `SHA1`
      # string.
      #
      # Returns the encoded String.
      def cache_key_for(request)
        array = request.inject([]) { |memo, (k,v)| memo << [k.to_s, v] }.sort
        Digest::SHA1.hexdigest(@serializer.dump(array))
      end
    end
  end
end
