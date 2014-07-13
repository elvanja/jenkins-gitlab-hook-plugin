module GitlabWebHook
  module FlatKeysHash
    FLATTENED_KEYS_DELIMITER = "."

    def to_flat_keys
      flatten_keys(self)
    end

    private

    def flatten_keys(data)
      return data unless data.is_a?(Enumerable)

      prepare_for_flattening(data).inject({}) do |flattened, (key, value)|
        flattened.merge!(expand_keys(key, value))
      end
    end

    def prepare_for_flattening(data)
      return data unless data.is_a?(Array)

      Hash[data.map.with_index { |value, index| [index.to_s, value] }]
    end

    def expand_keys(key, value)
      flattened = flatten_keys(value)
      (value.is_a?(Enumerable) ? build_expanded(flattened, key) : {}).tap do |expanded|
        expanded["#{key}"] = value.is_a?(Enumerable) ? value : flattened
      end
    end

    def build_expanded(flattened, key)
      flattened.inject({}) do |expanded, (nested_key, nested_value)|
        expanded["#{key}#{FLATTENED_KEYS_DELIMITER}#{nested_key}"] = nested_value
        expanded
      end
    end
  end
end