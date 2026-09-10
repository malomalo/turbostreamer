require 'test_helper'

class TurboStreamer::OptionsTest < ActiveSupport::TestCase

  test 'the suite runs on the encoder TSENCODER asked for' do
    skip 'TSENCODER is not set' unless ENV['TSENCODER']

    assert_equal ENV['TSENCODER'].to_sym,
      TurboStreamer.encoder_symbol_for(:json, TurboStreamer.default_encoder_for(:json))
  end

  # Building a builder used to read `@@encoder_options[encoder]`, and that Hash
  # assigns {} to a missing key as it reads it -- so any encoder merely
  # rendered with reported having options configured for it afterwards.
  # test_helper restores the Hash, so deleting the key here is contained.
  test 'rendering with an encoder does not make it look configured' do
    encoder = TurboStreamer.encoder_symbol_for(:json, TurboStreamer.default_encoder_for(:json))
    TurboStreamer.class_variable_get(:@@encoder_options).delete(encoder)
    refute TurboStreamer.has_default_encoder_options?(encoder)

    TurboStreamer.encode { |json| json.object! { json.a 1 } }

    refute TurboStreamer.has_default_encoder_options?(encoder),
      'rendering created an options entry for the encoder'
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

    