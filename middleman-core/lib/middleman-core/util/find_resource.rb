module Middleman
  module Util
    class FindResource
      def self.call(app, parent_resource, path)
        new(app, parent_resource, path).call
      end

      def initialize(app, parent_resource, path)
        @app = app
        @parent_resource = parent_resource
        @path = Pathname(path)
      end

      def call
        find_by_path || find_by_destination_path || find_by_full_path
      end

      private

      attr_reader :app, :parent_resource, :path

      def find_by_path
        find Pathname(parent_resource.path).dirname do |grounded_path|
          app.sitemap.find_resource_by_path(grounded_path.to_s)
        end
      end

      def find_by_destination_path
        find Pathname(parent_resource.destination_path).dirname do |grounded_path|
          app.sitemap.find_resource_by_destination_path(grounded_path.to_s)
        end
      end

      def find_by_full_path
        find Pathname(parent_resource.source_file).dirname do |grounded_path|
          app.sitemap.find_resource_by_full_path(grounded_path.to_s)
        end
      end

      def find(parent_directory)
        yield grounded_path_within(parent_directory)
      end

      def grounded_path_within(parent_directory)
        if path.relative?
          parent_directory.join(path)
        else
          path
        end
      end
    end
  end
end
