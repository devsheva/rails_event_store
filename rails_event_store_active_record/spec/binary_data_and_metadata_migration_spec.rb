require 'spec_helper'
require 'pathname'
require 'childprocess'
require 'active_record'
require 'logger'
require 'ruby_event_store'
require 'ruby_event_store/spec/event_repository_lint'

RSpec.describe "binary_data_and_metadata_migration" do
  include SchemaHelper

  specify do
    begin
      establish_database_connection
      fill_data_using_older_gem
      before =
        ActiveRecord::Base
          .connection
          .columns('event_store_events')
          .find { |c| c.name == 'data' }
          .type
      expect(before).to eq(:text)

      run_migration('binary_data_and_metadata')

      after =
        ActiveRecord::Base
          .connection
          .columns('event_store_events')
          .find { |c| c.name == 'data' }
          .type
      expect(after).to eq(:binary)
    ensure
      drop_database
    end
  end

  private

  def fill_data_using_older_gem
    pathname = Pathname.new(__FILE__).dirname
    cwd = pathname.join("before_binary_data_and_metadata")
    FileUtils.rm(cwd.join("Gemfile.lock")) if File.exists?(cwd.join("Gemfile.lock"))
    process = ChildProcess.build("bundle", "exec", "ruby", "fill_data.rb")
    process.environment['BUNDLE_GEMFILE'] = cwd.join('Gemfile')
    process.environment['DATABASE_URL']   = ENV['DATABASE_URL']
    process.environment['RAILS_VERSION']  = ENV['RAILS_VERSION']
    process.cwd = cwd
    process.io.stdout = $stdout
    process.io.stderr = $stderr
    process.start
    begin
      process.poll_for_exit(10)
    rescue ChildProcess::TimeoutError
      process.stop
    end
    expect(process.exit_code).to eq(0)
  end
end
