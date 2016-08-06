require File.expand_path('../../../spec_helper', __FILE__)
require 'cgi'

describe OmniAuth::Strategies::CAS, :type => :strategy do

  include OmniAuth::Test::StrategyTestCase

  def strategy
    @cas_server ||= 'https://cas.example.org'
    [OmniAuth::Strategies::CAS, {:cas_server => @cas_server}]
  end

  describe 'GET /auth/cas' do
    before do
      get '/auth/cas'
    end

    it 'should redirect to the CAS server' do
      last_response.should be_redirect
      return_to = CGI.escape(last_request.url + '/callback')
      last_response.headers['Location'].should == @cas_server + '/login?service=' + return_to
    end
  end

  describe 'GET /auth/cas/callback without a ticket' do
    before do
      get '/auth/cas/callback'
    end
    it 'should fail' do
      last_response.should be_redirect
      last_response.headers['Location'].should =~ /no_ticket/
    end
  end

  describe 'GET /auth/cas/callback with an invalid ticket' do
    before do
      stub_request(:get, /^https:\/\/cas.example.org(:443)?\/serviceValidate\?([^&]+&)?ticket=9391d/).
         to_return(:body => File.read(File.join(File.dirname(__FILE__), '..', '..', 'fixtures', 'cas_failure.xml')))
      get '/auth/cas/callback?ticket=9391d'
    end
    it 'should fail' do
      last_response.should be_redirect
      last_response.headers['Location'].should =~ /invalid_ticket/
    end
  end

  describe 'GET /auth/cas/callback with a valid ticket' do
    # this is where we need to update for cas_spec.3.0.xml
    before do
      stub_request(:get, /^http:\/\/cas.example.org:8080?\/serviceValidate\?([^&]+&)?ticket=593af/)
        .with { |request| @request_uri = request.uri.to_s }
        .to_return( body: File.read("spec/fixtures/#{xml_file_name}") )

        get "/auth/cas/callback?ticket=593af&url=#{return_url}"
    end

    it 'should strip the ticket parameter from the callback URL before sending it to the CAS server' do
      @request_uri.scan('ticket=').length.should == 1
    end

    context "request.env['omniauth.auth']" do
      subject { last_request.env['omniauth.auth'] }

      it { should be_kind_of Hash }

      its(:provider) { should == :cas }

      its(:uid) { should == '54'}

      context 'the info hash' do
        subject { last_request.env['omniauth.auth']['info'] }

        it { should have(6).items }

        its(:name)       { should == 'Peter Segel' }
        its(:first_name) { should == 'Peter' }
        its(:last_name)  { should == 'Segel' }
        its(:email)      { should == 'psegel@intridea.com' }
        its(:location)   { should == 'Washington, D.C.' }
        its(:image)      { should == '/images/user.jpg' }
        its(:phone)      { should == '555-555-5555' }
      end

      context 'the extra hash' do
        subject { last_request.env['omniauth.auth']['extra'] }

        it { should have(3).items }

        its(:user)       { should == 'psegel' }
        its(:employeeid) { should == '54' }
        its(:hire_date)  { should == '2004-07-13' }
      end

      context 'the credentials hash' do
        subject { last_request.env['omniauth.auth']['credentials'] }

        it { should have(1).items }

        its(:ticket) { should == '593af' }
      end
    end

    it 'should call through to the master app' do
      last_response.body.should == 'true'
    end
    
    context 'cas-protocol-2.0' do
      let(:xml_file_name) { 'cas_success_2.0.xml' }
      it_behaves_like :successful_validation
    end
  
    context 'cas-protocol-3.0' do
      let(:xml_file_name) { 'cas_success_3.0.xml' }
      it_behaves_like :successful_validation
    end
  end

  unless RUBY_VERSION =~ /^1\.8\.\d$/
    describe 'GET /auth/cas/callback with a valid ticket and gzipped response from the server on ruby >1.8' do
      before do
        zipped = StringIO.new
        Zlib::GzipWriter.wrap zipped do |io|
          io.write File.read(File.join(File.dirname(__FILE__), '..', '..', 'fixtures', 'cas_success.xml'))
        end
        stub_request(:get, /^https:\/\/cas.example.org(:443)?\/serviceValidate\?([^&]+&)?ticket=593af/).
           with { |request| @request_uri = request.uri.to_s }.
           to_return(:body => zipped.string, :headers => { 'content-encoding' => 'gzip' })
        get '/auth/cas/callback?ticket=593af'
      end

      it 'should call through to the master app when response is gzipped' do
          last_response.body.should == 'true'
      end
    end
  end
end
