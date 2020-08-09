Feature: Happy path for pair tickers

  As a crypto trader,
  I want to receive ticker messages for pairs I subscribe to
  So that I know what's up on the market

Background: We follow all the rules

  * I ran the following Kraken WS subscription:
    | pairs     | XBT/USD, XBT/EUR |
    | timeout   | 60               |
    | max ticks | 3                |

Scenario: The happy path

  * I received a confirmation for each ticker I subscribed to
  * I received at least one ticker message for each pair
  * Each pair's volume increased between ticks
  * I received a confirmation for each ticker I unsubscribed from
