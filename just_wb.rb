# frozen_string_literal: true

require 'websocket-eventmachine-client'
require 'pp'
require 'json'

# stopper = nil

def json_subscribe
  '{  "event": "subscribe",
      "pair": [
        "XBT/USD",
        "XBT/EUR"
      ],
      "subscription": {
        "name": "ticker"
    }}'
end

counter = 0

EM.run do
  ws = WebSocket::EventMachine::Client.connect \
    uri: 'wss://ws.kraken.com'

  EM.add_timer(30) do
    ws.close
  end

  ws.onopen do
    puts 'Connected'
    ws.send json_subscribe
  end

  ws.onmessage do |jmsg, _type|
    msg = JSON.parse(jmsg)
    pp msg unless (msg['event'] == 'heartbeat' rescue FALSE)
    counter += 1
    ws.close if counter > 10
  end

  ws.onclose do |code, _reason|
    puts "Disconnected with status code: #{code}"
    EM.stop
  end
end

puts "#{counter} messages received"
