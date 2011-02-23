module CASServer::Model
  class TicketGrantingTicket < Ticket
    @@life_time = 1.0/0
    class_inheritable_accessor :life_time  
    
    set_table_name 'casserver_tgt'

    serialize :extra_attributes

    has_many :granted_service_tickets,
      :class_name => 'CASServer::Model::ServiceTicket',
      :foreign_key => :granted_by_tgt_id
    
    after_save :log_ticket
    
    def log_ticket
      logger.debug("Generated ticket granting ticket '#{ticket}' for user '#{username}' at '#{client_hostname}'" +
        (extra_attributes.blank? ? "" : " with extra attributes #{extra_attributes.inspect}"))
    end
    
    def expired?
      life_time && Time.now - tgt.created_on > life_time
    end
    
    def self.generate!(username, host_name, extra_attributes = {})
      tgt = TicketGrantingTicket.new(
        :ticket           => "TGC-" + CASServer::Utils.random_string,
        :username         => username,
        :extra_attributes => extra_attributes,
        :client_hostname  => host_name
      )
      tgt.save!
      tgt
    end
    
    def self.validate!(ticket)
      logger.debug("Validating ticket granting ticket '#{ticket}'")

      if ticket.nil?
        error = "No ticket granting ticket given."
        logger.debug error
      elsif tgt = TicketGrantingTicket.find_by_ticket(ticket)
        if tgt.expired?
  	      tgt.destroy
          error = "Your session has expired. Please log in again."
          logger.info "Ticket granting ticket '#{ticket}' for user '#{tgt.username}' expired."
        else
          logger.info "Ticket granting ticket '#{ticket}' for user '#{tgt.username}' successfully validated."
        end
      else
        error = "Invalid ticket granting ticket '#{ticket}' (no matching ticket found in the database)."
        logger.warn(error)
      end

      [tgt, error]
    end
  end
end