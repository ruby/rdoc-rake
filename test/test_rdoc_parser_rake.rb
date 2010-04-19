require 'stringio'
require 'tempfile'
require 'rubygems'
require 'minitest/autorun'

require 'rdoc'
require 'rdoc/options'
require 'rdoc/parser/rake'

class TestRDocParserRake < MiniTest::Unit::TestCase

  def setup
    @tempfile = Tempfile.new self.class.name
    @filename = @tempfile.path

    util_top_level

    @options = RDoc::Options.new
    @options.quiet = true
    @stats = RDoc::Stats.new 0
  end

  def teardown
    @tempfile.close
  end

  def test_parse_tasks
    rakefile = <<-RAKE
desc "my cool task"
task :default do
  puts "you ran my cool task!"
end
    RAKE

    util_parser rakefile

    @parser.scan

    util_tasks
    assert_equal 1, @tasks.length
    task = @tasks.first

    assert_equal ':default', task.name
    assert_equal 'my cool task', task.comment
    assert_equal 'task :default', task.text
  end

  def test_parse_tasks_dependency
    rakefile = <<-RAKE
desc "my cool task"
task :default => :test do
  puts "you ran my cool task!"
end
    RAKE

    util_parser rakefile

    @parser.scan

    util_tasks
    assert_equal 1, @tasks.length
    task = @tasks.first

    assert_equal ':default', task.name
    assert_equal 'my cool task', task.comment

    assert_equal 'task :default', task.text
    assert_equal [:test], task.dependencies

    expected = [
      tk(:identifier, 2,  0, 'task', 'task'),
      tk(:space,      2,  4, nil,    ' '),
      tk(:symbol,     2,  5, nil,    ':default'),
      tk(:space,      2, 13, nil,    ' '),
      tk(:assign,     2, 14, nil,    '='),
      tk(:gt,         2, 15, nil,    '>'),
      tk(:space,      2, 16, nil,    ' '),
      tk(:symbol,     2, 17, nil,    ':test'),
      tk(:space,      2, 22, nil,    ' '),
      tk(:do,         2, 23, 'do',   'do'),
      tk(:nl,         2, 25, nil,    "\n"),
      tk(:space,      3,  0, nil,    '  '),
      tk(:identifier, 3,  2, 'puts', 'puts'),
      tk(:space,      3,  6, nil,    ' '),
      tk(:string,     3,  7, nil,    '"you ran my cool task!"'),
      tk(:nl,         3, 30, nil,    "\n"),
      tk(:end,        4,  0, 'end',  'end'),
    ]

    assert_equal expected, task.token_stream
  end

  def test_parse_tasks_dependency_only
    rakefile = <<-RAKE
desc "my cool task"
task :default => :test

task :test => :build
    RAKE

    util_parser rakefile

    @parser.scan

    util_tasks
    assert_equal 2, @tasks.length
    task = @tasks.first

    assert_equal ':default', task.name
    assert_equal 'my cool task', task.comment
    assert_equal 'task :default', task.text
    assert_equal [:test], task.dependencies

    expected = [
      tk(:identifier, 2,  0, 'task', 'task'),
      tk(:space,      2,  4, nil,    ' '),
      tk(:symbol,     2,  5, nil,    ':default'),
      tk(:space,      2, 13, nil,    ' '),
      tk(:assign,     2, 14, nil,    '='), # lexer bug
      tk(:gt,         2, 15, nil,    '>'),
      tk(:space,      2, 16, nil,    ' '),
      tk(:symbol,     2, 17, nil,    ':test'),
      tk(:nl,         2, 22, nil,    "\n"),
    ]

    assert_equal expected, task.token_stream
  end

  def test_parse_tasks_dependencies
    rakefile = <<-RAKE
desc "my cool task"
task :default => [:build, :test]
    RAKE

    util_parser rakefile

    @parser.scan

    util_tasks
    assert_equal 1, @tasks.length
    task = @tasks.first

    assert_equal ':default', task.name
    assert_equal 'my cool task', task.comment
    assert_equal 'task :default', task.text
    assert_equal [:build, :test], task.dependencies
  end

  def test_parse_tasks_hoe
    rakefile = <<-RAKE
Hoe.spec 'my_cool_project' do
  developer 'Cool Guy', 'cool_guy@example.com'
end

desc "my cool task"
task :default do
  puts "you ran my cool task!"
end
    RAKE

    util_parser rakefile

    @parser.scan

    util_tasks
    assert_equal 1, @tasks.length
    task = @tasks.first

    assert_equal ':default', task.name

    assert_equal 1, @rake_tasks.includes.length
    hoe = @rake_tasks.includes.first

    assert_equal 'Hoe', hoe.name
  end

  def test_parse_tasks_require
    rakefile = <<-RAKE
require 'blah'
    RAKE

    util_parser rakefile

    @parser.scan

    assert_equal 1, @top_level.requires.length
    require = @top_level.requires.first

    assert_equal 'blah', require.name
  end

  def test_parse_tasks_split
    rakefile = <<-RAKE
desc "my cool task"
task :default => :build

task :default => :test
    RAKE

    util_parser rakefile

    @parser.scan

    util_tasks
    assert_equal 1, @tasks.length
    task = @tasks.first

    assert_equal ':default', task.name
    assert_equal 'my cool task', task.comment
    assert_equal 'task :default', task.text
    assert_equal [:build, :test], task.dependencies
  end

  def test_parse_tasks_namespage
    rakefile = <<-RAKE
desc "my cool task"
task :default do
  puts "you ran my cool task!"
end

namespace :cool do
  task :awesome do
  end
end

desc "this is another cool task"
task :other
    RAKE

    util_parser rakefile

    @parser.scan

    #pp @top_level
    util_tasks

    assert_equal 2, @tasks.length
    task = @tasks.first

    assert_equal ':default', @tasks.first.name
    assert_equal ':other',   @tasks.last.name
  end

  def tk(klass, line, char, name, text) # HACK dup
    klass = RDoc::RubyToken.const_get "Tk#{klass.to_s.upcase}"

    token = if klass.instance_method(:initialize).arity == 3 then
              raise ArgumentError, "name not used for #{klass}" unless name.nil?
              klass.new nil, line, char
            else
              klass.new nil, line, char, name
            end

    token.set_text text

    token
  end

  def util_parser(content)
    @parser = RDoc::Parser::Rake.new @top_level, @filename, content, @options,
                                     @stats
  end

  def util_top_level
    RDoc::TopLevel.reset
    @top_level = RDoc::TopLevel.new @filename
  end

  def util_tasks
    @rake_tasks = @top_level.modules.first

    @tasks = @rake_tasks.method_list
  end

end

