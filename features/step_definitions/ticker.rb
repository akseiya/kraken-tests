# frozen_string_literal: true

require 'websocket-eventmachine-client'
require 'pp'
require 'json'
require_relative '../support/ticker'
require 'pry'

# rubocop:disable Style/GlobalVars

Given('I ran the following Kraken WS subscription:') do |table|
  parms = table.raw.to_h
  $subscription = KrakenTickerSubscription.new(
    pairs: parms['pairs'],
    ws_timeout: parms['timeout'].to_i,
    max_ticks: parms['max ticks'].to_i
  )
  $subscription.run_subscription
end

Then('I received a confirmation for each ticker I subscribed to') do
  $subscription.channels.each do |_, ticker|
    assert ticker[:subscription] == :confirmed
  end
end

Then('I received a confirmation for each ticker I unsubscribed from') do
  return pending('Timed out before receiving all messages') \
    if $subscription.timed_out

  $subscription.channels.each do |_, ticker|
    assert ticker[:unsubscription] == :confirmed
  end
end

Then('I received at least one ticker message for each pair') do
  $subscription.channels.each do |_, ticker|
    assert ticker[:ticks].length.positive?
  end
end

# Won't fail if only one tick arrived within timeout!
Then('Each pair\'s volume increased between ticks') do
  assert $subscription.channels.all? do |_pair, ticker|
    volume = 0
    ticker[:ticks].all? do |tick|
      _t_v, tick_volume24 = tick['v'].map(&:to_i)
      increased = tick_volume24 > volume
      volume = tick_volume24
      increased
    end
  end
end

# rubocop:enable Style/GlobalVars
