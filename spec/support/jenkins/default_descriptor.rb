# mocks extended stuff from Jenkins
module Jenkins
  module Model
    class DefaultDescriptor
      def configFile
        self
      end
      def file
        self
      end
      def exists
        false
      end
      def self.java_class
        self
      end
    end
  end
end

# explicitly require stuff from models root folder, due to above mock(s)
require 'models/root_action_descriptor'
