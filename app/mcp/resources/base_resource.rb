module Resources
  class BaseResource
    def definition
      raise NotImplementedError
    end

    def matches?(uri)
      raise NotImplementedError
    end

    def read(uri)
      raise NotImplementedError
    end
  end
end
