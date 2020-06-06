class OsxTools

  def self.osascript(script)
    system 'osascript', *script.split(/\n/).map { |line| ['-e', line] }.flatten
  end

  def self.send_imessage(phone_number, body)

    OsxTools.osascript <<-END
      tell application "Messages"
          -- if Messages.app was not running, launch it
          set wasRunning to true
          if it is not running then
              set wasRunning to false
              launch
              close window 1

              -- wait for "Messages" to launch
              repeat until my appIsRunning("Messages")
                  tell application "Messages" to close window 1
                  delay 1
              end repeat

              -- the fact that Messages.app is running
              -- does not mean it is ready to send,
              -- unfortunately, add another small delay
              delay 1
              close window 1
          end if

          -- send the message
          set targetService to 1st service whose service type = iMessage
          set targetBuddy to buddy "#{phone_number}" of targetService
          send "#{body}" to targetBuddy

          -- if the app was not running, close the window
          if not wasRunning
              close window 1
          end if
      end tell
    END
  end

  def self.send_sms_message(phone_number, body)

    OsxTools.osascript <<-END
      tell application "Messages"
          -- if Messages.app was not running, launch it
          set wasRunning to true
          if it is not running then
              set wasRunning to false
              launch
              close window 1

              -- wait for "Messages" to launch
              repeat until my appIsRunning("Messages")
                  tell application "Messages" to close window 1
                  delay 1
              end repeat

              -- the fact that Messages.app is running
              -- does not mean it is ready to send,
              -- unfortunately, add another small delay
              delay 1
              close window 1
          end if

          -- send the message
          set targetService to id of service "SMS"
          set targetBuddy to buddy "#{phone_number}" of service id targetService
          send "#{body}" to targetBuddy

          -- if the app was not running, close the window
          if not wasRunning
              close window 1
          end if
      end tell
    END

  end

end
