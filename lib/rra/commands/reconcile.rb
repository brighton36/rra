require 'tempfile'

class RRA::Commands::Reconcile < RRA::CommandBase
  accepts_options OPTION_ALL, OPTION_LIST, [:vsplit, :v]

  # There's a bug here where we scroll to the top of the file sometimes, on 
  # reload. Not sure what to do about that...
  VIMSCRIPT_HEADER = <<-EOD
    let $LANG='en_US.utf-8'

    function ReloadIfChanged(timer)
      checktime
    endfunction

    function ExecuteTransform()
      let transform_path = expand("%%")
      let output_path = tempname()
      let pager = '/bin/less'
      if len($PAGER) > 0
        pager = $PAGER
      endif

      execute('!%{rra_path} transform --concise ' .
        \\ shellescape(transform_path, 1) . 
        \\ ' 2>' . shellescape(output_path, 1) .
        \\ ' > ' . shellescape(output_path, 1))
      if v:shell_error
				echoerr "The following error(s) occurred during transformation:"
        execute '!' . pager . ' -r ' . shellescape(output_path, 1)
        redraw!
      endif
      silent execute('!rm '. shellescape(output_path,1))
    endfunction
  EOD

  def initialize(*args)
    super *args

    @errors << I18n.t( 'commands.reconcile.errors.unsupported_editor', 
      editor: ENV['EDITOR'].inspect ) unless /vi[m]?\Z/.match ENV['EDITOR']
  end

  def execute!
    Tempfile.create 'reconcile.vim' do |file|
      file.write [ (VIMSCRIPT_HEADER % {rra_path: $0}), 
        targets.collect{|target| target.to_vimscript options[:vsplit]}.join("\ntabnew\n")
      ].join

      file.close

      system [ENV['EDITOR'], '-S', file.path].join(' ')
    end
  end
  
  class Target < RRA::CommandBase::TransformerTarget
    VIMSCRIPT_TEMPLATE = <<-EOD
    edit %{output_file}
    setl autoread
    autocmd VimEnter * let timer=timer_start(1000,'ReloadIfChanged', {'repeat': -1} )
    call feedkeys("lh")
    setl nomodifiable
    %{split}
    edit %{input_file}
    autocmd BufWritePost * silent call ExecuteTransform()
    EOD

    def to_vimscript(is_vsplit)
      # NOTE: I guess we don't need to escape these paths, so long as there arent
      #       any \n's in the path name... I guess
      VIMSCRIPT_TEMPLATE % { output_file: @transformer.output_file, 
        input_file: @transformer.file, split: (is_vsplit) ? 'vsplit' : 'split' }
    end

  end
end
