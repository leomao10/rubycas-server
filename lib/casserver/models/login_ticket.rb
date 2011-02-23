module CASServer::Model
  class LoginTicket < Ticket
    @@life_time ||= 1.0 / 0 # infinity
    class_inheritable_accessor :life_time
    set_table_name 'casserver_lt'
    
    include Consumable
    
    after_save :log_ticket
    
    def expired?
      Time.now - self.created_on > @@life_time
    end
    
    def log_ticket
      logger.debug("Generated login ticket '#{ticket}' for client at '#{client_hostname}'")
    end
    
    def self.generate!(host_name)
      lt = LoginTicket.new(
        :ticket           => "LT-" + CASServer::Utils.random_string,
        :client_hostname  => host_name
      )
      lt.save!
      lt
    end
    
    def self.validate!(ticket)
      logger.debug("Validating login ticket '#{ticket}'")

      success = false
      if ticket.nil?
        error = _("Your login request did not include a login ticket. There may be a problem with the authentication system.")
        logger.warn "Missing login ticket."
      elsif lt = LoginTicket.find_by_ticket(ticket)
        if lt.consumed?
          error = _("The login ticket you provided has already been used up. Please try logging in again.")
          logger.warn "Login ticket '#{ticket}' previously used up"
        elsif lt.expired?
          error = _("You took too long to enter your credentials. Please try again.")
          logger.warn "Expired login ticket '#{ticket}'"
        else
          logger.info "Login ticket '#{ticket}' successfully validated"
        end
      else
        error = _("The login ticket you provided is invalid. There may be a problem with the authentication system.")
        logger.warn "Invalid login ticket '#{ticket}'"
      end

      lt.consume! if lt

      error
    end
  end
end