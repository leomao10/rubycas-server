module CASServer::Model
  class ProxyGrantingTicket < Ticket
    set_table_name 'casserver_pgt'
    belongs_to :service_ticket
    has_many :granted_proxy_tickets,
      :class_name => 'CASServer::Model::ProxyTicket',
      :foreign_key => :granted_by_pgt_id
    
    def self.generate!(pgt_url, host_name, st)
      pgt = ProxyGrantingTicket.new(
        :ticket             => "PGT-" + CASServer::Utils.random_string(60),
        :iou                => "PGTIOU-" + CASServer::Utils.random_string(57),
        :service_ticket_id  => st.id,
        :client_hostname    => host_name
      )

      if callback_url_valid?(pgt_url, pgt)
        pgt.save!
        logger.debug "PGT generated for pgt_url '#{pgt_url}': #{pgt.inspect}"
        pgt        
      else
        logger.warn "PGT callback server responded with a bad result code '#{response.code}'. PGT will not be stored."
        nil        
      end
    end
    
    def self.callback_url_valid?(pgt_url, pgt)
      uri = URI.parse(pgt_url)
      path = uri.path.empty? ? '/' : uri.path
      path += '?' + uri.query unless (uri.query.nil? || uri.query.empty?)
      path += (uri.query.nil? || uri.query.empty? ? '?' : '&') + "pgtId=#{pgt.ticket}&pgtIou=#{pgt.iou}"
      
      https = Net::HTTP.new(uri.host,uri.port)
      https.use_ssl = true      
      https.start do |conn|
        response = conn.request_get(path)
        if %w(200 202 301 302 304).include?(response.code)
          return true
        else
          return false      
        end
      end
    end
    
    def self.validate!(ticket)
      if ticket.nil?
        error = Error.new(:INVALID_REQUEST, "pgt parameter was missing in the request.")
        logger.warn("#{error.code} - #{error.message}")
      elsif pgt = ProxyGrantingTicket.find_by_ticket(ticket)
        if pgt.service_ticket
          logger.info("Proxy granting ticket '#{ticket}' belonging to user '#{pgt.service_ticket.username}' successfully validated.")
        else
          error = Error.new(:INTERNAL_ERROR, "Proxy granting ticket '#{ticket}' is not associated with a service ticket.")
          logger.error("#{error.code} - #{error.message}")
        end
      else
        error = Error.new(:BAD_PGT, "Invalid proxy granting ticket '#{ticket}' (no matching ticket found in the database).")
        logger.warn("#{error.code} - #{error.message}")
      end

      [pgt, error]
    end
  end
end