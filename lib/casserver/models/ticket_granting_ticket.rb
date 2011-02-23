module CASServer::Model
  class TicketGrantingTicket < Ticket
    set_table_name 'casserver_tgt'

    serialize :extra_attributes

    has_many :granted_service_tickets,
      :class_name => 'CASServer::Model::ServiceTicket',
      :foreign_key => :granted_by_tgt_id
    
    # Creates a TicketGrantingTicket for the given username. This is done when the user logs in
    # for the first time to establish their SSO session (after their credentials have been validated).
    #
    # The optional 'extra_attributes' parameter takes a hash of additional attributes
    # that will be sent along with the username in the CAS response to subsequent
    # validation requests from clients.
    def self.generate_ticket_granting_ticket(username, host_name, extra_attributes = {})
      # 3.6 (ticket granting cookie/ticket)
      tgt = TicketGrantingTicket.new
      tgt.ticket = "TGC-" + CASServer::Utils.random_string
      tgt.username = username
      tgt.extra_attributes = extra_attributes
      tgt.client_hostname = host_name
      tgt.save!
      $LOG.debug("Generated ticket granting ticket '#{tgt.ticket}' for user" +
        " '#{tgt.username}' at '#{tgt.client_hostname}'" +
        (extra_attributes.blank? ? "" : " with extra attributes #{extra_attributes.inspect}"))
      tgt
    end
    
    def self.validate_ticket_granting_ticket(ticket)
      $LOG.debug("Validating ticket granting ticket '#{ticket}'")

      if ticket.nil?
        error = "No ticket granting ticket given."
        $LOG.debug error
      elsif tgt = TicketGrantingTicket.find_by_ticket(ticket)
        if settings.config[:maximum_session_lifetime] && Time.now - tgt.created_on > settings.config[:maximum_session_lifetime]
  	tgt.destroy
          error = "Your session has expired. Please log in again."
          $LOG.info "Ticket granting ticket '#{ticket}' for user '#{tgt.username}' expired."
        else
          $LOG.info "Ticket granting ticket '#{ticket}' for user '#{tgt.username}' successfully validated."
        end
      else
        error = "Invalid ticket granting ticket '#{ticket}' (no matching ticket found in the database)."
        $LOG.warn(error)
      end

      [tgt, error]
    end
  end
end