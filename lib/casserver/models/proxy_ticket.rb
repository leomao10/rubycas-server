module CASServer::Model
  class ProxyTicket < ServiceTicket
    belongs_to :granted_by_pgt,
      :class_name => 'CASServer::Model::ProxyGrantingTicket',
      :foreign_key => :granted_by_pgt_id
      
    def self.generate!(target_service, host_name, pgt)
      # 3.2 (proxy ticket)
      pt = ProxyTicket.new(
        :ticket             => "PT-" + CASServer::Utils.random_string,
        :service            => target_service,
        :username           => pgt.service_ticket.username,
        :granted_by_pgt_id  => pgt.id,
        :granted_by_tgt_id  => pgt.service_ticket.granted_by_tgt.id,
        :client_hostname    => host_name
      )
      pt.save!
      logger.debug("Generated proxy ticket '#{pt.ticket}' for target service '#{pt.service}'" +
        " for user '#{pt.username}' at '#{pt.client_hostname}' using proxy-granting" +
        " ticket '#{pgt.ticket}'")
      pt
    end
    
    def self.validate_proxy_ticket(service, ticket)
      pt, error = ServiceTicket.validate_service_ticket(service, ticket, true)

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