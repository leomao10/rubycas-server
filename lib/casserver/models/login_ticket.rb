module CASServer::Model
  class LoginTicket < Ticket
    @@life_time ||= 1.0 / 0 # infinity
    class_inheritable_accessor :life_time
    set_table_name 'casserver_lt'
    
    include Consumable
    
    def expired?
      Time.now - self.created_on > @@life_time
    end
    
    def self.generate_login_ticket(host_name)
      # 3.5 (login ticket)
      lt = LoginTicket.new
      lt.ticket = "LT-" + CASServer::Utils.random_string

      lt.client_hostname = host_name
      lt.save!
      logger.debug("Generated login ticket '#{lt.ticket}' for client" +
        " at '#{lt.client_hostname}'")
      lt
    end
    
    def self.validate_login_ticket(ticket)
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