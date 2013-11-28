module DRbQueue
  class Store
    NotImplementedError = Class.new(StandardError)

    def persist(work)
      raise NotImplementedError, "Must implement #persist"
    end

    def each_persisted_work
      raise NotImplementedError, "Must implement #each_persisted_work"
    end
  end
end
