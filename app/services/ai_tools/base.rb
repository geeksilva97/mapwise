module AiTools
  class Base
    def self.definition
      raise NotImplementedError
    end

    def self.tool_name
      definition[:name]
    end

    def self.execute(map, params)
      raise NotImplementedError
    end
  end
end
