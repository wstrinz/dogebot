
require 'slack-ruby-bot'

require 'block_io'
BlockIo.set_options :api_key => ENV['BLOCK_IO_KEY'], :pin => ENV['BLOCK_IO_PIN'], :version => 2

class Bank
  def self.instance
    @bank ||= self.new
  end

  def initialize
    @ledger = JSON.parse(open('ledger.json').read)
  end

  def ledger
    @ledger
  end


  def ledger_value
    @ledger.values.sum
  end

  def remote_vault_value
    fetch_vault
  end

  def vault
    remote_vault_value - ledger_value
  end

  def fetch_vault
    BlockIo.get_balance.fetch("data").fetch("available_balance").to_f
  end

  def set(user, amount)
    @ledger[user] = amount
    save_ledger
    amount
  end

  def save_ledger
    open('ledger.json','w'){|f| f.write(ledger.to_json)}
  end

  def give_if_available(user, amount)
    if amount < vault
      user_curr = ledger[user] || 0.0
      set(user, user_curr + amount.to_f)
    else
      false
    end
  end

  def transfer(from, to, amount)
    from_holdings = ledger[from] || 0.0
    to_holdings = ledger[to] || 0.0
    amount = amount.to_f

    if amount <= from_holdings
      set(from, from_holdings - amount)
      set(to, to_holdings + amount)
    else
      false
    end
  end

  def signup(user, starting_amt = 0.1)
    current = ledger[user]
    if current
      "You already have #{current} Doge Coins!"
    else
      gave = give_if_available(user, starting_amt)
      if gave
        <<-MSG
You're signed up! You have #{starting_amt} Doge Coins.
        MSG
      else
        <<-MSG
Sorry! Not enough Doges in the vault (#{vault}) to give you #{starting_amt}
        MSG
      end
    end
  end
end

class DogeBot < SlackRubyBot::Bot

  command 'signup' do |client, data, match|
    result = Bank.instance.signup(data.user)
    client.say(text: result, channel: data.channel)
  end

  command 'ledger' do |client, data, match|
    bank = Bank.instance
    str = <<-MSG
Ledger: #{JSON.pretty_unparse JSON.parse(bank.ledger.to_json)}
Total: #{bank.ledger_value}

Vault: #{bank.vault}
    MSG

    client.say(text: str,
               channel: data.channel)
  end

  match /give (?<amount>\d+.\d+) to (?<user>.+)$/ do |client, data, match|
    amt = match[:amount].to_f
    to = match[:user]
    from = data.user

    result = Bank.instance.transfer(from, to, amt)
    if result
      client.say(text: "Transferred #{amt} from #{from} to #{to}", channel: data.channel)
    else
      client.say(text: "Failed to transfer #{amt} from #{from} to #{to}! Probably not enough Doges", channel: data.channel)
    end

  end

  command 'ping' do |client, data, match|
    str = <<-MSG
    PONG!
    #{data.user.class}
    #{data.to_json}
    MSG

    client.say(text: str, channel: data.channel)
  end
  command 'ping' do |client, data, match|
    str = <<-MSG
    PONG!
    #{data.user.class}
    #{data.to_json}
    MSG

    client.say(text: str, channel: data.channel)
  end
end

DogeBot.run
