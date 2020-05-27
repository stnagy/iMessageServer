# README

This repository requires a computer running OSX Catalina

## Required Dependencies
After cloning the repository, you will may need to install yarn and install/update webpacker (requires homebrew)
1. `brew install yarn`
2. `rails webpacker:install`

Homebrew can be installed by visiting https://brew.sh/

## Installation
1. To be completed :: need rake task for creating user and updating crontab.

## Required Permissions
On OS X, you may also need to enable full disk access for "Terminal" app and "cron" binary
1. For Terminal app: https://osxdaily.com/2018/10/09/fix-operation-not-permitted-terminal-error-macos/
2. For cron binary: https://osxdaily.com/2020/04/27/fix-cron-permissions-macos-full-disk-access/

## Twilio Account Required
You will need a [Twilio SMS account](https://www.twilio.com/sms) (free trial available as of May 2020) to send SMS messages. Once you sign up for Twilio, you will need to use this application's [web interface](http://localhost:3000/) to update the following to match your Twilio account:
1. Twilio phone Number
2. Twilio Account SID
3. Twilio Auth Token
