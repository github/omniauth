require 'omniauth/enterprise'

module OmniAuth
  module Strategies
    class CAS
      include OmniAuth::Strategy

      autoload :Configuration, 'omniauth/strategies/cas/configuration'
      autoload :ServiceTicketValidator, 'omniauth/strategies/cas/service_ticket_validator'

      attr_accessor :raw_info
      alias_method :user_info, :raw_info
      
      option :uid_key,              'user'
 
       # As required by https://github.com/intridea/omniauth/wiki/Auth-Hash-Schema
       AuthHashSchemaKeys = %w{name email first_name last_name location image phone}
       info do
         prune!({
           :name       => raw_info['name'],
           :email      => raw_info['email'],
           :first_name => raw_info['first_name'],
           :last_name  => raw_info['last_name'],
           :location   => raw_info['location'],
           :image      => raw_info['image'],
           :phone      => raw_info['phone']
         })
       end
       
      uid do
        raw_info[ @options[:uid_key].to_s ]
      end

      def initialize(app, options = {}, &block)
        super(app, options[:name] || :cas, options.dup, &block)
        @configuration = OmniAuth::Strategies::CAS::Configuration.new(options)
      end

      protected

      def request_phase
        [
          302,
          {
            'Location' => @configuration.login_url(callback_url),
            'Content-Type' => 'text/plain'
          },
          ["You are being redirected to CAS for sign-in."]
        ]
      end

      def callback_phase
        @ticket = request.params['ticket']
        return fail!(:no_ticket, 'No CAS Ticket') unless ticket

        self.raw_info = ServiceTicketValidator.new(@configuration, callback_url, @ticket).user_info
        #self.raw_info = ServiceTicketValidator.new(self, @options, callback_url, @ticket).user_info
        
        return fail!(:invalid_ticket, 'Invalid CAS Ticket') if raw_info.empty?
 
        super
      end

      def auth_hash
        OmniAuth::Utils.deep_merge(super, {
          'uid' => @user_info.delete('user'),
          'extra' => @user_info
        })
      end
      
      private
 
       # Deletes Hash pairs with `nil` values.
       # From https://github.com/mkdynamic/omniauth-facebook/blob/972ed5e3456bcaed7df1f55efd7c05c216c8f48e/lib/omniauth/strategies/facebook.rb#L122-127
        def prune!(hash)
        hash.delete_if do |_, value| 
          prune!(value) if value.is_a?(Hash)
          value.nil? || (value.respond_to?(:empty?) && value.empty?)
        end
      end

    end
  end
end
