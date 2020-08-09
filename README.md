# Kraken tests
Checking the exchange's API

## Prerequisites

1. Have a Unix machine with Ruby 2.7.1 and Bundler.
1. Run `bundle check || bundle update`

## Running the tests
1. Run `cucumber`
2. To see the webSockets messsages being exchanged etc, run `DEBUG=yes cucumber`

## Exercise

I know how to test REST APIs.

Not so much about webSockets solutions.

Let's have a test of a webSockets API with Cucumber.

## Process

I never used webSockets before, so I went with whatever tools popped first in my DuckDuckGo searches.

I got [Websockets Client for Ruby from Bernard Potocki](https://github.com/imanel/websocket-eventmachine-client) as the base interface.

I have no idea how to use that client in a manner that would allow me to use [the "monkeypatching" described by Michael Wynholds](https://blog.carbonfive.com/raking-and-testing-with-eventmachine/).

I can still trivially leverage Cuke's expressive powers to describe the checks I perform on the communications between my test client and Kraken, by having the whole exchange as a `When`, storing all received messages in memory and performing all the `Then` checks on the memory recording.

## Result

The scope I finished this evening is:
- subscribe to ticker channels for 2 pairs
- accumulate no more than `max ticks` per pair, then unsubscribe
- once all pairs were unsubscribed from, close the webSockets connection
- examine record of the webSockets messages received from Kraken
  - online status - raise if not online since no other action will succeed
  - confirmation of subscribing and unsubscribing from the ticker channels
    - if `max ticks` are high, `timeout` is low and there is little trading on the pair, the connection can expire before confirmation of unsubscription was received
      - when it happens, the last step of the Gherkin will be pending
      - this is an actual test of the test, proving that it can do more than just pass if we parameterise it just right
      - to make it always pass, it would suffice to change how closing of connection on timeout works:
        - send `unsubscribe` messages for all pairs
        - set a new timeout
        - let the default logic work (close connection when all unsubscription messages arrived)
        - raise on new timeout
  - presence of at least the one initial tick for each pair
  - if more than one tick was received for pair, I check that the volume over last 24h was always increasing