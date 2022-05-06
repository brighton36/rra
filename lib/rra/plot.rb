class RRA::Plot
  attr_reader :glob, :grid_hacks, :google_options, :sort_by_rows, 
    :truncate_rows, :switch_rows_columns

  REQUIRED_FIELDS = [:glob, :title]

  def initialize(yaml)
    raise StandardError, "Missing one or more required fields in %s: %s" % [
      yaml.path, REQUIRED_FIELDS] unless REQUIRED_FIELDS.all?{|f| yaml.has_key? f}

    @glob = yaml[:glob] if yaml.has_key? :glob

    unless /%\{year\}/.match glob
      raise StandardError, 
        "Plot file %s is missing a required 'year' parameter in glob" 
    end

    reports_corpus = Dir[RRA.app.config.build_path('reports/*')]

    @variants ||= (self.class.glob_variants(glob, reports_corpus) + 
      self.class.glob_variants(glob, reports_corpus, year: 'all'))

    @title = yaml[:title] if yaml.has_key? :title
    @grid_hacks = (yaml.has_key? :grid_hacks) ? yaml[:grid_hacks] : {}
    @google_options = yaml[:google] if yaml.has_key? :google
  end

  def variants(name = nil)
    name ? @variants.find{|v| v[:name] == name} : @variants
  end

  def variant_files(variant_name)
    variants(variant_name)[:files]
  end

  def title(variant_name)
    @title % variants(variant_name)[:pairs]
  end

  def grid(variant_name)
    @grid ||= {}
    @grid[variant_name] ||= begin
      # TODO: All of this probably needs to be wrapped into the ReportView.

      gopts, rvopts = {}, {}

      # Report Viewer Options:
      rvopts[:series_label] = @grid_hacks[:keystone] if (
        @grid_hacks.has_key? :keystone )

      rvopts[:store_cell] = @grid_hacks.has_key?(:store_cell) ? 
        lambda{|cell| @grid_hacks[:store_cell].call cell: cell } :
        lambda{|cell| (cell) ? cell.to_f : nil}

      rvopts[:select_rows] = lambda{|name, data| 
        @grid_hacks[:select_rows].call name: name, data: data
      } if @grid_hacks.has_key? :select_rows

      # Grid Options
      gopts[:sort_by_rows] = lambda{|row| 
        @grid_hacks[:sort_rows_by].call row: row
      } if @grid_hacks.has_key? :sort_rows_by

      gopts[:sort_by_cols] = lambda{|column| 
        @grid_hacks[:sort_columns_by].call column: column
      } if @grid_hacks.has_key? :sort_columns_by

      gopts[:truncate_rows] = @grid_hacks[:truncate_rows].to_i if (
        @grid_hacks.has_key? :truncate_rows )

      gopts[:switch_rows_columns] = @grid_hacks[:switch_rows_columns] if (
        @grid_hacks.has_key? :switch_rows_columns )
      
      gopts[:truncate_cols] = @grid_hacks[:truncate_columns].to_i if (
        @grid_hacks.has_key? :truncate_columns )

      gopts[:convert_null_to_zero] = @grid_hacks[:convert_null_to_zero] if (
        @grid_hacks.has_key? :convert_null_to_zero )


      RRA::ReportViewer.new(variant_files(variant_name), rvopts).to_grid(gopts)
    end
  end

  def column_titles(variant_name)
    grid(variant_name)[0]
  end

  def series(variant_name)
    grid(variant_name)[1..]
  end

  # This returns what plot variants are possible, given the glob, against the 
  # provided files.
  # If pair_values contains key: value combinations, then, any of the returned
  # variants will be sorted under the key:value provided . (Its really just meant
  # for {year: 'all'}  atm..)
  def self.glob_variants(glob, corpus, pair_values = {} )
    variant_names = glob.scan(/\%\{([^ \}]+)/).flatten.collect(&:to_sym)

    variant_matcher = Regexp.new( glob % Hash[ variant_names.collect{ |key| 
        [key, '(.+)' ] } ] )

    corpus.inject(Array.new) { |ret, file|
      matches = variant_matcher.match File.basename(file)

      if matches
        pairs = Hash[variant_names.collect.with_index{|key, i| 
          [key, pair_values.has_key?(key.to_sym) ? pair_values[key] : matches[i+1]]
        }]

        pair_i = ret.find_index{|variant| variant[:pairs] == pairs}
        if pair_i
          ret[pair_i][:files] << file
        else
          ret << {name: File.basename(glob % pairs, '.*'), pairs: pairs, 
            files: [file]}
        end
      end

      ret
    }.compact
  end

  def self.all(plot_directory_path)
    Dir.glob("%s/*.yml" % plot_directory_path).collect{|path|
      self.new RRA::Yaml.new(path, RRA.app.config.project_path)
    }
  end
end
