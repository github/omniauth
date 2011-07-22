require 'spec_helper'
require 'oauth'
require 'mechanize'

describe 'Twitter strategy integration testing' do 
  def config
    @config ||= {}
  end

  def app
    b = Rack::Builder.new
    b.use Rack::Session::Cookie
    b.use OmniAuth::Strategies::Twitter, config[:consumer_key] || 'abc', config[:consumer_secret] || 'def'
    b.run lambda{|env| [404, {'Auth' => env['omniauth.auth']}, [(env['omniauth.auth']['user_info']['name'] rescue "Hello.")]]}
    b.to_app
  end

  def run_request_phase
    get '/auth/twitter'
    last_response
  end

  context 'with invalid client credentials' do
    use_vcr_cassette 'twitter/invalid_client_credentials'

    it 'should error out' do
      lambda{ run_request_phase }.should raise_error(::OAuth::Unauthorized)
    end
  end

  context 'with valid client credentials' do
    use_vcr_cassette 'twitter/valid_client_credentials'

    before do
      config[:consumer_key] = TEST_CREDENTIALS['twitter']['key']
      config[:consumer_secret] = TEST_CREDENTIALS['twitter']['secret']
      @request_response = run_request_phase
    end

    it 'should redirect to Twitter for auth' do
      @request_response.headers['Location'].should be_include('api.twitter.com/oauth')
    end

    context 'on the authorize page' do
      let(:web){ Mechanize.new }
      let(:auth_page){ web.get @request_response.headers['Location'] }

      it 'should provide a Twitter username prompt at the designated URL' do
        auth_page.title.should == 'Twitter / Authorize an application'
      end

      context 'with user approval' do
        let(:auth_form){ auth_page.form_with(:id => 'oauth_form') }
        let(:approve_button){ auth_form.button_with(:id => "allow") }
        let(:approval_response) do
          username_field.value = TEST_CREDENTIALS['twitter']['username']
          password_field.value = TEST_CREDENTIALS['twitter']['password']
          auth_form.submit(approve_button)
        end
        let(:username_field){ auth_form.field_with(:name => 'session[username_or_email]') }
        let(:password_field){ auth_form.field_with(:name => 'session[password]') }
        let(:callback_url){ approval_response.meta_refresh.first.href }

        it 'should provide a redirect back to the application' do
          callback_url.should be_include("example.org/auth/twitter/callback")
        end
        
        context 'callback phase' do
          it 'should fetch an auth hash successfully' do
            get URI.parse(callback_url).path
            last_response.body.should == "Michael Bleigh"
          end
        end
      end
    end
  end
end

# Step 1: Run /auth/twitter and get the redirect URL
#   - Alternate: Run /auth/twitter with invalid credentials
# Step 2: Visit the redirect URL and click the "Approve" button
#   - Alternate: Click the "Deny" button
#   - Alternate: Make sure it works with /authorize instead of /authenticate
# Step 3: Grab the URL that Twitter redirects to, parse out the code
# Step 4: Call /auth/callback with the query params passed via the URL in step 3
# Step 5: Check that 
