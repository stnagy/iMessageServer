# README

This repository is only tested on OS X Catalina.

## Required Libraries / Dependencies
1. rvm / Rails - `\curl -sSL https://get.rvm.io | bash -s stable --rails`
2. Homebrew - https://brew.sh/
3. Yarn - `brew install yarn`
4. Webpacker - `rails webpacker:install`

## Required OS X Permissions
On OS X, you may also need to enable full disk access for "Terminal" app and "cron" binary
1. For Terminal: https://osxdaily.com/2018/10/09/fix-operation-not-permitted-terminal-error-macos/
2. For cron: https://osxdaily.com/2020/04/27/fix-cron-permissions-macos-full-disk-access/

## AWS Account -- Required
1. Must create SQS user(s) assigned to programmatically access SQS (potentially one user for twilio and another for your local server).
  * Use IAM tool
  * Add user
  * Attach "AmazonSQSFullAccess" permission
  * Make note of user access key and secret (will need both when setting up Twilio below and during installation rake task)
2. Create SQS Queue (FIFO - first in first out preferred)
  * Make not of AWS region (e.g. us-east-1) and SQS Queue URL (will need during installation rake task)

## Twilio Account -- Required
You will need a [Twilio SMS account](https://www.twilio.com/sms) (free trial available as of May 2020) to send SMS messages.
1. Once you sign up for Twilio, you will need to use this application's [web interface](http://localhost:3000/) to make note of the following, which will need to be provided during the installation rake task:
  * Twilio phone Number
  * Twilio Account SID
  * Twilio Auth Token
2. You must implement a custom script on Twilio to forward any responses Twilio receives via SMS to AWS SQS service. This is critical for being able to remotely start and stop iMessage forwarding while you are away from your local computer. To do so, navigate to https://www.twilio.com/console/functions/manage and create a new function.
  * Give your function a name (e.g. "Amazon SQS Enqueue")
  * Give your function a path (e.g. "/sqs")
  * Insert "AWS_KEY" and "AWK_SECRET" environment variables (use the values you recorded from the prior step above)
  * Insert the following code for the function and hit the "Save" button:

  `/* global exports, require, console, process, Twilio */
  'use strict'
  // Some Node.js modules are preinstalled in the system environment.
  // As of this writing, the third party modules are not configureable, but
  // they should be soon. For now, though, you can take advantage of
  // the AWS SDK being preinstalled. Require and initialize it here with the
  // IAM credentials in your system environment.
  const AWS = require('aws-sdk')
  AWS.config.update({
    accessKeyId: process.env.AWS_KEY,
    secretAccessKey: process.env.AWS_SECRET
  })
  // Get a handle to SQS in the AWS region you created it in
  let sqs = new AWS.SQS({ region: 'us-east-1' })
  // Define SQS queue URLs from your AWS account
  const INCOMING_SMS_URL = 'https://sqs.us-east-1.amazonaws.com/304033346064/TwilioIncomingSMS.fifo'
  const STATUS_CALLBACK_URL = '	https://sqs.us-east-1.amazonaws.com/304033346064/StatusCallbacks'
  // Implement handler function for incoming messages and status callbacks
  exports.handler = function(context, event, callback) {
    // SQS send params - assume it's a status callback to a standard queue
    let sendParameters = {
      MessageBody: JSON.stringify(event),
      QueueUrl: STATUS_CALLBACK_URL
    }
    // If the MessageStatus parameter is not passed, this is an incoming SMS
    // message - add appropriate SQS parameters and change the URL
    if (!event.MessageStatus) {
      sendParameters.QueueUrl = INCOMING_SMS_URL
      // FIFO queues use the message group ID to return messages to consumers
      // in logical groups. For an SMS app, a good group ID is the recipient
      // phone number
      sendParameters.MessageGroupId = event.From.replace(/\D/g,'')
    }
    // Add the message to the appropriate SQS queue
    sqs.sendMessage(sendParameters, (err, res) => {
      // For now, we'll just log any errors SQS throws us
      console.log(err)
      console.log(res)
      // Send a TwiML response with no reply message - we'll handle
      // any responses from our workers
      let twiml = new Twilio.twiml.MessagingResponse()
      callback(null, twiml)
    })
  }`

## Installation (Ensure Twilio and SQS are set up prior to installation)
1. To be completed :: need simple rake task for creating user with associated preferences and updating crontab.
2. For now, to update crontab:
`whenever --update-crontab --set environment='development'`
