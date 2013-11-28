module DRbQueue
  class Store
    class Redis < Store
      def initialize(options = {})
        @redis = options.fetch(:redis, lambda { ::Redis.current }).call
      end

      def persist(work)
        redis.rpush(persistence_key, work.serialize)
      end

      def each_persisted_work
        return enum_for(:each_persisted_work) unless block_given?

        while serialized_work = redis.lpop(persistence_key)
          yield(serialized_work)
        end
      end

      private
      attr_reader :redis

      def persistence_key
        'persisted:work'
      end
    end
  end
end
