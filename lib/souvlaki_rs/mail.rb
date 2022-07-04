# frozen_string_literal: true

require 'mail'

module SouvlakiRS
  module Email
    def self.send(sender, recipient, subj, msg)
      mail = Mail.new do
        from     sender
        to       recipient
        subject  subj
        body     msg
      end

      mail.delivery_method :sendmail
      mail.deliver

      true
    end
  end
end
