module CASServer::Model
  class ProxyGrantingTicket < Ticket
    set_table_name 'casserver_pgt'
    belongs_to :service_ticket
    has_many :granted_proxy_tickets,
      :class_name => 'CASServer::Model::ProxyTicket',
      :foreign_key => :granted_by_pgt_id
    
    def self.generate_proxy_granting_ticket(pgt_url, st)
      uri = URI.parse(pgt_url)
      https = Net::HTTP.new(uri.host,uri.port)
      https.use_ssl = true

      # Here's what's going on here:
      #
      #   1. We generate a ProxyGrantingTicket (but don't store it in the database just yet)
      #   2. Deposit the PGT and it's associated IOU at the proxy callback URL.
      #   3. If the proxy callback URL responds with HTTP code 200, store the PGT and return it;
      #      otherwise don't save it and return nothing.
      #
      https.start do |conn|
        path = uri.path.empty? ? '/' : uri.path
        path += '?' + uri.query unless (uri.query.nil? || uri.query.empty?)

        pgt = ProxyGrantingTicket.new
        pgt.ticket = "PGT-" + CASServer::Utils.random_string(60)
        pgt.iou = "PGTIOU-" + CASServer::Utils.random_string(57)
        pgt.service_ticket_id = st.id
        pgt.client_hostname = @env['HTTP_X_FORWARDED_FOR'] || @env['REMOTE_HOST'] || @env['REMOTE_ADDR']

        # FIXME: The CAS protocol spec says to use 'pgt' as the parameter, but in practice
        #         the JA-SIG and Yale server implementations use pgtId. We'll go with the
        #         in-practice standard.
        path += (uri.query.nil? || uri.query.empty? ? '?' : '&') + "pgtId=#{pgt.ticket}&pgtIou=#{pgt.iou}"

        response = conn.request_get(path)
        # TODO: follow redirects... 2.5.4 says that redirects MAY be followed
        # NOTE: The following response codes are valid according to the JA-SIG implementation even without following redirects

        if %w(200 202 301 302 304).include?(response.code)
          # 3.4 (proxy-granting ticket IOU)
          pgt.save!
          logger.debug "PGT generated for pgt_url '#{pgt_url}': #{pgt.inspect}"
          pgt
        else
          logger.warn "PGT callback server responded with a bad result code '#{response.code}'. PGT will not be stored."
          nil
        end
      end
    end
    
    def self.validate_proxy_granting_ticket(ticket)
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