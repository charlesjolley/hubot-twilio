{Robot, Adapter, TextMessage}   = require("hubot")
{inspect} = require 'util'
HTTP    = require "http"
URL     = require "url"
QS      = require "querystring"

class Twilio extends Adapter
  constructor: (robot) ->
    @sid   = process.env.HUBOT_SMS_SID
    @token = process.env.HUBOT_SMS_TOKEN
    @from  = process.env.HUBOT_SMS_FROM
    @robot = robot
    super robot

  send: (ctx, strings...) ->
    message = strings.join "\n"
    console.log "send"
    @robot.logger.debug "Twilio.send #{inspect(ctx)}: strings: '#{strings.join("','")}'"

    @send_sms message, ctx.user.id, (err, body) =>
      if err or not body?
        @robot.logger.info "Error sending reply SMS: #{err or "no body"}"
      else
        @robot.logger.info "Sending reply SMS: '#{message}' to #{ctx.user.id}"

  reply: (user, strings...) ->
    @send user, str for str in strings

  respond: (regex, callback) ->
    @hear regex, callback

  run: ->
    self = @

    @robot.router.get "/hubot/sms", (request, response) =>
      payload = URL.parse(request.url, true).query
      payload.From = payload.From.replace(/\s/g, '+') if payload.From
      payload.To = payload.To.replace(/\s/g, '+') if payload.To

      if payload.Body? and payload.From?
        @robot.logger.info "Received SMS: '#{payload.Body}' from #{payload.From}"
        @receive_sms(payload.Body, payload.From)

      response.writeHead 200, 'Content-Type': 'text/plain'
      response.end()

    self.emit "connected"

  receive_sms: (body, from) ->
    return if body.length is 0
    user = @robot.brain.userForId from
    @receive new TextMessage user, body

  send_sms: (message, to, callback) ->
    auth = new Buffer(@sid + ':' + @token).toString("base64")
    message = message.slice(0,159) if message.length>160
    data = QS.stringify From: @from, To: to, Body: message

    @robot.http("https://api.twilio.com")
      .path("/2010-04-01/Accounts/#{@sid}/SMS/Messages.json")
      .header("Authorization", "Basic #{auth}")
      .header("Content-Type", "application/x-www-form-urlencoded")
      .post(data) (err, res, body) ->
        if err
          callback err
        else if res.statusCode is 201
          json = JSON.parse(body)
          callback null, inspect(json)
        else
          json = JSON.parse(body)
          callback new Error(inspect(json))

exports.use = (robot) ->
  new Twilio robot

