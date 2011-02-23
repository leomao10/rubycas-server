module CASServer::Model
  class ProxyTicket < ServiceTicket
    belongs_to :granted_by_pgt,
      :class_name => 'CASServer::Model::ProxyGrantingTicket',
      :foreign_key => :granted_by_pgt_id
      
    def self.generate_proxy_ticket(target_service, pgt)
      # 3.2 (proxy ticket)
      pt = ProxyTicket.new
      pt.ticket = "PT-" + CASServer::Utils.random_string
      pt.service = target_service
      pt.username = pgt.service_ticket.username
      pt.granted_by_pgt_id = pgt.id
      pt.granted_by_tgt_id = pgt.service_ticket.granted_by_tgt.id
      pt.client_hostname = @env['HTTP_X_FORWARDED_FOR'] || @env['REMOTE_HOST'] || @env['REMOTE_ADDR']
      pt.save!
      $LOG.debug("Generated proxy ticket '#{pt.ticket}' for target service '#{pt.service}'" +
        " for user '#{pt.username}' at '#{pt.client_hostname}' using proxy-granting" +
        " ticket '#{pgt.ticket}'")
      pt
    end
    
    def self.validate_proxy_ticket(service, ticket)
      pt, error = validate_service_ticket(service, ticket, true)

      if pt.kind_of?(CASServer::Model::ProxyTicket) && !error
        if not pt.granted_by_pgt
          error = Error.new(:INTERNAL_ERROR, "Proxy ticket '#{pt}' belonging to user '#{pt.username}' is not associated with a proxy granting ticket.")
        elsif not pt.granted_by_pgt.service_ticket
          error = Error.new(:INTERNAL_ERROR, "Proxy granting ticket '#{pt.granted_by_pgt}'"+
            " (associated with proxy ticket '#{pt}' and belonging to user '#{pt.username}' is not associated with a service ticket.")
        end
      end

      [pt, error]
    end
  end
end