require "spec_helper"
require_relative "../../support/helpers/silence_stdout"

module RubyEventStore
  module ActiveRecord
    RSpec.describe MigrationGenerator do
      around { |example| SilenceStdout.silence_stdout { example.run } }

      before { allow(Time).to receive(:now).and_return(Time.new(2022, 11, 30, 21, 37, 00)) }

      context "with default migration path" do
        around do |example|
          begin
            @dir = FileUtils.mkdir_p("./db/migrate").first
            example.call
          ensure
            FileUtils.rm_rf(@dir)
            FileUtils.rmdir("./db")
          end
        end

        it "is created" do
          RubyEventStore::ActiveRecord::MigrationGenerator.new.call("binary")
          File.read("#{@dir}/20221130213700_create_event_store_events.rb")
        end
      end

      context "with custom directory" do
        around do |example|
          begin
            @dir = Dir.mktmpdir(nil, "./")
            example.call
          ensure
            FileUtils.rm_r(@dir)
          end
        end

        subject do
          RubyEventStore::ActiveRecord::MigrationGenerator.new.call("binary", migration_path: "#{@dir}/")
          File.read("#{@dir}/20221130213700_create_event_store_events.rb")
        end

        it "uses particular migration version" do
          expect(subject).to match(/ActiveRecord::Migration\[4\.2\]$/)
        end

        context "returns path to migration file" do
          subject { RubyEventStore::ActiveRecord::MigrationGenerator.new.call("binary", migration_path: "#{@dir}/") }
          it { is_expected.to match("#{@dir}/20221130213700_create_event_store_events.rb") }
        end

        context "when data_type option is specified" do
          subject do
            RubyEventStore::ActiveRecord::MigrationGenerator.new.call(data_type, migration_path: "#{@dir}/")
            File.read("#{@dir}/20221130213700_create_event_store_events.rb")
          end

          context "with a binary datatype" do
            let(:data_type) { "binary" }
            it { is_expected.to match(/t.binary\s+:metadata/) }
            it { is_expected.to match(/t.binary\s+:data/) }
          end

          context "with a json datatype" do
            let(:data_type) { "json" }
            it { is_expected.to match(/t.json\s+:metadata/) }
            it { is_expected.to match(/t.json\s+:data/) }
          end

          context "with a jsonb datatype" do
            let(:data_type) { "jsonb" }
            it { is_expected.to match(/t.jsonb\s+:metadata/) }
            it { is_expected.to match(/t.jsonb\s+:data/) }
          end

          context "with an invalid datatype" do
            let(:data_type) { "invalid" }

            it "raises an error" do
              expect {
                RubyEventStore::ActiveRecord::MigrationGenerator.new.call("invalid", migration_path: "#{@dir}/")
              }.to raise_error(
                ArgumentError,
                "Invalid value for --data-type option. Supported for options are: binary, json, jsonb."
              )
            end
          end
        end
      end
    end
  end
end