require 'test_helper'

class TurboStreamer::OptionsTest < ActiveSupport::TestCase

  test 'the suite runs on the encoder TSENCODER asked for' do
    skip 'TSENCODER is not set' unless ENV['TSENCODER']

    assert_equal ENV['TSENCODER'].to_sym,
      TurboStreamer.encoder_symbol_for(:json, TurboStreamer.default_encoder_for(:json))
  end

  test 'setting default options' do
    TurboStreamer.set_default_encoder(:json, :oj)
    TurboStreamer.set_default_encoder_options(:oj, {buffer_size: 2_048})
    ::Oj::StreamWriter.expects(:new).with {|a, b| b == {mode: :json, buffer_size: 2_048} }
    TurboStreamer.new
  end
  
  
  test 'setting default encoder and options' do
    TurboStreamer.set_default_encoder(:json, :oj, {buffer_size: 1_024})
    ::Oj::StreamWriter.expects(:new).with {|a, b| b == {mode: :json, buffer_size: 1_024} }
    TurboStreamer.new
  end

end

    