# iMessageServer

iMessageServer is a ruby/rails application designed to extract new iMessages from the iMessage database in the OS X operating system, format the extracted information into an SMS message, and transmit that message via [Twilio's SMS API](https://www.twilio.com/sms/api). The application can be controlled via the phone number receiving forwarded iMessages (via `forward` and `unforward` commands) or via a simple local web interface.

For this application to function, the user must be able to create a [Twilio account](https://www.twilio.com/sms/api) and an [AWS account](http://console.aws.amazon.com/). **This application will not run for free. Twilio and AWS charge fees according to their fee schedules ([Twilio](https://www.twilio.com/pricing), [AWS](https://aws.amazon.com/sqs/pricing/)).** For personal use, however, AWS charges will likely be zero (first 1 million `forward` and `unforward` commands per month are free as of the writing of this readme).

The application does not alter the operating system's iMessage database, but instead makes a temporary copy of the database in this application's directory each time iMessages are extracted. Accordingly, this application is not designed to respond to iMessage chats, but simply enables forwarding of the chat contents via SMS for users who are away from iMessage.

This repository has only been tested on OS X Catalina.

## Required Libraries / Dependencies
1. [RVM](https://rvm.io/) / [Rails](https://rubyonrails.org/) -- For one line installation: `\curl -sSL https://get.rvm.io | bash -s stable --rails`
2. [Homebrew](https://brew.sh/) -- For one line installation: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"`
3. [Yarn](https://yarnpkg.com/) -- For one line installation: `brew install yarn`
4. [Webpacker](https://github.com/rails/webpacker) -- For one line installation `rails webpacker:install`

## Required OS X Permissions
On OS X, you may also need to enable full disk access for "Terminal" app and "cron" binary
1. For Terminal: https://osxdaily.com/2018/10/09/fix-operation-not-permitted-terminal-error-macos/
2. For cron: https://osxdaily.com/2020/04/27/fix-cron-permissions-macos-full-disk-access/

## AWS Account -- Required
Because the iMessage server runs on your local machine, it would be difficult to handle callbacks associated with the `forward` and `unforward` commands without exposing your local machine to the internet. As an alternative, this application uses AWS Simple Queue Service (SQS) as a middle man for incoming commands to Twilio. When Twilio receives a command via SMS, the function shown below will create a message in AWS SQS. Your local machine will periodically check SQS for messages associated with these commands.
1. Sign up for [AWS](https://aws.amazon.com/).
2. Create SQS user(s) assigned to programmatically access SQS (e.g., one user for Twilio and another for your local server).
    * Use [IAM tool](https://console.aws.amazon.com/iam/)
    * Add user
    * Attach "AmazonSQSFullAccess" permission
    * Make note of user access key and secret (will need both when setting up Twilio below and during installation rake task)
3. Create two SQS Queues
    * Use [SQS tool](http://console.aws.amazon.com/sqs/)
    * Create Incoming Queue (FIFO - first in first out preferred) -- Make note of AWS region (e.g. us-east-1) and SQS Queue URL (will need during twilio set up and installation rake task)
    * Create SQS Callback Queue (Regular is fine) -- Make note of AWS region (e.g. us-east-1) and SQS Queue URL (will need during twilio set up)

## Twilio Account -- Required
You will need a [Twilio SMS account](https://www.twilio.com/sms) (free trial available as of May 2020) to send SMS messages.
1. Once you sign up for Twilio, make note of the following, which will need to be provided during the installation rake task:
    * Twilio phone Number
    * Twilio Account SID
    * Twilio Auth Token
2. You must implement a custom script on Twilio to forward the `forward` and `unforward` commands received by Twilio to the AWS SQS service. This is critical for being able to remotely start and stop iMessage forwarding while you are away from your local computer.
    * Navigate to https://www.twilio.com/console/functions/manage and create a new function.
    * Give your function a name (e.g. "Amazon SQS Enqueue")
    * Give your function a path (e.g. "/sqs")
    * Insert "AWS_KEY" and "AWS_SECRET" environment variables (use the values you recorded from the prior step above)
    * Insert "AWS_SQS_URL" and "AWS_CALLBACK_URL" environment variables (use URLs of two AWS SQS queues created above)
    * Insert the following code for the function and hit the "Save" button:
    * ```
      /* global exports, require, console, process, Twilio */
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
      const INCOMING_SMS_URL = process.env.AWS_SQS_URL
      const STATUS_CALLBACK_URL = process.env.AWS_CALLBACK_URL

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
      }
      ```

## Installation (Ensure Twilio and SQS are set up prior to installation)
1. **Complete the steps above to set up AWS and Twilio**
2. Clone or download this repository to a location on your Mac computer (running OS X) where it will not be accidentally deleted.
3. Navigate to the directory containing this repository and into the iMessageServer folder.
4. Run the command `rake setup:install` and follow the on screen prompts. All of the information requested must be entered correctly for the application to run properly. The application will not run if any required information is omitted (except optional information, e.g. iPhone number).
5. If some information was entered incorrectly, or some information needs to be changed, you may do so after installation using the web interface (see below).

## Usage
Assuming installation completed successfully, the application can be controlled entirely from the phone you are forwarding messages to. Currently, the application only supports the following commands when sent to your Twilio number (i.e., the number Twilio uses to forward iMessages to you).
1. `forward` (case insensitive) -- begins forwarding all iMessages received.
2. `unforward` (case insensitive) -- stops forwarding all iMessages received.
Currently, any other message sent to the Twilio number will elicit a response indicating the command is not supported.
    * IMPORTANT: Twilio supports standard SMS opt-in, opt-out, and help keywords (START, YES, UNSTOP, STOP, STOPALL, END, UNSUBSCRIBE, CANCEL, QUIT, HELP, and INFO). Using these keywords can opt-in and opt-out a telephone number from receiving messages from Twilio, but **these commands to not change the state of this application**. In other words, the opt-in command START will not cause iMessages to begin forwarding. Conversely, the opt-out command END will not cause the application to stop trying to forward iMessages
3. **Your computer must be awake to forward iMessages.** On OS X, change energy saver preferences to:
    * Check 'Prevent computer from sleeping automatically when the display is off'
    * Uncheck 'Put hard disks to sleep when possible'

By default, the application installs with forwarding **disabled** to avoid charging your Twilio and AWS accounts unless you affirmatively turn on forwarding, meaning you must turn forwarding on for iMessage forwarding to begin.

The application settings may also be controlled by a local web interface. To launch the local web server (not exposed to the internet), navigate to the directory containing this repository in Terminal, and (after installation) type the command `rails s`. This command starts the server. Once the server has started, navigate to http://localhost:3000/ in your browser.

As of the writing of this readme, the following Twilio charges apply (PLEASE CONSULT [TWILIO'S PRICING PAGE](https://www.twilio.com/pricing) FOR UP TO DATE PRICING INFORMATION):
    * Forward Simple SMS -- $0.0075 (Twilio fee) + carrier fees
    * Forward Picture Messages -- $0.02 (Twilio fee) + carrier fees
    * Recieve Simple SMS (e.g. `forward` and `unforward` command) -- $0.0075 (Twilio fee) + carrier fees

As of the writing of this readme, the following AWS charges apply (PLEASE CONSULT [AWS'S PRICING PAGE](https://aws.amazon.com/sqs/pricing/) FOR UP TO THE DATE PRICING INFORMATION):
    * The first million requests are free, after that, the following charges apply:
        * FIFO Message -- $0.0000005 per request ($0.50 per million requests)
        * Standard Message -- $0.0000004 per request ($0.40 per million requests)

For manually updating cron (advanced users): `whenever --update-crontab --set environment='development'`
