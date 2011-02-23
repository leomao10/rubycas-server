module CASServer::Model
  class ServiceTicket < Ticket
    set_table_name 'casserver_st'
    include Consumable

    belongs_to :granted_by_tgt,
      :class_name => 'CASServer::Model::TicketGrantingTicket',
      :foreign_key => :granted_by_tgt_id
    has_one :proxy_granting_ticket,
      :foreign_key => :created_by_st_id

    def matches_service?(service)
      CASServer::CAS.clean_service_url(self.service) ==
        CASServer::CAS.clean_service_url(service)
    end
    
    def self.generate_service_ticket(service, username, tgt, host_name)
      # 3.1 (service ticket)
      st = ServiceTicket.new
      st.ticket = "ST-" + CASServer::Utils.random_string
      st.service = service
      st.username = username
      st.granted_by_tgt_id = tgt.id
      st.client_hostname = host_name
      st.save!
      logger.debug("Generated service ticket '#{st.ticket}' for service '#{st.service}'" +
        " for user '#{st.username}' at '#{st.client_hostname}'")
      st
    end
    
    def self.validate_service_ticket(service, ticket, allow_proxy_tickets = false)
      logger.debug "Validating service/proxy ticket '#{ticket}' for service '#{service}'"

      if service.nil? or ticket.nil?
        error = Error.new(:INVALID_REQUEST, "Ticket or service parameter was missing in the request.")
        logger.warn "#{error.code} - #{error.message}"
      elsif st = ServiceTicket.find_by_ticket(ticket)
        if st.consumed?
          error = Error.new(:INVALID_TICKET, "Ticket '#{ticket}' has already been used up.")
          logger.warn "#{error.code} - #{error.message}"
        elsif st.kind_of?(CASServer::Model::ProxyTicket) && !allow_proxy_tickets
          error = Error.new(:INVALID_TICKET, "Ticket '#{ticket}' is a proxy ticket, but only service tickets are allowed here.")
          logger.warn "#{error.code} - #{error.message}"
        elsif Time.now - st.created_on > settings.config[:maximum_unused_service_ticket_lifetime]
          error = Error.new(:INVALID_TICKET, "Ticket '#{ticket}' has expired.")
          logger.warn "Ticket '#{ticket}' has expired."
        elsif !st.matches_service? service
          error = Error.new(:INVALID_SERVICE, "The ticket '#{ticket}' belonging to user '#{st.username}' is valid,"+
            " but the requested service '#{service}' does not match the service '#{st.service}' associated with this ticket.")
          logger.warn "#{error.code} - #{error.message}"
        else
          logger.info("Ticket '#{ticket}' for service '#{service}' for user '#{st.username}' successfully validated.")
        end
      else
        error = Error.new(:INVALID_TICKET, "Ticket '#{ticket}' not recognized.")
        logger.warn("#{error.code} - #{error.message}")
      end

      if st
        st.consume!
      end


      [st, error]
    end
  end
end