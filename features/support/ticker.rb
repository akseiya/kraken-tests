# frozen_string_literal: true

require 'websocket-eventmachine-client'
require 'pp'
require 'json'

# Runs a limited-time subscription to the ticker channel
# for specified pairs.
class KrakenTickerSubscription
  attr_reader :channels, :timed_out

  def initialize(pairs:, ws_timeout:, max_ticks: nil)
    @timed_out = false
    @timeout = ws_timeout
    @max_ticks = max_ticks
    clear_status(pairs: pairs)
  end

  def clear_status(pairs:)
    @history = []
    @kraken_online = false
    @channels = {}
    @pairs = pairs.split(',').map(&:strip)
    @pairs.each(&method('initialize_channel'))
  end

  def initialize_channel(pair_name)
    puts "Initialising channel for #{pair_name}" if ENV['DEBUG']
    @channels[pair_name] = {
      ticks: [],
      subscription: :unrequested,
      unsubscription: :unrequested
    }
  end

  def run_subscription
    EM.run do
      @ws = WebSocket::EventMachine::Client.connect(uri: 'wss://ws.kraken.com')
      EM.add_timer(@timeout) { time_out }
      @ws.onmessage { |jmsg| receive_message(jmsg) }
      @ws.onclose do |code, reason|
        puts "Disconnected. Code: #{code}; reason: #{reason}" if ENV['DEBUG']
        EM.stop
      end
    end
  end

  def time_out
    @timed_out = true
    @ws.close
  end

  def receive_message(jmsg)
    msg = JSON.parse(jmsg)
    pp msg if ENV['DEBUG']
    @history << msg
    if msg.is_a?(Array)
      consume_public_message(msg)
    else
      consume_general_message(msg)
    end
  end

  def consume_general_message(msg)
    case msg['event']
    when 'systemStatus'
      @kraken_online = msg['status'] == 'online'
      @kraken_online ? subscribe_to_tickers : @ws.close
    when 'subscriptionStatus' then check_subscription_status(msg)
    end
  end

  def subscribe_to_tickers
    pp subscription_message if ENV['DEBUG']
    @ws.send(JSON.dump(subscription_message))
    @pairs.each { |p| @channels[p][:subscription] = :requested }
  end

  def subscription_message(unsub: nil, pair: nil)
    {
      event: unsub.nil? ? 'subscribe' : 'unsubscribe',
      subscription: { name: 'ticker' },
      pair: pair ? [pair] : @pairs
    }
  end

  def check_subscription_status(msg)
    case msg['status']
    when 'subscribed' then @channels[msg['pair']][:subscription] = :confirmed
    when 'unsubscribed'
      @channels[msg['pair']][:unsubscription] = :confirmed
      @ws.close if @channels.all? { |_, c| c[:unsubscription] == :confirmed }
    else raise "Unexpected subscription response\n #{msg.pretty_inspect}"
    end
  end

  def consume_public_message(msg)
    _channel_id, tick, channel_name, pair = msg
    raise "Unexpected message #{channel_name} received" \
      unless channel_name == 'ticker'

    ticks = @channels[pair][:ticks]
    ticks << tick
    return unless @max_ticks && ticks.length >= @max_ticks

    unsub = subscription_message(unsub: true, pair: pair)
    pp unsub if ENV['DEBUG']
    @ws.send(JSON.dump(unsub))
    @channels[pair][:unsubscription] = :requested
  end
end
