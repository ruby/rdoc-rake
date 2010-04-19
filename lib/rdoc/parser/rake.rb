require 'rdoc/parser/ruby'

##
# Maps task builders like Hoe or RDoc::Task to an RDoc::Include

class RDoc::RakeBuilder < RDoc::Include
end

##
# Maps a Rake namespace to an RDoc::NormalModule

class RDoc::RakeNamespace < RDoc::NormalModule
end

##
# Maps a Rake::Task to an RDoc::AnyMethod

class RDoc::RakeTask < RDoc::AnyMethod

  attr_accessor :dependencies

  def initialize(*args)
    super
    @dependencies = []
  end

end

##
# An RDoc parser for Rakefiles.

class RDoc::Parser::Rake < RDoc::Parser

  VERSION = '1.0'

  include RDoc::RubyToken
  include RDoc::TokenStream
  include RDoc::Parser::RubyTools

  parse_files_matching(/Rakefile(\.rb)?$/i)
  parse_files_matching(/\.rake$/)

  def initialize(top_level, file_name, content, options, stats)
    super

    @size = 0
    @token_listeners = nil
    @scanner = RDoc::RubyLex.new content, @options
    @scanner.exception_on_syntax_error = false
    @rake_tasks = @top_level.add_module RDoc::RakeNamespace, 'Rake Tasks'

    reset
  end

  ##
  # Consumes an Array

  def consume_array
    tokens = get_tk_until TkRBRACK
    tokens << get_tk
    tokens
  end

  ##
  # Consumes the body of a task

  def consume_body
    seen_nest = false
    nest = 0

    body = []

    while tk = get_tk do
      body << tk

      case tk
      when TkDO, TkCLASS, TkMODULE, TkDEF, TkBEGIN, TkIF, TkUNLESS, TkCASE,
           TkWHILE, TkUNTIL, TkFOR then
        nest += 1
        seen_nest = true
      when TkEND then
        nest -= 1
      when TkNL then
        break unless seen_nest
      end

      break if nest == 0 and seen_nest
    end

    body
  end

  ##
  # Consumes arguments to a task

  def consume_task_arguments
    skip_tkspace false

    tk = get_tk

    case tk
    when TkNL, TkDO then
      unget_tk tk
    when TkASSIGN then
      get_tk # finish assoc, lexer bug
      skip_tkspace

      case tk = get_tk
      when TkLBRACK then
        tokens = consume_array
        tokens = tokens.select do |token| TkSYMBOL === token end
        tokens = tokens.map do |token| token.to_sym end
        @task.dependencies.push(*tokens)
      when TkSYMBOL then # ok
        @task.dependencies << tk.to_sym
      else
        puts :task_arg => tk
      end
    end
  end

  ##
  # Parses a Rake description
  #
  #   desc "My cool task"

  def parse_description
    skip_tkspace

    tk = get_tk

    @desc = tk.text[1..-2]
  end

  ##
  # Parses a Rake namespace
  #
  #   namespace "doc"

  def parse_namespace
    skip_tkspace

    tk = get_tk

    namespace = @container.add_module RDoc::RakeNamespace, tk.text[1..-1]

    skip_tkspace

    old_namespace = @container

    begin
      @nest += 1
      @container = namespace

      parse_rakefile
    ensure
      @container = old_namespace
      @nest -= 1
    end
  end

  ##
  # Parses a Rake task
  #
  #   task "my_cool_task"

  def parse_task(tk)
    collect_tokens
    add_token tk

    token_listener self do
      skip_tkspace false

      tk = get_tk
      name = tk.text

      @task = @container.find_instance_method_named name

      unless @task then
        @task = RDoc::RakeTask.new tokens_to_s, name
        @container.add_method @task
        @stats.add_method @task
      end

      @task.comment += use_desc

      consume_task_arguments
    end

    @task.collect_tokens
    @task.add_tokens token_stream

    token_listener @task do
      consume_body
    end

    @task
  end

  ##
  # Parses a Rake task builder
  #
  #   Hoe.new 'my_cool_project' do # ...

  def parse_task_builder(tk)
    name = tk.name

    if 'ENV' == name then
      get_tk_until TkNL
      return
    end

    get_tk_until TkDO, TkNL

    tk = get_tk

    case tk
    when TkDO then
      unget_tk tk
      consume_body
    end

    builder = RDoc::RakeBuilder.new name, ''

    @container.add_include builder
  end

  ##
  # Parses a Rakefile

  def parse_rakefile
    current_nest = @nest

    while tk = get_tk do
      case tk
      when TkCONSTANT then
        parse_task_builder tk
      when TkDO then
        @nest += 1
      when TkEND then
        @nest -= 1
        break if current_nest > 0 and @nest <= current_nest
      when TkIDENTIFIER then
        case tk.name
        when 'desc' then
          parse_description
        when 'task' then
          parse_task(tk)
        when 'namespace' then
          parse_namespace
        when 'require' then
          parse_require
        #else
        #  p :ident => tk
        end
      when TkNL, TkSPACE then # ignore
      #else
      #  p :unhandled => tk
      end
    end
  end

  ##
  # Adds a new RDoc::Require to the container

  def parse_require
    skip_tkspace false

    tk = get_tk

    name = tk.text if TkSTRING === tk

    if name then
      @container.add_require RDoc::Require.new(name, '')
    else
      unget_tk tk
    end
  end

  ##
  # Performs the work of parsing a rakefile

  def scan
    reset

    @container = @rake_tasks

    @stats.add_module @container

    catch :eof do
      catch :enddoc do
        parse_rakefile
      end
    end

    @top_level
  end

  ##
  # Uses the last description encountered

  def use_desc
    desc = @desc
    @desc = nil
    desc || ''
  end

end

