module "smsbot" {
  source = "git::https://github.com/nikdoof/lambda-sms//terraform"

  providers = {
    aws = aws.eu_west_2
  }

  name                 = "smsbot"
  reserved_concurrency = -1

  tags = {
    managed-by = "terraform"
    project    = "smsbot"
  }
}

output "smsbot_message_url" {
  description = "Twilio 'A Message Comes In' webhook URL."
  value       = module.smsbot.message_url
}

output "smsbot_call_url" {
  description = "Twilio 'A Call Comes In' webhook URL."
  value       = module.smsbot.call_url
}
