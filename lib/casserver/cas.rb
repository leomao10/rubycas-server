require 'uri'
require 'net/https'

require 'casserver/models/consumable'
require 'casserver/models/ticket'
require 'casserver/models/login_ticket'
require 'casserver/models/service_ticket'
require 'casserver/models/proxy_ticket'
require 'casserver/models/ticket_granting_ticket'
require 'casserver/models/proxy_granting_ticket'

# Encapsulates CAS functionality. This module is meant to be included in
# the CASServer::Controllers module.
module CASServer::CAS

  include CASServer::Model
  ActiveRecord::Base.logger = $LOG

  # Takes an existing ServiceTicket object (presumably pulled from the database)
  # and sends a POST with logout information to the service that the ticket
  # was generated for.
  #
  # This makes possible the "single sign-out" functionality added in CAS 3.1.
  # See http://www.ja-sig.org/wiki/display/CASUM/Single+Sign+Out
  def send_logout_notification_for_service_ticket(st)
    uri = URI.parse(st.service)
    http = Net::HTTP.new(uri.host, uri.port)
    #http.use_ssl = true if uri.scheme = 'https'

    time = Time.now
    rand = CASServer::Utils.random_string

    path = uri.path
    path = '/' if path.empty?

    req = Net::HTTP::Post.new(path)
    req.set_form_data(
      'logoutRequest' => %{<samlp:LogoutRequest ID="#{rand}" Version="2.0" IssueInstant="#{time.rfc2822}">
<saml:NameID></saml:NameID>
<samlp:SessionIndex>#{st.ticket}</samlp:SessionIndex>
</samlp:LogoutRequest>}
    )

    begin
      http.start do |conn|
        response = conn.request(req)

        if response.kind_of? Net::HTTPSuccess
          $LOG.info "Logout notification successfully posted to #{st.service.inspect}."
          return true
        else
          $LOG.error "Service #{st.service.inspect} responed to logout notification with code '#{response.code}'!"
          return false
        end
      end
    rescue Exception => e
      $LOG.error "Failed to send logout notification to service #{st.service.inspect} due to #{e}"
          return false
    end
  end

  def service_uri_with_ticket(service, st)
    raise ArgumentError, "Second argument must be a ServiceTicket!" unless st.kind_of? CASServer::Model::ServiceTicket

    # This will choke with a URI::InvalidURIError if service URI is not properly URI-escaped...
    # This exception is handled further upstream (i.e. in the controller).
    service_uri = URI.parse(service)

    if service.include? "?"
      if service_uri.query.empty?
        query_separator = ""
      else
        query_separator = "&"
      end
    else
      query_separator = "?"
    end

    service_with_ticket = service + query_separator + "ticket=" + st.ticket
    service_with_ticket
  end

  # Strips CAS-related parameters from a service URL and normalizes it,
  # removing trailing / and ?. Also converts any spaces to +.
  #
  # For example, "http://google.com?ticket=12345" will be returned as
  # "http://google.com". Also, "http://google.com/" would be returned as
  # "http://google.com".
  #
  # Note that only the first occurance of each CAS-related parameter is
  # removed, so that "http://google.com?ticket=12345&ticket=abcd" would be
  # returned as "http://google.com?ticket=abcd".
  def clean_service_url(dirty_service)
    return dirty_service if dirty_service.blank?
    clean_service = dirty_service.dup
    ['service', 'ticket', 'gateway', 'renew'].each do |p|
      clean_service.sub!(Regexp.new("&?#{p}=[^&]*"), '')
    end

    clean_service.gsub!(/[\/\?&]$/, '') # remove trailing ?, /, or &
    clean_service.gsub!('?&', '?')
    clean_service.gsub!(' ', '+')

    $LOG.debug("Cleaned dirty service URL #{dirty_service.inspect} to #{clean_service.inspect}") if
      dirty_service != clean_service

    return clean_service
  end
  module_function :clean_service_url

end
