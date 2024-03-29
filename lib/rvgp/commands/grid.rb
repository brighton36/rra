# frozen_string_literal: true

module RVGP
  module Commands
    # @!visibility private
    # This class contains the handling of the 'grid' command and task. This
    # code provides the list of grids that are available in the application, and
    # dispatches requests to build these grids.
    class Grid < RVGP::Base::Command
      accepts_options OPTION_ALL, OPTION_LIST

      include RakeTask
      rake_tasks :grid

      # @!visibility private
      def execute!(&block)
        RVGP.app.ensure_build_dir! 'grids'
        super(&block)
      end

      # @!visibility private
      # This class represents a grid, available for building. In addition, the #.all
      # method, returns the list of available targets.
      class Target < RVGP::Base::Command::Target
        # @!visibility private
        def initialize(grid_klass, starting_at, ending_at)
          @starting_at = starting_at
          @ending_at = ending_at
          @grid_klass = grid_klass
          super [year, grid_klass.name.tr('_', '-')].join('-'), grid_klass.status_name(year)
        end

        # @!visibility private
        def description
          I18n.t 'commands.grid.target_description', description: @grid_klass.description, year: year
        end

        # @!visibility private
        def uptodate?
          @grid_klass.uptodate? year
        end

        # @!visibility private
        def execute(_options)
          @grid_klass.new(@starting_at, @ending_at).to_file!
        end

        # @!visibility private
        def self.all
          starting_at = RVGP.app.config.grid_starting_at
          ending_at = RVGP.app.config.grid_ending_at

          starting_at.year.upto(ending_at.year).map do |y|
            RVGP.grids.classes.map do |klass|
              new klass,
                  y == starting_at.year ? starting_at : Date.new(y, 1, 1),
                  y == ending_at.year ? ending_at : Date.new(y, 12, 31)
            end
          end.flatten
        end

        private

        def year
          @starting_at.year
        end
      end
    end
  end
end
